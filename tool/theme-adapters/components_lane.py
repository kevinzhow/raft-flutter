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
    # PopoverSurface (menus, hover cards, popups): raft-ui 0.7 popover
    # `rounded-container ring-1 ring-line-seam shadow-float`; a57b9dab drew a 6px
    # corner without a ring.
    'radius.popover': (10, 6),
    'stroke.popoverRing': (1, 0),
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
    # FormField / Field: raft-ui 0.7 `field` (label footnote 13 semibold leading-none,
    # hint caption, error caption semibold, 6px gaps); a 14/20 label, 4px margins
    # and a mt-1 message before.
    'field.layout': ('raft', 'recipe'),
    # InputGroup / PrefixedInput / SlugInput: raft-ui 0.7 `inputGroup` (h-11, 1.5px
    # line-strong border, rounded-control, a fill-muted addon with a hairline, the
    # field type step); the generated group recipe before.
    'inputGroup.style': ('raft', 'recipe'),
    # AnnouncementDialog (raft-ui wip `announcement`): px-5 py-5 body, a status-pixel
    # label, `text-headline` title, `text-subhead` muted copy, no footer rule;
    # the px-7 recipe card with an accent dot and a `text-2xl` title before.
    'announcement.style': ('raft', 'recipe'),
    # Reaction chips (MessageReactionChip / AddButton): raft-ui 0.7 `messageReaction`
    # (h-6, rounded-chip, pl-1.5 pr-2, bg-fill-muted, mono-meta bold count,
    # attention-soft when mine, warning-soft on error); the mounted 20px chip before.
    'reaction.style': ('raft', 'recipe'),
    # Lightbox / attachment preview chrome: raft-ui 0.7 `lightbox` (pack backdrop,
    # `text-headline font-bold` title, ghost icon buttons, line-seam rule);
    # `bg-black/75`, a 14/20 title and outlined icon buttons before.
    'lightbox.style': ('raft', 'recipe'),
    # Document previews (csv / xlsx / text panes): raft-ui 0.7 card (rounded-container,
    # hairlines, fill-muted header and stripes, mono-meta cells); square panes before.
    'document.style': ('raft', 'recipe'),
    # Message hover toolbar: raft-ui 0.7 `messageItem` (`-top-[18px] right-3`, p-[3px],
    # 32px buttons with 18px glyphs, ring-1 line-seam + shadow-float, a fill-pressed
    # row wash); the 28px strip inside the row before.
    'messageToolbar.style': ('raft', 'recipe'),
    # Tooltip: raft-ui 0.7 `tooltip` (`rounded-chip bg-layer-hud shadow-float`, the
    # pack's float elevation); the hard-coded Elegant triple shadow before.
    'tooltip.style': ('raft', 'recipe'),
    # A person without a picture: AvatarSlot's Gravatar fallback is the person glyph
    # in v1.21.23; a57b9dab drew the initials.
    'avatar.humanFallback': ('icon', 'initials'),
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
    'field.layout': ('raft', 'recipe'),
    'inputGroup.style': ('raft', 'recipe'),
    'announcement.style': ('raft', 'recipe'),
    'reaction.style': ('raft', 'recipe'),
    'lightbox.style': ('raft', 'recipe'),
    'document.style': ('raft', 'recipe'),
    'messageToolbar.style': ('raft', 'recipe'),
    'tooltip.style': ('raft', 'recipe'),
    'avatar.humanFallback': ('icon', 'initials'),
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
