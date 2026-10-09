import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from parity_reference_defects import admitted_defects, annotate_site


class ReferenceDefectsTest(unittest.TestCase):
    def test_only_the_reviewed_source_and_image_admit_a_warning(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            image = root / 'case.png'
            image.write_bytes(b'reviewed-image')
            entry = {'baselineSha256': hashlib.sha256(image.read_bytes()).hexdigest()}
            registry = {'sourceCommit': 'pinned', 'cases': {'case': entry}}
            self.assertEqual(admitted_defects(registry, 'pinned', root), {'case': entry})
            self.assertEqual(admitted_defects(registry, 'different', root), {})
            image.write_bytes(b'new-capture')
            self.assertEqual(admitted_defects(registry, 'pinned', root), {})

    def test_annotation_keeps_original_result_payload_and_does_not_inject_markup(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            original = '<html><body><script id="vt-data">{"status":"different"}</script></body></html>'
            (root / 'index.html').write_text(original)
            defects = {'case': {'title': 'Invalid reference', 'description': '</script><a>raw text</a>'}}
            annotate_site(root, defects)
            rendered = (root / 'index.html').read_text()
            self.assertIn('<script id="vt-data">{"status":"different"}</script>', rendered)
            self.assertNotIn('</script><a>raw text</a>', rendered)
            self.assertEqual(json.loads((root / 'reference-defects.json').read_text()), defects)
            self.assertIn('data-reference-defect', rendered)
