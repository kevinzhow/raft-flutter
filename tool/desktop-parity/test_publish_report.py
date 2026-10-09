import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image

spec = importlib.util.spec_from_file_location('desktop_report', Path(__file__).with_name('publish-report.py'))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class FullFrameComparisonTest(unittest.TestCase):
    def test_size_mismatch_withholds_metrics_and_creates_no_cropped_outputs(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)
            Image.new('RGBA', (128, 80), 'white').save(p / 'web.png')
            Image.new('RGBA', (127, 80), 'white').save(p / 'native.png')
            result = report.compare_full_frames(p / 'web.png', p / 'native.png', p / 'diff.png', p / 'sheet.png')
            self.assertFalse(result['sizeEqual'])
            self.assertNotIn('delta24MismatchRatio', result)
            self.assertFalse((p / 'diff.png').exists())
            self.assertFalse((p / 'sheet.png').exists())

    def test_full_raster_and_alpha_are_included_without_acceptance_threshold(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)
            Image.new('RGBA', (4, 2), (100, 100, 100, 255)).save(p / 'web.png')
            native = Image.new('RGBA', (4, 2), (100, 100, 100, 255))
            native.putpixel((3, 1), (100, 100, 100, 230))
            native.save(p / 'native.png')
            result = report.compare_full_frames(p / 'web.png', p / 'native.png', p / 'diff.png', p / 'sheet.png')
            self.assertTrue(result['sizeEqual'])
            self.assertEqual(result['delta24MismatchRatio'], 1 / 8)
            self.assertEqual(result['exactPixelMismatchRatio'], 1 / 8)
            self.assertIsNone(result['acceptanceThreshold'])
            with Image.open(p / 'diff.png') as image:
                self.assertEqual(image.size, (4, 2))
            with Image.open(p / 'sheet.png') as image:
                self.assertEqual(image.size, (4 * 3 + 16, 2 + 28))


if __name__ == '__main__':
    unittest.main()
