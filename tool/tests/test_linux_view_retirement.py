"""Real locked GMutex and GObject lifecycle; does not substitute native GTK QA."""
from pathlib import Path
import os
import resource
import shutil
import subprocess
import sys
import tempfile
import unittest
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
ROOT=Path(__file__).resolve().parents[2]
RUNNER=ROOT/'apps/raft_flutter/linux/runner'
@unittest.skipUnless(sys.platform=='linux','Linux view lifetime')
class ViewRetirement(unittest.TestCase):
 def execute(self,scenario):
  with tempfile.TemporaryDirectory(prefix='raft-render-retirement-') as directory:
   work=Path(directory);fixture=ROOT/'tool/tests/linux_view_retirement_fixture.h'
   shutil.copy2(fixture,work/'desktop_view_retirement.h')
   shutil.copy2(RUNNER/'desktop_view_retirement.cc',work/'retirement.cc')
   production=Path(os.environ.get('RAFT_TEST_TRACK_WINDOW_SOURCE',RUNNER/'shared_egl_display.cc')).read_text()
   start=production.index('void raft_desktop_track_window(')
   entry=production[start:production.index('bool raft_desktop_finish_quit()',start)]
   (work/'entry.cc').write_text('#include "desktop_view_retirement.h"\n'+entry)
   flags=subprocess.check_output(['pkg-config','--cflags','--libs','gio-2.0'],text=True).split()
   command=['c++','-std=c++17','-Wall','-Wextra','-Werror','-pthread','-I'+str(work),'-I'+str(fixture.parent),str(work/'retirement.cc'),str(work/'entry.cc'),str(ROOT/'tool/tests/linux_view_retirement_fixture.cc'),'-o',str(work/'case'),*flags]
   compiled=subprocess.run(command,capture_output=True,text=True,timeout=30)
   self.assertEqual(compiled.returncode,0,compiled.stdout+compiled.stderr)
   result=subprocess.run([str(work/'case'),scenario],capture_output=True,text=True,timeout=3)
   self.assertEqual(result.returncode,0,result.stdout+result.stderr)
   self.assertIn('engineWeakRetired=1 rendererFinalized=1 unrelatedDisposed=0',result.stdout)
 def test_main_thread_engine_retirement_releases_only_disposed_own_children(self):self.execute('main-retirement')
 def test_worker_engine_retirement_queues_finalization_back_to_main(self):self.execute('worker-retirement')
if __name__=='__main__':unittest.main()
