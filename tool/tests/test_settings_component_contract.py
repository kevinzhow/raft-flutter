"""Settings values from Web v1.21.23 and the frozen a57b9dab recipes.

See PR472's source table: SidebarItem accent / SidebarGroupLabel,
SettingsPanel Card/content and its text-mono-code handle.
"""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SettingsComponentContractTests(unittest.TestCase):
    def assert_pack(self, family, light, dark):
        data = json.loads((ROOT / 'packages/raft_theme/assets/themes' /
                           f'{family}.theme.json').read_text())
        keys = ('type.settingsSidebarItem.size', 'type.settingsSidebarItem.line',
                'type.settingsGroupLabel.size', 'type.settingsGroupLabel.line',
                'type.settingsCardMeta.line')
        for mode, expected in (('light', light), ('dark', dark)):
            with self.subTest(family=family, mode=mode):
                values = data['modes'][mode]
                geometry = values['geometry']
                self.assertEqual([geometry.get(k) for k in keys], expected[:5])
                self.assertEqual(values['colors'].get('layer-settings-card'), expected[5])
                self.assertEqual(values['colors'].get('layer-settings-content'), expected[6])
                self.assertEqual(values['colors'].get('layer-settings-feedback-content'), expected[7])

    def test_raft_web_settings(self):
        # Web SidebarItem text-subhead, SidebarGroupLabel text-footnote,
        # handle text-mono-code; Card layer-card, Panel content layer-canvas.
        self.assert_pack('raft',
                         [15, 20, 13, 18, 20, '#ffffff', '#ffffff', '#ffffff'],
                         [15, 20, 13, 18, 20, '#242422', '#1b1b19', '#1b1b19'])

    def test_elegant_original_settings(self):
        # a57 accent recipe is 13px with a 1.5 line height. Group label is
        # 10/15; ordinary content stays panel; only Feedback is card/dark.
        self.assert_pack('elegant',
                         [13, 19.5, 10, 15, 20, '#ffffff', '#ffffff', '#ffffff'],
                         [13, 19.5, 10, 15, 20, '#242422', '#242422', '#1b1b19'])

    def test_brutal_original_settings_and_elegant_dark(self):
        self.assert_pack('brutal',
                         [14, 20, 10, 15, 20, '#ffffff', '#ffffff', '#ffffff'],
                         [13, 19.5, 10, 15, 20, '#242422', '#242422', '#1b1b19'])


if __name__ == '__main__':
    unittest.main()
