"""Harness lifecycle tests only; not native/AppImage acceptance."""
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('appimage_wayland_smoke', ROOT / 'tool/appimage-wayland-smoke.py')
harness = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(harness)


@unittest.skipUnless(os.name == 'posix', 'POSIX subprocess/socket fixture')
class WaylandHarnessTests(unittest.TestCase):
    def bind_socket(self, root):
        # Only a real S_IFSOCK path is needed by the readiness-unit fixtures.
        # A child cwd keeps its short AF_UNIX address inside the owned runtime
        # without changing the test runner's cwd or escaping a long TMPDIR.
        subprocess.run([sys.executable, '-c',
                        "import socket\nwith socket.socket(socket.AF_UNIX) as bound: bound.bind('wayland-raft')"],
                       cwd=root, check=True, timeout=5)

    def run_harness(self, scenario='delayed'):
        temporary = tempfile.TemporaryDirectory(prefix='raft-kwin-harness-')
        self.addCleanup(temporary.cleanup)
        work = Path(temporary.name)
        commands, output, source, runtime = (work / name for name in ('bin', 'evidence', 'source', 'runtime'))
        for path in (commands, output, source / 'tool', runtime):
            path.mkdir(parents=True)
        for path in ROOT.glob('tool/appimage-wayland-smoke.py'):
            shutil.copy2(path, source / 'tool' / path.name)
        smoke = source / 'tool/appimage-smoke.py'
        smoke.write_text('import os\nfrom pathlib import Path\n'
                         'p=Path(os.environ["FIXTURE_OUTPUT"])\n'
                         '(p/"production-smoke-called").write_text("wayland")\n'
                         'if os.environ["FIXTURE_SCENARIO"] == "smoke-fails": raise SystemExit(7)\n')
        compositor = commands / 'kwin_wayland'
        compositor.write_text('#!' + sys.executable + '\n' + '''
import os, socket, time
from pathlib import Path
out=Path(os.environ['FIXTURE_OUTPUT'])
(out/'fixture-pid').write_text(str(os.getpid()))
print('fixture compositor stderr', file=__import__('sys').stderr, flush=True)
s=socket.socket(socket.AF_UNIX)
# Bind a short address while keeping the socket inside the isolated temp tree.
os.chdir(os.environ['XDG_RUNTIME_DIR'])
s.bind('wayland-raft')
if os.environ['FIXTURE_SCENARIO'] == 'dead': raise SystemExit(23)
while True: time.sleep(0.05)
''')
        gdbus = commands / 'gdbus'
        gdbus.write_text('#!' + sys.executable + '\n' + '''
import os, sys
from pathlib import Path
out=Path(os.environ['FIXTURE_OUTPUT']); args=sys.argv[1:]
with (out/'dbus-calls').open('a') as log: log.write(' '.join(args)+'\\n')
if 'org.freedesktop.DBus.GetNameOwner' in args:
 p=out/'owner-probes'; n=int(p.read_text())+1 if p.exists() else 1; p.write_text(str(n))
 if n >= 3: (out/'registered').touch(); print("(':1.42',)"); sys.exit(0)
elif 'org.freedesktop.DBus.GetConnectionUnixProcessID' in args:
 pid=int((out/'fixture-pid').read_text())
 if os.environ['FIXTURE_SCENARIO']=='wrong-owner': pid+=1
 print('(uint32 '+str(pid)+',)'); sys.exit(0)
elif 'org.freedesktop.DBus.ListNames' in args:
 print("(['org.freedesktop.DBus'],)"); sys.exit(0)
elif 'org.kde.KWin.supportInformation' in args and (out/'registered').exists():
 print("('KWin fixture ready',)"); sys.exit(0)
print('GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: org.kde.KWin', file=sys.stderr)
sys.exit(1)
''')
        for name in ('dbus-update-activation-environment', 'kscreen-doctor', 'xwininfo'):
            path = commands / name
            path.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$FIXTURE_OUTPUT/' + name + '-calls"\n' +
                            ('if [ "$FIXTURE_SCENARIO" = scale-fails ]; then exit 9; fi\n' if name == 'kscreen-doctor' else ''))
        for path in commands.iterdir():
            path.chmod(0o755)
        script = (ROOT / 'tool/appimage-fedora-test.sh').read_text()
        block = re.search(r"dbus-run-session -- bash -euo pipefail -c '(.*)'\s*$", script, re.S)
        self.assertIsNotNone(block, 'Keep the isolated dbus-run-session boundary')
        program = block[1].replace('/evidence/fedora', str(output)).replace('/source', str(source))
        env = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ['PATH'],
                   FIXTURE_OUTPUT=str(output), FIXTURE_SCENARIO=scenario,
                   XDG_RUNTIME_DIR=str(runtime), DISPLAY=':fixture', RAFT_APPIMAGE=str(work / 'original.AppImage'))
        completed = subprocess.run(['bash', '-euo', 'pipefail', '-c', program], env=env,
                                   text=True, capture_output=True, timeout=10)
        return completed, output

    def test_socket_precedes_dbus_registration_but_real_support_is_required(self):
        completed, output = self.run_harness()
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertTrue((output / 'production-smoke-called').is_file())
        self.assertEqual((output / 'owner-probes').read_text(), '3')
        calls = (output / 'dbus-calls').read_text()
        self.assertIn('org.freedesktop.DBus.GetConnectionUnixProcessID', calls)
        self.assertIn('--dest :1.42', calls)
        self.assertIn('output.1.scale.2', (output / 'kscreen-doctor-calls').read_text())

    def test_long_isolated_tmpdir_keeps_the_socket_inside_its_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            long_root = Path(temporary) / ('nested-' + 'x' * 80)
            long_root.mkdir()
            with patch.object(tempfile, 'tempdir', str(long_root)):
                completed, output = self.run_harness()
            address = output.parent / 'runtime/wayland-raft'
            self.assertGreater(len(os.fsencode(address)), 107)
            before = Path.cwd()
            self.bind_socket(long_root)
            self.assertTrue((long_root / 'wayland-raft').is_socket())
            self.assertEqual(Path.cwd(), before)
            self.assertTrue(address.is_socket())
            self.assertTrue(address.is_relative_to(long_root))
            self.assertEqual(completed.returncode, 0, completed.stderr)
            state = json.loads((output / 'kwin-state.json').read_text())
            self.assertEqual(state['phase'], 'smoke-passed')
            self.assertIsNone(state['returnCodeBeforeCleanup'])
            self.assertIsNotNone(state['returnCodeAfterCleanup'])

    def test_compositor_death_is_not_replaced_by_a_ready_socket(self):
        completed, output = self.run_harness('dead')
        self.assertNotEqual(completed.returncode, 0)
        state = json.loads((output / 'kwin-state.json').read_text())
        self.assertIn('exit=23', state['error'])
        self.assertEqual(state['returnCodeBeforeCleanup'], 23)
        self.assertTrue(state['socketExistsBeforeCleanup'])
        self.assertFalse((output / 'production-smoke-called').exists())
        self.assertIn('fixture compositor stderr', (output / 'kwin.log').read_text())
        self.assertTrue((output / 'kwin-bus-names.log').is_file())

    def test_another_dbus_owner_never_accepts_or_scales_the_wrong_compositor(self):
        completed, output = self.run_harness('wrong-owner')
        self.assertNotEqual(completed.returncode, 0)
        state = json.loads((output / 'kwin-state.json').read_text())
        self.assertIn('not the launched compositor', state['error'])
        self.assertIsNone(state['returnCodeBeforeCleanup'])
        self.assertIsNotNone(state['returnCodeAfterCleanup'])
        self.assertNotIn('org.kde.KWin.supportInformation', (output / 'dbus-calls').read_text())
        self.assertFalse((output / 'kscreen-doctor-calls').exists())
        self.assertFalse((output / 'production-smoke-called').exists())

    def test_actual_smoke_failure_remains_failed_after_readiness(self):
        completed, output = self.run_harness('smoke-fails')
        self.assertNotEqual(completed.returncode, 0)
        self.assertTrue((output / 'production-smoke-called').is_file())
        state = json.loads((output / 'kwin-state.json').read_text())
        self.assertEqual(state['phase'], 'ready')
        self.assertIn('exit status 7', state['error'])
        self.assertIsNotNone(state['returnCodeAfterCleanup'])

    def test_scale_failure_does_not_reach_the_production_smoke(self):
        completed, output = self.run_harness('scale-fails')
        self.assertNotEqual(completed.returncode, 0)
        self.assertFalse((output / 'production-smoke-called').exists())
        state = json.loads((output / 'kwin-state.json').read_text())
        self.assertEqual(state['phase'], 'ready')
        self.assertIn('exit status 9', state['error'])

    def test_deadline_requires_both_socket_and_callable_support(self):
        for stage in ('no-socket', 'no-owner', 'no-method'):
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                if stage != 'no-socket':
                    self.bind_socket(root)
                process = Mock(pid=123)
                process.poll.return_value = None
                def call(args, **kwargs):
                    if stage == 'no-owner':
                        return subprocess.CompletedProcess(args, 1, '', 'ServiceUnknown')
                    if 'org.freedesktop.DBus.GetNameOwner' in args:
                        return subprocess.CompletedProcess(args, 0, "(':1.42',)", '')
                    if 'org.freedesktop.DBus.GetConnectionUnixProcessID' in args:
                        return subprocess.CompletedProcess(args, 0, '(uint32 123,)', '')
                    return subprocess.CompletedProcess(args, 1, '', 'MethodUnavailable')
                tick = iter(i / 100 for i in range(1000))
                with patch.object(harness.time, 'monotonic', side_effect=lambda: next(tick)), \
                     patch.object(harness.time, 'sleep'), patch.object(harness.subprocess, 'run', side_effect=call) as run:
                    with self.assertRaisesRegex(TimeoutError, 'deadline'):
                        harness.wait_for_kwin(process, root, root, timeout=0.15)
                self.assertFalse((root / 'kwin-support.txt').exists())
                if stage == 'no-socket':
                    run.assert_not_called()
                else:
                    self.assertTrue(run.called)
                    self.assertIn('Unavailable' if stage == 'no-method' else 'ServiceUnknown',
                                  (root / 'kwin-readiness.log').read_text())

    def test_unresponsive_dbus_call_is_bounded_and_logged(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.bind_socket(root)
            process = Mock(pid=123)
            process.poll.return_value = None
            tick = iter(i / 100 for i in range(1000))
            with patch.object(harness.time, 'monotonic', side_effect=lambda: next(tick)), \
                 patch.object(harness.time, 'sleep'), patch.object(harness.subprocess, 'run',
                 side_effect=subprocess.TimeoutExpired(['gdbus'], 1)) as run:
                with self.assertRaises(TimeoutError):
                    harness.wait_for_kwin(process, root, root, timeout=0.1)
            self.assertLessEqual(run.call_args.kwargs['timeout'], 0.1)
            self.assertIn('timed out', (root / 'kwin-readiness.log').read_text())


if __name__ == '__main__':
    unittest.main()
