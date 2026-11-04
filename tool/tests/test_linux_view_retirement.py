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
 def execute(self,scenario,qa=False):
  with tempfile.TemporaryDirectory(prefix='raft-render-retirement-') as directory:
   work=Path(directory);fixture=ROOT/'tool/tests/linux_view_retirement_fixture.h'
   shutil.copy2(fixture,work/'desktop_view_retirement.h')
   shutil.copy2(Path(os.environ.get('RAFT_TEST_RETIREMENT_SOURCE',RUNNER/'desktop_view_retirement.cc')),work/'retirement.cc')
   production=Path(os.environ.get('RAFT_TEST_TRACK_WINDOW_SOURCE',RUNNER/'shared_egl_display.cc')).read_text()
   start=production.index('void raft_desktop_track_window(')
   entry=production[start:production.index('bool raft_desktop_finish_quit()',start)]
   (work/'entry.cc').write_text('#include "desktop_view_retirement.h"\n'+entry)
   flags=subprocess.check_output(['pkg-config','--cflags','--libs','gio-2.0'],text=True).split()
   command=['c++','-std=c++17','-Wall','-Wextra','-Werror','-pthread','-I'+str(work),'-I'+str(fixture.parent),str(work/'retirement.cc'),str(work/'entry.cc'),str(ROOT/'tool/tests/linux_view_retirement_fixture.cc'),'-o',str(work/'case'),*flags]
   if qa:command.insert(1,'-DRAFT_MULTIWINDOW_QA=1')
   compiled=subprocess.run(command,capture_output=True,text=True,timeout=30)
   self.assertEqual(compiled.returncode,0,compiled.stdout+compiled.stderr)
   result=subprocess.run([str(work/'case'),scenario],capture_output=True,text=True,timeout=3)
   self.assertEqual(result.returncode,0,result.stdout+result.stderr)
   self.assertIn('singleWindowImmediate=1 engineRetired=1 noCleanupPending=1' if scenario=='single-window' else 'engineWeakRetired=1 rendererFinalized=1 unrelatedDisposed=0',result.stdout)
   if qa:
    self.assertLess(result.stderr.index('FIXTURE_ENGINE_WEAK_RETIRED'),result.stderr.index('event=view_child_finalized'))
    self.assertIn('event=view_children_released',result.stderr)
    self.assertIn('children=2 live=0',result.stderr)
 def test_main_thread_engine_retirement_releases_only_disposed_own_children(self):self.execute('main-retirement')
 def test_worker_engine_retirement_queues_finalization_back_to_main(self):self.execute('worker-retirement')
 def test_unused_multiwindow_retains_original_single_window_cleanup(self):self.execute('single-window')
 def test_qa_finalization_receipts_follow_engine_weak_and_real_finalize(self):self.execute('main-retirement',qa=True)
if __name__=='__main__':unittest.main()
