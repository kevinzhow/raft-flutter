import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'windows_dependencies', Path(__file__).resolve().parents[1] / 'windows_dependencies.py')
dependencies = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dependencies)


def pe(imports=(), delayed=()):
    """A minimal PE32+ image with one section holding its import tables."""
    section_rva, section_raw = 0x1000, 0x200
    body = bytearray(0x400)
    names_at = 0x200
    names = {}
    for name in [*imports, *delayed]:
        names[name] = section_rva + names_at
        encoded = name.encode() + b'\0'
        body[names_at:names_at + len(encoded)] = encoded
        names_at += len(encoded)
    for index, name in enumerate(imports):  # import descriptors at +0x000
        struct.pack_into('<I', body, 20 * index + 12, names[name])
    for index, name in enumerate(delayed):  # delay descriptors at +0x100
        struct.pack_into('<I', body, 0x100 + 32 * index + 4, names[name])
    optional = bytearray(240)
    struct.pack_into('<H', optional, 0, 0x20b)
    struct.pack_into('<I', optional, 112 + 8 * 1, section_rva if imports else 0)
    struct.pack_into('<I', optional, 112 + 8 * 13, section_rva + 0x100 if delayed else 0)
    header = bytearray(0x80)
    header[:2] = b'MZ'
    struct.pack_into('<I', header, 0x3c, 0x80)
    coff = b'PE\0\0' + struct.pack('<HHIIIHH', 0x8664, 1, 0, 0, 0, len(optional), 0x22)
    section = bytearray(40)
    section[:5] = b'.data'
    struct.pack_into('<IIII', section, 8, len(body), section_rva, len(body), section_raw)
    image = bytes(header) + coff + bytes(optional) + bytes(section)
    return image.ljust(section_raw, b'\0') + bytes(body)


class WindowsDependencyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.bundle = Path(temporary.name)

    def write(self, name, data):
        path = self.bundle / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def test_reads_normal_and_delay_load_imports(self):
        self.assertEqual(dependencies.pe_imports(pe(['KERNEL32.dll'], ['dwmapi.dll'])),
                         {'KERNEL32.dll', 'dwmapi.dll'})
        self.assertIsNone(dependencies.pe_imports(b'not a pe file'))

    def test_shipped_system_and_api_set_imports_pass(self):
        self.write('raft_flutter.exe', pe(['flutter_windows.dll', 'MSVCP140.dll', 'USER32.dll',
                                           'api-ms-win-core-file-l1-1-0.dll']))
        self.write('flutter_windows.dll', pe(['KERNEL32.dll']))
        self.write('msvcp140.dll', pe(['KERNEL32.dll']))
        self.write('data/app.so', b'not a pe image')
        self.assertEqual(dependencies.audit(self.bundle), {})
        dependencies.check(self.bundle)

    def test_missing_msvc_runtime_is_reported_with_its_importers(self):
        # v1.21.23+7: no app-local CRT, so the app did not start on a clean machine.
        self.write('raft_flutter.exe', pe(['MSVCP140.dll', 'VCRUNTIME140.dll', 'VCRUNTIME140_1.dll']))
        self.write('url_launcher_windows_plugin.dll', pe(['VCRUNTIME140.dll']))
        problems = dependencies.audit(self.bundle)
        self.assertEqual(set(problems), {'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'})
        self.assertEqual(problems['vcruntime140.dll'][1],
                         {'raft_flutter.exe', 'url_launcher_windows_plugin.dll'})
        with self.assertRaisesRegex(ValueError, 'msvcp140.dll: not in the bundle'):
            dependencies.check(self.bundle)

    def test_debug_runtime_fails_even_when_shipped(self):
        self.write('zlib.dll', pe(['VCRUNTIME140D.dll', 'ucrtbased.dll']))
        self.write('vcruntime140d.dll', pe(['KERNEL32.dll']))
        problems = dependencies.audit(self.bundle)
        self.assertEqual(set(problems), {'vcruntime140d.dll', 'ucrtbased.dll'})
        self.assertIn('debug runtime', problems['vcruntime140d.dll'][0])

    def test_unknown_delay_loaded_dll_fails(self):
        self.write('dartjni.dll', pe(delayed=['jvm.dll']))
        self.assertEqual(set(dependencies.audit(self.bundle)), {'jvm.dll'})

    def test_windows_app_runtime_is_not_a_system_dependency_even_for_bootstrap(self):
        self.write('Microsoft.WindowsAppRuntime.Bootstrap.dll', pe(['Microsoft.WindowsAppRuntime.dll']))
        self.assertEqual(dependencies.audit(self.bundle)['microsoft.windowsappruntime.dll'][1],
                         {'Microsoft.WindowsAppRuntime.Bootstrap.dll'})
        self.write('raft_flutter.exe', pe(['Microsoft.WindowsAppRuntime.dll']))
        self.assertEqual(dependencies.audit(self.bundle)['microsoft.windowsappruntime.dll'][1],
                         {'Microsoft.WindowsAppRuntime.Bootstrap.dll', 'raft_flutter.exe'})

    def test_bundling_the_old_runtime_does_not_hide_its_reintroduction(self):
        self.write('Microsoft.WindowsAppRuntime.Bootstrap.dll', pe(['KERNEL32.dll']))
        self.write('Microsoft.WindowsAppRuntime.dll', pe(['KERNEL32.dll']))
        self.write('raft_flutter.exe', pe(['Microsoft.WindowsAppRuntime.Bootstrap.dll']))
        problems = dependencies.audit(self.bundle)
        self.assertIn('microsoft.windowsappruntime.bootstrap.dll', problems)
        self.assertIn('microsoft.windowsappruntime.dll', problems)

    def test_command_line_exit_codes(self):
        self.write('raft_flutter.exe', pe(['KERNEL32.dll']))
        self.assertEqual(dependencies.main(['windows_dependencies.py', str(self.bundle)]), 0)
        self.write('raft_flutter.exe', pe(['missing.dll']))
        self.assertEqual(dependencies.main(['windows_dependencies.py', str(self.bundle)]), 1)
        self.assertEqual(dependencies.main(['windows_dependencies.py']), 2)


if __name__ == '__main__':
    unittest.main()
