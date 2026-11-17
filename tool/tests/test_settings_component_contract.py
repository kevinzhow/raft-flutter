"""Settings values from Web v1.21.23.

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


if __name__ == '__main__':
    unittest.main()
