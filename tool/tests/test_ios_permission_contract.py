"""Validate the shipped privacy declarations, before Flutter's debug injection."""
import pathlib
import plistlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class IOSPermissionContract(unittest.TestCase):
    def test_release_target_declares_permissions_used_by_native_features(self):
        # Debug Flutter builds inject a local-network description for the VM
        # service. The production target must declare its own LAN-server use.
        path = ROOT / 'apps/raft_flutter/ios/Runner/Info.plist'
        with path.open('rb') as source:
            info = plistlib.load(source)
        for key in ('NSLocalNetworkUsageDescription',
                    'NSPhotoLibraryUsageDescription',
                    'NSPhotoLibraryAddUsageDescription'):
            with self.subTest(key=key):
                self.assertTrue(info.get(key, '').strip(), key)


if __name__ == '__main__':
    unittest.main()
