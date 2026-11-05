"""Thin packages preserve a coherent host ABI and host child environment."""
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('system_runtime_test', TOOL / 'linux_system_runtime.py')
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class SystemRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='raft system runtime ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / 'payload'
        (self.bundle / 'lib').mkdir(parents=True)
        (self.bundle / 'raft_flutter').write_bytes(b'\x7fELFrunner')

    def test_inventory_keeps_app_engine_plugins_and_private_sqlite(self):
        names = ['libflutter_linux_gtk.so', 'libapp.so', 'libsqlite3.so',
                 'libraft_system_webview_plugin.so', 'libmedia_kit_video_plugin.so']
        for name in names:
            (self.bundle / 'lib' / name).write_bytes(b'\x7fELFowned')
        extension = self.bundle / 'lib/raft-webview/libraft_system_webview_extension.so'
        extension.parent.mkdir()
        extension.write_bytes(b'\x7fELFextension')
        libraries, files = runtime.inventory(self.bundle)
        self.assertEqual(libraries, sorted([*names, 'raft-webview/libraft_system_webview_extension.so']))
        self.assertEqual(len(files), 7)
        self.assertEqual(runtime.rpath(files[0], self.bundle), '$ORIGIN')
        self.assertEqual(runtime.rpath(self.bundle / 'raft_flutter', self.bundle), '$ORIGIN/lib')

    def test_only_exact_native_web_extension_path_is_allowed_and_scoped(self):
        extension = self.bundle / 'lib/raft-webview/libraft_system_webview_extension.so'
        extension.parent.mkdir()
        extension.write_bytes(b'\x7fELFapplication-extension')
        libraries, files = runtime.inventory(self.bundle)
        self.assertIn('raft-webview/libraft_system_webview_extension.so', libraries)
        self.assertIn(extension, files)
        self.assertEqual(runtime.rpath(extension, self.bundle), '$ORIGIN/..')
        extension.rename(extension.with_name('libwebkit2gtk-4.1.so.0'))
        with self.assertRaisesRegex(ValueError, 'must not be bundled'):
            runtime.inventory(self.bundle)

    def test_native_plugin_without_its_required_extension_stops_packaging(self):
        (self.bundle / 'lib/libraft_system_webview_plugin.so').write_bytes(b'\x7fELFplugin')
        with self.assertRaisesRegex(ValueError, 'required native WebExtension'):
            runtime.inventory(self.bundle)

    def test_distribution_abis_and_old_engines_never_enter_bundle(self):
        for name in ['libgtk-3.so.0', 'libglib-2.0.so.0', 'libgio-2.0.so.0',
                     'libwebkit2gtk-4.1.so.0', 'libWPEWebKit-2.0.so.1', 'libmpv.so.2',
                     'libsqlite3.so.0', 'libpcre2-8.so.0', 'libpixbufloader-svg.so',
                     'libflutter_inappwebview_linux_plugin.so', 'libmedia_kit_libs_linux_plugin.so']:
            with self.subTest(name=name):
                library = self.bundle / 'lib' / name
                library.write_bytes(b'\x7fELFforbidden')
                with self.assertRaisesRegex(ValueError, 'must not be bundled'):
                    runtime.inventory(self.bundle)
                library.unlink()

    def test_external_broken_links_and_hidden_helpers_are_rejected(self):
        target = self.bundle / 'lib/libapp.so'
        for destination in ['/etc/passwd', '/missing/fixture']:
            with self.subTest(destination=destination):
                target.symlink_to(destination)
                with self.assertRaisesRegex(ValueError, 'symlink'):
                    runtime.inventory(self.bundle)
                target.unlink()
        for relative, contents in [('bin/pdfinfo', b'\x7fELFhelper'),
                                   ('data/notices/raft-html-webview/manifest.json', b'{}'),
                                   ('data/lib-fallback/record', b''), ('data/loaders.cache', b'cache')]:
            path = self.bundle / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(contents)
            with self.assertRaises(ValueError):
                runtime.inventory(self.bundle)
            path.unlink()

    def launch(self, listing='libc.so.6 => /lib/libc.so.6', ldd_exit=0, *, plugin_failure=False):
        tools = self.root / 'tools'
        tools.mkdir()
        ldd = tools / 'ldd'
        plugin_check = ('case \"$1\" in */lib/libmedia_kit_video_plugin.so) printf \"%s\\n\" \"libmpv.so.2 => not found\"; exit 0;; esac\n' if plugin_failure else '')
        ldd.write_text('#!/bin/sh\n' + plugin_check + 'printf "%s\\n" ' + shlex.quote(listing) + '\nexit ' + str(ldd_exit) + '\n')
        ldd.chmod(0o755)
        if plugin_failure:
            (self.bundle / 'lib/libmedia_kit_video_plugin.so').write_bytes(b'\x7fELFdynamic-plugin')
        app = self.bundle / 'raft_flutter'
        app.write_text('#!' + sys.executable + '\nimport json,os,sys\nprint(json.dumps({"args":sys.argv[1:], "environment":dict(os.environ)}))\n')
        app.chmod(0o755)
        wrapper = self.bundle / 'run-raft'
        wrapper.write_text(runtime.launcher())
        wrapper.chmod(0o755)
        env = {'PATH': str(tools) + ':' + os.defpath, 'HOME': str(self.root),
               'GIO_MODULE_DIR': '/distribution modules', 'GDK_PIXBUF_MODULE_FILE': '',
               'GTK_IM_MODULE_FILE': '/chosen/host/cache', 'GSETTINGS_SCHEMA_DIR': '/chosen/schemas'}
        return subprocess.run([str(wrapper), 'a b', 'quote"$', 'raft://fixture'],
                              env=env, capture_output=True, text=True), env

    def test_actual_shell_wrapper_preserves_args_host_values_and_unset_markers(self):
        result, env = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output['args'], ['a b', 'quote"$', 'raft://fixture'])
        for key, value in env.items():
            self.assertEqual(output['environment'][key], value)
        for key in runtime.HOST_LAUNCH_VARIABLES:
            self.assertEqual(output['environment']['RAFT_APPIMAGE_HOST_' + key + '_SET'],
                             'x' if key in env else '')
            self.assertEqual(output['environment']['RAFT_APPIMAGE_HOST_' + key], env.get(key, ''))
        self.assertNotIn('LD_LIBRARY_PATH', output['environment'])
        self.assertNotIn('GIO_LAUNCH_DESKTOP', output['environment'])

    def test_healthy_runner_does_not_hide_missing_dynamically_loaded_media_library(self):
        result, _ = self.launch(plugin_failure=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')
        self.assertIn('libmpv.so.2 => not found', result.stderr)
        self.assertIn('thin Linux package', result.stderr)

    def test_missing_or_incompatible_system_library_blocks_app_with_install_instructions(self):
        for listing, code in [('libwebkit2gtk-4.1.so.0 => not found', 0),
                              ('libc.so.6: version `GLIBC_2.40\' not found', 1)]:
            with self.subTest(listing=listing):
                result, _ = self.launch(listing, code)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertIn('thin Linux package', result.stderr)
                self.assertIn('WebKitGTK4.1', result.stderr)
                self.assertIn(listing, result.stderr)
                (self.root / 'tools/ldd').unlink()
                (self.root / 'tools').rmdir()


if __name__ == '__main__':
    unittest.main()
