"""Exercise the actual native resolver without building or running WebKit."""
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HEADER = ROOT / 'tool/html_webview/raft_wpe_runtime_paths.h'
SONAME = 'libWPEWebKit-2.0.so.1'
WEB_PROCESS = 'libexec/wpe-webkit-2.0/WPEWebProcess'
INJECTED = 'lib/wpe-webkit-2.0/injected-bundle/libWPEInjectedBundle.so'
MARKER = 'share/raft-html-webview/runtime.marker'
HELPERS = (WEB_PROCESS, 'libexec/wpe-webkit-2.0/WPENetworkProcess',
           'libexec/wpe-webkit-2.0/WPEGPUProcess',
           'libexec/raft-html-webview/xdg-dbus-proxy')
IDENTITY = ('raft-html-wpe-runtime-v1\n'
            'wpewebkit=2.54.2\n'
            'source-sha256=f3284e19e47fcb5ac8c63c2e1c113dbd65b2423eb8a545f5b345707829004f56\n'
            'relocation=raft-v1\n'
            f'arch={platform.machine()}\n')
PROBE = '''import ctypes,json,sys
library=ctypes.CDLL(sys.argv[1])
library.qa_path.argtypes=[ctypes.c_char_p]
library.qa_path.restype=ctypes.c_char_p
library.qa_bubblewrap.restype=ctypes.c_char_p
library.qa_trusted.argtypes=[ctypes.c_char_p]
library.qa_trusted.restype=ctypes.c_bool
if sys.argv[2]=='@trusted':
 print(json.dumps([library.qa_trusted(path.encode()) for path in sys.argv[3:]]))
else:
 print(json.dumps([(library.qa_bubblewrap() if path=='@bubblewrap' else
                    library.qa_path(path.encode())).decode() for path in sys.argv[2:]]))
'''


@unittest.skipUnless(sys.platform == 'linux', 'The WPE adapter is Linux only')
class HtmlWebviewRuntimeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        compiler = shutil.which('clang++') or shutil.which('g++')
        if not compiler or not shutil.which('pkg-config'):
            raise unittest.SkipTest('A C++ compiler and GLib development files are required')
        flags = subprocess.run(['pkg-config', '--cflags', '--libs', 'glib-2.0'],
                               text=True, capture_output=True)
        if flags.returncode:
            raise unittest.SkipTest('GLib development files are required')
        cls.compiled = tempfile.TemporaryDirectory(prefix='raft-wpe-resolver-')
        folder = Path(cls.compiled.name)
        source = folder / 'probe.cc'
        source.write_text('#include "raft_wpe_runtime_paths.h"\n'
                          'extern "C" __attribute__((visibility("default")))\n'
                          'const char* qa_path(const char* relative) {\n'
                          '  static std::string result;\n'
                          '  result = RaftWPE::Runtime::current().path(relative);\n'
                          '  return result.c_str();\n}\n'
                          'extern "C" __attribute__((visibility("default")))\n'
                          'const char* qa_bubblewrap() {\n'
                          '  static std::string result = RaftWPE::Runtime::current().bubblewrap();\n'
                          '  return result.c_str();\n}\n'
                          'extern "C" __attribute__((visibility("default")))\n'
                          'bool qa_trusted(const char* path) {\n'
                          '  return RaftWPE::trustedSystemExecutable(path);\n}\n')
        cls.library = folder / SONAME
        result = subprocess.run([compiler, '-std=c++17', '-shared', '-fPIC',
                                 '-fvisibility=hidden', '-O0', '-I', str(HEADER.parent),
                                 str(source), '-Wl,-soname,' + SONAME, '-o', str(cls.library),
                                 *shlex.split(flags.stdout), '-ldl'], text=True, capture_output=True)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.compiled.cleanup()

    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='raft wpe bundle-日本語-')
        self.addCleanup(self.folder.cleanup)
        self.prefix = Path(self.folder.name)
        (self.prefix / 'lib').mkdir()
        shutil.copy2(self.library, self.prefix / 'lib' / SONAME)
        for relative in HELPERS:
            path = self.prefix / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2('/bin/true', path)
        path = self.prefix / INJECTED
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b'non-executed injected-bundle fixture')
        marker = self.prefix / MARKER
        marker.parent.mkdir(parents=True)
        marker.write_text(IDENTITY)

    def probe(self, *paths, environment=None):
        env = os.environ.copy()
        env.update(environment or {})
        result = subprocess.run([sys.executable, '-c', PROBE,
                                 str(self.prefix / 'lib' / SONAME), *paths],
                                env=env, cwd='/', capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def assert_disabled(self):
        self.assertEqual(self.probe(WEB_PROCESS, 'lib', 'share', INJECTED, '@bubblewrap'), [''] * 5)

    def test_relocated_bundle_with_spaces_and_unicode_resolves_every_role(self):
        roles = (*HELPERS, INJECTED, 'lib', 'share')
        self.assertEqual(self.probe(*roles), [str(self.prefix / path) for path in roles])

    def test_missing_marker_disables_all_roles(self):
        (self.prefix / MARKER).unlink()
        self.assert_disabled()

    def test_marker_engine_source_and_architecture_must_match_exactly(self):
        for old, new in [('2.54.2', '2.48.3'), ('f3284e19', '00000000'),
                         (platform.machine(), 'unknown'), ('raft-v1', 'raft-v2')]:
            with self.subTest(identity=old):
                (self.prefix / MARKER).write_text(IDENTITY.replace(old, new))
                self.assert_disabled()

    def test_appended_or_truncated_marker_fails_closed(self):
        for content in [IDENTITY + 'unexpected\n', IDENTITY[:-1]]:
            with self.subTest(length=len(content)):
                (self.prefix / MARKER).write_text(content)
                self.assert_disabled()

    def test_marker_symlink_is_rejected(self):
        marker = self.prefix / MARKER
        marker.unlink()
        alternate = self.prefix / 'alternate.marker'
        alternate.write_text(IDENTITY)
        marker.symlink_to(alternate)
        self.assert_disabled()

    def test_marker_fifo_is_rejected_without_blocking(self):
        marker = self.prefix / MARKER
        marker.unlink()
        os.mkfifo(marker)
        self.assert_disabled()

    def test_each_missing_helper_or_injected_bundle_disables_all_roles(self):
        for relative in (*HELPERS, INJECTED):
            with self.subTest(role=relative):
                path = self.prefix / relative
                backup = path.with_suffix('.saved')
                path.rename(backup)
                self.assert_disabled()
                backup.rename(path)

    def test_non_executable_helper_is_rejected(self):
        (self.prefix / WEB_PROCESS).chmod(0o644)
        self.assert_disabled()

    def test_helper_symlink_cannot_escape_bundle(self):
        helper = self.prefix / WEB_PROCESS
        helper.unlink()
        helper.symlink_to('/bin/true')
        self.assert_disabled()

    def test_data_directory_symlink_cannot_escape_bundle(self):
        data = self.prefix / 'share'
        data.rename(self.prefix / 'old-share')
        with tempfile.TemporaryDirectory() as external:
            data.symlink_to(external, target_is_directory=True)
            self.assert_disabled()

    def test_loaded_library_identity_cannot_come_from_another_prefix(self):
        path = self.prefix / 'lib' / SONAME
        path.unlink()
        path.symlink_to(self.library)
        self.assert_disabled()

    def test_environment_cannot_replace_invalid_bundle_or_select_helpers(self):
        (self.prefix / MARKER).unlink()
        self.assertEqual(self.probe(WEB_PROCESS, INJECTED, environment={
            'WEBKIT_EXEC_PATH': '/bin', 'WEBKIT_INJECTED_BUNDLE_PATH': '/tmp',
        }), ['', ''])

    def test_paths_reject_absolute_and_parent_traversal(self):
        self.assertEqual(self.probe('/etc/passwd', '../outside', 'lib/../outside',
                                    'lib/./unsafe', 'lib//unsafe', '', 'lib/'), [''] * 7)

    def test_bubblewrap_uses_fixed_system_path_instead_of_a_bundle_copy(self):
        rogue = self.prefix / 'libexec/raft-html-webview/bwrap'
        rogue.write_text('not an allowed sandbox executable')
        self.assertEqual(self.probe('@bubblewrap'), ['/usr/bin/bwrap'])

    def test_system_executable_requires_canonical_root_owned_protected_paths(self):
        copied = self.prefix / 'bwrap'
        shutil.copy2('/usr/bin/bwrap', copied)
        linked = self.prefix / 'linked-bwrap'
        linked.symlink_to('/usr/bin/bwrap')
        self.assertEqual(self.probe('@trusted', '/usr/bin/bwrap', str(copied),
                                    str(linked), '/usr/bin/../bin/bwrap',
                                    '/missing-bwrap'), [True, False, False, False, False])

    def test_root_owned_container_fixtures_cover_permissions_and_file_types(self):
        folder = os.environ.get('RAFT_WPE_ROOT_FIXTURES')
        if not folder:
            self.skipTest('Owned container root fixtures were not supplied')
        names = ['good', 'writable', 'unowned', 'script', 'wrong-elf',
                 'symlink', 'not-executable', 'writable-parent/good', 'fifo']
        self.assertEqual(self.probe('@trusted', *(str(Path(folder) / name) for name in names)),
                         [True] + [False] * (len(names) - 1))


if __name__ == '__main__':
    unittest.main()
