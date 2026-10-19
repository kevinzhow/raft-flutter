import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import contextlib
import io
from pathlib import Path
import tempfile
import threading
import time
import unittest
import unittest.mock

PATH = Path(__file__).resolve().parents[1] / 'check-project'
LOADER = importlib.machinery.SourceFileLoader('check_project', str(PATH))
SPEC = importlib.util.spec_from_loader('check_project', LOADER)
check = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(check)


def events(*items):
    return [json.dumps(item) for item in items]


SUITE = {'type': 'suite', 'suite': {'id': 1, 'platform': 'vm', 'path': '/repo/apps/raft_flutter/test/a_test.dart'}, 'time': 0}


def started(test_id, name, time, suite=1):
    return {'type': 'testStart', 'test': {'id': test_id, 'name': name, 'suiteID': suite}, 'time': time}


def done(test_id, time, result='success', skipped=False, hidden=False):
    return {'type': 'testDone', 'testID': test_id, 'result': result, 'skipped': skipped, 'hidden': hidden, 'time': time}


class PartitionTests(unittest.TestCase):
    def test_balances_by_weight_and_keeps_every_file_once(self):
        weights = {'a': 100, 'b': 60, 'c': 50, 'd': 40, 'e': 10}
        plan = check.partition(list(weights), weights, 2)
        self.assertEqual(sorted(sum((p['files'] for p in plan), [])), sorted(weights))
        self.assertLessEqual(max(p['weight'] for p in plan), 140)  # optimum 130

    def test_is_deterministic(self):
        weights = {f'f{i}': 1 + i % 7 for i in range(40)}
        self.assertEqual(check.partition(list(weights), weights, 4), check.partition(list(reversed(list(weights))), weights, 4))

    def test_unknown_files_get_a_share_by_size_not_zero(self):
        weights = {'known': 10}
        plan = check.partition(['known', 'new_big', 'new_small'], weights, 2, {'known': 100, 'new_big': 1000, 'new_small': 10})
        bins = {tuple(p['files']): p['weight'] for p in plan}
        self.assertIn(('new_big',), bins)
        self.assertEqual(bins[('new_big',)], 100.0)

    def test_without_history_everything_is_equal(self):
        plan = check.partition([f'f{i}' for i in range(10)], {}, 5)
        self.assertEqual([len(p['files']) for p in plan], [2] * 5)

    def test_never_more_shards_than_files(self):
        self.assertEqual(len(check.partition(['a', 'b'], {}, 8)), 2)
        self.assertEqual(check.partition([], {}, 4), [{'files': [], 'weight': 0.0}])


class StructurePreflightTests(unittest.TestCase):
    def test_growth_stops_before_assets_or_tests_and_records_a_failed_run(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            with unittest.mock.patch.object(check, 'local', folder), \
                    unittest.mock.patch.object(check.subprocess, 'check_output', return_value='hash\n'), \
                    unittest.mock.patch.object(check, 'discover_tests', return_value=[]), \
                    unittest.mock.patch.object(check, 'history_weights', return_value={}), \
                    unittest.mock.patch.object(check, 'run_logged', side_effect=[0, 1]) as run, \
                    unittest.mock.patch.object(check, 'clear_unit_test_assets') as assets, \
                    contextlib.redirect_stderr(io.StringIO()):
                result = check.run_gate({}, unittest.mock.Mock(), 0)
            self.assertFalse(result['ok'])
            self.assertEqual(result['failed_checks'], ['structure-audit.txt'])
            self.assertEqual(run.call_count, 2)
            self.assertEqual(run.call_args.args[0][-1], '--check')
            self.assertTrue(any(str(arg).endswith('structure-audit') for arg in run.call_args.args[0]))
            assets.assert_not_called()
            receipt = json.loads((folder / 'engineering-run.json').read_text())
            self.assertFalse(receipt['completed'])
            self.assertEqual(receipt['shards'], [])


class ParallelismTests(unittest.TestCase):
    def test_default_scales_with_cpus_and_load(self):
        self.assertEqual(check.plan_parallelism(16, 0.0, {}, 'linux'), (5, 3))
        self.assertEqual(check.plan_parallelism(16, 0.0, {}, 'darwin'), (1, 8))
        self.assertEqual(check.plan_parallelism(16, 0.0, {'RAFT_CHECK_SHARDS': '2'}, 'darwin'), (2, 4))
        self.assertEqual(check.plan_parallelism(16, 10.0, {}, 'linux'), (3, 2))
        # A saturated 16-CPU machine keeps three shards instead of one.
        self.assertEqual(check.plan_parallelism(16, 30.0, {}, 'linux'), (3, 2))
        self.assertEqual(check.plan_parallelism(8, 30.0, {}, 'linux'), (2, 2))
        self.assertEqual(check.plan_parallelism(2, 8.0, {}, 'linux'), (1, 2))
        self.assertLessEqual(check.plan_parallelism(128, 0.0, {}, 'linux')[0], 8)

    def test_shard_timeout_scales_with_measured_work(self):
        self.assertEqual(check.shard_timeout_seconds(600, 3), 3600)
        self.assertEqual(check.shard_timeout_seconds(6000, 2), 7500)
        self.assertEqual(check.shard_timeout_seconds(6000, 2, '90'), 5400)
        self.assertEqual(check.shard_timeout_seconds(None, 2), 3600)

    def test_environment_overrides(self):
        self.assertEqual(check.plan_parallelism(16, 0.0, {'RAFT_CHECK_SHARDS': '3', 'RAFT_CHECK_JOBS': '1'}, 'linux'), (3, 1))

    def test_rejects_invalid_override(self):
        for bad in ('0', 'x', '-1'):
            with self.assertRaises(SystemExit):
                check.plan_parallelism(16, 0.0, {'RAFT_CHECK_SHARDS': bad}, 'linux')


class EventTests(unittest.TestCase):
    def parse(self, *items):
        return check.parse_test_events(events(*items), lambda p: p.replace('/repo/', ''))

    def test_passed_failed_skipped_and_durations(self):
        results = self.parse(
            SUITE,
            started(1, 'loading /repo/apps/raft_flutter/test/a_test.dart', 0), done(1, 4000, hidden=True),
            started(2, 'ok', 4000), done(2, 4500),
            started(3, 'bad', 4500), {'type': 'error', 'testID': 3, 'error': 'Expected: 1\n  Actual: 2', 'stackTrace': '', 'isFailure': True, 'time': 5000},
            done(3, 6500, result='failure'),
            started(4, 'skip me', 6500), done(4, 6500, skipped=True))
        summary = check.summarize_shard(results)
        self.assertEqual((summary['passed'], summary['skipped']), (1, 1))
        self.assertEqual([f['name'] for f in summary['failed']], ['bad'])
        self.assertEqual(summary['failed'][0]['error'], 'Expected: 1')
        self.assertEqual(summary['failed'][0]['file'], 'apps/raft_flutter/test/a_test.dart')
        files = check.file_durations(results, shard=2)
        self.assertEqual(files['apps/raft_flutter/test/a_test.dart'], {'seconds': 6.5, 'loadSeconds': 4.0, 'tests': 3, 'shard': 2})

    def test_hidden_bookkeeping_entries_are_not_counted_as_tests(self):
        results = self.parse(
            SUITE,
            started(1, 'loading /repo/apps/raft_flutter/test/a_test.dart', 0), done(1, 4000, hidden=True),
            started(2, 'ok', 4000), done(2, 4500),
            started(3, '(setUpAll)', 4500), done(3, 4600, hidden=True),
            started(4, '(tearDownAll)', 4600), done(4, 4700, hidden=True),
            started(5, 'skip me', 4700), done(5, 4700, skipped=True))
        summary = check.summarize_shard(results)
        self.assertEqual((summary['passed'], summary['skipped'], summary['hidden']), (1, 1, 2))
        self.assertEqual(summary['failed'], [])
        self.assertEqual(check.file_durations(results)['apps/raft_flutter/test/a_test.dart']['tests'], 2)

    def test_a_failing_hidden_entry_is_still_a_failure(self):
        results = self.parse(
            SUITE,
            started(1, 'ok', 0), done(1, 10),
            started(2, '(tearDownAll)', 10), {'type': 'error', 'testID': 2, 'error': 'Leaked: 1 object', 'stackTrace': '', 'isFailure': True, 'time': 20},
            done(2, 20, result='failure', hidden=True))
        summary = check.summarize_shard(results)
        self.assertEqual((summary['passed'], summary['hidden']), (1, 0))
        self.assertEqual([f['name'] for f in summary['failed']], ['(tearDownAll)'])

    def test_load_failure_and_timeout_are_failures(self):
        results = self.parse(SUITE, started(1, 'loading /repo/x', 0), {'type': 'error', 'testID': 1, 'error': 'Compilation failed', 'stackTrace': '', 'isFailure': False, 'time': 10},
                             done(1, 20, result='error', hidden=True),
                             started(2, 'hangs', 30), {'type': 'error', 'testID': 2, 'error': 'TimeoutException after 0:01:00: Test timed out after 60 seconds.', 'stackTrace': '', 'isFailure': False, 'time': 60030},
                             done(2, 60030, result='error'))
        failed = check.summarize_shard(results)['failed']
        self.assertEqual([f['name'] for f in failed], ['loading /repo/x', 'hangs'])
        self.assertIn('timed out after 60 seconds', failed[1]['error'])

    def test_truncated_stream_reports_incomplete_test(self):
        lines = events(SUITE, started(1, 'killed mid-test', 100)) + ['{"type":"testDo']
        results = check.parse_test_events(lines)
        self.assertEqual([r['status'] for r in results], ['incomplete'])
        self.assertEqual(len(check.summarize_shard(results)['failed']), 1)

    def test_slowest_tests_are_sorted_capped_and_exclude_loading(self):
        items = [SUITE, started(1, 'loading /repo/x', 0), done(1, 99000, hidden=True)]
        for i in range(2, 32):
            items += [started(i, f't{i}', 0), done(i, i * 100)]
        slow = check.slowest_tests(self.parse(*items))
        self.assertEqual(len(slow), 20)
        self.assertEqual(slow[0]['name'], 't31')
        self.assertEqual([s['seconds'] for s in slow], sorted((s['seconds'] for s in slow), reverse=True))
        self.assertFalse(any(s['name'].startswith('loading') for s in slow))


class PassGateTests(unittest.TestCase):
    def test_marker_is_required(self):
        self.assertTrue(check.has_pass_marker('00:01 +3: foo\n00:02 +4 ~1: All tests passed!\n'))
        self.assertFalse(check.has_pass_marker('00:01 +652: slow test\n'))
        self.assertFalse(check.has_pass_marker('00:01 +4 -1: Some tests failed.\n'))
        self.assertFalse(check.has_pass_marker(''))

    def test_marker_must_be_at_the_end_not_in_test_output(self):
        log = 'All tests passed!\n' + '\n'.join(f'00:0{i} +{i}: next' for i in range(9))
        self.assertFalse(check.has_pass_marker(log))

    def test_files_that_never_ran_are_found(self):
        results = [{'file': 'apps/raft_flutter/test/a_test.dart'}, {'file': ''}]
        self.assertEqual(check.unfinished_files(['apps/raft_flutter/test/a_test.dart', 'apps/raft_flutter/test/b_test.dart'], results),
                         ['apps/raft_flutter/test/b_test.dart'])

    def test_repo_path_maps_app_relative_package_paths(self):
        self.assertEqual(check.repo_path('test/a_test.dart'), 'apps/raft_flutter/test/a_test.dart')
        self.assertEqual(check.repo_path('../../packages/raft_ui/test/c_test.dart'), 'packages/raft_ui/test/c_test.dart')


class SummaryTests(unittest.TestCase):
    def test_lists_failed_test_names_and_slowest(self):
        shards = [{'index': 0, 'passed': False, 'seconds': 61.2, 'files': ['a'], 'log': 'test-shard-0.txt'}]
        failures = [{'name': 'group hangs', 'file': 'apps/raft_flutter/test/a_test.dart', 'status': 'failed', 'error': 'Test timed out after 60 seconds.', 'shard': 0},
                    {'name': 'cut off', 'file': 'apps/raft_flutter/test/b_test.dart', 'status': 'incomplete', 'error': '', 'shard': 0}]
        text = check.format_summary(shards, failures, {'passed': 9, 'skipped': 1}, [{'name': 'slow one', 'file': 'f', 'seconds': 12.3}])
        self.assertIn('9 passed, 1 skipped, 2 failed across 1 shard(s)', text)
        self.assertIn('[0] apps/raft_flutter/test/a_test.dart: group hangs -- Test timed out after 60 seconds.', text)
        self.assertIn('cut off -- did not finish', text)
        self.assertIn('12.3s  f: slow one', text)

    def test_hidden_entries_are_reported_apart_from_the_test_count(self):
        text = check.format_summary([], [], {'passed': 9, 'skipped': 1, 'hidden': 4}, [])
        self.assertIn('9 passed, 1 skipped, 0 failed', text)
        self.assertIn('4 hidden setUpAll/tearDownAll entries are not counted as tests', text)
        self.assertNotIn('hidden', check.format_summary([], [], {'passed': 9, 'skipped': 1}, []))

    def test_limit_truncates_the_listing_not_the_count(self):
        failures = [{'name': f't{i}', 'file': 'f', 'status': 'failed', 'error': 'e', 'shard': 0} for i in range(5)]
        text = check.format_summary([], failures, {'passed': 0, 'skipped': 0}, [], limit=2)
        self.assertIn('5 failed', text)
        self.assertIn('f: t1', text)
        self.assertNotIn('f: t2', text)
        self.assertIn('and 3 more', text)

    def test_history_weights_read_previous_run(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            (repo / '.local').mkdir()
            (repo / '.local/check-durations.json').write_text(json.dumps({'files': {'a': {'seconds': 3.5}, 'b': {'seconds': 0}}}))
            self.assertEqual(check.history_weights(repo), {'a': 3.5})
            self.assertEqual(check.history_weights(repo / 'missing'), {})


class DiscoveryTests(unittest.TestCase):
    def test_finds_app_and_package_tests_relative_to_the_app(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            for name in ['apps/raft_flutter/test/a_test.dart', 'apps/raft_flutter/test/parity/b_test.dart', 'apps/raft_flutter/test/helper.dart', 'packages/raft_ui/test/c_test.dart']:
                (base / name).parent.mkdir(parents=True, exist_ok=True)
                (base / name).write_text('')
            self.assertEqual(check.discover_tests(base), ['test/a_test.dart', 'test/parity/b_test.dart', '../../packages/raft_ui/test/c_test.dart'])


if __name__ == '__main__':
    unittest.main()


class UnitTestAssetsTests(unittest.TestCase):
    def test_clears_cached_test_assets_and_keeps_other_build_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app = root / 'apps/raft_flutter/build/unit_test_assets/shaders'
            pkg = root / 'packages/raft_ui/build/unit_test_assets'
            apk = root / 'apps/raft_flutter/build/app/outputs'
            for d in (app, pkg, apk):
                d.mkdir(parents=True)
            (app / 'ink_sparkle.frag').write_text('vulkan only')
            removed = check.clear_unit_test_assets(root)
            self.assertEqual(len(removed), 2)
            self.assertFalse(app.parent.exists())
            self.assertFalse(pkg.exists())
            self.assertTrue(apk.is_dir())
            self.assertEqual(check.clear_unit_test_assets(root), [])


class RunTmpTests(unittest.TestCase):
    def test_creates_a_per_run_directory_and_removes_those_of_dead_runs(self):
        with tempfile.TemporaryDirectory() as tmp:
            local = Path(tmp) / '.local'
            local.mkdir()
            dead = local / 'tmp-4000000'  # no such pid
            dead.mkdir()
            (dead / 'flutter_tools.x').mkdir()
            alive = local / 'tmp-1'  # pid 1 exists
            alive.mkdir()
            (local / 'tmp-notanumber').mkdir()
            run = check.make_run_tmp(local, pid=777)
            self.assertEqual(run, local / 'tmp-777')
            self.assertTrue(run.is_dir())
            self.assertFalse(dead.exists())
            self.assertTrue(alive.exists())
            self.assertTrue((local / 'tmp-notanumber').exists())

    def test_children_get_the_directory_as_their_temp_dir(self):
        env = check.with_run_tmp({'PATH': '/bin', 'TMPDIR': '/tmp'}, Path('/w/.local/tmp-1'))
        self.assertEqual((env['TMPDIR'], env['TEMP'], env['TMP']), ('/w/.local/tmp-1',) * 3)
        self.assertEqual(env['PATH'], '/bin')

    def test_root_is_outside_the_checkout(self):
        # A throwaway git repository built in TMPDIR must not find the enclosing checkout.
        repo = Path(__file__).resolve().parents[2]
        with unittest.mock.patch.dict('os.environ', {'XDG_CACHE_HOME': '/c'}):
            self.assertEqual(check.run_tmp_root(), Path('/c/raft-flutter/gate-tmp'))
        root = check.run_tmp_root().resolve()
        self.assertFalse(root == repo or repo in root.parents)


class WarmupTests(unittest.TestCase):
    def test_picks_the_smallest_app_test(self):
        sizes = {'test/b_test.dart': 900, 'test/a_test.dart': 120, '../../packages/raft_ui/test/x_test.dart': 10}
        files = list(sizes) + ['test/missing_test.dart']
        self.assertEqual(check.smallest_app_test(files, sizes), 'test/a_test.dart')
        self.assertIsNone(check.smallest_app_test(['../../packages/x/test/y_test.dart'], {}))


class FakeChild:
    def __init__(self, exits_at=None, clock=None):
        self.exits_at, self.clock = exits_at, clock

    def poll(self):
        return 1 if self.exits_at is not None and self.clock.now >= self.exits_at else None


class FakeClock:
    """Time that only moves when the code under test sleeps."""

    def __init__(self, on_sleep=lambda now: None):
        self.now, self.on_sleep = 0.0, on_sleep

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds
        self.on_sleep(self.now)


class StartupGateTests(unittest.TestCase):
    def make_gate(self, tmp, timeout=30, on_sleep=lambda now: None):
        clock = FakeClock(on_sleep)
        return check.StartupGate(timeout=timeout, poll=1, clock=clock, sleep=clock.sleep), clock, Path(tmp) / 'events.json'

    def test_slot_is_released_once_the_event_file_has_content(self):
        with tempfile.TemporaryDirectory() as tmp:
            events = Path(tmp) / 'events.json'
            gate, clock, _ = self.make_gate(tmp, on_sleep=lambda now: events.write_text('{"type":"start"}') if now >= 4 else None)
            self.assertEqual(gate.wait_started(FakeChild(), events), 'started')
            self.assertEqual(clock.now, 4)

    def test_an_empty_event_file_does_not_count_as_started(self):
        with tempfile.TemporaryDirectory() as tmp:
            events = Path(tmp) / 'events.json'
            events.touch()
            gate, clock, _ = self.make_gate(tmp, timeout=5)
            self.assertEqual(gate.wait_started(FakeChild(), events), 'timeout')
            self.assertEqual(clock.now, 5)

    def test_a_shard_that_exits_during_startup_gives_the_slot_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            gate, clock, events = self.make_gate(tmp)
            self.assertEqual(gate.wait_started(FakeChild(exits_at=2, clock=clock), events), 'exited')
            self.assertEqual(clock.now, 2)

    def test_stop_request_ends_the_wait(self):
        with tempfile.TemporaryDirectory() as tmp:
            gate, clock, events = self.make_gate(tmp)
            self.assertEqual(gate.wait_started(FakeChild(), events, stopping=lambda: clock.now >= 3), 'stopped')

    def test_second_shard_waits_for_the_first_to_finish_starting(self):
        gate = check.StartupGate()
        order, first_in, second_tried = [], threading.Event(), threading.Event()

        def second():
            first_in.wait()
            second_tried.set()
            gate.enter()
            order.append('second in')
            gate.leave()

        thread = threading.Thread(target=second)
        thread.start()
        gate.enter()
        first_in.set()
        second_tried.wait()
        thread.join(0.2)  # the second shard stays blocked while the first holds the slot
        self.assertTrue(thread.is_alive())
        self.assertEqual(order, [])
        gate.leave()
        thread.join(5)
        self.assertEqual(order, ['second in'])

    def test_leave_is_idempotent_and_only_for_the_holder(self):
        gate = check.StartupGate()
        gate.leave()  # not held: no error
        gate.enter()
        gate.leave()
        gate.leave()
        gate.enter()  # the slot is free again
        gate.leave()

    def test_run_shard_holds_the_slot_until_startup_ends_but_not_while_tests_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            gate = check.StartupGate(timeout=5, poll=0.01)
            seen = {}

            def fake_run_logged(args, cwd, log, env, timeout, outcome, after_start):
                events = Path(args[args.index('--file-reporter') + 1].removeprefix('json:'))
                threading.Timer(0.1, lambda: events.write_text('{}')).start()
                after_start(FakeChild())
                seen['free_after_start'] = gate._slot.acquire(blocking=False)
                if seen['free_after_start']:
                    gate._slot.release()
                return 0

            with unittest.mock.patch.object(check, 'local', Path(tmp)), unittest.mock.patch.object(check, 'run_logged', fake_run_logged):
                shard = check.run_shard(3, ['test/a_test.dart'], 2, {}, 60, gate)
            self.assertTrue(seen['free_after_start'])
            self.assertEqual(shard['startup'][0], 'started')
            self.assertEqual(shard['code'], 0)

    def test_a_queued_shard_does_not_show_the_last_runs_log(self):
        with tempfile.TemporaryDirectory() as tmp:
            stale = Path(tmp) / 'test-shard-1.txt'
            stale.write_text('00:01 +0 -1: test/old_test.dart: from the last run [E]\n')
            (Path(tmp) / 'test-shard-1.json').write_text('{}')
            with unittest.mock.patch.object(check, 'local', Path(tmp)):
                logs, events = check.fresh_shard_outputs(2)
            self.assertEqual([p.name for p in logs], ['test-shard-0.txt', 'test-shard-1.txt'])
            self.assertEqual(check.LogTail(logs[1]).read(), '')  # still waiting for its startup turn
            self.assertFalse(events[1].exists())

    def test_run_shard_gives_the_slot_back_when_the_child_cannot_start(self):
        with tempfile.TemporaryDirectory() as tmp:
            gate = check.StartupGate()

            def failing(*args, **kwargs):
                raise OSError('no flutter')

            with unittest.mock.patch.object(check, 'local', Path(tmp)), unittest.mock.patch.object(check, 'run_logged', failing):
                with self.assertRaises(OSError):
                    check.run_shard(0, [], 2, {}, 60, gate)
            gate.enter()  # not deadlocked
            gate.leave()


def failure(file, name='boom', shard=0, status='failed'):
    return {'name': name, 'file': file, 'status': status, 'error': '', 'shard': shard}


class RetryDecisionTests(unittest.TestCase):
    def test_failed_test_files_are_retried_once_each(self):
        failures = [failure('a_test.dart', 'one'), failure('a_test.dart', 'two'), failure('b_test.dart')]
        decision = check.retry_decision(failures, True, None, 3)
        self.assertEqual(decision, {'files': ['a_test.dart', 'b_test.dart'], 'skip': None})

    def test_a_file_that_never_finished_is_retried_too(self):
        decision = check.retry_decision([failure('a_test.dart', '(file never ran)', status='incomplete')], True, None, 3)
        self.assertEqual(decision['files'], ['a_test.dart'])

    def test_six_files_still_retry_and_seven_do_not(self):
        six = [failure(f'f{i}_test.dart') for i in range(6)]
        self.assertEqual(len(check.retry_decision(six, True, None, 3)['files']), 6)
        seven = [failure(f'f{i}_test.dart') for i in range(7)]
        decision = check.retry_decision(seven, True, None, 3)
        self.assertEqual(decision['files'], [])
        self.assertIn('7 test files', decision['skip'])

    def test_many_failed_tests_in_few_files_still_count_files(self):
        failures = [failure('a_test.dart', f't{i}') for i in range(20)]
        self.assertEqual(check.retry_decision(failures, True, None, 3)['files'], ['a_test.dart'])

    def test_another_failing_check_means_no_retry(self):
        decision = check.retry_decision([failure('a_test.dart')], False, None, 3)
        self.assertEqual(decision['files'], [])

    def test_an_early_stop_means_no_retry(self):
        stop = {'reason': 'max-failures'}
        self.assertEqual(check.retry_decision([failure('a_test.dart')], True, stop, 3)['files'], [])

    def test_retries_zero_turns_it_off(self):
        self.assertEqual(check.retry_decision([failure('a_test.dart')], True, None, 0)['files'], [])

    def test_a_failure_without_a_test_file_means_no_retry(self):
        for bad in (failure(''), failure('?'), failure('a_test.dart', '(load/compile error)')):
            self.assertEqual(check.retry_decision([failure('b_test.dart'), bad], True, None, 3)['files'], [], bad)

    def test_nothing_failed_nothing_to_retry(self):
        self.assertEqual(check.retry_decision([], True, None, 3)['files'], [])


class RetryFilesTests(unittest.TestCase):
    def test_a_file_that_passes_on_a_retry_is_a_flake_with_the_first_runs_failed_tests(self):
        failures = [failure('a_test.dart', 'one'), failure('a_test.dart', 'one'), failure('a_test.dart', 'two'), failure('a_test.dart', '(file never ran)')]
        calls = []

        def run_once(file, attempt):
            calls.append((file, attempt))
            return attempt == 2

        flaky, still = check.retry_files(['a_test.dart'], failures, 3, run_once)
        self.assertEqual(flaky, [{'file': 'a_test.dart', 'tests': ['one', 'two'], 'errors': [], 'attempts': 2}])
        self.assertEqual(still, [])
        self.assertEqual(calls, [('a_test.dart', 1), ('a_test.dart', 2)])  # stops at the first pass

    def test_a_file_failing_every_attempt_stays_failed(self):
        calls = []
        flaky, still = check.retry_files(['a_test.dart'], [failure('a_test.dart')], 3, lambda f, n: calls.append(n) and False)
        self.assertEqual(flaky, [])
        self.assertEqual(still, [{'file': 'a_test.dart', 'attempts': 3}])
        self.assertEqual(calls, [1, 2, 3])

    def test_files_are_judged_independently(self):
        flaky, still = check.retry_files(['a_test.dart', 'b_test.dart'], [failure('a_test.dart'), failure('b_test.dart')], 3, lambda f, n: f == 'a_test.dart')
        self.assertEqual([f['file'] for f in flaky], ['a_test.dart'])
        self.assertEqual([f['file'] for f in still], ['b_test.dart'])
        self.assertEqual(flaky[0]['attempts'], 1)

    def test_retry_passed_needs_exit_zero_marker_and_every_test_finished(self):
        good = check.parse_test_events(events(SUITE, started(1, 'x', 0), done(1, 5)), lambda p: 'a_test.dart')
        self.assertTrue(check.retry_passed(0, 'ok\nAll tests passed!\n', good, ['a_test.dart']))
        self.assertFalse(check.retry_passed(1, 'All tests passed!\n', good, ['a_test.dart']))
        self.assertFalse(check.retry_passed(0, 'no marker\n', good, ['a_test.dart']))
        self.assertFalse(check.retry_passed(0, 'All tests passed!\n', good, ['other_test.dart']))
        bad = check.parse_test_events(events(SUITE, started(1, 'x', 0), done(1, 5, result='failure')), lambda p: 'a_test.dart')
        self.assertFalse(check.retry_passed(0, 'All tests passed!\n', bad, ['a_test.dart']))

    def test_summary_lists_flakes_and_still_failing_files(self):
        flaky = [{'file': 'a_test.dart', 'tests': ['one', 'two'], 'attempts': 2}]
        text = check.format_summary([], [], {'passed': 3, 'skipped': 0}, [], flaky=flaky, retry_failed=[{'file': 'b_test.dart', 'attempts': 3}])
        self.assertIn('FLAKY (passed on retry):', text)
        self.assertIn('a_test.dart (retry attempt 2): one; two', text)
        self.assertIn('Still failing after retries:', text)
        self.assertNotIn('FLAKY', check.format_summary([], [], {'passed': 3, 'skipped': 0}, []))


def test_events(path, name, ok):
    suite = {'type': 'suite', 'suite': {'id': 1, 'platform': 'vm', 'path': str(path)}, 'time': 0}
    return events(suite, started(10, f'loading {path}', 0), done(10, 1), started(11, name, 1), done(11, 2, result='success' if ok else 'failure'))


class RunGateRetryTests(unittest.TestCase):
    """run_gate end to end with fake child processes: one scripted outcome list per test file."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'apps/raft_flutter/test').mkdir(parents=True)
        self.script, self.calls, self.analyze_ok = {}, [], True
        env = unittest.mock.patch.dict(os.environ, {'RAFT_CHECK_MAX_FAILURES': '0', 'RAFT_CHECK_SHARDS': '2'})
        env.start()
        self.addCleanup(env.stop)
        for name, value in (('root', self.root), ('local', self.root / '.local'), ('app_dir', self.root / 'apps/raft_flutter')):
            patcher = unittest.mock.patch.object(check, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        for patcher in (unittest.mock.patch.object(check, 'run_logged', self.fake_run), unittest.mock.patch.object(check.subprocess, 'check_output', lambda *a, **k: 'hash')):
            patcher.start()
            self.addCleanup(patcher.stop)

    def add_tests(self, **outcomes):
        """name -> list of per-run outcomes (True = passes); the last one repeats."""
        for name, runs in outcomes.items():
            (self.root / 'apps/raft_flutter/test' / f'{name}_test.dart').write_text('void main() {}\n')
            self.script[f'test/{name}_test.dart'] = list(runs)

    def fake_run(self, args, cwd, log_path, env, timeout=None, outcome=None, after_start=None):
        args = [str(a) for a in args]
        if '--file-reporter' not in args:
            Path(log_path).write_text('ok\n')
            return 1 if 'analyze' in args and not self.analyze_ok else 0
        files = args[args.index('test') + 1:args.index('--no-pub')]
        events_path = Path(args[args.index('--file-reporter') + 1].removeprefix('json:'))
        retry = events_path.name.startswith('retry-')
        lines, ok = [], True
        for file in files:
            self.calls.append((file, 'retry' if retry else 'shard'))
            runs = self.script[file]
            passed = runs.pop(0) if len(runs) > 1 else runs[0]
            ok = ok and passed
            lines += test_events(self.root / 'apps/raft_flutter' / file, 'sample test', passed)
        events_path.write_text('\n'.join(lines) + '\n')
        Path(log_path).write_text('All tests passed!\n' if ok else 'Some tests failed.\n')
        if after_start:
            after_start(FakeChild())
        return 0 if ok else 1

    def run_it(self):
        emitted = []

        def emit(event, /, notify=None, **details):
            emitted.append(event)

        emit.message = lambda *a: ''
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            outcome = check.run_gate(dict(os.environ), emit, 0.0)
        return outcome, json.loads(out.getvalue().strip().splitlines()[-1]), emitted

    def retries(self, file):
        return [c for c in self.calls if c == (file, 'retry')]

    def test_a_flaky_file_passes_the_run_and_is_listed_in_the_json(self):
        self.add_tests(a=[False, True], b=[True])
        outcome, result, emitted = self.run_it()
        self.assertTrue(outcome['ok'])
        self.assertTrue(result['passed'])
        self.assertEqual(result['flaky'], [{'file': 'apps/raft_flutter/test/a_test.dart', 'tests': ['sample test'], 'errors': [], 'attempts': 1}])
        self.assertEqual(len(self.retries('test/a_test.dart')), 1)
        self.assertEqual(self.retries('test/b_test.dart'), [])
        self.assertTrue(all(result['checks'].values()))
        self.assertIn('FLAKY (passed on retry)', (self.root / '.local/check-summary.txt').read_text())
        self.assertIn('All tests passed!', (self.root / '.local/all-project-tests.txt').read_text())
        self.assertIn('FLAKY', emitted)

    def test_a_file_failing_all_three_attempts_keeps_the_run_failed(self):
        self.add_tests(a=[False], b=[True])
        outcome, result, _ = self.run_it()
        self.assertFalse(outcome['ok'])
        self.assertFalse(result['passed'])
        self.assertNotIn('flaky', result)
        self.assertEqual(len(self.retries('test/a_test.dart')), 3)
        self.assertFalse(result['checks']['all-project-tests.txt'])
        self.assertIn('Still failing after retries', (self.root / '.local/check-summary.txt').read_text())

    def test_a_flake_and_a_real_failure_in_one_run(self):
        self.add_tests(a=[False, True], b=[False])
        outcome, result, _ = self.run_it()
        self.assertFalse(result['passed'])
        self.assertEqual([f['file'] for f in result['flaky']], ['apps/raft_flutter/test/a_test.dart'])
        self.assertEqual([f['file'] for f in outcome['failures']], ['apps/raft_flutter/test/b_test.dart'])

    def test_more_than_six_failed_files_are_not_retried(self):
        self.add_tests(**{f'f{i}': [False, True] for i in range(7)})
        outcome, result, _ = self.run_it()
        self.assertFalse(result['passed'])
        self.assertEqual([c for c in self.calls if c[1] == 'retry'], [])

    def test_a_failing_analysis_is_never_retried(self):
        self.analyze_ok = False
        self.add_tests(a=[False, True])
        outcome, result, _ = self.run_it()
        self.assertFalse(result['passed'])
        self.assertFalse(result['checks']['analyze-all.txt'])
        self.assertEqual(self.retries('test/a_test.dart'), [])

    def test_retries_zero_is_the_opt_out(self):
        self.add_tests(a=[False, True])
        with unittest.mock.patch.dict(os.environ, {'RAFT_CHECK_RETRIES': '0'}):
            outcome, result, _ = self.run_it()
        self.assertFalse(result['passed'])
        self.assertEqual(self.retries('test/a_test.dart'), [])

    def test_a_clean_run_has_no_flaky_key_and_no_retry(self):
        self.add_tests(a=[True], b=[True])
        outcome, result, _ = self.run_it()
        self.assertTrue(result['passed'])
        self.assertNotIn('flaky', result)
        self.assertEqual([c for c in self.calls if c[1] == 'retry'], [])


def git(cwd, *args):
    return subprocess.check_output(['git', *args], cwd=cwd, text=True, env=dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t', GIT_COMMITTER_EMAIL='t@t')).strip()


class ReuseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name) / 'repo'
        self.repo.mkdir()
        self.cache = Path(self.tmp.name) / 'cache'
        self.env = {'RAFT_CHECK_CACHE': str(self.cache)}
        git(self.repo, 'init', '-q')
        (self.repo / 'a.txt').write_text('one\n')
        git(self.repo, 'add', '.')
        git(self.repo, 'commit', '-q', '-m', 'one')

    def tree(self):
        return git(self.repo, 'rev-parse', 'HEAD^{tree}')

    def test_clean_tree_hash_is_the_head_tree_and_none_when_dirty(self):
        self.assertEqual(check.clean_tree_hash(self.repo), self.tree())
        (self.repo / 'a.txt').write_text('changed\n')
        self.assertIsNone(check.clean_tree_hash(self.repo))
        git(self.repo, 'checkout', '-q', 'a.txt')
        (self.repo / 'new.txt').write_text('untracked\n')
        self.assertIsNone(check.clean_tree_hash(self.repo))

    def test_cache_dir_defaults_under_home_and_honours_the_override(self):
        self.assertEqual(check.cache_root({'RAFT_CHECK_CACHE': '/x/y'}), Path('/x/y'))
        self.assertEqual(check.cache_root({}), Path.home() / '.cache' / 'raft-check')

    def test_a_recorded_pass_is_found_for_the_same_tree(self):
        tree = self.tree()
        result = {'passed': True, 'sourceChanged': False, 'checks': {'x': True}, 'flaky': [{'file': 'a', 'tests': [], 'attempts': 1}]}
        path = check.record_pass(tree, 'abc123', result, 'sampled', {'themes': 'sampled'}, env=self.env, now=time.gmtime(0))
        self.assertEqual(path, self.cache / 'passed' / f'{tree}.json')
        record = json.loads(path.read_text())
        self.assertEqual((record['tree'], record['commit'], record['time'], record['result']), (tree, 'abc123', '1970-01-01T00:00:00Z', result))
        found = check.reusable_pass('sampled', self.repo, self.env)
        self.assertEqual(found['result'], result)  # the flakes stay listed
        self.assertIn(f'tree {tree} already passed at 1970-01-01T00:00:00Z on abc123; reusing', check.reuse_message(found))

    def test_a_different_tree_misses(self):
        check.record_pass(self.tree(), 'abc', {'passed': True}, 'sampled', env=self.env)
        (self.repo / 'a.txt').write_text('two\n')
        git(self.repo, 'commit', '-q', '-am', 'two')
        self.assertIsNone(check.reusable_pass('sampled', self.repo, self.env))

    def test_the_same_tree_under_another_commit_still_hits(self):
        check.record_pass(self.tree(), 'abc', {'passed': True}, 'sampled', env=self.env)
        git(self.repo, 'commit', '-q', '--allow-empty', '-m', 'same tree again')
        self.assertIsNotNone(check.reusable_pass('sampled', self.repo, self.env))

    def test_a_dirty_worktree_never_reuses(self):
        check.record_pass(self.tree(), 'abc', {'passed': True}, 'sampled', env=self.env)
        (self.repo / 'a.txt').write_text('dirty\n')
        self.assertIsNone(check.reusable_pass('sampled', self.repo, self.env))

    def test_no_record_and_unreadable_records_miss(self):
        self.assertIsNone(check.reusable_pass('sampled', self.repo, self.env))
        path = check.passed_record_path(self.tree(), self.env)
        path.parent.mkdir(parents=True)
        path.write_text('not json')
        self.assertIsNone(check.reusable_pass('sampled', self.repo, self.env))
        path.write_text(json.dumps({'tree': self.tree(), 'result': {'passed': False}}))
        self.assertIsNone(check.reusable_pass('sampled', self.repo, self.env))

    def test_a_sampled_pass_does_not_cover_all_themes_but_the_reverse_does(self):
        check.record_pass(self.tree(), 'abc', {'passed': True}, 'sampled', env=self.env)
        self.assertIsNone(check.reusable_pass('all', self.repo, self.env))
        check.record_pass(self.tree(), 'abc', {'passed': True}, 'all', env=self.env)
        self.assertIsNotNone(check.reusable_pass('sampled', self.repo, self.env))
        self.assertIsNone(check.record_pass(self.tree(), 'abc', {'passed': True}, 'sampled', env=self.env))  # keeps the all-themes record
        self.assertIsNotNone(check.reusable_pass('all', self.repo, self.env))

    def test_an_unwritable_cache_does_not_raise(self):
        blocker = Path(self.tmp.name) / 'file'
        blocker.write_text('x')
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertIsNone(check.record_pass(self.tree(), 'abc', {'passed': True}, 'sampled', env={'RAFT_CHECK_CACHE': str(blocker)}))

    def run_main(self, argv, gate_outcome=None):
        gate = unittest.mock.Mock(return_value=gate_outcome or {'ok': True, 'failures': [], 'stop': None, 'changed': False, 'failed_checks': [],
                                                                  'flaky': [], 'result': {'passed': True, 'checks': {}}, 'run_record': {'themes': 'sampled'}})

        class Silent:
            def __init__(self, *a):
                pass

            def __call__(self, *a, **k):
                pass

            def message(self, *a):
                return ''

        patches = [unittest.mock.patch.object(check, 'root', self.repo), unittest.mock.patch.object(check, 'local', self.repo / '.local'),
                   unittest.mock.patch.object(check, 'run_gate', gate), unittest.mock.patch.object(check.gate_events, 'Events', Silent),
                   unittest.mock.patch.object(check.gate_events, 'raise_on_signals', lambda: None),
                   unittest.mock.patch.object(check, 'run_tmp_root', lambda: Path(self.tmp.name) / 'tmp'),
                   unittest.mock.patch.object(sys, 'argv', ['check-project', *argv]), unittest.mock.patch.dict(os.environ, self.env)]
        for patcher in patches:
            patcher.start()
        self.addCleanup(check.STOP.clear)  # main() stops its children on the way out
        try:
            with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as raised:
                    check.main()
        finally:
            for patcher in reversed(patches):
                patcher.stop()
        return raised.exception.code, out.getvalue(), gate

    def test_reuse_hit_prints_the_line_and_the_stored_json_and_runs_nothing(self):
        tree = self.tree()
        stored = {'passed': True, 'sourceChanged': False, 'checks': {'x': True}}
        check.record_pass(tree, 'abc', stored, 'sampled', {'themes': 'sampled', 'completed': True}, env=self.env, now=time.gmtime(0))
        code, out, gate = self.run_main(['--reuse'])
        self.assertEqual(code, 0)
        gate.assert_not_called()
        lines = out.strip().splitlines()
        self.assertEqual(lines[0], f'check-project: tree {tree} already passed at 1970-01-01T00:00:00Z on abc; reusing')
        self.assertEqual(json.loads(lines[-1]), {**stored, 'reused': True})
        self.assertTrue(json.loads((self.repo / '.local/engineering-run.json').read_text())['completed'])

    def test_reuse_miss_runs_the_checks_and_records_the_pass(self):
        tree = self.tree()
        code, out, gate = self.run_main(['--reuse'])
        gate.assert_called_once()
        self.assertEqual(code, 0)
        self.assertEqual(check.read_pass_record(tree, self.env)['commit'], git(self.repo, 'rev-parse', 'HEAD'))

    def test_reuse_with_a_dirty_worktree_runs_and_records_nothing(self):
        check.record_pass(self.tree(), 'abc', {'passed': True}, 'sampled', env=self.env)
        (self.repo / 'a.txt').write_text('dirty\n')
        code, out, gate = self.run_main(['--reuse'])
        gate.assert_called_once()
        self.assertNotIn('reused', out)

    def test_a_run_without_the_flag_never_reuses_but_records_a_clean_pass(self):
        check.record_pass(self.tree(), 'abc', {'passed': True}, 'sampled', env=self.env)
        code, out, gate = self.run_main([])
        gate.assert_called_once()

    def test_a_failed_run_is_not_recorded(self):
        outcome = {'ok': False, 'failures': [], 'stop': None, 'changed': False, 'failed_checks': ['analyze-all.txt'], 'flaky': [], 'result': {'passed': False}}
        code, out, gate = self.run_main([], outcome)
        self.assertEqual(code, 1)
        self.assertIsNone(check.read_pass_record(self.tree(), self.env))

    def test_unknown_arguments_and_help(self):
        with self.assertRaises(SystemExit):
            check.parse_args(['--nope'])
        self.assertEqual(check.parse_args(['--reuse', '--all-themes']), (True, True))
        self.assertEqual(check.parse_args([]), (False, False))


class FlakyEvidenceTests(unittest.TestCase):
    def test_first_run_errors_are_kept_for_a_flake(self):
        failures = [
            {'file': 'a_test.dart', 'name': 'one', 'error': 'Expected: <14>\n  Actual: <6.4>', 'status': 'failed'},
            {'file': 'a_test.dart', 'name': 'two', 'error': 'Expected: <14>\n  Actual: <6.4>', 'status': 'failed'},
            {'file': 'b_test.dart', 'name': 'three', 'error': 'other file', 'status': 'failed'},
            {'file': 'a_test.dart', 'name': 'four', 'error': 'x' * 400, 'status': 'failed'},
        ]
        errors = check.first_run_errors(failures, 'a_test.dart')
        self.assertEqual(errors[0], 'Expected: <14>\n  Actual: <6.4>')
        self.assertEqual(len(errors), 2)
        self.assertTrue(errors[1].endswith('…'))
        self.assertLessEqual(len(errors[1]), 301)


class StaticFailFastTests(unittest.TestCase):
    """A failed analysis, lint or host-test run stops the gate before the Dart shards finish."""

    def _done(self, value):
        import concurrent.futures
        future = concurrent.futures.Future()
        future.set_result(value)
        return future

    def test_failed_static_check_is_a_verdict(self):
        import concurrent.futures
        pending = concurrent.futures.Future()
        verdict = check.static_failure({'analyze-all.txt': self._done(False), 'raft-lints.txt': pending})
        self.assertEqual(verdict['reason'], 'static-check')
        self.assertEqual(verdict['fields'], {'check': 'analyze-all.txt'})

    def test_passing_or_running_checks_do_not_stop(self):
        import concurrent.futures
        self.assertIsNone(check.static_failure({'analyze-all.txt': self._done(True),
                                                'raft-lints.txt': concurrent.futures.Future()}))
        self.assertIsNone(check.static_failure({}))

    def test_abort_message_names_the_check(self):
        class Emit:
            def message(self, *lines):
                return lines
        lines = check.abort_message(Emit(), {'reason': 'static-check', 'fields': {'check': 'analyze-all.txt'},
                                             'lines': ['see .local/analyze-all.txt']}, [])
        self.assertIn('analyze-all.txt', lines[0])
