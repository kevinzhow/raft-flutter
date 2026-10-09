import hashlib
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
