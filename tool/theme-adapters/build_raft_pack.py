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
    'radius.sticker': 4, 'radius.chip': 6, 'radius.control': 8, 'radius.controlSmall': 8,
    'radius.container': 10, 'radius.dialog': 16, 'radius.sheet': 16, 'radius.tooltip': 6,
    'radius.item': 6, 'radius.pill': 999, 'radius.avatar': 4, 'radius.rail': 0,
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
    # Shorter rows on short viewports (contract §3.3). Raft keeps one row height
    # and leaves these at the regular value; the family packs lower them.
    'size.navRowCompact': 34, 'size.menuRowCompact': 32,
    'space.controlX': 12, 'space.itemX': 10, 'space.inset.panel': 16,
    # The six type metrics raft-ui carries; they size the field and the card
    # title, so they belong to the contract rather than to a constant.
    'type.field.size': 16, 'type.field.line': 24, 'type.field.weight': 400,
    'type.cardTitle.size': 16, 'type.cardTitle.line': 22, 'type.cardTitle.weight': 500,
}

OPTIONS_RAFT = {
    'control.edge': 'inkBorder', 'sticker.ring': 'dieCut', 'emphasis.fill': 'solid',
    'press.effect': 'overlay', 'control.sheen': 'none', 'avatar.shape': 'square',
    'indicator.border': 'none', 'switch.shape': 'pill', 'checkbox.mark': 'fillCheck',
    'field.style': 'border', 'tabs.selected': 'sticker', 'segmented.selected': 'sticker',
    'mobileNav.style': 'docked', 'mobileNav.labels': 'iconsOnly', 'header.layout': 'overlay',
    'panel.edge': 'seam', 'nav.selection': 'sticker', 'tooltip.arrow': 'yes',
    'code.innerBorder': 'dashed', 'spinner.style': 'pixel',
}

CASE_RAFT = {'heading': 'none', 'label': 'none', 'badge': 'none'}


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
            'case': CASE_RAFT,
            'shadows': {
                'xs': 'none', 'sm': 'none', 'md': 'none',
                'lg': shadow_set['elevationFloat'], 'xl': shadow_set['elevationFloat'],
                'shadow.float': shadow_set['elevationFloat'],
                'shadow.sticker': shadow_set['elevationSticker'],
                'shadow.focusRing': shadow_set['focusRing'],
                'shadow.control': 'none',
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
