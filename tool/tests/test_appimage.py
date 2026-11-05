import hashlib
import importlib.util
import io
import json
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
SPEC = importlib.util.spec_from_file_location('appimage', Path(__file__).resolve().parents[1] / 'appimage.py')
appimage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(appimage)


class AppImageTests(unittest.TestCase):
    def test_dependency_parse_rejects_unresolved_libraries_and_version_failures(self):
        for text in ['libgtk-3.so.0 => not found', 'libc.so.6: version `GLIBC_2.40\' not found']:
            with patch.object(appimage, 'capture', return_value=text), self.assertRaises(ValueError):
                appimage.dependencies(Path('/app/raft'))

    def test_newer_glibc_payload_is_rejected_before_packaging(self):
        self.assertEqual(appimage.glibc_requirement('Name: GLIBC_2.38\nName: GLIBC_2.39'), (2, 39))
        with self.assertRaisesRegex(ValueError, 'exceeds'):
            appimage.glibc_requirement('Name: GLIBC_2.42')

    def test_tool_hash_drift_never_creates_a_cached_executable(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(appimage.urllib.request, 'urlopen',
                return_value=io.BytesIO(b'changed executable')):
            with self.assertRaisesRegex(ValueError, 'SHA-256'):
                appimage.download_tool('runtime', {'url': 'https://example.com/runtime', 'sha256': '0' * 64}, Path(folder))
            self.assertFalse(list(Path(folder).iterdir()))

    def test_verified_tool_cache_is_used_and_bad_cache_preserved(self):
        data = b'pinned executable'
        with tempfile.TemporaryDirectory() as folder, patch.object(appimage.urllib.request, 'urlopen') as request:
            path = Path(folder) / 'runtime'
            path.write_bytes(data)
            record = {'url': 'https://example.com/runtime', 'sha256': hashlib.sha256(data).hexdigest()}
            self.assertEqual(appimage.download_tool('runtime', record, Path(folder)), path)
            path.write_bytes(b'corrupted')
            with self.assertRaisesRegex(ValueError, 'cached'):
                appimage.download_tool('runtime', record, Path(folder))
            self.assertEqual(path.read_bytes(), b'corrupted')
            request.assert_not_called()

    def test_isolated_launcher_creates_its_own_directories_before_the_legacy_name(self):
        # The real build is unchanged; an isolated one creates <id> directories
        # so path_provider_linux never falls back to the executable-name directory.
        self.assertEqual(appimage.isolated_directory_setup('app.raft.raft_flutter', ''), '')
        app_id = 'app.raft.raft_flutter.isolated'
        script = appimage.isolated_directory_setup(app_id, '.isolated')
        with tempfile.TemporaryDirectory(prefix='raftiso') as temporary:
            home = Path(temporary)
            (home / '.local/share/raft_flutter').mkdir(parents=True)
            env = {'PATH': os.defpath, 'HOME': str(home)}
            subprocess.check_call(['sh', '-eu', '-c', script], env=env)
            self.assertTrue((home / '.local/share' / app_id).is_dir())
            self.assertTrue((home / '.cache' / app_id).is_dir())
            self.assertFalse((home / '.cache/raft_flutter').exists())
            data, cache = home / 'xdg-data', home / 'xdg-cache'
            subprocess.check_call(['sh', '-eu', '-c', script],
                                  env=dict(env, XDG_DATA_HOME=str(data), XDG_CACHE_HOME=str(cache)))
            self.assertTrue((data / app_id).is_dir())
            self.assertTrue((cache / app_id).is_dir())

    def test_application_id_defaults_to_the_real_app(self):
        if not os.environ.get('RAFT_APPLICATION_ID_SUFFIX'):
            self.assertEqual(appimage.APP_ID, 'app.raft.raft_flutter')

    def test_the_official_build_embeds_the_latest_release_feed_and_nothing_overrides_it(self):
        self.assertEqual(
            appimage.update_information('', {}),
            'gh-releases-zsync|kevinzhow|raft-flutter|latest|raft-flutter-*-appimage-x64.AppImage.zsync')
        self.assertLessEqual(len(appimage.OFFICIAL_UPDATE_INFORMATION), appimage.UPDATE_INFORMATION_LIMIT)
        # The pattern must select exactly the asset release.py publishes.
        import fnmatch
        asset = 'raft-flutter-0.1.1+3-appimage-x64.AppImage.zsync'
        self.assertTrue(fnmatch.fnmatchcase(asset, appimage.UPDATE_ASSET_PATTERN))
        self.assertFalse(fnmatch.fnmatchcase(asset[:-6], appimage.UPDATE_ASSET_PATTERN))
        self.assertFalse(fnmatch.fnmatchcase('raft-flutter-0.1.1+3-windows-x64.zip', appimage.UPDATE_ASSET_PATTERN))
        # A release can never pick up a test feed from its environment.
        with self.assertRaisesRegex(ValueError, 'isolated test builds'):
            appimage.update_information('', {'RAFT_APPIMAGE_UPDATE_INFO': 'zsync|http://127.0.0.1:1/a.zsync'})

    def test_the_app_and_the_packager_agree_on_the_official_feed(self):
        source = (appimage.ROOT / 'packages/raft_updater/lib/src/appimage/update_information.dart').read_text()
        self.assertIn(f"'{appimage.OFFICIAL_UPDATE_INFORMATION}'", source)

    def test_an_isolated_build_never_updates_itself_into_the_official_build(self):
        self.assertEqual(appimage.update_information('.isolated', {}), '')
        self.assertEqual(appimage.update_information('.isolated', {'RAFT_APPIMAGE_UPDATE_INFO': ' '}), '')
        feed = 'zsync|http://127.0.0.1:8099/raft.AppImage.zsync'
        self.assertEqual(appimage.update_information('.isolated', {'RAFT_APPIMAGE_UPDATE_INFO': feed}), feed)
        for bad in ['zsync|ftp://x/y', 'gh-releases-zsync|a|b|latest', 'bittorrent|x', 'zsync|http://a b/c',
                    'zsync|http://h/' + 'x' * 1100]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                appimage.update_information('.isolated', {'RAFT_APPIMAGE_UPDATE_INFO': bad})

    def fake_zsyncmake(self, folder, header=None):
        """A stand-in that writes the header zsyncmake would for its last argument."""
        script = folder / 'zsyncmake'
        script.write_text('''#!/usr/bin/env python3
import hashlib, os, sys
args = sys.argv[1:]
out = args[args.index('-o') + 1]
url = args[args.index('-u') + 1]
data = open(args[-1], 'rb').read()
extra = os.environ.get('FAKE_ZSYNC_HEADER', '')
open(out, 'wb').write(('zsync: 0.6.2\\nFilename: x\\nBlocksize: 2048\\nLength: %d\\nHash-Lengths: 2,2,5\\nURL: %s\\nSHA-1: %s\\n%s\\n' % (
    len(data), url, hashlib.sha1(data).hexdigest(), extra)).encode() + b'blocks')
''')
        script.chmod(0o755)
        return script

    def test_the_zsync_control_file_must_describe_the_published_appimage(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            artifact = folder / 'raft-flutter-0.1.1+3-appimage-x64.AppImage'
            artifact.write_bytes(b'appimage bytes')
            tool = self.fake_zsyncmake(folder)
            zsync = appimage.make_zsync(artifact, str(tool))
            self.assertEqual(zsync.name, artifact.name + '.zsync')
            fields = appimage.zsync_control(zsync)
            self.assertEqual(fields['URL'], artifact.name)  # relative: resolved against the .zsync asset
            self.assertEqual(fields['SHA-1'], hashlib.sha1(b'appimage bytes').hexdigest())
            artifact.write_bytes(b'changed after zsyncmake')
            with patch.object(appimage.subprocess, 'run'), self.assertRaisesRegex(ValueError, 'does not describe'):
                appimage.make_zsync(artifact, str(tool))
            with patch.dict(os.environ, {'FAKE_ZSYNC_HEADER': 'Z-URL: x.gz\n'}), \
                    self.assertRaisesRegex(ValueError, 'does not describe'):
                artifact.write_bytes(b'appimage bytes')
                appimage.make_zsync(artifact, str(tool))

    def test_missing_zsyncmake_stops_the_release_instead_of_publishing_without_deltas(self):
        with tempfile.TemporaryDirectory() as temporary:
            artifact = Path(temporary) / 'a.AppImage'
            artifact.write_bytes(b'x')
            with self.assertRaisesRegex(ValueError, 'zsyncmake is required'):
                appimage.make_zsync(artifact, 'definitely-not-installed-zsyncmake')


if __name__ == '__main__':
    unittest.main()
