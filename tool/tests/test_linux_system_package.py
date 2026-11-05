"""The production Linux staging entry must keep system ABIs outside the bundle."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

TOOL = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('system_package_release', TOOL / 'release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class SystemLinuxPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'apps/raft_flutter'
        self.bundle = self.app / 'build/linux/x64/release/bundle'
        (self.bundle / 'lib').mkdir(parents=True)
        (self.bundle / 'data/applications').mkdir(parents=True)
        (self.bundle / 'data/applications/app.raft.raft_flutter.desktop').write_text('Exec=old %u\n')
        (self.bundle / 'raft_flutter').write_bytes(b'\x7fELFfixture-runner')
        (self.bundle / 'lib/libflutter_linux_gtk.so').write_bytes(b'\x7fELFfixture-engine')
        (self.bundle / 'lib/libsqlite3.so').write_bytes(b'\x7fELFfixture-private-native-asset')
        # The old entry insists on its previous media ledger. Supplying an empty
        # valid one lets the regression reach its real copy/launcher behavior.
        self.notices = self.bundle / 'data/notices/raft-media'
        self.notices.mkdir(parents=True)
        (self.notices / 'manifest.json').write_text(json.dumps({'libraries': []}))
        self.stage = self.root / 'stage'
        self.commands = []

    def package(self, needed=''):
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'APP', self.app), \
                patch.object(release, 'copy_docs'), patch.object(release, 'run', side_effect=lambda args, **kw: self.commands.append(args)), \
                patch.object(release, 'capture', side_effect=lambda args: needed if '--print-needed' in args else ''), \
                patch.object(release.subprocess, 'check_output', return_value='libc.so.6 => /usr/lib/libc.so.6\n'), \
                patch.dict(os.environ, {}, clear=True):
            release.linux_package(self.stage)

    def test_production_entry_rejects_system_gtk_before_patch_or_probe(self):
        library = self.bundle / 'lib/libglib-2.0.so.0'
        library.write_bytes(b'old-bundled-glib')
        (self.notices / 'glib.copyright').write_text('fixture')
        (self.notices / 'manifest.json').write_text(json.dumps({'libraries': [{
            'library': library.name, 'package': 'glib', 'sha256': hashlib.sha256(library.read_bytes()).hexdigest()}]}))
        with self.assertRaisesRegex(ValueError, 'system|System'):
            self.package()
        self.assertEqual(self.commands, [])

    def test_unused_android_jni_asset_is_omitted_only_after_dependency_check(self):
        jni = self.bundle / 'lib/libdartjni.so'
        jni.write_bytes(b'\x7fELFunused-android-asset')
        self.package()
        self.assertFalse((self.stage / 'lib/libdartjni.so').exists())
        self.assertTrue(jni.exists())

    def test_linux_jni_dependency_is_rejected_instead_of_hiding_a_required_asset(self):
        (self.bundle / 'lib/libdartjni.so').write_bytes(b'\x7fELFrequired')
        with self.assertRaisesRegex(ValueError, 'JNI dependency'):
            self.package(needed='libdartjni.so\n')
        self.assertFalse((self.stage / 'run-raft').exists())

    def test_normal_entry_creates_wrapper_without_private_system_environment(self):
        self.package()
        wrapper = (self.stage / 'run-raft').read_text()
        self.assertIn('exec "$app_dir/raft_flutter" "$@"', wrapper)
        for key in ('LD_LIBRARY_PATH', 'GIO_MODULE_DIR', 'GSETTINGS_SCHEMA_DIR',
                    'GDK_PIXBUF_MODULE_FILE', 'GST_PLUGIN', 'RAFT_HTML_WEBVIEW_SDK'):
            self.assertNotIn('export ' + key, wrapper)
        self.assertFalse(any('--force-rpath' in cmd for cmd in self.commands))
        receipt = json.loads((self.stage / 'linux-system-runtime.json').read_text())
        self.assertEqual(receipt['policy'], 'system-gtk3-webkitgtk-4.1-v1')
        self.assertEqual(receipt['bundledSystemLibraries'], [])
        self.assertIn('libsqlite3.so', receipt['appPrivateLibraries'])


if __name__ == '__main__':
    unittest.main()
