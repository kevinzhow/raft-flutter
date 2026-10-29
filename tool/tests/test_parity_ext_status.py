"""Capture completeness must affect exit status even when the visual report was written."""
import argparse
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
loader = importlib.machinery.SourceFileLoader('parity_ext_status_adapter', str(TOOL / 'parity-ext/run'))
adapter = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
loader.exec_module(adapter)


class CaptureExitTests(unittest.TestCase):
    def run_capture(self, totals, *, allow_gaps=False, environment_failed=False, previous_reference=False, failed_shards=0):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            previous = {'cases': [{'id': 'sample', 'react': True}]} if previous_reference else {}
            (out / 'summary.json').write_text(json.dumps(previous))
            (out / 'summary.md').write_text('report')
            args = argparse.Namespace(cases='sample', frozen=False, refresh_react=False, skip_flutter=not failed_shards, shards=1,
                                      allow_structural_gaps=allow_gaps)
            with patch.object(adapter, 'OUT', out), \
                 patch.object(adapter, 'ext_cases', return_value=[{'id': 'sample'}]), \
                 patch.object(adapter.parity, 'select', side_effect=lambda cases, _: cases), \
                 patch.object(adapter, 'react_capture', return_value=environment_failed), \
                 patch.object(adapter, 'cli', side_effect=lambda *a, **k: (out / 'site').mkdir(exist_ok=True)), \
                 patch.object(adapter.parity, 'SITE', out / 'site'), \
                 patch.object(adapter.parity, 'git', return_value='source'), \
                 patch.dict(adapter.os.environ, {}), \
                 patch.object(adapter.parity, 'flutter_capture', return_value=failed_shards), \
                 patch.object(adapter, 'summarize', return_value={
                     'totals': totals, 'cases': [{'id': 'sample', 'react': not totals['reactMissing']}]}):
                adapter.cmd_run(args)
            self.assertTrue((out / 'site/flutter-parity-summary.json').is_file())

    def totals(self, **missing):
        return dict(total=1, passing=0, percentage=0, geometryPass=0, geometryPercentage=0,
                    reactCaptured=1, reactMissing=0, flutterCaptureFailed=0, notCovered=0, **missing)

    def test_failing_flutter_shard_is_not_hidden_by_complete_images(self):
        with self.assertRaises(SystemExit) as error:
            self.run_capture(self.totals(), failed_shards=1)
        self.assertEqual(error.exception.code, 1)

    def test_missing_web_reference_exits_nonzero(self):
        totals = self.totals()
        totals['reactMissing'] = 1
        with self.assertRaises(SystemExit) as error:
            self.run_capture(totals)
        self.assertEqual(error.exception.code, 1)

    def test_missing_flutter_or_unmapped_surface_exits_nonzero(self):
        for reason in ['flutterCaptureFailed', 'notCovered']:
            with self.subTest(reason=reason):
                totals = self.totals()
                totals[reason] = 1
                with self.assertRaises(SystemExit) as error:
                    self.run_capture(totals)
                self.assertEqual(error.exception.code, 1)

    def test_complete_capture_keeps_pixel_difference_reportable(self):
        self.run_capture(self.totals())

    def test_full_run_reports_structural_reference_gaps_without_failing(self):
        totals = self.totals()
        totals.update(total=100, reactCaptured=90, reactMissing=8, notCovered=2)
        self.run_capture(totals, allow_gaps=True)

    def test_browser_environment_failure_is_not_a_structural_gap(self):
        totals = self.totals()
        totals.update(total=100, reactCaptured=90, reactMissing=10)
        with self.assertRaises(SystemExit) as error:
            self.run_capture(totals, allow_gaps=True, environment_failed=True)
        self.assertEqual(error.exception.code, 1)

    def test_full_run_cannot_lose_a_reference_that_previously_succeeded(self):
        totals = self.totals()
        totals.update(total=100, reactCaptured=99, reactMissing=1)
        with self.assertRaises(SystemExit) as error:
            self.run_capture(totals, allow_gaps=True, previous_reference=True)
        self.assertEqual(error.exception.code, 1)

    def test_full_run_cannot_succeed_without_any_reference(self):
        totals = self.totals()
        totals.update(reactCaptured=0, reactMissing=1)
        with self.assertRaises(SystemExit) as error:
            self.run_capture(totals, allow_gaps=True)
        self.assertEqual(error.exception.code, 1)


if __name__ == '__main__':
    unittest.main()
