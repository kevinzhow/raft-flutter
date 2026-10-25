#!/usr/bin/env python3
"""Generate the test-only "extreme user theme" pack (docs/theme-contract.md section 8, "User theme").

  python3 tool/parity-ext/extreme_pack.py [--check] [--out FILE]

The pack `extends: "raft"` and overrides, for light and dark, EVERY name the contract lets a pack set, read from
packages/raft_theme/lib/src/contract_names.g.dart, so a role added later cannot be skipped:

  colours   every colour role and palette entry, a loud value per family: layer-* magenta, foreground* green,
            line-/border/edge cyan, brand-* orange, every other family its own hue (red / yellow / blue / violet);
            light and dark use different lightness, and a translucent role stays translucent (>= 50% alpha)
  geometry  radius.* = 40 (31 where Raft already uses 40), stroke.* = 0, size.* +7, space.* +5 (zero stays zero:
            a zero is a switch, not a length), type.*.size +8 / .line +10 / .weight flipped / .tracking +0.02,
            opacity, ratio, duration, motion and blur moved to another valid value
  type      the twelve type-scale slots: Raft size + 8, line + 10, tracking +0.02, weight 700 (400 where Raft is 700)
  fonts     sans, heading and mono all the pinned mono family (Space Mono)
  shadows   every shadow role `none`

Structural options and case transforms are not overridden (a user pack does not have to). The output is committed at
apps/raft_flutter/test/parity/fixtures/extreme.theme.json; `--check` fails when it is stale.
"""
import argparse
import colorsys
import json
import pathlib
import re
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
NAMES = ROOT / 'packages/raft_theme/lib/src/contract_names.g.dart'
RAFT = ROOT / 'packages/raft_theme/assets/themes/raft.theme.json'
OUT = ROOT / 'apps/raft_flutter/test/parity/fixtures/extreme.theme.json'

# hue in degrees per colour family
HUE = {'layer': 300, 'foreground': 130, 'line': 185, 'brand': 28}
OTHER_HUES = (0, 55, 215, 265, 330 - 20, 95 - 20)  # red, yellow, blue, violet, rose, olive: none is a family hue above
PALETTE_HUE = {'yellow': 55, 'orange': 28, 'red': 0, 'pink': 335, 'cream': 45, 'lavender': 265, 'purple': 280,
               'blue': 215, 'cyan': 185, 'green': 130, 'lime': 95, 'stone': 20, 'gray': 220, 'grey': 220,
               'neutral': 210, 'black': 240, 'white': 200, 'brown': 20, 'teal': 170, 'indigo': 245}


def sections():
    """-> (colour roles, geometry tokens, type slots) from the generated contract names."""
    src = NAMES.read_text()
    roles_src = src.split('raftColorRoles = {')[1].split('};')[0]
    geometry_src = src.split('raftGeometryTokens = {')[1].split('};')[0]
    take = lambda text: re.findall(r"^\s+'([^']+)',", text, re.M)
    return take(roles_src), take(geometry_src)


def alpha_of(value):
    value = value.strip()
    if value.startswith('#'):
        return int(value[7:9], 16) / 255 if len(value) == 9 else 1.0
    m = re.search(r'/\s*([0-9.]+%?)\s*\)', value)
    if m:
        a = m.group(1)
        return float(a[:-1]) / 100 if a.endswith('%') else float(a)
    return 1.0


def family_of(role):
    head = role.split('-')[0]
    if head in ('layer', 'foreground', 'brand'):
        return head
    if head == 'line' or 'border' in role or role.endswith('-edge') or role.endswith('-line') or '-line-' in role:
        return 'line'
    return head


def hue_of(role):
    fam = family_of(role)
    if fam in HUE:
        return HUE[fam]
    return OTHER_HUES[zlib.crc32(fam.encode()) % len(OTHER_HUES)]


def lightness(role, dark):
    m = re.search(r'-(\d{2,3})$', role)
    if m:  # 50..950 ramp: 950 is the darkest step
        step = int(m.group(1))
        base = 0.96 - 0.86 * (step / 1000)
    else:
        base = 0.30 + (zlib.crc32(role.encode()) % 40) / 100  # 0.30 .. 0.69
    return min(0.9, max(0.12, 1 - base if dark else base))


def hex_color(h, l, alpha):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360, l, 1.0)
    out = '#%02x%02x%02x' % (round(r * 255), round(g * 255), round(b * 255))
    return out if alpha >= 0.999 else out + '%02x' % round(alpha * 255)


def loud_color(role, original, dark):
    alpha = alpha_of(original)
    alpha = 1.0 if alpha >= 0.999 else max(alpha, 0.5)
    return hex_color(hue_of(role), lightness(role, dark), alpha)


def loud_palette(name, original, dark):
    """A palette entry (palette-<family>-<step>): its family hue, saturated, lightness from the step."""
    parts = name.split('-')
    hue = PALETTE_HUE.get(parts[1] if len(parts) > 1 else '', zlib.crc32(name.encode()) % 360)
    h = hue + 17  # not the Raft palette's own hue, so even an unchanged ramp would differ
    return hex_color(h, lightness(name, dark), 1.0)


def shifted(token, value, raft_radius_clash=40):
    """The extreme value of one numeric token (always different from [value])."""
    kind = token.split('.')[0]
    if kind == 'radius':
        return 31 if value == raft_radius_clash else raft_radius_clash
    if kind == 'stroke':
        return 0 if value != 0 else 0.75  # a stroke that is already 0 gets a hairline: still "different"
    if kind == 'type':
        leaf = token.rsplit('.', 1)[-1]
        if leaf == 'size':
            return value + 8
        if leaf == 'line':
            return value + 10
        if leaf == 'weight':
            return 400 if value >= 600 else 700
        if leaf == 'tracking':
            return round(value + 0.02, 4)
        return value + 3
    if kind == 'size':
        return value + 7 if value else 0
    if kind == 'space':
        if value == 0:
            return 0
        return value + 5 if value > 0 else value - 3
    if kind == 'opacity':
        return 0.37 if value >= 0.5 else 0.83
    if kind == 'ratio':
        return 0.25 if value > 0.3 else 0.6
    if kind == 'duration':
        return 777 if value != 777 else 555
    if kind == 'motion':
        return 333 if value != 333 else 99
    if kind == 'blur':
        return 9 if value != 9 else 6
    raise ValueError(f'no extreme rule for geometry token {token}')


def build():
    raft = json.loads(RAFT.read_text())
    roles, tokens = sections()
    mono_stack = ['Space Mono', 'ui-monospace', 'monospace']
    modes = {}
    for mode in ('light', 'dark'):
        base = raft['modes'][mode]
        dark = mode == 'dark'
        colors = {r: loud_color(r, base['colors'][r], dark) for r in roles}
        palette = {n: loud_palette(n, v, dark) for n, v in base['palette'].items()}
        geometry = {t: shifted(t, base['geometry'][t]) for t in tokens}
        types = {}
        for slot, (size, line, weight, tracking) in base['type'].items():
            types[slot] = [size + 8, line + 10, 400 if weight >= 600 else 700, round(tracking + 0.02, 4)]
        modes[mode] = {
            'colors': colors,
            'palette': palette,
            'geometry': geometry,
            'type': types,
            'font': {k: '{fonts.mono}' for k in base['font']},
            'shadows': {k: 'none' for k in base['shadows']},
        }
    return {
        '$description': 'Test-only extreme user theme (docs/theme-contract.md section 8). Generated by '
                        'tool/parity-ext/extreme_pack.py; never edit by hand.',
        'format': 'raft-theme/1',
        'id': 'user:extreme',
        'name': {'en': 'Extreme test theme'},
        'version': '1.0.0',
        'extends': 'raft',
        'builtIn': False,
        'author': 'raft-flutter tests',
        'fonts': {name: {'family': 'Space Mono', 'stack': mono_stack} for name in ('sans', 'heading', 'mono')},
        'modes': modes,
    }


def render():
    return json.dumps(build(), indent=1, ensure_ascii=False) + '\n'


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--check', action='store_true')
    p.add_argument('--out', default=str(OUT))
    a = p.parse_args()
    text = render()
    out = pathlib.Path(a.out)
    if a.check:
        if not out.is_file() or out.read_text() != text:
            sys.exit(f'{out} is stale; run tool/parity-ext/extreme_pack.py')
        print('extreme pack is current')
        return
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text)
    print(f'wrote {out}')


if __name__ == '__main__':
    main()
