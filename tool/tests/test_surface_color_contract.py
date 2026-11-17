"""Surface paints of the Raft look: Web v1.21.23."""
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


if __name__ == '__main__':
    unittest.main()
