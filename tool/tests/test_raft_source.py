"""tool/raft_source.py and tool/raft-source: one resolver for the pinned raft-source checkout."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import raft_source  # noqa: E402

_loader = importlib.machinery.SourceFileLoader('raft_source_cli', str(TOOL / 'raft-source'))
cli = importlib.util.module_from_spec(importlib.util.spec_from_loader(_loader.name, _loader))
_loader.exec_module(cli)


def git(*args, cwd):
    return subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@example.com', *args], cwd=cwd,
                          check=True, capture_output=True, text=True).stdout.strip()


def checkout(path, label, needs=raft_source.NEEDED):
    """A git checkout with one commit (content `label`) and the given needed files; returns its HEAD."""
    path.mkdir(parents=True)
    git('init', '--quiet', cwd=path)
    (path / 'label').write_text(label)
    git('add', 'label', cwd=path)
    git('commit', '--quiet', '-m', label, cwd=path)
    for need in needs:
        (path / need).parent.mkdir(parents=True, exist_ok=True)
        (path / need).write_text('{}')
    return git('rev-parse', 'HEAD', cwd=path)


class ResolverTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.root, self.home = base / 'repo', base / 'home'
        self.cache = self.home / '.cache/raft-flutter'

    def tearDown(self):
        self.tmp.cleanup()

    def pin(self, commit):
        (self.root / 'docs').mkdir(parents=True, exist_ok=True)
        (self.root / raft_source.PIN_FILE).write_text(json.dumps({'commit': commit}))

    def require(self, env=None, **kw):
        return raft_source.require({} if env is None else env, root=self.root, home=self.home, **kw)

    def test_env_override_wins_at_any_revision_but_still_needs_the_files(self):
        self.pin('0' * 40)
        other = Path(self.tmp.name) / 'elsewhere'
        checkout(other, 'old upstream', needs=(raft_source.SHARED_CASES,))
        env = {raft_source.ENV: str(other)}
        self.assertEqual(self.require(env, needs=(raft_source.SHARED_CASES,)), other)
        with self.assertRaises(raft_source.RaftSourceError) as error:
            self.require(env)
        message = str(error.exception)
        self.assertIn(str(other), message)
        self.assertIn(f'missing: {raft_source.RAFT_UI}', message)
        self.assertIn(f'{raft_source.ENV} points here', message)
        self.assertNotIn('expected commit', message)

    def test_pinned_lookup_finds_an_existing_checkout_of_the_pin(self):
        stale = checkout(self.cache / 'raft-source-1', 'v1.21.2')
        pinned = checkout(self.cache / 'raft-source-23', 'v1.21.23')
        checkout(self.cache / 'raft-source-24', 'v1.21.23 without node_modules', needs=())
        self.pin(pinned)
        self.assertNotEqual(stale, pinned)
        self.assertEqual(self.require(), self.cache / 'raft-source-23')
        self.assertIn('): ok', raft_source.describe({}, root=self.root, home=self.home))

    def test_the_canonical_name_comes_first(self):
        pinned = checkout(self.cache / 'raft-source-23', 'v1.21.23')
        self.pin(pinned)
        canonical = raft_source.canonical_dir(pinned, self.home)
        self.assertEqual(canonical.name, f'raft-source-{pinned[:12]}')
        canonical.symlink_to(self.cache / 'raft-source-23')
        self.assertEqual(self.require(), canonical)

    def test_wrong_commit_names_both_commits_and_the_prepare_command(self):
        actual = checkout(self.home / 'elsewhere', 'v1.21.2')
        self.pin('f' * 40)
        canonical = raft_source.canonical_dir('f' * 40, self.home)
        canonical.parent.mkdir(parents=True)
        canonical.symlink_to(self.home / 'elsewhere')
        with self.assertRaises(raft_source.RaftSourceError) as error:
            self.require()
        message = str(error.exception)
        self.assertIn(f'not usable: {canonical}', message)
        self.assertIn('expected commit: ' + 'f' * 40, message)
        self.assertIn(f'actual commit:   {actual}', message)
        self.assertIn(raft_source.PREPARE, message)

    def test_a_checkout_at_another_commit_is_never_used_instead(self):
        checkout(self.cache / 'raft-source-1', 'v1.21.2')
        self.pin('f' * 40)
        self.assertEqual(raft_source.raft_source_dir({}, root=self.root, home=self.home),
                         raft_source.canonical_dir('f' * 40, self.home))
        with self.assertRaises(raft_source.RaftSourceError) as error:
            self.require()
        self.assertIn('checkout not found', str(error.exception))
        self.assertIn(raft_source.PREPARE, str(error.exception))

    def test_missing_files_are_listed(self):
        pinned = checkout(self.home / 'clone', 'v1.21.23', needs=(raft_source.SHARED_CASES,))
        self.pin(pinned)
        raft_source.canonical_dir(pinned, self.home).parent.mkdir(parents=True)
        raft_source.canonical_dir(pinned, self.home).symlink_to(self.home / 'clone')
        with self.assertRaises(raft_source.RaftSourceError) as error:
            self.require()
        message = str(error.exception)
        for need in raft_source.NEEDED[1:]:
            self.assertIn(f'missing: {need}', message)
        self.assertNotIn(f'missing: {raft_source.SHARED_CASES}', message)
        self.assertNotIn('expected commit', message)
        self.assertIn(raft_source.PREPARE, message)
        self.assertIn('NOT USABLE', raft_source.describe({}, root=self.root, home=self.home))

    def test_prepare_clones_the_pin_from_the_mirror_and_installs(self):
        upstream = Path(self.tmp.name) / 'upstream'
        pinned = checkout(upstream, 'v1.21.23', needs=())
        git('commit', '--quiet', '--allow-empty', '-m', 'newer', cwd=upstream)
        mirror = Path(self.tmp.name) / 'mirror.git'
        git('clone', '--quiet', '--mirror', str(upstream), str(mirror), cwd=self.tmp.name)
        self.pin(pinned)
        calls = []

        def run(cmd, **kw):
            calls.append(cmd)
            if cmd[0] == 'pnpm':  # stands in for the install
                for need in raft_source.NEEDED:
                    (Path(kw['cwd']) / need).parent.mkdir(parents=True, exist_ok=True)
                    (Path(kw['cwd']) / need).write_text('{}')
                return subprocess.CompletedProcess(cmd, 0)
            return subprocess.run(cmd, check=True, capture_output=True)

        dest = cli.prepare(mirror=mirror, root=self.root, home=self.home, run=run, log=lambda _: None)
        self.assertEqual(dest, raft_source.canonical_dir(pinned, self.home))
        self.assertEqual(raft_source.head_commit(dest), pinned)
        self.assertIn(['pnpm', 'install', '--frozen-lockfile'], calls)
        self.assertEqual(self.require(), dest)
        calls.clear()
        self.assertEqual(cli.prepare(mirror=mirror, root=self.root, home=self.home, run=run, log=lambda _: None), dest)
        self.assertEqual(calls, [])  # already prepared: nothing to do

    def test_prepare_leaves_a_directory_at_another_commit_alone(self):
        other = checkout(self.cache / 'raft-source-x', 'v1.21.2')
        self.pin('f' * 40)
        with self.assertRaises(raft_source.RaftSourceError) as error:
            cli.prepare(self.cache / 'raft-source-x', root=self.root, home=self.home, run=None, log=lambda _: None)
        self.assertIn(other, str(error.exception))
        self.assertEqual(raft_source.head_commit(self.cache / 'raft-source-x'), other)

    def test_path_command_reports_the_reason_and_fails(self):
        env = {k: v for k, v in os.environ.items() if k != raft_source.ENV}
        env['HOME'] = str(self.home)
        done = subprocess.run([sys.executable, str(TOOL / 'raft-source'), 'path'], env=env,
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 1)
        self.assertEqual(done.stdout, '')
        self.assertIn('raft-source checkout not found', done.stderr)
        self.assertIn(raft_source.pinned_commit(), done.stderr)


class NoPrivateCheckoutTests(unittest.TestCase):
    def test_no_tool_hardcodes_a_raft_source_checkout(self):
        checkout_path = re.compile(r"(/home/|/mnt/)[^\s'\"]*/raft-source(-\d+|/|['\"])")
        offenders = []
        for path in TOOL.rglob('*'):
            if path.is_file() and 'node_modules' not in path.parts and path != Path(__file__).resolve():
                try:
                    text = path.read_text()
                except (UnicodeDecodeError, OSError):
                    continue
                offenders += [f'{path.relative_to(TOOL)}: {m.group(0)}' for m in checkout_path.finditer(text)]
        self.assertEqual(offenders, [], 'resolve the checkout with tool/raft_source.py instead')


if __name__ == '__main__':
    unittest.main()
