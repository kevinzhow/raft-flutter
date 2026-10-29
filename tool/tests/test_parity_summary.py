"""Summaries preserve variant identity without re-reading the manifest per row."""
import importlib.machinery
import importlib.util
import json
import sys
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
loader = importlib.machinery.SourceFileLoader('parity_summary_test_adapter', str(ROOT / 'tool/parity'))
parity = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
loader.exec_module(parity)


class SummaryManifestTest(unittest.TestCase):
    def test_manifest_read_once_and_exact_variant_identity_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            results = Path(temp)
            (results / 'diff').mkdir()
            rows = [
                {'id': 'a', 'status': 'same', 'baselineImage': 'a.png', 'currentImage': 'a2.png',
                 'metrics': {'pixelPerfectSimilarity': 1.0}},
                {'id': 'b', 'status': 'different', 'baselineImage': 'b.png', 'currentImage': 'b2.png',
                 'metrics': {'pixelPerfectSimilarity': 0.6124284511784511}},
                {'id': 'missing', 'status': 'missing'},
            ]
            (results / 'diff' / f'{parity.PAIR}.json').write_text(json.dumps({'results': rows}))
            (results / 'android-case-map.json').write_text(json.dumps({
                key: {'status': 'mapped'} for key in ('a', 'b')
            }))
            manifest = [
                {'id': 'a', 'variants': [{'id': 'chosen-a'}]},
                {'id': 'b', 'variants': [{'id': 'chosen-b'}]},
                # Match the original first-match behavior even for a duplicate.
                {'id': 'a', 'variants': [{'id': 'later-a'}]},
            ]
            with mock.patch.object(parity, 'RESULTS', results), \
                    mock.patch.object(parity, 'OUT', results), \
                    mock.patch.object(parity, 'manifest_cases', return_value=manifest) as read_manifest, \
                    mock.patch.object(parity, 'git', return_value='test-head'):
                summary = parity.summarize()
            self.assertEqual([row['variant'] for row in summary['cases']], ['chosen-a', 'chosen-b', None])
            self.assertEqual([row['verdict'] for row in summary['cases']], ['passing', 'failing', 'not-covered'])
            self.assertEqual(summary['cases'][1]['pixelPerfectSimilarity'], 0.6124284511784511)
            self.assertEqual(summary['totals']['passing'], 1)
            self.assertEqual(summary['totals']['total'], 3)
            self.assertEqual(read_manifest.call_count, 1)


class CaptureStatusTest(unittest.TestCase):
    def run_capture(self, failed_shards=0, *, missing=False):
        from argparse import Namespace
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)
            (out / 'summary.json').write_text('{}')
            (out / 'summary.md').write_text('report')
            summary = {'cases': [{'id': 'sample', 'react': True, 'flutter': not missing,
                                  'verdict': 'flutter-capture-failed' if missing else 'failing'}]}
            args = Namespace(cases='sample', frozen=None, refresh_react=False, react_fonts='production',
                             react_text_render='android', skip_flutter=False, shards=1)
            with mock.patch.object(parity, 'OUT', out), \
                 mock.patch.object(parity, 'SITE', out / 'site'), \
                 mock.patch.object(parity, 'manifest_cases', return_value=[{'id': 'sample'}]), \
                 mock.patch.object(parity, 'select', side_effect=lambda rows, _: rows), \
                 mock.patch.object(parity, 'react_capture'), \
                 mock.patch.object(parity, 'flutter_capture', return_value=failed_shards), \
                 mock.patch.object(parity, 'cli', side_effect=lambda *a, **k: (out / 'site').mkdir(exist_ok=True)), \
                 mock.patch.object(parity, 'summarize', return_value=summary), \
                 mock.patch.object(parity, 'git', return_value='fixture'), \
                 mock.patch.object(parity, 'admitted_defects', return_value={}), \
                 mock.patch.object(parity, 'repair_definition', return_value={}), \
                 mock.patch.object(parity, 'repair_annotations', return_value={}), \
                 mock.patch.object(parity, 'annotate_site'):
                try:
                    return parity.cmd_run(args)
                finally:
                    self.assertTrue((out / 'site/flutter-parity-summary.json').is_file())

    def test_failing_shard_cannot_succeed_even_if_all_images_exist(self):
        with self.assertRaises(SystemExit) as error:
            self.run_capture(1)
        self.assertEqual(error.exception.code, 1)

    def test_missing_selected_image_cannot_succeed(self):
        with self.assertRaises(SystemExit) as error:
            self.run_capture(missing=True)
        self.assertEqual(error.exception.code, 1)

    def test_pixel_difference_remains_reportable_after_complete_capture(self):
        self.assertEqual(self.run_capture()['cases'][0]['verdict'], 'failing')

    def test_child_test_exit_status_is_returned(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)
            with mock.patch.object(parity, 'OUT', out), \
                 mock.patch.object(parity, 'RESULTS', out / 'results'), \
                 mock.patch.object(parity, 'git', return_value='fixture'), \
                 mock.patch.object(parity.parity_case_map, 'write'), \
                 mock.patch.object(parity.subprocess, 'Popen') as popen:
                popen.return_value.wait.return_value = 1
                self.assertEqual(parity.flutter_capture([{'id': 'sample'}], 'sample', 1), 1)


if __name__ == '__main__':
    unittest.main()
