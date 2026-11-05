"""Build a thin AppImage with one distribution-owned GTK/WebKit/media ABI."""
import hashlib
import linux_system_runtime as system_runtime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
BASE_APP_ID = 'app.raft.raft_flutter'
# An isolated test build (RAFT_APPLICATION_ID_SUFFIX=.isolated, see
# apps/raft_flutter/linux/CMakeLists.txt) uses its own id for the desktop file,
# icon, AppStream id, data/cache directories and keyring attribute.
APP_ID_SUFFIX = os.environ.get('RAFT_APPLICATION_ID_SUFFIX', '')
APP_ID = BASE_APP_ID + APP_ID_SUFFIX
# Several plugins key host-wide state by the executable's name (the notification
# plugin keeps $XDG_RUNTIME_DIR/<name>/notification_plugin_cache.json, path_provider
# falls back to a data directory of that name), so an isolated build ships its
# binary under a different name.
BASE_EXECUTABLE = 'raft_flutter'
EXECUTABLE = 'raft_isolated' if APP_ID_SUFFIX else BASE_EXECUTABLE
# In-app updates (packages/raft_updater, docs/auto-update.md) read this string
# back from the AppImage's `.upd_info` ELF section and fetch the delta with the
# zsync protocol. The official build points at this repository's latest release;
# `AppImageUpdateInformation.official` in packages/raft_updater must stay equal
# (tool/tests/test_appimage.py compares the two).
UPDATE_OWNER, UPDATE_REPOSITORY = 'kevinzhow', 'raft-flutter'
UPDATE_ASSET_PATTERN = 'raft-flutter-*-appimage-x64.AppImage.zsync'
OFFICIAL_UPDATE_INFORMATION = (
    f'gh-releases-zsync|{UPDATE_OWNER}|{UPDATE_REPOSITORY}|latest|{UPDATE_ASSET_PATTERN}')
# The runtime reserves 1024 bytes for the string (AppImageSpec `.upd_info`).
UPDATE_INFORMATION_LIMIT = 1023


HOST_LIBRARY_DIRECTORIES = ('/usr/lib64', '/usr/lib/x86_64-linux-gnu', '/usr/lib', '/lib', '/lib64')


def update_information(suffix=APP_ID_SUFFIX, environ=os.environ):
    """The update information to embed, or '' for a build that must not self-update.

    The real build always points at the official latest release. An isolated
    test build (RAFT_APPLICATION_ID_SUFFIX) must never update itself into the
    official build, so it embeds nothing; only the test harness may name another
    feed through RAFT_APPIMAGE_UPDATE_INFO (rejected without the suffix, so
    release CI cannot pick it up by accident).
    """
    override = environ.get('RAFT_APPIMAGE_UPDATE_INFO', '').strip()
    if not suffix:
        if override:
            raise ValueError('RAFT_APPIMAGE_UPDATE_INFO is only for isolated test builds')
        return OFFICIAL_UPDATE_INFORMATION
    if not override:
        return ''
    if (len(override.encode()) > UPDATE_INFORMATION_LIMIT or
            not re.fullmatch(r'(?:zsync\|https?://[^|\s]+|gh-releases-zsync(?:\|[^|\s]+){4})', override)):
        raise ValueError('RAFT_APPIMAGE_UPDATE_INFO must be zsync|URL or gh-releases-zsync|owner|repo|tag|pattern')
    return override


def zsync_control(path):
    """Header fields of a .zsync control file (the text before the blank line)."""
    with Path(path).open('rb') as stream:
        head = stream.read(8192)
    end = head.find(b'\n\n')
    if end < 0:
        raise ValueError(f'{path} has no zsync header')
    fields = {}
    for line in head[:end].decode('utf-8').splitlines():
        key, _, value = line.partition(': ')
        fields[key] = value
    return fields


def make_zsync(artifact, zsyncmake='zsyncmake'):
    """Write `<artifact>.zsync` next to the AppImage and return its path.

    appimagetool only generates it when zsyncmake happens to be installed and
    otherwise just warns, so the release calls zsyncmake itself and checks the
    result against the artifact: the relative URL must be the asset's own file
    name (the client resolves it against the .zsync asset URL), and the whole-file
    SHA-1 and length must match.
    """
    artifact = Path(artifact)
    if not shutil.which(zsyncmake):
        raise ValueError('zsyncmake is required to publish delta updates (apt install zsync)')
    target = artifact.with_name(artifact.name + '.zsync')
    subprocess.run([zsyncmake, '-u', artifact.name, '-o', str(target), str(artifact)], check=True,
                   cwd=artifact.parent)
    fields = zsync_control(target)
    with artifact.open('rb') as stream:
        sha1 = hashlib.file_digest(stream, 'sha1').hexdigest()
    if (fields.get('URL') != artifact.name or fields.get('Length') != str(artifact.stat().st_size)
            or fields.get('SHA-1') != sha1 or 'Z-URL' in fields):
        raise ValueError(f'{target.name} does not describe {artifact.name}')
    return target


def isolated_directory_setup(app_id, suffix):
    """Create this id's XDG data and cache directories before the app starts.

    path_provider_linux falls back to a directory named after the executable
    when the id directory does not exist yet. The isolated binary already has
    its own name (EXECUTABLE); this keeps the id directory in place regardless.
    The real build (no suffix) gets no extra lines.
    """
    if not suffix:
        return ''
    dollar = chr(36)
    return '\n'.join([
        'data_home="' + dollar + '{XDG_DATA_HOME:-' + dollar + 'HOME/.local/share}"',
        'cache_home="' + dollar + '{XDG_CACHE_HOME:-' + dollar + 'HOME/.cache}"',
        'mkdir -p "' + dollar + 'data_home/' + app_id + '" "' + dollar + 'cache_home/' + app_id + '"',
    ]) + '\n'


def capture(args, **kwargs):
    return subprocess.check_output([str(x) for x in args], text=True, **kwargs).strip()


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def dependencies(path, env=None):
    listing = capture(['ldd', path], env=env)
    if 'not found' in listing or 'version `' in listing:
        raise ValueError(f'Unresolved dependencies for {path}: {listing}')
    return {name: Path(target) for name, target in
            re.findall(r'^\s*(\S+) => (/\S+)', listing, re.M)}


def download_tool(name, record, folder):
    path = folder / name
    if not path.exists():
        request = urllib.request.Request(record['url'], headers={'User-Agent': 'Raft-AppImage-CI'})
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != record['sha256']:
            raise ValueError(f'{name} download SHA-256 changed; update the reviewed tools lock')
        path.write_bytes(data)
    if digest(path) != record['sha256']:
        raise ValueError(f'{name} cached SHA-256 does not match the tools lock')
    path.chmod(0o755)
    return path


def glibc_requirement(text):
    versions = [tuple(map(int, value.split('.'))) for value in
                re.findall(r'Name: GLIBC_([0-9]+\.[0-9]+(?:\.[0-9]+)?)', text)]
    required = max(versions, default=(0, 0))
    if required > (2, 39):
        raise ValueError(f'AppImage requires GLIBC_{".".join(map(str, required))}; exceeds Ubuntu 24.04 baseline')
    return required


def package(stage, artifact, root, run, capture_output, file_digest):
    """Thin AppImage: package the app and declare distribution runtime dependencies."""
    work = stage.parent / 'appimage'
    appdir = work / 'Raft.AppDir'
    appdir.mkdir(parents=True)
    shutil.move(str(stage), appdir / 'raft')
    stage = appdir / 'raft'
    (stage / 'RUN.txt').unlink()
    if EXECUTABLE != BASE_EXECUTABLE:
        (stage / BASE_EXECUTABLE).rename(stage / EXECUTABLE)
    libraries, files = system_runtime.inventory(stage, EXECUTABLE)
    env = {key: value for key, value in os.environ.items() if key not in {'LD_LIBRARY_PATH', 'LD_PRELOAD'}}
    needed_glibc, host_libraries = (0, 0), set()
    for path in files:
        if path.name in system_runtime.LINKED_SYSTEM_ABIS:
            system_runtime.verify_linked_system_abi(path, capture_output(['patchelf', '--print-needed', path]))
        private_no_soname = path.name == 'libsqlite3.so' or path.relative_to(stage).as_posix() == 'lib/' + system_runtime.WEB_EXTENSION
        if private_no_soname and capture_output(['patchelf', '--print-soname', path]).strip():
            raise ValueError('Private SQLite/WebExtension must not shadow a system SONAME')
        run(['patchelf', '--set-rpath', system_runtime.rpath(path, stage), path])
        needed_glibc = max(needed_glibc, glibc_requirement(capture_output(['readelf', '--version-info', path])))
        for name, resolved in dependencies(path, env=env).items():
            if not resolved.resolve().is_relative_to(stage.resolve()):
                if not any(resolved.resolve().is_relative_to(Path(directory)) for directory in HOST_LIBRARY_DIRECTORIES):
                    raise ValueError('AppImage dependency is outside the app/distribution: ' + str(resolved))
                host_libraries.add(name)
    icon = root / 'apps/raft_flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png'
    shutil.copy2(icon, appdir / f'{APP_ID}.png')
    (appdir / '.DirIcon').symlink_to(f'{APP_ID}.png')
    desktop = (stage / 'data/applications' / f'{APP_ID}.desktop').read_text()
    desktop = re.sub(r'^Exec=.*$', f'Exec={EXECUTABLE} %u', desktop, flags=re.M)
    desktop = re.sub(r'^Icon=.*$', f'Icon={APP_ID}', desktop, flags=re.M)
    (appdir / f'{APP_ID}.desktop').write_text(desktop)
    metadata = appdir / 'usr/share/metainfo'
    metadata.mkdir(parents=True)
    base_metainfo = (root / 'packaging/appimage' / f'{BASE_APP_ID}.metainfo.xml').read_text()
    (metadata / f'{APP_ID}.metainfo.xml').write_text(
        base_metainfo.replace(BASE_APP_ID, APP_ID).replace('<name>Raft</name>', '<name>Raft (isolated build)</name>')
        if APP_ID_SUFFIX else base_metainfo)
    launcher = appdir / 'AppRun'
    text = system_runtime.launcher(EXECUTABLE, '$app_dir/raft')
    text = text.replace('# System GTK', isolated_directory_setup(APP_ID, APP_ID_SUFFIX) + '# System GTK', 1)
    launcher.write_text(text)
    launcher.chmod(0o755)
    policy = system_runtime.receipt(libraries, host_libraries)
    (stage / 'linux-system-runtime.json').write_text(json.dumps(policy, indent=2) + '\n')
    tools = json.loads((root / 'packaging/appimage/tools.json').read_text())
    tool_notices = stage / 'data/notices/appimage-runtime'
    tool_notices.mkdir(parents=True)
    shutil.copy2(root / 'packaging/appimage/runtime.LICENSE', tool_notices / 'LICENSE')
    (tool_notices / 'source.json').write_text(json.dumps(tools['runtime'], indent=2) + '\n')
    cache = root / '.local/appimage-tools'
    cache.mkdir(parents=True, exist_ok=True)
    tool = download_tool('appimagetool.AppImage', tools['appimagetool'], cache)
    runtime = download_tool('runtime-x86_64', tools['runtime'], cache)
    information = update_information()
    command = [tool, '--appimage-extract-and-run', '--runtime-file', runtime]
    if information:
        command += ['--updateinformation', information]
    run([*command, appdir, artifact], env=dict(env, ARCH='x86_64'), cwd=work)
    artifact.chmod(0o755)
    return {'runtime': tools['runtime'], 'appimagetool': tools['appimagetool'],
            'buildSystem': 'Ubuntu 24.04 x86_64',
            'maximumGlibcRequired': '.'.join(map(str, needed_glibc)),
            'elfFilesChecked': len(files), 'hostProvidedLibraries': sorted(host_libraries),
            'systemRuntime': policy, 'pdfHelpers': ['system pdfinfo', 'system pdftoppm'],
            'imageLoaderModules': 'distribution GdkPixbuf/SVG modules',
            'updateInformation': information or None,
            'desktopLauncher': 'distribution GIO; host environment is unchanged',
            'launchModes': ['direct (static FUSE 3 library)', '--appimage-extract-and-run (no FUSE)']}
