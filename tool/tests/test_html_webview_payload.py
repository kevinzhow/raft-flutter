"""Payload integrity/archive/packaging regressions; these do not run a renderer."""
import hashlib
import importlib
import io
import json
import os
from pathlib import Path
import sys
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
payload = importlib.import_module('html_webview.payload')


class HtmlPayloadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='raft wpe sdk-日本語-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sdk = self.root / 'sdk'
        self.sdk.mkdir()
        for relative in payload.RUNTIME:
            path = self.sdk / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'\x7fELFfixture-only' if relative in payload.NATIVE_ROLES else b'fixture')
            path.chmod(0o755 if relative.startswith('libexec/') else 0o644)
        meta = self.sdk / payload.METADATA
        (meta / 'source-inputs.json').write_text(json.dumps(payload.identity()))
        (self.sdk / 'lib/gio/modules/giomodule.cache').write_text('libgiognutls.so: gio-tls-backend\n')
        (meta / 'runtime.marker').write_text(
            'raft-html-wpe-runtime-v1\nwpewebkit=2.54.2\n'
            f'source-sha256={payload.ARCHIVE_SHA256}\nrelocation=raft-v1\narch=x86_64\n')
        (meta / 'cmakeconfig.h').write_text('\n'.join([
            '#define ENABLE_BUBBLEWRAP_SANDBOX 1', '#define ENABLE_DEVELOPER_MODE 0',
            '#define ENABLE_GPU_PROCESS 1', '#define ENABLE_WPE_PLATFORM_HEADLESS 1']))
        (meta / 'licenses').mkdir()
        (meta / 'licenses/fixture.txt').write_text('test data only, not a WPE binary/notice')
        (meta / 'packages.json').write_text(json.dumps({'artifacts': [{
            'name': 'wpewebkit', 'version': payload.VERSION, 'sha256': payload.ARCHIVE_SHA256,
            'url': 'https://example.org/fixture', 'notice': payload.METADATA + '/licenses/fixture.txt',
            'files': list(payload.NATIVE_ROLES)}]}))
        for name in payload.PKG_CONFIG:
            path = self.sdk / 'lib/pkgconfig' / (name + '.pc')
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('prefix=${pcfiledir}/../..\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n')
        (self.sdk / 'include').mkdir()
        (self.sdk / 'include/fixture.h').write_text('/* test-only SDK */')
        for path in self.sdk.rglob('*'):
            if path.is_file():
                path.chmod(0o755 if os.access(path, os.X_OK) else 0o644)
        # Only the manifest/integrity logic is under test. Never claim these
        # deliberately synthetic bytes are a compiled browser or GLIBC result.
        with patch.object(payload, 'inspect_elf', return_value='2.39'):
            self.pin = payload.seal(self.sdk)

    def archive(self, entries=None):
        path = self.root / 'sdk.tar'
        with tarfile.open(path, 'w') as tar:
            if entries is None:
                for item in sorted(self.sdk.rglob('*')):
                    tar.add(item, arcname=item.relative_to(self.sdk), recursive=False)
            else:
                for name, kind in entries:
                    info = tarfile.TarInfo(name)
                    if kind == 'link':
                        info.type, info.linkname = tarfile.SYMTYPE, '/outside'
                        tar.addfile(info)
                    elif kind == 'fifo':
                        info.type = tarfile.FIFOTYPE
                        tar.addfile(info)
                    else:
                        info.size = 1
                        tar.addfile(info, io.BytesIO(b'x'))
        return path, hashlib.sha256(path.read_bytes()).hexdigest()

    def test_pinned_archive_restores_complete_sdk_and_manifest(self):
        archive, pin = self.archive()
        destination = self.root / 'restored'
        self.assertEqual(payload.restore(archive, pin, destination), self.pin)
        self.assertEqual(payload.verify(destination, self.pin)['identity'], payload.identity())

    def test_changed_archive_pin_does_not_create_destination(self):
        archive, _ = self.archive()
        destination = self.root / 'not-created'
        with self.assertRaisesRegex(ValueError, 'archive SHA-256'):
            payload.restore(archive, '0' * 64, destination)
        self.assertFalse(destination.exists())

    def test_restore_keeps_previous_directory_and_dangling_symlink(self):
        archive, pin = self.archive()
        for target in [self.sdk, self.root / 'link']:
            if target != self.sdk:
                target.symlink_to('/missing-raft-sdk')
            with self.assertRaisesRegex(ValueError, 'new SDK destination'):
                payload.restore(archive, pin, target)
        self.assertTrue((self.sdk / payload.MANIFEST).is_file())

    def test_duplicate_traversal_special_and_absolute_entries_fail_closed(self):
        for entries in [[('../outside', 'file')], [('/outside', 'file')],
                        [('dup', 'file'), ('dup', 'file')], [('pipe', 'fifo')]]:
            with self.subTest(entries=entries):
                archive, pin = self.archive(entries)
                destination = self.root / 'not-created'
                with self.assertRaises(ValueError):
                    payload.restore(archive, pin, destination)
                self.assertFalse(destination.exists())

    def test_archive_escape_link_cannot_write_outside(self):
        archive, pin = self.archive([('escape', 'link'), ('escape/file', 'file')])
        with self.assertRaises((ValueError, tarfile.FilterError)):
            payload.restore(archive, pin, self.root / 'failed-preserved')
        self.assertFalse((self.root / 'file').exists())

    def test_manifest_pin_and_all_file_bytes_and_modes_are_verified(self):
        with self.assertRaisesRegex(ValueError, 'manifest SHA-256'):
            payload.verify(self.sdk, '0' * 64)
        helper = self.sdk / payload.RUNTIME[2]
        helper.chmod(0o644)
        with self.assertRaisesRegex(ValueError, 'files/permissions'):
            payload.verify(self.sdk, self.pin)
        helper.chmod(0o755)
        helper.write_bytes(b'\x7fELFchanged')
        with self.assertRaisesRegex(ValueError, 'files/permissions'):
            payload.verify(self.sdk, self.pin)

    def test_tls_module_identity_and_unsafe_sandbox_config_are_required(self):
        for relative, content in [
            (payload.METADATA + '/source-inputs.json', '{}'),
            (payload.METADATA + '/cmakeconfig.h', '#define ENABLE_BUBBLEWRAP_SANDBOX 0'),
            (payload.METADATA + '/runtime.marker', 'changed'),
        ]:
            path = self.sdk / relative
            before = path.read_text()
            path.write_text(content)
            with self.assertRaises(ValueError):
                payload.check_layout(self.sdk)
            path.write_text(before)
        (self.sdk / 'lib/gio/modules/libgiognutls.so').unlink()
        with self.assertRaisesRegex(ValueError, 'Incomplete HTML runtime'):
            payload.check_layout(self.sdk)

    def test_bundle_cannot_import_host_base_libraries_or_relocated_bwrap(self):
        for name in ['bwrap', 'libc.so.6', 'ld-linux-x86-64.so.2', 'libstdc++.so.6.0.33',
                     'radeonsi_dri.so', 'libvulkan_radeon.so']:
            path = self.sdk / 'lib' / name
            path.write_text('forbidden')
            path.chmod(0o644)
            with self.assertRaisesRegex(ValueError, 'must not be bundled'):
                payload.inventory(self.sdk)
            path.unlink()

    def test_sdk_symlink_escape_and_missing_package_provenance_are_rejected(self):
        link = self.sdk / 'lib/outside.so'
        link.symlink_to('/bin/true')
        with self.assertRaisesRegex(ValueError, 'Nonrelocatable'):
            payload.inventory(self.sdk)
        link.unlink()
        (self.sdk / payload.METADATA / 'packages.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'source provenance'):
            payload.check_layout(self.sdk)

    def test_system_library_or_bwrap_alias_cannot_bypass_inventory_rejection(self):
        for name in ['bwrap', 'libstdc++.so.6', 'ld-linux-x86-64.so.2']:
            link = self.sdk / 'lib' / name
            link.symlink_to('libWPEWebKit-2.0.so.1')
            with self.assertRaisesRegex(ValueError, 'must not be bundled'):
                payload.inventory(self.sdk)
            link.unlink()

    def test_merge_materializes_library_aliases_and_keeps_sdk_bytes(self):
        (self.sdk / payload.MANIFEST).unlink()
        link = self.sdk / 'lib/fixture.so'
        link.symlink_to('libWPEWebKit-2.0.so.1')
        with patch.object(payload, 'inspect_elf', return_value='2.39'):
            pin = payload.seal(self.sdk)
        stage = self.root / 'stage'
        stage.mkdir()
        record = payload.merge_runtime(self.sdk, stage, pin)
        self.assertFalse((stage / 'lib/fixture.so').is_symlink())
        self.assertFalse((stage / 'include').exists())
        helper = stage / payload.RUNTIME[2]
        helper.write_bytes(b'\x7fELFpatched-rpath')
        payload.record_packaged(stage, record)
        environment = {'RAFT_HTML_WEBVIEW_SDK': str(self.sdk), 'RAFT_HTML_WEBVIEW_MANIFEST_SHA256': pin}
        self.assertEqual(payload.optional_runtime(stage, environment)['manifestSha256'], pin)
        helper.write_bytes(b'\x7fELFunrecorded-change')
        with self.assertRaisesRegex(ValueError, 'differs from its receipt'):
            payload.optional_runtime(stage, environment)
        self.assertEqual(payload.verify(self.sdk, pin)['identity'], payload.identity())

    def test_merge_rejects_existing_different_media_or_plugin_bytes(self):
        stage = self.root / 'stage'
        (stage / 'lib').mkdir(parents=True)
        existing = stage / payload.RUNTIME[0]
        existing.write_bytes(b'existing-media-keep')
        with self.assertRaisesRegex(ValueError, 'collides'):
            payload.merge_runtime(self.sdk, stage, self.pin)
        self.assertEqual(existing.read_bytes(), b'existing-media-keep')

    def test_merge_rejects_destination_parent_symlink_escape(self):
        stage, outside = self.root / 'stage', self.root / 'outside'
        stage.mkdir()
        outside.mkdir()
        (stage / 'lib').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Invalid HTML runtime source/destination'):
            payload.merge_runtime(self.sdk, stage, self.pin)
        self.assertFalse(list(outside.iterdir()))

    def test_packaged_receipt_tracks_only_reviewed_host_va_fallback_relocation(self):
        relative = 'lib/libva.so.2'
        (self.sdk / relative).write_bytes(b'\x7fELFfixture-only')
        (self.sdk / relative).chmod(0o644)
        packages = self.sdk / payload.METADATA / 'packages.json'
        record = json.loads(packages.read_text())
        record['artifacts'][0]['files'].append(relative)
        packages.write_text(json.dumps(record))
        (self.sdk / payload.MANIFEST).unlink()
        with patch.object(payload, 'inspect_elf', return_value='2.39'):
            pin = payload.seal(self.sdk)
        stage = self.root / 'va-stage'
        stage.mkdir()
        record = payload.merge_runtime(self.sdk, stage, pin)
        (stage / 'lib-fallback').mkdir()
        target = 'lib-fallback/libva.so.2'
        (stage / relative).rename(stage / target)
        payload.record_packaged(stage, record, {relative: target})
        environment = {'RAFT_HTML_WEBVIEW_SDK': str(self.sdk), 'RAFT_HTML_WEBVIEW_MANIFEST_SHA256': pin}
        placed = payload.optional_runtime(stage, environment)
        self.assertEqual(placed['files'][target], payload.sha256(stage / target))
        with self.assertRaisesRegex(ValueError, 'reviewed host-VA'):
            payload.record_packaged(stage, record, {relative: '../outside'})

    def test_optional_payload_is_empty_by_default_and_rejects_half_configuration(self):
        self.assertIsNone(payload.optional_runtime(self.root, {}))
        with self.assertRaisesRegex(ValueError, 'Set both'):
            payload.optional_runtime(self.root, {'RAFT_HTML_WEBVIEW_SDK': str(self.sdk)})

    def test_actual_elf_metadata_must_keep_architecture_and_glibc_floor(self):
        with patch.object(payload.subprocess, 'check_output', return_value=(
                'Class: ELF64\nMachine: Advanced Micro Devices X86-64\nName: GLIBC_2.39\n')):
            self.assertEqual(payload.inspect_elf(self.sdk), '2.39')
        with patch.object(payload.subprocess, 'check_output', return_value=(
                'Class: ELF64\nMachine: Advanced Micro Devices X86-64\nName: GLIBC_2.43\n')):
            with self.assertRaisesRegex(ValueError, 'GLIBC 2.39'):
                payload.inspect_elf(self.sdk)
        with patch.object(payload.subprocess, 'check_output', return_value='Machine: AArch64\n'):
            with self.assertRaisesRegex(ValueError, 'x86_64'):
                payload.inspect_elf(self.sdk)

    def test_nested_helpers_modules_and_existing_flat_libraries_find_same_lib_dir(self):
        stage = Path('/tmp/relocated 日本語/raft')
        cases = {'raft_flutter': '$ORIGIN/lib', 'lib/plugin.so': '$ORIGIN',
                 'bin/pdfinfo': '$ORIGIN/../lib',
                 'libexec/wpe-webkit-2.0/WPEWebProcess': '$ORIGIN/../../lib',
                 'lib/wpe-webkit-2.0/injected-bundle/libWPEInjectedBundle.so': '$ORIGIN/../..',
                 'lib/gio/modules/libgiognutls.so': '$ORIGIN/../..'}
        for relative, expected in cases.items():
            self.assertEqual(payload.relative_rpath(stage / relative, stage), expected)

    def test_linux_package_preserves_default_path_and_adds_verified_nested_runtime(self):
        release = importlib.import_module('release')
        app = self.root / 'app'
        source = app / 'build/linux/x64/release/bundle'
        (source / 'lib').mkdir(parents=True)
        libraries = ['libmpv.so.2', 'libmedia_kit_video_plugin.so']
        for name in ['raft_flutter', *('lib/' + name for name in libraries)]:
            (source / name).write_bytes(b'\x7fELFapplication-fixture')
        notices = source / 'data/notices/raft-media'
        notices.mkdir(parents=True)
        (notices / 'fixture.copyright').write_text('test-only')
        (notices / 'manifest.json').write_text(json.dumps({'libraries': [
            {'library': name, 'package': 'fixture', 'sha256': payload.sha256(source / 'lib' / name)}
            for name in libraries]}))
        applications = source / 'data/applications'
        applications.mkdir(parents=True)
        (applications / 'app.raft.raft_flutter.desktop').write_text('Exec=/old/raft_flutter %u\n')
        for enabled in [False, True]:
            stage = self.root / ('with-html' if enabled else 'default')
            environment = ({'RAFT_HTML_WEBVIEW_SDK': str(self.sdk),
                            'RAFT_HTML_WEBVIEW_MANIFEST_SHA256': self.pin} if enabled else {})
            with patch.dict(os.environ, environment, clear=True), patch.object(release, 'APP', app), \
                    patch.object(release, 'run') as run, \
                    patch.object(release, 'capture', return_value=''), \
                    patch.object(release.subprocess, 'check_output', return_value=''), \
                    patch.object(release, 'copy_docs'):
                release.linux_package(stage)
            commands = {str(call.args[0][-1].relative_to(stage)): call.args[0][-2]
                        for call in run.call_args_list}
            self.assertEqual(commands['raft_flutter'], '$ORIGIN/lib')
            self.assertEqual(commands['lib/libmpv.so.2'], '$ORIGIN')
            self.assertEqual(commands['lib/libmedia_kit_video_plugin.so'], '$ORIGIN')
            if enabled:
                self.assertIn(payload.RUNTIME[2], commands, 'Verified HTML runtime helper must be packaged')
                self.assertEqual(commands[payload.RUNTIME[2]], '$ORIGIN/../../lib')
                self.assertEqual(commands[payload.RUNTIME[1]], '$ORIGIN/../..')
                self.assertEqual(commands['lib/gio/modules/libgiognutls.so'], '$ORIGIN/../..')
                self.assertTrue((stage / payload.PACKAGED).is_file())
                self.assertIn('Exec=run-raft %u', (stage / 'data/applications/app.raft.raft_flutter.desktop').read_text())
                self.check_generated_tar_launcher(stage)
            else:
                self.assertEqual(len(commands), 3)
                self.assertFalse((stage / payload.PACKAGED).exists())
                self.assertFalse((stage / 'run-raft').exists())

    def check_generated_tar_launcher(self, stage):
        # Shell/environment acceptance only: replace fake ELF fixtures with
        # controlled probes, never a browser or real desktop/account program.
        app = stage / 'raft_flutter'
        app.write_text('#!/bin/sh\nexec "' + sys.executable + '" "$@"\n')
        app.chmod(0o755)
        keys = ['GIO_MODULE_DIR', 'GST_PLUGIN_SYSTEM_PATH_1_0', 'GST_PLUGIN_PATH_1_0',
                'GST_PLUGIN_SCANNER_1_0', 'GST_REGISTRY_1_0', 'GST_PLUGIN_SCANNER', 'GST_REGISTRY']
        probe = 'import os,json; print(json.dumps({k:os.environ.get(k) for k in ' + repr(keys) + '}))'
        cache = self.root / 'qa-cache'
        original = {'PATH': os.defpath, 'HOME': str(self.root), 'XDG_CACHE_HOME': str(cache),
                    **{key: '/host/' + key for key in keys}}
        result = subprocess.run([str(stage / 'run-raft'), '-c', probe], env=original,
                                text=True, capture_output=True, check=True)
        values = json.loads(result.stdout)
        self.assertEqual(values['GIO_MODULE_DIR'], str(stage / 'lib/gio/modules'))
        self.assertEqual(values['GST_PLUGIN_SYSTEM_PATH_1_0'], str(stage / 'lib/gstreamer-1.0'))
        self.assertEqual(values['GST_PLUGIN_PATH_1_0'], '')
        self.assertEqual(values['GST_PLUGIN_SCANNER_1_0'], str(stage / payload.GST_SCANNER))
        self.assertEqual(values['GST_PLUGIN_SCANNER'], values['GST_PLUGIN_SCANNER_1_0'])
        self.assertEqual(values['GST_REGISTRY'], values['GST_REGISTRY_1_0'])
        self.assertTrue(Path(values['GST_PLUGIN_SCANNER']).is_relative_to(stage))
        self.assertTrue(values['GST_REGISTRY_1_0'].startswith(str(cache / 'raft-html-runtime')))
        registry_parent = Path(values['GST_REGISTRY']).parent
        self.assertTrue(registry_parent.is_relative_to(cache / 'raft-html-runtime' / self.pin))
        sentinel = registry_parent / 'qa-write-probe'
        sentinel.write_bytes(b'owned launcher test only')
        self.assertEqual(sentinel.read_bytes(), b'owned launcher test only')
        sentinel.unlink()
        helper = stage / payload.GIO_LAUNCHER
        helper.write_text('#!/bin/sh\nexec "$@"\n')
        external = ('import os,subprocess,sys; print(subprocess.check_output('
                    '[os.environ["GIO_LAUNCH_DESKTOP"], sys.executable, "-c", ' + repr(probe) +
                    '], text=True), end="")')
        result = subprocess.run([str(stage / 'run-raft'), '-c', external], env=original,
                                text=True, capture_output=True, check=True)
        self.assertEqual(json.loads(result.stdout), {key: original[key] for key in keys})


if __name__ == '__main__':
    unittest.main()
