"""Read actual distribution feature availability; never install or alter libraries."""
import ctypes
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

import linux_system_runtime as runtime

FEATURES = ('webkit', 'mpv', 'poppler')
SCENARIOS = {
    'missing-webkit': {'webkit': 'missing', 'mpv': 'available', 'poppler': 'missing'},
    'missing-mpv': {'webkit': 'available', 'mpv': 'missing', 'poppler': 'missing'},
    'missing-both': {'webkit': 'missing', 'mpv': 'missing', 'poppler': 'missing'},
    'restored': dict.fromkeys(FEATURES, 'available'),
}
PACKAGES = {
    'ubuntu': {'webkit': 'libwebkit2gtk-4.1-0', 'mpv': 'libmpv2', 'poppler': 'poppler-utils'},
    'fedora': {'webkit': 'webkit2gtk4.1', 'mpv': 'mpv-libs', 'poppler': 'poppler-utils'},
}


def artifact_receipt(artifact):
    artifact = Path(artifact).resolve(strict=True)
    receipt = json.loads(artifact.with_suffix('.json').read_text())
    with artifact.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != receipt['sha256']:
        raise ValueError('Downloaded AppImage differs from its source-bound receipt')
    return receipt


def feature_state():
    """dlopen in this probe process proves the runtime, not product wiring."""
    result = {}
    for feature, soname in (('webkit', 'libwebkit2gtk-4.1.so.0'), ('mpv', 'libmpv.so.2')):
        try:
            ctypes.CDLL(soname)
        except OSError as error:
            result[feature] = {'status': 'missing', 'soname': soname, 'error': str(error)}
        else:
            result[feature] = {'status': 'available', 'soname': soname}
    commands = {name: shutil.which(name) for name in ('pdfinfo', 'pdftoppm')}
    result['poppler'] = {'status': 'available' if all(commands.values()) else 'missing',
                         'commands': commands}
    maps = Path('/proc/self/maps')
    return {'features': result, 'probeProcessMaps': maps.read_text() if maps.exists() else '',
            'scope': 'probe-process availability only; native app and core messaging NOT_RUN'}


def package_state(distribution):
    """Record package-manager absence too; a broken installed library is not absent."""
    if distribution not in PACKAGES:
        raise ValueError('Expected an Ubuntu or Fedora disposable runtime')
    result = {}
    for feature, package in PACKAGES[distribution].items():
        command = (['dpkg-query', '-W', '-f=${Status}\n', package] if distribution == 'ubuntu'
                   else ['rpm', '-q', package])
        process = subprocess.run(command, capture_output=True, text=True, timeout=15)
        installed = process.returncode == 0 and (distribution != 'ubuntu' or
                                                'install ok installed' in process.stdout)
        result[feature] = {'package': package, 'installed': installed,
                           'exitCode': process.returncode, 'stdout': process.stdout,
                           'stderr': process.stderr}
    return result


def require_state(observed, expected, packages=None):
    for feature in FEATURES:
        actual = observed['features'][feature]['status']
        if actual != expected[feature]:
            raise ValueError(f'{feature}: expected {expected[feature]}, actual {actual}')
        if packages is not None and packages[feature]['installed'] != (actual == 'available'):
            raise ValueError(feature + ': package state does not prove the requested installed/absent scenario')


def check_elf_listing(relative, listing, expected):
    """Missing optional backend is allowed only in the matching absent scenario."""
    feature = runtime.OPTIONAL_LIBRARIES.get(Path(relative).relative_to('lib').as_posix()
                                             if Path(relative).parts[0] == 'lib' else '')
    if 'version `' in listing:
        raise ValueError('Incompatible ELF runtime: ' + str(relative) + ': ' + listing)
    if 'not found' in listing and not (feature and expected[feature] == 'missing'):
        raise ValueError('Missing required ELF runtime: ' + str(relative) + ': ' + listing)
    return {'file': str(relative), 'feature': feature or 'core',
            'unavailableExpected': bool('not found' in listing and feature), 'ldd': listing}
