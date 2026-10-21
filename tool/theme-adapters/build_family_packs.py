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
  docs/theme-contract.md §4         the 20 structural options per theme

  python3 tool/theme-adapters/build_family_packs.py           # write the packs
  python3 tool/theme-adapters/build_family_packs.py --check   # exit 1 when stale
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
VALUES = 'docs/theme-contract/values.json'
THEMES = 'packages/raft_theme/assets/themes'
PACK_FORMAT = 'raft-theme/1'

# AUTHORED: docs/theme-contract.md §4, one row per option. Raft's values live in
# build_raft_pack.py's OPTIONS_RAFT; these two are the same table's other columns.
OPTIONS_ELEGANT = {
    'control.edge': 'ring', 'sticker.ring': 'none', 'emphasis.fill': 'soft',
    'press.effect': 'scale', 'control.sheen': 'gradient', 'avatar.shape': 'circle',
    'indicator.border': 'none', 'switch.shape': 'pill', 'checkbox.mark': 'strokeCheck',
    'field.style': 'inset', 'tabs.selected': 'tint', 'segmented.selected': 'tint',
    # a57b9dab draws a flat row of separate segments: no rounded, padded track.
    'segmented.frame': 'separate',
    'mobileNav.style': 'floatingCapsule', 'mobileNav.labels': 'iconsOnly',
    'header.layout': 'overlay', 'panel.edge': 'seam', 'nav.selection': 'softFill',
    'tooltip.arrow': 'yes', 'code.innerBorder': 'dashed', 'spinner.style': 'ring',
}
OPTIONS_BRUTAL = {
    'control.edge': 'inkBorder', 'sticker.ring': 'none', 'emphasis.fill': 'solid',
    'press.effect': 'offsetShadow', 'control.sheen': 'none', 'avatar.shape': 'square',
    'indicator.border': 'ink', 'switch.shape': 'square', 'checkbox.mark': 'thickStroke',
    'field.style': 'border', 'tabs.selected': 'sticker', 'segmented.selected': 'sticker',
    'segmented.frame': 'separate',
    'mobileNav.style': 'docked', 'mobileNav.labels': 'withLabels', 'header.layout': 'inFlow',
    'panel.edge': 'border', 'nav.selection': 'sticker', 'tooltip.arrow': 'no',
    'code.innerBorder': 'solid', 'spinner.style': 'ring',
}

# AUTHORED: docs/theme-contract.md §3.1–3.3. Values marked † in the contract are
# digits that the P2 baseline can now confirm or refute; they are carried as-is
# until that reconciliation, which is its own change.
GEOMETRY_ELEGANT = {
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
    'space.controlX': 6, 'space.itemX': 10, 'space.inset.panel': 26,
    # a57b9dab `gap-1.5` between segments, at --spacing 0.25rem.
    'space.segmentGap': 6,
}
GEOMETRY_BRUTAL = {
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
    'space.controlX': 8, 'space.itemX': 12, 'space.inset.panel': 8,
    # a57b9dab `gap-1` between segments.
    'space.segmentGap': 4,
}

# AUTHORED: docs/theme-contract.md §3.5. The contract fixes three slots; a theme
# that has no opinion leaves the string alone.
CASE_ELEGANT = {'heading': 'none', 'label': 'uppercase', 'badge': 'none'}
CASE_BRUTAL = {'heading': 'uppercase', 'label': 'uppercase', 'badge': 'uppercase'}

# AUTHORED: docs/theme-contract.md §5.1. Families come from the P0 inventory;
# the stacks keep the CJK fallbacks the app needs to avoid tofu.
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
    'mono': {'family': 'Space Mono',
             'stack': ['Space Mono', 'ui-monospace', 'monospace']},
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
        return {
            'colors': colors,
            'geometry': geometry_with_type(spec['geometry'], type_metrics),
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
