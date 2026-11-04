"""Normal release SDK trust/dataflow checks; no Docker, Actions or native run."""
from contextlib import contextmanager
import itertools
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tool.tests import test_html_webview_payload as fixtures


def job(text, name):
    match = re.search(r'^  ' + re.escape(name) + r':\n(.*?)(?=^  [\w-]+:\n|\Z)', text, re.M | re.S)
    if not match:
        raise AssertionError('Missing workflow job: ' + name)
    return match[1]


def step(text, identifier):
    match = re.search(r'^      - id: ' + re.escape(identifier) +
                      r'\n(.*?)(?=^      - |\Z)', text, re.M | re.S)
    if not match:
        raise AssertionError('Missing workflow step: ' + identifier)
    return match[1]


def script(text):
    match = re.search(r"^          python - <<'PY'\n(.*?)^          PY$", text, re.M | re.S)
    if not match:
        raise AssertionError('Missing inline Python')
    return textwrap.dedent(match[1])


@contextmanager
def cwd(path):
    old = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(old)


class ReleaseHtmlSdkWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.release = (ROOT / '.github/workflows/release.yml').read_text()
        self.consumer = (ROOT / '.github/workflows/release-platform.yml').read_text()

    def run_script(self, source, root, environment):
        with cwd(root), patch.dict(os.environ, environment, clear=True):
            exec(compile(source, '<actual workflow Python>', 'exec'), {})

    def test_plan_splits_every_platform_subset_without_creating_extra_platforms(self):
        source = script(step(job(self.release, 'plan'), 'sdk-plan'))
        platforms = ['windows', 'android', 'linux', 'appimage', 'macos']
        for enabled in itertools.product([False, True], repeat=len(platforms)):
            rows = [{'platform': p, 'arch': 'x64', 'runner': 'old-runner'}
                    for p, on in zip(platforms, enabled) if on]
            with self.subTest(rows=rows), tempfile.TemporaryDirectory() as temp:
                output = Path(temp) / 'outputs'
                self.run_script(source, temp, {'RELEASE_MATRIX': json.dumps({'include': rows}),
                                              'GITHUB_OUTPUT': str(output)})
                values = dict(line.split('=', 1) for line in output.read_text().splitlines())
                independent = json.loads(values['independent_matrix'])['include']
                linux = json.loads(values['linux_matrix'])['include']
                self.assertEqual(independent, [r for r in rows if r['platform'] not in {'linux', 'appimage'}])
                self.assertEqual([r['platform'] for r in linux],
                                 [r['platform'] for r in rows if r['platform'] in {'linux', 'appimage'}])
                self.assertTrue(all(r['runner'] == 'ubuntu-24.04' for r in linux))
                self.assertEqual(values['has_linux'], str(bool(linux)).lower())
                self.assertEqual(values['has_independent'], str(bool(independent)).lower())

    def test_non_linux_has_no_sdk_dependency_and_linux_requires_success(self):
        independent = job(self.release, 'platform')
        self.assertIn('needs: [plan, prepare-release]', independent)
        self.assertNotIn('needs.html-sdk', independent)
        self.assertIn('has_independent', independent)
        self.assertIn('independent_matrix', independent)
        linux = job(self.release, 'linux-platform')
        self.assertIn('needs: [plan, prepare-release, html-sdk]', linux)
        self.assertIn('linux_matrix', linux)
        self.assertIn("needs.html-sdk.result == 'success'", linux)
        self.assertIn("needs.plan.outputs.has_linux == 'true'", linux)
        self.assertIn('!cancelled()', independent)
        self.assertIn('!cancelled()', linux)
        for text in (independent, linux):
            self.assertIn("github.event_name != 'push' || needs.prepare-release.result == 'success'", text)
            self.assertIn('uses: ./.github/workflows/release-platform.yml', text)
            self.assertIn("publish: ${{ github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v') }}", text)

    def test_both_noble_consumers_execute_noble_media_preparation(self):
        block = re.search(r'      - name: Install Linux build and media dependencies\n'
                          r'.*?        run: \|\n(.*?)(?=      - name:)',
                          self.consumer, re.S).group(1)
        for platform in ['linux', 'appimage']:
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                calls = directory / 'calls'
                for name in ['sudo', 'python']:
                    stub = directory / name
                    stub.write_text('#!/bin/sh\nprintf "%s %s\\n" "${0##*/}" "$*" >> "$QA_CALLS"\n')
                    stub.chmod(0o755)
                body = textwrap.dedent(block).replace('${{ inputs.platform }}', platform)
                subprocess.run(['/bin/bash', '-eu', '-c', body], check=True,
                               env={'PATH': f'{directory}:/usr/bin:/bin', 'QA_CALLS': str(calls)})
                media = [line for line in calls.read_text().splitlines()
                         if line.startswith('python tool/prepare-media')]
                self.assertEqual(media, ['python tool/prepare-media-appimage'])

    def test_actual_job_conditions_do_not_skip_independent_platforms_when_sdk_fails(self):
        states = ['success', 'failure', 'cancelled', 'skipped']
        for name in ['platform', 'html-sdk', 'linux-platform']:
            text = job(self.release, name)
            expression = re.search(r'if: >-\n(.*?)\n    needs:', text, re.S).group(1).strip()
            expression = expression.removeprefix('${{').removesuffix('}}').strip()
            for event, cancelled, plan, prepare, sdk, selected in itertools.product(
                    ['push', 'workflow_dispatch'], [False, True], states, states, states, [False, True]):
                values = {'!cancelled()': not cancelled, 'needs.plan.result': plan,
                          'needs.prepare-release.result': prepare, 'needs.html-sdk.result': sdk,
                          'needs.plan.outputs.has_linux': str(selected).lower(),
                          'needs.plan.outputs.has_independent': str(selected).lower(), 'github.event_name': event}
                rendered = expression
                for key, value in values.items():
                    rendered = rendered.replace(key, repr(value))
                actual = eval(' '.join(rendered.replace('&&', ' and ').replace('||', ' or ').split()),
                              {'__builtins__': {}}, {})
                expected = (not cancelled and plan == 'success' and selected
                            and (event != 'push' or prepare == 'success')
                            and (name != 'linux-platform' or sdk == 'success'))
                self.assertEqual(actual, expected, (name, values))

    def test_one_source_producer_has_bounded_build_and_retains_failures(self):
        producer = job(self.release, 'html-sdk')
        self.assertEqual(self.release.count('python -m tool.html_webview.sdk build'), 1)
        self.assertRegex(producer, r'timeout-minutes: (?:[1-9]\d?|1\d\d|20\d|210)\n')
        self.assertIn('--max-seconds 10800', producer)
        self.assertIn('runs-on: ubuntu-24.04', producer)
        self.assertIn("needs.plan.outputs.has_linux == 'true'", producer)
        for argument in ('--no-cache', '--pull', '--cpuset-cpus=0,1', '--memory=16g',
                         '--memory-swap=16g', '--cpu-quota=200000',
                         'RAFT_HTML_SDK_ENFORCE_LIMITS=1', 'DOCKER_BUILDKIT: \'0\''):
            self.assertIn(argument, producer)
        self.assertNotIn('actions/cache', producer)
        self.assertIn('if: always()', producer)
        self.assertIn('build/html-sdk/*.log', producer)
        self.assertIn('build/html-sdk/*.json', producer)
        self.assertNotIn('gh release', producer)

    def test_source_download_uses_the_reviewed_url_and_hash_before_build(self):
        producer = job(self.release, 'html-sdk')
        download = step(producer, 'source')
        self.assertIn('from tool.html_webview.prepare_source import ARCHIVE_SHA256, VERSION, sha256', download)
        self.assertIn('https://wpewebkit.org/releases/wpewebkit-', download)
        self.assertIn("'--proto', '=https'", download)
        self.assertIn('sha256(archive) != ARCHIVE_SHA256', download)
        self.assertLess(producer.index('- id: source'), producer.index('- id: source-build'))
        self.assertIn('image=$(cat build/html-sdk-image-id)', producer)
        self.assertIn('--image "$image"', producer)

    def producer_fixture(self, temp):
        fixture = fixtures.HtmlPayloadTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        work = Path(temp) / 'build/html-sdk'
        work.mkdir(parents=True)
        import shutil
        shutil.copytree(fixture.sdk, work / 'sdk')
        archive, pin = fixture.archive()
        shutil.copy2(archive, work / 'sdk.tar.gz')
        record = {'state': 'sdk-ready', 'prefix': 'sdk', 'archive': 'sdk.tar.gz',
                  'archiveSha256': pin, 'manifestSha256': fixture.pin}
        (work / 'result.json').write_text(json.dumps(record))
        return work, record

    def test_producer_outputs_both_hashes_only_after_complete_content_verification(self):
        source = script(step(job(self.release, 'html-sdk'), 'sdk-pins'))
        for defect in [None, 'archive', 'manifest', 'content', 'incomplete']:
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as temp:
                work, record = self.producer_fixture(temp)
                output = Path(temp) / 'outputs'
                if defect == 'archive':
                    (work / 'sdk.tar.gz').write_bytes(b'changed')
                elif defect == 'manifest':
                    record['manifestSha256'] = '0' * 64
                elif defect == 'content':
                    (work / 'sdk/include/fixture.h').write_text('changed')
                elif defect == 'incomplete':
                    record['state'] = 'failed'
                (work / 'result.json').write_text(json.dumps(record))
                env = {'GITHUB_OUTPUT': str(output)}
                if defect:
                    with self.assertRaises(ValueError):
                        self.run_script(source, temp, env)
                    self.assertFalse(output.exists())
                else:
                    self.run_script(source, temp, env)
                    self.assertEqual(dict(line.split('=', 1) for line in output.read_text().splitlines()),
                                     {'archive_sha256': record['archiveSha256'],
                                      'manifest_sha256': record['manifestSha256']})

    def test_linux_consumers_receive_same_run_artifact_and_two_trusted_pins(self):
        linux = job(self.release, 'linux-platform')
        for field in ('html_sdk_artifact_id', 'html_sdk_archive_sha256', 'html_sdk_manifest_sha256'):
            self.assertIn(field + ':', linux)
            self.assertIn(field + ':', self.consumer)
        self.assertIn('${{ needs.html-sdk.outputs.artifact_id }}', linux)
        self.assertIn('${{ needs.html-sdk.outputs.archive_sha256 }}', linux)
        self.assertIn('${{ needs.html-sdk.outputs.manifest_sha256 }}', linux)
        self.assertIn('artifact-ids: ${{ inputs.html_sdk_artifact_id }}', self.consumer)
        restore = step(job(self.consumer, 'build'), 'html-sdk-restore')
        self.assertIn('python -m tool.html_webview.sdk restore', restore)
        self.assertIn('--sha256 "$HTML_SDK_ARCHIVE_SHA256"', restore)
        for name in ('RAFT_HTML_WEBVIEW_SDK', 'RAFT_HTML_WEBVIEW_MANIFEST_SHA256',
                     'PKG_CONFIG_PATH', 'LIBRARY_PATH'):
            self.assertIn(name, restore)
        self.assertLess(self.consumer.index('- id: html-sdk-restore'),
                        self.consumer.index('name: Resolve locked dependencies'))

    def test_missing_artifact_or_pin_fails_before_download_not_download_everything(self):
        source = script(step(job(self.consumer, 'build'), 'html-sdk-contract'))
        environment = {'HTML_SDK_ARCH': 'x64', 'HTML_SDK_ARTIFACT_ID': '123',
                       'HTML_SDK_ARCHIVE_SHA256': 'a' * 64, 'HTML_SDK_MANIFEST_SHA256': 'b' * 64}
        with tempfile.TemporaryDirectory() as temp:
            self.run_script(source, temp, environment)
            for name in environment:
                for wrong in ['', 'unknown', '0', 'a' * 63]:
                    with self.subTest(name=name, wrong=wrong), self.assertRaises(ValueError):
                        self.run_script(source, temp, {**environment, name: wrong})
        self.assertLess(self.consumer.index('- id: html-sdk-contract'),
                        self.consumer.index('name: Download the same-run source-built Linux HTML SDK'))

    def test_restore_pin_mismatch_cannot_publish_sdk_environment(self):
        source = script(step(job(self.consumer, 'build'), 'html-sdk-restore'))
        for wrong in [None, 'archive', 'manifest', 'prefix']:
            with self.subTest(wrong=wrong), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                prefix = root / 'sdk'
                prefix.mkdir()
                record = {'prefix': str(prefix), 'archiveSha256': 'a' * 64, 'manifestSha256': 'b' * 64}
                if wrong:
                    record[{'archive': 'archiveSha256', 'manifest': 'manifestSha256', 'prefix': 'prefix'}[wrong]] = 'c' * 64
                (root / 'restore.json').write_text(json.dumps(record))
                env = {'GITHUB_ENV': str(root / 'environment'), 'HTML_SDK_RESTORE_JSON': str(root / 'restore.json'),
                       'HTML_SDK_DESTINATION': str(prefix), 'HTML_SDK_ARCHIVE_SHA256': 'a' * 64,
                       'HTML_SDK_MANIFEST_SHA256': 'b' * 64}
                if wrong:
                    with self.assertRaises(ValueError):
                        self.run_script(source, temp, env)
                    self.assertFalse((root / 'environment').exists())
                else:
                    self.run_script(source, temp, env)
                    exported = dict(line.split('=', 1) for line in (root / 'environment').read_text().splitlines())
                    self.assertEqual(exported['RAFT_HTML_WEBVIEW_SDK'], str(prefix))
                    self.assertEqual(exported['RAFT_HTML_WEBVIEW_MANIFEST_SHA256'], 'b' * 64)

    def test_consumer_keeps_timeout_signed_apt_dependencies_and_pinned_wrapper(self):
        build = job(self.consumer, 'build')
        self.assertIn('timeout-minutes: 60', build)
        for dependency in ('libgtk-3-dev', 'libsecret-1-dev', 'libsoup-3.0-dev', 'libjson-glib-dev',
                           'libepoxy-dev', 'libwayland-dev', 'nlohmann-json3-dev'):
            self.assertIn(dependency, build)
        self.assertNotIn('--allow-unauthenticated', build)
        self.assertIn('run: python tool/flutter pub get --enforce-lockfile', build)
        self.assertIn('run: python tool/release.py build ${{ inputs.platform }}', build)
        # The original per-platform publishing/signing policy remains separate.
        self.assertIn('needs: [build, appimage-compatibility]', job(self.consumer, 'publish'))
        self.assertIn('RAFT_ANDROID_KEYSTORE_BASE64', build)
        self.assertIn('SPARKLE_ED_PRIVATE_KEY', self.consumer)


if __name__ == '__main__':
    unittest.main()
