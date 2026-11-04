"""Build-local source adaptation and real pinned control-handler unit tests."""
from pathlib import Path
import hashlib
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADAPTER = ROOT / 'apps/raft_flutter/linux/runner/desktop_window_creation.cmake'
ORIGINAL = Path.home() / '.pub-cache/hosted/pub.dev/desktop_multi_window-0.3.1/linux/desktop_multi_window_plugin.cc'
SHA = 'd473daf57d9ae48a670672b21cbd21258febaf70814c2d2a96f4bd6b10ab3588'


@unittest.skipUnless(sys.platform == 'linux', 'Pinned Linux window-control host')
class LinuxWindowCreationGate(unittest.TestCase):
    def adapt(self, work, original=ORIGINAL):
        script = work / 'adapt.cmake'
        output = work / 'control.cc'
        script.write_text(f'include("{ADAPTER}")\nraft_copy_window_control("{original}" "{output}")\n')
        result = subprocess.run(['cmake', '-P', str(script)], capture_output=True, text=True, timeout=5)
        return result, output

    def test_only_create_branch_changes_and_original_is_immutable(self):
        before = ORIGINAL.read_bytes()
        self.assertEqual(hashlib.sha256(before).hexdigest(), SHA)
        with tempfile.TemporaryDirectory(prefix='raft-create-copy-') as folder:
            result, output = self.adapt(Path(folder))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            text = output.read_text()
            prefix = 'extern "C" bool raft_desktop_window_creation_allowed() __attribute__((weak));\n'
            guard = '''    if (raft_desktop_window_creation_allowed && !raft_desktop_window_creation_allowed()) {
      fl_method_call_respond_error(method_call, "desktop_app_closing",
          "Application is closing.", nullptr, nullptr);
      return;
    }
'''
            self.assertTrue(text.startswith(prefix))
            self.assertEqual(text.count(guard), 1)
            self.assertEqual(text[len(prefix):].replace(guard, '', 1).encode(), before)
        self.assertEqual(ORIGINAL.read_bytes(), before)

    def test_unknown_source_stops_before_creating_a_copy(self):
        with tempfile.TemporaryDirectory(prefix='raft-create-pin-') as folder:
            work = Path(folder); original = work / 'unknown.cc'
            original.write_bytes(ORIGINAL.read_bytes() + b'\n')
            result, output = self.adapt(work, original)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())

    def test_actual_plugin_target_uses_copy_and_only_one_exported_predicate(self):
        with tempfile.TemporaryDirectory(prefix='raft-create-cmake-') as folder:
            work = Path(folder)
            (work / 'runner.cc').write_text('int main() { return 0; }\n')
            (work / 'CMakeLists.txt').write_text(f'''cmake_minimum_required(VERSION 3.13)
project(raft_control_wiring LANGUAGES CXX)
function(apply_standard_settings target)
endfunction()
add_library(flutter INTERFACE)
add_library(PkgConfig::GTK INTERFACE IMPORTED)
add_executable(runner runner.cc)
add_subdirectory("{ORIGINAL.parent}" plugin)
include("{ADAPTER}")
raft_guard_window_creation(runner)
get_target_property(sources desktop_multi_window_plugin SOURCES)
get_target_property(options runner LINK_OPTIONS)
file(WRITE "${{CMAKE_BINARY_DIR}}/wiring.txt" "${{sources}}\n${{options}}\n")
''')
            result = subprocess.run(['cmake', '-S', str(work), '-B', str(work / 'build')],
                capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            sources, options = (work / 'build/wiring.txt').read_text().splitlines()
            self.assertEqual(sources.split(';'), [str(work / 'build/raft_desktop_multi_window_plugin.cc'),
                *[str(ORIGINAL.parent / name) for name in
                  ['multi_window_manager.cc', 'flutter_window.cc', 'window_channel_plugin.cc']]])
            self.assertEqual(options, '-Wl,--export-dynamic-symbol=raft_desktop_window_creation_allowed')
            self.assertEqual(hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(), SHA)

    def test_selective_export_resolves_the_hidden_plugin_weak_predicate(self):
        # Tiny ELF linkage fixture only; no GTK, Flutter engine or App build.
        with tempfile.TemporaryDirectory(prefix='raft-create-link-') as folder:
            work = Path(folder)
            result, patched = self.adapt(work)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            (work / 'plugin.cc').write_text(patched.read_text().splitlines()[0] + '''
extern "C" __attribute__((visibility("default"))) int probe() {
  return raft_desktop_window_creation_allowed ? raft_desktop_window_creation_allowed() : 2;
}
''')
            (work / 'host.cc').write_text('''#include <dlfcn.h>
bool allowed = true;
extern "C" __attribute__((visibility("default"))) bool raft_desktop_window_creation_allowed() { return allowed; }
extern "C" __attribute__((visibility("default"))) bool unrelated_runner_symbol() { return true; }
int main(int argc, char** argv) {
  if (argc != 2) return 1;
  void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) return 2;
  auto probe = reinterpret_cast<int (*)()>(dlsym(library, "probe"));
  if (!probe || probe() != 1) return 3;
  allowed = false;
  if (probe() != 0) return 4;
  return dlclose(library) != 0;
}
''')
            common = ['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-fvisibility=hidden']
            for command in [common + ['-shared', '-fPIC', str(work / 'plugin.cc'), '-o', str(work / 'plugin.so')],
                    common + [str(work / 'host.cc'), '-ldl',
                        '-Wl,--export-dynamic-symbol=raft_desktop_window_creation_allowed', '-o', str(work / 'host')]]:
                result = subprocess.run(command, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(work / 'host'), str(work / 'plugin.so')],
                capture_output=True, text=True, timeout=3)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            symbols = subprocess.check_output(['nm', '-D', '--defined-only', str(work / 'host')], text=True)
            self.assertIn('raft_desktop_window_creation_allowed', symbols)
            self.assertNotIn('unrelated_runner_symbol', symbols)

    def test_queued_create_is_rejected_but_queries_and_window_dispatch_are_unchanged(self):
        with tempfile.TemporaryDirectory(prefix='raft-create-handler-') as folder:
            work = Path(folder)
            result, patched = self.adapt(work)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            text = ORIGINAL.read_text() if os.environ.get('RAFT_TEST_ORIGINAL_CONTROL') else patched.read_text()
            start = text.index('static void desktop_multi_window_plugin_handle_method_call(')
            end = text.index('static void desktop_multi_window_plugin_dispose', start)
            declaration = 'extern "C" bool raft_desktop_window_creation_allowed() __attribute__((weak));\n'
            source = work / 'handler.cc'
            source.write_text(f'#include "{ROOT / "tool/tests/linux_window_control_fixture.h"}"\n'
                + declaration + text[start:end] + '''
bool allow_create=true;
#define CHECK(x) do { if (!(x)) { std::puts("FAIL control oracle: " #x); return 1; } } while(false)
int main() {
  auto* manager=MultiWindowManager::Instance(); DesktopMultiWindowPlugin plugin{&manager->window};
  FlMethodCall normal{"createWindow"}; desktop_multi_window_plugin_handle_method_call(&plugin,&normal);
  CHECK(normal.response==0 && manager->creates==1);
  GMainContext* context=g_main_context_new(); FlMethodCall queued{"createWindow"};
  struct Pending { DesktopMultiWindowPlugin* plugin; FlMethodCall* call; } pending{&plugin,&queued};
  GSource* idle=g_idle_source_new();g_source_set_callback(idle,[](gpointer data)->gboolean {
    auto* p=static_cast<Pending*>(data);desktop_multi_window_plugin_handle_method_call(p->plugin,p->call);return G_SOURCE_REMOVE;
  },&pending,nullptr);g_source_attach(idle,context);g_source_unref(idle);
  allow_create=false;g_main_context_iteration(context,FALSE);g_main_context_unref(context);
  CHECK(queued.response==1 && queued.code=="desktop_app_closing" && manager->creates==1);
  FlMethodCall query{"getAllWindows"};desktop_multi_window_plugin_handle_method_call(&plugin,&query);
  CHECK(query.response==0 && manager->queries==1);
  FlMethodCall hide{"window_hide"};fl_value_set_string_take(&hide.args,"windowId",fl_value_new_string("primary"));
  desktop_multi_window_plugin_handle_method_call(&plugin,&hide);CHECK(hide.response==0 && manager->window.controls==1);
  FlMethodCall definition{"getWindowDefinition"};desktop_multi_window_plugin_handle_method_call(&plugin,&definition);CHECK(definition.response==0);
  std::puts("PASS queued-create fence and untouched original query/window dispatch");
}
''')
            gate = work / 'gate.cc'
            gate.write_text('extern bool allow_create; extern "C" bool raft_desktop_window_creation_allowed() { return allow_create; }\n')
            flags = subprocess.check_output(['pkg-config', '--cflags', '--libs', 'glib-2.0'], text=True).split()
            compiled = subprocess.run(['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                '-Wno-missing-field-initializers', str(source), str(gate), '-o', str(work / 'handler'), *flags],
                capture_output=True, text=True, timeout=30)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            result = subprocess.run([str(work / 'handler')], capture_output=True, text=True, timeout=3)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('PASS queued-create fence', result.stdout)


if __name__ == '__main__':
    unittest.main()
