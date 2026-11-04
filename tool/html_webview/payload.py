"""Pin, restore and verify a locally built WPE SDK; never download or install it."""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import tarfile

from .prepare_source import ARCHIVE_SHA256, HERE, VERSION, sha256

MANIFEST = 'share/raft-html-webview/payload.json'
PACKAGED = 'share/raft-html-webview/packaged-runtime.json'
METADATA = 'share/raft-html-webview'
MAX_BYTES = 4 * 1024**3
MAX_ENTRIES = 30000
GIO_LAUNCHER = 'libexec/raft-html-webview/gio-launch-desktop'
GST_SCANNER = 'libexec/gstreamer-1.0/gst-plugin-scanner'
GST_CORE = 'lib/gstreamer-1.0/libgstcoreelements.so'
LAUNCH_VARIABLES = ('GST_PLUGIN_SYSTEM_PATH_1_0', 'GST_PLUGIN_PATH_1_0',
                    'GST_PLUGIN_SCANNER_1_0', 'GST_REGISTRY_1_0',
                    'GST_PLUGIN_SCANNER', 'GST_REGISTRY')
RUNTIME = (
    'lib/libWPEWebKit-2.0.so.1',
    'lib/wpe-webkit-2.0/injected-bundle/libWPEInjectedBundle.so',
    'libexec/wpe-webkit-2.0/WPEWebProcess',
    'libexec/wpe-webkit-2.0/WPENetworkProcess',
    'libexec/wpe-webkit-2.0/WPEGPUProcess',
    'libexec/raft-html-webview/xdg-dbus-proxy',
    'lib/gio/modules/libgiognutls.so', 'lib/gio/modules/giomodule.cache',
    f'{METADATA}/runtime.marker', f'{METADATA}/source-inputs.json',
    f'{METADATA}/cmakeconfig.h', f'{METADATA}/packages.json',
    GIO_LAUNCHER, GST_SCANNER, GST_CORE,
)
NATIVE_ROLES = (*RUNTIME[:7], GIO_LAUNCHER, GST_SCANNER, GST_CORE)
PKG_CONFIG = ('wpe-webkit-2.0', 'wpe-platform-2.0', 'wpe-platform-headless-2.0', 'wpe-1.0')
FALLBACKS = {'lib/' + name: 'lib-fallback/' + name for name in
             ('libva.so.2', 'libva-drm.so.2', 'libva-x11.so.2', 'libva-wayland.so.2')}


def identity():
    return {'engine': 'wpewebkit', 'version': VERSION, 'arch': 'x86_64',
            'sourceSha256': ARCHIVE_SHA256,
            'patchSha256': sha256(HERE / 'wpe-relocation.patch'),
            'headerSha256': sha256(HERE / 'raft_wpe_runtime_paths.h'),
            'buildOrderPatchSha256': sha256(HERE / 'wpe-build-order.patch'),
            'networkDataPatchSha256': sha256(HERE / 'wpe-network-data-order.patch')}


def relative_path(value):
    parts = PurePosixPath(value).parts
    if (not value or value.startswith('/') or any(p in {'.', '..'} for p in value.split('/'))
            or '//' in value or '\\' in value or not parts):
        raise ValueError(f'Unsafe payload path: {value}')
    return Path(*parts)


def inventory(prefix):
    prefix = Path(prefix).resolve()
    result = {}
    host_libraries = {line.split('#')[0].strip() for line in
                      (HERE.parents[1] / 'packaging/appimage/excludelist').read_text().splitlines()
                      if line.split('#')[0].strip()}
    host_libraries = (host_libraries | {'libGLESv2.so.2', 'libvulkan.so.1'}) - {'libjack.so.0'}
    host_stems = {name.split('.so', 1)[0] for name in host_libraries}
    for path in sorted(prefix.rglob('*')):
        relative = path.relative_to(prefix).as_posix()
        if relative == MANIFEST:
            continue
        if (path.name == 'bwrap' or ('.so' in path.name and path.name.split('.so', 1)[0] in host_stems)
                or re.search(r'(?:_dri\.so|^libvulkan_|^lib.*nvidia|^lib(?:EGL|GLX)_mesa)', path.name)):
            raise ValueError(f'System sandbox/base library must not be bundled: {relative}')
        mode = path.lstat().st_mode
        if stat.S_ISLNK(mode):
            target = os.readlink(path)
            if (Path(target).is_absolute() or not path.resolve().is_relative_to(prefix)
                    or not path.resolve().is_file()):
                raise ValueError(f'Nonrelocatable payload symlink: {relative}')
            result[relative] = {'link': target}
        elif stat.S_ISDIR(mode):
            continue
        elif stat.S_ISREG(mode) and not mode & 0o6022:
            result[relative] = {'sha256': sha256(path), 'size': path.stat().st_size,
                                'mode': stat.S_IMODE(mode)}
        else:
            raise ValueError(f'Unsafe payload file type/permissions: {relative}')
    if len(result) > MAX_ENTRIES or sum(v.get('size', 0) for v in result.values()) > MAX_BYTES:
        raise ValueError('Payload exceeds the reviewed archive limits')
    return result


def check_layout(prefix):
    prefix = Path(prefix)
    expected = identity()
    if (prefix / PACKAGED).exists():
        raise ValueError('A reusable SDK must not contain a mutated runtime receipt')
    for relative in RUNTIME:
        if not (prefix / relative).is_file():
            raise ValueError(f'Incomplete HTML runtime: {relative}')
    for relative in NATIVE_ROLES:
        with (prefix / relative).open('rb') as stream:
            if stream.read(4) != b'\x7fELF':
                raise ValueError(f'HTML runtime role is not an ELF binary: {relative}')
        if relative.startswith('libexec/') and not os.access(prefix / relative, os.X_OK):
            raise ValueError(f'HTML runtime helper is not executable: {relative}')
    inputs = json.loads((prefix / METADATA / 'source-inputs.json').read_text())
    if any(inputs.get(k) != v for k, v in expected.items() if k != 'arch'):
        raise ValueError('HTML runtime source/adapter inputs differ from the reviewed pin')
    marker = ('raft-html-wpe-runtime-v1\n' + f'wpewebkit={VERSION}\n'
              f'source-sha256={ARCHIVE_SHA256}\nrelocation=raft-v1\narch=x86_64\n')
    marker_path = prefix / METADATA / 'runtime.marker'
    if marker_path.is_symlink() or marker_path.read_text() != marker:
        raise ValueError('HTML runtime identity marker changed')
    config = (prefix / METADATA / 'cmakeconfig.h').read_text()
    for key, value in [('ENABLE_BUBBLEWRAP_SANDBOX', 1), ('ENABLE_DEVELOPER_MODE', 0),
                       ('ENABLE_GPU_PROCESS', 1), ('ENABLE_WPE_PLATFORM_HEADLESS', 1)]:
        if not re.search(rf'^#define {key} {value}$', config, re.M):
            raise ValueError(f'HTML runtime configuration must keep {key}={value}')
    for name in PKG_CONFIG:
        pc = prefix / 'lib/pkgconfig' / (name + '.pc')
        required = {'prefix=${pcfiledir}/../..', 'libdir=${prefix}/lib', 'includedir=${prefix}/include'}
        if not pc.is_file() or not required.issubset(set(pc.read_text().splitlines())):
            raise ValueError(f'Nonrelocatable/missing SDK pkg-config: {name}')
    if 'libgiognutls.so:' not in (prefix / 'lib/gio/modules/giomodule.cache').read_text():
        raise ValueError('GIO module cache does not register the packaged TLS backend')
    if not any((prefix / 'include').rglob('*.h')):
        raise ValueError('Missing SDK headers')
    if not any((prefix / METADATA / 'licenses').rglob('*')):
        raise ValueError('Missing source and package copyright notices')
    provenance = json.loads((prefix / METADATA / 'packages.json').read_text())
    covered = set()
    engine_source_found = False
    for artifact in provenance.get('artifacts', []):
        if (not artifact.get('name') or not artifact.get('version')
                or not re.fullmatch('[0-9a-f]{64}', artifact.get('sha256', ''))
                or not artifact.get('url', '').startswith('https://')):
            raise ValueError('Incomplete source/package provenance')
        notice = relative_path(artifact.get('notice', ''))
        if not str(notice).startswith(METADATA + '/licenses/') or not (prefix / notice).is_file():
            raise ValueError('Missing artifact copyright notice')
        for name in artifact.get('files', []):
            if name in covered or not (prefix / relative_path(name)).is_file():
                raise ValueError('Duplicate or missing artifact provenance path')
            covered.add(name)
        if (artifact['name'] == 'wpewebkit' and artifact['version'] == VERSION
                and artifact['sha256'] == ARCHIVE_SHA256):
            engine_source_found = set(RUNTIME[:5]).issubset(set(artifact.get('files', [])))
    if not engine_source_found:
        raise ValueError('Missing reviewed WPE engine source provenance')
    for path in prefix.rglob('*'):
        if path.is_file() and not path.is_symlink():
            with path.open('rb') as stream:
                if stream.read(4) == b'\x7fELF' and path.relative_to(prefix).as_posix() not in covered:
                    raise ValueError('ELF payload has no source/package provenance')


def inspect_elf(prefix):
    maximum = (0, 0)
    for path in Path(prefix).rglob('*'):
        if not path.is_file() or path.is_symlink():
            continue
        with path.open('rb') as stream:
            if stream.read(4) != b'\x7fELF':
                continue
        text = subprocess.check_output(['readelf', '--file-header', '--version-info', str(path)],
                                       text=True, env={**os.environ, 'LC_ALL': 'C'})
        if (not re.search(r'^\s*Machine:\s+Advanced Micro Devices X86-64\s*$', text, re.M)
                or not re.search(r'^\s*Class:\s+ELF64\s*$', text, re.M)):
            raise ValueError('HTML runtime binary is not the reviewed x86_64 architecture')
        versions = [tuple(map(int, v.split('.'))) for v in
                    re.findall(r'Name: GLIBC_([0-9]+\.[0-9]+(?:\.[0-9]+)?)', text)]
        maximum = max(maximum, max(versions, default=(0, 0)))
    if maximum > (2, 39):
        raise ValueError('HTML runtime exceeds the Ubuntu 24.04 GLIBC 2.39 ceiling')
    return '.'.join(map(str, maximum))


def seal(prefix):
    """Make a content manifest after staging; this does not approve native QA."""
    prefix = Path(prefix)
    manifest = prefix / MANIFEST
    if os.path.lexists(manifest):
        raise ValueError('Refusing to replace a previous payload manifest')
    files = inventory(prefix)
    check_layout(prefix)
    record = {'format': 1, 'identity': identity(), 'files': files,
              'maximumGlibcRequired': inspect_elf(prefix)}
    manifest.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    return sha256(manifest)


def verify(prefix, manifest_sha256):
    prefix = Path(prefix)
    manifest = prefix / MANIFEST
    if (not re.fullmatch('[0-9a-f]{64}', manifest_sha256 or '') or manifest.is_symlink()
            or sha256(manifest) != manifest_sha256):
        raise ValueError('HTML payload manifest SHA-256 differs from the reviewed pin')
    record = json.loads(manifest.read_text())
    if record.get('format') != 1 or record.get('identity') != identity():
        raise ValueError('HTML payload identity differs from the reviewed pin')
    if inventory(prefix) != record['files']:
        raise ValueError('HTML payload files/permissions differ from the pinned manifest')
    check_layout(prefix)
    return record


def restore(archive, archive_sha256, destination):
    """Restore only a pinned, bounded archive into a new directory; keep failures."""
    archive, destination = Path(archive), Path(destination)
    if not re.fullmatch('[0-9a-f]{64}', archive_sha256 or '') or sha256(archive) != archive_sha256:
        raise ValueError('HTML payload archive SHA-256 differs from the reviewed pin')
    if os.path.lexists(destination):
        raise ValueError('Use a new SDK destination; previous work/failures are retained')
    with tarfile.open(archive) as tar:
        members, names, total_bytes = [], set(), 0
        for member in tar:
            relative_path(member.name)
            if member.name in names or not (member.isfile() or member.isdir() or member.issym()):
                raise ValueError('Duplicate or unsafe SDK archive entry')
            if member.mode & 0o6000 or member.size < 0:
                raise ValueError('Setuid/setgid SDK archive entry is forbidden')
            names.add(member.name)
            members.append(member)
            total_bytes += member.size
            if len(members) > MAX_ENTRIES or total_bytes > MAX_BYTES:
                raise ValueError('SDK archive exceeds the reviewed limits')
        destination.mkdir(parents=True)
        tar.extractall(destination, members=members, filter='data')
    # The archive's caller-supplied pin authenticates this embedded manifest.
    pin = sha256(destination / MANIFEST)
    verify(destination, pin)
    return pin


def merge_runtime(prefix, stage, manifest_sha256):
    """Copy runtime only; reject byte collisions with media/plugin libraries."""
    prefix, stage = Path(prefix), Path(stage)
    record = verify(prefix, manifest_sha256)
    placed = []
    for relative in record['files']:
        if relative.startswith(('include/', 'lib/pkgconfig/')) or relative.endswith('.a'):
            continue
        source, target = prefix / relative_path(relative), stage / relative_path(relative)
        placed.append(relative)
        original = record['files'].get(source.resolve().relative_to(prefix.resolve()).as_posix(), {})
        expected = original.get('sha256')
        if not expected or not target.parent.resolve().is_relative_to(stage.resolve()):
            raise ValueError(f'Invalid HTML runtime source/destination: {relative}')
        target.parent.mkdir(parents=True, exist_ok=True)
        if os.path.lexists(target):
            if target.is_symlink() or not target.is_file() or sha256(target) != expected:
                raise ValueError(f'HTML runtime collides with an existing bundle file: {relative}')
            continue
        # Materialize SDK library symlinks so later ELF patching cannot mutate the SDK.
        shutil.copy2(source.resolve(), target)
        if sha256(target) != expected:
            raise ValueError(f'HTML runtime changed while copying: {relative}')
    target = stage / MANIFEST
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(prefix / MANIFEST, target)
    return {'manifestSha256': manifest_sha256, 'identity': record['identity'],
            'maximumGlibcRequired': record['maximumGlibcRequired'], 'paths': placed}


def placed_files(stage, paths, relocations):
    if any(name not in paths or FALLBACKS.get(name) != target for name, target in relocations.items()):
        raise ValueError('HTML runtime relocation must use the reviewed host-VA fallback paths')
    return {relocations.get(name, name): sha256(Path(stage) / relative_path(relocations.get(name, name)))
            for name in paths}


def record_packaged(stage, record, relocations=None):
    if record is None:
        return
    if sha256(Path(stage) / MANIFEST) != record['manifestSha256']:
        raise ValueError('Packaged HTML source manifest changed')
    result = dict(record)
    result['relocations'] = {**record.get('relocations', {}), **(relocations or {})}
    result['files'] = placed_files(stage, record['paths'], result['relocations'])
    (Path(stage) / PACKAGED).write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')


def optional_runtime(stage, environ=os.environ):
    prefix, pin = environ.get('RAFT_HTML_WEBVIEW_SDK', ''), environ.get('RAFT_HTML_WEBVIEW_MANIFEST_SHA256', '')
    if not prefix and not pin:
        if (Path(stage) / PACKAGED).exists():
            raise ValueError('Packaged HTML runtime requires its reviewed SDK/manifest pin')
        return None
    if not prefix or not pin:
        raise ValueError('Set both RAFT_HTML_WEBVIEW_SDK and RAFT_HTML_WEBVIEW_MANIFEST_SHA256')
    packaged = Path(stage) / PACKAGED
    if packaged.exists():
        source = verify(prefix, pin)
        record = json.loads(packaged.read_text())
        expected_paths = [name for name in source['files']
                          if not name.startswith(('include/', 'lib/pkgconfig/')) and not name.endswith('.a')]
        if (record.get('manifestSha256') != pin or record.get('identity') != source['identity']
                or sha256(Path(stage) / MANIFEST) != pin
                or record.get('paths') != expected_paths
                or record.get('files') != placed_files(stage, expected_paths, record.get('relocations', {}))):
            raise ValueError('Previously packaged HTML runtime differs from its receipt')
        return record
    return merge_runtime(prefix, stage, pin)


def relative_rpath(path, stage):
    relative = os.path.relpath(Path(stage) / 'lib', Path(path).parent)
    return '$ORIGIN' if relative == '.' else '$ORIGIN/' + Path(relative).as_posix()


def launch_environment(prefix, manifest_sha256):
    """Closed plugin paths; a registry scoped to this pinned SDK, not host state."""
    if prefix not in {'$app_dir', '$app_dir/raft'} or not re.fullmatch('[0-9a-f]{64}', manifest_sha256):
        raise ValueError('Use a fixed relative launcher prefix and reviewed manifest hash')
    return (f'export GIO_MODULE_DIR="{prefix}/lib/gio/modules"\n'
            f'export GST_PLUGIN_SYSTEM_PATH_1_0="{prefix}/lib/gstreamer-1.0"\n'
            'export GST_PLUGIN_PATH_1_0=""\n'
            f'export GST_PLUGIN_SCANNER_1_0="{prefix}/{GST_SCANNER}"\n'
            'export GST_PLUGIN_SCANNER="$GST_PLUGIN_SCANNER_1_0"\n'
            f'registry_dir="${{XDG_CACHE_HOME:-$HOME/.cache}}/raft-html-runtime/{manifest_sha256}"\n'
            'mkdir -p "$registry_dir"\n'
            'export GST_REGISTRY_1_0="$registry_dir/gstreamer-registry.bin"\n'
            'export GST_REGISTRY="$GST_REGISTRY_1_0"\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('seal', 'verify'):
        item = sub.add_parser(name)
        item.add_argument('--prefix', type=Path, required=True)
        if name == 'verify':
            item.add_argument('--manifest-sha256', required=True)
    item = sub.add_parser('restore')
    item.add_argument('--archive', type=Path, required=True)
    item.add_argument('--sha256', required=True)
    item.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'seal':
        print(seal(args.prefix))
    elif args.command == 'verify':
        print(json.dumps(verify(args.prefix, args.manifest_sha256)['identity'], indent=2))
    else:
        print(restore(args.archive, args.sha256, args.destination))


if __name__ == '__main__':
    main()
