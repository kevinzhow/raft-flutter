"""Release folders retain the source identity linked from their notices."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('copy_docs_release', TOOL / 'release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseCopyDocsTests(unittest.TestCase):
    def test_real_copy_preserves_readme_current_source_identity_and_notices(self):
        with tempfile.TemporaryDirectory(prefix='raft-release-copy-docs-') as folder:
            destination = Path(folder)
            release.copy_docs(destination)
            for name in ['README.md', 'THIRD_PARTY_NOTICES.md', 'docs/source-reference.json',
                         'docs/linux-media-runtime.md']:
                with self.subTest(name=name):
                    self.assertEqual((destination / name).read_bytes(), (release.ROOT / name).read_bytes())
            self.assertIn('docs/source-reference.json', (destination / 'THIRD_PARTY_NOTICES.md').read_text())
            self.assertTrue((destination / 'docs/licenses/raft-source-FSL-1.1-ALv2.txt').is_file())


if __name__ == '__main__':
    unittest.main()
