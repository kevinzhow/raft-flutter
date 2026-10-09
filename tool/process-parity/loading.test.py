#!/usr/bin/env python3
"""Ensure process inputs actually distinguish discovery and request ownership."""
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).with_name('build-loading-fixture.py')
spec = importlib.util.spec_from_file_location('loading_fixture', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class LoadingFixtureContract(unittest.TestCase):
    def test_cold_known_uses_real_sidebar_unknown_uses_valid_focus_anchor(self):
        known, unknown = module.build('cold-known'), module.build('cold-unknown')
        target = known['process']['channelId']
        self.assertIn(target, [r['id'] for r in known['routes']['GET /channels']])
        self.assertNotIn(target, [r['id'] for r in unknown['routes']['GET /channels']])
        self.assertNotIn(target, [r['id'] for r in unknown['context']['channels']])
        key = known['process']['metadataHold']
        self.assertEqual(known['routes'][key], unknown['routes'][key])
        self.assertEqual(known['process']['opener'], 'sidebar')
        self.assertEqual(known['process']['window'], 'tail')
        self.assertEqual(unknown['process']['window'], 'context')
        for fixture in (known, unknown):
            row = fixture['routes']['GET /channels/inbox']['items'][0]
            self.assertIsInstance(row['lastMessageId'], str)
            self.assertTrue(row['lastMessageId'])
            self.assertEqual(fixture['process']['hold'], fixture['process']['tailHold'])

    def test_stale_success_and_error_share_replacement_identity_and_bytes(self):
        success = module.build('stale-back-retarget-success')
        error = module.build('stale-back-retarget-error')
        flow = success['process']
        self.assertNotEqual(flow['hold'], flow['replacementHold'])
        self.assertNotEqual(flow['channelId'], flow['replacementChannelId'])
        self.assertEqual(success['routes'][flow['replacementHold']], error['routes'][flow['replacementHold']])
        self.assertEqual(error['routes'][flow['hold']]['__status'], 500)
        self.assertNotEqual(success['routes'][flow['hold']], error['routes'][flow['hold']])
        rows = success['routes'][flow['replacementHold']]['messages']
        self.assertEqual({r['channelId'] for r in rows}, {flow['replacementChannelId']})
        self.assertEqual(sum(r['id'] == flow['replacementTargetId'] for r in rows), 1)
        self.assertNotIn(flow['targetMessageId'], [r['id'] for r in rows])

if __name__ == '__main__':
    unittest.main()
