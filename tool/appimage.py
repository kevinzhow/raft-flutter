"""Build a relocatable AppImage on Ubuntu 24.04; keep graphics drivers on the host."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import shlex
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
HOST_LAUNCH_VARIABLES = ('PATH', 'LD_LIBRARY_PATH', 'GIO_MODULE_DIR',
                         'GSETTINGS_SCHEMA_DIR', 'GIO_LAUNCH_DESKTOP', 'GTK_IM_MODULE_FILE',
                         'GDK_PIXBUF_MODULE_FILE')


# libmpv links the VA-API client libraries. A VA driver (iHD, radeonsi) must be
# built against a libva no newer than the one that loads it, and libva searches
# the driver directory it was compiled with, so a bundled Ubuntu libva cannot
# load a Fedora driver. Prefer the host's; ship these only as a fallback that
# AppRun adds to the library path when the host lacks them.
LIBVA_LIBRARIES = ('libva.so.2', 'libva-drm.so.2', 'libva-x11.so.2', 'libva-wayland.so.2')
HOST_LIBRARY_DIRECTORIES = ('/usr/lib64', '/usr/lib/x86_64-linux-gnu', '/usr/lib')


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


def host_libva_check():
    names = ' '.join(LIBVA_LIBRARIES)
    dirs = ' '.join(HOST_LIBRARY_DIRECTORIES)
    return f'''host_libva=1
for lib in {names}; do
  found=0
  for dir in {dirs}; do
    if [ -e "$dir/$lib" ]; then found=1; break; fi
  done
  if [ "$found" = 0 ]; then host_libva=0; fi
done
'''


GTK3_IM_CACHES = (
    '/usr/lib64/gtk-3.0/3.0.0/immodules.cache',
    '/usr/lib/x86_64-linux-gnu/gtk-3.0/3.0.0/immodules.cache',
    '/usr/lib/gtk-3.0/3.0.0/immodules.cache',
)


def input_method_cache_setup(candidates=GTK3_IM_CACHES):
    dollar = chr(36)
    # These are host GTK3 module caches for the installed input-method bridge.
    # Preserve an explicit value, including an intentionally empty value.
    return '\n'.join([
        'if [ -z "' + dollar + '{GTK_IM_MODULE_FILE+x}" ]; then',
        '  for module_cache in ' + ' '.join(shlex.quote(path) for path in candidates) + '; do',
        '    if [ -r "' + dollar + 'module_cache" ]; then',
        '      export GTK_IM_MODULE_FILE="' + dollar + 'module_cache"',
        '      break',
        '    fi',
        '  done',
        'fi',
    ]) + '\n'


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


def host_environment_capture():
    lines = []
    for key in HOST_LAUNCH_VARIABLES:
        lines.append('export RAFT_APPIMAGE_HOST_' + key + '_SET="' +
                     chr(36) + '{' + key + '+x}"')
        lines.append('export RAFT_APPIMAGE_HOST_' + key + '="' +
                     chr(36) + '{' + key + '-}"')
    return '\n'.join(lines) + '\n'


def desktop_launcher_wrapper():
    # Host programs must not load Ubuntu AppImage libraries or GIO modules.
    dollar = chr(36)
    lines = ['#!/bin/sh', 'set -eu',
             'helper_dir=' + dollar + '(CDPATH= cd -- "' + dollar +
             '(dirname -- "' + dollar + '0")" && pwd)',
             'launcher="' + dollar + '{RAFT_APPIMAGE_HOST_GIO_LAUNCH_DESKTOP:-' +
             dollar + 'helper_dir/gio-launch-desktop}"']
    for key in HOST_LAUNCH_VARIABLES:
        prefix = 'RAFT_APPIMAGE_HOST_' + key
        lines.extend([
            'if [ "' + dollar + '{' + prefix + '_SET:-}" = x ]; then',
            '  export ' + key + '="' + dollar + '{' + prefix + '-}"',
            'else',
            '  unset ' + key,
            'fi',
            'unset ' + prefix + ' ' + prefix + '_SET'])
    lines.append('unset APPDIR APPIMAGE ARGV0 OWD')
    lines.append('exec "' + dollar + 'launcher" "' + dollar + '@"')
    return '\n'.join(lines) + '\n'


def image_loader_cache(text, modules):
    """Use module basenames; the bundled GModule finds them in private lib RPATH.

    Ubuntu's Linux GdkPixbuf is not built with Windows-style relocatable paths.
    CI must decode an SVG using the extracted library, not a host replacement.
    """
    for module in modules:
        text = text.replace('"' + str(module) + '"', '"' + module.name + '"')
    paths = re.findall(r'^"([^"\n]+\.so)"$', text, re.M)
    if set(paths) != {module.name for module in modules}:
        raise ValueError('Image loader cache does not match the packaged modules')
    # Build directory comments are unnecessary and would be misleading on hosts.
    return '\n'.join(line for line in text.splitlines() if not line.startswith('#')) + '\n'


def capture(args, **kwargs):
    return subprocess.check_output([str(x) for x in args], text=True, **kwargs).strip()


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def exclusions():
    vendor = {line.split('#')[0].strip() for line in
              (ROOT / 'packaging/appimage/excludelist').read_text().splitlines()
              if line.split('#')[0].strip()}
    # Ubuntu's libmpv/libavdevice link JACK even for ordinary playback. JACK
    # is optional on KDE/Fedora, so bundle its client instead of requiring users
    # to install a music-production backend just to open the application.
    return (vendor | {'libGLESv2.so.2', 'libvulkan.so.1'}) - {'libjack.so.0'}


def elf(path):
    with path.open('rb') as stream:
        return stream.read(4) == b'\x7fELF'


def dependencies(path, env=None):
    listing = capture(['ldd', path], env=env)
    if 'not found' in listing or 'version `' in listing:
        raise ValueError(f'Unresolved dependencies for {path}: {listing}')
    return {name: Path(target) for name, target in
            re.findall(r'^\s*(\S+) => (/\S+)', listing, re.M)}


def provenance(name, source, notices):
    source = source.resolve()
    # Handle merged-/usr packages whose recorded path differs from realpath.
    candidates = [source]
    if str(source).startswith('/usr/lib/'):
        candidates.append(Path(str(source).removeprefix('/usr')))
    owner = None
    for candidate in candidates:
        result = subprocess.run(['dpkg-query', '-S', str(candidate)], capture_output=True, text=True)
        if result.returncode == 0:
            owner = result.stdout.splitlines()[0].split(': ')[0]
            break
    if owner is None:
        raise ValueError(f'No distribution provenance for {source}')
    doc = Path('/usr/share/doc') / owner.split(':')[0] / 'copyright'
    if not doc.is_file():
        raise ValueError(f'No copyright notice for {owner}')
    shutil.copy2(doc, notices / (owner.replace(':', '_') + '.copyright'))
    version = capture(['dpkg-query', '-W', '-f=${Version}', owner])
    source_package = capture(['dpkg-query', '-W', '-f=${source:Package}', owner])
    source_version = capture(['dpkg-query', '-W', '-f=${source:Version}', owner])
    return {'library': name, 'package': owner, 'version': version,
            'sourcePackage': source_package, 'sourceVersion': source_version,
            'sourceUrl': f'https://launchpad.net/ubuntu/+source/{source_package}/{source_version}',
            'sha256': digest(source)}


def prepare_media():
    """Separate release preparation; never change the Ubuntu 26 development pins."""
    os_release = Path('/etc/os-release').read_text()
    if 'VERSION_ID="24.04"' not in os_release or capture(['dpkg', '--print-architecture']) != 'amd64':
        raise ValueError('AppImage media preparation requires Ubuntu 24.04 amd64')
    folder = ROOT / '.local/media-linux/bundle'
    if folder.exists():
        raise ValueError('Refusing to reuse media preparation from another build')
    libs, notices = folder / 'libs', folder / 'notices'
    libs.mkdir(parents=True)
    notices.mkdir()
    mpv = Path('/usr/lib/x86_64-linux-gnu/libmpv.so.2')
    sources = {'libmpv.so.2': mpv, **dependencies(mpv)}
    rows = []
    for name, path in sorted(sources.items()):
        if name in exclusions():
            continue
        rows.append(provenance(name, path, notices))
        shutil.copy2(path.resolve(), libs / name)
    (notices / 'manifest.json').write_text(json.dumps({
        'platform': 'Ubuntu 24.04 amd64 AppImage build; host glibc and device drivers',
        'libraries': rows, 'packages': [],
        'sourcePackages': 'Exact source package names, versions, SHA-256 and distribution copyright notices accompany every bundled library.'}, indent=2) + '\n')
    print(f'Prepared {len(rows)} Ubuntu 24.04 media libraries with provenance')


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
    work = stage.parent / 'appimage'
    appdir = work / 'Raft.AppDir'
    appdir.mkdir(parents=True)
    shutil.move(str(stage), appdir / 'raft')
    stage = appdir / 'raft'
    (stage / 'RUN.txt').unlink()
    if EXECUTABLE != BASE_EXECUTABLE:
        (stage / BASE_EXECUTABLE).rename(stage / EXECUTABLE)
    notices = stage / 'data/notices/raft-media'
    manifest_path = notices / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    records = {row['library']: row for row in manifest['libraries']}
    host_libraries = set()
    # Discard all device/base libraries even when a media dependency pulled them in.
    for path in (stage / 'lib').iterdir():
        if path.name in exclusions():
            path.unlink()
            records.pop(path.name, None)
            host_libraries.add(path.name)
    helpers = stage / 'bin'
    helpers.mkdir()
    commands = []
    for name in ('pdfinfo', 'pdftoppm', 'gio-launch-desktop'):
        # Bundled GLib otherwise calls its Ubuntu build-time libexec path,
        # which does not exist on Fedora/KDE. Its tiny launch helper uses libc
        # only, so ship the matching distribution helper with provenance.
        source = (Path('/usr/lib/x86_64-linux-gnu/glib-2.0/gio-launch-desktop')
                  if name == 'gio-launch-desktop' else Path(shutil.which(name) or ''))
        if not source.is_file() or not os.access(source, os.X_OK):
            raise ValueError(f'Missing desktop/PDF helper {name}')
        row = provenance(name, source, notices)
        row['name'] = row.pop('library')
        commands.append(row)
        shutil.copy2(source, helpers / name)
    loader_dir = Path('/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders')
    loaders = sorted(loader_dir.glob('libpixbufloader-*.so'))
    if not any(path.name == 'libpixbufloader-svg.so' for path in loaders):
        raise ValueError('Missing matching GdkPixbuf SVG loader')
    for source in loaders:
        records[source.name] = provenance(source.name, source, notices)
        shutil.copy2(source, stage / 'lib' / source.name)
    cache_text = capture(['/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders', *loaders])
    (stage / 'lib/loaders.cache').write_text(image_loader_cache(cache_text, loaders))
    env = {key: value for key, value in os.environ.items() if key not in {'LD_LIBRARY_PATH', 'LD_PRELOAD'}}
    files = [path for path in stage.rglob('*') if path.is_file() and elf(path)]
    # ldd resolves the recursive closure, including GTK and Secret Service plugins.
    for executable in files:
        for name, path in dependencies(executable, env=env).items():
            if name in exclusions():
                host_libraries.add(name)
                continue
            target = stage / 'lib' / name
            if not target.exists():
                records[name] = provenance(name, path, notices)
                shutil.copy2(path.resolve(), target)
    fallback = stage / 'lib-fallback'
    fallback.mkdir()
    for name in LIBVA_LIBRARIES:
        if (stage / 'lib' / name).exists():
            shutil.move(str(stage / 'lib' / name), fallback / name)
    # Avoid loading host GIO modules into the bundled GLib ABI.
    (stage / 'lib/gio/modules').mkdir(parents=True)
    schemas = appdir / 'usr/share/glib-2.0/schemas'
    schemas.mkdir(parents=True)
    shutil.copy2('/usr/share/glib-2.0/schemas/gschemas.compiled', schemas)
    if Path('/usr/share/poppler').is_dir():
        shutil.copytree('/usr/share/poppler', appdir / 'usr/share/poppler', symlinks=False)
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
        base_metainfo.replace(BASE_APP_ID, APP_ID).replace(
            '<name>Raft</name>', '<name>Raft (isolated build)</name>')
        if APP_ID_SUFFIX else base_metainfo)
    launcher = appdir / 'AppRun'
    launcher.write_text('''#!/bin/sh
set -eu
app_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
''' + host_environment_capture() + input_method_cache_setup() + host_libva_check() + isolated_directory_setup(APP_ID, APP_ID_SUFFIX) + '''export PATH="$app_dir/raft/bin:$PATH"
export LD_LIBRARY_PATH="$app_dir/raft/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [ "$host_libva" = 0 ]; then
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$app_dir/raft/lib-fallback"
fi
export GIO_MODULE_DIR="$app_dir/raft/lib/gio/modules"
export GSETTINGS_SCHEMA_DIR="$app_dir/usr/share/glib-2.0/schemas"
export GIO_LAUNCH_DESKTOP="$app_dir/raft/bin/raft-gio-launch-desktop"
export GDK_PIXBUF_MODULE_FILE="$app_dir/raft/lib/loaders.cache"
exec "$app_dir/raft/''' + EXECUTABLE + '''" "$@"
''')
    launcher.chmod(0o755)
    desktop_wrapper = helpers / 'raft-gio-launch-desktop'
    desktop_wrapper.write_text(desktop_launcher_wrapper())
    desktop_wrapper.chmod(0o755)
    files = [path for path in stage.rglob('*') if path.is_file() and elf(path)]
    needed_glibc = (0, 0)
    for path in files:
        rpath = '$ORIGIN/../lib' if path.parent == helpers else '$ORIGIN/lib' if path.name == EXECUTABLE else '$ORIGIN'
        run(['patchelf', '--force-rpath', '--set-rpath', rpath, path])
        needed_glibc = max(needed_glibc, glibc_requirement(capture_output(['readelf', '--version-info', path])))
        dependencies(path, env=env)
    for row in records.values():
        row.setdefault('preparedSha256', row['sha256'])
        placed = stage / 'lib-fallback' if row['library'] in LIBVA_LIBRARIES else stage / 'lib'
        row['sha256'] = file_digest(placed / row['library'])
    for row in commands:
        row['sha256'] = file_digest(helpers / row['name'])
    manifest.update(libraries=sorted(records.values(), key=lambda row: row['library']),
                    commands=commands, imageLoaderModules=[path.name for path in loaders],
                    hostProvidedLibraries=sorted(host_libraries))
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    tools = json.loads((root / 'packaging/appimage/tools.json').read_text())
    tool_notices = stage / 'data/notices/appimage-runtime'
    tool_notices.mkdir()
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
    # With zsyncmake installed appimagetool also writes <artifact>.zsync into its
    # working directory; run it in the scratch folder so no stray file lands in
    # the checkout (release.py makes the published .zsync itself).
    run([*command, appdir, artifact], env=dict(env, ARCH='x86_64'), cwd=work)
    artifact.chmod(0o755)
    return {'runtime': tools['runtime'], 'appimagetool': tools['appimagetool'],
            'buildSystem': 'Ubuntu 24.04 x86_64',
            'maximumGlibcRequired': '.'.join(map(str, needed_glibc)),
            'elfFilesChecked': len(files), 'hostProvidedLibraries': sorted(host_libraries),
            'pdfHelpers': ['pdfinfo', 'pdftoppm'],
            'imageLoaderModules': [path.name for path in loaders],
            'updateInformation': information or None,
            'desktopLauncher': 'raft-gio-launch-desktop (bundled helper, restored host environment)',
            'launchModes': ['direct (static FUSE 3 library)', '--appimage-extract-and-run (no FUSE)']}
