import contextlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
SPEC = importlib.util.spec_from_file_location('release_backfill', TOOL / 'release_backfill.py')
backfill = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(backfill)


class ReleaseBackfillTests(unittest.TestCase):
    tag = 'v1.21.23+10'
    commit = '5e7f6f56863e5af2cf6fae174b795880dffa3ca9'

    def remote(self, **changes):
        metadata = {'tag': self.tag, 'version': '1.21.23', 'buildNumber': '87',
                    'commit': self.commit, 'platforms': [{'platform': 'macos', 'arch': 'arm64'}], **changes}
        return {'tag_name': self.tag, 'body': f'<!-- raft-release:{json.dumps(metadata)} -->'}

    def test_original_provenance_reuses_build_number_instead_of_new_workflow_counter(self):
        identity = backfill.validate_release(self.remote(), self.tag, self.commit, '87')
        self.assertEqual(identity, {'version': '1.21.23', 'build_number': '87',
                                    'tag': self.tag, 'asset_version': '1.21.23+10'})

    def test_wrong_source_number_tag_or_platform_stops(self):
        for change in ({'commit': 'a' * 40}, {'buildNumber': '88'}, {'tag': 'v1.21.23+11'},
                       {'platforms': [{'platform': 'windows', 'arch': 'x64'}]}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                backfill.validate_release(self.remote(**change), self.tag, self.commit, '87')

    def test_branch_names_short_hashes_and_shell_payloads_are_rejected(self):
        for tag, sha, number in [('main', self.commit, '87'), (self.tag, '5e7f6f568', '87'),
                                 (self.tag + '; echo bad', self.commit, '87'),
                                 (self.tag, self.commit, '87\n'), (self.tag, self.commit, '0')]:
            with self.subTest(tag=tag, sha=sha, number=number), self.assertRaises(ValueError):
                backfill.validate_inputs(tag, sha, number)

    def test_checkout_and_tag_both_have_to_match(self):
        for responses in ([self.commit, 'a' * 40], ['a' * 40], [self.commit, self.commit, ' M tracked']):
            with self.subTest(responses=responses), patch.object(backfill.subprocess, 'check_output',
                    side_effect=[s + '\n' for s in responses]), self.assertRaises(ValueError):
                backfill.checked_source(Path('/source'), self.tag, self.commit)

    def test_normal_publisher_still_rejects_manual_events(self):
        with patch.dict(backfill.release.os.environ, {'GITHUB_EVENT_NAME': 'workflow_dispatch'}), \
                self.assertRaisesRegex(ValueError, 'version-tag push'):
            backfill.release.publish('macos')

    def test_build_subprocesses_compile_the_original_source_sha_not_the_workflow_sha(self):
        for platform, arch in [('macos', 'arm64'), ('appimage', 'x64')]:
            environment = {'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_SHA': 'a' * 40,
                           'GITHUB_RUN_NUMBER': '999', 'BACKFILL_TAG': self.tag,
                           'BACKFILL_COMMIT': self.commit, 'BACKFILL_BUILD_NUMBER': '87',
                           'BACKFILL_PLATFORM': platform}
            remote = self.remote(platforms=[{'platform': platform, 'arch': arch}])
            with self.subTest(platform=platform), \
                    patch.dict(backfill.os.environ, environment), \
                    patch.object(sys, 'argv', ['release_backfill.py', 'build', '--source', '/source']), \
                    patch.object(backfill.os, 'chdir'), \
                    patch.object(backfill, 'checked_source'), \
                    patch.object(backfill, 'existing_release', return_value=remote), \
                    patch.object(backfill, 'verify_hosted_runner') as verify_runner, \
                    patch.object(backfill.release, 'verify_artifacts'), \
                    patch.object(backfill.subprocess, 'run') as run:
                backfill.main()
                verify_runner.assert_called_once_with(Path('/source'), platform)
                self.assertEqual(run.call_count, 4 if platform == 'appimage' else 3)
                if platform == 'appimage':
                    self.assertEqual(Path(run.call_args_list[1].args[0][1]).name, 'prepare-media-appimage')
                for call in run.call_args_list:
                    env = call.kwargs['env']
                    self.assertEqual(env['GITHUB_SHA'], self.commit)
                    defines = backfill.release.release_defines('1.21.23', '87', env, self.tag)
                    self.assertEqual(defines['RAFT_COMMIT_SHA'], self.commit)
                    self.assertEqual(env['GITHUB_RUN_NUMBER'], '87')


class HostedBackfillRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name)
        (self.source / '.fvmrc').write_text(json.dumps({'flutter': '3.47.6'}))

    @contextlib.contextmanager
    def hosted_tools(self, selected='macos', *, environment='github-hosted',
                     machine=None, distribution='24.04', flutter='3.47.6',
                     ruby='ruby 3.3.8', pod='1.16.2', json_gem='2.18.0', missing=None):
        system = 'Darwin' if selected == 'macos' else 'Linux'
        machine = machine or ('arm64' if selected == 'macos' else 'x86_64')

        def output(command, **_):
            if '--machine' in command:
                return json.dumps({'frameworkVersion': flutter})
            if '-rjson' in command:
                return json_gem
            return pod if Path(command[0]).name == 'pod' else ruby

        with patch.dict(backfill.os.environ, {'RUNNER_ENVIRONMENT': environment}, clear=True), \
                patch.object(backfill.host_platform, 'system', return_value=system), \
                patch.object(backfill.host_platform, 'machine', return_value=machine), \
                patch.object(backfill.host_platform, 'python_version', return_value='3.12.3'), \
                patch.object(backfill.host_platform, 'freedesktop_os_release',
                             return_value={'ID': 'ubuntu', 'VERSION_ID': distribution}), \
                patch.object(backfill.shutil, 'which',
                             side_effect=lambda name: None if name == missing else '/hosted/bin/' + name), \
                patch.object(backfill.subprocess, 'check_output', side_effect=output), \
                patch.object(backfill.subprocess, 'run'):
            yield

    def test_hosted_native_tools_bind_the_original_sdk_without_private_cache_roots(self):
        for selected in ('macos', 'appimage'):
            with self.subTest(platform=selected), self.hosted_tools(selected):
                backfill.verify_hosted_runner(self.source, selected)
                self.assertEqual(backfill.os.environ['RAFT_FLUTTER_BIN'], '/hosted/bin/flutter')

    def test_self_hosted_wrong_architecture_or_newer_linux_abi_is_rejected(self):
        cases = [('macos', {'environment': 'self-hosted'}),
                 ('macos', {'machine': 'x86_64'}),
                 ('appimage', {'machine': 'aarch64'}),
                 ('appimage', {'distribution': '26.04'})]
        for selected, options in cases:
            with self.subTest(platform=selected, options=options), self.hosted_tools(selected, **options), \
                    self.assertRaises(ValueError):
                backfill.verify_hosted_runner(self.source, selected)

    def test_missing_tools_or_original_sdk_and_gem_drift_stop_before_build(self):
        for options in ({'missing': 'codesign'}, {'flutter': '3.44.0'},
                        {'ruby': 'ruby 3.4.0'}, {'pod': '1.17.0'}, {'json_gem': '2.19.0'}):
            with self.subTest(options=options), self.hosted_tools(**options), self.assertRaises(ValueError):
                backfill.verify_hosted_runner(self.source, 'macos')


if __name__ == '__main__':
    unittest.main()
