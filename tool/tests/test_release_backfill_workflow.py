"""Release-gate regression checks against the actual backfill workflow."""
import itertools
import json
from pathlib import Path
import re
import unittest


WORKFLOW = Path(__file__).resolve().parents[2] / '.github/workflows/release-backfill.yml'


class BackfillWorkflowTests(unittest.TestCase):
    def test_publisher_requires_successful_linux_startup_and_fedora_checks(self):
        text = WORKFLOW.read_text()
        publish = text.split('\n  publish:\n', 1)[1]
        self.assertRegex(publish, r'needs: \[build, appimage-startup, appimage-compatibility\]')
        expression = re.search(r'if: >-\n(.*?)\n    needs:', publish, re.S).group(1).strip()
        expression = expression.removeprefix('${{').removesuffix('}}').strip()
        for platform, enabled, cancelled, build, startup, compatibility in itertools.product(
                ['macos', 'appimage'], [False, True], [False, True],
                ['success', 'failure', 'cancelled', 'skipped'],
                ['success', 'failure', 'cancelled', 'skipped'],
                ['success', 'failure', 'cancelled', 'skipped']):
            rendered = expression
            values = {'!cancelled()': not cancelled, 'inputs.publish': enabled,
                      'inputs.platform': platform, 'needs.build.result': build,
                      'needs.appimage-startup.result': startup,
                      'needs.appimage-compatibility.result': compatibility}
            for key, value in values.items():
                rendered = rendered.replace(key, repr(value))
            rendered = rendered.replace('&&', ' and ').replace('||', ' or ')
            allowed = eval(' '.join(rendered.split()), {'__builtins__': {}}, {})
            expected = enabled and not cancelled and build == 'success' and (
                platform != 'appimage' or (startup == 'success' and compatibility == 'success'))
            self.assertEqual(allowed, expected, (platform, enabled, cancelled, build, startup, compatibility))

    def test_startup_uses_original_source_and_preserves_failure_evidence(self):
        text = WORKFLOW.read_text()
        build = text.split('\n  appimage-startup:\n', 1)[1].split('\n  appimage-compatibility:\n', 1)[0]
        self.assertIn('runs-on: ubuntu-24.04', build)
        self.assertIn('ref: ${{ inputs.release_tag }}', build)
        self.assertIn('needs: build', build)
        self.assertIn("-screen 0 2880x1800x24", build)
        for mode in ['direct', 'extract']:
            self.assertIn(f'python tool/appimage-smoke.py --artifact "$artifact" --output build/appimage-smoke --mode {mode}', build)
        self.assertIn('working-directory: source', build)
        self.assertIn('if: always()', build)
        compatibility = text.split('\n  appimage-compatibility:\n', 1)[1].split('\n  publish:\n', 1)[0]
        self.assertIn('needs: build', compatibility)
        self.assertIn('ref: ${{ inputs.release_tag }}', compatibility)
        self.assertIn('fedora:44 bash /source/tool/appimage-fedora-test.sh', compatibility)
        self.assertNotIn('/dev/fuse', compatibility)
        self.assertIn('if: always()', compatibility)

    def test_hosted_build_installs_tools_for_the_original_checkout_without_service_hooks(self):
        text = WORKFLOW.read_text()
        build = text.split('\n  build:\n', 1)[1].split('\n  appimage-startup:\n', 1)[0]
        self.assertIn("inputs.platform == 'macos' && 'macos-15' || 'ubuntu-24.04'", build)
        self.assertIn('flutter-version-file: source/.fvmrc', build)
        self.assertIn('architecture: ${{ runner.arch }}', build)
        for tool in ('actions/setup-python@v5', 'ruby/setup-ruby@v1', 'sudo apt-get install'):
            self.assertIn(tool, build)
        warmup = build.index('name: Initialize the downloaded Flutter SDK')
        verify_and_build = build.index('name: Build the exact original source and build number')
        self.assertLess(build.index('flutter-version-file:'), warmup)
        self.assertLess(warmup, verify_and_build)
        self.assertIn('shell: bash', build[warmup:verify_and_build])
        self.assertIn('run: flutter --version --machine', build[warmup:verify_and_build])
        self.assertNotIn('||', build[warmup:verify_and_build])
        self.assertNotIn('RAFT_LINUX_RUNNER_FINISH_HOOK', text)
        self.assertNotIn('raft-macos-arm64-data', text)
        self.assertNotIn('raft-linux-x64-data', text)

    def test_active_release_matrix_and_packaging_setup_use_native_hosted_runners(self):
        root = WORKFLOW.parents[2]
        config = json.loads((root / 'tool/release-platforms.json').read_text())
        self.assertEqual(config['macos']['runner'], 'macos-15')
        self.assertEqual(config['appimage']['runner'], 'ubuntu-24.04')
        self.assertFalse(config['linux']['enabled'])
        self.assertEqual(config['linux']['runner'], 'ubuntu-26.04')
        normal = (WORKFLOW.parent / 'release-platform.yml').read_text()
        self.assertNotIn('raft-macos-arm64-data', normal)
        self.assertNotIn('tool/macos_runner.py', normal)
        self.assertIn('test "$RUNNER_ENVIRONMENT" = github-hosted', normal)
        self.assertIn('test "$RUNNER_ARCH" = ARM64', normal)
        self.assertIn('test "$RUNNER_ARCH" = X64', normal)
        self.assertIn('test "$VERSION_ID" = 24.04', normal)
        self.assertIn('architecture: ${{ runner.arch }}', normal)


if __name__ == '__main__':
    unittest.main()
