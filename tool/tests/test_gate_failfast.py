import datetime
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import stat
import sys
import tempfile
import threading
import unittest
from unittest import mock

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import gate_events  # noqa: E402

LOADER = importlib.machinery.SourceFileLoader('check_project_failfast', str(TOOL / 'check-project'))
SPEC = importlib.util.spec_from_loader('check_project_failfast', LOADER)
check = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(check)

NOW = datetime.datetime(2026, 10, 12, 8, 30, 5, tzinfo=datetime.timezone.utc)

COMPILE_ERROR = """00:00 +0: loading /repo/apps/raft_flutter/test/a_test.dart
00:00 +0: loading /repo/apps/raft_flutter/test/b_test.dart
lib/platform/macos_dock_unread.dart:24:7: Error: Undefined name 'AppBadgePlus'.
      AppBadgePlus.updateBadge(count);
      ^^^^^^^^^^^^
test/b_test.dart:3:1: Error: 'Foo' isn't a type.
00:00 +0 -1: loading /repo/apps/raft_flutter/test/b_test.dart [E]
  Failed to load "/repo/apps/raft_flutter/test/b_test.dart":
  Compilation failed for testPath=/repo/apps/raft_flutter/test/b_test.dart: lib/platform/macos_dock_unread.dart:24:7: Error: Undefined name 'AppBadgePlus'.
"""
FAILED_TEST = "00:05 +3 ~1 -1: /repo/apps/raft_flutter/test/a_test.dart: group renders the badge [E]\n  Expected: <1>\n"


class EventLogTests(unittest.TestCase):
    def test_line_format(self):
        line = gate_events.format_event('FAIL-FIRST', 'cindy/x', 'abc1234', '/wt/x', now=NOW, file='test/a_test.dart', test='renders the badge')
        self.assertEqual(line, '2026-10-12T08:30:05Z FAIL-FIRST branch=cindy/x sha=abc1234 wt=/wt/x file=test/a_test.dart test="renders the badge"\n')

    def test_values_stay_on_one_bounded_line(self):
        line = gate_events.format_event('ERROR', 'b', 's', '/w', now=NOW, reason='boom\nsecond line ' + 'x' * 500)
        self.assertEqual(line.count('\n'), 1)
        self.assertLess(len(line), 500)

    def test_append_creates_the_file_and_concurrent_writers_do_not_interleave(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'events.log'
            lines = [gate_events.format_event('START', f'b{i}', 'abc', '/w', now=NOW, note='y' * 200) for i in range(40)]
            threads = [threading.Thread(target=gate_events.append_line, args=(line, path)) for line in lines]
            [t.start() for t in threads]
            [t.join() for t in threads]
            self.assertEqual(sorted(path.read_text().splitlines(keepends=True)), sorted(lines))

    def test_unwritable_log_never_raises(self):
        gate_events.append_line('x\n', '/nonexistent-dir/events.log')


class NotifyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.log = self.dir / 'events.log'
        self.fake_bin = self.dir / 'bin'
        self.fake_bin.mkdir()

    def fake_raft(self, exit_code=0):
        script = self.fake_bin / 'raft'
        script.write_text(f'#!/bin/sh\nprintf "%s\\n" "$@" > "{self.dir}/args"\ncat > "{self.dir}/stdin"\nexit {exit_code}\n')
        script.chmod(script.stat().st_mode | stat.S_IEXEC)

    def events(self, target='dm:@kevinzhow:abc', path=None):
        env = {'RAFT_GATE_EVENTS_LOG': str(self.log), 'PATH': path or f'{self.fake_bin}:/usr/bin:/bin'}
        if target:
            env['RAFT_GATE_NOTIFY_TARGET'] = target
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        if not target:  # a gate run exports its own target to these tests
            os.environ.pop('RAFT_GATE_NOTIFY_TARGET', None)
        return gate_events.Events(self.dir)

    def test_failure_is_sent_through_stdin_not_argv(self):
        self.fake_raft()
        emit = self.events()
        emit('FAIL', notify=emit.message('2 个测试失败', 'a_test.dart: x', '/wt/.local/check-summary.txt'), duration='3s')
        gate_events.flush_notifications()
        self.assertEqual((self.dir / 'args').read_text().split(), ['message', 'send', '--target', 'dm:@kevinzhow:abc'])
        body = (self.dir / 'stdin').read_text()
        self.assertTrue(body.startswith('全量检查失败：'))
        self.assertIn('原因：2 个测试失败', body)
        self.assertNotIn('NOTIFY-FAILED', self.log.read_text())

    def test_only_failure_events_notify(self):
        self.fake_raft()
        emit = self.events()
        for event in ('START', 'PASS', 'WAITING'):
            emit(event, notify='should not be sent')
        gate_events.flush_notifications()
        self.assertFalse((self.dir / 'stdin').exists())

    def test_no_target_sends_nothing(self):
        self.fake_raft()
        emit = self.events(target=None)
        emit('FAIL', notify='x')
        gate_events.flush_notifications()
        self.assertFalse((self.dir / 'stdin').exists())

    def test_failed_send_is_logged_and_harmless(self):
        self.fake_raft(exit_code=3)
        emit = self.events()
        emit('ERROR', notify='x', reason='boom')
        gate_events.flush_notifications()
        self.assertIn('NOTIFY-FAILED branch=', self.log.read_text())
        self.assertIn('error="exit 3"', self.log.read_text())

    def test_missing_raft_is_logged_and_harmless(self):
        empty = self.dir / 'empty'
        empty.mkdir()
        emit = self.events(path=str(empty))
        emit('ABORT', notify='x', reason='stall')
        gate_events.flush_notifications()
        self.assertIn('NOTIFY-FAILED', self.log.read_text())
        self.assertIn('ABORT', self.log.read_text())


class ScannerTests(unittest.TestCase):
    def scan(self, text, files=()):
        scanner = check.StreamScanner(files)
        return scanner, scanner.feed(text)

    def test_compile_error_block_is_one_finding_with_the_test_file(self):
        scanner, found = self.scan(COMPILE_ERROR)
        self.assertEqual([f['kind'] for f in found], ['compile'])
        compile_error = scanner.compile
        self.assertEqual(compile_error['file'], '/repo/apps/raft_flutter/test/b_test.dart')
        self.assertTrue(compile_error['done'])
        self.assertEqual(compile_error['lines'][0], "lib/platform/macos_dock_unread.dart:24:7: Error: Undefined name 'AppBadgePlus'.")
        self.assertIn("test/b_test.dart:3:1: Error: 'Foo' isn't a type.", compile_error['lines'])

    def test_first_diagnostic_is_reported_before_the_rest_arrives(self):
        scanner, found = self.scan("00:00 +0: loading /r/a_test.dart\nlib/a.dart:24:7: Error: Undefined name 'X'.\n")
        self.assertEqual(found[0]['file'], 'lib/a.dart')
        self.assertFalse(found[0]['done'])
        scanner.feed('00:00 +0 -1: loading /r/a_test.dart [E]\n')
        self.assertEqual((found[0]['file'], found[0]['done']), ('/r/a_test.dart', True))

    def test_neighbour_files_failing_afterwards_do_not_replace_the_culprit(self):
        text = ("00:00 +0: loading /r/a_test.dart\nlib/a.dart:1:1: Error: Undefined name 'X'.\n"
                '00:00 +0 -1: loading /r/a_test.dart [E]\n  Failed to load "/r/a_test.dart":\n'
                '00:00 +0 -2: loading /r/b_test.dart [E]\n  Error: The Dart compiler exited unexpectedly.\n')
        scanner, _ = self.scan(text)
        self.assertEqual(scanner.compile['file'], '/r/a_test.dart')

    def test_load_failure_without_compiler_output(self):
        scanner, found = self.scan('00:00 +0 -1: loading /r/missing_test.dart [E]\n  Failed to load "/r/missing_test.dart": Does not exist.\n')
        self.assertEqual(found[0]['kind'], 'compile')
        self.assertEqual(scanner.compile['file'], '/r/missing_test.dart')
        self.assertIn('Does not exist.', scanner.compile['lines'][0])

    def test_failed_test_with_file_prefix(self):
        _, found = self.scan(FAILED_TEST)
        self.assertEqual(found, [{'kind': 'test', 'file': '/repo/apps/raft_flutter/test/a_test.dart', 'name': 'group renders the badge'}])

    def test_failed_test_without_prefix_uses_the_only_file(self):
        text = '00:00 +0 -1: sending from older history clears the draft [E]\n  Test failed. See exception logs above.\n'
        self.assertEqual(self.scan(text, ['test/a_test.dart'])[1][0]['file'], 'test/a_test.dart')
        self.assertEqual(self.scan(text, ['a', 'b'])[1][0]['file'], '?')

    def test_passing_progress_and_error_words_in_test_names_are_not_failures(self):
        text = '00:01 +5 -1: /r/a_test.dart: shows Error: text for a failure banner\r00:02 +6 -1: /r/a_test.dart: next\n00:03 +7: All tests passed!\n'
        self.assertEqual(self.scan(text)[1], [])

    def test_carriage_return_progress_and_chunk_boundaries(self):
        scanner = check.StreamScanner()
        found = []
        data = '00:00 +1: /r/a_test.dart: ok\r00:01 +1 -1: /r/a_test.dart: bad one [E]\r00:02 +2 -1: /r/a_test.dart: next\n'
        for i in range(0, len(data), 7):
            found += scanner.feed(data[i:i + 7])
        self.assertEqual([f['name'] for f in found], ['bad one'])

    def test_ansi_colour_is_ignored(self):
        _, found = self.scan('\x1b[31m00:05 +3 -1: /r/a_test.dart: red one [E]\x1b[0m\n')
        self.assertEqual(found[0]['name'], 'red one')


class DecisionTests(unittest.TestCase):
    def test_max_failures_threshold(self):
        self.assertFalse(check.max_failures_reached(2, 3))
        self.assertTrue(check.max_failures_reached(3, 3))
        self.assertTrue(check.max_failures_reached(9, 3))

    def test_zero_never_stops_early(self):
        self.assertFalse(check.max_failures_reached(1000, 0))

    def test_stall_is_pure_on_timestamps(self):
        self.assertFalse(check.stalled(now=599, last_output=0, minutes=10))
        self.assertTrue(check.stalled(now=600, last_output=0, minutes=10))
        self.assertFalse(check.stalled(now=10**6, last_output=0, minutes=0))
        self.assertFalse(check.stalled(now=1000, last_output=700, minutes=10))

    def test_env_numbers(self):
        self.assertEqual(check.env_number('X', 3, {}), 3)
        self.assertEqual(check.env_number('X', 3, {'X': '0'}), 0)
        self.assertEqual(check.env_number('X', 10, {'X': '2.5'}), 2.5)
        with self.assertRaises(SystemExit):
            check.env_number('X', 3, {'X': 'many'})
        with self.assertRaises(SystemExit):
            check.env_number('X', 3, {'X': '-1'})

    def watch(self, max_failures=3, stall=10, shards=2):
        sent = []
        return check.GateWatch([['a'] * 2] * shards, 0, max_failures, stall, lambda event, **details: sent.append((event, details))), sent

    def test_three_failures_across_shards_stop_the_run(self):
        watch, sent = self.watch()
        watch.feed(0, '00:01 +1 -1: /r/a_test.dart: one [E]\n00:02 +1 -2: /r/a_test.dart: two [E]\n', 1)
        self.assertIsNone(watch.verdict(1))
        watch.feed(1, '00:01 +1 -1: /r/b_test.dart: three [E]\n', 2)
        verdict = watch.verdict(2)
        self.assertEqual((verdict['reason'], verdict['fields']), ('max-failures', {'failures': 3, 'limit': 3}))

    def test_fail_first_is_announced_once_at_first_sight(self):
        watch, sent = self.watch()
        watch.feed(0, '00:01 +1 -1: /r/a_test.dart: one [E]\n00:02 +1 -2: /r/a_test.dart: two [E]\n', 1)
        self.assertEqual(sent, [('FAIL-FIRST', {'file': '/r/a_test.dart', 'test': 'one'})])

    def test_limit_zero_keeps_running(self):
        watch, _ = self.watch(max_failures=0)
        watch.feed(0, ''.join(f'00:01 +1 -{i}: /r/a_test.dart: t{i} [E]\n' for i in range(1, 20)), 1)
        self.assertIsNone(watch.verdict(1))

    def test_compile_error_stops_when_named_or_after_the_grace_period(self):
        watch, sent = self.watch()
        watch.feed(0, "lib/a.dart:24:7: Error: Undefined name 'X'.\n", 5)
        self.assertEqual(sent[0][0], 'FAIL-FIRST')
        self.assertIsNone(watch.verdict(5.5))
        grace = watch.verdict(5 + check.COMPILE_GRACE_SECONDS)
        self.assertEqual((grace['reason'], grace['fields']['file']), ('compile-error', 'lib/a.dart'))
        watch, _ = self.watch()
        watch.feed(0, "lib/a.dart:24:7: Error: Undefined name 'X'.\n00:00 +0 -1: loading /r/a_test.dart [E]\n", 5)
        verdict = watch.verdict(5.1)
        self.assertEqual(verdict['fields']['file'], '/r/a_test.dart')
        self.assertEqual(verdict['lines'], ["lib/a.dart:24:7: Error: Undefined name 'X'."])

    def test_stall_verdict_and_output_resets_it(self):
        watch, _ = self.watch(stall=10)
        self.assertIsNone(watch.verdict(599))
        watch.feed(0, '00:01 +1: /r/a_test.dart: fine\n', 599)
        self.assertIsNone(watch.verdict(1000))
        self.assertEqual(watch.verdict(599 + 600)['reason'], 'stall')

    def test_log_tail_returns_only_new_text(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'log'
            tail = check.LogTail(path)
            self.assertEqual(tail.read(), '')
            path.write_bytes('héllo'.encode()[:2])  # split inside a multi-byte character
            first = tail.read()
            with path.open('ab') as f:
                f.write('héllo'.encode()[2:] + b' world')
            self.assertEqual(first + tail.read(), 'héllo world')


class SummaryTests(unittest.TestCase):
    def test_summary_says_why_the_run_stopped(self):
        shard = {'index': 0, 'passed': False, 'stopped': True, 'seconds': 12, 'files': ['a'], 'log': 'test-shard-0.txt'}
        stop = {'message': 'load/compile error in test/b_test.dart', 'lines': ["lib/a.dart:24:7: Error: Undefined name 'X'."]}
        text = check.format_summary([shard], [], {'passed': 0, 'skipped': 0}, [], stop=stop)
        self.assertIn('Run stopped early: load/compile error in test/b_test.dart\n  lib/a.dart:24:7: Error: Undefined name', text)
        self.assertIn('shard 0: STOPPED', text)


if __name__ == '__main__':
    unittest.main()


@unittest.skipIf(os.name == 'nt', 'flock holder note is POSIX only')
class PrepareHandoffLockTests(unittest.TestCase):
    def test_waiting_names_the_holder_and_the_lock_note_is_cleared(self):
        import fcntl
        loader = importlib.machinery.SourceFileLoader('prepare_handoff_lock', str(TOOL / 'prepare-handoff'))
        module = importlib.util.module_from_spec(importlib.util.spec_from_loader('prepare_handoff_lock', loader))
        loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            module.gate_lock = Path(tmp) / 'gate.lock'
            sent = []
            emit = lambda event, **details: sent.append((event, details))
            emit.branch = 'cindy/mine'
            seen = {}

            def stub(command, state):
                seen['note'] = module.gate_lock.read_text()
                return 'ran'
            module.run_check = stub
            holder = module.gate_lock.open('a+b')  # another gate holds the lock
            fcntl.flock(holder, fcntl.LOCK_EX)
            holder.write(f'branch=cindy/other pid={os.getpid()} started=2026-10-12T00:00:00Z\n'.encode())
            holder.flush()
            threading.Timer(0.5, lambda: fcntl.flock(holder, fcntl.LOCK_UN)).start()
            self.assertEqual(module.run_gate(emit, {'child': False}), 'ran')
            holder.close()
            self.assertEqual(sent[0][0], 'WAITING')
            self.assertIn('branch=cindy/other', sent[0][1]['holder'])
            self.assertIn('branch=cindy/mine', seen['note'])
            self.assertEqual(module.gate_lock.read_text(), '')
