"""Native linker/loader regression; no application, display or system install."""
import importlib.util
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'apps/raft_flutter/linux/runner'
ORIGINAL = ROOT / 'apps/raft_flutter/linux/flutter/generated_plugin_registrant.cc'
spec = importlib.util.spec_from_file_location('optional_registrant', RUNNER / 'generate_optional_registrant.py')
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class OptionalRegistrantTests(unittest.TestCase):
    def test_generated_copy_keeps_every_other_plugin_and_original_bytes(self):
        before = ORIGINAL.read_bytes()
        text = generator.generate(before.decode())
        self.assertEqual(ORIGINAL.read_bytes(), before)
        self.assertNotIn('media_kit_video_plugin_register_with_registrar', text)
        self.assertNotIn('raft_system_webview_plugin_register_with_registrar', text)
        calls = re.findall(r'^  ([a-z_]+_register_with_registrar)\(', before.decode(), re.M)
        for call in calls:
            if call not in {'media_kit_video_plugin_register_with_registrar',
                            'raft_system_webview_plugin_register_with_registrar'}:
                self.assertIn(call + '(', text)
        self.assertEqual(text.count('raft_register_optional_linux_plugins(registry);'), 1)

    def test_upstream_registration_drift_fails_instead_of_eager_registration(self):
        with self.assertRaisesRegex(ValueError, 'registration drifted'):
            generator.generate(ORIGINAL.read_text().replace('MediaKitVideoPlugin', 'ChangedVideoPlugin'))


@unittest.skipUnless(sys.platform == 'linux' and shutil.which('cmake') and shutil.which('c++'),
                     'Linux native compiler/CMake required')
class OptionalNativeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='raft-optional-native-')
        cls.folder = Path(cls.temporary.name)
        cls.build = cls.folder / 'build'
        (cls.folder / 'runner').mkdir()
        (cls.folder / 'flutter').mkdir()
        shutil.copy2(RUNNER / 'generate_optional_registrant.py', cls.folder / 'runner')
        shutil.copy2(ORIGINAL, cls.folder / 'flutter')
        (cls.folder / 'dependency.cc').write_text('extern "C" int needed_by_backend() { return 1; }\n')
        for feature, symbol in [('webkit', 'raft_system_webview_plugin_register_with_registrar'),
                                ('mpv', 'media_kit_video_plugin_register_with_registrar')]:
            (cls.folder / (feature + '.cc')).write_text(
                'extern "C" int needed_by_backend();\nstruct _FlPluginRegistrar;\n'
                f'extern "C" void {symbol}(_FlPluginRegistrar* value) '
                '{ *reinterpret_cast<int*>(value) += needed_by_backend(); }\n')
        (cls.folder / 'eager.cc').write_text('''
#include <cstdio>
struct _FlPluginRegistrar;
extern "C" void raft_system_webview_plugin_register_with_registrar(_FlPluginRegistrar*);
int main() { int count=0; std::puts("CORE_STARTED");
  raft_system_webview_plugin_register_with_registrar(reinterpret_cast<_FlPluginRegistrar*>(&count)); }
''')
        (cls.folder / 'core.cc').write_text('''
#include "optional_backend.h"
#include <cstdio>
#include <fstream>
#include <string>
int main(int argc, char** argv) {
  if(argc != 3) return 10;
  std::puts("CORE_STARTED");
  raft::OptionalBackendLoader loader(argv[1]);
  auto missing=loader.Probe("webkit");
  if(missing.available || missing.reason!="dependency_unavailable") return 11;
  std::puts("MISSING_IS_RECOVERABLE");
  std::ifstream input(argv[2],std::ios::binary);
  std::ofstream output(std::string(argv[1])+"/deps/libraft_optional_needed.so",std::ios::binary);
  output << input.rdbuf(); output.close();
  if(!loader.Probe("webkit").available) return 12;
  int first=0,second=0;
  auto registrar=[](int* count){return reinterpret_cast<_FlPluginRegistrar*>(count);};
  {
    raft::EngineBackends engine(loader);
    if(!engine.Ensure("webkit",registrar(&first)).available) return 13;
    engine.Ensure("webkit",registrar(&first));
    if(first!=1 || !engine.Registered("webkit")) return 14;
  }
  raft::EngineBackends other(loader);
  other.Ensure("webkit",registrar(&second));
  other.Ensure("mpv",registrar(&second));
  if(first!=1 || second!=2 || !other.Registered("mpv")) return 15;
  if(loader.Probe("../escape").available) return 16;
  std::puts("RESTORED_WITHOUT_RESTART_EACH_ENGINE_ONCE");
}
''')
        (cls.folder / 'CMakeLists.txt').write_text(f'''
cmake_minimum_required(VERSION 3.24)
project(optional_backend_regression LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 14)
include("{RUNNER / 'optional_plugins.cmake'}")
raft_prepare_optional_registrant(RAFT_PLUGIN_REGISTRANT)
add_library(test_dependency SHARED dependency.cc)
set_target_properties(test_dependency PROPERTIES OUTPUT_NAME raft_optional_needed
  LIBRARY_OUTPUT_DIRECTORY "${{CMAKE_BINARY_DIR}}/staging")
add_library(raft_system_webview_plugin SHARED webkit.cc)
add_library(media_kit_video_plugin SHARED mpv.cc)
foreach(plugin IN ITEMS raft_system_webview_plugin media_kit_video_plugin)
  target_link_libraries(${{plugin}} PRIVATE test_dependency)
  set_target_properties(${{plugin}} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${{CMAKE_BINARY_DIR}}/lib"
    BUILD_WITH_INSTALL_RPATH TRUE INSTALL_RPATH "$ORIGIN/deps")
endforeach()
add_executable(eager_runner eager.cc)
target_link_libraries(eager_runner PRIVATE raft_system_webview_plugin)
add_executable(core_runner core.cc "{RUNNER / 'optional_backend.cc'}")
target_include_directories(core_runner PRIVATE "{RUNNER}")
target_compile_options(core_runner PRIVATE -Wall -Wextra -Werror)
target_link_libraries(core_runner PRIVATE raft_system_webview_plugin media_kit_video_plugin)
raft_unlink_optional_plugins(core_runner)
get_target_property(links core_runner LINK_LIBRARIES)
get_target_property(dependencies core_runner MANUALLY_ADDED_DEPENDENCIES)
file(WRITE "${{CMAKE_BINARY_DIR}}/core-link-contract.txt" "${{links}}\\n${{dependencies}}\\n")
''')
        for command in [['cmake', '-S', str(cls.folder), '-B', str(cls.build)],
                        ['cmake', '--build', str(cls.build), '--parallel', '2']]:
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)

    @classmethod
    def tearDownClass(cls):
        if os.environ.get('RAFT_OPTIONAL_TEST_EVIDENCE'):
            shutil.copytree(cls.folder, Path(os.environ['RAFT_OPTIONAL_TEST_EVIDENCE']) / 'native-fixture')
        cls.temporary.cleanup()

    def test_core_linkage_excludes_optional_plugins_but_still_builds_real_targets(self):
        generated = (self.build / 'raft_generated_plugin_registrant.cc').read_text()
        self.assertNotIn('media_kit_video_plugin_register_with_registrar', generated)
        self.assertNotIn('raft_system_webview_plugin_register_with_registrar', generated)
        self.assertIn('raft_register_optional_linux_plugins(registry);', generated)
        contract = (self.build / 'core-link-contract.txt').read_text().splitlines()
        self.assertNotIn('raft_system_webview_plugin', contract[0])
        self.assertNotIn('media_kit_video_plugin', contract[0])
        self.assertIn('raft_system_webview_plugin', contract[1])
        self.assertIn('media_kit_video_plugin', contract[1])
        if shutil.which('readelf'):
            core = subprocess.check_output(['readelf', '-d', self.build / 'core_runner'], text=True)
            eager = subprocess.check_output(['readelf', '-d', self.build / 'eager_runner'], text=True)
            self.assertNotIn('libraft_system_webview_plugin.so', core)
            self.assertNotIn('libmedia_kit_video_plugin.so', core)
            self.assertIn('libraft_system_webview_plugin.so', eager)

    def test_missing_dependency_old_eager_startup_fails_core_retries_without_restart(self):
        restored = self.build / 'lib/deps/libraft_optional_needed.so'
        restored.parent.mkdir(exist_ok=True)
        env = dict(os.environ)
        env.pop('LD_LIBRARY_PATH', None)
        env.pop('LD_PRELOAD', None)
        eager = subprocess.run([self.build / 'eager_runner'], env=env, capture_output=True, text=True)
        self.assertNotEqual(eager.returncode, 0)
        self.assertNotIn('CORE_STARTED', eager.stdout)
        self.assertIn('libraft_optional_needed.so', eager.stderr)
        core = subprocess.run([self.build / 'core_runner', self.build / 'lib',
                               self.build / 'staging/libraft_optional_needed.so'],
                              env=env, capture_output=True, text=True, timeout=15)
        if os.environ.get('RAFT_OPTIONAL_TEST_EVIDENCE'):
            import json
            (Path(os.environ['RAFT_OPTIONAL_TEST_EVIDENCE']) / 'eager-vs-lazy.json').write_text(json.dumps({
                'scope': 'Actual ELF fixture using production loader/CMake unlink helper; not the full Flutter runner',
                'eager': {'exit': eager.returncode, 'stdout': eager.stdout, 'stderr': eager.stderr},
                'lazy': {'exit': core.returncode, 'stdout': core.stdout, 'stderr': core.stderr},
            }, indent=2) + '\n')
        self.assertEqual(core.returncode, 0, core.stdout + core.stderr)
        self.assertIn('MISSING_IS_RECOVERABLE', core.stdout)
        self.assertIn('RESTORED_WITHOUT_RESTART_EACH_ENGINE_ONCE', core.stdout)

    def test_coordinator_compiles_with_real_pinned_flutter_headers(self):
        version = '3.47.8'
        sdk = Path.home() / 'flutter-sdks/versions' / version / 'bin/cache/artifacts/engine/linux-x64'
        if not (sdk / 'flutter_linux/flutter_linux.h').is_file() or not shutil.which('pkg-config'):
            self.skipTest('Local pinned Flutter headers/pkg-config unavailable')
        flags = subprocess.run(['pkg-config', '--cflags', 'gtk+-3.0'], capture_output=True, text=True)
        if flags.returncode:
            self.skipTest('Local GTK3 headers unavailable')
        result = subprocess.run(['c++', '-std=c++14', '-Wall', '-Wextra', '-Werror', '-fsyntax-only',
                                 '-I' + str(sdk), *shlex.split(flags.stdout),
                                 str(RUNNER / 'linux_optional_plugins.cc')],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
