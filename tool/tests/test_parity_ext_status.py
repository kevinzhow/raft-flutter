"""Capture completeness must affect exit status even when the visual report was written."""
import argparse
import importlib.machinery
import importlib.util
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
    def run_capture(self, totals):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            (out / 'summary.json').write_text('{}')
            (out / 'summary.md').write_text('report')
            args = argparse.Namespace(cases='sample', frozen=False, refresh_react=False, skip_flutter=True)
            with patch.object(adapter, 'OUT', out), \
                 patch.object(adapter, 'ext_cases', return_value=[{'id': 'sample'}]), \
                 patch.object(adapter.parity, 'select', side_effect=lambda cases, _: cases), \
                 patch.object(adapter, 'react_capture'), \
                 patch.object(adapter, 'cli', side_effect=lambda *a, **k: (out / 'site').mkdir(exist_ok=True)), \
                 patch.object(adapter.parity, 'SITE', out / 'site'), \
                 patch.object(adapter.parity, 'git', return_value='source'), \
                 patch.object(adapter, 'summarize', return_value={'totals': totals}):
                adapter.cmd_run(args)
            self.assertTrue((out / 'site/flutter-parity-summary.json').is_file())

    def totals(self, **missing):
        return dict(total=1, passing=0, percentage=0, geometryPass=0, geometryPercentage=0,
                    reactMissing=0, flutterCaptureFailed=0, notCovered=0, **missing)

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


if __name__ == '__main__':
    unittest.main()
