import importlib.util
from pathlib import Path
import re
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('windows_installer', Path(__file__).resolve().parents[1] / 'windows_installer.py')
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class WindowsInstallerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.stage = self.root / 'stage'
        (self.stage / 'data').mkdir(parents=True)
        for name in ['raft_flutter.exe', 'raft.ico', 'flutter_windows.dll', 'RUN.txt', 'data/app.so']:
            (self.stage / name).write_bytes(b'x')
        self.out = self.root / 'out'
        self.out.mkdir()

    def test_numeric_version_strips_prerelease_and_appends_build(self):
        self.assertEqual(installer.numeric_version('0.1.1', '47'), '0.1.1.47')
        self.assertEqual(installer.numeric_version('1.2.3-rc.1', '9'), '1.2.3.9')
        with self.assertRaises(ValueError):
            installer.numeric_version('1.2', '9')
        with self.assertRaises(ValueError):
            installer.numeric_version('1.2.3', '0')

    def test_builds_installer_from_payload_without_portable_notes(self):
        seen = {}

        def fake_run(args, check):
            payload = Path(args[2].removeprefix('/DSourceDir='))
            seen['files'] = sorted(p.relative_to(payload).as_posix() for p in payload.rglob('*') if p.is_file())
            seen['args'] = args
            (self.out / 'raft-flutter-0.1.1+2-windows-x64-setup.exe').write_bytes(b'MZ')

        result = installer.build(self.stage, self.out, '0.1.1+2', '0.1.1', '47', 'x64', run=fake_run, compiler='ISCC.exe')
        self.assertEqual(result.name, 'raft-flutter-0.1.1+2-windows-x64-setup.exe')
        self.assertNotIn('RUN.txt', seen['files'])
        self.assertIn('data/app.so', seen['files'])
        self.assertIn('/DNumericVersion=0.1.1.47', seen['args'])
        self.assertEqual(list(self.out.glob('.installer-payload-*')), [])

    def test_incomplete_bundle_or_missing_output_is_rejected(self):
        (self.stage / 'raft.ico').unlink()
        with self.assertRaisesRegex(ValueError, 'Incomplete'):
            installer.build(self.stage, self.out, '1.0.0', '1.0.0', '1', 'x64', run=lambda *a, **k: None, compiler='x')
        (self.stage / 'raft.ico').write_bytes(b'x')
        with self.assertRaisesRegex(ValueError, 'did not produce'):
            installer.build(self.stage, self.out, '1.0.0', '1.0.0', '1', 'x64', run=lambda *a, **k: None, compiler='x')

    def test_compiler_lookup(self):
        self.assertEqual(installer.find_compiler({'ISCC': 'C:/x/ISCC.exe'}, which=lambda n: None, exists=lambda p: True), 'C:/x/ISCC.exe')
        with self.assertRaisesRegex(ValueError, 'Inno Setup'):
            installer.find_compiler({}, which=lambda n: None, exists=lambda p: False)

    def test_script_keeps_the_update_critical_settings(self):
        text = installer.SCRIPT.read_text()
        self.assertIn('PrivilegesRequired=lowest', text)  # silent updates without UAC
        self.assertIn('CloseApplications=yes', text)
        self.assertRegex(text, r'AppId=\{\{9A4A1E4B-DA33-4784-95CA-15E0D360C3B2\}')  # stable identity
        self.assertRegex(text, r'(?m)^Filename: "\{app\}\\raft_flutter\.exe".*postinstall')
        run_entries = re.findall(r'(?m)^Filename:.*$', text)
        self.assertFalse(any('skipifsilent' in line for line in run_entries))  # relaunch after silent update


if __name__ == '__main__':
    unittest.main()
