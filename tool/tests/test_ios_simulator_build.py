"""Simulator output keeps Xcode's signature instead of claiming iOS privileges."""
import contextlib
import io
from pathlib import Path
import plistlib
import runpy
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'ios-simulator-build'


class SimulatorBuildTests(unittest.TestCase):
    def run_helper(self, source=None, signature=None):
        commands = []
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / 'tool/ios-simulator-build'
            script.parent.mkdir()
            script.write_text(source if source is not None else SCRIPT.read_text())
            bundle = root / 'apps/raft_flutter/build/ios/iphonesimulator/Runner.app'
            for suffix in ['ShareExtension', 'ActionExtension', '']:
                target = bundle / f'PlugIns/{suffix}.appex' if suffix else bundle
                target.mkdir(parents=True, exist_ok=True)
                info = {
                    'CFBundleIdentifier': 'app.raft.raftFlutter' + ('.' + suffix if suffix else ''),
                    'RaftAppGroup': 'group.app.raft.raftFlutter',
                    'RaftShareKeychainGroup': 'TEST.app.raft.raftFlutter.shareSession',
                    'CFBundleVersion': '9', 'CFBundleShortVersionString': '0.1.0',
                }
                (target / 'Info.plist').write_bytes(plistlib.dumps(info))

            def run(command, **kwargs):
                commands.append(command)
                if '--sign' in command:
                    raise AssertionError('Must preserve Xcode simulator output; no re-signing')
                return subprocess.CompletedProcess(command, 0)

            def output(command, **kwargs):
                commands.append(command)
                return plistlib.dumps(signature or {})

            android = types.ModuleType('android_app')
            android.local_dev_version = lambda _: 'test.9'
            with patch.dict(sys.modules, {'android_app': android}), \
                    patch.object(sys, 'platform', 'darwin'), \
                    patch.object(sys, 'argv', [str(script), '--build-number=9']), \
                    patch('subprocess.run', side_effect=run), \
                    patch('subprocess.check_output', side_effect=output), \
                    contextlib.redirect_stdout(io.StringIO()):
                runpy.run_path(str(script), run_name='__main__')
        return commands

    def test_preserves_xcode_signature_and_never_installs_or_launches(self):
        commands = self.run_helper()
        self.assertEqual(3, sum('--display' in c for c in commands))
        self.assertEqual(1, sum('--verify' in c and '--deep' in c for c in commands))
        self.assertFalse(any('simctl' in c for c in commands))

    def test_rejects_ios_keychain_entitlement_in_host_signature(self):
        with self.assertRaisesRegex(SystemExit, 'host signature has entitlements'):
            self.run_helper(signature={'keychain-access-groups': ['TEST.app.raft.raftFlutter']})

    def test_rejects_ios_debug_entitlement_in_host_signature(self):
        with self.assertRaisesRegex(SystemExit, 'host signature has entitlements'):
            self.run_helper(signature={'get-task-allow': True})


if __name__ == '__main__':
    unittest.main()
