import importlib.util
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest import mock

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
        self.runtime = self.root / 'WindowsAppRuntimeInstall-x64.exe'
        self.runtime.write_bytes(b'MZ runtime fixture')
        runtime_hash = mock.patch.object(installer, 'RUNTIME_SHA256', hashlib.sha256(self.runtime.read_bytes()).hexdigest())
        runtime_env = mock.patch.dict(os.environ, {'RAFT_WINDOWS_APP_RUNTIME_INSTALLER': str(self.runtime)})
        runtime_hash.start()
        runtime_env.start()
        self.addCleanup(runtime_hash.stop)
        self.addCleanup(runtime_env.stop)

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
        self.assertIn('/DRuntimeInstaller=' + str(self.runtime.resolve()), seen['args'])
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

    def test_runtime_is_required_before_compiling_installer(self):
        calls = []

        def compile_without_runtime(args, check):
            calls.append(args)
            (self.out / 'raft-flutter-1.0.0-windows-x64-setup.exe').write_bytes(b'MZ')

        with mock.patch.dict(os.environ, {'RAFT_WINDOWS_APP_RUNTIME_INSTALLER': str(self.root / 'missing.exe')}):
            with self.assertRaisesRegex(ValueError, 'Windows App Runtime'):
                installer.build(self.stage, self.out, '1.0.0', '1.0.0', '1', 'x64',
                                run=compile_without_runtime, compiler='ISCC.exe')
        self.assertEqual(calls, [])

    def test_download_publishes_only_verified_payload_and_reuses_it(self):
        destination = self.root / 'download' / 'runtime.exe'
        opener = mock.Mock(side_effect=lambda *_args, **_kwargs: io.BytesIO(self.runtime.read_bytes()))
        self.assertEqual(installer.download_runtime(destination, opener=opener), destination.resolve())
        self.assertEqual(destination.read_bytes(), self.runtime.read_bytes())
        self.assertFalse(destination.with_name('runtime.exe.download').exists())
        installer.download_runtime(destination, opener=opener)
        self.assertEqual(opener.call_count, 1)

    def test_corrupt_download_never_becomes_an_installer(self):
        destination = self.root / 'runtime.exe'
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            installer.download_runtime(destination, opener=lambda *_a, **_k: io.BytesIO(b'corrupt'))
        self.assertFalse(destination.exists())
        self.assertEqual(destination.with_name('runtime.exe.download').read_bytes(), b'corrupt')

    def test_existing_untrusted_installer_is_not_silently_used_or_overwritten(self):
        destination = self.root / 'runtime.exe'
        destination.write_bytes(b'untrusted')
        opener = mock.Mock()
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            installer.download_runtime(destination, opener=opener)
        opener.assert_not_called()
        self.assertEqual(destination.read_bytes(), b'untrusted')

    @unittest.skipUnless(os.name == 'nt', 'Requires Windows PowerShell for the real package predicate')
    def test_runtime_detection_handles_partial_and_incompatible_installations(self):
        names = ['Microsoft.WindowsAppRuntime.1.7', 'MicrosoftCorporationII.WinAppRuntime.Main.1.7',
                 'MicrosoftCorporationII.WinAppRuntime.Singleton', 'Microsoft.WinAppRuntime.DDLM.7000.785.2325.0-x6']
        complete = [dict(Name=name, Architecture='X64', Version='7000.785.2325.0', Status='Ok') for name in names]
        cases = [('complete', complete, 0), ('missing', [], 1), ('framework-only', complete[:1], 1)]
        cases.append(('newer-singleton', [dict(p, Version='8002.5.1.0') if 'Singleton' in p['Name'] else p for p in complete], 0))
        cases.append(('wrong-architecture', [dict(p, Architecture='X86') if p['Name'] == names[0] else p for p in complete], 1))
        cases.append(('different-sdk-line', [dict(p, Name='Microsoft.WindowsAppRuntime.1.8') if p['Name'] == names[0] else p for p in complete], 1))
        cases.append(('broken-registration', [dict(p, Status='Modified') if p['Name'] == names[0] else p for p in complete], 1))
        powershell = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
        for label, packages, expected in cases:
            with self.subTest(label=label):
                payload = base64.b64encode(json.dumps(packages).encode('utf-8')).decode('ascii')
                # PowerShell 5 ConvertFrom-Json emits an array as one pipeline
                # object; Get-AppxPackage emits each package separately.
                query = "foreach($package in ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" + payload + "')) | ConvertFrom-Json)) { $package }"
                encoded = base64.b64encode(installer.runtime_check_script(query).encode('utf-16-le')).decode('ascii')
                result = subprocess.run([str(powershell), '-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
                                        capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
                self.assertEqual(result.returncode, expected, result.stderr.decode(errors='replace'))
        encoded = base64.b64encode(installer.runtime_check_script("throw 'package query unavailable'").encode('utf-16-le')).decode('ascii')
        result = subprocess.run([str(powershell), '-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
                                capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
        self.assertEqual(result.returncode, 2)

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
