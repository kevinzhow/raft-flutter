#!/usr/bin/env python3
"""N24 fixture admission checks, including independent parent hydration."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

TOOLS = Path(__file__).resolve().parent

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value

channel = module('channel_fixture', TOOLS / 'build-fixture.py')
thread = module('thread_fixture', TOOLS / 'build-thread-fixture.py')

class ActivityFixtureContract(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(prefix='raft-n24-fixture-')
        self.addCleanup(self.dir.cleanup)
        self.base = Path(self.dir.name) / 'channel.json'
        self.bytes = (json.dumps(channel.build(), indent=2) + '\n').encode()
        self.base.write_bytes(self.bytes)

    def test_n24_thread_parent_and_reply_are_separately_scoped(self):
        fixture = thread.build(self.base)
        flow, routes = fixture['process'], fixture['routes']
        self.assertEqual(self.base.read_bytes(), self.bytes)
        self.assertEqual(flow['requirement'], 'N24/thread-single')
        parent_rows = routes[flow['parentHold']]['messages']
        replies = routes[flow['repliesHold']]['messages']
        self.assertEqual([row['id'] for row in parent_rows], [flow['parentMessageId']])
        self.assertEqual({row['channelId'] for row in parent_rows}, {flow['parentChannelId']})
        self.assertEqual({row['channelId'] for row in replies}, {flow['threadChannelId']})
        self.assertEqual(sum(row['id'] == flow['threadTargetMessageId'] for row in replies), 1)
        self.assertEqual(len(replies), 21)
        # Canonical routes load an outer tail. It must not quietly seed the
        # supposedly held parent via the accepted channel bucket.
        outer = routes[f"GET /messages/channel/{flow['parentChannelId']}"]['messages']
        self.assertTrue(outer)
        self.assertNotIn(flow['parentMessageId'], [row['id'] for row in outer])
        self.assertNotEqual(flow['parentHold'], flow['repliesHold'])

    def test_n24_channel_after_thread_retains_original_channel_windows(self):
        original = json.loads(self.bytes)
        fixture = thread.build(self.base, after_thread=True)
        flow = fixture['process']
        self.assertEqual(flow['requirement'], 'N24/channel-after-thread-single')
        for key in (flow['hold'], f"GET /messages/channel/{flow['channelId']}"):
            self.assertEqual(fixture['routes'][key], original['routes'][key])
        self.assertEqual([row['kind'] for row in fixture['routes']['GET /channels/inbox']['items']], ['thread', 'channel'])

    def test_n24_double_and_sparse_are_distinct_inputs(self):
        fixture = thread.build(self.base, after_thread=True, activation='double', short_thread=True)
        flow = fixture['process']
        self.assertEqual(flow['requirement'], 'N24/channel-after-thread-double')
        self.assertEqual(flow['focusExpectation'], 'clamped-short-window')
        replies = fixture['routes'][flow['repliesHold']]['messages']
        self.assertEqual([row['id'] for row in replies], [flow['threadTargetMessageId']])
        self.assertEqual(self.base.read_bytes(), self.bytes)

if __name__ == '__main__':
    unittest.main()
