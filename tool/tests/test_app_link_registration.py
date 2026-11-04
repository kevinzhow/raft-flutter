"""Guard native URL registration and the public association handoff identities.

These check source configuration, not installed OS verification or signing.
"""
import json
import pathlib
import plistlib
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
APP = ROOT / 'apps/raft_flutter'
A = '{http://schemas.android.com/apk/res/android}'


class AppLinkRegistrationTests(unittest.TestCase):
    def test_android_verified_entry_has_one_activity_and_narrow_https_paths(self):
        manifest = ET.parse(APP / 'android/app/src/main/AndroidManifest.xml').getroot()
        aliases = manifest.findall('application/activity-alias')
        entry = next((item for item in aliases if item.get(A + 'name') == '.AppLinksEntry'), None)
        self.assertIsNotNone(entry)
        self.assertEqual(entry.get(A + 'targetActivity'), '.MainActivity')
        self.assertEqual(entry.get(A + 'enabled'), '${raftAppLinksEnabled}')
        filters = entry.findall('intent-filter')
        self.assertEqual(len(filters), 1)
        self.assertEqual(filters[0].get(A + 'autoVerify'), 'true')
        data = filters[0].findall('data')
        self.assertEqual({row.get(A + 'scheme') for row in data if row.get(A + 'scheme')}, {'https'})
        self.assertEqual({row.get(A + 'host') for row in data if row.get(A + 'host')}, {'${raftAppLinksHost}'})
        self.assertEqual({row.get(A + 'pathPattern') for row in data if row.get(A + 'pathPattern')},
                         {'/s/.*/channel/.*', '/s/.*/dm/.*'})
        self.assertEqual({row.get(A + 'pathPrefix') for row in data if row.get(A + 'pathPrefix')},
                         {'/join/', '/integration-invites/'})
        self.assertEqual({row.get(A + 'name') for row in filters[0].findall('category')},
                         {'android.intent.category.DEFAULT', 'android.intent.category.BROWSABLE'})

    def test_native_private_invite_does_not_depend_on_https_alias(self):
        manifest = ET.parse(APP / 'android/app/src/main/AndroidManifest.xml').getroot()
        main = next(row for row in manifest.findall('application/activity') if row.get(A + 'name') == '.MainActivity')
        paths = [row.attrib for row in main.findall('intent-filter/data')]
        self.assertIn({A + 'scheme': 'raft', A + 'host': 'v1', A + 'pathPrefix': '/integration-invites/'}, paths)
        self.assertFalse(any(row.get(A + 'scheme') in {'http', 'https'} for row in main.findall('intent-filter/data')))
        self.assertEqual(main.get(A + 'launchMode'), 'singleTask')

    def test_ios_deep_links_have_one_authenticated_coordinator_owner(self):
        with (APP / 'ios/Runner/Info.plist').open('rb') as stream:
            info = plistlib.load(stream)
        self.assertIs(info['FlutterDeepLinkingEnabled'], False)

    def test_apple_association_is_on_the_app_not_share_extensions(self):
        for path in ['ios/Runner/Runner.entitlements', 'macos/Runner/DebugProfileAppLinks.entitlements',
                     'macos/Runner/ReleaseAppLinks.entitlements']:
            with (APP / path).open('rb') as stream:
                values = plistlib.load(stream)
            self.assertEqual(values['com.apple.developer.associated-domains'], ['applinks:$(RAFT_APP_LINK_HOST)'])
        # Existing ad-hoc Mac signatures must not gain restricted capabilities.
        for path in ['macos/Runner/DebugProfile.entitlements', 'macos/Runner/Release.entitlements',
                     'ios/ShareExtension/ShareExtension.entitlements', 'ios/ActionExtension/ActionExtension.entitlements']:
            with (APP / path).open('rb') as stream:
                self.assertNotIn('com.apple.developer.associated-domains', plistlib.load(stream))

    def test_android_template_is_this_public_client_and_apple_identity_is_unfilled(self):
        statement, = json.loads((ROOT / 'packaging/app-links/assetlinks.json').read_text())
        self.assertEqual(statement['relation'], ['delegate_permission/common.handle_all_urls'])
        self.assertEqual(statement['target']['namespace'], 'android_app')
        self.assertEqual(statement['target']['package_name'], 'app.raft.raft_flutter')
        for fingerprint in statement['target']['sha256_cert_fingerprints']:
            self.assertRegex(fingerprint, r'^(?:[A-F0-9]{2}:){31}[A-F0-9]{2}$')
        template = json.loads((ROOT / 'packaging/app-links/apple-app-site-association.template').read_text())
        details, = template['applinks']['details']
        self.assertEqual(details['appIDs'], ['<OWNER_VERIFIED_APP_ID_PREFIX>.app.raft.raftFlutter'])
        self.assertEqual({row['/'] for row in details['components']},
                         {'/s/*/channel/*', '/s/*/dm/*', '/join/*', '/integration-invites/*'})

    def test_linux_does_not_claim_global_https(self):
        launcher = (APP / 'lib/platform/linux_uri_scheme.dart').read_text()
        cmake = (APP / 'linux/CMakeLists.txt').read_text()
        for content in [launcher, cmake]:
            self.assertIn('x-scheme-handler/raft', content)
            self.assertNotRegex(content, r'x-scheme-handler/https?(?:[;\\"\s]|$)')


if __name__ == '__main__':
    unittest.main()
