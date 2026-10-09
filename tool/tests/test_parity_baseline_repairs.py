import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from parity_baseline_repairs import (TASKS_ANCHOR, NOTIFICATION_ANCHOR, NOTIFICATION_IMPORT,
                                    repair_definition, repair_cases,
                                    capture_is_current, preserve_capture, repair_annotations)

ROOT = pathlib.Path(__file__).resolve().parents[2]


class BaselineRepairsTest(unittest.TestCase):
    def test_fixture_repair_changes_only_the_broken_task_projection(self):
        repair = repair_definition(ROOT)
        original = ('product-before\n' + TASKS_ANCHOR + '\n' + NOTIFICATION_IMPORT
                    + '\n' + NOTIFICATION_ANCHOR + '\nproduct-after')
        patched = repair_cases(original, repair, repair['sourceCommit'])
        self.assertTrue(patched.startswith('product-before\n'))
        self.assertTrue(patched.endswith('\nproduct-after'))
        self.assertEqual(patched.count('"status": "in_progress"'), 5)
        self.assertIn('NotificationTrigger flavor="mobile-navbar"', patched)
        self.assertIn('"kind": "warning"', patched)
        self.assertIn('"kind": "info"', patched)
        with self.assertRaises(ValueError):
            repair_cases(original, repair, 'different-source')
        with self.assertRaises(ValueError):
            repair_cases(original + TASKS_ANCHOR, repair, repair['sourceCommit'])
        with self.assertRaises(ValueError):
            repair_cases(original + NOTIFICATION_ANCHOR, repair, repair['sourceCommit'])

    def test_notification_and_markdown_cache_identities_are_independent(self):
        repair = repair_definition(ROOT)
        notification = repair['additionalRepairs'][0]
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            task_meta = root / f"{repair['markdownCases'][0]}.metadata.json"
            task_meta.write_text(json.dumps({'baselineRepair': {
                'fixtureSha256': repair['fixtureSha256'], 'renderVerified': True}}))
            notification_meta = root / f"{notification['cases'][0]}.metadata.json"
            notification_meta.write_text(task_meta.read_text())
            self.assertTrue(capture_is_current(task_meta, repair))
            self.assertFalse(capture_is_current(notification_meta, repair))
            notification_meta.write_text(json.dumps({'baselineRepair': {
                'fixtureSha256': notification['fixtureSha256'], 'renderVerified': True}}))
            self.assertFalse(capture_is_current(notification_meta, repair))
            notification_meta.write_text(json.dumps({'baselineRepair': {
                'fixtureSha256': notification['fixtureSha256'], 'renderVerified': True,
                'captureVerified': True}}))
            self.assertTrue(capture_is_current(notification_meta, repair))

    def test_changed_fixture_or_unverified_render_invalidates_cached_reference(self):
        with tempfile.TemporaryDirectory() as temp:
            metadata = pathlib.Path(temp) / 'case.metadata.json'
            repair = {'fixtureSha256': 'new'}
            for entry in ({}, {'fixtureSha256': 'old', 'renderVerified': True},
                          {'fixtureSha256': 'new', 'renderVerified': False}):
                metadata.write_text(json.dumps({'baselineRepair': entry}))
                self.assertFalse(capture_is_current(metadata, repair))
            metadata.write_text(json.dumps({'baselineRepair': {'fixtureSha256': 'new', 'renderVerified': True}}))
            self.assertTrue(capture_is_current(metadata, repair))

    def test_reference_refresh_preserves_original_bytes_and_metadata(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            react = root / 'react'
            react.mkdir()
            (react / 'case.png').write_bytes(b'original-failure')
            (react / 'case.metadata.json').write_text('{"status":"old"}')
            record = preserve_capture(react, root / 'history', 'case')
            expected = hashlib.sha256(b'original-failure').hexdigest()
            self.assertEqual(record['sha256'], expected)
            archived = pathlib.Path(record['directory'])
            (react / 'case.png').write_bytes(b'repaired')
            self.assertEqual((archived / 'case.png').read_bytes(), b'original-failure')
            self.assertEqual((archived / 'case.metadata.json').read_text(), '{"status":"old"}')

    def test_repair_notice_publishes_original_image_and_verified_render_receipt(self):
        with tempfile.TemporaryDirectory() as temp:
            out = pathlib.Path(temp)
            react = out / 'visual-testing-results/react'
            react.mkdir(parents=True)
            image = react / 'case.png'
            metadata = react / 'case.metadata.json'
            image.write_bytes(b'old-reference')
            preserve_capture(react, out / 'react-baseline-history', 'case')
            image.write_bytes(b'repaired-reference')
            repair = {'cases': ['case'], 'fixtureSha256': 'new'}
            metadata.write_text(json.dumps({'baselineRepair': {
                'fixtureSha256': 'new', 'renderVerified': True}}))
            site = out / 'site'
            notes = repair_annotations(out, site, repair)
            self.assertEqual(notes['case']['kind'], 'repair')
            self.assertEqual(notes['case']['baselineSha256'], hashlib.sha256(image.read_bytes()).hexdigest())
            old_link = notes['case']['links'][-1]['href']
            self.assertEqual((site / old_link).read_bytes(), b'old-reference')
            self.assertEqual((site / 'reference-repairs/case.metadata.json').read_bytes(), metadata.read_bytes())
