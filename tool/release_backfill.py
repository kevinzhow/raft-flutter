"""Build an existing release's original source; append only the selected platform's assets."""
import argparse
import json
import os
from pathlib import Path
import platform as host_platform
import re
import shutil
import subprocess
import sys
from urllib.parse import quote
from urllib.request import Request, urlopen

import release


def validate_inputs(tag, commit, number):
    if (not re.fullmatch(rf'v{release.VERSION_PATTERN}(?:\+[0-9]+)?', tag) or
            not re.fullmatch(r'[0-9a-f]{40}', commit) or
            not re.fullmatch(r'[1-9][0-9]*', number)):
        raise ValueError('Backfill requires a version tag, full source commit and original positive build number')


def validate_release(remote, tag, commit, number, platform='macos'):
    if platform not in {'macos', 'appimage'}:
        raise ValueError('Backfill supports macos and appimage only')
    validate_inputs(tag, commit, number)
    identity = release.release_identity('0.0.0', '1', f'refs/tags/{tag}', 'workflow_dispatch', number)
    metadata = release.checked_release(remote, identity, commit)
    arch = {'macos': 'arm64', 'appimage': 'x64'}[platform]
    if {'platform': platform, 'arch': arch} not in metadata['platforms']:
        raise ValueError('The existing release does not include the selected platform and architecture')
    return identity


def checked_source(source, tag, commit):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(source), *args], text=True).strip()
    if git('rev-parse', 'HEAD') != commit or git('rev-parse', f'refs/tags/{tag}^{{commit}}') != commit:
        raise ValueError('The build checkout, requested commit and existing tag must match exactly')
    if git('status', '--porcelain', '--untracked-files=no'):
        raise ValueError('The original release source has tracked modifications')


def existing_release(tag):
    repository = release.repository()
    request = Request(f'https://api.github.com/repos/{repository}/releases/tags/{quote(tag, safe="")}',
                      headers={'Accept': 'application/vnd.github+json'})
    if os.environ.get('GH_TOKEN'):
        request.add_header('Authorization', f'Bearer {os.environ["GH_TOKEN"]}')
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def verify_hosted_runner(source, selected_platform):
    """Check native hosted tools without requiring the retired runners' storage."""
    if os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise ValueError('Release backfills require a GitHub-hosted runner')
    if selected_platform == 'macos':
        if host_platform.system() != 'Darwin' or host_platform.machine() != 'arm64':
            raise ValueError('macOS backfills require native arm64')
        required = ('flutter', 'ruby', 'pod', 'xcodebuild', 'codesign')
    else:
        import linux_runner
        linux_runner.check_os(host_platform.system(), host_platform.machine(),
                              host_platform.freedesktop_os_release())
        required = linux_runner.TOOLS
    tools = {name: shutil.which(name) for name in required}
    if missing := [name for name, path in tools.items() if path is None]:
        raise ValueError('Missing hosted release tools: ' + ', '.join(missing))
    if not host_platform.python_version().startswith('3.12.'):
        raise ValueError('Hosted release backfills require Python 3.12')

    def output(command):
        return subprocess.check_output(command, text=True).strip()

    expected = json.loads((Path(source) / '.fvmrc').read_text())['flutter']
    flutter = json.loads(output([tools['flutter'], '--version', '--machine']))['frameworkVersion']
    if flutter != expected:
        raise ValueError('Hosted Flutter differs from the original release SDK pin')
    if selected_platform == 'macos':
        if (not re.match(r'ruby 3\.3\.', output([tools['ruby'], '--version'])) or
                output([tools['pod'], '--version']) != '1.16.2' or
                output([tools['ruby'], '-rjson', '-e', 'puts JSON::VERSION']) != '2.18.0'):
            raise ValueError('Hosted macOS packaging gems differ from release pins')
    else:
        subprocess.run([tools['pkg-config'], '--exists', 'gtk+-3.0', 'libsecret-1',
                        'jsoncpp', 'mpv'], check=True)
    os.environ['RAFT_FLUTTER_BIN'] = tools['flutter']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['build', 'publish'])
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    tag, commit, number = (os.environ.get(key, '') for key in
                           ('BACKFILL_TAG', 'BACKFILL_COMMIT', 'BACKFILL_BUILD_NUMBER'))
    validate_inputs(tag, commit, number)
    platform = os.environ.get('BACKFILL_PLATFORM', 'macos')
    source = args.source.resolve()
    checked_source(source, tag, commit)
    identity = validate_release(existing_release(tag), tag, commit, number, platform)
    os.chdir(source)
    # Only the helper comes from the workflow revision. Product and packaging
    # inputs are the original, clean tag checkout, never the runner wiring branch.
    output = source / 'build/release'
    if args.action == 'build':
        verify_hosted_runner(source, platform)
        env = dict(os.environ, GITHUB_REF=f'refs/tags/{tag}', GITHUB_RUN_NUMBER=number, GITHUB_SHA=commit,
                   GITHUB_EVENT_NAME='workflow_dispatch', RELEASE_VERSION=identity['version'],
                   RELEASE_BUILD_NUMBER=number)
        commands = [[sys.executable, source / 'tool/release.py', 'sdk']]
        if platform == 'appimage':
            commands.append([sys.executable, source / 'tool/prepare-media-appimage'])
        commands.extend(([sys.executable, source / 'tool/flutter', 'pub', 'get', '--enforce-lockfile'],
                         [sys.executable, source / 'tool/release.py', 'build', platform]))
        for command in commands:
            subprocess.run([str(x) for x in command], cwd=source, env=env, check=True)
        checked_source(source, tag, commit)
        release.verify_artifacts(output, {'include': [{'platform': platform, 'arch': {'macos': 'arm64', 'appimage': 'x64'}[platform]}]},
                                 identity['version'], commit, number, tag)
    else:
        # An explicit manual-only entry point for an already prepared release.
        # The normal tag-push publisher keeps its original trigger guard.
        if os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch':
            raise ValueError('Backfill publication requires an explicit manual workflow dispatch')
        release.ROOT, release.APP, release.OUT = source, source / 'apps/raft_flutter', output
        release.append_platform(platform, identity, commit)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f'Release backfill stopped: {error}')
