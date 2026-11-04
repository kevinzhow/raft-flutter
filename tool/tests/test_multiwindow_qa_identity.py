"""Source-policy checks only. These do NOT compile or run a native window."""
import pathlib,re,unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
class NativeMetadataPolicy(unittest.TestCase):
 def test_observer_is_dual_compile_gated_and_ordinary_entry_is_preserved(self):
  cmake=(ROOT/'apps/raft_flutter/linux/runner/CMakeLists.txt').read_text()
  self.assertIn('if("$ENV{RAFT_QA_ENGINE_INSTRUMENTATION}" STREQUAL "1")',cmake)
  self.assertIn('RAFT_MULTIWINDOW_QA=1',cmake)
  dart=(ROOT/'apps/raft_flutter/lib/platform/desktop_window_runtime.dart').read_text()
  self.assertIn("if (const bool.fromEnvironment('RAFT_MULTIWINDOW_QA'))",dart)
  self.assertIn("'qaWindowIdentity', current.windowId",dart)
  self.assertNotIn('arguments)',dart[dart.index('// QA-only metadata;'):dart.index('if (current.arguments.isEmpty)')])
 def test_only_native_metadata_is_recorded_at_the_fixed_owned_path(self):
  source=(ROOT/'apps/raft_flutter/linux/runner/desktop_qa_identity.cc').read_text()
  self.assertIn('"/evidence/engine-identities.jsonl"',source)
  self.assertIn('O_NOFOLLOW',source);self.assertIn('fstat(fd',source)
  self.assertIn('info.st_uid != geteuid()',source)
  self.assertIn('info.st_mode & 0077',source)
  payload=source[source.index('int length = snprintf'):source.index('bool accepted =')]
  for forbidden in ('session','credential','token','arguments','title','content','binding','origin','principal'):
   self.assertNotIn(forbidden,payload.lower())
  self.assertIn('wl_proxy_get_id',source);self.assertIn('fl_view_get_engine',source)
  self.assertIn('engine_finalized',source);self.assertIn('window_destroyed',source)
 def test_mapping_handler_has_no_business_dispatch_and_only_observes_windows(self):
  source=(ROOT/'apps/raft_flutter/linux/runner/my_application.cc').read_text()
  block=source[source.index('"qaWindowIdentity"'):source.index('#endif',source.index('"qaWindowIdentity"'))]
  self.assertIn('raft_qa_register_window_id',block)
  for forbidden in ('gtk_window_close','gtk_window_present','fl_method_channel_invoke','prepareClose','session'):
   self.assertNotIn(forbidden,block)
  self.assertIn('register_window_channels(view, window, title_bar, true);',source)
if __name__=='__main__':unittest.main()
