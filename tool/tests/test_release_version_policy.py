"""The app version follows the Raft server version (owner decision 2026-10-23)."""
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


class ServerVersionPolicyTest(unittest.TestCase):
    def test_server_version_is_the_pinned_web_release(self):
        self.assertEqual(release.server_version({'pinned': 'v1.21.23-source.1'}), '1.21.23')
        with self.assertRaises(ValueError):
            release.server_version({'pinned': 'main'})

    def test_tag_version_must_equal_the_server_version(self):
        release.check_server_version('1.21.23', '1.21.23')
        release.check_server_version('1.21.23-rc.1', '1.21.23')
        for version in ('0.1.0', '1.21.12', '1.21.24'):
            with self.assertRaisesRegex(ValueError, r'v1\.21\.23\+N'):
                release.check_server_version(version, '1.21.23')

    def test_plan_stops_a_tag_that_is_not_the_server_version(self):
        import os
        from unittest import mock
        env = {'GITHUB_EVENT_NAME': 'push', 'GITHUB_REF': 'refs/tags/v0.1.0+34', 'GITHUB_RUN_NUMBER': '300'}
        with mock.patch.dict(os.environ, env), mock.patch.object(release, 'server_version', return_value='1.21.23'):
            with self.assertRaisesRegex(ValueError, r'v1\.21\.23\+N'):
                release.plan()

    def test_pubspec_version_follows_the_pinned_server(self):
        # Branch builds use the pubspec version; moving the pin moves it too.
        version, _ = release.version_info((ROOT / 'apps/raft_flutter/pubspec.yaml').read_text())
        pinned = json.loads((ROOT / 'docs/upstream-sync.json').read_text())
        self.assertEqual(version, release.server_version(pinned))


if __name__ == '__main__':
    unittest.main()
