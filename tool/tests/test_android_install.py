"""Exercise deployment transactions using fake SDK/ADB, never a real device."""
import copy
import os
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import android_app as android


def dump(version=4001, inode=123, installed=True):
    return (f'Package [app.raft.raft_flutter]:\n    versionCode={version} minSdk=24 targetSdk=37\n'
            f'    User 0: ceDataInode={inode} deDataInode=456 installed={str(installed).lower()}\n'
            '      firstInstallTime=2026-10-10 12:34:56\n    User 10: installed=false\n')


# Reduced from the real icon APK's aapt xmltree output, not source XML.
ALIAS_MANIFEST = """N: android=http://schemas.android.com/apk/res/android
  E: manifest (line=2)
    A: package="app.raft.raft_flutter" (Raw: "app.raft.raft_flutter")
    E: application (line=59)
      E: activity (line=86)
        A: android:name(0x01010003)=".MainActivity"
        A: android:exported(0x01010010)=(type 0x12)0xffffffff
        E: intent-filter (line=99)
          E: action (line=100)
            A: android:name(0x01010003)="android.intent.action.MAIN"
          E: category (line=102)
            A: android:name(0x01010003)="android.intent.category.INFO"
      E: activity (line=159)
        A: android:name(0x01010003)=".YellowIconEntry"
        A: android:exported(0x01010010)=(type 0x12)0x0
      E: activity-alias (line=164)
        A: android:name(0x01010003)=".IconYellow"
        A: android:enabled(0x0101000e)=(type 0x12)0xffffffff
        A: android:exported(0x01010010)=(type 0x12)0xffffffff
        A: android:targetActivity(0x01010202)=".YellowIconEntry"
        E: intent-filter (line=172)
          E: action (line=173)
            A: android:name(0x01010003)="android.intent.action.MAIN"
          E: category (line=175)
            A: android:name(0x01010003)="android.intent.category.LAUNCHER"
"""


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='raft-install-test-')
        self.addCleanup(self.temp.cleanup)
        self.apk = Path(self.temp.name) / 'candidate.apk'
        with zipfile.ZipFile(self.apk, 'w') as archive:
            archive.writestr('lib/arm64-v8a/libflutter.so', 'fake fixture')
        self.commands = []
        self.receipts = []
        self.version = 4001
        self.target = 37
        self.package = android.PACKAGE
        self.old = dump()
        self.new = dump()
        self.mismatch_certificate = False
        self.fail_install = False
        self.corrupt_after = False
        self.installed = False
        self.retained_packages = ''
        self.appears_during_preflight = False
        self.absence_checks = 0
        self.badging_activity = True
        self.manifest = ALIAS_MANIFEST

    def fake_call(self, argv):
        argv = [str(arg) for arg in argv]
        self.commands.append(argv)
        if argv[0] == 'aapt':
            if argv[1:3] == ['dump', 'xmltree']:
                return self.manifest
            activity = "launchable-activity: name='app.raft.raft_flutter.MainActivity'\n" if self.badging_activity else ''
            return (f"package: name='{self.package}' versionCode='{self.version}'\n"
                    f"targetSdkVersion:'{self.target}'\n{activity}")
        if argv[0] == 'apksigner':
            cert = 'b' if self.mismatch_certificate and Path(argv[-1]).name == 'installed.apk' else 'a'
            return f'Signer #1 certificate SHA-256 digest: {cert * 64}\n'
        if argv[3:6] == ['shell', 'dumpsys', 'package']:
            return self.new if self.installed else self.old
        if argv[3:6] == ['shell', 'pm', 'list']:
            self.absence_checks += 1
            if self.appears_during_preflight and self.absence_checks > 1:
                return f'package:{android.PACKAGE}\n'
            return self.retained_packages
        if argv[3:6] == ['shell', 'pm', 'path']:
            return 'package:ignore\n' if self.old == 'missing' else 'package:/data/app/~~fixture==/raft==/base.apk\n'
        if argv[3] == 'pull':
            Path(argv[-1]).write_bytes(b'changed' if self.installed and self.corrupt_after else self.apk.read_bytes())
            return 'pulled\n'
        if argv[3] == 'install':
            if self.fail_install:
                raise android.SafetyError('INSTALL_FAILED_UPDATE_INCOMPATIBLE')
            self.installed = True
            return 'Success\n'
        if argv[3:6] == ['shell', 'am', 'start']:
            return 'Starting\n'
        self.fail(f'unexpected command {argv}')

    def update(self, **kw):
        return android.update(self.apk, 'owned-test-device', ('adb', 'aapt', 'apksigner'),
                              lambda report: self.receipts.append(copy.deepcopy(report)), run=self.fake_call, **kw)

    def mutations(self):
        return [cmd for cmd in self.commands if cmd[0] == 'adb' and cmd[3] == 'install']

    def test_alias_only_badging_update_retains_all_transaction_checks(self):
        self.badging_activity = False
        report = self.update(launch=True)
        self.assertEqual(report['apk']['activity'], android.PACKAGE + '.MainActivity')
        self.assertEqual(report['status'], 'verified')
        self.assertEqual(report['before'], report['after'])
        self.assertEqual(len(self.mutations()), 1)
        self.assertEqual(self.commands[-1][-1], android.PACKAGE + '/' + android.PACKAGE + '.MainActivity')

    def test_alias_only_badging_preflight_is_read_only(self):
        self.badging_activity = False
        self.assertEqual(self.update(check_only=True)['status'], 'preflight-passed')
        self.assertFalse(self.mutations())
        self.assertNotIn('start', str(self.commands))

    def test_alias_fallback_rejects_unavailable_or_ambiguous_entries_before_adb(self):
        alias = ALIAS_MANIFEST[ALIAS_MANIFEST.index('      E: activity-alias'):]
        cases = [
            ALIAS_MANIFEST.replace('A: package="app.raft.raft_flutter"', 'A: package="wrong.package"'),
            ALIAS_MANIFEST.replace('E: application (line=59)',
                                   'E: application (line=59)\n      A: android:enabled=(type 0x12)0x0'),
            ALIAS_MANIFEST.replace('android:targetActivity(0x01010202)=".YellowIconEntry"',
                                   'android:targetActivity(0x01010202)=".Missing"'),
            ALIAS_MANIFEST.replace('A: android:enabled(0x0101000e)=(type 0x12)0xffffffff',
                                   'A: android:enabled(0x0101000e)=(type 0x12)0x0'),
            ALIAS_MANIFEST.replace('android:targetActivity(0x01010202)=".YellowIconEntry"',
                                   'android:targetActivity(0x01010202)=".YellowIconEntry"\n        A: android:exported=(type 0x12)0x0'),
            ALIAS_MANIFEST.replace('A: android:name(0x01010003)=".YellowIconEntry"',
                                   'A: android:name(0x01010003)=".YellowIconEntry"\n        A: android:enabled=(type 0x12)0x0'),
            ALIAS_MANIFEST + alias.replace('".IconYellow"', '".SecondAlias"'),
            ALIAS_MANIFEST.replace('"android.intent.action.MAIN"', '"android.intent.action.VIEW"'),
            '',
        ]
        self.badging_activity = False
        for index, manifest in enumerate(cases):
            with self.subTest(index=index):
                self.manifest = manifest
                self.commands.clear()
                with self.assertRaises(android.SafetyError):
                    self.update()
                self.assertTrue(all(command[0] == 'aapt' for command in self.commands))

    def test_alias_without_info_uses_the_exported_alias_not_internal_target(self):
        manifest = ALIAS_MANIFEST.replace('"android.intent.category.INFO"', '"unused.category"')
        self.assertEqual(android.manifest_launch_activity(manifest, android.PACKAGE),
                         android.PACKAGE + '.IconYellow')

    def test_update_verifies_artifact_and_data_before_launch(self):
        report = self.update(launch=True)
        self.assertEqual(report['status'], 'verified')
        self.assertEqual(report['before'], report['after'])
        self.assertEqual(len(self.mutations()), 1)
        self.assertEqual(self.mutations()[0][:-1], ['adb', '-s', 'owned-test-device', 'install', '-r', '--user', '0'])
        self.assertEqual(Path(self.mutations()[0][-1]).name, 'candidate.apk')
        self.assertNotEqual(self.mutations()[0][-1], str(self.apk))
        self.assertEqual(self.commands[-1][3:6], ['shell', 'am', 'start'])
        self.assertNotIn('uninstall', str(self.commands))
        self.assertNotIn('clear', str(self.commands))

    def test_read_only_check_never_installs_or_launches(self):
        self.assertEqual(self.update(check_only=True, launch=True)['status'], 'preflight-passed')
        self.assertFalse(self.mutations())
        self.assertNotIn('start', str(self.commands))

    def test_first_install_is_explicit_and_verifies_created_package(self):
        self.old = f'Unable to find package: {android.PACKAGE}\n'
        with self.assertRaises(android.SafetyError):
            self.update()
        self.assertFalse(self.mutations())
        report = self.update(first_install=True)
        self.assertEqual(report['mode'], 'first-install')
        self.assertEqual(report['status'], 'verified')
        self.assertIsNone(report['before'])
        self.assertEqual(report['after'], android.package_state(self.new))
        self.assertEqual(self.mutations()[0][:-1], ['adb', '-s', 'owned-test-device', 'install', '--user', '0'])
        self.assertEqual(len(self.mutations()), 1)
        self.assertNotIn('uninstall', str(self.commands))

    def test_first_install_preflight_is_read_only(self):
        self.old = f'Unable to find package: {android.PACKAGE}\n'
        report = self.update(first_install=True, check_only=True, launch=True)
        self.assertEqual(report['status'], 'preflight-passed')
        self.assertFalse(self.mutations())
        self.assertNotIn('start', str(self.commands))

    def test_first_install_allows_distinct_packages_matching_android_filter(self):
        self.old = f'Unable to find package: {android.PACKAGE}\n'
        self.retained_packages = (f'package:{android.LAB_PACKAGE}\n'
                                  f'package:{android.PACKAGE}.other\n')
        report = self.update(first_install=True, check_only=True)
        self.assertEqual(report['status'], 'preflight-passed')
        self.assertFalse(self.mutations())
        self.assertEqual(self.update(first_install=True)['status'], 'verified')
        self.assertEqual(len(self.mutations()), 1)
        self.assertNotIn('uninstall', str(self.commands))
        self.assertNotIn('clear', str(self.commands))

    def test_first_install_rejects_unrecognized_package_listing(self):
        self.old = f'Unable to find package: {android.PACKAGE}\n'
        for listing in ('Error: unavailable', 'package:', 'unexpected output'):
            with self.subTest(listing=listing):
                self.retained_packages = listing
                with self.assertRaises(android.SafetyError):
                    self.update(first_install=True)
                self.assertFalse(self.mutations())

    def test_first_install_rejects_existing_retained_and_concurrently_added_package(self):
        absent = f'Unable to find package: {android.PACKAGE}\n'
        for state, retained, concurrent in ((dump(), '', False),
                                             (dump(installed=False), '', False),
                                             (absent, f'package:{android.PACKAGE}\n', False),
                                             (absent, f'package:{android.LAB_PACKAGE}\npackage:{android.PACKAGE}\n', False),
                                             (absent, '', True)):
            with self.subTest(state=state, retained=retained, concurrent=concurrent):
                self.old, self.retained_packages = state, retained
                self.appears_during_preflight = concurrent
                self.absence_checks = 0
                with self.assertRaises(android.SafetyError):
                    self.update(first_install=True, launch=True)
                self.assertFalse(self.mutations())
                self.assertNotIn('start', str(self.commands))

    def test_first_install_failure_or_wrong_artifact_never_retries_or_launches(self):
        self.old = f'Unable to find package: {android.PACKAGE}\n'
        for failure in ('install', 'hash'):
            with self.subTest(failure=failure):
                self.commands.clear()
                self.installed = False
                self.fail_install = failure == 'install'
                self.corrupt_after = failure == 'hash'
                with self.assertRaises(android.SafetyError):
                    self.update(first_install=True, launch=True)
                self.assertEqual(len(self.mutations()), 1)
                self.assertNotIn('uninstall', str(self.commands))
                self.assertNotIn('start', str(self.commands))

    @unittest.skipIf(os.name == 'nt', 'Android installer locking requires a macOS/Linux host')
    def test_same_device_updates_are_serialized_and_lock_releases(self):
        directory = Path(self.temp.name) / 'locks'
        with android.update_lock('owned-test-device', directory):
            with self.assertRaises(android.SafetyError):
                with android.update_lock('owned-test-device', directory):
                    self.fail('concurrent update must not enter')
            with android.update_lock('another-owned-device', directory):
                pass
        with android.update_lock('owned-test-device', directory):
            pass

    def test_sdk37_signature_output_and_duplicate_scheme_certificates(self):
        digest = 'a' * 64
        output = f'V2 Signer: certificate SHA-256 digest: {digest}\nV3 Signer: certificate SHA-256 digest: {digest}\nV3.0 Signer: certificate SHA-256 digest: {digest}\nV3.1 Signer: certificate SHA-256 digest: {digest}\n'
        self.assertEqual(android.certificate(self.apk, 'apksigner', lambda _: output), [digest])

    def test_identity_downgrade_signature_and_missing_app_block_before_mutation(self):
        cases = [('package', android.LAB_PACKAGE), ('version', 2001), ('target', 36),
                 ('mismatch_certificate', True), ('old', 'missing'),
                 ('old', dump(installed=False)), ('old', dump(inode=0))]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                original = getattr(self, field)
                setattr(self, field, value)
                with self.assertRaises(android.SafetyError):
                    self.update(launch=True)
                self.assertFalse(self.mutations())
                setattr(self, field, original)
                self.commands.clear()

    def test_failed_install_does_not_retry_uninstall_or_launch(self):
        self.fail_install = True
        with self.assertRaises(android.SafetyError):
            self.update(launch=True)
        self.assertEqual(len(self.mutations()), 1)
        self.assertEqual(self.receipts[-1]['status'], 'failed')
        self.assertNotIn('uninstall', str(self.commands))
        self.assertNotIn('start', str(self.commands))

    def test_changed_data_identity_or_wrong_artifact_stops_before_launch(self):
        for changed in ('inode', 'hash'):
            with self.subTest(changed=changed):
                self.commands.clear()
                self.installed = False
                self.new = dump(inode=789) if changed == 'inode' else dump()
                self.corrupt_after = changed == 'hash'
                with self.assertRaises(android.SafetyError):
                    self.update(launch=True)
                self.assertEqual(len(self.mutations()), 1)
                self.assertNotIn('start', str(self.commands))

    def test_flutter_drive_namespace_cleanup_path_is_blocked(self):
        arguments = ['drive', '-d', 'owned-test-device', '--profile']
        for extra in ([], ['--keep-app-running'],
                      ['--keep-app-running', f'--use-application-binary={self.apk}'],
                      ['--keep-app-running', '--no-keep-app-running', f'--use-application-binary={self.apk}']):
            with self.subTest(extra=extra), self.assertRaises(android.SafetyError):
                android.flutter_guard(arguments + extra, tools=('adb', 'aapt', 'apksigner'), run=self.fake_call)
        self.package = android.LAB_PACKAGE
        android.flutter_guard(arguments + ['--keep-app-running', f'--use-application-binary={self.apk}'],
                              tools=('adb', 'aapt', 'apksigner'), run=self.fake_call)
        self.assertFalse(self.mutations())

    def test_mobile_auto_install_blocked_desktop_and_widget_tests_allowed(self):
        for command in ('run', 'test', 'install'):
            with self.assertRaises(android.SafetyError):
                android.flutter_guard([command, '-d', 'owned-test-device'])
            with self.assertRaises(android.SafetyError):
                android.flutter_guard(['--verbose', command, '-d', 'owned-test-device'])
        for arguments in (['run', '-d', 'macos'], ['test', 'test/widget_test.dart'], ['build', 'apk']):
            android.flutter_guard(arguments)

    def test_non_arm64_artifact_is_rejected_before_mutation(self):
        with zipfile.ZipFile(self.apk, 'a') as archive:
            archive.writestr('lib/x86_64/libflutter.so', 'another ABI')
        with self.assertRaises(android.SafetyError):
            self.update()
        self.assertFalse(self.mutations())

    def test_lab_protects_physical_app_but_allows_empty_named_emulator(self):
        tools = ('adb', 'aapt', 'apksigner')
        self.assertEqual(android.protected_state('owned-test-device', tools, self.fake_call), android.package_state(dump()))
        absent = lambda _: 'Unable to find package: app.raft.raft_flutter\n'
        with self.assertRaises(android.SafetyError):
            android.protected_state('owned-test-device', tools, absent)
        self.assertIsNone(android.protected_state('emulator-5580', tools, absent))


if __name__ == '__main__':
    unittest.main()
