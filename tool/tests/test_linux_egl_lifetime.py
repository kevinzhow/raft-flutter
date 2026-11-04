"""Small production-policy executable. No window, display, engine or account."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'apps/raft_flutter/linux/runner'


@unittest.skipUnless(sys.platform == 'linux', 'Linux EGL host policy')
class LinuxEglLifetime(unittest.TestCase):
    def test_shared_display_survives_either_engine_close_order(self):
        with tempfile.TemporaryDirectory(prefix='raft-egl-policy-') as folder:
            executable = str(Path(folder) / 'policy')
            result = subprocess.run([
                os.environ.get('CXX', 'c++'), '-std=c++17', '-Wall', '-Wextra',
                '-Werror', '-pthread', '-I' + str(RUNNER),
                str(ROOT / 'tool/tests/linux_egl_termination.cc'),
                str(RUNNER / 'shared_egl_termination.cc'), '-o', executable,
            ], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([executable], capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('PASS shared EGL', result.stdout)

    def test_real_host_tears_down_gtk_before_final_egl_release(self):
        source = (RUNNER / 'main.cc').read_text()
        self.assertLess(source.index('g_application_run('), source.index('g_clear_object(&app)'))
        self.assertLess(source.index('g_clear_object(&app)'), source.index('raft_shared_egl_release()'))
        source = (RUNNER / 'shared_egl_display.cc').read_text()
        self.assertIn('actual_gtk_display != actual_engine_display', source)
        self.assertIn('eglGetCurrentDisplay()', source)
        self.assertIn('eglGetCurrentSurface(EGL_READ)', source)
        self.assertIn('gdk_gl_context_make_current(gdk_)', source)
        self.assertIn('eglMakeCurrent(display_, draw_, read_, context_)', source)
        self.assertNotIn('g_object_ref(engine)', source)


if __name__ == '__main__':
    unittest.main()
