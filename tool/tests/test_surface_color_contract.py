"""Frozen surface paints: Web v1.21.23 for Raft, a57b9dab for the families."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ROLES = ('layer-drawer', 'layer-drawer-header', 'layer-dialog',
         'layer-conversation-content', 'layer-conversation-tab-page',
         'layer-profile-content', 'layer-member-list', 'layer-member-header')


class SurfaceColorContractTests(unittest.TestCase):
    def assert_modes(self, family, light, dark):
        data = json.loads((ROOT / 'packages/raft_theme/assets/themes' /
                           f'{family}.theme.json').read_text())
        for mode, expected in (('light', light), ('dark', dark)):
            with self.subTest(family=family, mode=mode):
                colors = data['modes'][mode]['colors']
                self.assertEqual({role: colors.get(role) for role in ROLES},
                                 dict(zip(ROLES, expected)))

    def test_raft_web_surface_layers(self):
        # Drawer/DialogSurface popover, ConversationPanel/ThreadPanel canvas,
        # ChannelMemberListShell Card, ChannelMembers PanelHeader canvas.
        self.assert_modes('raft',
            ['#ffffff'] * 4 + ['#00000000'] + ['#ffffff'] * 3,
            ['#292927'] * 3 + ['#1b1b19'] * 3 + ['#242422', '#1b1b19'])

    def test_elegant_original_surface_layers(self):
        # a57 channel_overflow_sheet.dart:76,234,1043; dialog_card.dart:485
        # Card root resolves token(layerPanel), NOT token(layerCard).
        # conversation_surface.dart:20; channel_members_view.dart:365,843.
        self.assert_modes('elegant',
            ['#ffffff'] * 4 + ['#00000000'] + ['#ffffff'] * 2 + ['#fcfcfb'],
            ['#242422'] * 3 + ['#1b1b19'] * 3 + ['#242422', '#131311'])

    def test_brutal_original_surface_layers_and_entire_elegant_dark(self):
        # a57 drawer cream, yellow drawer/member headers, white Card/forward
        # dialog/list; the contract selects the whole Elegant mode at night.
        self.assert_modes('brutal',
            ['#fffaef', '#ffd440', '#ffffff', '#ffffff', '#00000000',
             '#ffffff', '#ffffff', '#ffd440'],
            ['#242422'] * 3 + ['#1b1b19'] * 3 + ['#242422', '#131311'])


if __name__ == '__main__':
    unittest.main()
