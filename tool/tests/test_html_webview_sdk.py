"""The reusable SDK entry point must preserve fixed source and process boundaries."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from html_webview import sdk


class SdkPreparationTest(unittest.TestCase):
    def test_build_key_excludes_machine_work_directory(self):
        environment = {'imageId': 'sha256:' + '1' * 64, 'packagesSha256': '2' * 64,
                       'compilerSha256': '3' * 64, 'backtraceSha256': '4' * 64}
        a = sdk.build_identity(environment)
        self.assertEqual(a, sdk.build_identity(dict(reversed(list(environment.items())))))
        self.assertNotEqual(a, sdk.build_identity({**environment, 'packagesSha256': '5' * 64}))
        self.assertEqual(a['sourceSha256'], sdk.ARCHIVE_SHA256)

    def test_configuration_retains_production_security_and_header_isolation(self):
        args = sdk.configure_command('/work/source', '/work/build', '/work/backtrace')
        self.assertIn('-DENABLE_BUBBLEWRAP_SANDBOX=ON', args)
        self.assertIn('-DENABLE_WPE_PLATFORM_HEADLESS=ON', args)
        self.assertIn('-DCMAKE_C_COMPILER=clang-18', args)
        self.assertIn('-DLIBBACKTRACE_INCLUDE_DIR=/work/backtrace', args)
        self.assertFalse(any('/13/include' in arg for arg in args))
        self.assertFalse(any('DISABLE_SANDBOX' in arg for arg in args))

    def test_compile_selects_only_five_engine_roles_and_inspector_resources(self):
        self.assertEqual(sdk.TARGETS, ('WebKit', 'WebProcess', 'NetworkProcess', 'GPUProcess',
                                     'WPEInjectedBundle', 'InspectorResources'))
        self.assertNotIn('all', sdk.TARGETS)

    def test_image_must_be_an_immutable_local_id(self):
        for image in ['ubuntu:24.04', 'owned:latest', 'sha256:short', 'sha256:' + 'g' * 64]:
            with self.assertRaises(ValueError):
                sdk.image_id(image)
        self.assertEqual(sdk.image_id('sha256:' + 'a' * 64), 'sha256:' + 'a' * 64)

    def test_container_is_capped_and_does_not_enable_host_or_security_bypasses(self):
        args = sdk.container_command('sha256:' + 'a' * 64, Path('/tmp/new-sdk'), 'owned-123', 1000, 1000)
        for option in ['--cpus=2', '--memory=16g', '--cpuset-cpus=0,1', '--network=none', '--user=1000:1000']:
            self.assertIn(option, args)
        self.assertNotIn('--rm', args)
        self.assertNotIn('--privileged', args)
        self.assertFalse(any('security-opt' in arg or '/var/run/docker.sock' in arg for arg in args))
        self.assertIn('readonly', next(arg for arg in args if 'target=/recipe' in arg))

    def test_existing_work_is_not_reused_or_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory) / 'work'
            work.mkdir()
            (work / 'failure.log').write_text('keep')
            with self.assertRaises(ValueError):
                sdk.new_work(work)
            self.assertEqual((work / 'failure.log').read_text(), 'keep')

    def test_invalid_configuration_fails_before_compilation(self):
        text = '#define ENABLE_BUBBLEWRAP_SANDBOX 0\n'
        with self.assertRaises(ValueError):
            sdk.validate_config(text)

    def test_exact_successful_configuration_is_accepted(self):
        text = '\n'.join(f'#define {key} {value}' for key, value in sdk.REQUIRED_FEATURES.items()) + '\n'
        sdk.validate_config(text)
        with self.assertRaises(ValueError):
            sdk.validate_config(text.replace('ENABLE_GPU_PROCESS 1', 'ENABLE_GPU_PROCESS 0'))

    def test_failed_step_has_terminal_receipt_and_retains_its_log(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            with patch.object(sdk.subprocess, 'run', return_value=sdk.subprocess.CompletedProcess(['x'], 9)):
                with self.assertRaises(sdk.subprocess.CalledProcessError):
                    sdk.logged(work, 'failed', ['x'], 2)
            self.assertTrue((work / 'failed.log').is_file())
            self.assertEqual(json.loads((work / 'failed.json').read_text())['exit'], 9)

    def test_install_uses_destdir_without_implicit_ninja_build(self):
        args, env = sdk.install_command('/work/build', '/work/install')
        self.assertEqual(args, ['cmake', '--install', '/work/build', '--config', 'Release'])
        self.assertEqual(env['DESTDIR'], '/work/install')
        self.assertNotIn('ninja', args)

    def test_config_fingerprint_is_part_of_cache_key(self):
        with patch.object(sdk, 'CMAKE_OPTIONS', (*sdk.CMAKE_OPTIONS, '-DFUTURE_FLAG=ON')):
            changed = sdk.build_identity({'imageId': 'sha256:' + 'a' * 64})
        self.assertNotEqual(changed['key'], sdk.build_identity({'imageId': 'sha256:' + 'a' * 64})['key'])


if __name__ == '__main__':
    unittest.main()
