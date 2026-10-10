import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from evidence import actual_layer, evaluate_item, machine_events, read_runs


def item():
    return {'id': 'N24', 'checks': [{'id': 'N24a', 'minimum_layer': 'mounted', 'minimum_passes': 1},
                                  {'id': 'N24b', 'minimum_layer': 'mounted', 'minimum_passes': 1}]}


def run(layer='mounted', result='success', skipped=False, valid=True, labels=('N24a', 'N24b')):
    return {'valid': valid, 'path': 'receipt.json', 'suiteLayers': {'test.dart': layer},
            'tests': [{'labels': [label], 'name': f'[{label}] scenario', 'suite': 'test.dart',
                       'result': result, 'skipped': skipped} for label in labels]}


class ChecklistEvidenceTest(unittest.TestCase):
    def performance_receipts(self, directory):
        module_path = Path(__file__).resolve().parents[1] / 'performance' / 'test_compare.py'
        spec = importlib.util.spec_from_file_location('sample_guards', module_path)
        module = importlib.util.module_from_spec(spec)
        # test_compare imports the real comparator as a sibling module.
        import sys
        sys.path.insert(0, str(module_path.parent))
        try:
            spec.loader.exec_module(module)
        finally:
            sys.path.pop(0)
        data = module.samples()
        for sample in data:
            sample['semanticsEnabled'] = False

        def save(base, filename, content):
            file = base / filename
            file.write_text(json.dumps(content))
            return {'path': filename, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest()}

        def bundle(base, commit, source_hash):
            base.mkdir()
            receipt = {
                'format': 'raft-native-performance-v1', 'commit': commit,
                'sourceHash': source_hash, 'sourceUnchanged': True,
                'completed': True, 'exitCode': 0, 'nativeExitCode': 0,
                'harnessSha256': 'identical-fixture', 'semanticsEnabled': False,
                'suite': 'integration_test/message_scroll_performance_test.dart',
                'name': '[P01a][P01b][P01c] brutal-light elegant-light elegant-dark',
                'samples': [save(base, f'sample-{i}.json', sample)
                            for i, sample in enumerate(data)],
                'driverResult': save(base, 'driver.json', {'result': 'true'}),
                'gateResult': save(base, 'gate.json', {'passed': True}),
            }
            save(base, 'receipt.json', receipt)
            return receipt

        root = Path(directory)
        reference = root / 'reference'
        bundle(reference, 'e210562a80e403986d0fc44090245657906277a0', 'baseline')
        current = root / 'current'
        receipt = bundle(current, 'candidate', 'current')
        reference_file = reference / 'receipt.json'
        receipt['referenceReceipt'] = {'path': str(reference_file),
                                      'sha256': hashlib.sha256(reference_file.read_bytes()).hexdigest()}
        save(current, 'receipt.json', receipt)
        return current / 'receipt.json', receipt, save

    def test_native_performance_recomputes_gate_and_requires_real_driver(self):
        with tempfile.TemporaryDirectory() as directory:
            path, receipt, save = self.performance_receipts(directory)
            requirement = {'id': 'P01', 'checks': [{'id': 'P01a', 'minimum_layer': 'native'}]}
            self.assertEqual(evaluate_item(requirement, read_runs([path], 'current'))['status'], 'verified')
            # A manually green gate cannot hide a failed raw CPU measurement.
            sample = json.loads((path.parent / 'sample-0.json').read_text())
            sample['cpuPercentOneCore'] = 100
            receipt['samples'][0] = save(path.parent, 'sample-0.json', sample)
            save(path.parent, 'receipt.json', receipt)
            self.assertEqual(evaluate_item(requirement, read_runs([path], 'current'))['status'], 'partial')

    def test_native_performance_tamper_reference_and_driver_failure_cannot_pass(self):
        for mutation in ('tamper', 'missing-reference', 'failed-driver', 'incomplete', 'mode-mismatch'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                path, receipt, save = self.performance_receipts(directory)
                if mutation == 'tamper':
                    (path.parent / 'sample-0.json').write_text('{}')
                    with self.assertRaises(ValueError):
                        read_runs([path], 'current')
                    continue
                if mutation == 'missing-reference':
                    receipt.pop('referenceReceipt')
                elif mutation == 'failed-driver':
                    receipt['driverResult'] = save(path.parent, 'driver.json', {'result': 'false'})
                elif mutation == 'mode-mismatch':
                    receipt['semanticsEnabled'] = True
                else:
                    receipt['completed'] = False
                save(path.parent, 'receipt.json', receipt)
                self.assertFalse(read_runs([path], 'current')[0]['valid'])

    def test_single_semantics_mode_cannot_verify_the_canonical_performance_contract(self):
        with tempfile.TemporaryDirectory() as directory:
            path, _, _ = self.performance_receipts(directory)
            contract = json.loads((Path(__file__).parent / 'data/performance.json').read_text())[0]
            self.assertEqual(evaluate_item(contract, read_runs([path], 'current'))['status'], 'partial')

    def test_exported_native_bundle_retains_verifiable_reference_and_raw_frames(self):
        from build import export_performance_receipt
        with tempfile.TemporaryDirectory() as directory:
            path, _, _ = self.performance_receipts(directory)
            exported = export_performance_receipt(path, Path(directory) / 'published')
            self.assertTrue(read_runs([exported], 'current')[0]['valid'])
            self.assertFalse((exported.parent / 'runner.log').exists())

    def test_plain_registration_cannot_be_promoted_by_a_suite_flag(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'mixed_test.dart'
            source.write_text("test('model', () {});\ntestWidgets('page', (t) async {});\n")
            origin = {'root_url': source.as_uri(), 'root_line': 1}
            self.assertEqual(actual_layer(origin, 'mounted'), 'model')
            self.assertEqual(actual_layer({**origin, 'root_line': 2}, 'mounted'), 'mounted')
            self.assertEqual(actual_layer({**origin, 'root_line': 2}, 'controller'), 'controller')

    def test_chat_component_proof_cannot_verify_actual_activity_handler(self):
        it = item(); it['checks'] = [{**it['checks'][0], 'proof_file': 'workspace_test.dart'}]
        self.assertEqual(evaluate_item(it, [run()])['status'], 'partial')

    def test_all_children_must_pass_on_page(self):
        self.assertEqual(evaluate_item(item(), [run()])['status'], 'verified')
        self.assertEqual(evaluate_item(item(), [run(labels=('N24a',))])['status'], 'partial')

    def test_model_and_controller_proof_cannot_verify_page_contract(self):
        for layer in ('model', 'controller'):
            self.assertEqual(evaluate_item(item(), [run(layer=layer)])['status'], 'partial')

    def test_failed_skipped_aborted_or_changed_input_cannot_verify(self):
        for overrides in ({'result': 'failure'}, {'skipped': True}, {'valid': False}):
            self.assertEqual(evaluate_item(item(), [run(**overrides)])['status'], 'partial')

    def test_duplicate_attempts_cannot_satisfy_missing_theme_count(self):
        it = {'id': 'L02', 'checks': [{'id': 'L02', 'minimum_layer': 'mounted', 'minimum_passes': 3}]}
        self.assertEqual(evaluate_item(it, [run(labels=('L02',))] * 3)['status'], 'partial')

    def test_handwritten_completion_is_rejected(self):
        with self.assertRaises(ValueError):
            evaluate_item({**item(), 'status': 'verified'}, [])

    def test_historical_implementation_progress_never_becomes_current_proof(self):
        for old in ('verified', 'implemented_unverified'):
            self.assertEqual(evaluate_item(item(), [], {'status': old})['status'], 'missing_evidence')
        self.assertEqual(evaluate_item(item(), [], {'status': 'partial'})['status'], 'partial')
        self.assertEqual(evaluate_item(item(), [], {'status': 'not_started'})['status'], 'not_started')
        self.assertEqual(evaluate_item(item(), [])['status'], 'missing_evidence')
        self.assertEqual(evaluate_item(item(), [run()], {'status': 'not_started'})['status'], 'verified')

    def test_performance_labels_remain_native_only(self):
        raw = json.dumps({"type": "testStart", "test": {"id": 1, "name": "[P01a][P01b][P01c] brutal-light profile"}})
        self.assertEqual(machine_events(raw)["tests"][0]["labels"], ["P01a", "P01b", "P01c"])
        requirement = {"id": "P01", "checks": [{"id": "P01a", "minimum_layer": "native"}]}
        self.assertEqual(evaluate_item(requirement, [run(labels=("P01a",))])["status"], "partial")
        self.assertEqual(evaluate_item(requirement, [run(layer="native", labels=("P01a",))])["status"], "verified")

    def test_machine_incomplete_test_is_retained_and_failure_preserved(self):
        raw = '\n'.join(json.dumps(e) for e in [
            {'type': 'testStart', 'test': {'id': 1, 'suiteID': 1, 'name': '[N24a] slow response'}},
            {'type': 'error', 'testID': 1, 'error': 'crash'},
            {'type': 'done', 'success': False}])
        result = machine_events(raw)
        self.assertFalse(result['completed'])
        self.assertEqual(result['tests'][0]['result'], 'incomplete')
        self.assertEqual(len(result['errors']), 1)

    def test_wrong_snapshot_and_tampered_log_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / 'tests.jsonl'; log.write_text('{"type":"done","success":true}\n')
            receipt = root / 'receipt.json'
            receipt.write_text(json.dumps({'sourceHash': 'old', 'machineLog': log.name,
                                           'machineLogSha': hashlib.sha256(log.read_bytes()).hexdigest(),
                                           'sourceUnchanged': True, 'exitCode': 0}))
            self.assertEqual(read_runs([receipt], 'new'), [])
            log.write_text('changed')
            with self.assertRaises(ValueError):
                read_runs([receipt], 'old')


if __name__ == '__main__':
    unittest.main()
