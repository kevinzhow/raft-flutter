"""Component surface aliases, with source paints kept per pack and mode.

Raft: Web v1.21.23 Drawer popup/DialogSurface, ThreadPanel.tsx:2318/2526,
ExternalIdentityDetailPanel.tsx:74, ChannelMembers Card and PanelHeader.
Families: a57b9dab channel_overflow_sheet.dart:76/234/1043,
dialog_card.dart:485 (Card root is layerPanel), forward_desktop_dialog.dart:18,
conversation_surface.dart:20, channel_members_view.dart:365/843.
These are aliases of existing colours; this table introduces no palette value.
"""


def surface_colors(column, colors):
    raft = column.startswith('raft')
    dark = column.endswith('Dark')
    brutal = column == 'brutal'
    content = colors['layer-canvas' if raft else 'layer-card' if dark else 'layer-panel']
    return {
        'layer-drawer': colors['layer-popover' if raft else 'brutal-cream' if brutal else 'layer-panel'],
        'layer-drawer-header': colors['layer-popover' if raft else 'color-soft-signal' if brutal else 'layer-panel'],
        'layer-dialog': colors['layer-popover' if raft else 'layer-panel'],
        'layer-conversation-content': content,
        # The light tab page overlays its parent without adding a paint layer.
        'layer-conversation-tab-page': content if dark else '#00000000',
        'layer-profile-content': content,
        'layer-member-list': colors['layer-card' if raft else 'layer-panel'],
        'layer-member-header': colors['layer-canvas' if raft else 'color-soft-signal' if brutal else 'layer-inset'],
        # Web SettingsPanel uses canvas for both content contexts. a57
        # settings_layout.dart:410 keeps ordinary content on panel; only
        # feedbackSurface (:351) switches to card in dark mode.
        'layer-settings-card': colors['layer-card' if raft else 'layer-panel'],
        'layer-settings-content': colors['layer-canvas' if raft else 'layer-panel'],
        'layer-settings-feedback-content': content,
    }
