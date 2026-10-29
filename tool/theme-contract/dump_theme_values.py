#!/usr/bin/env python3
"""Dump the theme-contract value tables from the two sources P0 names.

Sources (both read out of git, nothing hand-copied):

  OLD = a57b9dab (the commit before the theme families were deleted)
        packages/raft_ui/lib/src/tokens/{semantic_colors,product_colors,
        component_colors}.g.dart   -> Brutal / Elegant light / Elegant dark
  NEW = HEAD (cindy/raft-design, raft-ui 0.7.1 single look)
        packages/raft_ui/lib/src/tokens/raft_tokens.g.dart   -> RaftLight / RaftDark
        packages/raft_ui/lib/src/tokens/raft_token_mapping.dart
                                       -> old role name -> 0.7.1 token name

Writes:
  docs/theme-contract/values-appendix.md   the human tables (generated, do not edit)
  docs/theme-contract/values.json          the same data for the P1 adapters

Usage:
  python3 tool/theme-contract/dump_theme_values.py            # write the files
  python3 tool/theme-contract/dump_theme_values.py --check     # exit 1 when stale
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OLD = 'a57b9dab'
TIERS = ('semantic', 'product', 'component')
TIER_TITLE = {
    'semantic': 'Colour · semantic roles',
    'product': 'Colour · product aliases',
    'component': 'Colour · component roles',
}


def show(path: str) -> str:
    return subprocess.run(
        ['git', 'show', f'{OLD}:{path}'],
        cwd=ROOT, check=True, capture_output=True, text=True).stdout


def read(path: str) -> str:
    return (ROOT / path).read_text()


COLOR = re.compile(
    r'Color\(0x([0-9a-fA-F]{8})\)'
    r'|Color\.from\(alpha:\s*([0-9.]+),\s*red:\s*([0-9.]+),\s*'
    r'green:\s*([0-9.]+),\s*blue:\s*([0-9.]+)'
    r'|Color\.fromRGBO\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)')


def fmt(match: re.Match) -> str:
    if match.group(1):
        argb = match.group(1).lower()
        alpha = int(argb[:2], 16)
        rgb = argb[2:]
        if alpha == 0xFF:
            return f'#{rgb}'
        return f'#{rgb} / {alpha / 255:.3f}'.replace('.000', '')
    if match.group(6):
        r, g, b = (int(match.group(i)) for i in (6, 7, 8))
        a = float(match.group(9))
        return f'#{r:02x}{g:02x}{b:02x} / {a:.2f}'.replace(' / 1.00', '')
    a, r, g, b = (float(match.group(i)) for i in (2, 3, 4, 5))

    def channel(v: float) -> int:
        return round(v * 255)

    return f'#{channel(r):02x}{channel(g):02x}{channel(b):02x} / {a:.2f}'.replace(
        ' / 1.00', '')


def css_names(source: str) -> dict[str, str]:
    """camelCase field -> CSS name, from the generated toCssMap()."""
    block = source.split('Map<String, Color> toCssMap()')[1]
    block = block.split('\n  };')[0]
    out = {}
    for css, field in re.findall(r"'([^']+)':\s*([A-Za-z0-9_]+),", block):
        out[field] = css
    return out


def statics(source: str, cls: str) -> dict[str, dict[str, str]]:
    """`static const brutal = Cls(` blocks -> {theme: {field: value}}."""
    out: dict[str, dict[str, str]] = {}
    for name in ('brutal', 'elegantLight', 'elegantDark'):
        m = re.search(rf'static const {name} = {cls}\((.*?)\n  \);', source, re.S)
        if not m:
            continue
        values: dict[str, str] = {}
        for line in m.group(1).splitlines():
            line = line.strip()
            if not line or line.startswith('//') or ':' not in line:
                continue
            field, _, rest = line.partition(':')
            cm = COLOR.search(rest)
            if cm:
                values[field.strip()] = fmt(cm)
        out[name] = values
    return out


def new_colors(source: str, cls: str) -> dict[str, str]:
    """RaftLight/RaftDark `colors` map, CSS name -> value."""
    block = source.split(f'abstract final class {cls} {{')[1].split(
        '  static const Map<String, RaftShadow> shadows')[0]
    declarations = re.findall(
        r'static const Color ([A-Za-z0-9_]+) = (Color\(0x[0-9a-fA-F]{8}\)'
        r'|Color\.from\([^;]*?\)|Color\.fromRGBO\([^;]*?\));', block, re.S)
    value_of = {}
    for name, expr in declarations:
        m = COLOR.search(expr)
        if m:
            value_of[name] = fmt(m)
    out = {}
    for css, field in re.findall(r"'([^']+)':\s*([A-Za-z0-9_]+),", block):
        if field in value_of:
            out[css] = value_of[field]
    return out


def parse_mapping(source: str) -> dict[str, str]:
    """raftSemanticMapping + raftProductMapping + raftComponentMapping."""
    out = {}
    for name in ('raftSemanticMapping', 'raftProductMapping',
                 'raftComponentMapping'):
        block = source.split(f'const Map<String, String> {name} = ')[1]
        block = block.split('\n};')[0]
        for old, new in re.findall(r"'([^']+)':\s*'([^']+)'", block):
            out[old] = new
    return out


def shadows(source: str, theme: str) -> dict[str, str]:
    """`static const <theme> = RaftThemeShadows(` -> {xs..xl: css-ish text}."""
    m = re.search(rf'static const {theme} = RaftThemeShadows\((.*?)\n  \);',
                  source, re.S)
    if not m:
        return {}
    out = {}
    for name, body in re.findall(r'(\w+): RaftShadow\(\[(.*?)\]\)', m.group(1), re.S):
        out[name] = ' , '.join(
            f"{'inset ' if inset == 'true' else ''}"
            f'{fmt_x(float(x))} {fmt_x(float(y))} {fmt_x(float(blur))} '
            f'{fmt_x(float(spread))} {fmt(COLOR.search(color))}'
            for inset, x, y, blur, spread, color in re.findall(
                r'RaftCssShadow\(inset: (true|false), offset: Offset\(([-0-9.]+), '
                r'([-0-9.]+)\), blur: ([-0-9.]+), spread: ([-0-9.]+), '
                r'color: (Color\([^)]*\)|Color\.fromRGBO\([^)]*\))', body))
    return out


def named_shadows(source: str, cls: str) -> dict[str, str]:
    """RaftLight/RaftDark `static const RaftShadow <name> = RaftShadow([...])`."""
    block = source.split(f'abstract final class {cls} {{')[1]
    block = block.split('abstract final class ')[0]
    out = {}
    for name, body in re.findall(
            r'static const RaftShadow (\w+) = RaftShadow\(\[(.*?)\]\);', block, re.S):
        out[name] = ' , '.join(
            f"{'inset ' if inset == 'true' else ''}"
            f'{fmt_x(float(x))} {fmt_x(float(y))} {fmt_x(float(blur))} '
            f'{fmt_x(float(spread))} {fmt(COLOR.search(color))}'
            for inset, x, y, blur, spread, color in re.findall(
                r'RaftCssShadow\(inset: (true|false), offset: Offset\(([-0-9.]+), '
                r'([-0-9.]+)\), blur: ([-0-9.]+), spread: ([-0-9.]+), '
                r'color: (Color\([^)]*\)|Color\.fromRGBO\([^)]*\))', body))
    return out


def fmt_x(value: float) -> str:
    return f'{value:g}px'


def metrics(source: str, theme: str) -> dict[str, str]:
    """RaftThemeMetrics statics -> plain values."""
    m = re.search(rf'static const {theme} = RaftThemeMetrics\((.*?)\n  \);',
                  source, re.S)
    if not m:
        return {}
    out = {}
    for field, value in re.findall(
            r'(\w+): (\[[^\]]*\]|\d+\.\d+|[^,\n]+),', m.group(1)):
        out[field] = value.strip()
    return out


def extra_rows() -> dict[str, dict[str, str]]:
    """Shadow sets and type metrics for the three themes."""
    old_sh = show('packages/raft_ui/lib/src/tokens/shadows.g.dart')
    old_me = show('packages/raft_ui/lib/src/tokens/metrics.g.dart')
    tokens = read('packages/raft_ui/lib/src/tokens/raft_tokens.g.dart')
    raft_sh = named_shadows(tokens, 'RaftLight')
    raft_sh_dark = named_shadows(tokens, 'RaftDark')

    elev = {}
    for name, canonical in (('xs', 'xs'), ('sm', 'sm'), ('md', 'md'),
                            ('lg', 'lg'), ('xl', 'xl')):
        raft_step = raft_sh.get('elevationFloat', '') if name in ('lg', 'xl') \
            else 'none (controls and steps xs…md cast nothing)'
        elev[canonical] = {
            'brutal': shadows(old_sh, 'brutal').get(name, ''),
            'elegantLight': shadows(old_sh, 'elegantLight').get(name, ''),
            'elegantDark': shadows(old_sh, 'elegantDark').get(name, ''),
            'raftLight': raft_step,
            'raftDark': raft_step,
        }
    roles = {
        'shadow.float': ('elevationFloat', 'elevationFloat'),
        'shadow.sticker': ('elevationSticker', 'elevationSticker'),
        'shadow.focusRing': ('focusRing', 'focusRing'),
    }
    for role, (light_key, dark_key) in roles.items():
        elev[role] = {
            'brutal': '', 'elegantLight': '', 'elegantDark': '',
            'raftLight': raft_sh.get(light_key, ''),
            'raftDark': raft_sh_dark.get(dark_key, ''),
        }

    type_rows = {}
    for field, label in (('fieldFontSize', 'type.field.size'),
                         ('fieldLineHeight', 'type.field.line'),
                         ('fieldFontWeight', 'type.field.weight'),
                         ('cardTitleFontSize', 'type.cardTitle.size'),
                         ('cardTitleLineHeight', 'type.cardTitle.line'),
                         ('cardTitleFontWeight', 'type.cardTitle.weight'),
                         ('headingFontStack', 'font.heading.stack'),
                         ('sansFontStack', 'font.sans.stack'),
                         ('monoFontStack', 'font.mono.stack')):
        type_rows[label] = {
            'brutal': metrics(old_me, 'brutal').get(field, ''),
            'elegantLight': metrics(old_me, 'elegantLight').get(field, ''),
            'elegantDark': metrics(old_me, 'elegantDark').get(field, ''),
            'raftLight': _raft_metric(tokens, field),
            'raftDark': _raft_metric(tokens, field),
        }
    return {'elevation': elev, 'type': type_rows}


def _raft_metric(source: str, field: str) -> str:
    if field in ('headingFontStack', 'sansFontStack'):
        return ('Space Grotesk › PingFang SC › Hiragino Sans GB › '
                'Microsoft YaHei › Noto Sans SC › system-ui › sans-serif')
    if field == 'monoFontStack':
        return 'Space Mono › ui-monospace › SF Mono › Menlo › monospace'
    css = {
        'fieldFontSize': 'field-font-size',
        'fieldLineHeight': 'field-line-height',
        'fieldFontWeight': 'field-font-weight',
        'cardTitleFontSize': 'card-title-font-size',
        'cardTitleLineHeight': 'card-title-line-height',
        'cardTitleFontWeight': 'card-title-font-weight',
    }[field]
    m = re.search(rf"'{css}': ([A-Za-z0-9_]+),", source)
    if not m:
        return ''
    value = re.search(
        rf'static const double {m.group(1)} = ([-0-9.]+);', source)
    return value.group(1) if value else ''


def tier_rows() -> dict[str, list[dict[str, str]]]:
    old_file = {
        'semantic': 'semantic_colors.g.dart',
        'product': 'product_colors.g.dart',
        'component': 'component_colors.g.dart',
    }
    cls = {
        'semantic': 'RaftSemanticColors',
        'product': 'RaftProductColors',
        'component': 'RaftComponentColors',
    }
    new_map = parse_mapping(
        read('packages/raft_ui/lib/src/tokens/raft_token_mapping.dart'))
    tokens = read('packages/raft_ui/lib/src/tokens/raft_tokens.g.dart')
    light = new_colors(tokens, 'RaftLight')
    dark = new_colors(tokens, 'RaftDark')

    out: dict[str, list[dict[str, str]]] = {}
    for tier in TIERS:
        old_src = show(f'packages/raft_ui/lib/src/tokens/{old_file[tier]}')
        names = css_names(old_src)
        values = statics(old_src, cls[tier])
        rows = []
        for field, css in names.items():
            target = new_map.get(css)
            rows.append({
                'role': css,
                'brutal': values.get('brutal', {}).get(field, ''),
                'elegantLight': values.get('elegantLight', {}).get(field, ''),
                'elegantDark': values.get('elegantDark', {}).get(field, ''),
                'raftLight': light.get(target, '') if target else '',
                'raftDark': dark.get(target, '') if target else '',
                'raftToken': target or '',
            })
        out[tier] = rows
    return out


def table(rows: list[dict[str, str]]) -> str:
    head = ('| role (contract name) | Brutal | Elegant light | Elegant dark '
            '| Raft light | Raft dark | raft-ui 0.7.1 token |\n'
            '| --- | --- | --- | --- | --- | --- | --- |')
    body = []
    for r in rows:
        body.append(
            f"| `{r['role']}` | {r['brutal'] or '–'} | {r['elegantLight'] or '–'} "
            f"| {r['elegantDark'] or '–'} | {r['raftLight'] or '–'} "
            f"| {r['raftDark'] or '–'} | `{r['raftToken'] or '–'}` |")
    return head + '\n' + '\n'.join(body)


def render(rows: dict[str, list[dict[str, str]]],
           extra: dict[str, dict[str, str]]) -> str:
    out = [
        '<!-- GENERATED by tool/theme-contract/dump_theme_values.py — do not edit. -->',
        '',
        '# Theme contract · value appendix',
        '',
        'Every colour role the contract carries, with the value it takes in each',
        'built-in theme. Values are read from git, not transcribed: Brutal and',
        'Elegant from `a57b9dab` (the commit before the theme families were deleted),',
        'Raft from the vendored raft-ui 0.7.1 `tokens.json` through the explicit',
        '`raft_token_mapping.dart` table.',
        '',
        '- `#rrggbb` is opaque; `/ a` is the authored alpha (Flutter `Color.a`).',
        '- The Elegant light column is the old light Elegant theme; the old default',
        '  light theme was Brutal, so Brutal has no dark column: dark was always',
        '  Elegant.',
        '- The last column is the raft-ui 0.7.1 token the Raft theme reads for that',
        '  role. Where several roles share one token, the 0.7.1 theme has one value',
        '  for all of them — that collapse is the reason the contract keeps the old',
        '  role names (see the contract, “Why the colour vocabulary is the old role',
        '  schema”).',
        '',
    ]
    for tier in TIERS:
        out += [f'## {TIER_TITLE[tier]}', '', table(rows[tier]), '']
    out += ['## Elevation scale', '',
            'The five shadow steps every theme fills, plus the three role',
            'shadows raft-ui 0.7.1 names. A theme is not required to make them',
            'a scale; the contract only requires the roles components read.', '',
            '| token | Brutal | Elegant light | Elegant dark | Raft light | Raft dark |',
            '| --- | --- | --- | --- | --- | --- |']
    for role, v in extra['elevation'].items():
        out.append(f"| `{role}` | {v['brutal'] or '–'} | {v['elegantLight'] or '–'} "
                   f"| {v['elegantDark'] or '–'} | {v['raftLight'] or '–'} "
                   f"| {v['raftDark'] or '–'} |")
    out += ['', '## Type metrics and families', '',
            'The six metric tokens raft-ui carries plus the three font stacks.',
            'Weights are CSS weights; sizes and line heights are px.', '',
            '| token | Brutal | Elegant light | Elegant dark | Raft (both modes) |',
            '| --- | --- | --- | --- | --- |']
    for role, v in extra['type'].items():
        def cell(value: str) -> str:
            if not value:
                return '–'
            if value.startswith('['):
                return value.strip('[]').replace("'", '').replace(', ', ' › ')
            return value
        out.append(f"| `{role}` | {cell(v['brutal'])} | {cell(v['elegantLight'])} "
                   f"| {cell(v['elegantDark'])} | {cell(v['raftLight'])} |")
    out.append('')
    return '\n'.join(out)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()

    rows = tier_rows()
    extra = extra_rows()
    md_path = ROOT / 'docs/theme-contract/values-appendix.md'
    json_path = ROOT / 'docs/theme-contract/values.json'
    rendered = render(rows, extra)
    data = json.dumps({'source': {'old': OLD, 'new': 'cindy/raft-design'},
                       'tiers': rows, 'extra': extra}, indent=2, sort_keys=False) + '\n'

    if args.check:
        stale = []
        if not md_path.exists() or md_path.read_text() != rendered:
            stale.append(str(md_path.relative_to(ROOT)))
        if not json_path.exists() or json_path.read_text() != data:
            stale.append(str(json_path.relative_to(ROOT)))
        if stale:
            print('stale: ' + ', '.join(stale))
            return 1
        print('value appendix is current')
        return 0

    md_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.write_text(rendered)
    json_path.write_text(data)
    total = sum(len(v) for v in rows.values())
    print(f'wrote {md_path.relative_to(ROOT)} and {json_path.relative_to(ROOT)} '
          f'({total} roles)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
