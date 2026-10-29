"""Ownership, state and evidence contracts, separate from count-only helpers.

JSON fixtures exercise metadata decisions only. ResolvedInventoryTest invokes
the real analyzer once; no mock inventory is called runtime/visual acceptance.
"""
import importlib.machinery
import importlib.util
import contextlib
import io
import base64
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
import ds_coverage as coverage  # noqa: E402


class CoverageDecisionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.file = 'packages/raft_ui/lib/sample.dart'
        path = self.root / self.file
        path.parent.mkdir(parents=True)
        path.write_text('source fixture; not a rendered frame')
        self.identity = self.file + '#class:Owned'
        self.use = self.identity + '|state:hover'
        self.registry = {
            'families': {'button': {'canonical': ['Owned'], 'deprecated': {},
                                   'canonicalBindings': {'Owned': {'declarationId': self.identity, 'role': 'public_api'}}}},
            'recipes': {'buttonVariants': {'family': 'button', 'decision': 'existing',
                                          'owner': 'fixture', 'axes': {'size': ['sm']}}},
        }
        pending = {'applicability': 'unknown', 'owner': 'fixture', 'reason': 'No actual state evidence.'}
        self.ledger = {'designSystemCoverage': {
            'schemaVersion': 1, 'canonicalRegistry': 'tool/ds-audit-families.json',
            'declarations': {self.identity: {'role': 'canonical_component', 'familyRefs': ['button'], 'owner': 'fixture'}},
            'entries': {'sample': {'owner': 'fixture', 'mountStatus': 'unresolved',
                                   'declarationRefs': [self.identity], 'reason': 'Not mounted.'}},
            'requirements': {'sample:hover': {**pending, 'entryId': 'sample'}},
            'knownStateAtoms': {'hover': 'hover'}, 'stateUses': {self.use: pending},
            'evidence': {}, 'currentClaims': {},
        }}
        self.inventory = {'version': 1, 'files': [self.file],
                          'declarations': [{'id': self.identity, 'name': 'Owned', 'kind': 'widget'}],
                          'recipes': {'buttonVariants': {'axes': {'size': ['sm']}}},
                          'references': [], 'stateAtoms': {'hover': 'hover'},
                          'stateUses': [{'id': self.use, 'owner': self.identity, 'atom': 'hover'}]}

    @property
    def rows(self):
        return self.ledger['designSystemCoverage']

    def check(self):
        return coverage.validate(self.root, self.registry, self.ledger, self.inventory, [self.file])

    def fails(self, needle):
        result = self.check()
        self.assertTrue(any(needle in error for error in result['errors']), result)
        self.assertEqual(result['visualPasses'], 0)

    def test_registered_pending_does_not_become_pass_or_block_functional_edit(self):
        self.assertEqual(self.check()['errors'], [])
        (self.root / self.file).write_text('callback-only fixture edit')
        result = self.check()
        self.assertEqual((result['errors'], result['visualPasses']), ([], 0))

    def test_new_recipe_and_known_axis_value_require_registration(self):
        self.inventory['recipes']['newRecipe'] = {'axes': {}}
        self.fails('recipe registration differs')
        self.inventory['recipes'].pop('newRecipe')
        self.inventory['recipes']['buttonVariants']['axes']['size'].append('lg')
        self.fails('known variant/axis')

    def test_new_resolved_declaration_fails_even_without_style_literals(self):
        self.inventory['declarations'].append({'id': self.file + '#class:NewWidget', 'kind': 'widget'})
        self.fails('unregistered widget')

    def test_new_known_state_or_atom_cannot_disappear(self):
        self.inventory['stateUses'].append({'id': self.identity + '|state:active'})
        self.fails('unregistered known state')
        self.inventory['stateUses'].pop()
        self.inventory['stateAtoms']['active'] = 'active'
        self.fails('state atoms changed')

    def test_missing_na_reason_or_source_binding_fails(self):
        row = self.rows['requirements']['sample:hover']
        row.update(applicability='not_applicable', reason='')
        self.fails('owner and reason')
        row['reason'] = 'Static label has no hover interaction.'
        self.fails('missing exact input bindings')

    def test_unqualified_pass_and_wrong_canonical_binding_are_rejected(self):
        self.rows['declarations'][self.identity]['pass'] = True
        self.fails('unqualified visual pass')
        self.rows['declarations'][self.identity].pop('pass')
        self.registry['families']['button']['canonicalBindings']['Owned']['declarationId'] = 'other.dart#class:Owned'
        self.fails('not resolved/registered')

    def test_a_new_widget_cannot_declare_itself_another_canonical_api(self):
        identity = self.file + '#class:SecondButton'
        self.rows['declarations'][identity] = {'role': 'canonical_component', 'familyRefs': ['button'], 'owner': 'fixture'}
        self.inventory['declarations'].append({'id': identity, 'name': 'SecondButton', 'kind': 'widget'})
        self.fails('not chosen by the canonical registry')

    def test_internal_wrapper_requires_real_resolved_delegation(self):
        wrapper = self.file + '#class:Wrapper'
        self.rows['declarations'][wrapper] = {
            'role': 'internal_wrapper', 'owner': 'fixture', 'familyRefs': ['button'],
            'delegatesTo': [self.identity],
        }
        self.inventory['declarations'].append({'id': wrapper, 'kind': 'widget'})
        self.fails('delegation is not resolved')
        self.inventory['references'].append({'owner': wrapper, 'target': self.identity})
        self.fails('delegation is not resolved')
        self.inventory['references'][-1]['kind'] = 'type'
        self.fails('delegation is not resolved')
        self.inventory['references'][-1]['kind'] = 'constructor_call'
        self.assertEqual(self.check()['errors'], [])
        self.inventory['paintUses'] = [{'owner': wrapper, 'name': 'ColoredBox'}]
        self.fails('independent paint')

    def test_unused_claim_is_contradicted_by_resolved_reference(self):
        row = self.rows['declarations'][self.identity]
        row.update(role='proven_unused', reason='Fixture review', reviewDecision='fixture-reviewed',
                   sourceBindings=[coverage.file_binding(self.root, self.file)])
        self.inventory['references'].append({'owner': 'caller', 'target': self.identity})
        self.fails('contradict proven_unused')

    def test_surface_function_needs_explicit_entry_mapping(self):
        self.inventory['declarations'][0]['kind'] = 'surface_factory'
        self.rows['entries']['sample']['declarationRefs'] = []
        self.fails('unregistered surface entry')

    def test_incomplete_runtime_census_is_a_failure(self):
        self.inventory['files'] = []
        self.fails('runtime file census is incomplete')

    def test_stale_history_is_retained_and_never_counted_current(self):
        binding = coverage.file_binding(self.root, self.file)
        self.rows['evidence']['old'] = {'scope': 'historical', 'result': 'pass', 'sourceBindings': [binding]}
        (self.root / self.file).write_text('new source')
        result = self.check()
        self.assertEqual((result['errors'], result['staleHistory'], result['visualPasses']), ([], ['old'], 0))
        self.rows['currentClaims']['sample:hover'] = 'old'
        self.fails('cannot count historical evidence')

    def test_unknown_or_stale_receipt_cannot_claim_current_pass(self):
        self.rows['evidence']['new'] = {
            'scope': 'current', 'result': 'pass', 'capturedCommit': 'a' * 40,
            'capturedTree': 'b' * 40, 'sourceBindings': [coverage.file_binding(self.root, self.file)],
        }
        self.rows['currentClaims']['sample:hover'] = 'new'
        self.fails('UNKNOWN/NA requirement')
        self.rows['requirements']['sample:hover']['applicability'] = 'required'
        self.fails('registered requirement')

    def test_input_bindings_reject_outside_paths(self):
        self.assertTrue(coverage.binding_errors(self.root, [{'file': '../private', 'bytes': 0, 'sha256': '0' * 64}]))

    def test_changed_fixture_bytes_invalidate_a_copied_input_hash(self):
        inputs = [coverage.file_binding(self.root, self.file)]
        value = coverage.digest(json.dumps(inputs, sort_keys=True, separators=(',', ':')).encode())
        receipt = {'result': 'pass', 'inputBindings': inputs, 'inputSHA256': value}
        requirement = {'applicability': 'required', 'inputSHA256': value, 'inputFiles': [self.file]}
        (self.root / self.file).write_text('changed fixture/action bytes')
        errors = coverage.current_receipt_errors(self.root, receipt, requirement, None)
        self.assertTrue(any('input: input binding changed' in e for e in errors), errors)

    def test_current_reference_must_match_the_actual_pinned_web_package(self):
        path = self.root / 'docs/source-reference.json'
        path.parent.mkdir()
        path.write_text(json.dumps({'commit': 'c' * 40, 'raftUiNpmVersion': '0.7.0'}))
        receipt = {'result': 'pass', 'referenceCommit': 'd' * 40, 'referencePackageVersion': '0.39.0',
                   'referenceBindings': [coverage.file_binding(self.root, 'docs/source-reference.json')]}
        errors = coverage.current_receipt_errors(self.root, receipt, {'applicability': 'required'}, None)
        self.assertTrue(any('current pinned Web dependency' in e for e in errors), errors)

    def test_type_wrong_schema_version_is_not_integer_one(self):
        self.rows['schemaVersion'] = True
        self.fails('integer1')

    def test_unknown_rows_ignore_an_incomplete_local_capture_manifest(self):
        for name in ['tool/ds-audit', 'tool/ds_coverage.py', 'tool/gen_l10n_index.py',
                     'tool/ds_audit/bin/ds_audit.dart', 'tool/ds_audit/lib/ownership_inventory.dart', 'pubspec.lock']:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('source fixture')
        (self.root / 'tool/ds-audit-families.json').write_text(json.dumps(self.registry))
        (self.root / 'docs').mkdir()
        (self.root / 'docs/state-parity.json').write_text(json.dumps(self.ledger))
        (self.root / '.local').mkdir()
        (self.root / '.local/design-system-execution.json').write_text('incomplete {')
        with mock.patch.object(coverage, 'runtime_sources', return_value=([self.file], [])), \
                mock.patch.object(coverage.subprocess, 'check_output', return_value=b''):
            result = coverage.check(self.root, self.inventory)
        self.assertEqual((result['errors'], result['visualPasses']), ([], 0))


class SourceFreshnessTest(unittest.TestCase):
    def test_each_ds_authority_and_the_hash_algorithm_invalidates_the_stamp(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'tool').mkdir()
            script = root / 'tool/source-hash'
            shutil.copyfile(ROOT / 'tool/source-hash', script)

            def stamp():
                return subprocess.check_output([sys.executable, str(script)], text=True)

            for name in ['tool/ds_coverage.py', 'tool/ds-audit-families.json', 'docs/state-parity.json']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('initial')
                before = stamp()
                path.write_text('mutated')
                self.assertNotEqual(before, stamp(), name)
            before = stamp()
            script.write_text(script.read_text() + '\n# algorithm version mutation\n')
            self.assertNotEqual(before, stamp(), 'hash algorithm itself')
            before = stamp()
            for name in ['docs/general.md', '.local/ds-audit.json', 'third_party/sample/cache/lib/generated.dart']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('transient')
            self.assertEqual(before, stamp(), 'general docs, reports and vendor cache stay excluded')


class PinnedReferenceProofTest(unittest.TestCase):
    def setUp(self):
        objects = {}

        def obj(kind, data):
            oid = hashlib.sha1(kind.encode() + b' ' + str(len(data)).encode() + b'\0' + data).hexdigest()
            if kind != 'blob':
                objects[oid] = {'type': kind, 'dataBase64': base64.b64encode(data).decode()}
            return oid

        package = b'{"dependencies":{"raft-ui":"npm:@botiverse/raft-ui@0.7.0"}}'
        source = b'export const stateFill = "bg-fill-pressed";'
        web = obj('tree', b'100644 Sidebar.tsx\0' + bytes.fromhex(obj('blob', source)) +
                  b'100644 package.json\0' + bytes.fromhex(obj('blob', package)))
        packages = obj('tree', b'40000 web\0' + bytes.fromhex(web))
        root = obj('tree', b'40000 packages\0' + bytes.fromhex(packages))
        self.commit = obj('commit', b'tree ' + root.encode() + b'\nauthor Fixture\n\nsource fixture\n')
        self.sources = ['packages/web/package.json', 'packages/web/Sidebar.tsx']
        self.proof = {'objects': objects, 'sources': [
            {'sourcePath': self.sources[0], 'dataBase64': base64.b64encode(package).decode()},
            {'sourcePath': self.sources[1], 'dataBase64': base64.b64encode(source).decode()},
        ]}

    def test_bundled_public_objects_validate_without_a_checkout_or_network(self):
        self.assertEqual(coverage.reference_proof_errors(self.proof, self.commit, '0.7.0', self.sources), [])

    def test_same_commit_label_cannot_hide_different_reference_source_bytes(self):
        self.proof['sources'][1]['dataBase64'] = base64.b64encode(b'export const stateFill = "bg-fill-muted";').decode()
        errors = coverage.reference_proof_errors(self.proof, self.commit, '0.7.0', self.sources)
        self.assertTrue(any('differs from pinned Git object' in e for e in errors), errors)

    def test_changed_tree_payload_is_rejected_even_with_unchanged_source_hash_labels(self):
        tree = next(r for r in self.proof['objects'].values() if r['type'] == 'tree')
        tree['dataBase64'] = base64.b64encode(b'changed tree').decode()
        errors = coverage.reference_proof_errors(self.proof, self.commit, '0.7.0', self.sources)
        self.assertTrue(any('Git object digest mismatch' in e for e in errors), errors)


class StandaloneGateTest(unittest.TestCase):
    def test_ds_failure_stops_before_asset_warmup_or_dart_test_shards(self):
        loader = importlib.machinery.SourceFileLoader('ds_check_project', str(ROOT / 'tool/check-project'))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        check = importlib.util.module_from_spec(spec)
        loader.exec_module(check)
        with tempfile.TemporaryDirectory() as temp:
            folder = pathlib.Path(temp)
            with mock.patch.object(check, 'local', folder), \
                    mock.patch.object(check.subprocess, 'check_output', return_value='hash\n'), \
                    mock.patch.object(check, 'discover_tests', return_value=[]), \
                    mock.patch.object(check, 'history_weights', return_value={}), \
                    mock.patch.object(check, 'run_logged', side_effect=[0, 0, 1]) as run, \
                    mock.patch.object(check, 'clear_unit_test_assets',
                                      side_effect=AssertionError('DS failure must stop before asset warmup')) as assets, \
                    contextlib.redirect_stderr(io.StringIO()):
                result = check.run_gate({}, mock.Mock(), 0)
            self.assertFalse(result['ok'])
            self.assertEqual(result['failed_checks'], ['ds-audit.txt'])
            self.assertEqual(run.call_count, 3)
            self.assertTrue(any(str(arg).endswith('ds-audit') for arg in run.call_args.args[0]))
            assets.assert_not_called()
            receipt = json.loads((folder / 'engineering-run.json').read_text())
            self.assertFalse(receipt['completed'])
            self.assertEqual(receipt['stoppedEarly']['reason'], 'ds-audit')
            self.assertEqual(receipt['shards'], [])


class ResolvedInventoryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        loader = importlib.machinery.SourceFileLoader('ds_ownership_cli', str(ROOT / 'tool/ds-audit'))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        cli = importlib.util.module_from_spec(spec)
        loader.exec_module(cli)
        cls.file = 'packages/raft_ui/test/fixtures/ds_audit_ownership/ownership_sample.dart'
        cls.report = cli.run_scanner([cls.file], contract=[], bypass=[], inventory=True,
                                     inventory_paths=[cls.file])['ownership']

    def test_resolved_private_state_and_widget_builder_are_inventoried(self):
        rows = {r['id']: r for r in self.report['declarations']}
        self.assertEqual(rows[self.file + '#class:OwnedSample']['kind'], 'widget')
        self.assertEqual(rows[self.file + '#class:_OwnedSampleState']['kind'], 'paint_owner')
        self.assertIn(self.file + '#function:buildOwnedSample', rows)

    def test_same_named_local_class_is_not_the_canonical_raft_button(self):
        local = self.file + '#class:RaftButton'
        self.assertTrue(any(r['target'] == local for r in self.report['references']))
        self.assertFalse(any(r['target'] == 'packages/raft_ui/lib/src/raft/button.dart#class:RaftButton'
                             for r in self.report['references']))

    def test_dynamic_builder_remains_unresolved(self):
        self.assertTrue(self.report['dynamicEdges'])
        self.assertEqual(self.report['mountEvidence'], 'NOT_PROVEN_BY_RESOLVED_REFERENCES')

    def test_literal_state_inputs_are_registered_but_conditions_are_not_atoms(self):
        atoms = {r['atom'] for r in self.report['stateUses']}
        self.assertIn('data-owned=true', atoms)
        self.assertIn('hover', atoms)
        self.assertNotIn('condition-only-not-an-atom', atoms)


class GeneratedMetadataTest(unittest.TestCase):
    def test_implicit_constructor_axes_survive_resolved_generated_metadata(self):
        loader = importlib.machinery.SourceFileLoader('ds_metadata_cli', str(ROOT / 'tool/ds-audit'))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        cli = importlib.util.module_from_spec(spec)
        loader.exec_module(cli)
        files = ['packages/raft_theme/lib/recipes/spinner.g.dart',
                 'packages/raft_theme/lib/recipes/button_variants.g.dart']
        data = cli.run_scanner(files, contract=['packages/raft_theme/lib/recipes'], bypass=[],
                               inventory=True, inventory_paths=files)['ownership']
        self.assertEqual(data['recipes']['spinner']['axes']['size'], ['xs', 'sm', 'md', 'lg'])
        self.assertEqual(data['recipes']['buttonVariants']['axes']['size'][-2:], ['icon-md', 'icon-lg'])


class ResolvedReviewRegressionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        loader = importlib.machinery.SourceFileLoader('ds_review_cli', str(ROOT / 'tool/ds-audit'))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        cli = importlib.util.module_from_spec(spec)
        loader.exec_module(cli)
        cls.file = 'packages/raft_ui/test/fixtures/ds_audit_ownership/review_regressions.dart'
        cls.report = cli.run_scanner([cls.file], contract=[], bypass=[], inventory=True,
                                     inventory_paths=[cls.file])['ownership']

    def decisions(self):
        pending = {'role': 'unresolved', 'familyRefs': [], 'owner': 'fixture',
                   'reason': 'No visual or semantic ownership claim.'}
        return {'designSystemCoverage': {
            'schemaVersion': 1, 'canonicalRegistry': 'tool/ds-audit-families.json',
            'declarations': {r['id']: dict(pending) for r in self.report['declarations']},
            'entries': {}, 'requirements': {}, 'knownStateAtoms': {},
            'stateUses': {}, 'evidence': {}, 'currentClaims': {},
        }}

    def validate(self, ledger, registry=None):
        return coverage.validate(ROOT, registry or {'families': {}, 'recipes': {}},
                                 ledger, self.report, [self.file])

    def test_local_widget_factories_are_distinct_resolved_declarations(self):
        local = [r for r in self.report['declarations'] if r['name'] == 'localPanel']
        self.assertEqual(len(local), 5, local)
        self.assertEqual(len({r['id'] for r in local}), 5)
        self.assertTrue(all(r['kind'] == 'builder' and not r['public'] for r in local))
        self.assertTrue(all(r['id'].startswith(self.file + '#local-function:') for r in local))

    def test_nested_and_same_named_block_scopes_keep_exact_reference_owners(self):
        local = {r['id']: r for r in self.report['declarations'] if r['name'] == 'localPanel'}
        self.assertEqual(len(local), 5)
        nested = [r for r in local.values() if r['owner'] in local]
        self.assertEqual(len(nested), 1)
        self.assertEqual(local[nested[0]['owner']]['owner'], self.file + '#function:firstScope')
        self.assertEqual(nested[0]['id'].count('FUNCTION:localPanel@'), 2)
        method_local = [r for r in local.values() if r['owner'] == self.file + '#method:LocalBuilderSample.build']
        self.assertEqual(len(method_local), 1)
        self.assertIn('CLASS:LocalBuilderSample@', method_local[0]['id'])
        self.assertIn('METHOD:build@', method_local[0]['id'])
        blocks = [r for r in local.values() if r['owner'] == self.file + '#function:secondScope']
        self.assertEqual(len(blocks), 2)
        targets = {r['target'] for r in self.report['references'] if r.get('kind') == 'function_call'}
        self.assertTrue(set(local) <= targets)

    def test_local_factory_registration_is_required_and_unknown_stays_nonvisual(self):
        ledger = self.decisions()
        self.assertEqual(self.validate(ledger)['errors'], [])
        rows = ledger['designSystemCoverage']['declarations']
        local = [r['id'] for r in self.report['declarations'] if r['name'] == 'localPanel']
        for identity in local:
            rows.pop(identity)
        result = self.validate(ledger)
        self.assertEqual(len(result['errors']), 5, result)
        self.assertTrue(all(any(identity in error for error in result['errors']) for identity in local))
        self.assertEqual(result['visualPasses'], 0)

    def wrapper_result(self, name):
        ledger = self.decisions()
        rows = ledger['designSystemCoverage']['declarations']
        target = self.file + '#class:CanonicalLeaf'
        wrapper = self.file + '#class:' + name
        rows[target] = {'role': 'canonical_component', 'familyRefs': ['leaf'], 'owner': 'fixture'}
        rows[wrapper] = {'role': 'internal_wrapper', 'familyRefs': ['leaf'], 'owner': 'fixture',
                         'delegatesTo': [target]}
        registry = {'families': {'leaf': {'canonical': ['CanonicalLeaf'], 'deprecated': {},
                     'canonicalBindings': {'CanonicalLeaf': {'declarationId': target, 'role': 'public_api'}}}},
                    'recipes': {}}
        return self.validate(ledger, registry)

    def test_type_annotation_alone_cannot_prove_wrapper_delegation(self):
        result = self.wrapper_result('AnnotationOnlyWrapper')
        self.assertTrue(any('declared delegation is not resolved' in e for e in result['errors']), result)
        self.assertEqual(result['visualPasses'], 0)

    def test_actual_constructor_delegation_still_satisfies_structural_role(self):
        self.assertEqual(self.wrapper_result('ActualWrapper')['errors'], [])


if __name__ == '__main__':
    unittest.main()
