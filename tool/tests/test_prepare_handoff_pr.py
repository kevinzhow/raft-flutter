"""tool/prepare-handoff --pr: gh and git are mocked; nothing here touches a network, a login or a remote."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
LOADER = importlib.machinery.SourceFileLoader('prepare_handoff_pr', str(TOOL / 'prepare-handoff'))
ph = importlib.util.module_from_spec(importlib.util.spec_from_loader('prepare_handoff_pr', LOADER))
LOADER.exec_module(ph)

LINE = 'handoff: cindy/x abc1234 (contains origin/cindy/integration def5678); check-project PASSED (themes: sampled); sourceHash 0123456789ab'


def done(args, code=0, out='', err=''):
    return subprocess.CompletedProcess(args, code, out, err)


class FakeRun:
    """Stands in for subprocess.run; `script` maps a command prefix to (code, stdout)."""

    def __init__(self, script=None):
        self.calls = []
        self.script = script or {}
        self.bodies = {}

    def __call__(self, args, **kwargs):
        args = list(args)
        self.calls.append(args)
        if '--body-file' in args:  # the temp file is gone after publish_pr returns
            self.bodies[tuple(args[:3])] = Path(args[args.index('--body-file') + 1]).read_text(encoding='utf-8')
        for prefix, result in self.script.items():
            if args[:len(prefix)] == list(prefix):
                if isinstance(result, Exception):
                    raise result
                return done(args, *result)
        return done(args)

    def commands(self, *prefix):
        return [c for c in self.calls if c[:len(prefix)] == list(prefix)]


class Common(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.body = self.tmp / 'body.md'
        self.body.write_text('## 改了什么\n\nsomething\n', encoding='utf-8')
        quiet = mock.patch('builtins.print')
        quiet.start()
        self.addCleanup(quiet.stop)

    def patch_run(self, script=None):
        fake = FakeRun(script)
        patcher = mock.patch.object(ph.subprocess, 'run', fake)
        patcher.start()
        self.addCleanup(patcher.stop)
        return fake


class PreflightTests(Common):
    def argv(self, *extra):
        patcher = mock.patch.object(sys, 'argv', ['prepare-handoff', *extra])
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_unauthenticated_gh_stops_before_touching_anything(self):
        fake = self.patch_run({('gh', 'auth', 'status'): (1, '', 'You are not logged into any GitHub hosts')})
        self.argv('--pr', '--pr-body', str(self.body))
        with self.assertRaises(SystemExit) as stop:
            ph.main()
        self.assertIn('gh is not authenticated', str(stop.exception))
        self.assertNotEqual(stop.exception.code, 0)
        self.assertEqual(fake.calls, [['gh', 'auth', 'status']])  # no fetch, rebase, gate or push

    def test_missing_gh_binary_is_the_same_clear_failure(self):
        fake = self.patch_run({('gh', 'auth', 'status'): FileNotFoundError('gh')})
        self.argv('--pr', '--pr-body', str(self.body))
        with self.assertRaises(SystemExit) as stop:
            ph.main()
        self.assertIn('gh is not authenticated', str(stop.exception))
        self.assertEqual(len(fake.calls), 1)

    def test_pr_needs_a_body_file(self):
        fake = self.patch_run()
        self.argv('--pr')
        with self.assertRaises(SystemExit) as stop:
            ph.main()
        self.assertIn('--pr-body', str(stop.exception))
        self.argv('--pr', '--pr-body', str(self.tmp / 'missing.md'))
        with self.assertRaises(SystemExit) as stop:
            ph.main()
        self.assertIn('not found', str(stop.exception))
        self.assertEqual(fake.calls, [])

    def test_pr_cannot_skip_the_gate(self):
        fake = self.patch_run()
        self.argv('--pr', '--pr-body', str(self.body), '--no-check')
        with self.assertRaises(SystemExit) as stop:
            ph.main()
        self.assertIn('--no-check', str(stop.exception))
        self.assertEqual(fake.calls, [])


class PushTests(Common):
    def test_new_branch_is_a_normal_push_of_its_own_ref(self):
        fake = self.patch_run({('git', 'rev-parse'): (1, '')})
        ph.push_branch('cindy/x')
        self.assertEqual(fake.commands('git', 'push'), [['git', 'push', 'origin', 'refs/heads/cindy/x:refs/heads/cindy/x']])

    def test_fast_forward_of_an_existing_branch_is_a_normal_push(self):
        fake = self.patch_run({('git', 'rev-parse'): (0, 'aaa111\n'), ('git', 'merge-base'): (0, '')})
        ph.push_branch('cindy/x')
        self.assertEqual(fake.commands('git', 'push'), [['git', 'push', 'origin', 'refs/heads/cindy/x:refs/heads/cindy/x']])

    def test_rebased_branch_uses_force_with_lease_for_itself_only(self):
        fake = self.patch_run({('git', 'rev-parse'): (0, 'aaa111\n'), ('git', 'merge-base'): (1, '')})
        ph.push_branch('cindy/x')
        pushes = fake.commands('git', 'push')
        self.assertEqual(pushes, [['git', 'push', '--force-with-lease=refs/heads/cindy/x:aaa111', 'origin',
                                   'refs/heads/cindy/x:refs/heads/cindy/x']])
        self.assertNotIn('--force', pushes[0])
        self.assertFalse(any('integration' in part or 'main' in part for part in pushes[0]))

    def test_protected_branches_are_never_pushed(self):
        for name in ['cindy/integration', 'main', 'master', '']:
            fake = self.patch_run()
            with self.assertRaises(SystemExit):
                ph.push_branch(name)
            self.assertEqual(fake.commands('git', 'push'), [], name)

    def test_failed_push_stops_before_any_pr_call(self):
        fake = self.patch_run({('git', 'rev-parse'): (1, ''), ('git', 'push'): (1, '', 'rejected')})
        with self.assertRaises(SystemExit) as stop:
            ph.publish_pr('cindy/x', str(self.body), LINE)
        self.assertIn('Push of cindy/x failed', str(stop.exception))
        self.assertEqual(fake.commands('gh', 'pr'), [])


class PublishTests(Common):
    def test_creates_a_pr_against_integration_with_body_and_gate_line(self):
        fake = self.patch_run({('git', 'rev-parse'): (1, ''), ('git', 'log'): (0, 'docs: cleanup\n'),
                               ('gh', 'pr', 'list'): (0, '[]'),
                               ('gh', 'pr', 'create'): (0, 'https://github.com/example/repo/pull/7\n')})
        with mock.patch('builtins.print') as printed:  # innermost patch wins over the quiet one
            ph.publish_pr('cindy/x', str(self.body), LINE)
        create = fake.commands('gh', 'pr', 'create')[0]
        self.assertEqual(create[3:10], ['--base', 'cindy/integration', '--head', 'cindy/x', '--title', 'docs: cleanup', '--body-file'])
        body = fake.bodies[('gh', 'pr', 'create')]
        self.assertIn('something', body)
        self.assertIn(LINE, body)
        self.assertEqual(fake.commands('gh', 'pr', 'edit'), [])
        printed.assert_called_with('https://github.com/example/repo/pull/7')

    def test_title_falls_back_to_the_branch_for_several_commits_and_honors_an_explicit_one(self):
        fake = self.patch_run({('git', 'rev-parse'): (1, ''), ('git', 'log'): (0, 'one\ntwo\n'), ('gh', 'pr', 'list'): (0, '[]')})
        ph.publish_pr('cindy/x', str(self.body), LINE)
        self.assertIn('cindy/x', fake.commands('gh', 'pr', 'create')[0][fake.commands('gh', 'pr', 'create')[0].index('--title') + 1])
        fake = self.patch_run({('git', 'rev-parse'): (1, ''), ('gh', 'pr', 'list'): (0, '[]')})
        ph.publish_pr('cindy/x', str(self.body), LINE, 'My title')
        create = fake.commands('gh', 'pr', 'create')[0]
        self.assertEqual(create[create.index('--title') + 1], 'My title')

    def test_updates_the_open_pr_instead_of_creating_another(self):
        fake = self.patch_run({('git', 'rev-parse'): (1, ''), ('gh', 'pr', 'list'): (0, '[{"number": 12}]')})
        ph.publish_pr('cindy/x', str(self.body), LINE)
        edit = fake.commands('gh', 'pr', 'edit')[0]
        self.assertEqual(edit[:6], ['gh', 'pr', 'edit', '12', '--base', 'cindy/integration'])
        self.assertNotIn('--title', edit)  # a hand-edited title survives
        self.assertIn(LINE, fake.bodies[('gh', 'pr', 'edit')])
        self.assertEqual(fake.commands('gh', 'pr', 'create'), [])

    def test_gh_failure_is_reported(self):
        self.patch_run({('git', 'rev-parse'): (1, ''), ('gh', 'pr', 'list'): (0, '[]'), ('gh', 'pr', 'create'): (1, '', 'boom')})
        with self.assertRaises(SystemExit) as stop:
            ph.publish_pr('cindy/x', str(self.body), LINE)
        self.assertIn('boom', str(stop.exception))

    def test_no_gh_call_other_than_auth_list_create_edit(self):
        fake = self.patch_run({('git', 'rev-parse'): (1, ''), ('gh', 'pr', 'list'): (0, '[]')})
        ph.publish_pr('cindy/x', str(self.body), LINE)
        for call in fake.calls:
            if call[0] == 'gh':
                self.assertEqual(call[1:3], ['pr', call[2]])
                self.assertIn(call[2], {'list', 'create', 'edit'})


class MainFlowTests(Common):
    """main() with the gate and git helpers faked: the PR is published only after a passing gate."""

    def run_main(self, passed, script=None, *extra, preflight=True):
        root = self.tmp / 'repo'
        (root / '.local').mkdir(parents=True)
        (root / '.local/engineering-run.json').write_text(json.dumps({'themes': 'sampled', 'sourceHash': '0123456789abcdef'}))
        results = {'status': '', 'branch': 'cindy/x', 'rev-parse': 'abc1234'}
        fake = self.patch_run({('git', 'rebase'): (0, ''), ('gh', 'auth', 'status'): (0, 'Logged in'),
                               ('git', 'rev-parse', '--verify'): (1, ''), ('gh', 'pr', 'list'): (0, '[]'),
                               ('gh', 'pr', 'create'): (0, 'https://github.com/example/repo/pull/9\n'),
                               **(script or {})})
        gate = done([], 0 if passed else 1, json.dumps({'passed': passed}))
        events = mock.MagicMock()
        self.order = []
        self.preflight = mock.MagicMock(side_effect=lambda base: self.order.append('preflight') or preflight)
        self.gate = mock.MagicMock(side_effect=lambda *a, **k: self.order.append('gate') or gate)
        patches = [
            mock.patch.object(ph, 'run_preflight', self.preflight),
            mock.patch.object(ph, 'root', root),
            mock.patch.object(ph, 'git', lambda *a, **k: 'cindy/x' if a[0] == 'branch' else ('' if a[0] in ('status', 'fetch') else 'abc1234')),
            mock.patch.object(ph, 'run_gate', self.gate),
            mock.patch.object(ph.gate_events, 'Events', lambda r: events),
            mock.patch.object(ph.gate_events, 'identity', lambda r: ('cindy/x', 'abc1234')),
            mock.patch.object(ph.gate_events, 'raise_on_signals', lambda: None),
            mock.patch.object(ph.gate_events, 'flush_notifications', lambda: None),
            mock.patch.object(sys, 'argv', ['prepare-handoff', '--pr', '--pr-body', str(self.body), *extra]),
            mock.patch.object(ph.pathlib.Path, 'home', lambda: self.tmp),
        ]
        for patcher in patches:
            patcher.start()
            self.addCleanup(patcher.stop)
        with self.assertRaises(SystemExit) as stop:
            ph.main()
        return fake, stop.exception.code

    def test_passing_gate_pushes_and_opens_the_pr(self):
        fake, code = self.run_main(True)
        self.assertEqual(code, 0)
        self.assertEqual(len(fake.commands('git', 'push')), 1)
        self.assertEqual(len(fake.commands('gh', 'pr', 'create')), 1)
        body = fake.bodies[('gh', 'pr', 'create')]
        self.assertIn('check-project PASSED', body)
        self.assertIn('handoff: cindy/x abc1234', body)

    def test_failing_gate_publishes_nothing(self):
        fake, code = self.run_main(False)
        self.assertEqual(code, 1)
        self.assertEqual(fake.commands('git', 'push'), [])
        self.assertEqual(fake.commands('gh', 'pr', 'create'), [])

    def test_preflight_runs_against_the_base_before_the_gate(self):
        fake, code = self.run_main(True)
        self.preflight.assert_called_once_with('origin/cindy/integration')
        self.assertEqual(self.order, ['preflight', 'gate'])
        self.assertEqual(code, 0)

    def test_failing_preflight_stops_before_the_gate_and_publishes_nothing(self):
        fake, code = self.run_main(True, None, preflight=False)
        self.assertIn('preflight failed', str(code))
        self.gate.assert_not_called()
        self.assertEqual(fake.commands('git', 'push'), [])
        self.assertEqual(fake.commands('gh', 'pr', 'create'), [])

    def test_skip_preflight_goes_straight_to_the_gate(self):
        fake, code = self.run_main(True, None, '--skip-preflight', preflight=False)
        self.assertEqual(code, 0)
        self.preflight.assert_not_called()
        self.gate.assert_called_once()

    def test_no_check_does_not_run_preflight(self):
        self.patch_run({('gh', 'auth', 'status'): (0, '')})
        argv = mock.patch.object(sys, 'argv', ['prepare-handoff', '--no-check', '--base', 'origin/x'])
        argv.start()
        self.addCleanup(argv.stop)
        preflight = mock.MagicMock(return_value=True)
        for patcher in (mock.patch.object(ph, 'run_preflight', preflight),
                        mock.patch.object(ph, 'git', lambda *a, **k: ''),
                        mock.patch.object(ph.gate_events, 'Events', lambda r: mock.MagicMock()),
                        mock.patch.object(ph.pathlib.Path, 'home', lambda: self.tmp)):
            patcher.start()
            self.addCleanup(patcher.stop)
        ph.main()
        preflight.assert_not_called()


class RunPreflightTests(Common):
    def test_runs_the_script_with_the_base_and_reports_its_exit_code(self):
        fake = self.patch_run()
        self.assertTrue(ph.run_preflight('origin/cindy/integration'))
        command = fake.calls[0]
        self.assertEqual(command[0], sys.executable)
        self.assertTrue(command[1].endswith('tool/preflight'))
        self.assertEqual(command[2:], ['--base', 'origin/cindy/integration'])
        self.patch_run({(sys.executable,): (1, '')})
        self.assertFalse(ph.run_preflight('origin/cindy/integration'))


if __name__ == '__main__':
    unittest.main()
