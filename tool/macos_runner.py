"""Validate the dedicated data-volume macOS runner before using its toolchain."""
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess


CACHE_VARIABLES = (
    'TMPDIR', 'XDG_CACHE_HOME', 'PUB_CACHE', 'RUNNER_TOOL_CACHE',
    'AGENT_TOOLSDIRECTORY', 'GEM_HOME', 'GEM_PATH', 'GEM_SPEC_CACHE',
    'BUNDLE_USER_CACHE', 'BUNDLE_USER_CONFIG', 'BUNDLE_USER_PLUGIN', 'BUNDLE_PATH',
    'CP_HOME_DIR', 'CP_CACHE_DIR', 'PIP_CACHE_DIR', 'npm_config_cache',
    'COREPACK_HOME', 'CLANG_MODULE_CACHE_PATH', 'SWIFTPM_MODULECACHE_OVERRIDE',
    'FVM_CACHE_PATH', 'DOTNET_CLI_HOME', 'DOTNET_BUNDLE_EXTRACT_BASE_DIR',
    'NUGET_PACKAGES',
)


def inside(path, root):
    return Path(path).resolve().is_relative_to(root.resolve())


def check_storage(environment, workspace, *, mounted=os.path.ismount):
    data = Path('/Volumes/Data')
    root = Path(environment.get('RAFT_MACOS_RUNNER_ROOT', ''))
    if not environment.get('RAFT_MACOS_RUNNER_ROOT') or not mounted(data):
        raise ValueError('The dedicated macOS runner requires its mounted data volume')
    if not inside(root, data) or root.resolve() == data:
        raise ValueError('Runner root must be a dedicated directory on the data volume')
    if not inside(workspace, root):
        raise ValueError('Build checkout must be inside the dedicated runner root')
    for key in CACHE_VARIABLES:
        if not environment.get(key) or not inside(environment[key], root):
            raise ValueError(f'{key} must use the dedicated data-volume directory')
    return root


def verify(source):
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise ValueError('This runner requires macOS arm64')
    source = Path(source).resolve()
    root = check_storage(os.environ, source)
    expected_flutter = json.loads((source / '.fvmrc').read_text())['flutter']
    tools = {}
    for tool in ('python', 'ruby', 'pod', 'flutter'):
        path = shutil.which(tool)
        if not path or not inside(path, root):
            raise ValueError(f'{tool} must come from the dedicated data-volume toolchain')
        tools[tool] = path
    if os.environ.get('RAFT_FLUTTER_BIN') != tools['flutter']:
        raise ValueError('The repository wrapper must use the dedicated Flutter')
    def output(args):
        return subprocess.check_output(args, text=True).strip()
    versions = {
        'python': output([tools['python'], '--version']),
        'ruby': output([tools['ruby'], '--version']),
        'cocoapods': output([tools['pod'], '--version']),
        'json': output([tools['ruby'], '-rjson', '-e', 'puts JSON::VERSION']),
        'flutter': json.loads(output([tools['flutter'], '--version', '--machine']))['frameworkVersion'],
    }
    if (not versions['python'].startswith('Python 3.12.') or
            not re.match(r'ruby 3\.3\.', versions['ruby']) or
            versions['cocoapods'] != '1.16.2' or versions['json'] != '2.18.0' or
            versions['flutter'] != expected_flutter):
        raise ValueError(f'Dedicated runner toolchain differs from release pins: {versions}')
    receipt = {'platform': 'macos-arm64', 'storage': 'dedicated mounted data volume',
               'versions': versions, 'cacheVariablesChecked': list(CACHE_VARIABLES)}
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
        parser.exit(1, f'Mac runner stopped: {error}\n')
