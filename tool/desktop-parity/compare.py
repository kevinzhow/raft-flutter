#!/usr/bin/env python3
"""Pair react vs android(flutter-linux) desktop captures.

For every case present on both sides writes into <results>/../compare/:
  <id>.side-by-side.png   Web | Flutter | diff mask (red = differs)
and <results>/../compare/summary.json with, per case:
  mismatch      fraction of pixels whose max channel delta > 24
  columns       detected full-height vertical separators (x) per side
  rows          detected full-width horizontal separators (y) per side
  regions       DOM / widget probe rects from both metadata files
Usage: compare.py [results-dir]
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

repo = pathlib.Path(__file__).resolve().parents[2]
results = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else repo / '.local/desktop-parity/visual-testing-results'
out = results.parent / 'compare'
out.mkdir(parents=True, exist_ok=True)


def separators(a, axis, min_cover=0.55):
    """Positions of long straight lines: a pixel run that differs from its
    neighbour 2px away across >= min_cover of the orthogonal extent."""
    g = a.astype(np.int16).mean(axis=2)
    if axis == 0:  # vertical lines -> compare columns
        d = np.abs(g[:, 2:] - g[:, :-2]) > 18
        cover = d.mean(axis=0)
    else:
        d = np.abs(g[2:, :] - g[:-2, :]) > 18
        cover = d.mean(axis=1)
    idx = [int(i) + 1 for i in np.where(cover >= min_cover)[0]]
    merged = []
    for i in idx:
        if merged and i - merged[-1][-1] <= 3:
            merged[-1].append(i)
        else:
            merged.append([i])
    return [m[0] for m in merged]


cases = json.loads((repo / 'docs/desktop-cases.json').read_text())['cases']
summary = []
for c in cases:
    cid = c['id']
    rp, ap = results / 'react' / f'{cid}.png', results / 'android' / f'{cid}.png'
    if not (rp.exists() and ap.exists()):
        summary.append({'id': cid, 'react': rp.exists(), 'android': ap.exists()})
        continue
    r = np.asarray(Image.open(rp).convert('RGB'))
    a = np.asarray(Image.open(ap).convert('RGB'))
    h, w = min(r.shape[0], a.shape[0]), min(r.shape[1], a.shape[1])
    rr, aa = r[:h, :w], a[:h, :w]
    diff = np.abs(rr.astype(np.int16) - aa.astype(np.int16)).max(axis=2) > 24
    mask = np.where(diff[..., None], np.array([230, 40, 40], np.uint8), (rr // 3 + 170).astype(np.uint8))
    sheet = Image.new('RGB', (w * 3 + 16, h + 28), 'white')
    sheet.paste(Image.fromarray(rr), (0, 28))
    sheet.paste(Image.fromarray(aa), (w + 8, 28))
    sheet.paste(Image.fromarray(mask), (2 * w + 16, 28))
    d = ImageDraw.Draw(sheet)
    d.text((6, 8), f'WEB (react)  {cid}', fill='black')
    d.text((w + 14, 8), 'FLUTTER LINUX (android/flutter-linux)', fill='black')
    d.text((2 * w + 22, 8), f'DIFF  mismatch={diff.mean():.3f}', fill='black')
    sheet.save(out / f'{cid}.side-by-side.png')
    meta = {}
    for side, p in (('react', rp), ('android', ap)):
        mp = p.with_suffix('.metadata.json')
        meta[side] = json.loads(mp.read_text()).get('regions', {}) if mp.exists() else {}
    summary.append({
        'id': cid,
        'size': [w, h],
        'mismatch': round(float(diff.mean()), 4),
        'columns': {'react': separators(r, 0), 'android': separators(a, 0)},
        'rows': {'react': separators(r, 1, 0.6), 'android': separators(a, 1, 0.6)},
        'regions': meta,
    })
(out / 'summary.json').write_text(json.dumps(summary, indent=1) + '\n')
paired = [s for s in summary if 'mismatch' in s]
print(f'{len(paired)} paired, {len(summary) - len(paired)} unpaired -> {out}')
for s in sorted(paired, key=lambda s: -s['mismatch'])[:200]:
    print(f"{s['mismatch']:.3f}  {s['id']:60s} cols web={s['columns']['react']} fl={s['columns']['android']}")
