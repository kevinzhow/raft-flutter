import hashlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('sources', Path(__file__).resolve().parents[1] / 'media_linux_sources.py')
sources = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sources)


class PinnedSourcesTests(unittest.TestCase):
    def test_download_uses_generic_package_and_accepts_only_approved_hash(self):
        payload = b'approved binary'
        with tempfile.TemporaryDirectory() as temp, patch.object(sources.urllib.request, 'urlopen',
                return_value=io.BytesIO(payload)) as request:
            path = sources.download_pinned('libmpv2', '0.41.0-2ubuntu4', hashlib.sha256(payload).hexdigest(), temp)
            self.assertTrue(request.call_args.args[0].endswith('/libmpv2_0.41.0-2ubuntu4_amd64.deb'))
            self.assertEqual(path.read_bytes(), payload)

    def test_hash_drift_never_populates_the_cache(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(sources.urllib.request, 'urlopen',
                return_value=io.BytesIO(b'optimized variant')):
            with self.assertRaisesRegex(ValueError, 'SHA-256'):
                sources.download_pinned('libmpv2', '0.41.0-2ubuntu4', '0' * 64, temp)
            self.assertFalse(list(Path(temp).iterdir()))

    def test_bad_existing_cache_is_preserved_and_rejected(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(sources.urllib.request, 'urlopen') as request:
            path = Path(temp) / 'libmpv2_0.41.0-2ubuntu4_amd64.deb'
            path.write_bytes(b'bad cached bytes')
            with self.assertRaisesRegex(ValueError, 'Cached'):
                sources.download_pinned('libmpv2', '0.41.0-2ubuntu4', '0' * 64, temp)
            self.assertEqual(path.read_bytes(), b'bad cached bytes')
            request.assert_not_called()


if __name__ == '__main__':
    unittest.main()
