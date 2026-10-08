"""Design-system drift ratchet (tool/ds-audit) and scanner semantics."""
import importlib.machinery
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
_loader = importlib.machinery.SourceFileLoader('ds_audit_cli', str(ROOT / 'tool/ds-audit'))
_spec = importlib.util.spec_from_loader('ds_audit_cli', _loader)
ds_audit = importlib.util.module_from_spec(_spec)
_loader.exec_module(ds_audit)

FIXTURE = 'apps/raft_flutter/test/fixtures/ds_audit_sample.dart'


class CompareTest(unittest.TestCase):
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
        self.assertIn('tool/ds-audit --update-baseline',
                      ds_audit.format_comparison(regressions, improvements))

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


class RatchetTest(unittest.TestCase):
    """Fails when apps/raft_flutter/lib gains design-system drift."""

    def test_no_file_exceeds_the_baseline(self):
        report = ds_audit.aggregate(ds_audit.run_scanner([ds_audit.SCOPE]))
        baseline = ds_audit.load_baseline()
        self.assertEqual(baseline.get('scope'), ds_audit.SCOPE)
        regressions, improvements = ds_audit.compare(baseline['files'], report['files'])
        message = ds_audit.format_comparison(regressions, improvements)
        if improvements and not regressions:
            print('\n' + message)
        self.assertEqual(regressions, [], '\n' + message)
        self.assertEqual(report['malformedAllows'], [], 'ds-allow comments need a reason')


if __name__ == '__main__':
    unittest.main()
