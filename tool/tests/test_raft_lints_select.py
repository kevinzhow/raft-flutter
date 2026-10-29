import importlib.machinery
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]


def load(name, filename):
    loader = importlib.machinery.SourceFileLoader(name, str(TOOL / filename))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


lints = load('raft_lints_runner', 'raft-lints')
sync = load('sync_pub_lock', 'sync-pub-lock')
install = load('install_git_hooks', 'install-git-hooks')


def git(root, *args):
    env = {**os.environ, 'GIT_AUTHOR_NAME': 't', 'GIT_AUTHOR_EMAIL': 't@t', 'GIT_COMMITTER_NAME': 't', 'GIT_COMMITTER_EMAIL': 't@t'}
    out = subprocess.run(['git', '-C', str(root), *args], capture_output=True, text=True, env=env)
    assert out.returncode == 0, out.stderr
    return out.stdout


def write(root, name, text='x\n'):
    path = Path(root) / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


class TempRepo(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.root = Path(self.dir.name)
        git(self.root, 'init', '-q', '-b', 'main')
        git(self.root, 'config', 'commit.gpgsign', 'false')

    def commit(self, message='c'):
        git(self.root, 'add', '-A')
        git(self.root, 'commit', '-q', '-m', message)


class LintTargetTests(unittest.TestCase):
    def test_only_lib_dart_of_the_scanned_packages(self):
        yes = ['apps/raft_flutter/lib/a.dart', 'apps/raft_flutter/lib/x/y/b.dart', 'packages/raft_ui/lib/src/c.dart']
        no = ['apps/raft_flutter/test/a_test.dart', 'packages/raft_ui/test/x.dart', 'tool/raft_lints/lib/main.dart',
              'apps/raft_flutter/lib/a.txt', 'apps/raft_flutter/tool/bindings_generator/lib/x.dart',
              'packages/raft_ui/lib/src/glyphs.g.dart', 'apps/other/lib/a.dart', 'packages/lib/a.dart', 'lib/a.dart']
        self.assertEqual([p for p in yes if lints.is_lint_target(p)], yes)
        self.assertEqual([p for p in no if lints.is_lint_target(p)], [])


class ChangedFilesTests(TempRepo):
    def setUp(self):
        super().setUp()
        for name in ['apps/raft_flutter/lib/keep.dart', 'apps/raft_flutter/lib/edit.dart', 'apps/raft_flutter/lib/gone.dart',
                     'packages/raft_ui/lib/ui.dart', 'apps/raft_flutter/test/t_test.dart']:
            write(self.root, name)
        self.commit('base')
        git(self.root, 'branch', 'base')
        git(self.root, 'checkout', '-q', '-b', 'work')

    def changed(self):
        return lints.changed_files(self.root, 'base')

    def test_nothing_changed(self):
        self.assertEqual(self.changed(), [])

    def test_committed_staged_unstaged_and_untracked_are_all_selected(self):
        write(self.root, 'apps/raft_flutter/lib/committed.dart')
        self.commit('committed')
        write(self.root, 'packages/raft_ui/lib/staged.dart')
        git(self.root, 'add', 'packages/raft_ui/lib/staged.dart')
        write(self.root, 'apps/raft_flutter/lib/edit.dart', 'edited\n')
        write(self.root, 'apps/raft_flutter/lib/untracked.dart')
        self.assertEqual(self.changed(), [
            'apps/raft_flutter/lib/committed.dart', 'apps/raft_flutter/lib/edit.dart',
            'apps/raft_flutter/lib/untracked.dart', 'packages/raft_ui/lib/staged.dart'])

    def test_non_lib_generated_deleted_and_ignored_files_are_dropped(self):
        write(self.root, 'apps/raft_flutter/test/t_test.dart', 'edited\n')
        write(self.root, 'apps/raft_flutter/lib/new.g.dart')
        write(self.root, 'apps/raft_flutter/lib/readme.md')
        write(self.root, 'tool/raft_lints/lib/main.dart')
        write(self.root, '.gitignore', 'apps/raft_flutter/lib/ignored.dart\n')
        write(self.root, 'apps/raft_flutter/lib/ignored.dart')
        (self.root / 'apps/raft_flutter/lib/gone.dart').unlink()
        self.assertEqual(self.changed(), [])
        git(self.root, 'rm', '-q', '--cached', 'apps/raft_flutter/lib/keep.dart')
        (self.root / 'apps/raft_flutter/lib/keep.dart').unlink()
        self.assertEqual(self.changed(), [])

    def test_changes_already_on_the_base_are_not_selected(self):
        git(self.root, 'checkout', '-q', 'base')
        write(self.root, 'apps/raft_flutter/lib/upstream.dart')
        self.commit('upstream moved on')
        git(self.root, 'checkout', '-q', 'work')
        write(self.root, 'apps/raft_flutter/lib/mine.dart')
        self.assertEqual(lints.changed_files(self.root, 'main'), ['apps/raft_flutter/lib/mine.dart'])

    def test_renamed_file_is_selected_under_its_new_name(self):
        git(self.root, 'mv', 'apps/raft_flutter/lib/edit.dart', 'apps/raft_flutter/lib/renamed.dart')
        self.assertEqual(self.changed(), ['apps/raft_flutter/lib/renamed.dart'])

    def test_unknown_base_explains_itself(self):
        with self.assertRaisesRegex(RuntimeError, 'merge-base with nope'):
            lints.changed_files(self.root, 'nope')

    def test_staged_files_ignore_unstaged_and_untracked(self):
        write(self.root, 'apps/raft_flutter/lib/staged.dart')
        git(self.root, 'add', 'apps/raft_flutter/lib/staged.dart')
        write(self.root, 'apps/raft_flutter/lib/edit.dart', 'edited\n')
        write(self.root, 'apps/raft_flutter/lib/untracked.dart')
        write(self.root, 'apps/raft_flutter/test/staged_test.dart')
        git(self.root, 'add', 'apps/raft_flutter/test/staged_test.dart')
        self.assertEqual(lints.staged_files(self.root), ['apps/raft_flutter/lib/staged.dart'])

    def test_staged_deletion_is_not_selected(self):
        git(self.root, 'rm', '-q', 'apps/raft_flutter/lib/gone.dart')
        self.assertEqual(lints.staged_files(self.root), [])

    def test_filenames_with_spaces_survive(self):
        write(self.root, 'apps/raft_flutter/lib/with space.dart')
        self.assertEqual(self.changed(), ['apps/raft_flutter/lib/with space.dart'])


class ParseTests(unittest.TestCase):
    def test_modes(self):
        self.assertEqual(lints.parse([]), ('full', lints.DEFAULT_BASE, []))
        self.assertEqual(lints.parse(['a.dart', 'lib']), ('paths', lints.DEFAULT_BASE, ['a.dart', 'lib']))
        self.assertEqual(lints.parse(['--changed']), ('changed', lints.DEFAULT_BASE, []))
        self.assertEqual(lints.parse(['--changed', '--base', 'origin/x']), ('changed', 'origin/x', []))
        self.assertEqual(lints.parse(['--base=main', '--changed']), ('changed', 'main', []))
        self.assertEqual(lints.parse(['--staged']), ('staged', lints.DEFAULT_BASE, []))
        self.assertEqual(lints.parse(['--test', '-r', 'expanded']), ('test', None, ['-r', 'expanded']))

    def test_invalid_combinations(self):
        for argv in (['--changed', 'a.dart'], ['--changed', '--staged'], ['--base', 'x'], ['--base'], ['--bogus'], ['--staged', '--base', 'x']):
            with self.assertRaises(ValueError, msg=argv):
                lints.parse(argv)


class GitEnvTests(unittest.TestCase):
    def test_git_variables_are_not_passed_to_the_flutter_sdk(self):
        saved = dict(os.environ)
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(saved)))
        os.environ.update({'GIT_DIR': '/x/.git', 'GIT_INDEX_FILE': '/x/index', 'KEEP_ME': '1'})
        env = lints.without_git_env()
        self.assertNotIn('GIT_DIR', env)
        self.assertNotIn('GIT_INDEX_FILE', env)
        self.assertEqual(env['KEEP_ME'], '1')


class SnapshotKeyTests(unittest.TestCase):
    def test_key_follows_sources_and_sdk(self):
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / 'pkg'
            sdk = Path(tmp) / 'sdk'
            for name in ('pubspec.yaml', 'pubspec.lock', 'bin/check.dart', 'lib/a.dart'):
                write(package, name)
            write(sdk, 'version', '3.1\n')
            first = lints.snapshot_key(sdk, package)
            self.assertEqual(first, lints.snapshot_key(sdk, package))
            write(package, 'lib/a.dart', 'changed\n')
            second = lints.snapshot_key(sdk, package)
            self.assertNotEqual(first, second)
            write(package, 'pubspec.lock', 'changed\n')
            third = lints.snapshot_key(sdk, package)
            self.assertNotEqual(second, third)
            write(sdk, 'version', '3.2\n')
            self.assertNotEqual(third, lints.snapshot_key(sdk, package))


class SyncPubLockTests(TempRepo):
    def setUp(self):
        super().setUp()
        for name in ('pubspec.lock', 'tool/raft_lints/pubspec.lock', 'tool/other.txt'):
            write(self.root, name)
        write(self.root, 'pubspec.yaml')
        write(self.root, 'tool/raft_lints/pubspec.yaml')
        self.commit('one')
        self.old = git(self.root, 'rev-parse', 'HEAD').strip()
        self.calls = []
        self.original = sync.pub_get
        sync.pub_get = lambda root, directory: (self.calls.append(directory), (True, ''))[1]
        self.addCleanup(lambda: setattr(sync, 'pub_get', self.original))

    def test_silent_when_no_lock_changed(self):
        write(self.root, 'tool/other.txt', 'y\n')
        self.commit('two')
        self.assertEqual(sync.changed_lock_dirs(self.root, self.old, 'HEAD'), [])
        self.assertEqual(sync.main([self.old, 'HEAD'], self.root), 0)
        self.assertEqual(self.calls, [])

    def test_runs_only_where_a_lock_changed(self):
        write(self.root, 'tool/raft_lints/pubspec.lock', 'y\n')
        self.commit('two')
        self.assertEqual(sync.changed_lock_dirs(self.root, self.old, 'HEAD'), ['tool/raft_lints'])
        sync.main([self.old, 'HEAD'], self.root)
        self.assertEqual(self.calls, ['tool/raft_lints'])
        write(self.root, 'pubspec.lock', 'y\n')
        self.commit('three')
        self.calls.clear()
        sync.main([self.old, 'HEAD'], self.root)
        self.assertEqual(self.calls, ['', 'tool/raft_lints'])

    def test_unknown_or_null_old_revision_is_silent(self):
        self.assertEqual(sync.changed_lock_dirs(self.root, '0' * 40, 'HEAD'), [])
        self.assertEqual(sync.main(['0' * 40, 'HEAD'], self.root), 0)
        self.assertEqual(self.calls, [])

    def test_failure_warns_and_still_exits_zero(self):
        write(self.root, 'pubspec.lock', 'y\n')
        self.commit('two')
        sync.pub_get = lambda root, directory: (False, 'version solving failed')
        import contextlib
        import io
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertEqual(sync.main([self.old, 'HEAD'], self.root), 0)
        self.assertIn('WARNING', err.getvalue())
        self.assertIn('version solving failed', err.getvalue())

    def test_pub_get_reports_a_failing_command(self):
        sync.pub_get = self.original
        (self.root / 'tool').mkdir(exist_ok=True)
        flutter = self.root / 'tool/flutter'
        flutter.write_text('#!/bin/sh\necho "Because x depends on y, version solving failed." >&2\nexit 1\n')
        flutter.chmod(0o755)
        if os.name != 'nt':
            self.assertEqual(sync.pub_get(self.root, ''), (False, 'Because x depends on y, version solving failed.'))
            flutter.write_text('#!/bin/sh\nexit 0\n')
            self.assertEqual(sync.pub_get(self.root, ''), (True, ''))
            # Inside a git hook GIT_DIR is set; the SDK must not see it.
            flutter.write_text('#!/bin/sh\n[ -z "$GIT_DIR$GIT_INDEX_FILE" ] || { echo "git env leaked" >&2; exit 1; }\n')
            os.environ['GIT_DIR'] = str(self.root / '.git')
            self.addCleanup(os.environ.pop, 'GIT_DIR', None)
            self.assertEqual(sync.pub_get(self.root, ''), (True, ''))


@unittest.skipIf(os.name == 'nt' or shutil.which('sh') is None, 'hooks are POSIX shell')
class HookScriptTests(TempRepo):
    """Runs the real hook scripts in a throw-away repo whose tool/ is a copy of this one's hooks."""

    def setUp(self):
        super().setUp()
        shutil.copytree(TOOL / 'git-hooks', self.root / 'tool/git-hooks')
        self.log = self.root / 'calls.log'
        for name, body in {
            'raft-lints': f'#!/bin/sh\necho "raft-lints $*" >> {self.log}\nexit "${{FAKE_LINT_EXIT:-0}}"\n',
            'sync-pub-lock': f'#!/bin/sh\necho "sync-pub-lock $*" >> {self.log}\n',
        }.items():
            write(self.root, f'tool/{name}', body)
            (self.root / 'tool' / name).chmod(0o755)
        # tool/*-scripts are run as `python3 tool/<name>`: make that work for the shell stubs too.
        bindir = self.root / 'bin'
        bindir.mkdir()
        python = bindir / 'python3'
        python.write_text('#!/bin/sh\nexec sh "$@"\n')
        python.chmod(0o755)
        self.env = {**os.environ, 'PATH': f'{bindir}{os.pathsep}{os.environ["PATH"]}'}
        write(self.root, 'tool/raft_lints/.dart_tool/package_config.json')
        write(self.root, 'README', 'r\n')
        write(self.root, 'pubspec.lock', 'a\n')
        self.commit('base')
        git(self.root, 'config', 'core.hooksPath', 'tool/git-hooks')

    def run_hook(self, name, *args, **extra):
        env = {**self.env, **extra}
        return subprocess.run([str(self.root / 'tool/git-hooks' / name), *args], cwd=self.root, capture_output=True, text=True, env=env)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_pre_commit_does_nothing_without_staged_lib_dart(self):
        write(self.root, 'apps/raft_flutter/test/a_test.dart')
        write(self.root, 'apps/raft_flutter/lib/unstaged.dart')
        git(self.root, 'add', 'apps/raft_flutter/test/a_test.dart')
        result = self.run_hook('pre-commit')
        self.assertEqual((result.returncode, result.stdout, result.stderr, self.calls()), (0, '', '', []))

    def test_pre_commit_lints_staged_files_and_blocks_on_findings(self):
        write(self.root, 'apps/raft_flutter/lib/a.dart')
        git(self.root, 'add', '-A')
        self.assertEqual(self.run_hook('pre-commit').returncode, 0)
        self.assertEqual(self.calls(), ['raft-lints --staged'])
        failing = self.run_hook('pre-commit', FAKE_LINT_EXIT='1')
        self.assertEqual(failing.returncode, 1)
        self.assertIn('--no-verify', failing.stderr)

    def test_pre_commit_through_git_commit_and_no_verify(self):
        write(self.root, 'packages/raft_ui/lib/a.dart')
        git(self.root, 'add', '-A')
        env = {**self.env, 'FAKE_LINT_EXIT': '1', 'GIT_AUTHOR_NAME': 't', 'GIT_AUTHOR_EMAIL': 't@t', 'GIT_COMMITTER_NAME': 't', 'GIT_COMMITTER_EMAIL': 't@t'}
        blocked = subprocess.run(['git', '-C', str(self.root), 'commit', '-q', '-m', 'x'], capture_output=True, text=True, env=env)
        self.assertNotEqual(blocked.returncode, 0)
        allowed = subprocess.run(['git', '-C', str(self.root), 'commit', '-q', '--no-verify', '-m', 'x'], capture_output=True, text=True, env=env)
        self.assertEqual(allowed.returncode, 0, allowed.stderr)

    def test_pre_commit_skips_with_a_warning_when_raft_lints_is_not_resolved(self):
        (self.root / 'tool/raft_lints/.dart_tool/package_config.json').unlink()
        write(self.root, 'apps/raft_flutter/lib/a.dart')
        git(self.root, 'add', '-A')
        result = self.run_hook('pre-commit')
        self.assertEqual((result.returncode, self.calls()), (0, []))
        self.assertIn('pub get', result.stderr)

    def test_post_checkout_only_for_branch_checkouts_with_a_new_head(self):
        self.assertEqual(self.run_hook('post-checkout', 'aaa', 'bbb', '0').returncode, 0)
        self.assertEqual(self.run_hook('post-checkout', 'aaa', 'aaa', '1').returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.run_hook('post-checkout', 'aaa', 'bbb', '1').returncode, 0)
        self.assertEqual(self.calls(), ['sync-pub-lock aaa bbb'])

    def test_post_merge_and_post_rewrite_compare_orig_head_to_head(self):
        self.assertEqual(self.run_hook('post-merge', '0').returncode, 0)  # no ORIG_HEAD yet
        self.assertEqual(self.calls(), [])
        git(self.root, 'update-ref', 'ORIG_HEAD', 'HEAD')
        self.run_hook('post-merge', '0')
        self.run_hook('post-rewrite', 'amend')
        self.run_hook('post-rewrite', 'rebase')
        self.assertEqual(self.calls(), ['sync-pub-lock ORIG_HEAD HEAD', 'sync-pub-lock ORIG_HEAD HEAD'])

    def test_real_sync_pub_lock_failure_never_fails_the_hook(self):
        # use the real helper with a stub tool/flutter that fails
        shutil.copy(TOOL / 'sync-pub-lock', self.root / 'tool/sync-pub-lock')
        (self.root / 'tool/flutter').write_text('#!/bin/sh\necho "no network" >&2\nexit 69\n')
        (self.root / 'tool/flutter').chmod(0o755)
        write(self.root, 'tool/raft_lints/pubspec.lock', 'a\n')
        write(self.root, 'tool/raft_lints/pubspec.yaml')
        git(self.root, 'add', '-A')
        git(self.root, 'commit', '-q', '--no-verify', '-m', 'locks')
        git(self.root, 'update-ref', 'ORIG_HEAD', 'HEAD~1')
        real = subprocess.run([str(self.root / 'tool/git-hooks/post-merge'), '0'], cwd=self.root, capture_output=True, text=True,
                              env={**os.environ, 'PATH': os.environ['PATH']})
        self.assertEqual(real.returncode, 0)
        self.assertIn('WARNING', real.stderr)
        self.assertIn('no network', real.stderr)


class InstallTests(TempRepo):
    def setUp(self):
        super().setUp()
        for name in ('pre-commit', 'post-merge', 'post-checkout', 'post-rewrite'):
            write(self.root, f'tool/git-hooks/{name}')

    def hooks_path(self):
        out = subprocess.run(['git', '-C', str(self.root), 'config', '--local', '--get', 'core.hooksPath'], capture_output=True, text=True)
        return out.stdout.strip()

    def test_install_status_and_uninstall(self):
        self.assertEqual(install.main([], self.root), 0)
        self.assertEqual(self.hooks_path(), 'tool/git-hooks')
        self.assertEqual(install.main(['--status'], self.root), 0)
        self.assertEqual(install.main([], self.root), 0)  # idempotent
        self.assertEqual(install.main(['--uninstall'], self.root), 0)
        self.assertEqual(self.hooks_path(), '')

    def test_does_not_replace_a_foreign_hooks_path_without_force(self):
        git(self.root, 'config', 'core.hooksPath', '.husky')
        self.assertEqual(install.main([], self.root), 1)
        self.assertEqual(self.hooks_path(), '.husky')
        self.assertEqual(install.main(['--uninstall'], self.root), 0)
        self.assertEqual(self.hooks_path(), '.husky')
        self.assertEqual(install.main(['--force'], self.root), 0)
        self.assertEqual(self.hooks_path(), 'tool/git-hooks')

    def test_refuses_when_hooks_are_missing(self):
        (self.root / 'tool/git-hooks/post-rewrite').unlink()
        self.assertEqual(install.main([], self.root), 1)
        self.assertEqual(self.hooks_path(), '')

    def test_shared_with_linked_worktrees(self):
        write(self.root, 'f')
        self.commit('c')
        git(self.root, 'worktree', 'add', '-q', str(self.root.parent / (self.root.name + '-wt')), '-b', 'wt')
        self.addCleanup(shutil.rmtree, self.root.parent / (self.root.name + '-wt'), True)
        install.main([], self.root)
        out = subprocess.run(['git', '-C', str(self.root.parent / (self.root.name + '-wt')), 'config', '--get', 'core.hooksPath'], capture_output=True, text=True)
        self.assertEqual(out.stdout.strip(), 'tool/git-hooks')


if __name__ == '__main__':
    unittest.main()
