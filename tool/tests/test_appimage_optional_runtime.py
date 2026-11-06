"""Missing-library evidence classification; native use cases are separate."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import linux_optional_runtime as optional

SPEC = importlib.util.spec_from_file_location('optional_smoke_test', TOOL / 'appimage-smoke.py')
smoke = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(smoke)


class OptionalRuntimeEvidenceTests(unittest.TestCase):
    def test_unresolved_backend_is_allowed_only_when_its_actual_feature_is_missing(self):
        cases = [('lib/libraft_system_webview_plugin.so', 'webkit'),
                 ('lib/raft-webview/libraft_system_webview_extension.so', 'webkit'),
                 ('lib/libmedia_kit_video_plugin.so', 'mpv')]
        for relative, feature in cases:
            with self.subTest(relative=relative):
                expected = dict.fromkeys(optional.FEATURES, 'available')
                with self.assertRaisesRegex(ValueError, 'Missing required'):
                    optional.check_elf_listing(relative, 'library => not found', expected)
                expected[feature] = 'missing'
                result = optional.check_elf_listing(relative, 'library => not found', expected)
                self.assertTrue(result['unavailableExpected'])
                self.assertEqual(result['feature'], feature)
                with self.assertRaisesRegex(ValueError, 'Incompatible'):
                    optional.check_elf_listing(relative, "libc.so.6: version `GLIBC_2.40' not found", expected)

    def test_core_and_unrelated_modules_never_inherit_an_optional_exception(self):
        for relative in ('raft_flutter', 'lib/libflutter_linux_gtk.so',
                         'lib/libunrelated_plugin.so', 'lib/other/libraft_system_webview_plugin.so'):
            with self.subTest(relative=relative), self.assertRaisesRegex(ValueError, 'Missing required'):
                optional.check_elf_listing(relative, 'dependency => not found', optional.SCENARIOS['missing-both'])

    def test_missing_probe_and_installed_package_cannot_masquerade_as_clean_absence(self):
        observed = {'features': {feature: {'status': state} for feature, state in
                                 optional.SCENARIOS['missing-both'].items()}}
        packages = {feature: {'installed': False} for feature in optional.FEATURES}
        optional.require_state(observed, optional.SCENARIOS['missing-both'], packages)
        packages['webkit']['installed'] = True
        with self.assertRaisesRegex(ValueError, 'package state'):
            optional.require_state(observed, optional.SCENARIOS['missing-both'], packages)
        observed['features']['mpv']['status'] = 'available'
        with self.assertRaisesRegex(ValueError, 'expected missing'):
            optional.require_state(observed, optional.SCENARIOS['missing-both'])

    def test_dlopen_failures_and_missing_poppler_commands_are_recorded(self):
        with patch.object(optional.ctypes, 'CDLL', side_effect=OSError('lib fixture unavailable')), \
                patch.object(optional.shutil, 'which', return_value=None):
            state = optional.feature_state()
        self.assertEqual({key: value['status'] for key, value in state['features'].items()},
                         optional.SCENARIOS['missing-both'])
        self.assertIn('native app and core messaging NOT_RUN', state['scope'])
        self.assertIn('fixture unavailable', state['features']['webkit']['error'])

    def test_absent_pdf_is_explicitly_not_rendered_and_never_fails_startup_case(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(smoke.shutil, 'which', return_value=None):
            result = smoke.pdf_probe(temporary, 'missing')
            self.assertFalse(result['pdfPageRendered'])
            self.assertTrue(result['pdfFeatureUnavailableExpected'])
            with self.assertRaisesRegex(ValueError, 'optional distribution'):
                smoke.pdf_probe(temporary, 'available')

    def test_artifact_must_match_the_independent_source_bound_receipt(self):
        with tempfile.TemporaryDirectory() as temporary:
            artifact = Path(temporary) / 'fixture.AppImage'
            artifact.write_bytes(b'fixture')
            artifact.with_suffix('.json').write_text(json.dumps({'sha256': '0' * 64, 'commit': 'f' * 40}))
            with self.assertRaisesRegex(ValueError, 'source-bound receipt'):
                optional.artifact_receipt(artifact)

    def test_package_inspection_requires_installed_not_merely_a_dpkg_record(self):
        removed = subprocess.CompletedProcess([], 0, 'deinstall ok config-files\n', '')
        with patch.object(optional.subprocess, 'run', return_value=removed) as command:
            result = optional.package_state('ubuntu')
        self.assertFalse(any(value['installed'] for value in result.values()))
        self.assertTrue(all(call.kwargs['timeout'] == 15 for call in command.call_args_list))

    def test_disposable_script_refuses_execution_before_any_host_package_action(self):
        script = TOOL / 'appimage-optional-test.sh'
        subprocess.run(['bash', '-n', str(script)], check=True)
        result = subprocess.run(['bash', str(script), '--restore-only', 'ubuntu'],
                                env={'PATH': os.defpath, 'GITHUB_ACTIONS': 'false'},
                                capture_output=True, text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('disposable CI Docker container', result.stderr)


if __name__ == '__main__':
    unittest.main()
