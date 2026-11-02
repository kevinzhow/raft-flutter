#!/usr/bin/env python3
"""Run the production AppImage smoke after its nested KWin is actually ready."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def wait_for_kwin(process, runtime, output, timeout=30):
    # KWin creates its socket before Workspace registers org.kde.KWin. A socket
    # alone therefore proves neither a live compositor nor a callable D-Bus API.
    deadline = time.monotonic() + timeout
    with (output / 'kwin-readiness.log').open('w') as log:
        def call(destination, path, method, *arguments):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return None
            try:
                reply = subprocess.run([
                    'gdbus', 'call', '--session', '--timeout', '1', '--dest', destination,
                    '--object-path', path, '--method', method, *arguments,
                ], text=True, capture_output=True, timeout=min(1, remaining))
            except subprocess.TimeoutExpired:
                log.write(method + ': timed out\n')
                log.flush()
                return None
            log.write(f'{method}: exit={reply.returncode}\n{reply.stdout}{reply.stderr}')
            log.flush()
            return reply.stdout.strip() if reply.returncode == 0 else None

        while time.monotonic() < deadline:
            code = process.poll()
            if code is not None:
                raise RuntimeError(f'KWin exited before D-Bus readiness (exit={code})')
            if (runtime / 'wayland-raft').is_socket():
                owner = call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                             'org.freedesktop.DBus.GetNameOwner', 'org.kde.KWin')
                if owner is not None:
                    match = re.fullmatch(r"\('(:[0-9]+\.[0-9]+)',\)", owner)
                    if not match:
                        raise ValueError('Unexpected KWin D-Bus name-owner reply')
                    owner = match[1]
                    pid = call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                               'org.freedesktop.DBus.GetConnectionUnixProcessID', owner)
                    if pid is not None:
                        match = re.fullmatch(r'\(uint32 ([0-9]+),\)', pid)
                        if not match or int(match[1]) != process.pid:
                            raise ValueError('KWin D-Bus owner is not the launched compositor')
                        support = call(owner, '/KWin', 'org.kde.KWin.supportInformation')
                        if support:
                            if process.poll() is not None:
                                raise RuntimeError('KWin exited during its readiness probe')
                            (output / 'kwin-support.txt').write_text(support + '\n')
                            return owner
            time.sleep(min(0.25, max(0, deadline - time.monotonic())))
    raise TimeoutError('KWin socket/D-Bus supportInformation was not ready within the deadline')


def smoke(artifact, output):
    output.mkdir(parents=True, exist_ok=True)
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    kwin_env = dict(os.environ, QT_FORCE_STDERR_LOGGING='1')
    state = {'phase': 'starting', 'socket': 'wayland-raft'}
    with (output / 'kwin.log').open('wb') as log:
        process = subprocess.Popen([
            'kwin_wayland', '--x11-display', os.environ['DISPLAY'], '--no-lockscreen',
            '--no-global-shortcuts', '--width', '2880', '--height', '1800',
            '--socket', 'wayland-raft',
        ], env=kwin_env, stdout=log, stderr=subprocess.STDOUT)
        state['pid'] = process.pid
        env = dict(os.environ, WAYLAND_DISPLAY='wayland-raft', XDG_SESSION_TYPE='wayland')
        env.pop('QT_QPA_PLATFORM', None)
        try:
            subprocess.run(['dbus-update-activation-environment', 'WAYLAND_DISPLAY',
                            'XDG_CURRENT_DESKTOP', 'KDE_SESSION_VERSION', 'XDG_SESSION_TYPE'],
                           env=env, check=True)
            state['owner'] = wait_for_kwin(process, runtime, output)
            state['phase'] = 'ready'
            with (output / 'output-scale.log').open('wb') as scale:
                qt_env = dict(env, QT_QPA_PLATFORM='wayland')
                subprocess.run(['kscreen-doctor', 'output.1.scale.2'], env=qt_env,
                               stdout=scale, stderr=subprocess.STDOUT, check=True)
                subprocess.run(['kscreen-doctor', '-o'], env=qt_env,
                               stdout=scale, stderr=subprocess.STDOUT, check=True)
            with (output / 'nested-compositor-windows.txt').open('wb') as windows:
                subprocess.run(['xwininfo', '-root', '-tree'], env=env, stdout=windows, check=True)
            subprocess.run([sys.executable, str(Path(__file__).with_name('appimage-smoke.py')),
                            '--artifact', str(artifact), '--output', str(output), '--mode', 'wayland'],
                           env=env, check=True)
            if process.poll() is not None:
                raise RuntimeError('KWin exited during the production Wayland smoke')
            state['phase'] = 'smoke-passed'
        except Exception as error:
            state['error'] = str(error)
            # Query the existing bus only: never activate a replacement KWin.
            with (output / 'kwin-bus-names.log').open('wb') as bus:
                try:
                    subprocess.run(['gdbus', 'call', '--session', '--timeout', '1',
                                    '--dest', 'org.freedesktop.DBus', '--object-path',
                                    '/org/freedesktop/DBus', '--method', 'org.freedesktop.DBus.ListNames'],
                                   stdout=bus, stderr=subprocess.STDOUT, timeout=2)
                except subprocess.TimeoutExpired:
                    bus.write(b'Listing bus names timed out\n')
            raise
        finally:
            state['returnCodeBeforeCleanup'] = process.poll()
            state['socketExistsBeforeCleanup'] = (runtime / 'wayland-raft').is_socket()
            if process.poll() is None:
                try:
                    process.terminate()
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            state['returnCodeAfterCleanup'] = process.returncode
            (output / 'kwin-state.json').write_text(json.dumps(state, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    arguments = parser.parse_args()
    smoke(arguments.artifact, arguments.output)
