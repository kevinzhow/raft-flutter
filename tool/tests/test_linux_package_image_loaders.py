"""Normal production run-raft must select its matching packaged image loaders."""
from contextlib import ExitStack
import hashlib
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('release', Path(__file__).resolve().parents[1] / 'release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
appimage = release.tool_module('appimage')


class LinuxPackageImageLoadersTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='raft linux package-日本語-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.app = self.root / 'input-app'
        self.source = self.app / 'build/linux/x64/release/bundle'
        for name in ['raft_flutter', 'lib/libmpv.so.2', 'lib/libmedia_kit_video_plugin.so',
                     'lib/libpixbufloader-svg.so']:
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'\x7fELF controlled packaging fixture')
        notices = self.source / 'data/notices/raft-media'
        notices.mkdir(parents=True)
        (notices / 'librsvg2-common_amd64.copyright').write_text('Synthetic license fixture')
        module = self.source / 'lib/libpixbufloader-svg.so'
        self.manifest = {'libraries': [{'library': module.name, 'package': 'librsvg2-common:amd64',
                         'sha256': hashlib.sha256(module.read_bytes()).hexdigest()}],
                         'imageLoaderModules': [module.name]}
        self.manifest_path = notices / 'manifest.json'
        self.manifest_path.write_text(json.dumps(self.manifest))
        desktop = self.source / 'data/applications/app.raft.raft_flutter.fixture.desktop'
        desktop.parent.mkdir(parents=True)
        desktop.write_text('[Desktop Entry]\nExec=raft_flutter %u\n')
        self.stage = self.root / 'relocated package'
        self.query_calls = []
        self.query_output = None

    def package(self):
        def runtime(stage):
            (stage / 'libexec/raft-html-webview').mkdir(parents=True)
            return {'manifestSha256': 'a' * 64}

        payload = SimpleNamespace(optional_runtime=runtime,
                                  relative_rpath=lambda path, stage: '$ORIGIN',
                                  record_packaged=lambda *args: None,
                                  LAUNCH_VARIABLES=(),
                                  launch_environment=lambda *args: 'export GIO_MODULE_DIR="$app_dir/lib/gio/modules"\n')

        def tool(name):
            return {'html_webview.payload': payload, 'appimage': appimage}[name]

        def query(args, **kwargs):
            self.query_calls.append((args, kwargs))
            if self.query_output is not None:
                return self.query_output
            return '\n'.join('# query metadata\n"' + str(path) + '"\n"svg" 5 "gdk-pixbuf" "SVG" "LGPL"\n'
                             for path in args[1:])

        with ExitStack() as stack:
            stack.enter_context(patch.object(release, 'APP', self.app))
            stack.enter_context(patch.object(release, 'tool_module', side_effect=tool))
            stack.enter_context(patch.object(release, 'capture', return_value=''))
            stack.enter_context(patch.object(release, 'run'))
            stack.enter_context(patch.object(release, 'copy_docs'))
            stack.enter_context(patch.object(release.subprocess, 'check_output', return_value=''))
            stack.enter_context(patch.object(appimage, 'capture', side_effect=query))
            stack.enter_context(patch.dict(release.os.environ,
                                {'LD_LIBRARY_PATH': '/host/lib', 'LD_PRELOAD': '/host/inject.so',
                                 'GDK_PIXBUF_MODULE_FILE': '/host/loaders.cache'}, clear=True))
            release.linux_package(self.stage, suffix='.fixture')

    def test_normal_production_wrapper_selects_verified_packaged_svg_loader(self):
        self.package()
        cache = self.stage / 'lib/loaders.cache'
        self.assertTrue(cache.is_file(), 'Normal linux_package omitted the matching image-loader cache')
        self.assertIn('"libpixbufloader-svg.so"', cache.read_text())
        self.assertNotIn(str(self.stage), cache.read_text())
        wrapper = (self.stage / 'run-raft').read_text()
        self.assertIn('export GDK_PIXBUF_MODULE_FILE="$app_dir/lib/loaders.cache"', wrapper)
        self.assertIn('RAFT_APPIMAGE_HOST_GDK_PIXBUF_MODULE_FILE', wrapper)
        desktop_helper = (self.stage / 'libexec/raft-html-webview/raft-gio-launch-desktop').read_text()
        self.assertIn('unset GDK_PIXBUF_MODULE_FILE', desktop_helper)
        self.assertEqual(self.query_calls[0][0][1:], [self.stage / 'lib/libpixbufloader-svg.so'])
        self.assertNotIn('LD_LIBRARY_PATH', self.query_calls[0][1]['env'])
        self.assertNotIn('LD_PRELOAD', self.query_calls[0][1]['env'])

    def test_incomplete_real_query_metadata_fails_packaging(self):
        self.query_output = ''
        with self.assertRaisesRegex(ValueError, 'Image loader cache'):
            self.package()

    def test_unproven_module_is_not_queried_or_selected(self):
        self.manifest['imageLoaderModules'] = ['libunproven.so']
        self.manifest_path.write_text(json.dumps(self.manifest))
        with self.assertRaisesRegex(ValueError, 'Image loader'):
            self.package()
        self.assertEqual(self.query_calls, [])

    def test_external_module_path_is_not_queried_or_selected(self):
        self.manifest['imageLoaderModules'] = ['/host/libpixbufloader-svg.so']
        self.manifest_path.write_text(json.dumps(self.manifest))
        with self.assertRaisesRegex(ValueError, 'Image loader'):
            self.package()
        self.assertEqual(self.query_calls, [])

    def test_duplicate_module_records_are_rejected(self):
        self.manifest['imageLoaderModules'] *= 2
        self.manifest_path.write_text(json.dumps(self.manifest))
        with self.assertRaisesRegex(ValueError, 'Image loader'):
            self.package()

    def test_no_declared_loaders_does_not_override_host_loader_configuration(self):
        self.manifest['imageLoaderModules'] = []
        self.manifest_path.write_text(json.dumps(self.manifest))
        self.package()
        self.assertEqual(self.query_calls, [])
        self.assertNotIn('export GDK_PIXBUF_MODULE_FILE=', (self.stage / 'run-raft').read_text())
