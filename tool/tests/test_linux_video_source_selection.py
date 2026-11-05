"""Configure the unchanged 2.0.1 upstream CMake, without building native code."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'tool/tests/fixtures/media_kit_video-2.0.1'
REAL_SOURCES = {'media_kit_video_plugin.cc', 'texture_gl.cc', 'texture_sw.cc',
                'video_output_manager.cc', 'video_output.cc', 'utils.cc'}


@unittest.skipUnless(shutil.which('cmake') and shutil.which('c++'), 'CMake/C++ compiler required for configure-only contract')
class LinuxVideoSourceSelectionTests(unittest.TestCase):
    def configure(self, *, cached_off=False, missing_mpv=False):
        temporary = tempfile.TemporaryDirectory(prefix='raft-system-video-cmake-')
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        child, modules = root / 'upstream', root / 'modules'
        child.mkdir(); modules.mkdir()
        pins = json.loads((FIXTURE / 'UPSTREAM.json').read_text())['files']
        cmake = (FIXTURE / 'CMakeLists.txt').read_bytes()
        self.assertEqual(hashlib.sha256(cmake).hexdigest(), pins['CMakeLists.txt']['sha256'])
        (child / 'CMakeLists.txt').write_bytes(cmake)
        (child / 'include').mkdir()
        for name in REAL_SOURCES:
            (child / name).write_text('// Configure-only placeholder, never compiled.\n')
        (modules / 'FindPkgConfig.cmake').write_text('''
set(PKG_CONFIG_FOUND TRUE)
function(pkg_check_modules prefix)
  if(prefix STREQUAL "MPV" AND RAFT_TEST_MISSING_MPV)
    message(FATAL_ERROR "Fixture system mpv unavailable")
  endif()
  if(NOT TARGET PkgConfig::${prefix})
    add_library(PkgConfig::${prefix} INTERFACE IMPORTED GLOBAL)
  endif()
endfunction()
''')
        source = (ROOT / 'apps/raft_flutter/linux/CMakeLists.txt').read_text()
        # Execute the production prerequisite block; upstream chooses its own
        # real/stub source list. This fixture never rewrites that upstream list.
        start = source.index('pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)')
        end = source.index('# Run the Flutter tool portions', start)
        production = source[start:end]
        cached = 'set(MEDIA_KIT_LIBS_AVAILABLE OFF CACHE BOOL "old cache value" FORCE)\n' if cached_off else ''
        (root / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.13)
project(raft_source_selection LANGUAGES CXX)
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/modules")
find_package(PkgConfig REQUIRED)
add_library(flutter INTERFACE IMPORTED GLOBAL)
add_library(PkgConfig::GTK INTERFACE IMPORTED GLOBAL)
function(apply_standard_settings target)
endfunction()
''' + cached + production + '''
add_subdirectory(upstream)
get_target_property(sources media_kit_video_plugin SOURCES)
get_target_property(defines media_kit_video_plugin COMPILE_DEFINITIONS)
get_target_property(links media_kit_video_plugin LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/selection.txt" "${sources}\\n${defines}\\n${links}\\n")
''')
        result = subprocess.run(['cmake', '-S', str(root), '-B', str(root / 'build'),
                                 '-DRAFT_TEST_MISSING_MPV=' + ('ON' if missing_mpv else 'OFF')],
                                capture_output=True, text=True, timeout=60)
        selection = root / 'build/selection.txt'
        return result, selection.read_text().splitlines() if selection.exists() else None

    def test_system_mpv_selects_real_video_sources_in_fresh_and_cached_off_configs(self):
        for cached_off in [False, True]:
            with self.subTest(cached_off=cached_off):
                result, selection = self.configure(cached_off=cached_off)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(set(selection[0].split(';')), REAL_SOURCES)
                self.assertNotIn('MEDIA_KIT_LIBS_NOT_FOUND', selection[1])
                self.assertIn('PkgConfig::mpv', selection[2].split(';'))

    def test_missing_system_mpv_stops_before_a_stub_can_be_packaged(self):
        result, selection = self.configure(missing_mpv=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Fixture system mpv unavailable', result.stderr)
        self.assertIsNone(selection)


if __name__ == '__main__':
    unittest.main()
