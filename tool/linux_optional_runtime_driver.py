#!/usr/bin/env python3
"""Drive the production Linux AppImage using XTEST input and visible text.

The fixture replaces only the remote service. No Dart entrypoint, plugin,
account-store implementation, dependency service, or UI callback is replaced.
Screenshots/OCR and the local service's independent data readback are retained.
"""
import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time
import urllib.request


def capture(argv, **kwargs):
    return subprocess.check_output([str(value) for value in argv], text=True, **kwargs)


class Desktop:
    def __init__(self, output, env):
        self.output, self.env = output, env
        self.actions, self.serial = [], 0
        self.window = None

    def run(self, *argv):
        return capture(argv, env=self.env, timeout=20)

    def snapshot(self, label):
        self.serial += 1
        file = self.output / f'{self.serial:03d}-{label}.png'
        self.run('import', '-window', 'root', file)
        # Sparse OCR ignores text enclosed by long button borders. Preserve
        # the original and supplement it with a same-size analysis image that
        # removes long lines. All reported coordinates remain original pixels.
        ink, clean = file.with_suffix('.ink.png'), file.with_suffix('.borderless.png')
        self.run('convert', file, '-colorspace', 'Gray', '-threshold', '35%', '-negate', ink)
        self.run('convert', ink, '(', ink, '-morphology', 'Open', 'Rectangle:80x1', ')',
                 '-compose', 'MinusSrc', '-composite',
                 '(', ink, '-morphology', 'Open', 'Rectangle:1x80', ')',
                 '-compose', 'MinusSrc', '-composite', '-negate', clean)
        lines = {}
        for mode, source in [('original', file), ('borderless', clean)]:
            tsv = self.run('tesseract', source, 'stdout', '--psm', '11', 'tsv')
            file.with_suffix('.' + mode + '.tsv').write_text(tsv)
            for row in csv.DictReader(io.StringIO(tsv), delimiter='\t'):
                if row['text'].strip():
                    key = (mode, *(row[key] for key in ('page_num', 'block_num', 'par_num', 'line_num')))
                    lines.setdefault(key, []).append(row)
        observed = []
        for words in lines.values():
            left = min(int(word['left']) for word in words)
            top = min(int(word['top']) for word in words)
            right = max(int(word['left']) + int(word['width']) for word in words)
            bottom = max(int(word['top']) + int(word['height']) for word in words)
            text = ' '.join(word['text'] for word in words)
            if not any(row['text'] == text and abs(row['box'][0] - left) < 10 and
                       abs(row['box'][1] - top) < 10 for row in observed):
                observed.append({'text': text, 'box': [left, top, right, bottom]})
        file.with_suffix('.json').write_text(json.dumps(observed, indent=2) + '\n')
        return file, observed

    def find(self, phrase, label, timeout=30, last=False, scroll=False):
        deadline = time.monotonic() + timeout
        while True:
            file, rows = self.snapshot(label)
            matches = sorted(
                (row for row in rows if phrase.casefold() in row['text'].casefold()),
                key=lambda row: (row['box'][1], row['box'][0]),
            )
            if matches:
                return file, matches[-1 if last else 0]
            if time.monotonic() >= deadline:
                raise AssertionError(f'Visible text not found: {phrase}; last screenshot {file.name}')
            if scroll:
                self.scroll(down=True, ticks=2)
            time.sleep(.5)

    def scroll(self, down, ticks):
        if self.window is None:
            raise AssertionError('Bind the actual application window before scrolling')
        window = self.window
        geometry = dict(line.split('=', 1) for line in self.run(
            'xdotool', 'getwindowgeometry', '--shell', window).splitlines() if '=' in line)
        x = int(geometry['X']) + int(geometry['WIDTH']) * 3 // 4
        y = int(geometry['Y']) + int(geometry['HEIGHT']) * 3 // 4
        self.actions.append({'kind': 'XTEST scroll', 'direction': 'down' if down else 'up',
                             'ticks': ticks, 'x': x, 'y': y, 'window': window})
        self.run('xdotool', 'mousemove', '--sync', x, y, 'click', '--repeat', ticks,
                 '--delay', '80', '5' if down else '4')

    def bind_window(self, pid):
        windows = self.run('xdotool', 'search', '--onlyvisible', '--pid', pid).split()
        candidates = []
        for window in windows:
            geometry = dict(line.split('=', 1) for line in self.run(
                'xdotool', 'getwindowgeometry', '--shell', window).splitlines() if '=' in line)
            candidates.append((int(geometry['WIDTH']) * int(geometry['HEIGHT']), window))
        if not candidates:
            raise AssertionError('Actual runner has no visible top-level window')
        self.window = max(candidates)[1]
        # This private Xvfb has no window manager. Establish the top-level
        # keyboard focus a desktop window manager normally assigns; never focus
        # a WebKit child or a document element to prime its input behavior.
        self.run('xdotool', 'windowfocus', '--sync', self.window)
        self.actions.append({'kind': 'private desktop top-level focus', 'pid': pid,
                             'window': self.window})

    def click(self, phrase, label, below=0, last=False):
        file, match = self.find(phrase, label, last=last)
        left, top, right, bottom = match['box']
        x, y = (left + right) // 2, (top + bottom) // 2 + below
        self.actions.append({'kind': 'XTEST click', 'x': x, 'y': y,
                             'visible': match, 'screenshot': file.name})
        self.run('xdotool', 'mousemove', '--sync', x, y, 'click', '1')

    def key(self, value):
        self.actions.append({'kind': 'XTEST key', 'key': value})
        self.run('xdotool', 'key', '--clearmodifiers', value)

    def type(self, value):
        self.actions.append({'kind': 'XTEST text', 'characters': len(value)})
        self.run('xdotool', 'type', '--clearmodifiers', '--delay', '25', value)


def request(origin, route, value=None):
    data = json.dumps(value).encode() if value is not None else None
    req = urllib.request.Request(origin + route, data=data,
                                 headers={'content-type': 'application/json'})
    with urllib.request.urlopen(req, timeout=5) as response:
        return json.load(response)


def wait_value(check, description, timeout=25):
    deadline = time.monotonic() + timeout
    while True:
        value = check()
        if value:
            return value
        if time.monotonic() >= deadline:
            raise AssertionError(description)
        time.sleep(.2)


def birth(pid):
    try:
        return Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[19]
    except FileNotFoundError:
        return None


def runner_identity(leader):
    """Find the actual product process below our own AppImage launcher."""
    pending = [leader]
    while pending:
        pid = pending.pop()
        try:
            executable = Path(f'/proc/{pid}/exe').resolve(strict=True)
            children = Path(f'/proc/{pid}/task/{pid}/children').read_text().split()
        except FileNotFoundError:
            continue
        if executable.name == 'raft_flutter':
            return {'pid': pid, 'birth': birth(pid), 'executable': str(executable)}
        pending.extend(int(child) for child in children)
    return None


def main(args):
    if os.environ.get('GITHUB_ACTIONS') != 'true' or not Path('/.dockerenv').exists() or os.getuid() == 0:
        raise ValueError('Run only as the private nonroot user in a disposable CI Docker desktop')
    import linux_optional_runtime as optional
    receipt = optional.artifact_receipt(args.artifact)
    before = json.loads(args.environment_before.read_text())
    if before['artifact'] != receipt['sha256'] or before['scenario'] != args.scenario:
        raise ValueError('Scenario/environment/artifact binding mismatch')
    optional.require_state(optional.feature_state(), optional.SCENARIOS[args.scenario])
    args.output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, GDK_SCALE='2', GDK_DPI_SCALE='1', LANGUAGE='en', LANG='C.UTF-8')
    for name in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        directory = args.output / name.lower()
        directory.mkdir(mode=0o700)
        env[name] = str(directory.resolve())
    env['NODE_PATH'] = os.environ.get('RAFT_OPTIONAL_FIXTURE_NODE_PATH', '')
    fixture_source = Path(__file__).with_name('linux_optional_fixture') / 'server.cjs'
    desktop = Desktop(args.output, env)
    processes, logs, assertions = [], [], []
    origin = None
    outcome = {'artifact': receipt['sha256'], 'commit': receipt['commit'], 'scenario': args.scenario,
               'fixtureSourceSha256': hashlib.sha256(fixture_source.read_bytes()).hexdigest(),
               'targetedUseCase': 'FAIL', 'assertions': assertions}

    def launch(command, name):
        log = (args.output / (name + '.log')).open('x')
        logs.append(log)
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        identity = {'pid': process.pid, 'birth': birth(process.pid), 'argv': command}
        processes.append((process, identity))
        (args.output / (name + '-process.json')).write_text(json.dumps(identity, indent=2) + '\n')
        return process

    try:
        fixture = launch(['node', str(fixture_source), str(args.output.resolve())], 'fixture')
        wait_value(lambda: (args.output / 'fixture.json').exists() or fixture.poll() is not None,
                   'Loopback fixture did not start')
        if fixture.poll() is not None:
            raise AssertionError('Loopback fixture exited')
        origin = json.loads((args.output / 'fixture.json').read_text())['origin']
        if not origin.startswith('http://127.0.0.1:'):
            raise ValueError('Fixture must use loopback')
        # Only the synthetic server origin and appearance are seeded. The
        # product must still authenticate through its visible login controls.
        for name in ('app.raft.raft_flutter', 'raft_flutter'):
            location = Path(env['XDG_DATA_HOME']) / name
            location.mkdir()
            (location / 'shared_preferences.json').write_text(json.dumps({
                'flutter.raft.origin': origin, 'flutter.raft.mode': 'light'}))
        keyring = subprocess.run(['gnome-keyring-daemon', '--unlock', '--components=secrets'],
                                 input='synthetic-private-keyring', capture_output=True,
                                 text=True, env=env, timeout=10)
        if keyring.returncode:
            raise AssertionError('Private Secret Service could not start')
        alias = capture(['dbus-send', '--session', '--print-reply',
                         '--dest=org.freedesktop.secrets', '/org/freedesktop/secrets',
                         'org.freedesktop.Secret.Service.ReadAlias', 'string:default'],
                        env=env, timeout=10)
        (args.output / 'private-keyring-alias.txt').write_text(alias)
        collection = re.search(r'object path "([^"]+)"', alias)
        if collection is None or collection[1] == '/':
            raise AssertionError('Private keyring has no initialized default collection')
        app = launch([str(args.artifact.resolve()), '--appimage-extract-and-run'], 'app')
        # The Email label belongs to the actual AuthView. XTEST clicks into its
        # visible fields. Focus traversal includes the forgot-password link,
        # so the password and submit button are selected from their visible UI.
        _, initial = desktop.find('Email', 'login-visible')
        _, initial_rows = desktop.snapshot('login-without-startup-prompt')
        assert not any('install command' in row['text'].lower() or 'system dependencies' in row['text'].lower()
                       for row in initial_rows), 'Startup must not show dependency installation UI'
        actual_runner = wait_value(lambda: runner_identity(app.pid), 'Actual product runner was not found')
        desktop.bind_window(actual_runner['pid'])
        (args.output / 'actual-runner-before.json').write_text(json.dumps(actual_runner, indent=2) + '\n')
        assertions.append({'id': 'startup-has-no-install-modal', 'result': 'PASS'})
        desktop.click('Email', 'login-email', below=55)
        desktop.type('runtime@fixture.invalid')
        desktop.click('Password', 'login-password', below=55)
        desktop.type('synthetic-password')
        desktop.key('Return')
        wait_value(lambda: request(origin, '/qa/state')['authenticated'], 'Visible login did not reach fixture')
        assertions.append({'id': 'visible-login', 'result': 'PASS'})
        desktop.click('Optional Runtime QA', 'server-choice')
        desktop.click('general', 'channel-choice')
        desktop.find('Core messaging is independent', 'core-chat')
        outgoing = 'Optional outgoing proof'
        desktop.click('Message', 'composer', last=True)
        desktop.type(outgoing)
        desktop.key('Return')
        wait_value(lambda: request(origin, '/qa/state')['sent'] == 1,
                   'Actual composer did not POST exactly one message')
        desktop.find(outgoing, 'sent-visible')
        incoming = 'Optional incoming proof'
        delivered = request(origin, '/qa/receive', {'content': incoming})
        desktop.find(incoming, 'received-visible')
        state = request(origin, '/qa/state')
        assert state['connections'] > 0 and state['sent'] == 1 and state['incoming'] == 1
        assert any(row['id'] == delivered['id'] and row['connectedRecipients'] > 0
                   for row in state['liveDeliveries'])
        assert not any(row['id'] == delivered['id'] for row in state['messages']), 'Socket proof must not come from HTTP history'
        (args.output / 'core-service-readback.json').write_text(json.dumps(state, indent=2) + '\n')
        assertions.append({'id': 'core-send-receive-with-current-dependencies', 'result': 'PASS',
                           'proof': 'XTEST composer -> HTTP saved row; Socket.IO incoming -> visible row'})
        desktop.key('ctrl+comma')
        desktop.click('Desktop', 'desktop-settings')
        desktop.find('System dependencies', 'dependencies-settings')
        desktop.click('Check dependencies', 'check-dependencies')
        expected = optional.SCENARIOS[args.scenario]
        # Each missing feature must expose its actual install command; these
        # are feature-specific package names, never a generic green banner.
        for feature, status in expected.items():
            if status == 'missing':
                package = before['packages'][feature]['package']
                desktop.find(package, 'missing-' + feature, scroll=True)
                assertions.append({'id': 'install-guidance-' + feature, 'result': 'PASS', 'package': package})
        (args.output / 'before-restore-pid.json').write_text(json.dumps(actual_runner) + '\n')
        if args.scenario != 'restored':
            command = json.loads(args.restore_command_json)
            if not isinstance(command, list) or not command or not all(isinstance(x, str) for x in command):
                raise ValueError('A fixed container-local restore argv is required')
            with (args.output / 'restore.log').open('x') as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=240, check=True)
            assert app.poll() is None and birth(actual_runner['pid']) == actual_runner['birth']
            after = optional.feature_state()
            optional.require_state(after, dict.fromkeys(optional.FEATURES, 'available'))
            (args.output / 'environment-restored.json').write_text(json.dumps(after, indent=2) + '\n')
            desktop.scroll(down=False, ticks=30)
            desktop.click('Check dependencies', 'recheck-dependencies')
        def all_available():
            _, rows = desktop.snapshot('all-dependencies-status')
            text = '\n'.join(row['text'] for row in rows)
            return ('Unavailable' not in text and 'Copy install command' not in text
                    and text.count('Available') == 3 and 'Check dependencies' in text)
        wait_value(all_available, 'Recheck did not finish with three Available states and no install guidance')
        assert birth(actual_runner['pid']) == actual_runner['birth']
        assertions.append({'id': 'same-process-recheck-clears-install-guidance' if args.scenario != 'restored'
                                else 'all-installed-dependencies-available',
                           'result': 'PASS', 'pid': actual_runner['pid']})
        # Dependency checks alone do not prove HTML/player/PDF execution.
        # Retain this boundary explicitly until the corresponding feature
        # driver has actually exercised the rendered attachment.
        outcome.update(targetedUseCase='CORE_AND_SETTINGS_PASS_FEATURE_EXECUTION_NOT_RUN',
                       unrun=['HTML script input', 'decoded media playback', 'PDF rendered page'])
    except BaseException as error:
        outcome['error'] = type(error).__name__ + ': ' + str(error)
        if origin:
            try:
                (args.output / 'first-failure-service-state.json').write_text(
                    json.dumps(request(origin, '/qa/state'), indent=2) + '\n')
            except BaseException:
                pass
        try:
            desktop.snapshot('first-failure')
        except BaseException:
            pass
        raise
    finally:
        for process, identity in reversed(processes):
            try:
                if process.poll() is None and birth(process.pid) == identity['birth']:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(5)
            except subprocess.TimeoutExpired:
                if birth(process.pid) == identity['birth']:
                    os.killpg(process.pid, signal.SIGKILL)
                process.wait(5)
            except ProcessLookupError:
                pass
            except BaseException as error:
                outcome.setdefault('cleanupErrors', []).append(str(error))
        for log in logs:
            log.close()
        (args.output / 'actions.json').write_text(json.dumps(desktop.actions, indent=2) + '\n')
        (args.output / 'result.json').write_text(json.dumps(outcome, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--scenario', choices=['missing-webkit', 'missing-mpv', 'missing-both', 'restored'], required=True)
    parser.add_argument('--environment-before', type=Path, required=True)
    parser.add_argument('--restore-command-json', default='[]')
    main(parser.parse_args())
