"""SDK archive metadata must be portable and must never replace existing evidence."""
import hashlib
from pathlib import Path
import tarfile
import tempfile
import unittest

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from html_webview.stage import archive_sdk, build_receipts


class SdkArchiveTest(unittest.TestCase):
    def test_archive_roundtrip_preserves_nested_helper_and_contained_alias(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            prefix = root / 'sdk'
            helper = prefix / 'libexec/wpe-webkit-2.0/WPEWebProcess'
            helper.parent.mkdir(parents=True)
            helper.write_bytes(b'fixture helper, not an engine')
            helper.chmod(0o755)
            (prefix / 'lib').mkdir()
            (prefix / 'lib/actual').write_bytes(b'fixture library')
            (prefix / 'lib/alias').symlink_to('actual')
            archive = root / 'sdk.tar.gz'
            archive_sdk(prefix, archive)
            with tarfile.open(archive) as tar:
                entries = tar.getmembers()
                self.assertTrue(all(item.uid == item.gid == item.mtime == 0 for item in entries))
                self.assertTrue(all(item.uname == item.gname == '' for item in entries))
                tar.extractall(root / 'restored', filter='data')
            self.assertEqual((root / 'restored/lib/alias').read_bytes(), b'fixture library')
            self.assertEqual((root / 'restored/libexec/wpe-webkit-2.0/WPEWebProcess').stat().st_mode & 0o777, 0o755)

    def test_same_bytes_ignore_original_file_times(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            prefix = root / 'sdk'
            prefix.mkdir()
            file = prefix / 'notice'
            file.write_text('fixture')
            archive_sdk(prefix, root / 'a.tar.gz')
            file.touch()
            archive_sdk(prefix, root / 'b.tar.gz')
            self.assertEqual(hashlib.sha256((root / 'a.tar.gz').read_bytes()).digest(),
                             hashlib.sha256((root / 'b.tar.gz').read_bytes()).digest())

    def test_full_build_ledger_is_copied_and_bound_to_the_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'installed-packages.tsv').write_text('fixture version architecture')
            (root / 'package-archives.json').write_text('[]')
            (root / 'compiler.txt').write_text('fixture compiler identity')
            (root / 'resource-readback.txt').write_text('fixture capped resources')
            identity = {'environment': {
                'packagesSha256': hashlib.sha256((root / 'installed-packages.tsv').read_bytes()).hexdigest(),
                'packageArchivesSha256': hashlib.sha256((root / 'package-archives.json').read_bytes()).hexdigest(),
                'resourceReadbackSha256': hashlib.sha256((root / 'resource-readback.txt').read_bytes()).hexdigest(),
            }}
            build_receipts(root, root / 'metadata', identity)
            self.assertEqual((root / 'metadata/compiler.txt').read_text(), 'fixture compiler identity')
            self.assertEqual((root / 'metadata/installed-packages.tsv').read_bytes(),
                             (root / 'installed-packages.tsv').read_bytes())
            self.assertTrue((root / 'metadata/adapters/wpe-network-data-order.patch').is_file())

    def test_changed_build_ledger_is_rejected_before_copying(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'installed-packages.tsv').write_text('changed')
            with self.assertRaisesRegex(ValueError, 'Build provenance changed'):
                build_receipts(root, root / 'metadata', {'environment': {'packagesSha256': 'a' * 64}})
            self.assertFalse((root / 'metadata').exists())

    def test_previous_archive_is_retained(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'prefix').mkdir()
            previous = root / 'previous.tar.gz'
            previous.write_bytes(b'previous failure')
            with self.assertRaises(FileExistsError):
                archive_sdk(root / 'prefix', previous)
            self.assertEqual(previous.read_bytes(), b'previous failure')


if __name__ == '__main__':
    unittest.main()
