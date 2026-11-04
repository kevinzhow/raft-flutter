"""The generated Pub dependency is authenticated, isolated and never overwritten."""
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest import mock

from tool.html_webview import linux_pointer as pointer


class PointerPreparationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='raft-pointer-prepare-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / 'input.tar.gz'
        self.output = self.root / 'generated'
        self.files = {'pubspec.yaml': b'name: flutter_inappwebview_linux\n',
                      pointer.TARGET: b'original pointer source\n',
                      'linux/native.cc': b'unchanged native source\n'}

    def archive_files(self, extra=None):
        with tarfile.open(self.archive, 'w:gz') as archive:
            for name, contents in self.files.items():
                entry = tarfile.TarInfo(name)
                entry.mode = 0o644
                entry.size = len(contents)
                archive.addfile(entry, io.BytesIO(contents))
            if extra:
                archive.addfile(extra, io.BytesIO(b'x') if extra.isfile() else None)
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(pointer, 'ARCHIVE_SHA256', hashlib.sha256(self.archive.read_bytes()).hexdigest()).start()
        mock.patch.object(pointer, 'patch', lambda text: text.replace('original', 'adapted')).start()

    def test_authenticate_and_change_one_file_only_then_reuse_exact_output(self):
        self.archive_files()
        result = pointer.prepare(self.archive, self.output)
        self.assertEqual(result, pointer.prepare(self.archive, self.output))
        self.assertEqual([n for n in result['original'] if result['original'][n] != result['output'][n]],
                         [pointer.TARGET])
        for name, data in self.files.items():
            self.assertEqual((self.output / name).read_bytes(),
                             data.replace(b'original', b'adapted') if name == pointer.TARGET else data)
            self.assertEqual((self.output / name).stat().st_mode & 0o7777, 0o644)

    def test_bad_archive_pin_creates_nothing(self):
        self.archive_files()
        with mock.patch.object(pointer, 'ARCHIVE_SHA256', '0' * 64):
            with self.assertRaisesRegex(ValueError, 'fixed SHA256'):
                pointer.prepare(self.archive, self.output)
        self.assertFalse(self.output.exists())

    def test_changed_existing_file_is_preserved(self):
        self.archive_files()
        pointer.prepare(self.archive, self.output)
        file = self.output / pointer.TARGET
        file.write_bytes(b'keep this failed or locally modified output')
        with self.assertRaisesRegex(ValueError, 'differs; preserve'):
            pointer.prepare(self.archive, self.output)
        self.assertEqual(file.read_bytes(), b'keep this failed or locally modified output')

    def test_extra_symlink_directory_and_hardlink_are_rejected(self):
        self.archive_files()
        pointer.prepare(self.archive, self.output)
        extra = self.output / 'extra'
        extra.symlink_to(self.root, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'differs; preserve'):
            pointer.prepare(self.archive, self.output)
        extra.unlink()
        file = self.output / pointer.TARGET
        outside = self.root / 'outside.dart'
        outside.write_bytes(file.read_bytes())
        file.unlink()
        os.link(outside, file)
        with self.assertRaisesRegex(ValueError, 'differs; preserve'):
            pointer.prepare(self.archive, self.output)

    def test_changed_mode_or_receipt_is_not_repaired_in_place(self):
        self.archive_files()
        pointer.prepare(self.archive, self.output)
        file = self.output / pointer.TARGET
        file.chmod(0o666)
        with self.assertRaisesRegex(ValueError, 'differs; preserve'):
            pointer.prepare(self.archive, self.output)
        self.assertEqual(file.stat().st_mode & 0o7777, 0o666)
        file.chmod(0o644)
        record = self.output / pointer.RECEIPT
        value = json.loads(record.read_text())
        value['archiveSha256'] = 'untrusted replacement'
        record.write_text(json.dumps(value))
        with self.assertRaisesRegex(ValueError, 'differs; preserve'):
            pointer.prepare(self.archive, self.output)

    def test_destination_parent_symlink_is_never_traversed(self):
        self.archive_files()
        alias = self.root / 'alias'
        alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'cannot traverse'):
            pointer.prepare(self.archive, alias / 'generated')
        self.assertFalse(self.output.exists())

    def test_archive_links_traversal_duplicates_and_permissions_fail_closed(self):
        for kind in ['link', 'parent', 'duplicate', 'mode']:
            with self.subTest(kind=kind):
                entry = tarfile.TarInfo('../escape' if kind == 'parent' else
                                        pointer.TARGET if kind == 'duplicate' else 'extra')
                entry.size = 1
                entry.mode = 0o600 if kind == 'mode' else 0o644
                if kind == 'link':
                    entry.type = tarfile.SYMTYPE
                    entry.linkname = '/etc/passwd'
                    entry.size = 0
                self.archive_files(extra=entry)
                with self.assertRaises(ValueError):
                    pointer.prepare(self.archive, self.output)
                self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()
