#!/usr/bin/env python3
"""Restore a caller-pinned SDK or build and seal one in an isolated Noble container."""
import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

from . import payload
from .prepare_source import ARCHIVE_SHA256, HERE, prepare, sha256

TARGETS = ('WebKit', 'WebProcess', 'NetworkProcess', 'GPUProcess',
           'WPEInjectedBundle', 'InspectorResources')
REQUIRED_FEATURES = {'ENABLE_BUBBLEWRAP_SANDBOX': 1, 'ENABLE_DEVELOPER_MODE': 0,
                     'ENABLE_GPU_PROCESS': 1, 'ENABLE_WPE_PLATFORM_HEADLESS': 1,
                     'ENABLE_WPE_PLATFORM_WAYLAND': 1}
EXPECTED_CONFIG_SHA256 = '539903a29f5eba087a93539752a59cfecef2afa5ec7d16589dc8af00f27239cb'
BACKTRACE = {
    'include/backtrace.h': '6b12f37a587fc493295e87ee81824d9b43e64cfed1d4592114e43461e8e411be',
    'include/backtrace-supported.h': '6e429faa940f5f7e8165205c760ee4f719eb1fb1d962907c9098e84ed9e10961',
    'libbacktrace.a': '4f356ced4c57cbf863d843d19c0ebe1c74d95cf859c1bee36d93433613de8575',
}
CMAKE_OPTIONS = (
    '-DPORT=WPE', '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_INSTALL_PREFIX=/opt/raft-html-wpe',
    '-DCMAKE_C_COMPILER=clang-18', '-DCMAKE_CXX_COMPILER=clang++-18',
    '-DCMAKE_C_FLAGS_RELEASE=-O2 -DNDEBUG', '-DCMAKE_CXX_FLAGS_RELEASE=-O2 -DNDEBUG',
    '-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=/usr/bin/ld.lld-18',
    '-DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=/usr/bin/ld.lld-18',
    '-DENABLE_BUBBLEWRAP_SANDBOX=ON', '-DENABLE_WPE_PLATFORM=ON',
    '-DENABLE_WPE_PLATFORM_HEADLESS=ON', '-DENABLE_WPE_PLATFORM_WAYLAND=ON',
    '-DENABLE_WPE_PLATFORM_DRM=OFF', '-DENABLE_WPE_LEGACY_API=OFF', '-DENABLE_WPE_QT_API=OFF',
    '-DENABLE_DOCUMENTATION=OFF', '-DENABLE_INTROSPECTION=OFF', '-DENABLE_MINIBROWSER=OFF',
    '-DENABLE_API_TESTS=OFF', '-DENABLE_LAYOUT_TESTS=OFF', '-DENABLE_WEBDRIVER=OFF',
    '-DUSE_THIN_ARCHIVES=OFF',
)


def json_file(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def new_work(path):
    path = Path(path).absolute()
    if os.path.lexists(path):
        raise ValueError('Use a new work directory; previous work and failures are retained')
    path.mkdir(parents=True)
    return path


def image_id(value):
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', value or ''):
        raise ValueError('Use a verified local immutable Docker image ID, not a mutable tag')
    return value


def build_identity(environment):
    """Canonical cache identity; paths, timestamps and container names are excluded."""
    inputs = {**payload.identity(), 'environment': environment,
              'cmakeOptions': CMAKE_OPTIONS, 'configSha256': EXPECTED_CONFIG_SHA256,
              'backtrace': BACKTRACE, 'targets': TARGETS,
              'workerSha256': sha256(__file__), 'dockerfileSha256': sha256(HERE / 'Dockerfile'),
              'archiveVerifierSha256': sha256(HERE / 'archives.py'),
              'stagerSha256': sha256(HERE / 'stage.py'),
              'libwpePinsSha256': sha256(HERE / 'libwpe-pins.json'),
              'fetcherSha256': sha256(HERE / 'fetch_libwpe.py'),
              'buildResourceCheckSha256': sha256(HERE / 'build_resources.sh')}
    key = hashlib.sha256(json.dumps(inputs, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {**inputs, 'key': key}


def configure_command(source, build, backtrace):
    return ['cmake', '-S', str(source), '-B', str(build), '-G', 'Ninja', *CMAKE_OPTIONS,
            f'-DLIBBACKTRACE_INCLUDE_DIR={backtrace}',
            '-DLIBBACKTRACE_LIBRARY=/usr/lib/gcc/x86_64-linux-gnu/13/libbacktrace.a']


def install_command(build, destination):
    return (['cmake', '--install', str(build), '--config', 'Release'],
            {'DESTDIR': str(destination)})


def validate_config(text):
    for key, value in REQUIRED_FEATURES.items():
        if not re.search(rf'^#define {key} {value}$', text, re.M):
            raise ValueError(f'SDK build must keep {key}={value}')


def logged(work, name, command, seconds, env=None):
    record = {'command': [str(a) for a in command], 'started': time.time(), 'limitSeconds': seconds}
    try:
        with (Path(work) / (name + '.log')).open('wb') as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                                    env=env, timeout=seconds)
        record['exit'] = result.returncode
        result.check_returncode()
    except subprocess.TimeoutExpired:
        record['timedOut'] = True
        raise
    finally:
        record['finished'] = time.time()
        json_file(Path(work) / (name + '.json'), record)


def bind_mount(source, target, readonly=False):
    output = io.StringIO()
    fields = ['type=bind', 'source=' + str(Path(source).resolve()), 'target=' + target]
    if readonly:
        fields.append('readonly')
    csv.writer(output, lineterminator='').writerow(fields)
    return output.getvalue()


def container_command(image, work, name, uid, gid, archive=None):
    recipe = HERE.parents[1].resolve()
    command = ['docker', 'create', '--name', name, '--label=raft-html-sdk=source-build',
            '--cpus=2', '--memory=16g', '--memory-swap=16g', '--cpuset-cpus=0,1', '--network=none',
            f'--user={uid}:{gid}', '--env=PYTHONPATH=/recipe/tool',
            '--mount', bind_mount(work, '/work'),
            '--mount', bind_mount(recipe, '/recipe', readonly=True)]
    if archive is not None:
        command += ['--mount', bind_mount(archive, '/inputs/wpewebkit.tar.xz', readonly=True)]
    return [*command, '--entrypoint=python3', image_id(image), '-m', 'html_webview.sdk', '_worker']


def inspect_owned(container):
    data = json.loads(subprocess.check_output(['docker', 'inspect', container], text=True, timeout=30))[0]
    if (data['Id'] != container or data['Config']['Labels'].get('raft-html-sdk') != 'source-build'
            or data['HostConfig']['NanoCpus'] != 2_000_000_000
            or data['HostConfig']['Memory'] != 16 * 1024**3
            or data['HostConfig']['CpusetCpus'] != '0,1'
            or data['HostConfig']['MemorySwap'] != 16 * 1024**3):
        raise ValueError('SDK container identity or resource contract changed')
    return data


def build(archive, work, image, seconds):
    """One bounded source build/stage. Retain its container, raw install and every failure."""
    if not 60 <= seconds <= 43200:
        raise ValueError('Set an explicit build bound between60 and43200seconds')
    image = image_id(image)
    inspected = json.loads(subprocess.check_output(['docker', 'image', 'inspect', image], text=True, timeout=30))[0]
    if inspected['Id'] != image or inspected.get('Architecture') != 'amd64':
        raise ValueError('SDK builder must be the selected immutable amd64 image')
    work = new_work(work)
    record = {'imageId': image, 'sourceSha256': ARCHIVE_SHA256, 'limitSeconds': seconds}
    json_file(work / 'request.json', record)
    if not Path(archive).is_file():
        raise ValueError('Source archive is missing; preserve the new request directory')
    name = 'raft-html-sdk-' + uuid.uuid4().hex[:16]
    command = container_command(image, work, name, os.getuid(), os.getgid(), archive)
    container = subprocess.check_output(command, text=True, timeout=30).strip()
    if not re.fullmatch('[0-9a-f]{64}', container):
        raise ValueError('Docker did not return a full SDK container ID')
    record['containerId'] = container
    json_file(work / 'request.json', record)
    try:
        inspect_owned(container)
        logged(work, 'container', ['docker', 'start', '--attach', container], seconds)
    finally:
        current = inspect_owned(container)
        if current['State']['Running']:
            # Only the exact just-created, labelled container may be stopped.
            logged(work, 'bounded-stop', ['docker', 'stop', '--time=5', container], 30)
        record['terminalState'] = inspect_owned(container)['State']
        json_file(work / 'request.json', record)
    result = json.loads((work / 'result.json').read_text())
    if result.get('state') != 'sdk-ready':
        raise ValueError('The source build did not produce a complete sealed SDK')
    return result


def worker():
    """Container-only worker; no package install, networking, renderer or GUI."""
    work = Path('/work')
    request = json.loads((work / 'request.json').read_text())
    if os.getuid() == 0 or os.getpriority(os.PRIO_PROCESS, 0) != 0:
        raise ValueError('Use an unprivileged worker at initial nice0; it applies nice15 once')
    os.nice(15)
    resource_readback = subprocess.check_output(
        ['/bin/sh', str(HERE / 'build_resources.sh')], text=True,
        env={**os.environ, 'RAFT_HTML_SDK_ENFORCE_LIMITS': '1'}, timeout=15)
    (work / 'resource-readback.txt').write_text(resource_readback)
    prepare('/inputs/wpewebkit.tar.xz', work / 'prepared')
    release = dict(line.split('=', 1) for line in Path('/etc/os-release').read_text().splitlines() if '=' in line)
    if release.get('ID', '').strip('"') != 'ubuntu' or release.get('VERSION_ID', '').strip('"') != '24.04':
        raise ValueError('SDK source builds require the Ubuntu24.04 ABI environment')
    compiler = Path(shutil.which('clang-18')).resolve()
    version = subprocess.check_output(['clang-18', '--version'], text=True)
    if 'clang version 18.1.3' not in version:
        raise ValueError('The reviewed SDK compiler is Clang18.1.3')
    packages = subprocess.check_output(['dpkg-query', '-W', '-f=${Package}\t${Version}\t${Architecture}\n'])
    (work / 'installed-packages.tsv').write_bytes(packages)
    (work / 'compiler.txt').write_text(version)
    backtrace = work / 'backtrace'
    backtrace.mkdir()
    gcc = Path('/usr/lib/gcc/x86_64-linux-gnu/13')
    for name, expected in BACKTRACE.items():
        if sha256(gcc / name) != expected:
            raise ValueError('GCC13 libbacktrace input differs from the reviewed header/archive pin')
        if name.startswith('include/'):
            shutil.copy2(gcc / name, backtrace / Path(name).name)
    environment = {'imageId': request['imageId'], 'compilerSha256': sha256(compiler),
                   'packagesSha256': hashlib.sha256(packages).hexdigest(),
                   'backtraceSha256': BACKTRACE['libbacktrace.a'],
                   'resourceReadbackSha256': sha256(work / 'resource-readback.txt')}
    from .archives import Store, authenticate
    packages_index, apt_proof = authenticate()
    store = Store('/opt/raft-html-sdk-debs', work / 'authenticated-packages', packages_index, apt_proof)
    archive_inputs = [{k: v for k, v in item.items() if k != 'archive'}
                      for _, item in sorted(store.records.items())]
    json_file(work / 'package-archives.json', archive_inputs)
    environment['packageArchivesSha256'] = sha256(work / 'package-archives.json')
    identity = build_identity(environment)
    json_file(work / 'build-inputs.json', identity)
    source = work / 'prepared' / 'wpewebkit-2.54.2'
    build_dir = work / 'build'
    logged(work, 'configure', configure_command(source, build_dir, backtrace), 300)
    validate_config((build_dir / 'cmakeconfig.h').read_text())
    if sha256(build_dir / 'cmakeconfig.h') != EXPECTED_CONFIG_SHA256:
        raise ValueError('Configured feature fingerprint differs; review drift before compiling')
    logged(work, 'compile', ['ninja', '-C', str(build_dir), '-j2', *TARGETS], request['limitSeconds'])
    command, additions = install_command(build_dir, work / 'install')
    logged(work, 'install', command, 120, env={**os.environ, **additions})
    from .stage import stage
    result = stage(work / 'install/opt/raft-html-wpe', source, build_dir, work / 'sdk',
                   work / 'stage-work', '/opt/raft-html-sdk-debs', identity, work / 'sdk.tar.gz')
    result.update(prefix='sdk', archive='sdk.tar.gz', sourceInputs='prepared/source-inputs.json')
    json_file(work / 'result.json', result)



def restore(archive, pin, destination):
    manifest = payload.restore(archive, pin, destination)
    return {'prefix': str(Path(destination).resolve()), 'manifestSha256': manifest,
            'archiveSha256': pin, 'scope': 'Caller-pinned SDK restored and content-verified; native QA not run'}


def main():
    if sys.argv[1:] == ['_worker']:
        worker()
        return
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    item = commands.add_parser('restore', help='Restore a trusted workflow SDK with its externally supplied pin')
    item.add_argument('--archive', type=Path, required=True)
    item.add_argument('--sha256', required=True)
    item.add_argument('--destination', type=Path, required=True)
    item = commands.add_parser('build', help='Build, authenticate and seal a new SDK; retain failed work')
    item.add_argument('--archive', type=Path, required=True)
    item.add_argument('--work', type=Path, required=True)
    item.add_argument('--image', required=True)
    item.add_argument('--max-seconds', type=int, required=True)
    args = parser.parse_args()
    if args.command == 'restore':
        print(json.dumps(restore(args.archive, args.sha256, args.destination), indent=2))
    else:
        print(json.dumps(build(args.archive, args.work, args.image, args.max_seconds), indent=2))


if __name__ == '__main__':
    main()
