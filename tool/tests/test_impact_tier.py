"""The `impact` test tier of tool/check-project (tool/impact_tier.py): selection merge, fallbacks, cache tiers."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
import unittest.mock

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import impact_tier  # noqa: E402

LOADER = importlib.machinery.SourceFileLoader('check_project_impact', str(TOOL / 'check-project'))
SPEC = importlib.util.spec_from_loader('check_project_impact', LOADER)
check = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(check)

APP = 'apps/raft_flutter'
UI = 'packages/raft_ui'
PACKAGES = [APP, UI, 'packages/raft_client']


def git(repo, *args):
    return subprocess.run(['git', *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()


def app_files(count, prefix='t'):
    return [f'{APP}/test/{prefix}{i}_test.dart' for i in range(count)]


def selection(tests=(), maps=(APP, UI, 'packages/raft_client'), select_all=None, warnings=()):
    return {'tests': {name: ['changes x'] for name in tests}, 'maps': {m: 'abc' for m in maps}, 'select_all': select_all,
            'warnings': list(warnings), 'notes': []}


class PlanPackagesTests(unittest.TestCase):
    def test_merges_selector_guards_and_changed_tests_once_in_candidate_order(self):
        files = app_files(10)
        sel = selection([files[3], files[1], f'{APP}/test/gone_test.dart'])
        plans = impact_tier.plan_packages(files, PACKAGES, sel, None, guards={files[1], files[7]}, changed_tests={files[0]})
        self.assertEqual(len(plans), 1)
        plan = plans[0]
        self.assertEqual(plan['mode'], 'impact')
        self.assertEqual(plan['files'], [files[0], files[1], files[3], files[7]])  # candidate order, no duplicate, no missing file
        self.assertEqual((plan['selected'], plan['total']), (4, 10))
        self.assertEqual(plan['counts'], {'selector': 2, 'guard': 2, 'changed': 1})
        self.assertIn('selector 2, guards 2, changed tests 1', plan['reason'])

    def test_each_package_is_planned_on_its_own(self):
        app, ui = app_files(4), [f'{UI}/test/u{i}_test.dart' for i in range(4)]
        sel = selection([app[0], *ui[:3]])
        plans = {p['package']: p for p in impact_tier.plan_packages(app + ui, PACKAGES, sel, None, set(), set())}
        self.assertEqual(set(plans), {APP, UI})  # raft_client has no candidates: no line for it
        self.assertEqual((plans[APP]['mode'], plans[APP]['files']), ('impact', [app[0]]))
        self.assertEqual((plans[UI]['mode'], plans[UI]['files']), ('gate', []))

    def test_more_than_half_falls_back_to_the_gate_but_exactly_half_does_not(self):
        files = app_files(10)
        half = impact_tier.plan_packages(files, PACKAGES, selection(files[:5]), None, set(), set())[0]
        self.assertEqual(half['mode'], 'impact')
        over = impact_tier.plan_packages(files, PACKAGES, selection(files[:4]), None, guards={files[9], files[8]}, changed_tests=set())[0]
        self.assertEqual((over['mode'], over['files'], over['selected']), ('gate', [], 6))  # the guards count towards the share
        self.assertIn('more than 50% of 10', over['reason'])

    def test_a_failed_selector_puts_every_package_on_the_gate(self):
        files = app_files(10) + [f'{UI}/test/u_test.dart']
        plans = impact_tier.plan_packages(files, PACKAGES, None, 'tool/test-impact select exited 1: boom', {files[0]}, set())
        self.assertEqual({p['mode'] for p in plans}, {'gate'})
        self.assertTrue(all('selector failed: tool/test-impact select exited 1: boom' in p['reason'] for p in plans))

    def test_a_package_without_a_map_falls_back(self):
        files = app_files(10)
        plan = impact_tier.plan_packages(files, PACKAGES, selection([files[0]], maps=[UI]), None, set(), set())[0]
        self.assertEqual((plan['mode'], plan['reason']), ('gate', 'no impact map for this package'))

    def test_select_all_falls_back_with_the_selectors_reason(self):
        files = app_files(10)
        plan = impact_tier.plan_packages(files, PACKAGES, selection(select_all='no impact map'), None, set(), set())[0]
        self.assertEqual(plan['mode'], 'gate')
        self.assertIn('no impact map', plan['reason'])

    def test_summary_says_selected_n_of_m_and_why(self):
        files = app_files(10)
        plans = impact_tier.plan_packages(files + [f'{UI}/test/u_test.dart'], PACKAGES, selection([files[0]], maps=[APP]), None, set(), set())
        lines = impact_tier.summary_lines(plans, ['stale map raft_ui: built 30h ago'])
        self.assertEqual(lines[0], 'test-impact: stale map raft_ui: built 30h ago')
        self.assertIn(f'impact {APP}: selected 1 of 10 (selector 1, guards 0, changed tests 0)', lines)
        self.assertIn(f'impact {UI}: selected 0 of 1; gate tier for this package (no impact map for this package)', lines)


class GuardFileTests(unittest.TestCase):
    def test_globs_cross_cutting_list_and_zh_catalog_only_for_l10n(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            names = [f'{APP}/test/capability_parity_guard_test.dart', f'{APP}/test/builder_registry_test.dart',
                     f'{APP}/test/close_popups_test.dart', f'{APP}/test/plain_test.dart', f'{APP}/test/sub/nested_guard_test.dart',
                     f'{UI}/test/text_scale_audit_test.dart', f'{UI}/test/text_scale_audit_tall_test.dart', f'{UI}/test/zh_catalog_files_test.dart']
            for name in names:
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text('void main() {}\n')
            base = {f'{APP}/test/capability_parity_guard_test.dart', f'{APP}/test/builder_registry_test.dart', f'{APP}/test/close_popups_test.dart',
                    f'{UI}/test/text_scale_audit_test.dart', f'{UI}/test/text_scale_audit_tall_test.dart'}
            self.assertEqual(impact_tier.guard_files(root, [f'{APP}/lib/a.dart']), base)
            self.assertEqual(impact_tier.guard_files(root, [f'{UI}/lib/src/l10n/zh.dart']), base | {f'{UI}/test/zh_catalog_files_test.dart'})
            self.assertIn(f'{UI}/test/zh_catalog_files_test.dart', impact_tier.guard_files(root, None))

    def test_changed_test_files_are_the_test_dart_paths(self):
        self.assertEqual(impact_tier.changed_test_files([f'{APP}/lib/a.dart', f'{APP}/test/a_test.dart', 'docs/x.md']), {f'{APP}/test/a_test.dart'})
        self.assertEqual(impact_tier.changed_test_files(None), set())


class RunSelectorTests(unittest.TestCase):
    def selector_root(self, body):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        (root / 'tool').mkdir()
        (root / 'tool/test-impact').write_text('import json, sys\n' + body)
        return root

    def test_parses_the_json_and_passes_base_and_worktree(self):
        root = self.selector_root("print(json.dumps({'tests': {'a_test.dart': []}, 'maps': {}, 'argv': sys.argv[1:]}))\n")
        result, error = impact_tier.run_selector(root, 'origin/x', worktree=True)
        self.assertIsNone(error)
        self.assertEqual(result['argv'], ['select', '--root', str(root), '--base', 'origin/x', '--format', 'json', '--worktree'])

    def test_failures_are_reported_not_raised(self):
        cases = {"print('boom', file=sys.stderr); sys.exit(3)\n": 'exited 3: boom', "print('not json')\n": 'printed no JSON',
                 "print(json.dumps({'maps': {}}))\n": 'printed no test list', 'import time; time.sleep(5)\n': 'timed out'}
        for body, expected in cases.items():
            result, error = impact_tier.run_selector(self.selector_root(body), 'origin/x', worktree=False, timeout=1)
            self.assertIsNone(result, body)
            self.assertIn(expected, error, body)


class ApplyImpactTierTests(unittest.TestCase):
    """check-project's file list for RAFT_TEST_TIER=impact, on a small tree."""

    FILES = {f'{APP}/test/a_test.dart': False, f'{APP}/test/b_test.dart': False, f'{APP}/test/c_test.dart': False,
             f'{APP}/test/d_test.dart': False, f'{APP}/test/e_test.dart': False, f'{APP}/test/f_test.dart': False,
             f'{APP}/test/slow_test.dart': True, f'{APP}/test/shell_guard_test.dart': False,
             f'{UI}/test/u1_test.dart': False, f'{UI}/test/u_slow_test.dart': True}

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.top = Path(tmp.name)
        for name, slow in self.FILES.items():
            (self.top / name).parent.mkdir(parents=True, exist_ok=True)
            (self.top / name).write_text(("@Tags(['slow'])\nlibrary;\n" if slow else '') + 'void main() {}\n')
        self.app = self.top / APP
        self.files = [os.path.relpath(self.top / name, self.app) for name in self.FILES]

    def apply(self, select, changed=(f'{APP}/lib/a.dart',)):
        with unittest.mock.patch.object(check, 'root', self.top):
            return check.apply_test_tier(self.files, 'impact', self.app, list(changed), reach=lambda c: set(), select=select)

    def test_impact_packages_run_the_selection_and_fallback_packages_run_the_gate(self):
        sel = selection([f'{APP}/test/a_test.dart', f'{APP}/test/slow_test.dart'], maps=[APP])  # raft_ui has no map
        kept, slow, impact = self.apply(lambda: (sel, None), changed=[f'{APP}/lib/a.dart', f'{APP}/test/b_test.dart'])
        self.assertEqual(kept, ['test/a_test.dart', 'test/b_test.dart', 'test/slow_test.dart', 'test/shell_guard_test.dart',
                                '../../packages/raft_ui/test/u1_test.dart'])
        self.assertEqual(slow['tier'], 'impact')
        self.assertEqual(slow['skipped'], [f'{UI}/test/u_slow_test.dart'])  # the gate fallback still skips unreached slow files
        plans = {p['package']: p for p in impact['packages']}
        self.assertEqual((plans[APP]['mode'], plans[APP]['selected'], plans[APP]['total']), ('impact', 4, 8))  # exactly half
        self.assertEqual(plans[UI]['mode'], 'gate')
        self.assertEqual(impact['skipped'], 5)

    def test_a_selector_failure_runs_the_gate_everywhere(self):
        kept, slow, impact = self.apply(lambda: (None, 'tool/test-impact select exited 1: no such ref'))
        with unittest.mock.patch.object(check, 'root', self.top):
            gate_kept, _ = check.apply_slow_tier(self.files, 'gate', self.app, [f'{APP}/lib/a.dart'], lambda c: set())
        self.assertEqual(kept, gate_kept)
        self.assertTrue(all(p['mode'] == 'gate' and 'no such ref' in p['reason'] for p in impact['packages']))

    def test_an_unknown_diff_does_not_call_the_selector(self):
        select = unittest.mock.Mock()
        with unittest.mock.patch.object(check, 'root', self.top), unittest.mock.patch.object(check, 'changed_since_base', return_value=None):
            kept, slow, impact = check.apply_test_tier(self.files, 'impact', self.app, None, reach=lambda c: set(), select=select)
        select.assert_not_called()
        self.assertEqual(len(kept), len(self.files))  # unknown diff: the gate runs every slow file too
        self.assertIn('could not be computed', impact['error'])

    def test_more_than_half_of_a_package_falls_back(self):
        sel = selection([f'{APP}/test/{n}_test.dart' for n in 'abcd'], maps=[APP, UI])  # 4 + the guard = 5 of 8
        kept, _, impact = self.apply(lambda: (sel, None))
        plans = {p['package']: p for p in impact['packages']}
        self.assertEqual(plans[APP]['mode'], 'gate')
        self.assertIn('test/f_test.dart', kept)
        self.assertEqual((plans[UI]['mode'], plans[UI]['selected']), ('impact', 0))
        self.assertNotIn('../../packages/raft_ui/test/u1_test.dart', kept)

    def test_other_tiers_have_no_impact_plan(self):
        with unittest.mock.patch.object(check, 'root', self.top):
            kept, slow, impact = check.apply_test_tier(self.files, 'gate', self.app, [], reach=lambda c: set(), select=unittest.mock.Mock())
        self.assertIsNone(impact)
        self.assertEqual(slow['tier'], 'gate')

    def test_the_summary_and_the_plan_show_the_selection(self):
        sel = selection([f'{APP}/test/a_test.dart'], maps=[APP], warnings=['stale map raft_flutter: built 30h ago'])
        _, slow, impact = self.apply(lambda: (sel, None))
        text = check.format_summary([], [], {'passed': 0, 'skipped': 0}, [], slow=slow, impact=impact)
        self.assertIn(f'impact {APP}: selected 2 of 8 (selector 1, guards 1, changed tests 0)', text)
        self.assertIn('test-impact: stale map raft_flutter', text)
        with unittest.mock.patch.object(check, 'root', self.top), unittest.mock.patch.object(check, 'app_dir', self.app), \
                unittest.mock.patch.object(check, 'discover_tests', return_value=self.files), \
                unittest.mock.patch.object(check.theme_looks, 'guard', return_value=[]):
            lines, numbers = check.plan_report({'RAFT_TEST_TIER': 'impact'}, changed=[f'{APP}/lib/a.dart'], reach=lambda c: set(), select=lambda: (sel, None))
        self.assertIn('tier impact', lines[0])
        self.assertIn(f'    impact, runs: {APP}/test/a_test.dart', lines)
        self.assertIn(f'    impact, runs: {APP}/test/shell_guard_test.dart', lines)
        self.assertEqual((numbers['toRun'], numbers['impactSkipped'], numbers['slowSkipped']), (3, 6, 1))


class TierModeTests(unittest.TestCase):
    def test_impact_is_a_tier_and_all_themes_still_forces_full(self):
        self.assertEqual(check.tier_mode({'RAFT_TEST_TIER': 'impact'}), 'impact')
        self.assertEqual(check.tier_mode({'RAFT_TEST_TIER': ' Impact '}), 'impact')
        self.assertEqual(check.tier_mode({'RAFT_TEST_TIER': 'impact', 'RAFT_TEST_ALL_THEMES': '1'}), 'full')
        with self.assertRaises(SystemExit):
            check.tier_mode({'RAFT_TEST_TIER': 'quick'})


class ImpactCacheTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.repo = Path(tmp.name) / 'repo'
        self.repo.mkdir()
        self.env = {'RAFT_CHECK_CACHE': str(Path(tmp.name) / 'cache')}
        git(self.repo, 'init', '-q')
        git(self.repo, 'config', 'user.email', 'test@example.invalid')
        git(self.repo, 'config', 'user.name', 'test')
        (self.repo / 'a.txt').write_text('one\n')
        git(self.repo, 'add', '.')
        git(self.repo, 'commit', '-q', '-m', 'one')
        self.tree = git(self.repo, 'rev-parse', 'HEAD^{tree}')

    def record(self, tier):
        return check.record_pass(self.tree, 'abc', {'passed': True}, 'raft', {'tier': tier}, env=self.env, now=time.gmtime(0), tier=tier)

    def test_an_impact_pass_is_recorded_as_impact_and_satisfies_only_impact(self):
        path = self.record('impact')
        self.assertEqual(json.loads(path.read_text())['tier'], 'impact')
        self.assertIsNotNone(check.reusable_pass('raft', self.repo, self.env, tier='impact'))
        self.assertIsNone(check.reusable_pass('raft', self.repo, self.env, tier='gate'))
        self.assertIsNone(check.reusable_pass('raft', self.repo, self.env, tier='full'))

    def test_a_gate_or_full_pass_satisfies_impact(self):
        self.record('gate')
        self.assertIsNotNone(check.reusable_pass('raft', self.repo, self.env, tier='impact'))
        self.assertIsNone(check.reusable_pass('raft', self.repo, self.env, tier='full'))
        self.record('full')
        for tier in check.TIERS:
            self.assertIsNotNone(check.reusable_pass('raft', self.repo, self.env, tier=tier), tier)

    def test_an_impact_pass_never_replaces_a_gate_record(self):
        self.record('gate')
        self.assertIsNone(self.record('impact'))
        self.assertEqual(check.read_pass_record(self.tree, self.env)['tier'], 'gate')
        self.record('full')
        self.assertEqual(check.read_pass_record(self.tree, self.env)['tier'], 'full')

    def test_pass_covers_ranks_the_tiers(self):
        self.assertFalse(check.pass_covers({'themes': 'raft', 'tier': 'impact'}, 'raft', 'gate'))
        self.assertTrue(check.pass_covers({'themes': 'raft', 'tier': 'gate'}, 'raft', 'impact'))
        self.assertTrue(check.pass_covers({'themes': 'raft'}, 'raft', 'impact'))  # an old record without a tier ran every file
        self.assertFalse(check.pass_covers({'themes': 'raft', 'tier': 'weird'}, 'raft', 'impact'))


if __name__ == '__main__':
    unittest.main()
