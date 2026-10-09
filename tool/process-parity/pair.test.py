#!/usr/bin/env python3
"""Receipt admission tests only; these do not claim actual renderer evidence."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('pair_admission', Path(__file__).with_name('compare-pair.py'))
pair = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pair)

class BoundProcessReceipts(unittest.TestCase):
    def setUp(self):
        self.source = {
            'fixtureSha': 'a' * 64, 'sourceHead': 'b' * 40,
            'sourceInputSha': 'c' * 64, 'runtimeSha': 'd' * 64,
            'theme': 'brutal', 'form': 'mobile',
            'viewport': {'width': 390, 'height': 844},
        }
        self.flutter = {**copy.deepcopy(self.source),
                        'platform': 'linux', 'device': 'linux-xvfb'}

    def test_same_width_linux_is_not_android(self):
        self.assertEqual(pair.input_failures(self.source, self.flutter), [])
        self.assertEqual(self.flutter['platform'], 'linux')
        actual_android = {**self.flutter, 'platform': 'android', 'device': 'emulator-5580'}
        self.assertEqual(pair.input_failures(self.source, actual_android), [])
        self.assertEqual(actual_android['platform'], 'android')

    def test_same_missing_fingerprints_cannot_become_bound_pair(self):
        for key in ('sourceInputSha', 'runtimeSha'):
            with self.subTest(key=key):
                source, flutter = copy.deepcopy(self.source), copy.deepcopy(self.flutter)
                source[key] = flutter[key] = None
                self.assertTrue(pair.input_failures(source, flutter))
                del source[key]
                del flutter[key]
                self.assertIn(f'Missing bound input: {key}', pair.input_failures(source, flutter))

    def test_exact_fixture_does_not_hide_stale_product_or_runtime(self):
        for key in ('sourceInputSha', 'runtimeSha'):
            with self.subTest(key=key):
                self.assertIn(f'Input mismatch: {key}', pair.input_failures(
                    self.source, {**self.flutter, key: 'e' * 64}))

    def test_missing_device_or_platform_never_infers_linux(self):
        for key in ('device', 'platform'):
            with self.subTest(key=key):
                flutter = copy.deepcopy(self.flutter)
                del flutter[key]
                self.assertTrue(pair.input_failures(self.source, flutter))

    def test_malformed_matching_fingerprint_is_rejected(self):
        for key in ('fixtureSha', 'sourceHead', 'sourceInputSha', 'runtimeSha'):
            with self.subTest(key=key):
                source, flutter = copy.deepcopy(self.source), copy.deepcopy(self.flutter)
                source[key] = flutter[key] = 'same-unverified-value'
                self.assertTrue(pair.input_failures(source, flutter))

    def test_unknown_identity_cannot_borrow_resolved_controls(self):
        shell = {'headers': 1, 'tabs': 1, 'composer': 1, 'accepted': None}
        unresolved = {'channelPlaceholder': True, 'tabs': 0, 'composer': 0, 'accepted': None}
        summary = {'stages': {'pending-tail': shell, 'tail-still-held': shell, 'pending-identity': unresolved}}
        self.assertEqual(pair.loading_failures('cold-unknown', summary, summary), [])
        borrowed = copy.deepcopy(summary)
        borrowed['stages']['pending-identity']['composer'] = 1
        self.assertTrue(pair.loading_failures('cold-unknown', summary, borrowed))
        fake_tail = copy.deepcopy(summary)
        fake_tail['stages']['pending-tail']['accepted'] = {'inView': True}
        self.assertTrue(pair.loading_failures('cold-known', summary, fake_tail))

    def test_canceled_request_is_not_late_success_or_late_error_proof(self):
        delivered = {'receipt': {'stages': [{'name': 'stale-response-released', 'staleResponseObserved': True}]}}
        canceled = {'receipt': {'stages': [{'name': 'stale-response-released', 'staleResponseObserved': False}]}}
        for flow in ('stale-back-retarget-success', 'stale-back-retarget-error'):
            self.assertEqual(pair.loading_failures(flow, delivered, delivered), [])
            self.assertTrue(pair.loading_failures(flow, delivered, canceled))

if __name__ == '__main__':
    unittest.main()
