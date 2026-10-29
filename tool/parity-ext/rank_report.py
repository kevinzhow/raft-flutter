#!/usr/bin/env python3
"""Ranked list of everything below the 96% line, with the side-by-side of each (docs/parity.md "Visual suite levels").

  tool/parity-ext/rank_report.py --out <regress out dir> [--also DIR ...] [--top 30] [--shots DIR] [--causes tool/parity-ext/ranked-causes.json]

Reads the job directories of `tool/parity-ext/run regress` (the same --out / --also as the summary), ranks the cases below the
pass line by score, attaches the likely cause from the curated glob table `ranked-causes.json` (written after reading the
side-by-sides; the first matching glob wins, nothing is guessed from the pixels), and, with --shots, copies the side-by-side of
the first --top cases (and of the worst case of every area) into <shots>/<look>-<mode>/<id>.png so they can be pushed to the
evidence branch.
"""
import argparse
import fnmatch
import json
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import levels  # noqa: E402

PASS_LINE = 0.96


def area_of(case_id):
    parts = case_id.split('.')
    return parts[1] if parts[0] == 'components' else parts[0]


def side_by_side(roots, look, mode, engine, case_id):
    for root in roots:
        p = pathlib.Path(root) / f'{look}-{mode}' / engine / 'visual-testing-results/diff/react__android' / f'{case_id}.side-by-side.png'
        if p.is_file():
            return p
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', required=True)
    ap.add_argument('--also', action='append', default=[])
    ap.add_argument('--top', type=int, default=30, help='surfaces listed for the Raft look')
    ap.add_argument('--top-frozen', type=int, default=12, help='surfaces listed for Elegant / Brutal (compared with their frozen originals)')
    ap.add_argument('--shots')
    ap.add_argument('--causes', default=str(HERE / 'ranked-causes.json'))
    ap.add_argument('--write', help='markdown file for the ranked table')
    a = ap.parse_args()
    roots = [a.out, *a.also]
    rows = json.loads((pathlib.Path(a.out) / 'regress-summary.json').read_text())['rows']
    causes = json.loads(pathlib.Path(a.causes).read_text()) if pathlib.Path(a.causes).is_file() else []
    below = sorted((r for r in rows if r['score'] is not None and r['score'] <= PASS_LINE), key=lambda r: r['score'])
    out = ['| # | score | level | look | mode | area | case | likely cause |', '| --- | --- | --- | --- | --- | --- | --- | --- |']
    for i, r in enumerate(below, 1):
        looks = lambda c: c.get('look', ['raft']) if isinstance(c.get('look', ['raft']), list) else [c['look']]
        cause = next((c['cause'] for c in causes if fnmatch.fnmatchcase(r['id'], c['glob']) and r['look'] in looks(c)), '')
        r['cause'] = cause
        out.append(f"| {i} | {r['score'] * 100:.1f}% | {r['level']} | {r['look']} | {r['mode']} | {area_of(r['id'])} | `{r['id']}` | {cause} |")
    # Worst case per surface (first three id segments) and look / mode: what Cody works from, one line per surface.
    groups = {}
    for r in rows:
        if r['score'] is None:
            continue
        key = (r['look'], r['mode'], '.'.join(r['id'].split('.')[:3]) if r['id'].startswith('components.') else r['id'])
        g = groups.setdefault(key, {'worst': r, 'cases': 0, 'below': 0, 'sum': 0.0})
        g['cases'] += 1
        g['below'] += r['score'] <= PASS_LINE
        g['sum'] += r['score']
        if r['score'] < g['worst']['score']:
            g['worst'] = r
    top = []
    for look, mode in (('raft', 'light'), ('raft', 'dark'), ('elegant', 'light'), ('elegant', 'dark'), ('brutal', 'light')):
        mine = [g for (lk, md, _), g in groups.items() if (lk, md) == (look, mode) and g['below']]
        # surfaces ordered by their mean score (how broken the whole surface is), frame and page surfaces before components
        mine.sort(key=lambda g: (g['worst']['level'] == 'component', g['sum'] / g['cases']))
        top += ['', f'### {look} {mode}', '', '| # | mean | worst | below / cases | level | area | worst case | likely cause |', '| --- | --- | --- | --- | --- | --- | --- | --- |']
        limit = a.top if look == 'raft' else a.top_frozen
        for i, g in enumerate(mine[:limit], 1):
            w = g['worst']
            top.append(f"| {i} | {g['sum'] / g['cases'] * 100:.1f}% | {w['score'] * 100:.1f}% | {g['below']} / {g['cases']} | {w['level']} | {area_of(w['id'])} | "
                       f"`{w['id']}` | {w.get('cause', '')} |")
        a.picked_groups = getattr(a, 'picked_groups', []) + [g['worst'] for g in mine[:limit]]
    if a.write:
        pathlib.Path(a.write).write_text('## Top surfaces per look and mode\n' + '\n'.join(top) + '\n\n## Every case below the line\n\n' + '\n'.join(out) + '\n')
    if a.shots:
        shots = pathlib.Path(a.shots)
        picked = list(a.picked_groups)  # the worst case of every listed surface
        copied = 0
        for r in picked:
            src = side_by_side(roots, r['look'], r['mode'], r['engine'], r['id'])
            if src is None:
                continue
            dest = shots / f"{r['look']}-{r['mode']}" / f"{r['id']}.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            # the evidence branch lives in a public repo: cap the width and re-encode so 100 images stay a few MB
            from PIL import Image
            with Image.open(src) as image:
                image = image.convert('RGB')
                if image.width > 1400:
                    image = image.resize((1400, round(image.height * 1400 / image.width)))
                image.quantize(colors=128).save(dest, optimize=True)
            copied += 1
        print(f'{len(below)} below the line; {copied} side-by-sides copied to {shots}')
    else:
        print(f'{len(below)} below the line')


if __name__ == '__main__':
    main()
