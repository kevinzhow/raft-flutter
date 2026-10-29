"""The application-menu update command must reach the production delegate."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


class MacOSUpdateMenuTests(unittest.TestCase):
    def test_update_command_is_between_preferences_and_services(self):
        tree = ET.parse(ROOT / 'apps/raft_flutter/macos/Runner/Base.lproj/MainMenu.xib')
        items = tree.find(".//menu[@systemMenu='apple']/items")
        titles = [item.get('title') for item in items]
        self.assertIn('Check for Updates…', titles)
        self.assertLess(titles.index('Preferences…'), titles.index('Check for Updates…'))
        self.assertLess(titles.index('Check for Updates…'), titles.index('Services'))
        command = items.find("menuItem[@title='Check for Updates…']")
        action = command.find('connections/action')
        self.assertIsNotNone(action)
        self.assertEqual(action.get('selector'), 'checkForUpdates:')
        self.assertEqual(action.get('target'), 'Voe-Tx-rLC')
        self.assertIsNone(command.get('keyEquivalent'))


if __name__ == '__main__':
    unittest.main()
