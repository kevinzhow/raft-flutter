#!/usr/bin/env python3
"""Build the built-in Raft theme pack from the generated raft-ui 0.7.1 tokens.

The pack is the contract's first citizen: `packages/raft_theme/assets/themes/
raft.theme.json`. It is data, not code, and it is generated so it can never
drift from the tokens it claims to represent.

Sources, all read out of the tree (nothing hand-copied except the two tables
marked AUTHORED, which cite the file and line they come from):

  packages/raft_ui/lib/src/tokens/raft_token_mapping.dart
      role -> raft-ui 0.7.1 token name, per tier
  packages/raft_ui/lib/src/tokens/raft_tokens.g.dart
      RaftLight / RaftDark colour values (the Chromium-exact conversion),
      RaftRadius and RaftTypeScale from styles.css @theme
  packages/raft_ui/lib/src/tokens/token_set.dart
      the bundled font families and stacks

  python3 tool/theme-adapters/build_raft_pack.py           # write the pack
  python3 tool/theme-adapters/build_raft_pack.py --check   # exit 1 when stale
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

from button_contract import button_colors

ROOT = pathlib.Path(__file__).resolve().parents[2]
TOKENS = 'packages/raft_ui/lib/src/tokens'
PACK = 'packages/raft_theme/assets/themes/raft.theme.json'
PACK_DART = 'packages/raft_theme/lib/src/raft_pack.g.dart'
NAMES_DART = 'packages/raft_theme/lib/src/contract_names.g.dart'
PACK_FORMAT = 'raft-theme/1'

COLOR = re.compile(
    r'Color\(0x([0-9a-fA-F]{8})\)'
    r'|Color\.fromRGBO\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\s*\)'
    r'|Color\.from\(alpha:\s*([0-9.]+),\s*red:\s*([0-9.]+),\s*green:\s*([0-9.]+),'
    r'\s*blue:\s*([0-9.]+)\)')


def read(path: str) -> str:
    return (ROOT / path).read_text()


def fmt_alpha(value: float) -> str:
    """0.678000 -> '0.678', 0.0 -> '0', 0.050000 -> '0.05'."""
    text = f'{value:.6f}'.rstrip('0').rstrip('.')
    return text or '0'


def color_hex(match: re.Match) -> str:
    """An opaque colour as `#rrggbb`, a translucent one as `rgba(r g b / a)`.

    Alpha is carried as the exact fraction the token was generated with: a
    `#rrggbbaa` form would quantise it to 8 bits and change the painted pixel.
    """
    if match.group(1):
        argb = match.group(1).lower()
        if argb.startswith('ff'):
            return '#' + argb[2:]
        alpha = int(argb[:2], 16) / 255
        r, g, b = (int(argb[i:i + 2], 16) for i in (2, 4, 6))
        return f'rgba({r} {g} {b} / {fmt_alpha(alpha)})'
    if match.group(2):
        r, g, b = (int(match.group(i)) for i in (2, 3, 4))
        alpha = float(match.group(5))
        return f'#{r:02x}{g:02x}{b:02x}' if alpha >= 1 else f'rgba({r} {g} {b} / {fmt_alpha(alpha)})'
    a, r, g, b = (float(match.group(i)) for i in (6, 7, 8, 9))
    rgb = f'#{round(r * 255):02x}{round(g * 255):02x}{round(b * 255):02x}'
    return rgb if a >= 1 else f'rgba({round(r * 255)} {round(g * 255)} {round(b * 255)} / {fmt_alpha(a)})'


def mode_colors(source: str, cls: str) -> dict[str, str]:
    """CSS token name -> colour, for RaftLight or RaftDark."""
    block = source.split(f'abstract final class {cls} {{')[1].split('abstract final class ')[0]
    declarations = {}
    for name, expression in re.findall(
            r'static const Color ([A-Za-z0-9_]+) = '
            r'(Color\(0x[0-9a-fA-F]{8}\)|Color\.fromRGBO\([^;]*?\)|Color\.from\([^;]*?\));',
            block, re.S):
        match = COLOR.search(expression)
        if match:
            declarations[name] = color_hex(match)
    out = {}
    for css, field in re.findall(r"'([^']+)':\s*([A-Za-z0-9_]+),", block):
        if field in declarations:
            out[css] = declarations[field]
    return out


def role_mapping(source: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for name in ('raftSemanticMapping', 'raftProductMapping', 'raftComponentMapping'):
        block = source.split(f'const Map<String, String> {name} = ')[1].split('\n};')[0]
        for role, token in re.findall(
                r"'([^']+)':\s*('(?:[^']+)'|raftTransparentToken)", block):
            out[role] = '' if token == 'raftTransparentToken' else token.strip("'")
    return out


def doubles(source: str, cls: str) -> dict[str, float]:
    block = source.split(f'abstract final class {cls} {{')[1].split('abstract final class ')[0]
    return {name: float(value) for name, value in
            re.findall(r'static const double ([A-Za-z0-9_]+) = ([-0-9.]+);', block)}


def type_scale(source: str) -> dict[str, list[float]]:
    block = source.split('abstract final class RaftTypeScale {')[1].split('abstract final class ')[0]
    out = {}
    for name, body in re.findall(r'static const RaftTypeStyle (\w+) = RaftTypeStyle\((.*?)\);', block):
        size, line = (float(v) for v in body.split(',')[:2])
        weight = re.search(r'fontWeight: (\d+)', body)
        tracking = re.search(r'letterSpacingEm: ([-0-9.]+)', body)
        # The contract spells the two mono slots with a dash, the Dart class
        # with camelCase; the pack always uses the contract's names.
        slot = {'monoMeta': 'mono-meta', 'monoCode': 'mono-code'}.get(name, name)
        out[slot] = [size, line, float(weight.group(1)) if weight else 400.0,
                     float(tracking.group(1)) if tracking else 0.0]
    return out


def shadows(source: str, cls: str) -> dict[str, str]:
    block = source.split(f'abstract final class {cls} {{')[1].split('abstract final class ')[0]
    out = {}
    for name, body in re.findall(r'static const RaftShadow (\w+) = RaftShadow\(\[(.*?)\]\);',
                                 block, re.S):
        layers = []
        for inset, x, y, blur, spread, colour in re.findall(
                r'RaftCssShadow\(inset: (true|false), offset: Offset\(([-0-9.]+), ([-0-9.]+)\), '
                r'blur: ([-0-9.]+), spread: ([-0-9.]+), color: (Color\([^)]*\)|Color\.fromRGBO\([^)]*\))',
                body):
            value = color_hex(COLOR.search(colour))
            layers.append(f'{"inset " if inset == "true" else ""}{float(x):g}px '
                          f'{float(y):g}px {float(blur):g}px {float(spread):g}px {value}')
        out[name] = ', '.join(layers)
    return out


def stretch(families: list[str], mono: bool = False) -> str:
    return ' › '.join(families)


# AUTHORED: the two tables below are the contract's decisions, not derived data.
# §3.3–3.5 of docs/theme-contract.md lists where each number comes from.
GEOMETRY_RAFT = {
    # MobileNav: Web v1.21.23 / a57b9dab mobile_navigation.dart.
    'space.mobileNavInline': 8,
    'space.mobileNavTop': 6,
    'stroke.mobileNavTop': 1,
    'stroke.mobileNavBottom': 0,
    'stroke.mobileNavDivider': 0,
    'size.mobileNavGlyph': 22,
    'size.mobileNavItem': 45,
    'size.mobileNavItemCompact': 45,
    'size.mobileNavGlyphHideHeight': 0,
    'space.mobileNavItemTop': 4,
    'space.mobileNavGlyphLabel': 7,
    'type.mobileNavLabel.size': 10,
    'type.mobileNavLabel.line': 12,
    'type.mobileNavLabel.weight': 600,
    'type.mobileNavLabelSelected.weight': 700,
    'type.mobileNavLabel.tracking': 0,
    'size.mobileNavStickerWidth': 56,
    'size.mobileNavStickerHeight': 30,
    'radius.mobileNavSticker': 8,
    'stroke.mobileNavSticker': 1.5,
    'stroke.mobileNavStickerRing': 1.5,
    'size.mobileNavSafeMax': 34,

    # Shared Button source metrics, Cindy a0741fbf/c1ec691c.
    'size.control.xs': 32,
    'type.button.xs.size': 13,
    'type.button.sm.size': 13,
    'type.button.md.size': 13,
    'type.button.lg.size': 15,
    'type.button.sm.line': 18,
    'type.button.md.line': 18,
    'type.button.lg.line': 20,
    'type.button.weight': 700,
    'space.buttonInline.xs': 12,
    'space.buttonInline.sm': 12,
    'space.buttonInline.lg': 16,
    'space.buttonGap.xs': 8,
    'space.buttonGap.sm': 8,
    'space.buttonGap.md': 8,
    'space.buttonGap.lg': 8,
    'size.buttonGlyph.xs': 16,
    'size.buttonGlyph.sm': 16,
    'size.buttonGlyph.lg': 18,
    'size.buttonGlyph.iconMd': 18,
    'size.buttonGlyph.iconLg': 22,
    'size.buttonGlyph.iconXs': 18,
    'size.buttonGlyph.iconSm': 18,
    'opacity.buttonDisabled': 1,
    # Confirmation / Banner source contract, Cindy fe0074f6.
    'stroke.dialog': 0,
    'stroke.dialogRing': 1,
    'space.bannerInline': 14,
    'space.bannerGap': 10,
    'type.bannerBody.line': 20,
    'type.bannerBody.size': 14,
    'type.bannerBody.tracking': 0,
    'size.bannerGlyph': 20,
    'radius.banner': 10,
    'stroke.bannerBorder': 0,
    'stroke.bannerRing': 1,
    'type.confirmBody.size': 15,
    'type.confirmBody.line': 20,
    'type.confirmName.weight': 600,
    'type.confirmPrompt.size': 13,
    'type.confirmPrompt.line': 18,
    'type.confirmPrompt.weight': 600,
    'type.confirmSlug.size': 13,
    'type.confirmSlug.weight': 600,
    'space.confirmSlugInline': 4,
    'size.confirmAction': 44,
    # Shared Dialog slots, Web 0.7.0 / a57 runtime probes; Cindy 046ef0f7.
    'space.dialogContentInline': 0,
    'space.dialogContentBlock': 0,
    'space.dialogPartGap': 0,
    'space.dialogHeaderInline': 20,
    'space.dialogHeaderTop': 20,
    'space.dialogHeaderBottom': 0,
    'space.dialogHeaderGap': 8,
    'space.dialogBodyInline': 20,
    'space.dialogBodyTop': 6,
    'space.dialogBodyBottom': 20,
    'space.dialogFooterInline': 20,
    'space.dialogFooterTop': 0,
    'space.dialogFooterBottom': 20,
    'space.dialogFooterGap': 8,
    'type.dialogTitle.size': 17,
    'type.dialogTitle.line': 22,
    'size.dialogClose': 32,
    'size.dialogCloseGlyph': 18,
    'space.dialogCloseOutset': 6,
    'blur.dialogBackdrop': 0,
    # ComposerToolbarLabel / shared CheckboxIndicator, Cindy fc426a64.
    'size.composerTaskToggle': 32,
    'size.composerTaskCheckbox': 20,
    'space.composerTaskGap': 8,
    'type.composerTaskLabel.size': 14,
    'type.composerTaskLabel.line': 20,
    'type.composerTaskLabel.weight': 600,

    # Web 0.7.0 + actual a57 composer probes; Cindy 16e23df0.
    'space.composerShellInline': 12,
    'space.composerShellTop': 12,
    'space.composerShellBottom': 8,
    'space.composerEditorInline': 2,
    'space.composerEditorTop': 0,
    'space.composerToolbarInline': 0,
    'space.composerToolbarTop': 0,
    'space.composerToolbarBottom': 0,
    'space.composerToolbarShiftY': 0,
    'space.composerFirstActionOffset': -5,
    'space.composerActionGap': 8,
    'space.composerMetaGap': 8,
    'size.composerEditorMinimumDesktop': 24,
    'size.composerAction': 32,
    'size.composerSubmit': 32,
    'size.composerGlyph': 18,
    'type.composerNotice.size': 13,
    'type.composerNotice.line': 18,
    'type.composerNotice.weight': 400,
    'radius.composerNotice': 10,
    'stroke.composerNotice': 1,
    'space.composerNoticeTop': 8,
    'space.composerNoticeEnd': 12,
    'space.composerNoticeBottom': 8,
    'space.composerNoticeStart': 12,

    # Web appearanceStore.ts + MessageItem text roles (Cindy 5eef1cad/4e2f12b0).
    'type.messageBody.sm.size': 14, 'type.messageBody.sm.line': 20,
    'type.messageBody.md.size': 16, 'type.messageBody.md.line': 24,
    'type.messageBody.lg.size': 18, 'type.messageBody.lg.line': 28,
    'type.messageSender.sm.size': 13, 'type.messageSender.md.size': 15, 'type.messageSender.lg.size': 17,
    'type.messageSender.sm.line': 20, 'type.messageSender.md.line': 20, 'type.messageSender.lg.line': 20,
    'type.messageSender.weight': 700, 'type.messageBody.tracking': 0,
    'type.messageMeta.lg.size': 13, 'type.messagePreview.sm.size': 12,
    'type.messagePreview.md.size': 13, 'type.messagePreviewTime.md.size': 12,
    # a57b9dab switch/control bounds; 0 keeps the Raft hit-only expander.
    'size.touchLayoutMin': 0,
    # Actual Web v1.21.23 AvatarSlot DOM (profile-hero / profile-tile / panel-header).
    'size.avatar.profileHero': 99, 'size.avatar.profileTile': 51, 'size.avatar.panelHeader': 35,
    # SettingsProfileCard source values, approved Cindy 318b1d17.
    'radius.settingsCard': 10,
    # Web MenuItem min-h-9 / max-height:600px min-h-8; ContextMenu min-w-60.
    'size.menuActionRow': 36, 'size.menuActionRowCompact': 32, 'size.menuPopupMin': 240,
    # Current Web MessageInput / a57 legacy composer, approved Cindy 27a5a99c.
    'space.composerHostInline': 20, 'space.composerHostTop': 8,
    'type.composerInput.line': 24, 'type.composerInputDesktop.size': 16,
    'type.settingsCardTitle.size': 17, 'type.settingsCardTitle.line': 22,
    'type.settingsCardMeta.size': 13, 'type.settingsCardMeta.line': 18,
    # 0.7.1 switchRecipe (dist/index.mjs): border 1.5 + padding 2.5.
    'size.switch.width.sm': 50, 'size.switch.width.md': 50,
    'size.switch.height.sm': 30, 'size.switch.height.md': 30,
    'size.switch.thumb.sm': 22, 'size.switch.thumb.md': 22,
    'space.switchInset': 4, 'motion.switchSlideMs': 220, 'motion.switchColorMs': 150,
    'radius.sticker': 4, 'radius.chip': 6, 'radius.control': 8, 'radius.controlSmall': 8,
    'radius.container': 10, 'radius.dialog': 16, 'radius.sheet': 16, 'radius.tooltip': 6,
    'radius.item': 6, 'radius.pill': 999, 'radius.avatar': 4, 'radius.rail': 0,
    # The avatar's inner content radius (0.7.1: rounded-[2px]). It is NOT
    # outer - inset: the official specimen insets the image by 1px and still
    # rounds it to 2, so concentric arithmetic gives 3 and would be wrong.
    'radius.avatarInner': 2,
    # The legacy field shape (design_primitives.dart:411). 0.7.1's Input uses
    # radius.control; this token keeps the older field recipe where it is.
    'radius.field': 6,
    'stroke.hairline': 1, 'stroke.control': 1.5, 'stroke.container': 1, 'stroke.rule': 1,
    # Measured from @botiverse/raft-ui 0.7.1 button.tsx: xs/sm/md share h-8=32,
    # lg is h-11=44, xl is h-13=52. The contract keeps one token per size, so
    # Raft's md token is 32 rather than the old 44 (which was a port artefact).
    'size.control.sm': 32, 'size.control.md': 32, 'size.control.lg': 44,
    'size.control.xl': 52,
    'size.control.onFrame': 36, 'size.field': 44, 'size.panelHeader': 56, 'size.rail': 56,
    'size.railGlyph': 16, 'size.navRow': 34, 'size.menuRow': 32, 'size.drawer': 380,
    # The rail on a short viewport (height <= 600). Raft keeps one width; the
    # pre-theme app narrowed Brutal to 50 there. Paired with size.rail exactly as
    # navRow/navRowCompact and menuRow/menuRowCompact already are.
    'size.railShort': 56,
    # Shorter rows on short viewports (contract §3.3). Raft keeps one row height
    # and leaves these at the regular value; the family packs lower them.
    'size.navRowCompact': 34, 'size.menuRowCompact': 32,
    # Navigation row at desktop width (>= 768). Raft keeps the regular row.
    'size.navRowWide': 34,
    'space.controlX': 12, 'space.itemX': 10, 'space.inset.panel': 16,
    # Gap between separate segments (the `separate` frame). Raft frames its
    # segments in a track, so this only takes effect for the family packs.
    'space.segmentGap': 2,
    # The six type metrics raft-ui carries; they size the field and the card
    # title, so they belong to the contract rather than to a constant.
    'size.fieldInput': 44, 'size.fieldSelect': 44,
    'type.fieldLabel.size': 13, 'type.fieldLabel.line': 18, 'type.fieldLabel.weight': 600,
    'space.fieldGap': 6, 'space.fieldLabelAccessoryOutset': 7,
    'type.field.size': 16, 'type.field.line': 24, 'type.field.weight': 400,
    'type.cardTitle.size': 16, 'type.cardTitle.line': 22, 'type.cardTitle.weight': 500,
}

# Select uses the same h-11 tier, not an independent authored 44 (Cindy 511917e6).
# Pack geometry stores numbers, so this alias is resolved by the generator.
GEOMETRY_RAFT['size.composerAction'] = GEOMETRY_RAFT['size.control.sm']
GEOMETRY_RAFT['size.composerSubmit'] = GEOMETRY_RAFT['size.control.sm']
GEOMETRY_RAFT['size.selectTrigger'] = GEOMETRY_RAFT['size.control.lg']
GEOMETRY_RAFT['type.selectValue.size'] = 15
GEOMETRY_RAFT['type.selectValue.weight'] = 600
GEOMETRY_RAFT['type.selectValue.tracking'] = -.005
GEOMETRY_RAFT['type.selectPlaceholder.weight'] = 500
GEOMETRY_RAFT.update({
    'opacity.selectDisabled': 1, 'space.selectTriggerStart': 14,
    'size.selectChevron': 16, 'stroke.selectChevron': 2,
})


# Message row source contract, Cindy 53e94688.
GEOMETRY_RAFT.update({'size.messageRowMin': 0,
 'stroke.messageRow': 0,
 'space.messageRowInline': 8,
 'space.messageRowInlineCompact': 8,
 'space.messageRowInlineThread': 8,
 'space.messageRowTop': 8,
 'space.messageRowTopCompact': 8,
 'space.messageRowContinuationTop': 0,
 'space.messageRowBottom': 8,
 'space.messageRowFollowedGroupBottom': 8,
 'space.messageRowBottomCompact': 8,
 'space.messageRowFollowedCompactBottom': 8,
 'space.messageRowFollowedCompactBottomCompact': 8,
 'space.messageRowMarginInline': 0,
 'space.messageRowMarginTop': 0,
 'space.messageRowMarginBottom': 0,
 'size.messageRowGutter': 35,
 'size.messageRowGutterCompact': 35,
 'size.messageRowAvatar': 35,
 'space.messageRowGapCompact': 12,
 'space.messageHeaderReserve': 0,
 'size.messageHeaderLine': 20,
 'space.messageHeaderGap': 6,
 'space.messageHeaderAfter': 1,
 'space.messageHeaderAfterCompact': 1,
 'space.messageBodyBottom': 0,
 'space.messageBodyBottomCompact': 0,
 'space.messageAttachmentsTop': 8,
 'type.messageMeta.sm.line': 16,
 'type.messageMeta.md.line': 16,
 'type.messageMeta.lg.line': 16,
 'type.messageMeta.tracking': 0,
 'size.messageRowAvatarLarge': 34})

# Spinner source contract, Cindy 63f52c81 / 3fd7a4e6.
GEOMETRY_RAFT.update({
    'size.spinnerDefault': 12, 'duration.spinnerTurn': 1000,
    'stroke.spinnerRing': 0, 'ratio.spinnerRingRadius': 10 / 24,
    'space.spinnerRingInset': 0, 'opacity.spinnerArc': .8,
})

OPTIONS_RAFT = {
    'mobileNav.boxLayout': 'css', 'mobileNav.textLayout': 'css',
    'button.hoverSurface': 'overlay',
    'button.linkDecoration': 'underline',
    'button.linkPadding': 'none',
    'button.disabledSurface': 'muted', 'button.xsLine': 'fixed',
    'messageHeader.timePosition': 'trailing',
    'messageHeader.align': 'center',
    'control.edge': 'inkBorder', 'sticker.ring': 'dieCut', 'emphasis.fill': 'solid',
    'iconButton.surface': 'generic', 'panelAction.surface': 'ghost',
    'sidebar.mobileSurface': 'canvas', 'resource.surface': 'canvas',
    'resource.rows': 'flat', 'resource.badge': 'sticker', 'resource.markRead': 'ghost',
    'listGroup.frame': 'plain', 'task.status': 'square', 'searchResult.selection': 'flat', 'messageReference.chipLayout': 'fixed', 'messageMenu.reactionDivider': 'shown',
    'press.effect': 'overlay', 'control.sheen': 'none', 'avatar.shape': 'square',
    'indicator.border': 'none', 'switch.shape': 'pill', 'checkbox.mark': 'fillCheck',
    'field.style': 'border', 'tabs.selected': 'sticker', 'segmented.selected': 'sticker',
    # 0.7.1 wraps the segments in a rounded, padded track.
    'segmented.frame': 'framed',
    'mobileNav.selection': 'iconSticker',
    'mobileNav.style': 'docked', 'mobileNav.labels': 'withLabels', 'header.layout': 'overlay',
    'panel.edge': 'seam', 'nav.selection': 'sticker', 'tooltip.arrow': 'yes',
    'code.innerBorder': 'dashed', 'spinner.style': 'pixel',
    'dialog.close': 'ghost', 'dialog.cancelSurface': 'ghost',
    'banner.iconAlignment': 'start', 'banner.iconColor': 'foreground', 'confirm.slug': 'chip',
    'confirm.explanation': 'dangerBanner',
    'spinner.ringShape': 'sweep', 'spinner.foreground': 'inherited',
}

CASE_RAFT = {'dialogShellTitle': 'none','heading': 'none', 'label': 'none', 'badge': 'none'}


def build() -> dict:
    mapping = role_mapping(read(f'{TOKENS}/raft_token_mapping.dart'))
    tokens = read(f'{TOKENS}/raft_tokens.g.dart')
    light = mode_colors(tokens, 'RaftLight')
    dark = mode_colors(tokens, 'RaftDark')
    radii = doubles(tokens, 'RaftRadius')
    scale = type_scale(tokens)
    light_shadows = shadows(tokens, 'RaftLight')
    dark_shadows = shadows(tokens, 'RaftDark')
    fonts = read(f'{TOKENS}/token_set.dart')

    def roles(palette: dict[str, str]) -> dict[str, str]:
        out = {}
        for role, token in mapping.items():
            # A role the Raft look does not paint is fully transparent.
            out[role] = '#00000000' if not token else palette.get(
                token, palette.get(token, '#00000000'))
        # The 0.7.1 names the ported components read (`sticker-ink`,
        # `layer-frame`, `foreground-on-frame`, `presence-*`, `task-status-*`, …)
        # are roles too, so a theme can set them without going through the
        # legacy alias. Palette ramps and 0.7.1's deprecated aliases are not
        # roles: the pack carries the palette separately below.
        for token, value in palette.items():
            if token.startswith(('palette-', 'deprecated-', 'color-')):
                continue
            out.setdefault(token, value)
        for target, source in {
            'layer-mobile-nav': 'layer-card', 'layer-mobile-nav-system': 'layer-card', 'line-mobile-nav': 'line-seam',
            'line-mobile-nav-divider': 'line-seam',
            'foreground-mobile-nav': 'foreground-hint',
            'foreground-mobile-nav-selected': 'foreground',
            'foreground-mobile-nav-glyph-selected': 'sticker-ink',
            'layer-mobile-nav-selected': 'brand-400', 'line-mobile-nav-selected': 'sticker-ink',
            'line-mobile-nav-selected-ring': 'sticker-edge',
            'layer-mobile-nav-pressed': 'fill-pressed',
        }.items():
            out[target] = out[source]
        out['line-composer'] = out['line-strong']
        out['foreground-composer-task'] = out['foreground']
        out['layer-composer-task-checked'] = out['foreground']
        out['line-composer-task'] = out['line-strong']
        out['layer-composer-notice'] = out['warning-soft']
        out['foreground-composer-notice'] = out['foreground']
        out['line-composer-notice'] = out['line-hairline']
        out['layer-auth-header'] = out['layer-frame']
        out['foreground-message'] = out['foreground']
        out['foreground-message-meta'] = out['foreground-hint']
        out['foreground-spinner'] = out['foreground']
        out['foreground-banner-body'] = out['foreground']
        out['layer-banner-destructive'] = out['danger-soft']
        out['layer-banner-warning'] = out['warning-soft']
        out['layer-banner-info'] = out['info-soft']
        out['layer-banner-success'] = out['success-soft']

        out['line-dialog'] = out['line-seam']
        out['foreground-dialog-close'] = out['foreground']
        out['line-banner'] = out['line-hairline']
        out['foreground-confirm-name'] = out['foreground']
        out['foreground-confirm-prompt'] = out['foreground']
        out['foreground-confirm-slug'] = out['foreground']
        out['foreground-confirm-input'] = out['foreground']
        out['layer-confirm-slug'] = out['fill-muted']

        # Component aliases: values are existing roles, never new palette colors.
        # These component-only roles do not belong to the legacy semantic
        # getter map. Keep their pack data and public contract independently.
        out['layer-panel-header'] = out['layer-canvas']
        out['layer-section-header-mobile'] = out['layer-frame']
        for target, source in {
            'foreground-field-label': 'foreground-muted',
            'foreground-field-required': 'foreground-muted',
            'foreground-select': 'foreground',
            'foreground-select-placeholder': 'foreground-hint',
            'foreground-select-disabled': 'foreground-disabled',
            'layer-select': 'layer-card', 'layer-select-hover': 'layer-card',
            'layer-select-disabled': 'fill-muted',
            'line-select': 'line-strong', 'line-select-disabled': 'line-hairline',
        }.items():
            out[target] = out[source]
        out.update(button_colors('raftDark' if palette is dark else 'raftLight', out))
        return out

    def stack(prefix: str) -> list[str]:
        match = re.search(rf'const List<String> {prefix} = \[(.*?)\];', fonts, re.S)
        return re.findall(r"'([^']+)'", match.group(1)) if match else []

    def mode(palette: dict[str, str], shadow_set: dict[str, str]) -> dict:
        return {
            'colors': roles(palette),
            'palette': {k: v for k, v in palette.items() if k.startswith('palette-')},
            'geometry': dict(GEOMETRY_RAFT, **{
                'radius.sticker': radii['sticker'], 'radius.chip': radii['chip'],
                'radius.control': radii['control'], 'radius.container': radii['container'],
                'radius.dialog': radii['dialog'],
            }),
            'type': scale,
            'font': {'font.messageTime': '{fonts.mono}',
                     'font.messageSubtitle': '{fonts.sans}'},
            'case': CASE_RAFT,
            'shadows': {
                'xs': 'none', 'sm': 'none', 'md': 'none',
                'lg': shadow_set['elevationFloat'], 'xl': shadow_set['elevationFloat'],
                'shadow.float': shadow_set['elevationFloat'],
                'shadow.sticker': shadow_set['elevationSticker'],
                'shadow.focusRing': shadow_set['focusRing'],
                'shadow.control': 'none',
                'shadow.select': 'none',
                'shadow.selectHover': 'none',
                'shadow.selectPressed': 'none',
                'shadow.selectFocus': shadow_set['focusRing'],
                'shadow.buttonSuccess': 'none',
                'shadow.buttonHover': 'none',
                'shadow.buttonPressed': 'none',
                'shadow.buttonDangerOutline': 'none',
            },
            'options': OPTIONS_RAFT,
        }

    return {
        'format': PACK_FORMAT,
        'id': 'raft',
        'name': {'en': 'Raft', 'zh': 'Raft'},
        'version': '0.7.1',
        'builtIn': True,
        'author': 'Raft Design System',
        'fonts': {
            'sans': {'family': 'Space Grotesk', 'stack': stack('raftSansFontStack')},
            'heading': {'family': 'Space Grotesk', 'stack': stack('raftSansFontStack')},
            'mono': {'family': 'Space Mono', 'stack': stack('raftMonoFontStack')},
        },
        'source': {
            'tokens': 'tool/design-source/raft-ui-0.7.1/tokens.json',
            'generator': 'tool/theme-adapters/build_raft_pack.py',
        },
        'modes': {
            'light': mode(light, light_shadows),
            'dark': mode(dark, dark_shadows),
        },
    }


def render(pack: dict) -> str:
    return json.dumps(pack, indent=2, ensure_ascii=False) + '\n'


def render_pack_dart(pack: dict) -> str:
    header = (
        "// GENERATED - do not edit. Regenerate with `tool/theme-adapters/build_raft_pack.py`.\n"
        "//\n"
        "// The built-in Raft theme, as a compile-time constant so the first frame can\n"
        "// be themed synchronously: reading an asset is async, and a frame painted\n"
        "// before that lands is the theme flash docs/theme-flash.md warns about.\n"
        "// The same bytes are written to assets/themes/raft.theme.json for tooling and\n"
        "// for anyone who wants to edit a copy.\n"
        "//\n"
        "// ignore_for_file: lines_longer_than_80_chars\n"
        "library;\n\n"
    )
    body = render(pack)
    quote = "'" * 3
    if quote in body:
        raise SystemExit("the pack contains a triple quote")
    return (
        header
        + "const String raftThemePackId = '" + pack["id"] + "';\n\n"
        + "const String raftThemePackJson = r" + quote + body + quote + ";\n"
    )


def render_names_dart(roles: list[str], geometry: list[str]) -> str:
    def block(items: list[str]) -> str:
        return "\n".join("  '" + item + "'," for item in items)

    header = (
        "// GENERATED - do not edit. Regenerate with `tool/theme-adapters/build_raft_pack.py`.\n"
        "//\n"
        "// Every name a theme pack may set a value for. A pack that misspells one is\n"
        "// rejected with its JSON path instead of being silently ignored, so a\n"
        "// designer sees the typo rather than a theme that quietly did nothing.\n"
        "library;\n\n"
    )
    return (
        header
        + "/// Colour roles: the legacy role schema components read, plus the 0.7.1\n"
        + "/// names the ported components read directly. Palette entries are not\n"
        + "/// roles; they live under `palette` and a role refers to one as\n"
        + "/// `{palette.x.y}`.\n"
        + "const Set<String> raftColorRoles = {\n" + block(roles) + "\n};\n\n"
        + "/// Numeric tokens: radii, stroke widths, sizes, density and spacing.\n"
        + "const Set<String> raftGeometryTokens = {\n" + block(geometry) + "\n};\n"
    )




def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()

    pack = build()
    outputs = {
        PACK: render(pack),
        PACK_DART: render_pack_dart(pack),
        NAMES_DART: render_names_dart(sorted(pack['modes']['light']['colors']),
                                      sorted(GEOMETRY_RAFT)),
    }
    if args.check:
        stale = [name for name, text in outputs.items()
                 if not (ROOT / name).exists() or (ROOT / name).read_text() != text]
        if stale:
            print('stale: ' + ', '.join(stale) +
                  '; run python3 tool/theme-adapters/build_raft_pack.py')
            return 1
        print('raft theme pack, its Dart constant and the contract names are current')
        return 0
    for name, text in outputs.items():
        path = ROOT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        print(f'wrote {name}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
