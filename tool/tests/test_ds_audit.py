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
BYPASS_FIXTURES = 'apps/raft_flutter/test/fixtures/ds_audit_bypass'
FAMILY_FIXTURES = 'apps/raft_flutter/test/fixtures/ds_audit_family'


def check_report(files, baseline, **extra):
    """Run the real CLI policy against a fake report, without keeping scratch files."""
    report = {'scannedFiles': 1, 'scopes': ds_audit.SCOPES, 'totals': {}, 'allowedTotals': {},
              'allowed': {}, 'files': files, 'malformedAllows': [], 'generated': {},
              'generatedTotal': 0, **extra}
    output = io.StringIO()
    with tempfile.TemporaryDirectory() as temporary:
        root = pathlib.Path(temporary)
        with mock.patch.object(ds_audit, 'run_scanner', return_value={}), \
                mock.patch.object(ds_audit, 'aggregate', return_value=report), \
                mock.patch.object(ds_audit, 'load_baseline', return_value=baseline), \
                mock.patch.object(ds_audit, 'ROOT', root), \
                mock.patch.object(ds_audit, 'REPORT', root / '.local/ds-audit.json'), \
                contextlib.redirect_stdout(output):
            code = ds_audit.main(['--check'])
    return code, output.getvalue()


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
        for files, expected in (({'a.dart': {'widget.list_tile': 1}}, 0),  # decreases only
                                ({'a.dart': {'widget.list_tile': 2}, 'b.dart': {'widget.dialog': 1}}, 0),
                                ({'a.dart': {'widget.list_tile': 3}}, 1)):
            self.assertEqual(check_report(files, baseline)[0], expected, files)

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


class FakeReportHelperTest(unittest.TestCase):
    def test_scratch_and_mocks_are_restored_when_the_cli_raises(self):
        original_root, original_report = ds_audit.ROOT, ds_audit.REPORT
        original_scanner = ds_audit.run_scanner
        temporary_roots = []

        def fail_after_writing_report(arguments):
            self.assertEqual(arguments, ['--check'])
            root = ds_audit.ROOT
            temporary_roots.append(root)
            self.assertTrue(root.is_dir())
            ds_audit.REPORT.parent.mkdir()
            ds_audit.REPORT.write_text('partial report before failure')
            raise RuntimeError('fixture CLI failure')

        with mock.patch.object(ds_audit, 'main', side_effect=fail_after_writing_report):
            with self.assertRaisesRegex(RuntimeError, 'fixture CLI failure'):
                check_report({}, {'files': {}})
        self.assertEqual(len(temporary_roots), 1)
        self.assertFalse(temporary_roots[0].exists())
        self.assertEqual(ds_audit.ROOT, original_root)
        self.assertEqual(ds_audit.REPORT, original_report)
        self.assertIs(ds_audit.run_scanner, original_scanner)


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
        return check_report(files, baseline or self.BASELINE, **extra)

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


class BypassRatchetTest(unittest.TestCase):
    """The bypass group: raw Material/Cupertino controls and overlays in app and raft_ui."""

    APP = 'apps/raft_flutter/lib/features/x.dart'
    UI = 'packages/raft_ui/lib/src/y.dart'
    BASELINE = {'files': {APP: {'bypass.dialog': 2, 'widget.dialog': 2}, UI: {'bypass.text_field': 1}}}

    def check(self, files, **extra):
        return ContractRatchetTest.check(self, files, baseline=self.BASELINE, **extra)

    def test_growth_in_either_scope_fails_and_names_the_raft_component(self):
        for name, category, use in ((self.APP, 'bypass.dialog', 'showRaftAlertDialog'),
                                    (self.UI, 'bypass.text_field', 'RaftTextInput'),
                                    (self.UI, 'bypass.menu', 'RaftDropdownMenu'),
                                    (self.APP, 'bypass.button', 'RaftButton')):
            files = {self.APP: {'bypass.dialog': 2, 'widget.dialog': 2}, self.UI: {'bypass.text_field': 1}}
            files.setdefault(name, {})
            files[name][category] = files[name].get(category, 0) + 1
            code, output = self.check(files)
            self.assertEqual(code, 1, category)
            self.assertIn(f'{name}: {category}', output)
            self.assertIn(f'{category}: ', output)
            self.assertIn(use, output)
            self.assertIn('BYPASS_ALLOWLIST', output)

    def test_every_family_has_a_raft_replacement_hint(self):
        for category in ('bypass.dialog', 'bypass.bottom_sheet', 'bypass.menu', 'bypass.select', 'bypass.tooltip',
                         'bypass.button', 'bypass.icon_button', 'bypass.toggle', 'bypass.chip', 'bypass.list_tile',
                         'bypass.progress', 'bypass.refresh', 'bypass.divider', 'bypass.text_field',
                         'bypass.picker', 'bypass.snackbar', 'bypass.overlay'):
            self.assertIn(category, ds_audit.BYPASS_USE)
            self.assertIn('Raft', ds_audit.BYPASS_USE[category])

    def test_decreases_and_unchanged_counts_pass(self):
        for files in (self.BASELINE['files'],
                      {self.APP: {'bypass.dialog': 1, 'widget.dialog': 2}},
                      {}):
            code, output = self.check(files)
            self.assertEqual(code, 0, files)
            self.assertNotIn('GREW', output)

    def test_a_new_file_with_a_bypass_fails(self):
        code, output = self.check({**self.BASELINE['files'], 'apps/raft_flutter/lib/new.dart': {'bypass.tooltip': 1}})
        self.assertEqual(code, 1)
        self.assertIn('new.dart: bypass.tooltip 0 -> 1', output)

    def test_the_wrapper_allowlist_is_explicit_small_and_points_at_real_files(self):
        self.assertLessEqual(len(ds_audit.BYPASS_ALLOWLIST), 8)
        for name, families in ds_audit.BYPASS_ALLOWLIST.items():
            self.assertTrue((ROOT / name).is_file(), name)
            self.assertTrue(name.startswith('packages/raft_ui/lib/'), name)  # wrappers only, never the app
            for family, reason in families.items():
                self.assertIn(f'bypass.{family}', ds_audit.BYPASS_USE, f'{name}: {family}')
                self.assertGreater(len(reason), 10, f'{name}: {family} needs a reason')

    def test_scanner_scopes_cover_app_and_raft_ui(self):
        self.assertEqual(ds_audit.BYPASS_SCOPES, ['apps/raft_flutter/lib', 'packages/raft_ui/lib'])


class BypassScannerFixtureTest(unittest.TestCase):
    """Exact counts for the resolved-AST bypass scan on a fixture with negatives."""

    WRAPPER = f'{BYPASS_FIXTURES}/wrapper_sample.dart'

    @classmethod
    def setUpClass(cls):
        cls.document = ds_audit.run_scanner(
            [BYPASS_FIXTURES], contract=[], bypass=[BYPASS_FIXTURES],
            bypass_allow={cls.WRAPPER: {'text_field': 'fixture stands in for the input wrapper'}})
        cls.report = ds_audit.aggregate(cls.document)

    def bypass(self, table):
        return {c: n for c, n in table.items() if c.startswith('bypass.')}

    def test_fixture_counts_per_family(self):
        self.assertEqual(self.bypass(self.report['totals']), {
            'bypass.bottom_sheet': 1, 'bypass.button': 2, 'bypass.chip': 1,
            'bypass.dialog': 5,  # AlertDialog, SimpleDialog, Dialog.fullscreen, showDialog(), showDialog tear-off
            'bypass.divider': 1, 'bypass.icon_button': 2, 'bypass.list_tile': 1, 'bypass.menu': 2,
            'bypass.overlay': 3, 'bypass.picker': 1, 'bypass.progress': 2, 'bypass.refresh': 1,
            'bypass.select': 2, 'bypass.text_field': 2, 'bypass.toggle': 2,
            'bypass.tooltip': 2,  # Tooltip( and `extends Tooltip`
        })

    def test_wrapper_allowlist_reports_separately_and_only_its_families(self):
        self.assertEqual(self.bypass(self.report['files'][self.WRAPPER]), {'bypass.overlay': 1})
        self.assertEqual(self.bypass(self.report['allowed'][self.WRAPPER]), {'bypass.text_field': 1})
        reasons = [f['allowReason'] for f in self.document['findings'] if f['file'] == self.WRAPPER and f['allowed']]
        self.assertEqual(reasons, ['raft_ui wrapper: fixture stands in for the input wrapper'])

    def test_ds_allow_comments_work_for_bypass_findings(self):
        self.assertEqual(self.bypass(self.report['allowedTotals']), {'bypass.dialog': 2, 'bypass.text_field': 1})
        self.assertEqual(self.report['malformedAllows'], [])

    def test_same_name_non_material_classes_and_raft_components_are_not_counted(self):
        lookalikes = [f for f in self.document['findings'] if f['file'].endswith('lookalikes.dart')]
        self.assertEqual(lookalikes, [])
        names = {f['name'] for f in self.document['findings'] if f['category'].startswith('bypass.')}
        self.assertFalse({n for n in names if n.startswith(('fake', 'Raft'))})
        sample = [f for f in self.document['findings']
                  if f['file'].endswith('bypass_sample.dart') and f['category'].startswith('bypass.')]
        self.assertTrue(all(f['line'] < 78 or f['name'] == 'extends Tooltip' for f in sample), sample)

    def test_without_the_bypass_prefix_nothing_is_counted(self):
        report = ds_audit.aggregate(ds_audit.run_scanner([BYPASS_FIXTURES], contract=[], bypass=[]))
        self.assertFalse([c for c in report['totals'] if c.startswith('bypass.')])
        self.assertTrue(any(c.startswith('widget.') for c in report['totals']))  # the app rules still run


class FamilyRegistryTest(unittest.TestCase):
    """tool/ds-audit-families.json: one implementation per design-system family."""

    @classmethod
    def setUpClass(cls):
        cls.families = ds_audit.load_families()
        cls.sources = {p: p.read_text() for p in (ROOT / 'packages/raft_ui/lib').rglob('*.dart')}

    def declared(self, name, text):
        import re
        return re.search(rf'^(?:abstract |final |base |sealed |interface )*(?:class|mixin|enum) {name}\b'
                         rf'|^[A-Za-z<>?, ]+ {name}[<(]', text, re.M) is not None

    def test_every_deprecated_name_is_declared_in_its_listed_raft_ui_file(self):
        for family, entry in self.families.items():
            for name, file in entry['deprecated'].items():
                self.assertTrue(file.startswith('packages/raft_ui/lib/'), f'{family}: {name}')
                self.assertTrue((ROOT / file).is_file(), f'{family}: {name} -> {file}')
                self.assertTrue(self.declared(name, (ROOT / file).read_text()), f'{name} is not declared in {file}')

    def test_every_canonical_component_exists_in_raft_ui(self):
        for family, entry in self.families.items():
            if 'pending' in entry:  # canonical choice belongs to an open work package
                self.assertEqual((entry['canonical'], entry['deprecated']), ([], {}), family)
                continue
            self.assertTrue(entry['canonical'], family)
            for name in entry['canonical']:
                self.assertTrue(any(self.declared(name, text) for text in self.sources.values()),
                                f'{family}: canonical {name} not found in packages/raft_ui/lib')

    def test_a_name_belongs_to_one_family_and_never_to_both_roles(self):
        seen = ds_audit.duplicate_index(self.families)  # raises if two families deprecate the same name
        canonical = {n for e in self.families.values() for n in e['canonical']}
        self.assertEqual(canonical & set(seen), set())

    def test_deprecating_a_name_twice_is_an_error(self):
        families = {'a': {'canonical': ['X'], 'deprecated': {'Old': 'f.dart'}},
                    'b': {'canonical': ['Y'], 'deprecated': {'Old': 'g.dart'}}}
        with self.assertRaises(ds_audit.AuditError):
            ds_audit.duplicate_index(families)

    def test_the_requested_families_are_registered_and_uncertain_choices_say_why(self):
        self.assertEqual(set(self.families), {'button', 'menu', 'popover', 'dialog', 'segmented', 'spinner',
                                               'card', 'banner', 'list_row', 'checkbox', 'select', 'switch',
                                               'radio_group', 'toggle_group', 'tabs', 'picker_trigger', 'combobox',
                                               'steps'})
        self.assertGreater(len(self.families['menu']['pending']), 40)  # P2 decides; nothing counted yet
        for family in ('dialog',):
            self.assertGreater(len(self.families[family].get('uncertain', '')), 40, family)
        for family in ('segmented', 'checkbox', 'select', 'switch', 'radio_group', 'toggle_group', 'tabs',
                       'picker_trigger', 'combobox', 'steps'):  # decided by P4: canonical only, nothing uncertain
            self.assertNotIn('uncertain', self.families[family], family)
            self.assertTrue(self.families[family]['canonical'], family)
        for family in ('spinner', 'card', 'popover'):  # decided by P6: canonical only, no duplicate left
            self.assertEqual(self.families[family]['deprecated'], {}, family)
        self.assertIn('RaftArchivedNameBanner', self.families['banner']['deprecated'])
        self.assertNotIn('RaftAgentBanner', self.families['banner']['deprecated'])  # thin adapter over RaftBanner


class FamilyRatchetTest(unittest.TestCase):
    """duplicate.<family>: growth fails and names the canonical component, decreases pass."""

    APP = 'apps/raft_flutter/lib/features/x.dart'
    UI = 'packages/raft_ui/lib/src/y.dart'
    BASELINE = {'files': {APP: {'duplicate.button': 3}, UI: {'duplicate.dialog': 2}}}

    def check(self, files):
        return ContractRatchetTest.check(self, files, baseline=self.BASELINE)

    def test_growth_fails_in_either_scope_and_names_the_canonical_component(self):
        for name, category, canonical, old in ((self.APP, 'duplicate.button', 'RaftButton', 'RaftRecipeButton'),
                                               (self.UI, 'duplicate.dialog', 'RaftDialog', 'RaftDialogCard'),
                                               (self.UI, 'duplicate.list_row', 'RaftListRow', 'RaftAvatarListRow'),
                                               (self.APP, 'duplicate.banner', 'RaftBanner', 'RaftComposerNotice')):
            files = {self.APP: {'duplicate.button': 3}, self.UI: {'duplicate.dialog': 2}}
            files.setdefault(name, {})
            files[name][category] = files[name].get(category, 0) + 1
            code, output = self.check(files)
            self.assertEqual(code, 1, category)
            self.assertIn(f'{name}: {category}', output)
            self.assertIn(f'{category}: use {canonical}', output)
            self.assertIn(old, output)

    def test_unchanged_and_lower_counts_pass(self):
        for files in (self.BASELINE['files'], {self.APP: {'duplicate.button': 1}}, {}):
            code, output = self.check(files)
            self.assertEqual(code, 0, files)
            self.assertNotIn('GREW', output)

    def test_a_new_file_using_a_deprecated_duplicate_fails(self):
        code, output = self.check({**self.BASELINE['files'], 'apps/raft_flutter/lib/new.dart': {'duplicate.menu': 1}})
        self.assertEqual(code, 1)
        self.assertIn('new.dart: duplicate.menu 0 -> 1', output)


class FamilyScannerFixtureTest(unittest.TestCase):
    """Exact counts for the resolved-AST family scan on a fixture with negatives."""

    OLD = f'{FAMILY_FIXTURES}/old_widgets.dart'
    REGISTRY = {
        'button': {'canonical': ['NewButton'], 'deprecated': {'OldButton': OLD}},
        'banner': {'canonical': ['NewButton'], 'deprecated': {'OldBanner': OLD}},
        'dialog': {'canonical': ['NewButton'], 'deprecated': {'showOldModal': OLD}},
    }

    @classmethod
    def setUpClass(cls):
        cls.document = ds_audit.run_scanner([FAMILY_FIXTURES], contract=[], bypass=[FAMILY_FIXTURES],
                                            bypass_allow={}, families=cls.REGISTRY)
        cls.report = ds_audit.aggregate(cls.document)

    def duplicates(self, table):
        return {c: n for c, n in table.items() if c.startswith('duplicate.')}

    def test_counts_references_outside_the_defining_file(self):
        self.assertEqual(self.duplicates(self.report['totals']), {
            'duplicate.banner': 1,
            # field type, parameter type, extends, const call, named constructor, static member, is-check
            'duplicate.button': 7,
            'duplicate.dialog': 2,  # call and tear-off
        })
        self.assertEqual(list(self.report['files']), [f'{FAMILY_FIXTURES}/family_sample.dart'])

    def test_the_defining_file_the_canonical_component_and_a_same_named_class_elsewhere_do_not_count(self):
        counted = {f['file'].rsplit('/', 1)[1] for f in self.document['findings']
                   if f['category'].startswith('duplicate.')}
        self.assertEqual(counted, {'family_sample.dart'})  # not old_widgets.dart, new_widgets.dart or lookalike.dart
        lines = {f['line'] for f in self.document['findings'] if f['category'].startswith('duplicate.')}
        self.assertFalse(lines & {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12})  # comments, doc reference, imports, string

    def test_without_a_registry_nothing_is_counted(self):
        report = ds_audit.aggregate(ds_audit.run_scanner([FAMILY_FIXTURES], contract=[], bypass=[FAMILY_FIXTURES],
                                                         bypass_allow={}, families={}))
        self.assertFalse([c for c in report['totals'] if c.startswith('duplicate.')])

    def test_a_directory_outside_the_scan_scopes_is_not_scanned(self):
        report = ds_audit.aggregate(ds_audit.run_scanner([FAMILY_FIXTURES], contract=[], bypass=[],
                                                         bypass_allow={}, families=self.REGISTRY))
        self.assertFalse([c for c in report['totals'] if c.startswith('duplicate.')])


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
