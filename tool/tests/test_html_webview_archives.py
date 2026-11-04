"""Authentication and notice resolution must fail closed without trusting the host."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from html_webview import archives, fetch_libwpe


class ArchiveAuthenticationTest(unittest.TestCase):
    def test_signed_release_table_uses_full_sha_and_size(self):
        text = 'Origin: Ubuntu\nSHA256:\n ' + 'a' * 64 + ' 42 main/binary-amd64/Packages\nSHA512:\n x\n'
        self.assertEqual(archives.release_checksums(text),
                         {'main/binary-amd64/Packages': ('a' * 64, 42)})

    def test_foreign_origin_and_expired_release_fail(self):
        for text in ['Origin: Other\n',
                     'Origin: Ubuntu\nValid-Until: Thu, 01 Jan 1970 00:00:00 UTC\n']:
            with self.assertRaises(ValueError):
                archives.release_checksums(text)

    def test_no_authenticated_indices_is_an_error(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'No authenticated'):
                archives.authenticate(Path(directory))

    def store(self, directory):
        store = object.__new__(archives.Store)
        store.workspace = Path(directory)
        store.records, store.roots = {}, {}
        return store

    def test_directory_alias_resolves_only_to_another_authenticated_private_tree(self):
        with tempfile.TemporaryDirectory() as directory:
            store = self.store(directory)
            library = Path(directory) / 'library'
            base = Path(directory) / 'base'
            (library / 'usr/share/doc').mkdir(parents=True)
            (base / 'usr/share/doc/gcc-14-base').mkdir(parents=True)
            (library / 'usr/share/doc/libatomic1').symlink_to('gcc-14-base')
            wanted = base / 'usr/share/doc/gcc-14-base/copyright'
            wanted.write_text('retained exact notice')
            key, parent = ('libatomic1', 'x', 'amd64'), ('gcc-14-base', 'x', 'amd64')
            store.records = {key: {}, parent: {}}
            store.roots = {key: library, parent: base}
            self.assertEqual(store.notice(key), wanted)

    def test_missing_notice_has_no_host_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            store = self.store(directory)
            key = ('missing-package', 'x', 'amd64')
            store.records = {key: {}}
            store.roots = {key: Path(directory)}
            with self.assertRaisesRegex(ValueError, 'No authenticated target'):
                store.notice(key)

    def test_absolute_or_parent_notice_alias_is_rejected(self):
        for link in ['/etc', '../../../../../../etc']:
            with self.subTest(link=link), tempfile.TemporaryDirectory() as directory:
                store = self.store(directory)
                root = Path(directory)
                (root / 'usr/share/doc').mkdir(parents=True)
                (root / 'usr/share/doc/malicious').symlink_to(link)
                key = ('malicious', 'x', 'amd64')
                store.records = {key: {}}
                store.roots = {key: root}
                with self.assertRaisesRegex(ValueError, 'leaves the private'):
                    store.notice(key)

    def test_file_escaping_package_root_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            store = self.store(directory)
            root = Path(directory) / 'private'
            root.mkdir()
            secret = Path(directory) / 'outside'
            secret.write_text('not a package')
            (root / 'alias').symlink_to(secret)
            key = ('owned', 'x', 'amd64')
            store.records = {key: {}}
            store.roots = {key: root}
            with self.assertRaisesRegex(ValueError, 'leaves its private'):
                store.file(key, 'alias')

    def test_fixed_libwpe_fetch_rejects_wrong_body_before_writing(self):
        class Response:
            url = 'https://deb.debian.org/example'
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self, limit): return b'not the authenticated archive'
        with tempfile.TemporaryDirectory() as directory, patch.object(
                fetch_libwpe.urllib.request, 'urlopen', return_value=Response()):
            with self.assertRaises(ValueError):
                fetch_libwpe.fetch(directory)
            self.assertEqual(list(Path(directory).iterdir()), [])


if __name__ == '__main__':
    unittest.main()
