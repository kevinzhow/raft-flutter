"""Run the real thin AppImage packaging entry with synthetic app/tool bytes."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
spec = importlib.util.spec_from_file_location('appimage_system_entry', TOOL / 'appimage.py')
appimage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(appimage)


class AppImageSystemPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.stage = self.root / 'stage'
        (self.stage / 'lib').mkdir(parents=True)
        for name in ['raft_flutter', 'lib/libflutter_linux_gtk.so', 'lib/libsqlite3.so',
                     'lib/libraft_system_webview_plugin.so']:
            (self.stage / name).write_bytes(b'\x7fELFsynthetic')
        extension = self.stage / 'lib/raft-webview/libraft_system_webview_extension.so'
        extension.parent.mkdir()
        extension.write_bytes(b'\x7fELFapplication-extension')
        (self.stage / 'RUN.txt').write_text('fixture instructions')
        desktop = self.stage / 'data/applications' / (appimage.APP_ID + '.desktop')
        desktop.parent.mkdir(parents=True)
        desktop.write_text('Exec=run-raft %u\nIcon=raft\n')
        icon = self.root / 'apps/raft_flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png'
        icon.parent.mkdir(parents=True)
        icon.write_bytes(b'fixture')
        policy = self.root / 'packaging/appimage'
        policy.mkdir(parents=True)
        for name in ['runtime.LICENSE', appimage.BASE_APP_ID + '.metainfo.xml']:
            (policy / name).write_text('fixture')
        (policy / 'tools.json').write_text(json.dumps({'runtime': {'sha256': 'a' * 64},
                                                       'appimagetool': {'sha256': 'b' * 64}}))
        self.artifact = self.root / 'a.AppImage'
        self.commands = []

    def run_command(self, args, **kwargs):
        self.commands.append((args, kwargs))
        if '--appimage-extract-and-run' in args:
            Path(args[-1]).write_bytes(b'fake packaging output')

    def package(self, *, soname='', stub_browser=False):
        def output(command):
            if '--print-needed' in command:
                return '' if stub_browser else 'libwebkit2gtk-4.1.so.0\n'
            return soname if '--print-soname' in command else 'Name: GLIBC_2.39'
        with patch.object(appimage, 'dependencies', return_value={'libc.so.6': Path('/lib/libc.so.6')}), \
                patch.object(appimage, 'download_tool', side_effect=lambda name, record, folder: folder / name):
            return appimage.package(self.stage, self.artifact, self.root,
                                    self.run_command, output, lambda _: 'fixture')

    def test_real_entry_keeps_tool_runtime_update_and_thin_host_contract(self):
        result = self.package()
        self.assertEqual(result['maximumGlibcRequired'], '2.39')
        self.assertEqual(result['systemRuntime']['bundledSystemLibraries'], [])
        self.assertIn('libsqlite3.so', result['systemRuntime']['appPrivateLibraries'])
        self.assertEqual(result['pdfHelpers'], ['system pdfinfo', 'system pdftoppm'])
        appdir = self.root / 'appimage/Raft.AppDir'
        launcher = (appdir / 'AppRun').read_text()
        self.assertIn('exec "$app_dir/raft/' + appimage.EXECUTABLE + '" "$@"', launcher)
        for key in ['LD_LIBRARY_PATH', 'LD_PRELOAD', 'GIO_MODULE_DIR', 'GIO_LAUNCH_DESKTOP',
                    'GDK_PIXBUF_MODULE_FILE', 'GSETTINGS_SCHEMA_DIR']:
            self.assertNotIn('export ' + key + '=', launcher)
        self.assertTrue(all('--force-rpath' not in args for args, _ in self.commands))
        packaging = self.commands[-1][0]
        self.assertIn('--runtime-file', packaging)
        self.assertIn('--updateinformation', packaging)
        self.assertEqual(packaging[packaging.index('--updateinformation') + 1], appimage.OFFICIAL_UPDATE_INFORMATION)
        self.assertTrue(self.artifact.stat().st_mode & 0o111)
        self.assertFalse((appdir / 'raft/bin/pdfinfo').exists())
        self.assertFalse((appdir / 'raft/lib/loaders.cache').exists())

    def test_private_sqlite_must_not_export_the_system_soname(self):
        with self.assertRaisesRegex(ValueError, 'SONAME'):
            self.package(soname='libsqlite3.so.0')
        self.assertFalse(self.artifact.exists())
        self.assertFalse(any('--appimage-extract-and-run' in args for args, _ in self.commands))

    def test_native_extension_has_only_app_runpath_and_cannot_claim_system_soname(self):
        extension = self.stage / 'lib/raft-webview/libraft_system_webview_extension.so'
        result = self.package()
        self.assertTrue(result['systemRuntime']['nativeWebExtension']['installed'])
        self.assertTrue(any(args[:3] == ['patchelf', '--set-rpath', '$ORIGIN/..']
                            for args, _ in self.commands))

    def test_native_extension_cannot_shadow_the_system_soname(self):
        (self.stage / 'lib/libsqlite3.so').unlink()
        extension = self.stage / 'lib/raft-webview/libraft_system_webview_extension.so'
        with self.assertRaisesRegex(ValueError, 'SONAME'):
            self.package(soname='libwebkit2gtk-4.1.so.0')
        self.assertFalse(self.artifact.exists())

    def test_stub_browser_cannot_bypass_appimage_entry_contract(self):
        with self.assertRaisesRegex(ValueError, 'libwebkit2gtk-4.1.so.0'):
            self.package(stub_browser=True)
        self.assertFalse(self.artifact.exists())

    def test_thick_payload_stops_before_native_commands_or_tool_download(self):
        (self.stage / 'lib/libgtk-3.so.0').write_bytes(b'\x7fELFstale')
        with patch.object(appimage, 'download_tool') as download, self.assertRaisesRegex(ValueError, 'must not be bundled'):
            self.package()
        download.assert_not_called()
        self.assertEqual(self.commands, [])


if __name__ == '__main__':
    unittest.main()
