import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'probe_test_guard', Path(__file__).resolve().parents[1] / 'probe_test_guard.py')
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


class ProbeNameTests(unittest.TestCase):
    """The matching rule itself, without needing a repository."""

    def test_leading_underscore_test_is_a_probe(self):
        for path in [
            'packages/raft_ui/test/_p_test.dart',
            'packages/raft_ui/test/_probe_buttons_test.dart',
            'apps/raft_flutter/test/_d3_test.dart',
            'apps/raft_flutter/test/_zz_probe_test.dart',
        ]:
            self.assertTrue(guard.is_probe_test(path), path)

    def test_probe_in_the_name_is_not_enough(self):
        # Eight real tests in this repository contain "probe" (video frame
        # probing, MP4 header parsing, provider probing). Matching on it would
        # reject future edits to all of them, so only the leading underscore
        # counts. These paths are the actual ones.
        for path in [
            'apps/raft_flutter/test/mp4_hdr_probe_test.dart',
            'apps/raft_flutter/test/video_frame_probe_mpv_test.dart',
            'apps/raft_flutter/test/video_frame_probe_test.dart',
            'packages/raft_client/test/provider_probe_test.dart',
            'packages/raft_ui/test/text_scale_audit_probe_test.dart',
        ]:
            self.assertFalse(guard.is_probe_test(path), path)

    def test_ordinary_tests_are_allowed(self):
        for path in [
            'packages/raft_ui/test/button_metrics_theme_test.dart',
            'apps/raft_flutter/test/startup_appearance_test.dart',
            'packages/raft_theme/test/family_packs_test.dart',
        ]:
            self.assertFalse(guard.is_probe_test(path), path)

    def test_non_test_files_are_ignored(self):
        for path in [
            'packages/raft_ui/lib/_private.dart',
            'tool/_helper.py',
            'packages/raft_ui/test/support/_fixtures.dart',
            'app_icons/_probe.png',
        ]:
            self.assertFalse(guard.is_probe_test(path), path)

    def test_a_test_outside_a_test_directory_is_ignored(self):
        # `*_test.dart` outside test/ is not how this repository runs tests, and
        # the hook must not reason about it.
        self.assertFalse(guard.is_probe_test('tool/_fake_test.dart'))


class StagedFilesTests(unittest.TestCase):
    """The hook end to end: a real index, a real refusal."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self._git('init', '-q')
        self._git('config', 'user.email', 'test@example.invalid')
        self._git('config', 'user.name', 'Test')
        (self.root / 'README.md').write_text('x\n')
        self._git('add', 'README.md')
        self._git('commit', '-qm', 'base')

    def _git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True,
                              capture_output=True, text=True).stdout

    def _stage(self, relative: str):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('void main() {}\n')
        self._git('add', relative)

    def test_staged_probe_is_rejected(self):
        self._stage('packages/raft_ui/test/_scratch_test.dart')
        self.assertEqual(guard.main(['--root', str(self.root)]), 1)

    def test_staged_probe_is_named_in_the_message(self):
        self._stage('packages/raft_ui/test/_scratch_two_test.dart')
        result = subprocess.run(
            [__import__('sys').executable, str(Path(guard.__file__)), '--root', str(self.root)],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('_scratch_two_test.dart', result.stderr)
        # The message must say where probes belong, or the author only learns "no".
        self.assertIn('/tmp/', result.stderr)

    def test_staged_real_test_is_allowed(self):
        self._stage('packages/raft_ui/test/button_metrics_theme_test.dart')
        self.assertEqual(guard.main(['--root', str(self.root)]), 0)

    def test_modifying_an_existing_probe_is_allowed(self):
        # Only ADDED files are checked: an old probe that is being edited or
        # removed must not trap the author.
        self._stage('packages/raft_ui/test/_old_test.dart')
        self._git('commit', '-qm', 'probe landed before the hook', '--no-verify')
        path = self.root / 'packages/raft_ui/test/_old_test.dart'
        path.write_text('void main() { /* edited */ }\n')
        self._git('add', 'packages/raft_ui/test/_old_test.dart')
        self.assertEqual(guard.main(['--root', str(self.root)]), 0)

    def test_explicit_paths_are_checked_without_git(self):
        # The same rule via --paths, which is how a caller can dry-run it.
        self.assertEqual(guard.main(['--root', str(self.root),
                                     'packages/x/test/_p_test.dart']), 1)
        self.assertEqual(guard.main(['--root', str(self.root),
                                     'packages/x/test/real_test.dart']), 0)


class HookWiringTests(unittest.TestCase):
    """The hook script itself must actually call the guard."""


    def test_hook_without_the_guard_still_lets_a_commit_through(self):
        """A copy of the hook in a bare repository must not fail."""
        import shutil
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            hooks = root / 'hooks'
            hooks.mkdir()
            shutil.copy(
                Path(__file__).resolve().parents[2] / 'tool/git-hooks/pre-commit',
                hooks / 'pre-commit')
            subprocess.run(['git', 'init', '-q'], cwd=root, check=True)
            subprocess.run(['git', 'config', 'user.email', 't@e.invalid'], cwd=root, check=True)
            subprocess.run(['git', 'config', 'user.name', 'T'], cwd=root, check=True)
            (root / 'a.txt').write_text('x')
            subprocess.run(['git', 'add', 'a.txt'], cwd=root, check=True)
            result = subprocess.run(['sh', str(hooks / 'pre-commit')], cwd=root,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, '')

    def test_pre_commit_runs_the_guard_and_propagates_failure(self):
        hook = (Path(__file__).resolve().parents[2] / 'tool/git-hooks/pre-commit').read_text()
        self.assertIn('probe_test_guard.py', hook)
        # A bare invocation would swallow the rejection and let the commit through.
        self.assertRegex(hook, r'"\$python" "\$guard"[^\n]*\|\|\s*exit')

    def test_guard_is_located_next_to_the_hook_not_in_the_repository(self):
        # Tests copy the hook into a scratch repository with no tool/ directory;
        # resolving the guard from $root there makes the hook exit 2 and fails
        # those tests. It must resolve from the hook's own directory and step
        # aside when the guard is not there.
        hook = (Path(__file__).resolve().parents[2] / 'tool/git-hooks/pre-commit').read_text()
        self.assertIn('dirname -- "$0"', hook)
        self.assertIn('guard="$hook_dir/../probe_test_guard.py"', hook)
        self.assertRegex(hook, r'if \[ -f "\$guard" \]')
        # Absence must be silent: the hook tests assert empty stderr on a no-op run.
        self.assertNotIn('probe-test guard not found', hook)


if __name__ == '__main__':
    unittest.main()
