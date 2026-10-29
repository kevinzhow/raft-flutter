import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
SPEC = importlib.util.spec_from_file_location('test_budget', TOOL / 'test_budget.py')
budget = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(budget)

BASELINE = {'version': 1, 'files': {'apps/raft_flutter/test/big_test.dart': {'cases': 100, 'seconds': 80.0}}}


def entry(cases, seconds, load=1.0):
    return {'tests': cases, 'seconds': seconds + load, 'loadSeconds': load}


class MeasureTests(unittest.TestCase):
    def test_run_seconds_exclude_the_load(self):
        measured = budget.measure({'a_test.dart': entry(7, 12.0, load=3.0), 'empty_test.dart': {'tests': 0, 'seconds': 1.0, 'loadSeconds': 1.0}})
        self.assertEqual(measured, {'a_test.dart': {'cases': 7, 'seconds': 12.0}})


class CheckTests(unittest.TestCase):
    def verdict(self, measured, exempt=False, baseline=BASELINE, exists=True):
        return budget.check(measured, baseline, lambda name: exempt, lambda name: exists)

    def test_a_small_new_file_passes(self):
        self.assertEqual(self.verdict({'new_test.dart': {'cases': 60, 'seconds': 30.0}})['violations'], [])

    def test_a_new_file_over_the_case_limit_fails_unless_exempt(self):
        now = {'cases': 61, 'seconds': 2.0}
        result = self.verdict({'new_test.dart': now})
        self.assertEqual(len(result['violations']), 1)
        self.assertIn('nightly-full', result['violations'][0])
        self.assertEqual(self.verdict({'new_test.dart': now}, exempt=True)['violations'], [])

    def test_seconds_only_warn_because_gate_timings_depend_on_the_other_shards(self):
        result = self.verdict({'new_test.dart': {'cases': 3, 'seconds': 31.0}})
        self.assertEqual((result['violations'], len(result['warnings'])), ([], 1))
        self.assertEqual(self.verdict({'new_test.dart': {'cases': 3, 'seconds': 31.0}}, exempt=True)['warnings'], [])

    def test_a_listed_file_may_not_gain_cases_and_running_much_longer_warns(self):
        name = 'apps/raft_flutter/test/big_test.dart'
        self.assertEqual(self.verdict({name: {'cases': 100, 'seconds': 80.0}})['violations'], [])
        self.assertEqual(self.verdict({name: {'cases': 90, 'seconds': 120.0}})['warnings'], [])  # noise inside 1.5x + 10 s
        self.assertIn('grew from 100 to 101', self.verdict({name: {'cases': 101, 'seconds': 80.0}})['violations'][0])
        slower = self.verdict({name: {'cases': 100, 'seconds': 131.0}})
        self.assertEqual((slower['violations'], len(slower['warnings'])), ([], 1))

    def test_stale_entries_are_notes_never_failures(self):
        name = 'apps/raft_flutter/test/big_test.dart'
        gone = self.verdict({}, exists=False)
        self.assertEqual((gone['violations'], len(gone['notes'])), ([], 1))
        tagged = self.verdict({name: {'cases': 100, 'seconds': 80.0}}, exempt=True)
        self.assertEqual((tagged['violations'], len(tagged['notes'])), ([], 1))
        small = self.verdict({name: {'cases': 10, 'seconds': 5.0}})
        self.assertEqual((small['violations'], len(small['notes'])), ([], 1))


class LoweredTests(unittest.TestCase):
    def test_entries_shrink_or_go_and_none_is_added(self):
        baseline = {'version': 1, 'files': {
            'a_test.dart': {'cases': 100, 'seconds': 80.0}, 'b_test.dart': {'cases': 90, 'seconds': 70.0},
            'c_test.dart': {'cases': 80, 'seconds': 60.0}, 'd_test.dart': {'cases': 70, 'seconds': 50.0}}}
        measured = {'a_test.dart': {'cases': 90, 'seconds': 95.0},  # fewer cases, slower
                    'b_test.dart': {'cases': 10, 'seconds': 3.0},   # under the limits: entry goes
                    'new_test.dart': {'cases': 500, 'seconds': 500.0}}  # never added
        result = budget.lowered(baseline, measured, lambda name: name == 'c_test.dart', lambda name: name != 'd_test.dart')
        self.assertEqual(result['files'], {'a_test.dart': {'cases': 90, 'seconds': 80.0}})


class ExemptionTests(unittest.TestCase):
    def test_slow_tag_in_the_head_or_the_marker_anywhere(self):
        with tempfile.TemporaryDirectory() as tmp:
            def write(name, text):
                path = Path(tmp) / name
                path.write_text(text)
                return path
            self.assertTrue(budget.is_exempt(write('a.dart', "@Tags(['slow'])\nlibrary;\nimport 'x';\n")))
            self.assertTrue(budget.is_exempt(write('b.dart', "import 'x';\nvoid main() {\n  // matrix: nightly-full -- the gate runs the L\n}\n")))
            self.assertTrue(budget.is_exempt(write('s.dart', "// budget: per-surface (one case per registered surface)\nimport 'x';\n")))
            self.assertFalse(budget.is_exempt(write('c.dart', "import 'x';\n// we discuss matrix: nightly-full here\n")))
            self.assertFalse(budget.is_exempt(write('d.dart', "@Tags(['golden'])\nlibrary;\n")))
            self.assertFalse(budget.is_exempt(Path(tmp) / 'missing.dart'))


class BootstrapTests(unittest.TestCase):
    def test_only_over_limit_non_exempt_files_are_listed_and_a_second_bootstrap_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            cases = Path(tmp) / 'cases.json'
            cases.write_text(json.dumps({'big_test.dart': {'cases': 99, 'seconds': 10.0}, 'small_test.dart': {'cases': 5, 'seconds': 2.0}}))
            target = Path(tmp) / 'baseline.json'
            self.assertEqual(budget.main(['--bootstrap', str(cases), '--baseline', str(target)]), 0)
            self.assertEqual(list(json.loads(target.read_text())['files']), ['big_test.dart'])
            with self.assertRaises(SystemExit):
                budget.main(['--bootstrap', str(cases), '--baseline', str(target)])


def events(*items):
    return [json.dumps(item) for item in items]


def suite_events(path, cases, hidden=0, loading=True):
    """The JSON-reporter stream of one suite: a load entry, `cases` tests and `hidden` bookkeeping entries."""
    out = [{'type': 'suite', 'suite': {'id': 1, 'path': path}}]
    if loading:
        out += [{'type': 'testStart', 'test': {'id': 100, 'name': f'loading {path}', 'suiteID': 1}, 'time': 0},
                {'type': 'testDone', 'testID': 100, 'result': 'success', 'time': 500}]
    for i in range(cases + hidden):
        out += [{'type': 'testStart', 'test': {'id': i, 'name': f'case {i}', 'suiteID': 1}, 'time': 1000 + i},
                {'type': 'testDone', 'testID': i, 'result': 'success', 'hidden': i >= cases, 'time': 1500 + i}]
    return out


class MeasureEventsTests(unittest.TestCase):
    def test_counts_the_cases_a_file_declares_like_the_full_check(self):
        lines = events(*suite_events('/repo/a_test.dart', 7, hidden=2))
        self.assertEqual(budget.measure_events(lines, lambda p: p.replace('/repo/', ''))['a_test.dart']['cases'], 7)  # load and (setUpAll) entries are not cases

    def test_a_skipped_case_still_counts_and_a_file_without_cases_is_left_out(self):
        items = suite_events('/repo/a_test.dart', 2)
        items[-1] = dict(items[-1], skipped=True)
        self.assertEqual(budget.measure_events(events(*items))['/repo/a_test.dart']['cases'], 2)
        self.assertEqual(budget.measure_events(events(*suite_events('/repo/empty_test.dart', 0))), {})

    def test_it_agrees_with_what_check_project_stores_for_the_same_stream(self):
        import test_events
        lines = events(*suite_events('/repo/a_test.dart', 5), *suite_events('/repo/b_test.dart', 3)[:0])
        durations = test_events.file_durations(test_events.parse_test_events(lines))
        self.assertEqual(budget.measure(durations), budget.measure_events(lines))

    def test_a_truncated_stream_is_tolerated(self):
        lines = events(*suite_events('/repo/a_test.dart', 3)) + ['{"type": "tes']
        self.assertEqual(budget.measure_events(lines)['/repo/a_test.dart']['cases'], 3)


class BudgetFilesTests(unittest.TestCase):
    DIRS = ['apps/raft_flutter/test', 'packages/raft_ui/test']
    T = 'apps/raft_flutter/test/'

    def part(self, target):
        return f"import '{target}' show registerThings;\nimport 'support/test_parts.dart';\nvoid main() => registerThings(TestPart(1, 3));\n"

    def files(self, changed, sources, dirs=None):
        return budget.budget_files(changed, sources, {'raft_ui': 'packages/raft_ui'}, dirs or self.DIRS)

    def test_a_changed_test_file_counts_and_other_changed_files_do_not(self):
        found = self.files([self.T + 'a_test.dart', self.T + 'support/helper.dart', 'apps/raft_flutter/lib/x.dart', 'tool/x_test.dart'], {})
        self.assertEqual(found, [self.T + 'a_test.dart'])

    def test_every_part_of_a_changed_registering_file_counts(self):
        sources = {self.T + 'viewer_test.dart': 'void registerThings(TestPart p) {}\nvoid main() => registerThings(TestPart(0, 3));\n',
                   self.T + 'viewer_part2_test.dart': self.part('viewer_test.dart'),
                   self.T + 'viewer_part3_test.dart': self.part('viewer_test.dart'),
                   self.T + 'other_part2_test.dart': self.part('other_test.dart')}
        self.assertEqual(self.files([self.T + 'viewer_test.dart'], sources),
                         [self.T + 'viewer_part2_test.dart', self.T + 'viewer_part3_test.dart', self.T + 'viewer_test.dart'])

    def test_a_changed_shared_registration_helper_pulls_in_its_parts_too(self):
        sources = {self.T + 'support/cases.dart': 'void registerThings(TestPart p) {}\n', self.T + 'a_part2_test.dart': self.part('support/cases.dart')}
        self.assertEqual(self.files([self.T + 'support/cases.dart'], sources), [self.T + 'a_part2_test.dart'])

    def test_a_test_that_merely_imports_a_changed_file_is_not_a_part(self):
        sources = {self.T + 'b_test.dart': "import 'support/helper.dart';\nvoid main() {}\n"}
        self.assertEqual(self.files([self.T + 'support/helper.dart'], sources), [])

    def test_package_imports_and_test_dirs_are_followed(self):
        sources = {'packages/raft_ui/test/x_part2_test.dart': "import 'package:raft_ui/test_cases.dart';\nvoid main() => run(TestPart(1, 2));\n",
                   'tool/y_part2_test.dart': "import 'package:raft_ui/test_cases.dart';\nvoid main() => run(TestPart(1, 2));\n"}
        self.assertEqual(self.files(['packages/raft_ui/lib/test_cases.dart'], sources), ['packages/raft_ui/test/x_part2_test.dart'])


class CheckMeasuredTests(unittest.TestCase):
    BASE = {'version': 1, 'files': {'a_test.dart': {'cases': 100, 'seconds': 5.0}, 'untouched_test.dart': {'cases': 80, 'seconds': 5.0}}}

    def test_a_listed_file_that_grew_fails_and_unmeasured_entries_stay_quiet(self):
        result = budget.check_measured({'a_test.dart': {'cases': 108, 'seconds': 1.0}}, self.BASE, lambda name: False)
        self.assertEqual(len(result['violations']), 1)
        self.assertIn('a_test.dart: grew from 100 to 108 cases', result['violations'][0])
        self.assertEqual(result['notes'], [])  # untouched_test.dart is neither measured nor reported as gone

    def test_an_unlisted_file_over_the_limit_fails_unless_marked_per_surface(self):
        over = {'new_test.dart': {'cases': 61, 'seconds': 1.0}}
        self.assertEqual(len(budget.check_measured(over, self.BASE)['violations']), 1)
        self.assertEqual(budget.check_measured(over, self.BASE, lambda name: True)['violations'], [])

    def test_the_report_has_the_full_check_wording(self):
        result = budget.check_measured({'a_test.dart': {'cases': 108, 'seconds': 1.0}}, self.BASE)
        self.assertEqual(budget.report_lines(result, 1), [
            'test-budget: FAIL a_test.dart: grew from 100 to 108 cases; a file listed in tool/test-budget-baseline.json may only shrink.',
            'test-budget: 1 files measured, 1 over budget, 0 slow warnings.'])


if __name__ == '__main__':
    unittest.main()
