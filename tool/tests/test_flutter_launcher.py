"""Exercise the public wrapper without downloading or changing an SDK."""
from contextlib import redirect_stderr
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[2]
VERSION = json.loads((ROOT / '.fvmrc').read_text())['flutter']


class FlutterLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='raft-flutter-launch-')
        self.addCleanup(self.temporary.cleanup)
        self.sdk = Path(self.temporary.name) / 'Flutter SDK with spaces'
        self.launcher = self.sdk / 'bin/flutter.bat'
        self.dart = self.sdk / 'bin/cache/dart-sdk/bin/dart.exe'
        self.snapshot = self.sdk / 'bin/cache/flutter_tools.snapshot'
        self.packages = self.sdk / 'packages/flutter_tools/.dart_tool/package_config.json'
        for path in (self.launcher, self.dart, self.snapshot, self.packages):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()

    def invoke(self, args, *, launcher=None, platform='nt', tool_args='', probe=None):
        execute = Mock(side_effect=SystemExit(29))
        platform_os = SimpleNamespace(**vars(os))
        platform_os.name, platform_os.execv = platform, execute
        modules = {
            'os': platform_os,
            'android_app': SimpleNamespace(SafetyError=RuntimeError, flutter_guard=Mock()),
            'parity_case_map': SimpleNamespace(write=Mock()),
            'gen_l10n_index': SimpleNamespace(write=Mock()),
        }
        probe = probe or subprocess.CompletedProcess([], 0, json.dumps({'frameworkVersion': VERSION}))
        environment = {'RAFT_FLUTTER_BIN': str(launcher or self.launcher),
                       'FLUTTER_TOOL_ARGS': tool_args, 'FLUTTER_ROOT': 'stale-sdk',
                       'RAFT_LAUNCH_TEST': 'preserved', 'PATH': 'existing-path'}
        errors = io.StringIO()
        with patch.dict(sys.modules, modules), \
                patch.object(sys, 'path', [str(ROOT / 'tool'), *sys.path]), \
                patch.object(sys, 'argv', [str(ROOT / 'tool/flutter'), *args]), \
                patch.dict(os.environ, environment), \
                redirect_stderr(errors), \
                patch('subprocess.run', return_value=probe) as bootstrap, \
                patch('subprocess.call', return_value=23) as child:
            with self.assertRaises(SystemExit) as exited:
                runpy.run_path(str(ROOT / 'tool/flutter'), run_name='__main__')
            parent_root = os.environ['FLUTTER_ROOT']
        return SimpleNamespace(code=exited.exception.code, bootstrap=bootstrap,
                               child=child, execute=execute, modules=modules,
                               parent_root=parent_root, stderr=errors.getvalue())

    def test_long_test_list_reaches_native_dart_with_every_argument_unchanged(self):
        files = [f'test/folder {i}/long_regression_{i:04}_test.dart' for i in range(240)]
        args = ['test', *files, '--no-pub', '--reporter', 'expanded',
                '--file-reporter', 'json:C:/results with spaces/events.json',
                '--plain-name', '中文 & %quoted% "exact" \\']
        self.assertGreater(len(subprocess.list2cmdline(args)), 8191)
        result = self.invoke(args)
        command = result.child.call_args.args[0]
        self.assertEqual(command, [str(self.dart), f'--packages={self.packages}',
                                   str(self.snapshot), *args])
        self.assertEqual(result.code, 23)
        result.bootstrap.assert_called_once_with(
            [str(self.launcher), '--version', '--machine'], capture_output=True, text=True)
        result.modules['android_app'].flutter_guard.assert_called_once_with(args)
        result.modules['parity_case_map'].write.assert_called_once_with()
        result.modules['gen_l10n_index'].write.assert_called_once_with()

    def test_native_tool_gets_sdk_root_and_bundled_git_without_changing_parent(self):
        mingit = self.sdk / 'bin/mingit/cmd'
        mingit.mkdir(parents=True)
        result = self.invoke(['analyze', '--no-pub'])
        environment = result.child.call_args.kwargs['env']
        self.assertEqual(environment['FLUTTER_ROOT'], str(self.sdk))
        self.assertEqual(environment['PATH'], f'existing-path{os.pathsep}{mingit}')
        self.assertEqual(environment['RAFT_LAUNCH_TEST'], 'preserved')
        self.assertEqual(result.parent_root, 'stale-sdk')

    @unittest.skipUnless(os.name == 'nt', 'Uses Windows command-line parsing')
    def test_dart_vm_flags_keep_windows_quoting_and_precede_snapshot(self):
        flags = ['--enable-asserts', '--Dfolder=C:\\SDK with spaces\\']
        result = self.invoke(['test', 'test/a_test.dart'],
                             tool_args=subprocess.list2cmdline(flags))
        self.assertEqual(result.child.call_args.args[0], [
            str(self.dart), f'--packages={self.packages}', *flags,
            str(self.snapshot), 'test', 'test/a_test.dart',
        ])

    def test_custom_launcher_without_sdk_layout_keeps_its_entrypoint(self):
        launcher = Path(self.temporary.name) / 'custom launcher.bat'
        launcher.touch()
        result = self.invoke(['test', 'test/a_test.dart'], launcher=launcher)
        self.assertEqual(result.child.call_args.args[0], [str(launcher), 'test', 'test/a_test.dart'])
        self.assertEqual(result.code, 23)

    def test_incomplete_sdk_keeps_official_entrypoint(self):
        self.snapshot.unlink()
        result = self.invoke(['doctor'])
        self.assertEqual(result.child.call_args.args[0], [str(self.launcher), 'doctor'])

    def test_failed_bootstrap_never_runs_the_requested_command(self):
        result = self.invoke(['test'], probe=subprocess.CompletedProcess(
            [], 17, json.dumps({'frameworkVersion': VERSION})))
        self.assertEqual(result.code, 17)
        result.child.assert_not_called()
        result.execute.assert_not_called()

    def test_wrong_sdk_version_never_runs_the_requested_command(self):
        result = self.invoke(['test'], probe=subprocess.CompletedProcess(
            [], 0, json.dumps({'frameworkVersion': 'wrong'})))
        self.assertIn('requires Flutter', result.code)
        result.child.assert_not_called()
        result.execute.assert_not_called()

    def test_unverifiable_sdk_never_runs_the_requested_command(self):
        result = self.invoke(['test'], probe=subprocess.CompletedProcess([], 0, 'not json'))
        self.assertIn('Cannot verify', result.code)
        result.child.assert_not_called()
        result.execute.assert_not_called()

    def test_bootstrap_noise_is_reported_but_never_accepted_as_machine_json(self):
        output = 'Building flutter tool...\n' + json.dumps({'frameworkVersion': VERSION})
        result = self.invoke(['pub', 'get', '--enforce-lockfile'],
                             probe=subprocess.CompletedProcess([], 0, output, 'SDK setup notice'))
        self.assertIn('Cannot verify', result.code)
        self.assertIn('Building flutter tool', result.stderr)
        self.assertIn('SDK setup notice', result.stderr)
        self.assertIn('"returnCode": 0', result.stderr)
        result.child.assert_not_called()
        result.execute.assert_not_called()

    def test_probe_diagnostics_are_bounded_and_redact_credentials_and_urls(self):
        output = ('SDK setup\nSIGNPATH_TEST_API_TOKEN=short-private-value\n'
                  'https://user:password@fixture.invalid/path?token=short\n'
                  + 'line of bootstrap output\n' * 500
                  + 'Bearer small-private-value\nend of output')
        result = self.invoke(['test'], probe=subprocess.CompletedProcess([], 0, output, ''))
        report = json.loads(result.stderr.removeprefix('Flutter SDK probe: ').strip())
        self.assertLessEqual(len(report['stdout']['head']), 1024)
        self.assertLessEqual(len(report['stdout']['tail']), 1024)
        self.assertTrue(report['stdout']['truncated'])
        self.assertEqual(report['stdout']['characters'], len(output))
        self.assertIn('end of output', result.stderr)
        for secret in ['short-private-value', 'fixture.invalid', 'user:password',
                       'small-private-value']:
            self.assertNotIn(secret, result.stderr)
        result.child.assert_not_called()

    def test_machine_version_requires_a_json_object_with_a_string_version(self):
        for payload in [[], None, {'other': VERSION}, {'frameworkVersion': [VERSION]}]:
            with self.subTest(payload=payload):
                result = self.invoke(['test'], probe=subprocess.CompletedProcess(
                    [], 0, json.dumps(payload), ''))
                self.assertIn('Cannot verify', result.code)
                result.child.assert_not_called()
                result.execute.assert_not_called()

    def test_bom_or_trailing_json_noise_is_not_silently_ignored(self):
        machine = json.dumps({'frameworkVersion': VERSION})
        for output in ['\ufeff' + machine, machine + '\nextra output']:
            with self.subTest(output=output):
                result = self.invoke(['test'], probe=subprocess.CompletedProcess([], 0, output, ''))
                self.assertIn('Cannot verify', result.code)
                result.child.assert_not_called()

    def test_non_windows_launch_is_unchanged(self):
        result = self.invoke(['test', 'test/a_test.dart'], platform='posix')
        result.child.assert_not_called()
        result.execute.assert_called_once_with(
            str(self.launcher), [str(self.launcher), 'test', 'test/a_test.dart'])
        self.assertEqual(result.code, 29)


if __name__ == '__main__':
    unittest.main()
