"""Stage a complete SDK from one builder's raw install and authenticated private archives."""
from pathlib import Path
import gzip
import json
import os
import re
import shutil
import stat
import subprocess
import tarfile

from . import payload
from .archives import Store, authenticate
from .prepare_source import ARCHIVE_SHA256, sha256


def readelf(path):
    text = subprocess.check_output(['readelf', '--dynamic', str(path)], text=True, timeout=15)
    return (re.findall(r'\(NEEDED\).*\[(.*?)\]', text),
            re.findall(r'\(SONAME\).*\[(.*?)\]', text))


def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if os.path.lexists(target):
        if target.is_symlink() or not target.is_file() or sha256(source) != sha256(target):
            raise ValueError('Conflicting SDK file: ' + str(target))
    else:
        shutil.copy2(source, target)


def package_owner(path):
    for candidate in [str(path), str(path).replace('/usr/lib/', '/lib/', 1)]:
        result = subprocess.run(['dpkg-query', '-S', candidate], capture_output=True, text=True, timeout=15)
        owners = {line.rsplit(': ', 1)[0] for line in result.stdout.splitlines()
                  if ': ' in line and line.rsplit(': ', 1)[1] == candidate}
        if len(owners) == 1:
            return next(iter(owners))
    raise ValueError('No unique installed package owner for ' + str(path))


def dependency_paths():
    text = subprocess.check_output(['/sbin/ldconfig', '-p'], text=True, timeout=15)
    result = {}
    for line in text.splitlines():
        match = re.match(r'\s*(\S+) \([^)]*x86-64[^)]*\) => (\S+)', line)
        if match:
            result.setdefault(match[1], Path(match[2]).resolve())
    return result


def is_elf(path):
    if not path.is_file() or path.is_symlink():
        return False
    with path.open('rb') as stream:
        return stream.read(4) == b'\x7fELF'



def archive_sdk(prefix, destination):
    """Write deterministic archive metadata without exposing the build user's identity."""
    def normalized(member):
        member.uid = member.gid = 0
        member.uname = member.gname = ''
        member.mtime = 0
        member.pax_headers = {}
        return member
    with Path(destination).open('xb') as output:
        with gzip.GzipFile(fileobj=output, mode='wb', filename='', mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w') as tar:
                for file in sorted(Path(prefix).iterdir()):
                    tar.add(file, arcname=file.name, recursive=True, filter=normalized)


def stage(raw, source, build, prefix, workspace, cache, build_identity, archive):
    """No network, package installation or host fallback is permitted during staging."""
    raw, source, build, prefix, workspace, cache = map(Path, (raw, source, build, prefix, workspace, cache))
    if any(os.path.lexists(p) for p in [prefix, workspace, Path(archive)]):
        raise ValueError('Use new SDK, archive and staging-work paths; retain every failed attempt')
    workspace.mkdir(parents=True)
    packages, proofs = authenticate()
    store = Store(cache, workspace / 'packages', packages, proofs)
    shutil.copytree(raw, prefix, symlinks=True)
    payload.inventory(prefix)  # Validate raw links/permissions before writing through this tree.
    meta = prefix / payload.METADATA
    licenses = meta / 'licenses'
    licenses.mkdir(parents=True)
    excluded = {line.split('#')[0].strip() for line in
                (payload.HERE.parents[1] / 'packaging/appimage/excludelist').read_text().splitlines()
                if line.split('#')[0].strip()}
    excluded = (excluded | {'libGLESv2.so.2', 'libvulkan.so.1'}) - {'libjack.so.0'}
    installed = dependency_paths()
    installed['libWPEWebKit-2.0.so.1'] = (prefix / 'lib/libWPEWebKit-2.0.so.1').resolve()
    foreign = ('libwpe-1.0-1', '1.16.3-2', 'amd64')
    foreign_path = store.file(foreign, 'usr/lib/x86_64-linux-gnu/libwpe-1.0.so.1.9.6')
    installed['libwpe-1.0.so.1'] = foreign_path
    roots = [(prefix / name).resolve() for name in payload.RUNTIME[:5]]
    helpers = {
        '/usr/bin/xdg-dbus-proxy': 'libexec/raft-html-webview/xdg-dbus-proxy',
        '/usr/lib/x86_64-linux-gnu/glib-2.0/gio-launch-desktop': payload.GIO_LAUNCHER,
        '/usr/lib/x86_64-linux-gnu/gio/modules/libgiognutls.so': 'lib/gio/modules/libgiognutls.so',
        '/usr/lib/x86_64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner': payload.GST_SCANNER,
        '/usr/lib/x86_64-linux-gnu/gstreamer-1.0/libgstcoreelements.so': payload.GST_CORE,
    }
    destinations = {Path(k).resolve(): v for k, v in helpers.items()}
    roots += [*destinations, foreign_path]
    todo, seen, records, file_records = roots[:], set(), {}, []

    def artifact(key):
        if key not in records:
            item = {k: v for k, v in store.records[key].items() if k != 'archive'}
            notice = store.notice(key)
            target = licenses / 'packages' / (key[0] + '.copyright')
            copy(notice, target)
            item.update(notice=target.relative_to(prefix).as_posix(), files=[])
            records[key] = item
        return records[key]

    while todo:
        path = Path(todo.pop()).resolve()
        if path in seen:
            continue
        seen.add(path)
        if not path.is_file():
            raise ValueError('Required runtime file missing: ' + str(path))
        needed, sonames = readelf(path)
        if not path.is_relative_to(prefix):
            if path == foreign_path:
                key, original = foreign, path
            else:
                key = store.installed_key(package_owner(path))
                original = store.file(key, str(path).lstrip('/'))
                if sha256(original) != sha256(path):
                    raise ValueError('Installed runtime differs from its authenticated package: ' + str(path))
            if path in destinations:
                relative = destinations[path]
            elif len(sonames) == 1:
                relative = 'lib/' + sonames[0]
            else:
                raise ValueError('Dependency has no unique contained runtime location')
            payload.relative_path(relative)
            copy(original, prefix / relative)
            artifact(key)['files'].append(relative)
            file_records.append({'path': relative, 'pristineSha256': sha256(original),
                                 'buildPackageVersion': key[1], 'runtimePackageVersion': key[1]})
        for dependency in needed:
            if dependency not in excluded:
                if dependency not in installed:
                    raise ValueError('Unresolved runtime dependency: ' + dependency)
                todo.append(installed[dependency])
    # libwpe is extracted, never installed over Ubuntu; include its SDK headers/linker alias.
    development = ('libwpe-1.0-dev', '1.16.3-2', 'amd64')
    tree = store.extract(development)
    for file in (tree / 'usr/include').rglob('*'):
        if file.is_file():
            copy(file, prefix / 'include' / file.relative_to(tree / 'usr/include'))
    copy(tree / 'usr/lib/x86_64-linux-gnu/pkgconfig/wpe-1.0.pc', prefix / 'lib/pkgconfig/wpe-1.0.pc')
    (prefix / 'lib/libwpe-1.0.so').symlink_to('libwpe-1.0.so.1')
    for file in (prefix / 'lib/pkgconfig').glob('*.pc'):
        text = file.read_text()
        for name, value in [('prefix', '${pcfiledir}/../..'), ('libdir', '${prefix}/lib'),
                            ('includedir', '${prefix}/include'), ('moduledir', '${libdir}/wpe-platform-2.0/modules')]:
            text = re.sub(rf'^{name}=.*$', name + '=' + value, text, flags=re.M)
        file.write_text(text)
    source_notices = []
    for file in sorted((source / 'Source').rglob('*')):
        if file.is_file() and re.match(r'(?i)^(?:LICENSE|COPYING|NOTICE|COPYRIGHT)(?:$|[-_.])', file.name):
            target = licenses / 'wpewebkit' / file.relative_to(source)
            copy(file, target)
            source_notices.append({'path': file.relative_to(source).as_posix(), 'sha256': sha256(file)})
    if not source_notices:
        raise ValueError('No upstream source notices found')
    base = store.installed_key('base-files')
    common = store.extract(base) / 'usr/share/common-licenses'
    common_files = []
    for file in common.iterdir():
        if file.is_file():
            if not file.resolve().is_relative_to(store.extract(base)):
                raise ValueError('Common license leaves its authenticated archive')
            target = licenses / 'common-licenses' / file.name
            copy(file, target)
            common_files.append(target.relative_to(prefix).as_posix())
    artifact(base)['files'].extend(common_files)
    # Static libbacktrace's exact compiler archive and notice remain explicit too.
    artifact(store.installed_key('libgcc-13-dev'))
    copy(source.parent / 'source-inputs.json', meta / 'source-inputs.json')
    copy(build / 'cmakeconfig.h', meta / 'cmakeconfig.h')
    marker = ('raft-html-wpe-runtime-v1\nwpewebkit=2.54.2\nsource-sha256=' + ARCHIVE_SHA256
              + '\nrelocation=raft-v1\narch=x86_64\n')
    (meta / 'runtime.marker').write_text(marker)
    elfs = [file for file in prefix.rglob('*') if is_elf(file)]
    for file in elfs:
        subprocess.run(['patchelf', '--force-rpath', '--set-rpath', payload.relative_rpath(file, prefix), str(file)],
                       check=True, capture_output=True, timeout=30)
    subprocess.run(['/usr/lib/x86_64-linux-gnu/glib-2.0/gio-querymodules', str(prefix / 'lib/gio/modules')],
                   check=True, capture_output=True, timeout=30)
    covered = {name for record in records.values() for name in record['files']}
    engine_files = [file.relative_to(prefix).as_posix() for file in elfs
                    if file.relative_to(prefix).as_posix() not in covered]
    engine_files += [name for name in payload.RUNTIME[:5] if name not in engine_files]
    engine = {'name': 'wpewebkit', 'version': '2.54.2', 'sha256': ARCHIVE_SHA256,
              'url': 'https://wpewebkit.org/releases/wpewebkit-2.54.2.tar.xz',
              'notice': (licenses / 'wpewebkit/Source/WebCore/LICENSE-APPLE').relative_to(prefix).as_posix(),
              'files': engine_files, 'sourceNotices': source_notices}
    provided = {soname for file in elfs for soname in readelf(file)[1]}
    for file in elfs:
        missing = set(readelf(file)[0]) - provided - excluded
        if missing:
            raise ValueError('Unresolved staged ELF dependencies: ' + ','.join(sorted(missing)))
    for record in file_records:
        record['runtimeSha256'] = sha256(prefix / record['path'])
    (meta / 'packages.json').write_text(json.dumps({'artifacts': [engine, *records.values()],
                                                  'files': file_records, 'systemSonames': sorted(excluded)}, indent=2) + '\n')
    (meta / 'build-inputs.json').write_text(json.dumps(build_identity, indent=2) + '\n')
    (meta / 'apt-authentication.json').write_text(json.dumps(proofs, indent=2) + '\n')
    for file in prefix.rglob('*'):
        if file.is_file() and not file.is_symlink():
            file.chmod(stat.S_IMODE(file.stat().st_mode) & ~0o022)
    manifest = payload.seal(prefix)
    payload.verify(prefix, manifest)
    archive_sdk(prefix, archive)
    return {'state': 'sdk-ready', 'prefix': str(prefix), 'manifestSha256': manifest,
            'archive': str(archive), 'archiveSha256': sha256(archive), 'buildKey': build_identity['key'],
            'scope': 'Authenticated SDK closure/content/ELF floor only; native renderer acceptance not run'}
