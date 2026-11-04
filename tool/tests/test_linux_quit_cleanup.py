"""Actual main entry + production cleanup; real GObject tasks, no GTK App."""
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


@unittest.skipUnless(sys.platform == 'linux', 'Linux global-quit host policy')
class LinuxQuitCleanup(unittest.TestCase):
    def execute(self, scenario):
        with tempfile.TemporaryDirectory(prefix='raft-quit-policy-') as folder:
            work = Path(folder)
            # Copy the real entry unchanged so its quoted headers can use the
            # display-free fixture. Override only this path for the old RED.
            main = Path(os.environ.get('RAFT_TEST_QUIT_MAIN', RUNNER / 'main.cc'))
            shutil.copy2(main, work / 'main.cc')
            shutil.copy2(ROOT / 'tool/tests/linux_quit_fixture.h', work / 'my_application.h')
            (work / 'shared_egl_display.h').write_text(
                'bool raft_desktop_finish_quit();\nbool raft_shared_egl_release();\n')
            flags = subprocess.check_output(['pkg-config', '--cflags', '--libs', 'gio-2.0'], text=True).split()
            command = ['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                '-I' + str(work), '-I' + str(RUNNER), str(work / 'main.cc'),
                str(ROOT / 'tool/tests/linux_quit_fixture.cc'),
                str(RUNNER / 'desktop_quit_cleanup.cc'), '-o', str(work / 'policy'), *flags]
            build = subprocess.run(command, capture_output=True, text=True, timeout=30)
            self.assertEqual(build.returncode, 0, build.stdout + build.stderr)
            return subprocess.run([str(work / 'policy')], capture_output=True, text=True,
                timeout=3, env=dict(os.environ, RAFT_QUIT_SCENARIO=scenario))

    def test_actual_main_disposes_owned_objects_and_drains_queued_completion(self):
        result = self.execute('queued')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('windows=0 views=0 engines=0 terminate=1', result.stdout)
        self.assertIn('late create rejected', result.stdout)

    def test_held_engine_still_fails_instead_of_erasing_the_counter(self):
        result = self.execute('held')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('engines=1 terminate=0', result.stdout)
        self.assertIn('bounded held-engine failure', result.stdout)

    def test_cleanup_is_only_after_run_and_before_app_unref(self):
        source = (RUNNER / 'main.cc').read_text()
        self.assertLess(source.index('g_application_run('), source.index('raft_desktop_finish_quit()'))
        self.assertLess(source.index('raft_desktop_finish_quit()'), source.index('g_clear_object(&app)'))
        self.assertLess(source.index('g_clear_object(&app)'), source.index('raft_shared_egl_release()'))
        source = (RUNNER / 'shared_egl_display.cc').read_text()
        self.assertIn('g_main_context_default(), 2 * G_USEC_PER_SEC', source)
        self.assertIn('return owned_windows.accepting()', source)
        host = (RUNNER / 'my_application.cc').read_text()
        close = host[host.index('static void desktop_close_reply('):
                     host.index('static void register_window_channels(')]
        # Exact existing child Close / draft-veto callbacks remain unchanged.
        self.assertEqual(hashlib.sha256(close.encode()).hexdigest(),
            'ae6dca32e2b2c9e3797330287f5cb902848d6040eec98183ad2925d9d2a33fa4')


if __name__ == '__main__':
    unittest.main()
