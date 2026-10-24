#!/usr/bin/env python3
"""Build the built-in Elegant and Brutal theme packs from the P0 contract data.

These packs are the contract's second and third citizens:

  packages/raft_theme/assets/themes/elegant.theme.json
  packages/raft_theme/assets/themes/brutal.theme.json

Both extend `raft`, so a pack carries only what differs from Raft. That is
deliberate (contract §5 rule 1): when the upstream Raft look gains a token,
these two do not break — they inherit it instead of missing a value.

Sources, all read out of the tree, nothing hand-copied except the tables marked
AUTHORED (which cite the contract section they come from):

  docs/theme-contract/values.json   colours + elevation + type, generated from
                                    a57b9dab by tool/theme-contract/dump_theme_values.py
  docs/theme-contract.md §3.1–3.5   geometry per theme
  docs/theme-contract.md §4         the structural options per theme

  python3 tool/theme-adapters/build_family_packs.py           # write the packs
  python3 tool/theme-adapters/build_family_packs.py --check   # exit 1 when stale
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

from button_contract import button_colors, button_palette

ROOT = pathlib.Path(__file__).resolve().parents[2]
VALUES = 'docs/theme-contract/values.json'
THEMES = 'packages/raft_theme/assets/themes'
PACK_FORMAT = 'raft-theme/1'

# AUTHORED: docs/theme-contract.md §4, one row per option. Raft's values live in
# build_raft_pack.py's OPTIONS_RAFT; these two are the same table's other columns.
OPTIONS_ELEGANT = {
    'mobileNav.boxLayout': 'natural', 'mobileNav.textLayout': 'natural',
    'mobileNav.selection': 'cell',
    'button.hoverSurface': 'variant',
    'button.linkDecoration': 'none',
    'button.linkPadding': 'size',
    'button.disabledSurface': 'opacity', 'button.xsLine': 'inherited',
    'messageHeader.timePosition': 'inline',
    'messageHeader.align': 'baseline',
    'control.edge': 'ring', 'sticker.ring': 'none', 'emphasis.fill': 'soft',
    'iconButton.surface': 'generic', 'panelAction.surface': 'outline',
    # a57b9dab design_primitives.dart:141-145; resource_view.dart:2385,2393.
    'sidebar.mobileSurface': 'sidebar', 'resource.surface': 'sidebar',
    'resource.rows': 'cards', 'resource.badge': 'pill', 'resource.markRead': 'outline',
    'listGroup.frame': 'framed', 'task.status': 'symbol', 'searchResult.selection': 'card', 'messageReference.chipLayout': 'intrinsic', 'messageMenu.reactionDivider': 'hidden',
    'press.effect': 'scale', 'control.sheen': 'gradient', 'avatar.shape': 'circle',
    'indicator.border': 'none', 'switch.shape': 'pill', 'checkbox.mark': 'strokeCheck',
    'field.style': 'inset', 'tabs.selected': 'tint', 'segmented.selected': 'tint',
    # a57b9dab draws a flat row of separate segments: no rounded, padded track.
    'segmented.frame': 'separate',
    'mobileNav.style': 'floatingCapsule', 'mobileNav.labels': 'iconsOnly',
    'header.layout': 'overlay', 'panel.edge': 'seam', 'nav.selection': 'softFill',
    'tooltip.arrow': 'yes', 'code.innerBorder': 'dashed', 'spinner.style': 'ring',
    'dialog.close': 'ghost', 'dialog.cancelSurface': 'outline',
    'banner.iconAlignment': 'center', 'banner.iconColor': 'intent', 'confirm.slug': 'text',
    'confirm.explanation': 'plain',
    'spinner.ringShape': 'sweep', 'spinner.foreground': 'inherited',
    'toast.style': 'recipe',
}
OPTIONS_BRUTAL = {
    'mobileNav.boxLayout': 'natural', 'mobileNav.textLayout': 'natural',
    'mobileNav.selection': 'cell',
    'button.hoverSurface': 'variant',
    'button.linkDecoration': 'none',
    'button.linkPadding': 'size',
    'button.disabledSurface': 'opacity', 'button.xsLine': 'inherited',
    'messageHeader.timePosition': 'inline',
    'messageHeader.align': 'center',
    'control.edge': 'inkBorder', 'sticker.ring': 'none', 'emphasis.fill': 'solid',
    'iconButton.surface': 'raised', 'panelAction.surface': 'outline',
    'sidebar.mobileSurface': 'canvas', 'resource.surface': 'canvas',
    'resource.rows': 'cards', 'resource.badge': 'pill', 'resource.markRead': 'outline',
    'listGroup.frame': 'framed', 'task.status': 'symbol', 'searchResult.selection': 'card', 'messageReference.chipLayout': 'intrinsic', 'messageMenu.reactionDivider': 'hidden',
    'press.effect': 'offsetShadow', 'control.sheen': 'none', 'avatar.shape': 'square',
    'indicator.border': 'ink', 'switch.shape': 'square', 'checkbox.mark': 'thickStroke',
    'field.style': 'border', 'tabs.selected': 'sticker', 'segmented.selected': 'sticker',
    'segmented.frame': 'separate',
    'mobileNav.style': 'docked', 'mobileNav.labels': 'withLabels', 'header.layout': 'inFlow',
    'panel.edge': 'border', 'nav.selection': 'sticker', 'tooltip.arrow': 'no',
    'code.innerBorder': 'solid', 'spinner.style': 'ring',
    'dialog.close': 'outline', 'dialog.cancelSurface': 'outline',
    'banner.iconAlignment': 'center', 'banner.iconColor': 'foreground', 'confirm.slug': 'text',
    'confirm.explanation': 'plain',
    'spinner.ringShape': 'quarter', 'spinner.foreground': 'fixed',
    'toast.style': 'recipe',
}

# AUTHORED: docs/theme-contract.md §3.1–3.3. Values marked † in the contract are
# digits that the P2 baseline can now confirm or refute; they are carried as-is
# until that reconciliation, which is its own change.
GEOMETRY_ELEGANT = {
    # MobileNav: Web v1.21.23 / a57b9dab mobile_navigation.dart.
    'space.mobileNavInline': 0,
    'space.mobileNavTop': 0,
    'stroke.mobileNavTop': 2,
    'stroke.mobileNavBottom': 2,
    'stroke.mobileNavDivider': 2,
    'size.mobileNavGlyph': 18,
    'size.mobileNavItem': 51,
    'size.mobileNavItemCompact': 31,
    'size.mobileNavGlyphHideHeight': 600,
    'space.mobileNavItemTop': 8,
    'space.mobileNavGlyphLabel': 2,
    'type.mobileNavLabel.size': 10,
    'type.mobileNavLabel.line': 15,
    'type.mobileNavLabel.weight': 400,
    'type.mobileNavLabelSelected.weight': 400,
    'type.mobileNavLabel.tracking': 0.5,
    'size.mobileNavStickerWidth': 56,
    'size.mobileNavStickerHeight': 30,
    'radius.mobileNavSticker': 0,
    'stroke.mobileNavSticker': 0,
    'stroke.mobileNavStickerRing': 0,
    'size.mobileNavSafeMax': 34,

    'size.fieldInput': 38, 'size.fieldSelect': 36,
    'type.fieldLabel.size': 14, 'type.fieldLabel.line': 20, 'type.fieldLabel.weight': 700,
    'space.fieldGap': 6, 'space.fieldLabelAccessoryOutset': 0,
    # Shared Button source metrics, Cindy a0741fbf/c1ec691c.
    'size.control.xs': 24,
    'type.button.xs.size': 11,
    'type.button.sm.size': 12,
    'type.button.md.size': 14,
    'type.button.lg.size': 16,
    'type.button.sm.line': 16,
    'type.button.md.line': 20,
    'type.button.lg.line': 24,
    'type.button.weight': 500,
    'space.buttonInline.xs': 8,
    'space.buttonInline.sm': 10,
    'space.buttonInline.lg': 14,
    'space.buttonGap.xs': 4,
    'space.buttonGap.sm': 5,
    'space.buttonGap.md': 5.5,
    'space.buttonGap.lg': 6,
    'size.buttonGlyph.xs': 12,
    'size.buttonGlyph.sm': 14,
    'size.buttonGlyph.lg': 16,
    'size.buttonGlyph.iconMd': 16,
    'size.buttonGlyph.iconLg': 16,
    'size.buttonGlyph.iconXs': 12,
    'size.buttonGlyph.iconSm': 14,
    'opacity.buttonDisabled': 0.4,
    # Confirmation / Banner source contract, Cindy fe0074f6.
    'stroke.dialog': 0,
    'stroke.dialogRing': 0,
    'space.bannerInline': 12,
    'space.bannerGap': 8,
    'type.bannerBody.line': 16,
    'type.bannerBody.size': 13,
    'type.bannerBody.tracking': -0.065,
    'size.bannerGlyph': 16,
    'radius.banner': 4,
    'stroke.bannerBorder': 0,
    'stroke.bannerRing': 0,
    'type.confirmBody.size': 14,
    'type.confirmBody.line': 22.75,
    'type.confirmName.weight': 700,
    'type.confirmPrompt.size': 14,
    'type.confirmPrompt.line': 20,
    'type.confirmPrompt.weight': 400,
    'type.confirmSlug.size': 14,
    'type.confirmSlug.weight': 700,
    'space.confirmSlugInline': 0,
    'size.confirmAction': 28,
    # Shared Dialog slots, Web 0.7.0 / a57 runtime probes; Cindy 046ef0f7.
    'space.dialogContentInline': 0,
    'space.dialogContentBlock': 0,
    'space.dialogPartGap': 0,
    'space.dialogHeaderInline': 24,
    'space.dialogHeaderTop': 12,
    'space.dialogHeaderBottom': 12,
    'space.dialogHeaderGap': 12,
    'space.dialogBodyInline': 24,
    'space.dialogBodyTop': 20,
    'space.dialogBodyBottom': 20,
    'space.dialogFooterInline': 24,
    'space.dialogFooterTop': 12,
    'space.dialogFooterBottom': 12,
    'space.dialogFooterGap': 12,
    'type.dialogTitle.size': 16,
    'type.dialogTitle.line': 24,
    'size.dialogClose': 28,
    'size.dialogCloseGlyph': 16,
    'space.dialogCloseOutset': 0,
    'blur.dialogBackdrop': 2,
    # ComposerToolbarLabel / shared CheckboxIndicator, Cindy fc426a64.
    'size.composerTaskToggle': 16,
    'size.composerTaskCheckbox': 14,
    'space.composerTaskGap': 6,
    'type.composerTaskLabel.size': 12,
    'type.composerTaskLabel.line': 16,
    'type.composerTaskLabel.weight': 700,

    # Web 0.7.0 + actual a57 composer probes; Cindy 16e23df0.
    'space.composerShellInline': 0,
    'space.composerShellTop': 0,
    'space.composerShellBottom': 0,
    'space.composerEditorInline': 12,
    'space.composerEditorTop': 12,
    'space.composerToolbarInline': 10,
    'space.composerToolbarTop': 4,
    'space.composerToolbarBottom': 10,
    'space.composerToolbarShiftY': 4,
    'space.composerFirstActionOffset': 0,
    'space.composerActionGap': 6,
    'space.composerMetaGap': 12,
    'size.composerEditorMinimumDesktop': 40,
    'size.composerAction': 28,
    'size.composerSubmit': 28,
    'size.composerGlyph': 14,
    'type.composerNotice.size': 12,
    'type.composerNotice.line': 16,
    'type.composerNotice.weight': 700,
    'radius.composerNotice': 4,
    'stroke.composerNotice': 0,
    'space.composerNoticeTop': 10,
    'space.composerNoticeEnd': 8,
    'space.composerNoticeBottom': 10,
    'space.composerNoticeStart': 10,

    # Web appearanceStore.ts / pre-theme display tiers (Cindy 5eef1cad/4e2f12b0).
    'type.messageBody.sm.size': 12, 'type.messageBody.sm.line': 16,
    'type.messageBody.md.size': 14, 'type.messageBody.md.line': 20,
    'type.messageBody.lg.size': 16, 'type.messageBody.lg.line': 24,
    'type.messageSender.sm.size': 12, 'type.messageSender.md.size': 14, 'type.messageSender.lg.size': 16,
    'type.messageMeta.lg.size': 14, 'type.messagePreview.sm.size': 11,
    'type.messagePreview.md.size': 12.5, 'type.messagePreviewTime.md.size': 11.5,
    'type.messageSender.sm.line': 12, 'type.messageSender.md.line': 14, 'type.messageSender.lg.line': 16,
    'type.messageSender.weight': 500, 'type.messageBody.tracking': -.01,
    # a57b9dab switch/control bounds; 0 keeps the Raft hit-only expander.
    'size.touchLayoutMin': 48,
    # a57b9dab AvatarSlot profileTile and panelHeader.
    'size.avatar.profileHero': 64, 'size.avatar.profileTile': 64, 'size.avatar.panelHeader': 36,
    # SettingsProfileCard source values, approved Cindy 318b1d17.
    'radius.settingsCard': 0,
    # Original Select trigger measurement: 32px, 14/20 medium in both families.
    'size.selectTrigger': 32, 'type.selectValue.size': 14, 'type.selectValue.weight': 500, 'type.selectValue.tracking': -.005, 'type.selectPlaceholder.weight': 500,
    # a57b9dab measured Select values; disabled:opacity-40 (not .5).
    'opacity.selectDisabled': .4, 'space.selectTriggerStart': 12,
    'size.selectChevron': 14, 'stroke.selectChevron': 1.5,
    # Pure MenuItem action rows; separate from selection menuRow (Cindy 4e51e70c).
    'size.menuActionRow': 28, 'size.menuActionRowCompact': 28, 'size.menuPopupMin': 192,
    # Current Web MessageInput / a57 legacy composer, approved Cindy 27a5a99c.
    'space.composerHostInline': 12, 'space.composerHostTop': 12,
    'type.composerInput.line': 20, 'type.composerInputDesktop.size': 14,
    'type.settingsCardTitle.size': 18, 'type.settingsCardTitle.line': 22.5,
    'type.settingsCardMeta.size': 14, 'type.settingsCardMeta.line': 20,
    # a57b9dab switch.dart:65-81 and primitive_tokens.dart:12.
    'size.switch.width.sm': 28, 'size.switch.width.md': 36,
    'size.switch.height.sm': 16, 'size.switch.height.md': 20,
    'size.switch.thumb.sm': 12, 'size.switch.thumb.md': 16,
    'space.switchInset': 2, 'motion.switchSlideMs': 180, 'motion.switchColorMs': 180,
    'radius.sticker': 3, 'radius.chip': 4, 'radius.control': 6, 'radius.controlSmall': 4,
    'radius.container': 8, 'radius.dialog': 8, 'radius.sheet': 16, 'radius.tooltip': 6,
    'radius.item': 2, 'radius.pill': 999, 'radius.avatar': 999, 'radius.rail': 8,
    # a57b9dab rounds the inner container with the same expression as the outer
    # (size/2), so the content is circular too.
    'radius.avatarInner': 999,
    'radius.field': 6,
    'stroke.hairline': 0.5, 'stroke.control': 0, 'stroke.container': 1, 'stroke.rule': 1,
    # a57b9dab RaftButtonRecipe.resolve: sm 28, md 32, lg 36.
    'size.control.sm': 28, 'size.control.md': 32, 'size.control.lg': 36,
    'size.control.onFrame': 32, 'size.field': 36, 'size.panelHeader': 56, 'size.rail': 56,
    'size.railGlyph': 16, 'size.navRow': 34, 'size.navRowCompact': 30,
    'size.menuRow': 31.5, 'size.menuRowCompact': 27.5, 'size.drawer': 380,
    # a57b9dab keeps Elegant's rail at one width on short viewports.
    'size.railShort': 56,
    # a57b9dab: Elegant keeps its regular row at desktop width.
    'size.navRowWide': 34,
    'space.controlX': 6, 'space.itemX': 10, 'space.inset.panel': 26,
    # a57b9dab `gap-1.5` between segments, at --spacing 0.25rem.
    'space.segmentGap': 6,
}
GEOMETRY_BRUTAL = {
    # MobileNav: Web v1.21.23 / a57b9dab mobile_navigation.dart.
    'space.mobileNavInline': 0,
    'space.mobileNavTop': 0,
    'stroke.mobileNavTop': 2,
    'stroke.mobileNavBottom': 2,
    'stroke.mobileNavDivider': 2,
    'size.mobileNavGlyph': 18,
    'size.mobileNavItem': 51,
    'size.mobileNavItemCompact': 31,
    'size.mobileNavGlyphHideHeight': 600,
    'space.mobileNavItemTop': 8,
    'space.mobileNavGlyphLabel': 2,
    'type.mobileNavLabel.size': 10,
    'type.mobileNavLabel.line': 15,
    'type.mobileNavLabel.weight': 400,
    'type.mobileNavLabelSelected.weight': 400,
    'type.mobileNavLabel.tracking': 0.5,
    'size.mobileNavStickerWidth': 56,
    'size.mobileNavStickerHeight': 30,
    'radius.mobileNavSticker': 0,
    'stroke.mobileNavSticker': 0,
    'stroke.mobileNavStickerRing': 0,
    'size.mobileNavSafeMax': 34,

    'size.fieldInput': 44, 'size.fieldSelect': 44,
    'type.fieldLabel.size': 14, 'type.fieldLabel.line': 20, 'type.fieldLabel.weight': 700,
    'space.fieldGap': 4, 'space.fieldLabelAccessoryOutset': 0,
    # Shared Button source metrics, Cindy a0741fbf/c1ec691c.
    'size.control.xs': 24,
    'type.button.xs.size': 11,
    'type.button.sm.size': 12,
    'type.button.md.size': 14,
    'type.button.lg.size': 14,
    'type.button.sm.line': 16,
    'type.button.md.line': 20,
    'type.button.lg.line': 20,
    'type.button.weight': 700,
    'space.buttonInline.xs': 8,
    'space.buttonInline.sm': 10,
    'space.buttonInline.lg': 16,
    'space.buttonGap.xs': 4,
    'space.buttonGap.sm': 5,
    'space.buttonGap.md': 5.5,
    'space.buttonGap.lg': 6,
    'size.buttonGlyph.xs': 12,
    'size.buttonGlyph.sm': 14,
    'size.buttonGlyph.lg': 16,
    'size.buttonGlyph.iconMd': 16,
    'size.buttonGlyph.iconLg': 16,
    'size.buttonGlyph.iconXs': 12,
    'size.buttonGlyph.iconSm': 14,
    'opacity.buttonDisabled': 0.4,
    # Confirmation / Banner source contract, Cindy fe0074f6.
    'stroke.dialog': 2,
    'stroke.dialogRing': 0,
    'space.bannerInline': 12,
    'space.bannerGap': 12,
    'type.bannerBody.line': 20,
    'type.bannerBody.size': 14,
    'type.bannerBody.tracking': 0,
    'size.bannerGlyph': 18,
    'radius.banner': 0,
    'stroke.bannerBorder': 2,
    'stroke.bannerRing': 0,
    'type.confirmBody.size': 14,
    'type.confirmBody.line': 22.75,
    'type.confirmName.weight': 700,
    'type.confirmPrompt.size': 14,
    'type.confirmPrompt.line': 20,
    'type.confirmPrompt.weight': 400,
    'type.confirmSlug.size': 14,
    'type.confirmSlug.weight': 700,
    'space.confirmSlugInline': 0,
    'size.confirmAction': 28,
    # Shared Dialog slots, Web 0.7.0 / a57 runtime probes; Cindy 046ef0f7.
    'space.dialogContentInline': 24,
    'space.dialogContentBlock': 16,
    'space.dialogPartGap': 16,
    'space.dialogHeaderInline': 0,
    'space.dialogHeaderTop': 0,
    'space.dialogHeaderBottom': 0,
    'space.dialogHeaderGap': 12,
    'space.dialogBodyInline': 0,
    'space.dialogBodyTop': 8,
    'space.dialogBodyBottom': 8,
    'space.dialogFooterInline': 0,
    'space.dialogFooterTop': 0,
    'space.dialogFooterBottom': 0,
    'space.dialogFooterGap': 12,
    'type.dialogTitle.size': 18,
    'type.dialogTitle.line': 18,
    'size.dialogClose': 32,
    'size.dialogCloseGlyph': 20,
    'space.dialogCloseOutset': 0,
    'blur.dialogBackdrop': 0,
    # ComposerToolbarLabel / shared CheckboxIndicator, Cindy fc426a64.
    'size.composerTaskToggle': 16,
    'size.composerTaskCheckbox': 14,
    'space.composerTaskGap': 6,
    'type.composerTaskLabel.size': 12,
    'type.composerTaskLabel.line': 16,
    'type.composerTaskLabel.weight': 700,

    # Web 0.7.0 + actual a57 composer probes; Cindy 16e23df0.
    'space.composerShellInline': 8,
    'space.composerShellTop': 8,
    'space.composerShellBottom': 8,
    'space.composerEditorInline': 0,
    'space.composerEditorTop': 0,
    'space.composerToolbarInline': 0,
    'space.composerToolbarTop': 0,
    'space.composerToolbarBottom': 0,
    'space.composerToolbarShiftY': 0,
    'space.composerFirstActionOffset': 0,
    'space.composerActionGap': 8,
    'space.composerMetaGap': 12,
    'size.composerEditorMinimumDesktop': 40,
    'size.composerAction': 26,
    'size.composerSubmit': 28,
    'size.composerGlyph': 14,
    'type.composerNotice.size': 12,
    'type.composerNotice.line': 16,
    'type.composerNotice.weight': 700,
    'radius.composerNotice': 0,
    'stroke.composerNotice': 2,
    'space.composerNoticeTop': 8,
    'space.composerNoticeEnd': 8,
    'space.composerNoticeBottom': 8,
    'space.composerNoticeStart': 8,

    # Web appearanceStore.ts / pre-theme display tiers (Cindy 5eef1cad/4e2f12b0).
    'type.messageBody.sm.size': 12, 'type.messageBody.sm.line': 16,
    'type.messageBody.md.size': 14, 'type.messageBody.md.line': 20,
    'type.messageBody.lg.size': 16, 'type.messageBody.lg.line': 24,
    'type.messageSender.sm.size': 12, 'type.messageSender.md.size': 14, 'type.messageSender.lg.size': 16,
    'type.messageMeta.lg.size': 14, 'type.messagePreview.sm.size': 11,
    'type.messagePreview.md.size': 12.5, 'type.messagePreviewTime.md.size': 11.5,
    'type.messageSender.sm.line': 20, 'type.messageSender.md.line': 20, 'type.messageSender.lg.line': 20,
    'type.messageSender.weight': 700, 'type.messageBody.tracking': 0,
    # a57b9dab switch/control bounds; 0 keeps the Raft hit-only expander.
    'size.touchLayoutMin': 48,
    # a57b9dab AvatarSlot profileTile and panelHeader.
    'size.avatar.profileHero': 64, 'size.avatar.profileTile': 64, 'size.avatar.panelHeader': 36,
    # SettingsProfileCard source values, approved Cindy 318b1d17.
    'radius.settingsCard': 0,
    # Original Select trigger measurement: 32px, 14/20 medium in both families.
    'size.selectTrigger': 32, 'type.selectValue.size': 14, 'type.selectValue.weight': 700, 'type.selectValue.tracking': 0, 'type.selectPlaceholder.weight': 700,
    # a57b9dab measured Select values; disabled:opacity-40 (not .5).
    'opacity.selectDisabled': .4, 'space.selectTriggerStart': 12,
    'size.selectChevron': 14, 'stroke.selectChevron': 1.5,
    # Pure MenuItem action rows; separate from selection menuRow (Cindy 4e51e70c).
    'size.menuActionRow': 28, 'size.menuActionRowCompact': 28, 'size.menuPopupMin': 192,
    # Current Web MessageInput / a57 legacy composer, approved Cindy 27a5a99c.
    'space.composerHostInline': 12, 'space.composerHostTop': 12,
    'type.composerInput.line': 20, 'type.composerInputDesktop.size': 14,
    'type.settingsCardTitle.size': 18, 'type.settingsCardTitle.line': 22.5,
    'type.settingsCardMeta.size': 14, 'type.settingsCardMeta.line': 20,
    # a57b9dab switch.dart:65-81 and primitive_tokens.dart:12.
    'size.switch.width.sm': 28, 'size.switch.width.md': 36,
    'size.switch.height.sm': 16, 'size.switch.height.md': 20,
    'size.switch.thumb.sm': 10, 'size.switch.thumb.md': 14,
    'space.switchInset': 3, 'motion.switchSlideMs': 180, 'motion.switchColorMs': 180,
    'radius.sticker': 0, 'radius.chip': 0, 'radius.control': 0, 'radius.controlSmall': 0,
    'radius.container': 0, 'radius.dialog': 0, 'radius.sheet': 0, 'radius.tooltip': 0,
    'radius.item': 0, 'radius.pill': 0, 'radius.avatar': 0, 'radius.rail': 0,
    'radius.avatarInner': 0,
    'radius.field': 0,
    'stroke.hairline': 1, 'stroke.control': 2, 'stroke.container': 2, 'stroke.rule': 2,
    # a57b9dab RaftButtonRecipe.resolve: sm 28, md 32, lg 40.
    'size.control.sm': 28, 'size.control.md': 32, 'size.control.lg': 40,
    'size.control.onFrame': 32, 'size.field': 40, 'size.panelHeader': 62, 'size.rail': 64,
    'size.railGlyph': 18, 'size.navRow': 40, 'size.navRowCompact': 32,
    'size.menuRow': 36, 'size.menuRowCompact': 28,
    # Measured: a57b9dab's drawer/profile width is a flat 380 in every family
    # (adaptive_workspace.dart profileWidth default; no theme branch). The 420 the
    # contract carried had no source.
    'size.drawer': 380,
    # a57b9dab: Brutal narrows its rail to 50 below 600px tall.
    'size.railShort': 50,
    # a57b9dab: Brutal uses its compact row at desktop width.
    'size.navRowWide': 32,
    'space.controlX': 8, 'space.itemX': 12, 'space.inset.panel': 8,
    # a57b9dab `gap-1` between segments.
    'space.segmentGap': 4,
}

# AUTHORED: docs/theme-contract.md §3.5. The contract fixes three slots; a theme
# that has no opinion leaves the string alone.
CASE_ELEGANT = {'dialogShellTitle': 'uppercase','heading': 'none', 'label': 'uppercase', 'badge': 'none'}
CASE_BRUTAL = {'dialogShellTitle': 'uppercase','heading': 'uppercase', 'label': 'uppercase', 'badge': 'uppercase'}

# AUTHORED: docs/theme-contract.md §5.1. Families come from the P0 inventory;
# the stacks keep the CJK fallbacks the app needs to avoid tofu.

# Message row source contract, Cindy 53e94688.
GEOMETRY_ELEGANT.update({'size.messageRowMin': 48,
 'stroke.messageRow': 1,
 'space.messageRowInline': 28,
 'space.messageRowInlineCompact': 16,
 'space.messageRowInlineThread': 12,
 'space.messageRowTop': 14,
 'space.messageRowTopCompact': 8,
 'space.messageRowContinuationTop': 6,
 'space.messageRowBottom': 12,
 'space.messageRowFollowedGroupBottom': 6,
 'space.messageRowBottomCompact': 6,
 'space.messageRowFollowedCompactBottom': 2,
 'space.messageRowFollowedCompactBottomCompact': 0,
 'space.messageRowMarginInline': 0,
 'space.messageRowMarginTop': 0,
 'space.messageRowMarginBottom': 0,
 'size.messageRowGutter': 36,
 'size.messageRowGutterCompact': 32,
 'size.messageRowAvatar': 36,
 'space.messageRowGapCompact': 8,
 'space.messageHeaderReserve': 96,
 'size.messageHeaderLine': 21,
 'space.messageHeaderGap': 6,
 'space.messageHeaderAfter': 6,
 'space.messageHeaderAfterCompact': 4,
 'space.messageBodyBottom': 6,
 'space.messageBodyBottomCompact': 4,
 'space.messageAttachmentsTop': 4,
 'type.messageMeta.sm.line': 11,
 'type.messageMeta.md.line': 12,
 'type.messageMeta.lg.line': 14,
 'type.messageMeta.tracking': -0.14,
 'size.messageRowAvatarLarge': 36})
GEOMETRY_BRUTAL.update({'size.messageRowMin': 48,
 'stroke.messageRow': 2,
 'space.messageRowInline': 6,
 'space.messageRowInlineCompact': 6,
 'space.messageRowInlineThread': 6,
 'space.messageRowTop': 4,
 'space.messageRowTopCompact': 4,
 'space.messageRowContinuationTop': 4,
 'space.messageRowBottom': 4,
 'space.messageRowFollowedGroupBottom': 4,
 'space.messageRowBottomCompact': 4,
 'space.messageRowFollowedCompactBottom': 4,
 'space.messageRowFollowedCompactBottomCompact': 4,
 'space.messageRowMarginInline': 12,
 'space.messageRowMarginTop': 6,
 'space.messageRowMarginBottom': 4,
 'size.messageRowGutter': 36,
 'size.messageRowGutterCompact': 36,
 'size.messageRowAvatar': 36,
 'space.messageRowGapCompact': 12,
 'space.messageHeaderReserve': 96,
 'size.messageHeaderLine': 20,
 'space.messageHeaderGap': 8,
 'space.messageHeaderAfter': 0,
 'space.messageHeaderAfterCompact': 0,
 'space.messageBodyBottom': 0,
 'space.messageBodyBottomCompact': 0,
 'space.messageAttachmentsTop': 4,
 'type.messageMeta.sm.line': 16,
 'type.messageMeta.md.line': 16,
 'type.messageMeta.lg.line': 16,
 'type.messageMeta.tracking': 0,
 'size.messageRowAvatarLarge': 36})

# Original a57 Spinner geometry and animation, Cindy 63f52c81.
GEOMETRY_ELEGANT.update({
    'size.spinnerDefault': 14, 'duration.spinnerTurn': 1600,
    'stroke.spinnerRing': 0, 'ratio.spinnerRingRadius': 10 / 24,
    'space.spinnerRingInset': 0, 'opacity.spinnerArc': .8,
})
GEOMETRY_BRUTAL.update({
    'size.spinnerDefault': 16, 'duration.spinnerTurn': 1000,
    'stroke.spinnerRing': 2, 'ratio.spinnerRingRadius': .5,
    'space.spinnerRingInset': 1, 'opacity.spinnerArc': 1,
})

FONTS_ELEGANT = {
    'sans': {'family': 'Geist',
             'stack': ['Geist', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei',
                       'Noto Sans SC', 'system-ui', 'sans-serif']},
    'heading': {'family': 'Inter',
                'stack': ['Inter', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei',
                          'Noto Sans SC', 'system-ui', 'sans-serif']},
    'mono': {'family': 'Geist Mono',
             'stack': ['Geist Mono', 'ui-monospace', 'monospace']},
}
# a57b9dab's Brutal look is HankenGrotesk, not Space Grotesk: its generated
# metrics.g.dart sets headingFont and sansFont to `packages/raft_ui/HankenGrotesk`
# (line 59-60). Measured from the P2 baseline metadata too -- a Brutal page there
# reports fontFamily HankenGrotesk while the pack used to claim Space Grotesk.
FONTS_BRUTAL = {
    'sans': {'family': 'HankenGrotesk',
             'stack': ['HankenGrotesk', 'PingFang SC', 'Hiragino Sans GB',
                       'Microsoft YaHei', 'Noto Sans SC', 'system-ui', 'sans-serif']},
    'heading': {'family': 'HankenGrotesk',
                'stack': ['HankenGrotesk', 'PingFang SC', 'Hiragino Sans GB',
                          'Microsoft YaHei', 'Noto Sans SC', 'system-ui', 'sans-serif']},
    # a57 metrics.g.dart:58-61: every original family uses Geist Mono.
    'mono': {'family': 'Geist Mono',
             'stack': ['Geist Mono', 'ui-monospace', 'monospace']},
}

# values.json keys its columns by these names.
COLUMN = {
    'brutal': 'brutal',
    'elegantLight': 'elegantLight',
    'elegantDark': 'elegantDark',
}


def load_values() -> dict:
    return json.loads((ROOT / VALUES).read_text())


_HEX_ALPHA = __import__('re').compile(
    r'^#([0-9a-fA-F]{6})\s*/\s*([0-9]*\.?[0-9]+)$')
# The same pattern anywhere inside a shadow layer list.
_HEX_ALPHA_ANY = __import__('re').compile(
    r'#([0-9a-fA-F]{6})\s*/\s*([0-9]*\.?[0-9]+)')


def shadow(text: str) -> str:
    """Normalise a contract shadow value to the pack's CSS syntax.

    values.json writes a translucent layer as `#rrggbb / 0.07`; the pack parser
    wants `rgba(r g b / a)`. It also writes an absent shadow as an empty string,
    which in pack terms is `none`. Multiple layers are comma-separated and each
    `#rrggbb / alpha` inside them is rewritten, not just a bare colour.
    """
    text = text.strip()
    if not text or text.lower() == 'none':
        return 'none'
    return _HEX_ALPHA_ANY.sub(
        lambda m: 'rgba({} {} {} / {:g})'.format(
            int(m.group(1)[0:2], 16), int(m.group(1)[2:4], 16),
            int(m.group(1)[4:6], 16), float(m.group(2))),
        text,
    )


def color(text: str) -> str:
    """Normalise a contract colour to what the pack parser accepts.

    values.json reports a translucent role as `#rrggbb / 0.60`. The `raft-theme/1`
    parser accepts `#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb()` and `oklch()`. Alpha is
    emitted as `rgb(r g b / a)` rather than `#rrggbbaa`: an 8-bit hex alpha would
    quantise 0.68 to 173/255 and change the painted pixel, which is exactly the
    kind of drift a pixel baseline exists to catch.
    """
    match = _HEX_ALPHA.match(text.strip())
    if not match:
        return text
    digits, alpha = match.group(1), float(match.group(2))
    r, g, b = (int(digits[i:i + 2], 16) for i in (0, 2, 4))
    if alpha >= 1:
        return f'#{digits}'
    return f'rgb({r} {g} {b} / {alpha:g})'


def collect(values: dict, column: str) -> tuple[dict, dict, dict]:
    """Flatten values.json's tiered tables into colors / shadows / type."""
    colors: dict[str, str] = {}
    for tier in values['tiers'].values():
        for entry in tier:
            role = entry['role']
            value = entry.get(column)
            if value:
                colors[role] = color(value)

    shadows = {}
    for name, entry in values['extra']['elevation'].items():
        value = entry.get(column)
        if value is not None:
            shadows[name] = shadow(value)

    # The human-readable dump rounds alpha (e.g. .071 -> .07). Preserve
    # unchanged a57 source values, with file SHA recorded beside the layers.
    original = json.loads((ROOT / 'tool/theme-adapters/original_shadows.json').read_text())
    shadows.update(original['css'][column])

    type_metrics = {}
    for name, entry in values['extra']['type'].items():
        value = entry.get(column)
        if value:
            type_metrics[name] = value
    return colors, shadows, type_metrics


def geometry_with_type(geometry: dict, type_metrics: dict) -> dict:
    """geometry carries the six type metrics too, like the Raft pack."""
    out = dict(geometry)
    for name, value in type_metrics.items():
        if name.startswith('type.'):
            # values.json stores them as strings ("16.0"); the pack wants numbers.
            try:
                out[name] = float(value)
            except ValueError:
                out[name] = value
    return out


def pack(pack_id: str, name_en: str, name_zh: str, values: dict,
         light: dict, dark: dict) -> dict:
    """Build one pack from its light and dark value sets.

    `light` and `dark` each carry the column to read from plus the geometry,
    options, case and fonts for that mode. They are separate because a theme's
    dark look is not always its light look reskinned: Brutal, in the old app,
    drops to the whole Elegant look at night, structure included.
    """
    def mode(spec: dict):
        colors, shadows, type_metrics = collect(values, spec['column'])
        # The dedicated sidebar role preserves the original desktop fill;
        # layer-canvas-muted is also used by other legacy surfaces.
        colors['layer-sidebar'] = (colors['brutal-cream']
                                   if spec['column'] == 'brutal'
                                   else colors['layer-canvas-muted'])
        colors['layer-panel-header'] = (colors['layer-panel'] if spec['column'] == 'brutal' else colors['layer-canvas-muted'])
        colors['layer-section-header-mobile'] = (colors['color-soft-signal']
                                   if spec['column'] == 'brutal'
                                   else colors['layer-panel'])
        # Frozen a57 docked cells; dark Brutal uses the entire Elegant spec.
        colors['layer-mobile-nav'] = colors['layer-panel']
        colors['layer-mobile-nav-system'] = '#00000000'
        colors['line-mobile-nav'] = colors['ink']
        colors['line-mobile-nav-divider'] = colors['line-strong']
        colors['foreground-mobile-nav'] = 'rgba(0 0 0 / 0.55)'
        colors['foreground-mobile-nav-selected'] = colors['ink']
        colors['foreground-mobile-nav-glyph-selected'] = colors['ink']
        colors['layer-mobile-nav-selected'] = colors['primary-400']
        colors['line-mobile-nav-selected'] = '#00000000'
        colors['line-mobile-nav-selected-ring'] = '#00000000'
        colors['layer-mobile-nav-pressed'] = colors['ink-6']
        colors['line-composer'] = colors['ink' if spec['column'] == 'brutal' else 'ink-6']
        colors['foreground-composer-task'] = ('{palette.composerTaskLabel}'
            if spec['column'] == 'brutal' else colors['foreground-strong'])
        colors['layer-composer-task-checked'] = colors['ink' if spec['column'] == 'brutal' else 'foreground-strong']
        colors['line-composer-task'] = colors['ink' if spec['column'] == 'brutal' else 'line-strong']
        # Existing a57 compiled Banner colors, measured in all four appearances.
        # These are role values from that recipe, not new palette entries.
        colors['layer-composer-notice'] = ('{palette.orange.100}' if spec['column'] == 'brutal'
            else '{palette.elegantNotice.dark}' if spec['column'] == 'elegantDark'
            else '{palette.elegantNotice.light}')
        colors['foreground-composer-notice'] = colors['foreground-strong' if spec['column'] == 'brutal' else 'foreground-muted']
        colors['line-composer-notice'] = colors['foreground-strong'] if spec['column'] == 'brutal' else '#00000000'
        colors['layer-auth-header'] = colors['layer-section-header-mobile']
        colors['foreground-message'] = colors['ink' if spec['column'] == 'brutal' else 'foreground-muted']
        colors['foreground-message-meta'] = '{palette.messageMeta}'
        colors['foreground-spinner'] = colors['ink' if spec['column'] == 'brutal' else 'foreground']
        colors['foreground-field-label'] = colors['foreground-hint' if spec['column'] == 'elegantDark' else 'foreground-strong']
        colors['foreground-field-required'] = colors['danger-strong']
        colors['foreground-banner-body'] = colors['foreground' if spec['column'] == 'brutal' else 'foreground-muted']
        colors['layer-banner-destructive'] = ('{palette.elegantBanner.destructive.dark}' if spec['column'] == 'elegantDark' else colors['danger-soft'])
        colors['layer-banner-info'] = ('{palette.elegantBanner.info.dark}' if spec['column'] == 'elegantDark' else colors['info-soft'])
        colors['layer-banner-success'] = ('{palette.elegantBanner.success.dark}' if spec['column'] == 'elegantDark' else colors['success-soft'])
        colors['layer-banner-warning'] = ('{palette.elegantNotice.dark}' if spec['column'] == 'elegantDark' else colors['warning-soft'])

        colors['line-dialog'] = colors['line-strong' if spec['column'] == 'brutal' else 'line-muted']
        colors['foreground-dialog-close'] = colors['ink' if spec['column'] == 'brutal' else 'foreground-placeholder']
        colors['line-banner'] = colors['line-strong']
        colors['foreground-confirm-name'] = colors['foreground-muted']
        colors['foreground-confirm-prompt'] = colors['foreground-muted']
        colors['foreground-confirm-slug'] = colors['foreground-strong']
        colors['foreground-confirm-input'] = colors['foreground-muted']
        colors['layer-confirm-slug'] = colors['fill-muted']

        # Actual a57b9dab Select: muted Elegant text, solid Brutal text;
        # disabled keeps the same colors under the 0.4 group opacity.
        select_ink = 'foreground-strong' if spec['column'] == 'brutal' else 'foreground-muted'
        select_fill = 'fill-muted' if spec['column'] == 'elegantDark' else 'layer-panel'
        select_line = 'foreground-strong' if spec['column'] == 'brutal' else 'line-muted'
        for target, source in {
            'foreground-select': select_ink, 'foreground-select-placeholder': select_ink,
            'foreground-select-disabled': select_ink,
            'layer-select': select_fill, 'layer-select-disabled': select_fill,
            'layer-select-hover': select_fill if spec['column'] == 'brutal' else 'ink-2',
            'line-select': select_line, 'line-select-disabled': select_line,
        }.items():
            colors[target] = colors[source]
        # a57b9dab component_colors.g.dart stores this subtle dark switch
        # shadow in float sRGB. values.json's display-rounded .04 / #f3f3f7
        # changes antialiased switch-edge pixels, so retain the source precision.
        if spec['column'] == 'elegantDark':
            # a57 semantic_colors.g.dart:1094, preserve float RGB/alpha.
            colors['line-muted'] = 'rgb(240.576945 240.576945 241.18257 / 0.101961)'
            # a57b9dab shadows.g.dart xs: preserve authored alpha 0.045.
            shadows['xs'] = shadows['xs'].replace('/ 0.04)', '/ 0.045)', 1)
            colors['switch-shadow-bottom'] = (
                'rgb(243.444675 243.444675 247.22862 / 0.039203)')
            # semantic_colors.g.dart:1111 uses the same calibrated float for
            # ink-4. Rounding its alpha/RGB changes small ghost-hover pixels.
            colors['ink-4'] = (
                'rgb(243.444675 243.444675 247.22862 / 0.039203)')
        # a57 semantic_colors.g.dart:752. The display dump rounds RGB.
        if spec['column'] == 'elegantLight':
            colors['primary-edge'] = 'rgb(232.32132 196.60704 78.03561 / 0.7)'
        # Shared Button elevation, independent of edge rings and press motion.
        normal = shadows['sm'] if spec['column'] == 'brutal' else shadows['xs'] if spec['column'] == 'elegantDark' else 'none'
        shadows['shadow.buttonSuccess'] = shadows['sm'] if spec['column'] == 'brutal' else 'none'
        shadows['shadow.control'] = normal
        # Select elevation is independent of the shared press-motion option.
        shadows['shadow.select'] = normal
        shadows['shadow.selectHover'] = shadows['md'] if spec['column'] == 'brutal' else normal
        shadows['shadow.selectPressed'] = shadows['xs'] if spec['column'] == 'brutal' else normal
        shadows['shadow.selectFocus'] = normal if spec['column'] == 'brutal' else 'none'
        shadows['shadow.buttonHover'] = shadows['md'] if spec['column'] == 'brutal' else normal
        shadows['shadow.buttonPressed'] = shadows['xs'] if spec['column'] == 'brutal' else normal
        shadows['shadow.buttonDangerOutline'] = normal if spec['column'] == 'elegantDark' else 'none'
        colors.update(button_colors(spec['column'], colors))
        return {
            'colors': colors,
            # Only the Elegant source modes carry these legacy preservation
            # colors; Brutal dark inherits the whole Elegant mode.
            'palette': {**({'palette-orange-100': colors['task-status-todo-soft'],
                         'palette-composerTaskLabel': 'rgba(0 0 0 / 0.6)',
                         'palette-messageMeta': 'rgba(0 0 0 / 0.4)'}
                if spec['column'] == 'brutal' else {
                    'palette-messageMeta': ('rgba(196 196 193 / 0.7)' if spec['column'] == 'elegantDark' else 'rgba(61 61 58 / 0.7)'),
                    'palette-elegantBanner-destructive-dark': 'rgba(198.253830000 48.559650000 36.180165000 / 0.180368)',
                    'palette-elegantBanner-info-dark': 'rgba(0.153765000 94.616985000 121.406010000 / 0.180551)',
                    'palette-elegantBanner-success-dark': 'rgba(20.536935000 115.217670000 63.901470000 / 0.180368)',
                    'palette-elegantNotice-light': '#ffeadc',
                    # a57 recipe_utilities.g.dart _v609 actual Flutter paint color.
                    'palette-elegantNotice-dark': f'rgba({.534161 * 255:.9f} {.321382 * 255:.9f} {.207110 * 255:.9f} / 0.180368)',
                }), **button_palette(spec['column'])},
            'geometry': {**geometry_with_type(spec['geometry'], type_metrics),
                         **({'space.dialogBodyTop': 10} if spec['column'] == 'elegantDark' else {})},
            'font': {name: '{fonts.mono}' if spec['column'] == 'brutal' else '{fonts.sans}'
                     for name in ('font.messageTime', 'font.messageSubtitle')},
            # Brutal dark is the complete Elegant mode, including its families.
            **({'fonts': spec['fonts']} if spec['fonts'] != light['fonts'] else {}),
            'shadows': shadows,
            'case': spec['case'],
            'options': spec['options'],
        }

    return {
        'format': PACK_FORMAT,
        'id': pack_id,
        'name': {'en': name_en, 'zh': name_zh},
        'version': '1.0.0',
        'extends': 'raft',
        'builtIn': True,
        'author': 'Raft Design System',
        'fonts': light['fonts'],
        'modes': {
            'light': mode(light),
            'dark': mode(dark),
        },
    }


def build() -> dict[str, dict]:
    values = load_values()
    elegant_light = {
        'column': 'elegantLight', 'geometry': GEOMETRY_ELEGANT,
        'options': OPTIONS_ELEGANT, 'case': CASE_ELEGANT, 'fonts': FONTS_ELEGANT,
    }
    elegant_dark = dict(elegant_light, column='elegantDark')
    brutal_light = {
        'column': 'brutal', 'geometry': GEOMETRY_BRUTAL,
        'options': OPTIONS_BRUTAL, 'case': CASE_BRUTAL, 'fonts': FONTS_BRUTAL,
    }
    return {
        f'{THEMES}/elegant.theme.json': pack(
            'elegant', 'Elegant', '雅致', values, elegant_light, elegant_dark),
        # Brutal has no dark look of its own. The old app forced the family to
        # Elegant whenever dark was on (a57b9dab theme.dart:102:
        # `dark ? RaftFamily.elegant : family`), so dark was Elegant's colours,
        # radii, strokes and options -- not Brutal's light values with a dark
        # palette. Rendering Brutal+dark on a57b9dab returns exactly the
        # Elegant+dark tokens, which is why dark reuses the whole elegant_dark
        # spec rather than only the palette column.
        f'{THEMES}/brutal.theme.json': pack(
            'brutal', 'Brutal', '粗野', values, brutal_light, elegant_dark),
    }


def render(pack_data: dict) -> str:
    return json.dumps(pack_data, indent=2, sort_keys=False) + '\n'


def render_dart(pack_data: dict) -> str:
    """The same pack as a compile-time constant.

    The app declares no assets of its own, so a package asset does not reach its
    bundle; more importantly the first frame must already be themed. Reading a
    pack asynchronously would paint one frame in the previous look, which is the
    flash docs/theme-flash.md exists to prevent. The Raft pack solves this the
    same way, so the families do too.
    """
    name = pack_data['id']
    header = (
        '// GENERATED - do not edit. Regenerate with '
        '`tool/theme-adapters/build_family_packs.py`.\n'
        '//\n'
        f'// The built-in {pack_data["name"]["en"]} theme as a compile-time constant, so the\n'
        '// first frame can be themed synchronously (an async asset read would paint\n'
        '// one frame in the previous look). The same bytes are written to\n'
        f'// assets/themes/{name}.theme.json for tooling and for editing a copy.\n'
        '//\n'
        '// ignore_for_file: lines_longer_than_80_chars\n'
        'library;\n\n'
    )
    body = render(pack_data)
    quote = "'" * 3
    if quote in body:
        raise SystemExit(f'the {name} pack contains a triple quote')
    variable = name[0].upper() + name[1:]
    return (
        header
        + f"const String {name}ThemePackId = '{name}';\n\n"
        + f'const String {name}ThemePackJson = r{quote}{body}{quote};\n'
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()

    packs = build()
    outputs = {}
    for name, data in packs.items():
        outputs[name] = render(data)
        # The Dart constant lives beside the Raft one so `built_in.dart` can
        # expose every built-in pack from one place.
        outputs[f'packages/raft_theme/lib/src/{data["id"]}_pack.g.dart'] = \
            render_dart(data)

    if args.check:
        stale = [name for name, text in outputs.items()
                 if not (ROOT / name).exists() or (ROOT / name).read_text() != text]
        if stale:
            print('stale: ' + ', '.join(stale) +
                  '; run python3 tool/theme-adapters/build_family_packs.py')
            return 1
        print('elegant and brutal theme packs and their Dart constants are current')
        return 0

    for name, text in outputs.items():
        path = ROOT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        print(f'wrote {name}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
