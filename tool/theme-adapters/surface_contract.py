"""Component surface aliases, with source paints kept per pack and mode.

Raft: Web v1.21.23 Drawer popup/DialogSurface, ThreadPanel.tsx:2318/2526,
ExternalIdentityDetailPanel.tsx:74, ChannelMembers Card and PanelHeader.
These are aliases of existing colours; this table introduces no palette value.
"""


def surface_colors(column, colors):
    dark = column.endswith('Dark')
    content = colors['layer-canvas']
    return {
        'layer-drawer': colors['layer-popover'],
        'layer-drawer-header': colors['layer-popover'],
        'layer-dialog': colors['layer-popover'],
        'layer-conversation-content': content,
        # The light tab page overlays its parent without adding a paint layer.
        'layer-conversation-tab-page': content if dark else '#00000000',
        'layer-profile-content': content,
        'layer-member-list': colors['layer-card'],
        'layer-member-header': colors['layer-canvas'],
        # Web SettingsPanel uses canvas for both content contexts. a57
        # settings_layout.dart:410 keeps ordinary content on panel; only
        # feedbackSurface (:351) switches to card in dark mode.
        'layer-settings-card': colors['layer-card'],
        'layer-settings-content': colors['layer-canvas'],
        'layer-settings-feedback-content': content,
    }
