"""Design-system drift ratchet (tool/ds-audit) and scanner semantics."""
import contextlib
import importlib.machinery
import importlib.util
import io
import pathlib
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[2]
_loader = importlib.machinery.SourceFileLoader('ds_audit_cli', str(ROOT / 'tool/ds-audit'))
_spec = importlib.util.spec_from_loader('ds_audit_cli', _loader)
ds_audit = importlib.util.module_from_spec(_spec)
_loader.exec_module(ds_audit)

FIXTURE = 'apps/raft_flutter/test/fixtures/ds_audit_sample.dart'
CONTRACT_FIXTURES = 'packages/raft_ui/test/fixtures/ds_audit_contract'


class CompareTest(unittest.TestCase):
    def test_engine_directories_and_exact_helper_files_keep_their_audit_scope(self):
        for scope in ds_audit.ENGINE_SCOPES:
            name = scope if scope.endswith('.dart') else scope + '/sample.g.dart'
            self.assertEqual(ds_audit.scope_of(name), scope)
        self.assertNotIn('packages/raft_theme/lib/src/raft_pack.g.dart', ds_audit.SCOPES)

    def test_growth_new_category_and_new_file_are_regressions(self):
        baseline = {'a.dart': {'widget.list_tile': 2}, 'b.dart': {'style.sized_box': 1}}
        current = {'a.dart': {'widget.list_tile': 3, 'style.edge_insets': 1},
                   'b.dart': {'style.sized_box': 1}, 'c.dart': {'widget.dialog': 1}}
        regressions, improvements = ds_audit.compare(baseline, current)
        self.assertEqual(regressions, [('a.dart', 'style.edge_insets', 0, 1),
                                       ('a.dart', 'widget.list_tile', 2, 3),
                                       ('c.dart', 'widget.dialog', 0, 1)])
        self.assertEqual(improvements, [])

    def test_decreases_are_improvements_with_update_hint(self):
        baseline = {'a.dart': {'widget.list_tile': 2}, 'gone.dart': {'widget.dialog': 4}}
        regressions, improvements = ds_audit.compare(baseline, {'a.dart': {'widget.list_tile': 1}})
        self.assertEqual(regressions, [])
        self.assertEqual(improvements, [('a.dart', 'widget.list_tile', 2, 1),
                                        ('gone.dart', 'widget.dialog', 4, 0)])
        message = ds_audit.format_comparison(regressions, improvements)
        self.assertIn('baseline can lower', message)
        self.assertIn('tool/ds-audit --update-baseline', message)
        self.assertIn('do NOT edit', message)  # feature branches leave the baseline to the integration owner

    def test_check_passes_when_counts_went_down_and_fails_when_they_grew(self):
        baseline = {'files': {'a.dart': {'widget.list_tile': 2}, 'b.dart': {'widget.dialog': 1}}}
        report = lambda files, **extra: {'scannedFiles': 1, 'scopes': ds_audit.SCOPES, 'totals': {}, 'allowedTotals': {},
                                         'allowed': {}, 'files': files, 'malformedAllows': [], 'generated': {},
                                         'generatedTotal': 0, **extra}
        tmp = pathlib.Path(tempfile.mkdtemp())
        for files, expected in (({'a.dart': {'widget.list_tile': 1}}, 0),  # decreases only
                                ({'a.dart': {'widget.list_tile': 2}, 'b.dart': {'widget.dialog': 1}}, 0),
                                ({'a.dart': {'widget.list_tile': 3}}, 1)):
            with mock.patch.object(ds_audit, 'run_scanner', return_value={}), \
                    mock.patch.object(ds_audit, 'aggregate', return_value=report(files)), \
                    mock.patch.object(ds_audit, 'load_baseline', return_value=baseline), \
                    mock.patch.object(ds_audit, 'ROOT', tmp), \
                    mock.patch.object(ds_audit, 'REPORT', tmp / '.local/ds-audit.json'), \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(ds_audit.main(['--check']), expected, files)

    def test_moving_a_violation_between_categories_still_fails(self):
        regressions, _ = ds_audit.compare({'a.dart': {'widget.button': 1}},
                                          {'a.dart': {'widget.icon_button': 1}})
        self.assertEqual(regressions, [('a.dart', 'widget.icon_button', 0, 1)])

    def test_allowlisted_findings_are_counted_separately(self):
        finding = lambda allowed, **extra: dict(file='a.dart', line=1, column=1, category='widget.tooltip',
                                               name='Tooltip', allowed=allowed, **extra)
        report = ds_audit.aggregate({'scanned': ['a.dart'], 'findings': [
            finding(False), finding(True, allowReason='platform'), finding(False, allowError='needs a reason')]})
        self.assertEqual(report['files'], {'a.dart': {'widget.tooltip': 2}})
        self.assertEqual(report['allowed'], {'a.dart': {'widget.tooltip': 1}})
        self.assertEqual(len(report['malformedAllows']), 1)


class ScannerFixtureTest(unittest.TestCase):
    """Exact counts for the resolved-AST scanner on a fixture with negatives."""

    def test_fixture_counts(self):
        report = ds_audit.aggregate(ds_audit.run_scanner([FIXTURE]))
        self.assertEqual(report['totals'], {
            'style.border_radius': 2, 'style.color_literal': 1, 'style.dimension': 1,
            'style.duration': 1, 'style.edge_insets': 2, 'style.font_size': 2,
            'style.font_weight': 2, 'style.material_colors': 1, 'style.material_icons': 1,
            'style.material_theme': 2, 'style.sized_box': 2, 'style.text_metrics': 1,
            'style.text_style': 1, 'widget.button': 4, 'widget.dialog': 2, 'widget.divider': 1,
            'widget.list_tile': 2, 'widget.other': 1, 'widget.progress': 1,
            'widget.snackbar': 2, 'widget.tooltip': 1,
        })
        self.assertEqual(report['allowedTotals'], {'widget.list_tile': 2})
        self.assertEqual(len(report['malformedAllows']), 1)


class ContractRatchetTest(unittest.TestCase):
    """The packages/raft_ui/lib scope: growth fails --check, decreases never do."""

    BASELINE = {'files': {
        'packages/raft_ui/lib/src/a.dart': {'contract.color_literal': 3, 'contract.radius_literal': 2},
        'packages/raft_ui/lib/src/b.dart': {'contract.legacy_recipe_theme': 1},
    }}

    def check(self, files, baseline=None, **extra):
        report = {'scannedFiles': 1, 'scopes': ds_audit.SCOPES, 'totals': {}, 'allowedTotals': {}, 'allowed': {},
                  'files': files, 'malformedAllows': [], 'generated': {}, 'generatedTotal': 0, **extra}
        tmp = pathlib.Path(tempfile.mkdtemp())
        out = io.StringIO()
        with mock.patch.object(ds_audit, 'run_scanner', return_value={}), \
                mock.patch.object(ds_audit, 'aggregate', return_value=report), \
                mock.patch.object(ds_audit, 'load_baseline', return_value=baseline or self.BASELINE), \
                mock.patch.object(ds_audit, 'ROOT', tmp), \
                mock.patch.object(ds_audit, 'REPORT', tmp / '.local/ds-audit.json'), \
                contextlib.redirect_stdout(out):
            return ds_audit.main(['--check']), out.getvalue()

    def test_every_category_growing_in_raft_ui_fails(self):
        a = 'packages/raft_ui/lib/src/a.dart'
        for category in ('contract.color_literal', 'contract.font_size_literal', 'contract.radius_literal',
                         'contract.stroke_width_literal', 'contract.theme_name_branch',
                         'contract.legacy_recipe_theme'):
            files = {a: {'contract.color_literal': 3, 'contract.radius_literal': 2},
                     'packages/raft_ui/lib/src/b.dart': {'contract.legacy_recipe_theme': 1}}
            files[a][category] = files[a].get(category, 0) + 1
            code, output = self.check(files)
            self.assertEqual(code, 1, category)
            self.assertIn(f'{a}: {category}', output)

    def test_a_new_raft_ui_file_with_literals_fails(self):
        code, output = self.check({**self.BASELINE['files'],
                                   'packages/raft_ui/lib/src/new.dart': {'contract.color_literal': 1}})
        self.assertEqual(code, 1)
        self.assertIn('new.dart: contract.color_literal 0 -> 1', output)

    def test_raft_ui_counts_at_or_below_the_baseline_pass(self):
        for files in (self.BASELINE['files'],
                      {'packages/raft_ui/lib/src/a.dart': {'contract.color_literal': 1}},  # decrease + file gone
                      {}):
            code, output = self.check(files)
            self.assertEqual(code, 0, files)
            self.assertNotIn('GREW', output)

    def test_decrease_prints_the_lower_baseline_note(self):
        code, output = self.check({'packages/raft_ui/lib/src/a.dart': {'contract.color_literal': 1}})
        self.assertEqual(code, 0)
        self.assertIn('baseline can lower', output)

    def test_generated_recipe_constants_are_informational(self):
        generated = {'packages/raft_ui/lib/src/recipes/x.g.dart': 99999}
        code, output = self.check(dict(self.BASELINE['files']), generated=generated, generatedTotal=99999)
        self.assertEqual(code, 0)
        self.assertIn('generated.recipe_constants (informational, not checked): 99999', output)

    def test_the_app_scope_still_fails_next_to_a_clean_raft_ui(self):
        files = {**self.BASELINE['files'], 'apps/raft_flutter/lib/features/x.dart': {'widget.dialog': 1}}
        self.assertEqual(self.check(files)[0], 1)

    def test_aggregate_keeps_generated_out_of_the_enforced_counts(self):
        report = ds_audit.aggregate({'scanned': ['a.dart'], 'findings': [],
                                     'generated': {'b.g.dart': 3, 'a.g.dart': 2}})
        self.assertEqual((report['files'], report['totals']), ({}, {}))
        self.assertEqual(report['generated'], {'a.g.dart': 2, 'b.g.dart': 3})
        self.assertEqual(report['generatedTotal'], 5)

    def test_baseline_document_lists_both_scopes_and_the_generated_counts(self):
        report = ds_audit.aggregate({'scanned': ['a.dart'], 'findings': [], 'generated': {'b.g.dart': 3}})
        document = ds_audit.baseline_document(report)
        self.assertEqual(document['scopes'], [
            'apps/raft_flutter/lib', 'packages/raft_ui/lib',
            'packages/raft_theme/lib/recipes',
            'packages/raft_theme/lib/src/css_recipe_decoration.dart',
            'packages/raft_theme/lib/src/outer_shadow_painter.dart',
            'packages/raft_theme/lib/src/lru_cache.dart',
        ])
        self.assertEqual(document['generated'], {'b.g.dart': 3})


class ContractScannerFixtureTest(unittest.TestCase):
    """Exact counts for the theme-contract rules on a fixture with negatives."""

    @classmethod
    def setUpClass(cls):
        cls.report = ds_audit.aggregate(ds_audit.run_scanner([CONTRACT_FIXTURES], contract=[CONTRACT_FIXTURES]))

    def test_fixture_counts_per_category(self):
        self.assertEqual(self.report['totals'], {
            'contract.color_literal': 5,
            'contract.font_size_literal': 2,
            'contract.legacy_recipe_theme': 2,
            'contract.radius_literal': 3,
            'contract.stroke_width_literal': 5,
            'contract.theme_name_branch': 12,
        })

    def test_ds_allow_is_counted_separately_and_a_malformed_one_still_counts(self):
        self.assertEqual(self.report['allowedTotals'],
                         {'contract.color_literal': 2, 'contract.legacy_recipe_theme': 1})
        self.assertEqual(len(self.report['malformedAllows']), 1)

    def test_generated_files_are_excluded_from_literals_and_their_constants_counted(self):
        generated = f'{CONTRACT_FIXTURES}/recipes/sample_recipe.g.dart'
        self.assertEqual(self.report['generated'], {generated: 5})
        self.assertEqual(self.report['generatedTotal'], 5)
        self.assertNotIn(generated, self.report['files'])
        self.assertFalse([f for f in self.report['findings'] if f['file'] == generated])

    def test_the_app_rules_do_not_apply_to_the_contract_scope(self):
        self.assertFalse([c for c in self.report['totals'] if c.startswith(('style.', 'widget.'))])

    def test_without_the_contract_prefix_the_same_files_use_the_app_rules(self):
        report = ds_audit.aggregate(ds_audit.run_scanner([CONTRACT_FIXTURES], contract=[]))
        self.assertTrue(all(not c.startswith('contract.') for c in report['totals']))
        self.assertEqual(report['generated'], {})


class RatchetTest(unittest.TestCase):
    """Fails when apps/raft_flutter/lib or packages/raft_ui/lib gains drift.

    tool/check-project runs this test with the host tests, so it is the gate
    enforcement for both scopes (tool/preflight runs `tool/ds-audit --check`).
    """

    def test_no_file_exceeds_the_baseline(self):
        report = ds_audit.aggregate(ds_audit.run_scanner(ds_audit.SCOPES))
        baseline = ds_audit.load_baseline()
        self.assertEqual(baseline.get('scopes'), ds_audit.SCOPES)
        regressions, improvements = ds_audit.compare(baseline['files'], report['files'])
        message = ds_audit.format_comparison(regressions, improvements)
        if improvements and not regressions:
            print('\n' + message)
        self.assertEqual(regressions, [], '\n' + message)
        self.assertEqual(report['malformedAllows'], [], 'ds-allow comments need a reason')


if __name__ == '__main__':
    unittest.main()
