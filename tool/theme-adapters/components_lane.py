"""Shared-component theme tokens (the "components" lane of the Web v1.21.23 alignment).

One file so the component work adds its tokens without touching the shared tables:
build_raft_pack.py and build_family_packs.py each call into it from a few lines.
Raft values follow the Web v1.21.23 render; the Elegant / Brutal column keeps the
pre-theme (a57b9dab) value of the same token, so those looks do not move.

Nothing here branches on a theme name: a token has one value per pack, a component
reads the token. Every entry says where the number comes from.
"""

from __future__ import annotations

# ---------------------------------------------------------------- geometry
# token: (Raft, Elegant and Brutal)
_GEOMETRY = {
    # ConversationPanelFooter: `bg-layer-canvas`, no rule above it (raft-ui 0.7
    # `conversationPanel.footer`); a57b9dab drew `border-t border-line-muted`.
    'stroke.channelFooter': (0, 1),
}

# ---------------------------------------------------------------- options
# option: (Raft, Elegant and Brutal)
_OPTIONS = {
    # Toast: raft-ui 0.7 `toastStyles` as LocalizedToastProvider wraps it (a neutral
    # HUD, a 9px status pixel, a bare X); a57b9dab paints the generated recipe.
    'toast.style': ('hud', 'recipe'),
    # RaftRecipeButton (the product-dialog button): the ported raft-ui Button surface
    # (the one RaftButton paints) in Raft; the generated recipe before.
    'button.surface': ('ported', 'recipe'),
    # Banner: raft-ui 0.7 `banner` (one box, only padding / gap / text per density,
    # BannerAction in its own row, description font-normal); the recipe before.
    'banner.style': ('raft', 'recipe'),
    # The Join CTA of the channel footer: `Button size="lg"` (v1.21.23); `md` before.
    'channelFooter.joinSize': ('lg', 'md'),
    # Composer attachments: raft-ui 0.7 `composerAttachment` (fill-muted chips with a
    # hairline, an always-visible remove square, layer-card washes, a soft failure
    # row); the generated recipe before.
    'composerAttachment.style': ('raft', 'recipe'),
    # Skeleton: raft-ui 0.7 `skeleton` (a `fill-muted` block with the sticker radius for
    # line, block and circle alike); black/10 squares and ink-ringed circles before.
    'skeleton.style': ('raft', 'recipe'),
    # SurfaceListItem: raft-ui 0.7 `Card variant="default"` with `bg-info-soft` when
    # selected and a press overlay on hover (the hairline never changes); the
    # recipe card with a coloured selected border and shadow before.
    'surfaceItem.style': ('raft', 'recipe'),
    # AvatarListRow: a raft-ui `ListRow` (16/24 600 title, Space Mono meta, hairline
    # rules from the text edge) inside a `ListRowGroup`; a bordered surface card each before.
    'avatarListRow.style': ('raft', 'recipe'),
    # SelectionPopover: v1.21.23 `SelectionPopoverSections` (caption title and
    # underlined Clear, a 40px search row with a hairline, 36px rounded rows, a 16px
    # check, brand-soft hover); the bordered card with 36px divided rows before.
    'selectionPopover.style': ('raft', 'recipe'),
    # ProgressBar: raft-ui 0.7 `progress` (13/18 semibold label, mono hint value, an
    # 8px fill-muted track, an info / success / warning indicator ringed in
    # sticker-ink); the generated recipe with a mono muted label before.
    'progress.style': ('raft', 'recipe'),
    # MenuItem (product `ui/MenuItem`): `min-h-9 gap-2.5 rounded-control px-2.5 py-1.5`,
    # callout medium ink, `hover:bg-brand-soft`; the ghost `sm` button recipe before.
    'menuItem.style': ('raft', 'recipe'),
}

# Allowed values per option, merged into raftStructuralOptions (theme_pack.dart).
OPTION_VALUES = {
    'toast.style': ('hud', 'recipe'),
    'button.surface': ('ported', 'recipe'),
    'banner.style': ('raft', 'recipe'),
    'channelFooter.joinSize': ('lg', 'md'),
    'composerAttachment.style': ('raft', 'recipe'),
    'skeleton.style': ('raft', 'recipe'),
    'surfaceItem.style': ('raft', 'recipe'),
    'avatarListRow.style': ('raft', 'recipe'),
    'selectionPopover.style': ('raft', 'recipe'),
    'progress.style': ('raft', 'recipe'),
    'menuItem.style': ('raft', 'recipe'),
}

# ---------------------------------------------------------------- colours
# role: (Raft source role, family source role). Values are existing roles.
_COLOR_ALIASES = {
    # The Join footer's guest explanation: `text-caption text-foreground-hint`
    # (Raft); `text-foreground-muted` before.
    'foreground-channel-footer-note': ('foreground-hint', 'foreground-muted'),
}


def geometry_raft() -> dict:
    return {k: v[0] for k, v in _GEOMETRY.items()}


def geometry_family() -> dict:
    return {k: v[1] for k, v in _GEOMETRY.items()}


def options_raft() -> dict:
    return {k: v[0] for k, v in _OPTIONS.items()}


def options_family() -> dict:
    return {k: v[1] for k, v in _OPTIONS.items()}


def raft_aliases(colors: dict) -> None:
    for role, (raft, _) in _COLOR_ALIASES.items():
        colors[role] = colors[raft]


def family_aliases(colors: dict) -> None:
    for role, (_, family) in _COLOR_ALIASES.items():
        colors[role] = colors[family]
