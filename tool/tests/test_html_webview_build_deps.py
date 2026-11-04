"""A private configure dependency must preserve package bytes and public host state."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from html_webview import build_deps


class PrivateBuildDepsTest(unittest.TestCase):
    def test_merge_resolves_dev_link_with_runtime_and_rewrites_only_private_pc(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dev, runtime = root / 'dev', root / 'runtime'
            relative = Path('usr/lib/x86_64-linux-gnu')
            (dev / relative / 'pkgconfig').mkdir(parents=True)
            (runtime / relative).mkdir(parents=True)
            pc = dev / relative / 'pkgconfig/gstreamer-mpegts-1.0.pc'
            pc.write_text('prefix=/usr\nlibdir=${prefix}/lib/x86_64-linux-gnu\n'
                          'includedir=${prefix}/include\nName: fixture\nDescription: fixture\n'
                          'Version: 1.24.2\nLibs: -L${libdir} -lgstmpegts-1.0\n')
            (dev / relative / 'libgstmpegts-1.0.so').symlink_to('libgstmpegts-1.0.so.0')
            (runtime / relative / 'libgstmpegts-1.0.so.0').write_bytes(b'fixture runtime, not ELF')
            keys = [(name, '1.24.2-1ubuntu4', 'amd64') for name in build_deps.NAMES]
            class Store:
                records = {key: {'name': key[0], 'version': key[1], 'sha256': 'a' * 64} for key in keys}
                def extract(self, key): return dev if key == keys[0] else runtime
            work = root / 'work'
            work.mkdir()
            before = dict(os.environ)
            env = build_deps.prepare(Store(), work)
            private = work / 'gstreamer-build-deps'
            self.assertEqual((private / relative / 'libgstmpegts-1.0.so').read_bytes(),
                             b'fixture runtime, not ELF')
            self.assertEqual(pc.read_text().splitlines()[0], 'prefix=/usr')
            self.assertEqual((private / relative / 'pkgconfig/gstreamer-mpegts-1.0.pc').read_text().splitlines()[0],
                             'prefix=${pcfiledir}/../../..')
            self.assertEqual(dict(os.environ), before)
            self.assertTrue(env['PKG_CONFIG_PATH'].startswith(str(private)))
            receipt = json.loads((work / 'private-build-deps.json').read_text())
            self.assertEqual(len(receipt['packages']), 2)
            self.assertEqual(receipt['files'][(relative / 'libgstmpegts-1.0.so').as_posix()],
                             {'link': 'libgstmpegts-1.0.so.0'})

    def test_conflicting_package_bytes_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'source').mkdir()
            (root / 'target').mkdir()
            (root / 'source/header').write_text('new')
            (root / 'target/header').write_text('old evidence')
            with self.assertRaisesRegex(ValueError, 'byte collision'):
                build_deps.merge_tree(root / 'source', root / 'target')
            self.assertEqual((root / 'target/header').read_text(), 'old evidence')

    def test_escaping_link_fails_without_installing_a_host_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'source').mkdir()
            (root / 'source/link').symlink_to('../../outside')
            with self.assertRaisesRegex(ValueError, 'leaves its prefix'):
                build_deps.merge_tree(root / 'source', root / 'target')
            self.assertFalse((root / 'outside').exists())

    def test_missing_exact_package_is_not_resolved_through_host_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            class Store:
                records = {}
            with self.assertRaisesRegex(ValueError, 'authenticated exact'):
                build_deps.prepare(Store(), Path(directory))


if __name__ == '__main__':
    unittest.main()
