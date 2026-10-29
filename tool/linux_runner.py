"""Check the dedicated Ubuntu 24.04 release environment before packaging."""
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess


CACHE_VARIABLES = (
    'PUB_CACHE', 'RUNNER_TOOL_CACHE', 'AGENT_TOOLSDIRECTORY',
    'XDG_CACHE_HOME', 'PIP_CACHE_DIR', 'NPM_CONFIG_CACHE',
)
TOOLS = (
    'python', 'flutter', 'git', 'clang', 'cmake', 'ninja', 'pkg-config',
    'patchelf', 'pdftoppm', 'zsyncmake', 'Xvfb', 'dbus-run-session',
    'readelf', 'ldd', 'desktop-file-validate', 'findmnt',
)


def filesystem(path):
    return subprocess.check_output(
        ['findmnt', '--noheadings', '--output', 'FSTYPE', '--target', str(path)], text=True).strip()


def check_storage(environment, source, *, filesystem_type=filesystem):
    roots = {}
    for name in ('WORK', 'CACHE', 'TMP'):
        key = f'RAFT_LINUX_RUNNER_{name}_ROOT'
        if not environment.get(key):
            raise ValueError(f'{key} must identify the dedicated persistent directory')
        root = Path(environment[key]).resolve()
        if not root.is_dir() or root == Path('/'):
            raise ValueError(f'{key} must be an existing dedicated directory')
        roots[name] = root
    if any(a.is_relative_to(b) for name, a in roots.items() for other, b in roots.items() if name != other):
        raise ValueError('Work, cache and temporary roots must be separate')
    if not Path(source).resolve().is_relative_to(roots['WORK']):
        raise ValueError('Source checkout must stay inside the dedicated work directory')
    for key, parent in [(key, roots['CACHE']) for key in CACHE_VARIABLES] + [('TMPDIR', roots['TMP'])]:
        if not environment.get(key) or not Path(environment[key]).resolve().is_relative_to(parent):
            raise ValueError(f'{key} must stay inside its dedicated persistent directory')
    types = {name: filesystem_type(path) for name, path in roots.items()}
    if any(not value or value in {'tmpfs', 'ramfs'} for value in types.values()):
        raise ValueError('Release work, caches and temporary files must use persistent storage')
    return roots, types


def check_os(system, machine, release):
    if (system != 'Linux' or machine != 'x86_64' or
            release.get('ID') != 'ubuntu' or release.get('VERSION_ID') != '24.04'):
        raise ValueError('AppImage releases require Ubuntu 24.04 x86_64; do not use a newer host ABI')


def verify(source):
    check_os(platform.system(), platform.machine(), platform.freedesktop_os_release())
    source = Path(source).resolve()
    roots, storage = check_storage(os.environ, source)
    tools = {name: shutil.which(name) for name in TOOLS}
    if missing := [name for name, path in tools.items() if path is None]:
        raise ValueError('Missing Linux release tools: ' + ', '.join(missing))
    if not Path(tools['flutter']).resolve().is_relative_to(roots['CACHE']):
        raise ValueError('Flutter must use the dedicated persistent tool cache')
    expected = json.loads((source / '.fvmrc').read_text())['flutter']
    flutter = json.loads(subprocess.check_output(
        [tools['flutter'], '--version', '--machine'], text=True))['frameworkVersion']
    python = subprocess.check_output([tools['python'], '--version'], text=True).strip()
    if flutter != expected or not python.startswith('Python 3.12.'):
        raise ValueError(f'Linux release toolchain differs from its pins: Flutter {flutter}, {python}')
    subprocess.run([tools['pkg-config'], '--exists', 'gtk+-3.0', 'libsecret-1', 'jsoncpp', 'mpv'], check=True)
    os.environ['RAFT_FLUTTER_BIN'] = tools['flutter']
    receipt = {'platform': 'linux-x64', 'distribution': 'Ubuntu 24.04',
               'flutter': flutter, 'python': python, 'storageFilesystems': storage,
               'cacheVariablesChecked': list(CACHE_VARIABLES), 'packagingToolsChecked': list(TOOLS)}
    print(json.dumps(receipt, indent=2))
    return receipt


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        verify(args.source)
    except (ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Linux runner stopped: {error}\n')
