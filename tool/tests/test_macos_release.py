import importlib.util
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('macos_release', Path(__file__).resolve().parents[1] / 'macos_release.py')
macos = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(macos)


class MacReleaseTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.app = self.root / 'Raft.app'
        (self.app / 'Contents/MacOS').mkdir(parents=True)
        (self.app / 'Contents/MacOS/Raft').write_bytes(b'\xcf\xfa\xed\xfe' + b'native-fixture')
        self.info = {'CFBundleIdentifier': 'app.raft.raftFlutter', 'CFBundleExecutable': 'Raft',
                     'CFBundleShortVersionString': '0.1.0', 'CFBundleVersion': '41'}
        self.write_info()
        self.entitlements = self.root / 'Release.entitlements'
        self.entitlements.write_bytes(plistlib.dumps({'com.apple.security.app-sandbox': True,
                                                    'com.apple.security.network.client': True}))

    def write_info(self):
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps(self.info))

    def outputs(self, args):
        if args[0] == 'lipo':
            return b'arm64\n', b''
        if '--entitlements' in args:
            return self.entitlements.read_bytes(), b''
        return b'', b'Signature=adhoc\nTeamIdentifier=not set\n'

    def test_rejects_development_profile_before_signing(self):
        (self.app / 'Contents/embedded.provisionprofile').write_bytes(b'private-profile')
        with self.assertRaisesRegex(ValueError, 'provisioning profile'):
            macos.inventory(self.app)

    def test_rejects_symlink_to_outside_app(self):
        (self.app / 'Contents/external').symlink_to(self.root)
        with self.assertRaisesRegex(ValueError, 'external symlink'):
            macos.inventory(self.app)

    def test_accepts_framework_internal_symlink(self):
        (self.app / 'Contents/internal').symlink_to('MacOS')
        self.assertEqual(len(macos.inventory(self.app)), 1)

    def test_rejects_unreviewed_nested_bundle_entitlements(self):
        (self.app / 'Contents/Helper.xpc').mkdir()
        with self.assertRaisesRegex(ValueError, 'entitlement policy'):
            macos.inventory(self.app)

    def sparkle(self):
        framework = self.app / 'Contents/Frameworks/Sparkle.framework/Versions/B'
        for bundle in ['XPCServices/Installer.xpc/Contents/MacOS/Installer',
                       'XPCServices/Downloader.xpc/Contents/MacOS/Downloader',
                       'Updater.app/Contents/MacOS/Updater']:
            (framework / bundle).parent.mkdir(parents=True)
            (framework / bundle).write_bytes(b'\xcf\xfa\xed\xfe' + b'sparkle')
        (framework.parent / 'Current').symlink_to('B')
        (self.app / 'Contents/Frameworks/Sparkle.framework/Updater.app').symlink_to('Versions/Current/Updater.app')

    def test_accepts_only_sparkles_nested_bundles_with_their_own_policy(self):
        self.sparkle()
        self.assertEqual(len(macos.inventory(self.app)), 4)
        self.assertEqual([p.name for p in macos.nested_bundles(self.app)].count('Installer.xpc'), 1)
        (self.app / 'Contents/Frameworks/Other.framework/Versions/A/XPCServices/Installer.xpc').mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, 'entitlement policy'):
            macos.inventory(self.app)

    def test_package_signs_sparkle_bundles_inside_out_preserving_xpc_entitlements(self):
        self.sparkle()
        self.info['SUEnableInstallerLauncherService'] = True
        self.write_info()
        calls, stage = [], self.root / 'stage'

        def fake_run(args):
            calls.append([str(a) for a in args])
            if args[0] == 'ditto':  # stand in for ditto's copy
                shutil.copytree(args[1], args[2], symlinks=True)

        with patch.object(macos, 'run', side_effect=fake_run), patch.object(macos, 'output', side_effect=self.outputs):
            macos.package(self.app, stage, self.entitlements, '0.1.0', '41', public_key='KEY')
        names = [c for c in calls if c[0] == 'codesign' and '--force' in c]
        xpc = [c for c in names if c[-1].endswith('.xpc')]
        self.assertEqual(len(xpc), 2)
        self.assertTrue(all('--preserve-metadata=entitlements' in c for c in xpc))
        app_sign = [c for c in names if c[-1].endswith('Raft.app')][0]
        self.assertIn('--entitlements', app_sign)
        self.assertEqual(names[-1], app_sign)  # app is sealed last
        self.assertTrue(all('runtime' not in ' '.join(c) for c in names))  # no library validation
        index = {c[-1].split('/')[-1]: n for n, c in enumerate(names)}
        self.assertLess(index['Installer.xpc'], index['Sparkle.framework'])
        info = plistlib.loads((stage / 'Raft.app/Contents/Info.plist').read_bytes())
        self.assertEqual(info['SUPublicEDKey'], 'KEY')

    def test_updater_key_and_launcher_service_must_match_the_build_intent(self):
        self.sparkle()
        with patch.object(macos, 'run'):
            with self.assertRaisesRegex(ValueError, 'differs'):
                macos.verify_updater(self.app, 'KEY')  # no key in the plist
            macos.configure_updater(self.app, 'KEY')
            with self.assertRaisesRegex(ValueError, 'LauncherService'):
                macos.verify_updater(self.app, 'KEY')
            self.info['SUEnableInstallerLauncherService'] = True
            self.info['SUPublicEDKey'] = 'KEY'
            self.write_info()
            self.assertEqual(macos.verify_updater(self.app, 'KEY')['enabled'], True)
            with self.assertRaisesRegex(ValueError, 'differs'):
                macos.verify_updater(self.app, '')

    def test_build_without_key_has_no_updater_key_and_still_verifies(self):
        self.info['SUPublicEDKey'] = 'STALE'
        self.write_info()
        macos.configure_updater(self.app, '')
        self.assertNotIn('SUPublicEDKey', plistlib.loads((self.app / 'Contents/Info.plist').read_bytes()))
        with patch.object(macos, 'run'), patch.object(macos, 'output', side_effect=self.outputs):
            self.assertFalse(macos.verify(self.app, self.entitlements, '0.1.0', '41')['updater']['enabled'])

    def test_rejects_version_mismatch(self):
        self.info['CFBundleVersion'] = '40'
        self.write_info()
        with self.assertRaisesRegex(ValueError, 'release plan'):
            macos.verify(self.app, self.entitlements, '0.1.0', '41')

    def test_rejects_wrong_architecture(self):
        with patch.object(macos, 'output', return_value=(b'x86_64\n', b'')):
            with self.assertRaisesRegex(ValueError, 'architecture'):
                macos.verify(self.app, self.entitlements, '0.1.0', '41')

    def test_signature_claim_cannot_replace_actual_signature(self):
        def wrong_signature(args):
            if args[0] == 'codesign' and '-vv' in args:
                return b'', b'Authority=Apple Development\n'
            return self.outputs(args)
        with patch.object(macos, 'run'), patch.object(macos, 'output', side_effect=wrong_signature):
            with self.assertRaisesRegex(ValueError, 'ad-hoc'):
                macos.verify(self.app, self.entitlements, '0.1.0', '41')

    def test_rejects_changed_entitlements(self):
        def wrong_entitlements(args):
            if '--entitlements' in args:
                return plistlib.dumps({'com.apple.security.get-task-allow': True}), b''
            return self.outputs(args)
        with patch.object(macos, 'run'), patch.object(macos, 'output', side_effect=wrong_entitlements):
            with self.assertRaisesRegex(ValueError, 'entitlements'):
                macos.verify(self.app, self.entitlements, '0.1.0', '41')

    def test_records_verified_ad_hoc_metadata(self):
        with patch.object(macos, 'run'), patch.object(macos, 'output', side_effect=self.outputs):
            result = macos.verify(self.app, self.entitlements, '0.1.0', '41')
        self.assertEqual(result['architecture'], 'arm64')
        self.assertTrue(result['entitlementsVerified'])


if __name__ == '__main__':
    unittest.main()
