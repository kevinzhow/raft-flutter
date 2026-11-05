"""Atomic build-local copy boundaries, with no Flutter, GTK window or source-cache writes."""
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch

from tool import desktop_window_creation as copier

ORIGINAL = Path.home() / '.pub-cache/hosted/pub.dev/desktop_multi_window-0.3.1/linux/desktop_multi_window_plugin.cc'


@unittest.skipUnless(sys.platform == 'linux', 'Linux build-local file descriptors')
class PrivateCreationCopy(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='raft-private-control-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source.cc'
        self.source.write_bytes(ORIGINAL.read_bytes())
        self.destination = self.root / 'control.cc'

    def test_complete_fixed_output_is_private_and_reused_without_rewrite(self):
        source = self.source.read_bytes()
        first = copier.prepare(self.source, self.destination)
        before = self.destination.stat()
        second = copier.prepare(self.source, self.destination)
        self.assertFalse(first['reused'])
        self.assertTrue(second['reused'])
        self.assertEqual(first['sha256'], copier.OUTPUT_SHA256)
        self.assertEqual((before.st_ino, before.st_mtime_ns),
                         (self.destination.stat().st_ino, self.destination.stat().st_mtime_ns))
        self.assertEqual(stat.S_IMODE(before.st_mode), 0o600)
        self.assertEqual(before.st_nlink, 1)
        self.assertEqual(self.source.read_bytes(), source)
        self.assertEqual(self.destination.read_bytes(), copier.DECLARATION + source.replace(copier.BRANCH, copier.GUARD))

    def test_unknown_source_cannot_create_a_temporary_or_touch_existing_output(self):
        self.source.write_bytes(b'Unexpected source; preserve the previous build.\n')
        self.destination.write_bytes(b'Keep this unexpected output.\n')
        with self.assertRaisesRegex(ValueError, 'source changed'):
            copier.prepare(self.source, self.destination)
        self.assertEqual(self.destination.read_bytes(), b'Keep this unexpected output.\n')
        self.assertEqual(sorted(p.name for p in self.root.iterdir()), ['control.cc', 'source.cc'])

    def test_even_matching_output_is_rejected_when_hardlinked(self):
        copier.prepare(self.source, self.destination)
        alias = self.root / 'protected-copy.cc'
        os.link(self.destination, alias)
        body = alias.read_bytes()
        with self.assertRaisesRegex(ValueError, 'Unsafe existing'):
            copier.prepare(self.source, self.destination)
        self.assertEqual(alias.read_bytes(), body)
        self.assertEqual(self.destination.stat().st_nlink, 2)

    def test_source_and_destination_cannot_alias_the_original_input(self):
        before = self.source.read_bytes()
        with self.assertRaisesRegex(ValueError, 'differs; preserve'):
            copier.prepare(self.source, self.source)
        self.assertEqual(self.source.read_bytes(), before)

    def test_no_open_truncates_a_previous_or_new_file(self):
        real_open = os.open
        flags = []

        def record(path, options, *args, **kwargs):
            flags.append(options)
            return real_open(path, options, *args, **kwargs)

        with patch.object(copier.os, 'open', side_effect=record):
            copier.prepare(self.source, self.destination)
            copier.prepare(self.source, self.destination)
            self.destination.write_bytes(b'Preserve different output.\n')
            with self.assertRaisesRegex(ValueError, 'differs; preserve'):
                copier.prepare(self.source, self.destination)
        self.assertTrue(flags)
        self.assertFalse(any(value & os.O_TRUNC for value in flags))
        self.assertEqual(self.destination.read_bytes(), b'Preserve different output.\n')

    def test_concurrent_destination_is_preserved_without_partial_publication(self):
        real_link = os.link

        def collision(*args, **kwargs):
            self.destination.write_bytes(b'Concurrent output; do not replace.\n')
            return real_link(*args, **kwargs)

        with patch.object(copier.os, 'link', side_effect=collision):
            with self.assertRaisesRegex(ValueError, 'output appeared'):
                copier.prepare(self.source, self.destination)
        self.assertEqual(self.destination.read_bytes(), b'Concurrent output; do not replace.\n')
        self.assertFalse(any(p.name.startswith('.raft-window-control-') for p in self.root.iterdir()))

    def test_failed_private_write_never_publishes_partial_cpp(self):
        real_write = os.write
        calls = 0

        def failed_write(fd, data):
            nonlocal calls
            calls += 1
            if calls == 1:
                return real_write(fd, data[:7])
            raise OSError('Synthetic full filesystem')

        with patch.object(copier.os, 'write', side_effect=failed_write):
            with self.assertRaises(OSError):
                copier.prepare(self.source, self.destination)
        self.assertFalse(self.destination.exists())
        self.assertEqual([p.name for p in self.root.iterdir()], ['source.cc'])

    def test_parent_substitution_is_rejected_and_cannot_redirect_output(self):
        parent = self.root / 'parent'
        parent.mkdir()
        elsewhere = self.root / 'unrelated'
        elsewhere.mkdir()
        destination = parent / 'control.cc'
        real_check = copier.parent_unchanged
        calls = 0

        def replace_parent(path, fd):
            nonlocal calls
            calls += 1
            if calls == 2:
                parent.rename(self.root / 'preserved-parent')
                parent.symlink_to(elsewhere, target_is_directory=True)
            return real_check(path, fd)

        with patch.object(copier, 'parent_unchanged', side_effect=replace_parent):
            with self.assertRaises(OSError):
                copier.prepare(self.source, destination)
        self.assertEqual(list(elsewhere.iterdir()), [])
        self.assertEqual(list((self.root / 'preserved-parent').iterdir()), [])
        self.assertTrue(parent.is_symlink())


if __name__ == '__main__':
    unittest.main()
