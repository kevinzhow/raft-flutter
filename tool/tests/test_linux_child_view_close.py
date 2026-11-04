"""Actual child registration/plugin removal with real GObject retained ownership."""
from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'apps/raft_flutter/linux/runner'
PLUGIN = Path.home() / '.pub-cache/hosted/pub.dev/desktop_multi_window-0.3.1/linux/multi_window_manager.cc'


@unittest.skipUnless(sys.platform == 'linux', 'Linux child-view lifecycle')
class ChildViewClose(unittest.TestCase):
    def execute(self, scenario):
        with tempfile.TemporaryDirectory(prefix='raft-child-view-') as folder:
            work = Path(folder)
            header = ROOT / 'tool/tests/linux_child_view_fixture.h'
            shutil.copy2(header, work / 'desktop_view_close.h')
            shutil.copy2(RUNNER / 'desktop_view_close.cc', work / 'close.cc')
            host = Path(os.environ.get('RAFT_TEST_CHILD_REGISTER', RUNNER / 'my_application.cc')).read_text()
            start = host.index('static void register_child_window(')
            child = host[start:host.index('// Called when first Flutter frame', start)]
            child = child.replace('static void register_child_window(', 'void register_child_window(', 1)
            plugin = PLUGIN.read_text()
            self.assertEqual(hashlib.sha256(PLUGIN.read_bytes()).hexdigest(),
                '0fbfd36d9027b44268b3b5624cd816f5c71536330468c9d9d336a9b385fb87fb')
            start = plugin.index('void MultiWindowManager::ObserveWindowClose(')
            observer = plugin[start:plugin.index('FlutterWindow* MultiWindowManager::GetWindow(', start)]
            (work / 'entry.cc').write_text(f'#include "{header}"\n' + child + observer)
            flags = subprocess.check_output(['pkg-config', '--cflags', '--libs', 'gio-2.0'], text=True).split()
            command = ['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                '-I' + str(work), '-I' + str(header.parent), str(work / 'close.cc'),
                str(work / 'entry.cc'), str(ROOT / 'tool/tests/linux_child_view_fixture.cc'),
                '-o', str(work / 'case'), *flags]
            compiled = subprocess.run(command, capture_output=True, text=True, timeout=30)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            result = subprocess.run([str(work / 'case'), scenario], capture_output=True, text=True, timeout=3)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('ownedEngineGone=1 unrelatedEngineGone=0', result.stdout)

    def test_retained_raster_view_does_not_keep_its_engine_after_child_close(self):
        self.execute('held-raster')

    def test_already_released_view_and_unrelated_window_keep_their_lifetimes(self):
        self.execute('already-released')


if __name__ == '__main__':
    unittest.main()
