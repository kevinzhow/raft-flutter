"""Launcher boundary tests; these do not replace missing-library native E2E."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('optional_system_runtime', TOOL / 'linux_system_runtime.py')
runtime = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runtime)


class OptionalLauncherTests(unittest.TestCase):
    def launch(self, missing=()):
        temporary = tempfile.TemporaryDirectory(prefix='raft optional runtime ')
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        bundle, tools = root / 'bundle', root / 'tools'
        (bundle / 'lib/raft-webview').mkdir(parents=True)
        tools.mkdir()
        for name in ('libflutter_linux_gtk.so', 'libapp.so',
                     'libmedia_kit_video_plugin.so', 'libraft_system_webview_plugin.so',
                     'raft-webview/libraft_system_webview_extension.so',
                     'libunrelated_plugin.so'):
            (bundle / 'lib' / name).write_bytes(b'\x7fELFfixture')
        ldd = tools / 'ldd'
        ldd.write_text('#!' + sys.executable + '\n' +
                       'import json,os,sys\nfrom pathlib import Path\n'
                       'p=Path(sys.argv[1]); name=p.name\n'
                       'with Path(os.environ["PROBES"]).open("a") as out: out.write(name+"\\n")\n'
                       'missing=json.loads(os.environ["MISSING"])\n'
                       'if name in missing: print(missing[name]+" => not found")\n'
                       'else: print("libc.so.6 => /lib/libc.so.6")\n')
        ldd.chmod(0o755)
        runner = bundle / 'raft_flutter'
        runner.write_text('#!' + sys.executable + '\nimport json,sys\n'
                          'print(json.dumps({"started": True, "args":sys.argv[1:]}))\n')
        runner.chmod(0o755)
        launcher = bundle / 'run-raft'
        launcher.write_text(runtime.launcher())
        launcher.chmod(0o755)
        probes = root / 'probes'
        env = dict(os.environ, PATH=str(tools) + ':' + os.defpath,
                   MISSING=json.dumps(dict(missing)), PROBES=str(probes))
        result = subprocess.run([str(launcher), 'raft://fixture', 'space argument'],
                                capture_output=True, text=True, env=env, timeout=5)
        return result, probes.read_text().splitlines()

    def test_webkit_mpv_or_both_missing_do_not_block_core_startup(self):
        webkit = {'libraft_system_webview_plugin.so': 'libwebkit2gtk-4.1.so.0',
                  'libraft_system_webview_extension.so': 'libwebkit2gtk-4.1.so.0'}
        media = {'libmedia_kit_video_plugin.so': 'libmpv.so.2'}
        for missing in (webkit, media, webkit | media):
            with self.subTest(missing=missing):
                result, probes = self.launch(missing.items())
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout),
                                 {'started': True, 'args': ['raft://fixture', 'space argument']})
                self.assertIn('raft_flutter', probes)
                self.assertIn('libflutter_linux_gtk.so', probes)
                self.assertIn('libunrelated_plugin.so', probes)
                self.assertNotIn('libraft_system_webview_plugin.so', probes)
                self.assertNotIn('libmedia_kit_video_plugin.so', probes)
                self.assertNotIn('libraft_system_webview_extension.so', probes)

    def test_core_or_an_unrelated_plugin_missing_is_still_fatal(self):
        for name, dependency in (('raft_flutter', 'libgtk-3.so.0'),
                                 ('libflutter_linux_gtk.so', 'libstdc++.so.6'),
                                 ('libunrelated_plugin.so', 'libsecret-1.so.0')):
            with self.subTest(name=name):
                result, probes = self.launch([(name, dependency)])
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertIn(dependency + ' => not found', result.stderr)
                self.assertIn(name, probes)

    def test_core_direct_links_to_backends_or_optional_system_abis_are_rejected(self):
        for name in ('raft_flutter', 'libflutter_linux_gtk.so', 'libunrelated_plugin.so'):
            for needed in ('libwebkit2gtk-4.1.so.0', 'libmpv.so.2',
                           'libjavascriptcoregtk-4.1.so.0', 'libsoup-3.0.so.0',
                           'libraft_system_webview_plugin.so', 'libmedia_kit_video_plugin.so'):
                with self.subTest(name=name, needed=needed):
                    with self.assertRaisesRegex(ValueError, 'Core ELF.*optional'):
                        runtime.verify_linked_system_abi(name, 'libgtk-3.so.0\n' + needed)

    def test_real_backends_still_need_their_declared_distribution_abi(self):
        for plugin, needed in runtime.LINKED_SYSTEM_ABIS.items():
            runtime.verify_linked_system_abi(plugin, needed)
            with self.assertRaisesRegex(ValueError, needed):
                runtime.verify_linked_system_abi(plugin, 'libgtk-3.so.0')
        for path in ('raft_flutter', 'libraft_system_webview_plugin.so'):
            with self.assertRaisesRegex(ValueError, 'WPE'):
                runtime.verify_linked_system_abi(path, 'libwebkit2gtk-4.1.so.0\nlibWPEWebKit-2.0.so.1')


if __name__ == '__main__':
    unittest.main()
