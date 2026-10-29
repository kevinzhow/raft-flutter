"""tool/nightly-quality: the pure parts (event parsing, areas, osv, summary text) and the gate-lock bound."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
LOADER = importlib.machinery.SourceFileLoader('nightly_quality', str(TOOL / 'nightly-quality'))
nq = importlib.util.module_from_spec(importlib.util.spec_from_loader('nightly_quality', LOADER))
LOADER.exec_module(nq)

LEAK = """Expected: leak free
  Actual: <Instance of 'Leaks'>
   Which: contains leaks:
          notDisposed:
            total: 2
            objects:
              AttachmentTransfer:
                test: a lease that outlives
                identityHashCode: 553701260
              ValueNotifier<int>:
                test: the shell
                identityHashCode: 201202039
"""


def events(*items):
    return [json.dumps(item) for item in items]


class EventTests(unittest.TestCase):
    def test_counts_failures_and_hidden_failures(self):
        lines = events(
            {'type': 'suite', 'suite': {'id': 0, 'path': '/wt/apps/raft_flutter/test/a_test.dart'}},
            {'type': 'testStart', 'test': {'id': 1, 'name': 'loading /wt/a_test.dart', 'suiteID': 0}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': True},
            {'type': 'testStart', 'test': {'id': 2, 'name': 'works', 'suiteID': 0}},
            {'type': 'testDone', 'testID': 2, 'result': 'success', 'hidden': False},
            {'type': 'testStart', 'test': {'id': 3, 'name': 'skipped one', 'suiteID': 0}},
            {'type': 'testDone', 'testID': 3, 'result': 'success', 'skipped': True},
            {'type': 'testStart', 'test': {'id': 4, 'name': 'breaks', 'suiteID': 0}},
            {'type': 'error', 'testID': 4, 'error': 'Expected: 1\n  Actual: 2', 'isFailure': True},
            {'type': 'testDone', 'testID': 4, 'result': 'failure', 'hidden': False},
            {'type': 'testStart', 'test': {'id': 5, 'name': '(tearDownAll)', 'suiteID': 0}},
            {'type': 'error', 'testID': 5, 'error': LEAK},
            {'type': 'testDone', 'testID': 5, 'result': 'error', 'hidden': True},
        ) + ['not json at all', '[1]']
        parsed = nq.parse_test_events(lines, '/wt')
        self.assertEqual((parsed['passed'], parsed['skipped']), (1, 1))
        self.assertEqual([f['name'] for f in parsed['failed']], ['breaks', '(tearDownAll)'])
        self.assertEqual(parsed['failed'][0]['file'], 'apps/raft_flutter/test/a_test.dart')
        self.assertEqual([nq.failure_kind(f) for f in parsed['failed']], ['test', 'leak'])
        self.assertEqual(nq.leak_classes(parsed['failed'][1]['error']), ['AttachmentTransfer', 'ValueNotifier<int>'])

    def test_a_file_that_does_not_compile_is_a_compile_failure(self):
        failure = {'name': 'loading /wt/x_test.dart', 'error': 'Failed to load', 'file': 'x'}
        self.assertEqual(nq.failure_kind(failure), 'compile')

    def test_first_line(self):
        self.assertEqual(nq.first_line('\n\n  hello  \nworld'), 'hello')


class CoverageTests(unittest.TestCase):
    def test_areas(self):
        paths = {
            'apps/raft_flutter/lib/features/a.dart': 'app/features',
            'apps/raft_flutter/lib/main.dart': 'app/(lib root)',
            'packages/raft_ui/lib/src/recipes/x.dart': 'raft_ui/recipes',
            'packages/raft_ui/lib/src/button.dart': 'raft_ui/src',
            'packages/raft_client/lib/src/proxy/p.dart': 'raft_client/proxy',
            'packages/raft_client/lib/raft_client.dart': 'raft_client/(lib)',
            'apps/raft_flutter/test/a_test.dart': None,
        }
        for path, area in paths.items():
            self.assertEqual(nq.area_of(path), area, path)

    def test_summary_skips_generated_and_test_files(self):
        coverage = {
            'apps/raft_flutter/lib/features/a.dart': {1: 1, 2: 0, 3: 0},
            'apps/raft_flutter/lib/features/b.g.dart': {1: 0},
            'apps/raft_flutter/test/a_test.dart': {1: 1},
            'packages/raft_ui/lib/src/button.dart': {1: 2},
        }
        areas, total = nq.area_summary(coverage)
        self.assertEqual(areas, {'app/features': (1, 3), 'raft_ui/src': (1, 1)})
        self.assertEqual(total, (2, 4))
        self.assertEqual(nq.pct(*total), '50.0%')
        self.assertEqual(nq.pct(0, 0), '-')

    def test_least_covered_files_orders_by_missed_lines(self):
        coverage = {'apps/raft_flutter/lib/features/a.dart': {i: 0 for i in range(50)},
                    'apps/raft_flutter/lib/features/b.dart': {i: (i % 2) for i in range(60)},
                    'apps/raft_flutter/lib/features/tiny.dart': {1: 0}}
        rows = nq.least_covered_files(coverage, count=5, minimum=40)
        self.assertEqual([r[2] for r in rows], ['apps/raft_flutter/lib/features/a.dart', 'apps/raft_flutter/lib/features/b.dart'])


class OsvTests(unittest.TestCase):
    def test_parse(self):
        report = {'results': [
            {'source': {'path': '/wt/pubspec.lock'}, 'packages': [
                {'package': {'name': 'archive', 'version': '3.0.0'}, 'vulnerabilities': [{'id': 'GHSA-b'}, {'id': 'GHSA-a'}]},
                {'package': {'name': 'dio', 'version': '5.0.0'}}]},
            {'source': {'path': '/wt/tool/pubspec.lock'}, 'packages': [{'package': {'name': 'x', 'version': '1'}}]},
        ]}
        parsed = nq.parse_osv(report)
        self.assertEqual(parsed['packages'], 3)
        self.assertEqual(parsed['lockfiles'], ['/wt/pubspec.lock', '/wt/tool/pubspec.lock'])
        self.assertEqual(parsed['vulns'], [{'lock': '/wt/pubspec.lock', 'package': 'archive', 'version': '3.0.0', 'ids': ['GHSA-a', 'GHSA-b']}])
        self.assertEqual(nq.parse_osv({}), {'packages': 0, 'lockfiles': [], 'vulns': []})

    def test_blind_spots_list_the_files_it_will_not_read(self):
        found = nq.blind_spot_files(['pubspec.lock', 'apps/a/macos/Podfile.lock', 'apps/a/android/build.gradle.kts', 'packages/p/android/build.gradle'])
        self.assertEqual(found['Podfile.lock'], ['apps/a/macos/Podfile.lock'])
        self.assertEqual(found['build.gradle*'], ['apps/a/android/build.gradle.kts', 'packages/p/android/build.gradle'])


class HelperTests(unittest.TestCase):
    def test_coverage_package_pattern_keeps_the_app_itself(self):
        # --coverage-package replaces flutter's default (the current package).
        import re
        for name in ('raft_flutter', 'raft_ui', 'raft_client', 'raft_sync'):
            self.assertTrue(re.search(nq.COVERAGE_PACKAGES, name), name)
        self.assertFalse(re.search(nq.COVERAGE_PACKAGES, 'dio'))

    def test_test_code_is_not_library_code(self):
        self.assertTrue(nq.is_test_code('apps/raft_flutter/test/a_test.dart'))
        self.assertTrue(nq.is_test_code('apps/raft_flutter/integration_test/support/open_smoke.dart'))
        self.assertFalse(nq.is_test_code('apps/raft_flutter/lib/features/chat_view.dart'))

    def test_durations(self):
        self.assertEqual([nq.fmt_duration(s) for s in (5, 65, 3725)], ['5s', '1m05s', '1h02m'])

    def test_previous_summary_is_the_newest_earlier_date(self):
        with tempfile.TemporaryDirectory() as tmp:
            for day in ('2026-10-10', '2026-10-12', '2026-10-14'):
                (Path(tmp) / day).mkdir()
                (Path(tmp) / day / 'summary.json').write_text('{}')
            (Path(tmp) / '2026-10-13').mkdir()  # no summary: skipped
            self.assertEqual(nq.pick_previous(tmp, '2026-10-14').parent.name, '2026-10-12')
            self.assertIsNone(nq.pick_previous(tmp, '2026-10-09'))

    def test_uncached_prs_go_first_newest_first(self):
        prs = [{'number': n} for n in (10, 11, 12, 13)]
        order = nq.order_prs(prs, lambda p: p['number'] in (11, 13))
        self.assertEqual([p['number'] for p in order], [12, 10, 13, 11])

    def test_cache_key_changes_with_head_or_base(self):
        pr = {'number': 7, 'headRefOid': 'a' * 40}
        self.assertEqual(nq.cache_key(pr, 'b' * 40), '7-aaaaaaaaaaaa-bbbbbbbbbbbb')
        self.assertNotEqual(nq.cache_key(pr, 'c' * 40), nq.cache_key(pr, 'b' * 40))


class GateLockTests(unittest.TestCase):
    def test_gives_up_after_the_bound_and_names_the_holder(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'gate.lock'
            first, second = nq.GateLock(path), nq.GateLock(path)
            self.assertEqual(first.acquire(1, 'branch=gate pid=1\n')[0], True)
            slept = []
            got, holder = second.acquire(0.05, 'x', poll=0.01, sleep=lambda s: (slept.append(s), time.sleep(s)))
            self.assertFalse(got)
            self.assertIn('branch=gate', holder)
            self.assertTrue(slept)
            first.release()
            self.assertTrue(second.acquire(1, 'branch=nightly\n')[0])
            second.release()

    def test_waits_for_a_gate_that_finishes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'gate.lock'
            gate = nq.GateLock(path)
            gate.acquire(1, 'gate\n')
            threading.Timer(0.1, gate.release).start()
            nightly = nq.GateLock(path)
            got, _ = nightly.acquire(5, 'nightly\n', poll=0.02)
            nightly.release()
            self.assertTrue(got)


class RunTests(unittest.TestCase):
    def test_timeout_kills_the_child_group_and_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            started = time.monotonic()
            done = nq.run([sys.executable, '-c', 'import time; time.sleep(60)'], tmp, Path(tmp) / 'log', 1)
            self.assertTrue(done['timed_out'])
            self.assertLess(time.monotonic() - started, 30)

    def test_exit_code(self):
        with tempfile.TemporaryDirectory() as tmp:
            done = nq.run([sys.executable, '-c', 'raise SystemExit(3)'], tmp, Path(tmp) / 'log', 30)
            self.assertEqual((done['code'], done['timed_out']), (3, False))


class SummaryTests(unittest.TestCase):
    def base(self, **extra):
        data = {'date': '2026-10-14', 'seed': 42, 'started': '03:00', 'seconds': 3600, 'lock_wait': 0, 'worktree': '/wt', 'out': '/out',
                'base': {'sha': 'a' * 40, 'subject': 'subject'}, 'notes': ['a note']}
        data.update(extra)
        return data

    def test_gate_busy_still_renders_osv(self):
        text = nq.render_summary(self.base(skipped='skipped: gate busy（等了 2h00m）', osv={
            'lockfiles': ['/wt/pubspec.lock'], 'packages': 252, 'vulns': [], 'blind': {'Podfile.lock': ['m/Podfile.lock']}}))
        self.assertIn('skipped: gate busy', text)
        self.assertIn('扫描 1 个 pubspec.lock，252 个包：未发现漏洞', text)
        self.assertIn('Podfile.lock', text)
        self.assertIn('未运行：skipped: gate busy', text)

    def test_aborted_run_says_what_did_not_run(self):
        text = nq.render_summary(self.base(aborted='异常中止：SystemExit: 143'))
        self.assertNotIn('未运行：无', text)
        self.assertEqual(text.count('未运行：运行被中止'), 4)  # tests, coverage, PR diff coverage, osv
        self.assertIn('SystemExit: 143', text)

    def test_aborted_after_tests_still_reports_prs_not_run(self):
        tests = [{'name': 'app', 'passed': 1, 'skipped': 0, 'seconds': 1, 'ok': True, 'timed_out': False, 'code': 0, 'log': 'l', 'limit': 5, 'failed': []}]
        coverage = {'total': [1, 2], 'areas': {'a': [1, 2]}, 'least': []}
        text = nq.render_summary(self.base(tests=tests, coverage=coverage, aborted='异常中止：KeyboardInterrupt: '))
        self.assertIn('## 3. 开放 PR 的 diff 覆盖（改动行里没有任何测试执行过的）\n- 未运行：运行被中止', text)
        self.assertNotIn('未运行：无', text)

    def test_unfinished_run_without_reason_is_unknown_not_none(self):
        text = nq.render_summary(self.base())
        self.assertNotIn('未运行：无', text)
        self.assertIn('状态未知', text)

    def test_failures_leaks_and_repro_line(self):
        tests = [{'name': 'app', 'passed': 10, 'skipped': 1, 'seconds': 120, 'ok': False, 'timed_out': False, 'code': 1, 'log': 'app.log', 'limit': 5400,
                  'failed': [{'file': 'apps/raft_flutter/test/a_test.dart', 'name': 'breaks', 'error': 'Expected: 1'},
                             {'file': 'apps/raft_flutter/test/b_test.dart', 'name': '(tearDownAll)', 'error': LEAK}]}]
        coverage = {'total': [50, 100], 'areas': {'app/features': [50, 100]}, 'least': [[40, 60, 'apps/raft_flutter/lib/x.dart']], 'delta': -0.5, 'previous_date': '2026-10-13'}
        text = nq.render_summary(self.base(tests=tests, coverage=coverage, prs=[
            {'number': 9, 'title': 'T', 'branch': 'b', 'head': 'c' * 40, 'status': 'diff 覆盖 1/2 = 50.0%', 'lines': ['`f.dart`：1/2，未执行 7'],
             'executable': 2, 'covered': 1}]))
        self.assertIn('1 个失败'.replace('1', '2'), text)
        self.assertIn('对象泄漏（leak_tracker）：1', text)
        self.assertIn('AttachmentTransfer, ValueNotifier<int>', text)
        self.assertIn('--test-randomize-ordering-seed 42', text)
        self.assertIn('lib 行覆盖 50.0%（较 2026-10-13 -0.50 个百分点）', text)
        self.assertIn('#9', text)
        self.assertIn('1 个开放 PR，1 个有未执行的改动行', text)


class TestEnvironmentTests(unittest.TestCase):
    def test_the_nightly_runs_the_full_tier_with_sampled_themes(self):
        import os
        import types
        from unittest import mock
        with tempfile.TemporaryDirectory() as tmp:
            args = types.SimpleNamespace(date='2026-10-19', out_dir=tmp, worktree=str(Path(tmp) / 'wt'), max_hours=1, seed=1)
            run = nq.Run(args)
            run.tmp = Path(tmp) / 'tmp'
            with mock.patch.dict(os.environ, {'RAFT_TEST_ALL_THEMES': '1', 'RAFT_TEST_TIER': 'gate'}):
                env = run.test_env()
        self.assertEqual(env['RAFT_TEST_TIER'], 'full')
        self.assertNotIn('RAFT_TEST_ALL_THEMES', env)
        self.assertEqual(env['RAFT_TEST_LOOKS'], 'raft')  # the legacy looks run in the legacy-looks suite

    def test_the_raft_run_leaves_tagged_legacy_files_to_the_legacy_suite(self):
        self.assertEqual(nq.LEGACY_TAG_EXCLUDES, ['-x', 'look-elegant', '-x', 'look-brutal'])

    def test_the_legacy_suite_runs_tool_theme_suite_for_every_legacy_look(self):
        import types
        from unittest import mock
        with tempfile.TemporaryDirectory() as tmp:
            args = types.SimpleNamespace(date='2026-10-25', out_dir=tmp, worktree=str(Path(tmp) / 'wt'), max_hours=1, seed=1, legacy_timeout_minutes=5)
            run = nq.Run(args)
            run.env = {}
            with mock.patch.object(nq, 'run', return_value={'code': 0, 'timed_out': False, 'seconds': 1.0}) as runner:
                suite = run.legacy_suite()
        command = runner.call_args.args[0]
        self.assertIn('theme-suite', command[1])
        self.assertEqual(command[command.index('--look') + 1], 'all')
        self.assertIn('--tests-only', command)
        self.assertEqual((suite['name'], suite['cwd']), ('legacy-looks', 'apps/raft_flutter'))


if __name__ == '__main__':
    unittest.main()
