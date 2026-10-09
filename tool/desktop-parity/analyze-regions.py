#!/usr/bin/env python3
"""Diagnose desktop regions using the same measured Source boxes on both PNGs.

Separate from official whole-frame acceptance. No resize, alignment, pixel
normalization, anti-alias mask, score-selected box or provider-specific crop.
Dependencies: Pillow and numpy, as for the existing desktop report.
"""
import argparse
import base64
from collections import Counter
from datetime import datetime, timezone
import hashlib
import html
import json
import math
from pathlib import Path
import re
import shutil

import numpy as np
from PIL import Image

NAMES = ('rail', 'sidebar', 'header', 'body', 'rightPanel')
COLORS = ('#d62828', '#9b00bd', '#005dce', '#00834d', '#d06a00')
SOURCE_COMMIT = '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6'


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pixel_box(rect, density, size):
    """Use half-open DOM rectangles and raster pixel-center membership.

    Refuse out-of-bounds boxes instead of clipping them into a better score.
    Adjacent fractional DOM regions cannot count the same boundary pixel twice.
    """
    values = [rect.get(k) for k in ('x', 'y', 'width', 'height')]
    if not all(isinstance(v, (int, float)) and math.isfinite(v) for v in values):
        raise ValueError('invalid/nonfinite DOM rectangle')
    x, y, width, height = values
    if density <= 0 or width <= 0 or height <= 0:
        raise ValueError('nonpositive rectangle or density')
    if x < 0 or y < 0 or (x + width) * density > size[0] + 1e-6 or (y + height) * density > size[1] + 1e-6:
        raise ValueError('DOM rectangle extends beyond the original raster')
    box = [math.ceil(v * density - .5) for v in (x, y, x + width, y + height)]
    if box[2] <= box[0] or box[3] <= box[1]:
        raise ValueError('DOM rectangle contains no raster pixel centers')
    return box


def compare_pixels(left, right):
    delta = np.abs(left.astype(np.int16) - right.astype(np.int16))
    maximum = delta.max(axis=2)
    exact = float((maximum == 0).mean())
    return {
        'pixels': int(maximum.size), 'exactMatchingPixels': int((maximum == 0).sum()),
        'rawRgbaExactSimilarity': exact,
        'rawRgbaMeanAbsoluteDelta': float(delta.mean()),
        'delta24MismatchRatio': float((maximum > 24).mean()),
        'diagnosticAbove96': exact > .96,
        'formalAccepted': False,
    }


def rect_equal(a, b):
    return isinstance(a, dict) and isinstance(b, dict) and all(
        isinstance(a.get(k), (int, float)) and isinstance(b.get(k), (int, float)) and
        math.isclose(a[k], b[k], abs_tol=1e-6, rel_tol=0)
        for k in ('x', 'y', 'width', 'height'))


def analyze(case, web_meta, native_meta, measured, web, native):
    """Admission before metrics; missing geometry never becomes a pixel pass."""
    regions = {name: {
        'sourceStatus': measured.get('regions', {}).get(name, {}).get('status', 'unmeasured'),
        'sourceMeasurement': measured.get('regions', {}).get(name),
        'status': 'blocked', 'formalAccepted': False,
    } for name in NAMES}
    result = {'id': case['id'], 'theme': case['theme'], 'regions': regions, 'admissionErrors': []}
    errors = result['admissionErrors']
    for label, meta in [('Web', web_meta), ('Flutter', native_meta), ('DOM', measured)]:
        if meta.get('caseId') != case['id'] or meta.get('theme') != case['theme']:
            errors.append(f'{label} case/theme differs from manifest')
        if meta.get('viewport') != case['viewport']:
            errors.append(f'{label} viewport/density differs from manifest')
    if measured.get('schemaVersion') != 1 or measured.get('coordinateSystem') != 'Source CSS viewport':
        errors.append('unknown DOM measurement contract')
    if web_meta.get('sourceCommit') != SOURCE_COMMIT or measured.get('sourceCommit') != SOURCE_COMMIT:
        errors.append('Web/DOM source is not the pinned reference')
    fixtures = [m.get('fixtureSha256') for m in (web_meta, native_meta, measured)]
    if not fixtures[0] or len(set(fixtures)) != 1:
        errors.append('Web/Flutter/DOM fixture binding differs or is absent')
    if measured.get('route') != web_meta.get('route'):
        errors.append('DOM initial route differs from captured Web route')
    known = {'rail': 'rail', 'sidebar': 'sidebar', 'rightPanel': 'thread'}
    for name, key in known.items():
        prior = web_meta.get('regions', {}).get(key)
        if prior is not None and not rect_equal(prior, measured.get('regions', {}).get(name, {}).get('rect')):
            errors.append(f'{name} DOM differs from original Web capture geometry')
    prior_main = web_meta.get('regions', {}).get('threadMain')
    if prior_main is not None and not rect_equal(prior_main, measured.get('mainFrame', {}).get('rect')):
        errors.append('main frame DOM differs from original Web capture geometry')
    size = (web.shape[1], web.shape[0])
    expected = tuple(round(case['viewport'][k] * case['viewport'].get('density', 1)) for k in ('width', 'height'))
    if web.shape != native.shape or size != expected:
        errors.append('original raster sizes differ or do not match the manifest; no intersection/resize')
    if errors:
        return result
    result['wholeFrameRawDiagnostic'] = compare_pixels(web, native)
    density = case['viewport'].get('density', 1)
    coverage = np.zeros(web.shape[:2], dtype=np.uint8)
    for name, region in regions.items():
        status = region['sourceStatus']
        region['status'] = status
        if status != 'eligible':
            continue
        try:
            box = pixel_box(region['sourceMeasurement'].get('rect', {}), density, size)
        except ValueError as error:
            region.update(status='blocked', reason=str(error))
            continue
        x0, y0, x1, y1 = box
        coverage[y0:y1, x0:x1] += 1
        region.update(pixelRect={'x': x0, 'y': y0, 'width': x1-x0, 'height': y1-y0},
                      metrics=compare_pixels(web[y0:y1, x0:x1], native[y0:y1, x0:x1]))
    result['regionCoverage'] = {
        'wholeFramePixels': int(coverage.size), 'coveredPixels': int((coverage > 0).sum()),
        'unassignedPixels': int((coverage == 0).sum()), 'overlapPixels': int((coverage > 1).sum()),
        'note': 'unassigned/overlap pixels remain in the independent whole-frame result; no regional aggregate acceptance',
    }
    for key, selected in [('unassigned', coverage == 0), ('overlap', coverage > 1)]:
        if selected.any():
            # Keep excluded layout borders measurable, without adding another
            # score-selected region or changing the five region denominators.
            result['regionCoverage'][key + 'Metrics'] = compare_pixels(
                web[selected][None, :, :], native[selected][None, :, :])
    return result


def summarize(rows, total):
    result = {}
    for name in NAMES:
        regions = [row['regions'][name] for row in rows]
        eligible = [r for r in regions if r['status'] == 'eligible' and 'metrics' in r]
        above = sum(r['metrics']['diagnosticAbove96'] for r in eligible)
        result[name] = {
            'totalManifestCases': total, 'reportedCases': len(rows),
            'statusCounts': dict(Counter(r['status'] for r in regions)),
            'sourceStatusCounts': dict(Counter(r['sourceStatus'] for r in regions)),
            'eligibleMeasured': len(eligible), 'diagnosticAbove96Count': above,
            'above96Denominator': len(eligible), 'formalAcceptedCount': 0,
            'meanRawRgbaExactSimilarity': float(np.mean([r['metrics']['rawRgbaExactSimilarity'] for r in eligible])) if eligible else None,
        }
    return result


def asset(path, out, relative):
    destination = out / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, destination)
    digest = sha(path)
    if sha(destination) != digest:
        raise ValueError(f'asset copy differs: {path}')
    return {'path': relative, 'sha256': digest, 'bytes': path.stat().st_size}


def bind_official(original, web_path, native_path):
    if not original:
        return None
    matches = (web_path.exists() and native_path.exists() and
               original.get('baselineSha256') == sha(web_path) and
               original.get('currentSha256') == sha(native_path))
    return {'status': original.get('status') if matches else 'stale-input-binding',
            'inputHashesMatch': matches, 'originalStatus': original.get('status'),
            'metrics': original.get('metrics'), 'scope': 'unaltered full-frame official entry'}


def compare_runs(current, previous):
    """Retain every previous/current case, including full-frame regressions.

    Region contributions use the full original raster as their denominator,
    rather than adding independently averaged regional percentages.
    """
    comparison = {'admitted': False, 'admissionErrors': [], 'regions': {}}
    errors = comparison['admissionErrors']
    if current.get('admissionErrors') or previous.get('admissionErrors'):
        errors.append('previous/current region admission must both succeed')
    if current.get('id') != previous.get('id') or current.get('theme') != previous.get('theme'):
        errors.append('previous/current case/theme differs')
    current_web_sha = current.get('assets', {}).get('web', {}).get('sha256')
    previous_web_sha = previous.get('assets', {}).get('web', {}).get('sha256')
    if not current_web_sha or current_web_sha != previous_web_sha:
        errors.append('previous/current original Source PNG bytes differ')
    if errors:
        return comparison
    whole = current['wholeFrameRawDiagnostic']
    old_whole = previous['wholeFrameRawDiagnostic']
    comparison['admitted'] = True
    comparison['wholeFrameRawDeltaPercentagePoints'] = (
        whole['exactMatchingPixels'] - old_whole['exactMatchingPixels']) / whole['pixels'] * 100
    for name in NAMES:
        now, old = current['regions'][name], previous['regions'][name]
        if now.get('pixelRect') != old.get('pixelRect') or 'metrics' not in now or 'metrics' not in old:
            comparison['regions'][name] = {'status': 'unavailable', 'formalAccepted': False}
            continue
        n, p = now['metrics'], old['metrics']
        delta_pixels = n['exactMatchingPixels'] - p['exactMatchingPixels']
        comparison['regions'][name] = {
            'status': 'eligible', 'previousSimilarity': p['rawRgbaExactSimilarity'],
            'currentSimilarity': n['rawRgbaExactSimilarity'],
            'regionDeltaPercentagePoints': delta_pixels / n['pixels'] * 100,
            'wholeFrameContributionPercentagePoints': delta_pixels / whole['pixels'] * 100,
            'exactMatchingPixelDelta': delta_pixels, 'formalAccepted': False,
        }
    for key in ('unassigned', 'overlap'):
        now = current['regionCoverage'].get(key + 'Metrics')
        old = previous['regionCoverage'].get(key + 'Metrics')
        if now and old and now['pixels'] == old['pixels']:
            comparison[key + 'WholeFrameContributionPercentagePoints'] = (
                now['exactMatchingPixels'] - old['exactMatchingPixels']) / whole['pixels'] * 100
    previous_official, current_official = previous.get('official'), current.get('official')
    if (previous_official and current_official and previous_official['inputHashesMatch'] and
            current_official['inputHashesMatch']):
        old_score = previous_official['metrics'].get('pixelPerfectSimilarity')
        new_score = current_official['metrics'].get('pixelPerfectSimilarity')
        if old_score is not None and new_score is not None:
            comparison['officialWholeFrame'] = {
                'previousSimilarity': old_score, 'currentSimilarity': new_score,
                'deltaPercentagePoints': (new_score - old_score) * 100,
                'scope': 'existing verified whole-frame JSON entries; unchanged',
            }
    return comparison


def summarize_changes(rows):
    comparisons = [(r['id'], r.get('comparison', {})) for r in rows]
    admitted = [(cid, c) for cid, c in comparisons if c.get('admitted')]
    official = [(cid, c['officialWholeFrame']) for cid, c in admitted if 'officialWholeFrame' in c]
    regressions = [{'id': cid, **scores} for cid, scores in official if scores['deltaPercentagePoints'] < 0]
    return {
        'totalCases': len(rows), 'admittedCases': len(admitted), 'officialBoundCases': len(official),
        'officialImproved': sum(s['deltaPercentagePoints'] > 0 for _, s in official),
        'officialRegressed': len(regressions),
        'officialUnchanged': sum(s['deltaPercentagePoints'] == 0 for _, s in official),
        'officialMeanPreviousSimilarity': float(np.mean([s['previousSimilarity'] for _, s in official])) if official else None,
        'officialMeanCurrentSimilarity': float(np.mean([s['currentSimilarity'] for _, s in official])) if official else None,
        'officialRegressions': regressions,
        'formalAccepted': False,
    }


def overlay_svg(row, image):
    width, height = row['rasterSize']
    pieces = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
              f'<image href="{html.escape(image, quote=True)}" width="{width}" height="{height}"/>']
    for name, color in zip(NAMES, COLORS):
        region = row['regions'][name]
        r = region.get('pixelRect')
        if r is None:
            continue
        pieces += [f'<rect x="{r["x"]}" y="{r["y"]}" width="{r["width"]}" height="{r["height"]}" fill="none" stroke="{color}" stroke-width="2"/>',
                   f'<text x="{r["x"]+3}" y="{r["y"]+15}" fill="{color}" stroke="white" stroke-width=".5" paint-order="stroke" font-size="12">{name}</text>']
    return '\n'.join(pieces + ['</svg>'])


def render_report(data):
    parts = ['<!doctype html><html lang="en"><meta charset="utf-8"><title>Desktop Source-region diagnostics</title>',
             '<style>body{font:15px system-ui;margin:24px;color:#222}table{border-collapse:collapse;margin:12px 0}td,th{padding:6px 10px;border:1px solid #ccc}img{width:49%;height:auto;vertical-align:top}code{overflow-wrap:anywhere}summary{cursor:pointer;padding:8px} .warn{color:#934400}</style>',
             '<h1>Desktop region diagnostics</h1><p>Original whole-frame acceptance remains separate. These are Source DOM regions applied at the same coordinates to both original rasters. No alignment, resize, anti-alias mask or score-selected crop. Region “&gt;96%” is diagnostic only.</p>',
             '<p>Absent/hidden/ambiguous/unmeasured regions have no pixel score. Main body includes all space below the measured top header, including tabs and composer. Overlays remain included in the pixels.</p>',
             '<table><tr><th>Region</th><th>Measured / total cases</th><th>Diagnostic &gt;96% / eligible</th><th>States</th></tr>']
    for name, s in data['summary'].items():
        parts.append(f'<tr><td>{name}</td><td>{s["eligibleMeasured"]} / {s["totalManifestCases"]}</td><td>{s["diagnosticAbove96Count"]} / {s["above96Denominator"]}</td><td>{html.escape(json.dumps(s["statusCounts"]))}</td></tr>')
    parts.append('</table><p><a href="regions.json">Full coordinates and provenance JSON</a></p>')
    if data.get('officialWholeFrame'):
        parts.append('<p><a href="provenance/official-whole-frame.json">Unmodified official whole-frame report</a></p>')
    if data.get('changeSummary'):
        changes = data['changeSummary']
        parts.append(f'<h2>Full-frame changes across all {changes["totalCases"]} cases</h2><p>Verified official input bindings: {changes["officialBoundCases"]}; improved: {changes["officialImproved"]}; regressed: {changes["officialRegressed"]}; unchanged: {changes["officialUnchanged"]}. This does not revise acceptance.</p>')
        parts.append('<table><tr><th>Every official regression</th><th>Whole-frame delta (percentage points)</th><th>Regional whole-frame contributions (percentage points)</th></tr>')
        by_id = {r['id']: r for r in data['cases']}
        for regression in changes['officialRegressions']:
            row = by_id[regression['id']]
            contributions = {name: round(value['wholeFrameContributionPercentagePoints'], 6)
                             for name, value in row['comparison']['regions'].items()
                             if 'wholeFrameContributionPercentagePoints' in value}
            parts.append(f'<tr><td><a href="#{html.escape(row["id"])}">{html.escape(row["id"])}</a></td><td>{regression["deltaPercentagePoints"]:.6f}</td><td><code>{html.escape(json.dumps(contributions))}</code></td></tr>')
        parts.append('</table><p><a href="provenance/previous-official-whole-frame.json">Unmodified previous official whole-frame report</a></p>')
    for row in data['cases']:
        official = row.get('official', {})
        parts.append(f'<details id="{html.escape(row["id"])}"><summary>{html.escape(row["id"])} — official: {html.escape(official.get("status", "unavailable"))}</summary>')
        if row.get('admissionErrors'):
            parts.append(f'<p class="warn">{html.escape("; ".join(row["admissionErrors"]))}</p>')
        if 'assets' in row:
            parts.append(f'<p>Original full Source frame | original full Flutter frame, identical Source region outlines</p><img loading="lazy" src="frames/{row["id"]}.web.svg"><img loading="lazy" src="frames/{row["id"]}.flutter.svg">')
        if row.get('previous', {}).get('assets'):
            parts.append(f'<p>Previous original full Flutter frame, identical Source region outlines</p><img loading="lazy" src="frames/{row["id"]}.previous.flutter.svg">')
        if 'regionCoverage' in row:
            coverage = row['regionCoverage']
            parts.append(f'<p>Whole-frame pixels: {coverage["wholeFramePixels"]}; regional covered: {coverage["coveredPixels"]}; unassigned: {coverage["unassignedPixels"]}; overlap: {coverage["overlapPixels"]}. Unassigned pixels remain in the whole-frame result.</p>')
        parts.append('<table><tr><th>Region</th><th>Status</th><th>Source CSS rect</th><th>Raw RGBA exact similarity</th><th>Previous/current delta and whole-frame contribution</th></tr>')
        for name, r in row['regions'].items():
            score = r.get('metrics', {}).get('rawRgbaExactSimilarity')
            change = row.get('comparison', {}).get('regions', {}).get(name, {})
            change_text = (f'{change["regionDeltaPercentagePoints"]:.6f} pp in region; '
                           f'{change["wholeFrameContributionPercentagePoints"]:.6f} pp of whole frame') if change.get('status') == 'eligible' else 'unavailable'
            parts.append(f'<tr><td>{name}</td><td>{html.escape(r["status"])}</td><td><code>{html.escape(json.dumps((r.get("sourceMeasurement") or {}).get("rect")))}</code></td><td>{f"{score * 100:.6f}%" if score is not None else "unavailable"}</td><td>{change_text}</td></tr>')
        parts.append('</table></details>')
    return '\n'.join(parts + ['</html>'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--results', type=Path, required=True)
    parser.add_argument('--measurements', type=Path, required=True)
    parser.add_argument('--previous-results', type=Path, help='Optional complete older capture; retain every full-frame regression and same-box regional changes')
    parser.add_argument('--manifest', type=Path, default=Path(__file__).resolve().parents[2] / 'docs/desktop-cases.json')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        parser.error('Choose a fresh output directory; preserve previous evidence.')
    cases = read(args.manifest)['cases']
    ids = [c['id'] for c in cases]
    if len(ids) != len(set(ids)) or any(not re.fullmatch(r'[a-zA-Z0-9._-]+', cid) for cid in ids):
        parser.error('Manifest case IDs must be unique safe filenames.')
    args.out.mkdir(parents=True)
    manifest_asset = asset(args.manifest, args.out, 'provenance/desktop-cases.json')
    official_path = args.results / 'diff/react__android.json'
    official = read(official_path) if official_path.exists() else None
    official_rows = {r['id']: r for r in official.get('results', [])} if official else {}
    official_asset = asset(official_path, args.out, 'provenance/official-whole-frame.json') if official else None
    input_receipt = args.results.parent / 'input-receipt.json'
    input_asset = asset(input_receipt, args.out, 'provenance/input-receipt.json') if input_receipt.exists() else None
    previous_path = args.previous_results / 'diff/react__android.json' if args.previous_results else None
    previous_official = read(previous_path) if previous_path and previous_path.exists() else None
    previous_official_rows = {r['id']: r for r in previous_official.get('results', [])} if previous_official else {}
    previous_official_asset = asset(previous_path, args.out, 'provenance/previous-official-whole-frame.json') if previous_official else None
    previous_receipt = args.previous_results.parent / 'input-receipt.json' if args.previous_results else None
    previous_input_asset = asset(previous_receipt, args.out, 'provenance/previous-input-receipt.json') if previous_receipt and previous_receipt.exists() else None
    rows = []
    for case in cases:
        cid = case['id']
        wp, npth = [args.results / f'{side}/{cid}.png' for side in ('react', 'android')]
        wm, nm = wp.with_suffix('.metadata.json'), npth.with_suffix('.metadata.json')
        mp = args.measurements / f'{cid}.regions.json'
        missing = [str(p) for p in (wp, npth, wm, nm, mp) if not p.exists()]
        if missing:
            measured = read(mp) if mp.exists() else {}
            row = {'id': cid, 'theme': case['theme'], 'admissionErrors': ['missing inputs: ' + ', '.join(missing)],
                   'regions': {name: {'sourceStatus': measured.get('regions', {}).get(name, {}).get('status', 'unmeasured'),
                                     'sourceMeasurement': measured.get('regions', {}).get(name), 'status': 'unmeasured', 'formalAccepted': False} for name in NAMES}}
        else:
            with Image.open(wp) as wim, Image.open(npth) as nim:
                web, native = np.asarray(wim.convert('RGBA')), np.asarray(nim.convert('RGBA'))
            row = analyze(case, read(wm), read(nm), read(mp), web, native)
            row['rasterSize'] = [web.shape[1], web.shape[0]]
            row['assets'] = {
                'web': asset(wp, args.out, f'frames/{cid}.web.png'),
                'flutter': asset(npth, args.out, f'frames/{cid}.flutter.png'),
                'webMetadata': asset(wm, args.out, f'provenance/{cid}.web.metadata.json'),
                'flutterMetadata': asset(nm, args.out, f'provenance/{cid}.flutter.metadata.json'),
                'measurement': asset(mp, args.out, f'provenance/{cid}.regions.json'),
            }
            for side in ('web', 'flutter'):
                # SVG loaded as an <img> cannot fetch external image resources.
                # Embed the byte-identical copied PNG without rerasterizing it.
                encoded = base64.b64encode((args.out / row['assets'][side]['path']).read_bytes()).decode('ascii')
                (args.out / f'frames/{cid}.{side}.svg').write_text(overlay_svg(row, f'data:image/png;base64,{encoded}'))
        bound = bind_official(official_rows.get(cid), wp, npth)
        if bound:
            row['official'] = bound
        if args.previous_results:
            old_wp, old_np = [args.previous_results / f'{side}/{cid}.png' for side in ('react', 'android')]
            old_wm, old_nm = old_wp.with_suffix('.metadata.json'), old_np.with_suffix('.metadata.json')
            old_missing = [str(p) for p in (old_wp, old_np, old_wm, old_nm, mp) if not p.exists()]
            if old_missing:
                previous = {'id': cid, 'theme': case['theme'], 'admissionErrors': ['missing previous inputs: ' + ', '.join(old_missing)]}
            else:
                with Image.open(old_wp) as image, Image.open(old_np) as old_image:
                    old_web, old_native = np.asarray(image.convert('RGBA')), np.asarray(old_image.convert('RGBA'))
                previous = analyze(case, read(old_wm), read(old_nm), read(mp), old_web, old_native)
                previous['rasterSize'] = [old_web.shape[1], old_web.shape[0]]
                previous['assets'] = {
                    'web': asset(old_wp, args.out, f'frames/{cid}.previous.web.png'),
                    'flutter': asset(old_np, args.out, f'frames/{cid}.previous.flutter.png'),
                    'webMetadata': asset(old_wm, args.out, f'provenance/{cid}.previous.web.metadata.json'),
                    'flutterMetadata': asset(old_nm, args.out, f'provenance/{cid}.previous.flutter.metadata.json'),
                }
                encoded = base64.b64encode(old_np.read_bytes()).decode('ascii')
                (args.out / f'frames/{cid}.previous.flutter.svg').write_text(overlay_svg(previous, f'data:image/png;base64,{encoded}'))
                old_bound = bind_official(previous_official_rows.get(cid), old_wp, old_np)
                if old_bound:
                    previous['official'] = old_bound
            row['previous'] = previous
            row['comparison'] = compare_runs(row, previous)
        rows.append(row)
    data = {'schemaVersion': 1, 'generatedAt': datetime.now(timezone.utc).isoformat(),
            'sourceCommit': SOURCE_COMMIT, 'manifest': manifest_asset,
            'officialWholeFrame': official_asset, 'officialSummaryUnmodified': official.get('summary') if official else None,
            'inputReceipt': input_asset, 'previousInputReceipt': previous_input_asset,
            'previousOfficialWholeFrame': previous_official_asset,
            'previousOfficialSummaryUnmodified': previous_official.get('summary') if previous_official else None,
            'diagnosticContract': {'sameSourceRectangleForBoth': True, 'pixelMembership': 'pixel centers in half-open Source DOM rectangle',
                                   'normalization': 'none', 'acceptance': 'none; >96% region count is diagnostic only',
                                   'missingRegionIsPass': False, 'body': 'entire measured main frame below its top header, or entire frame when header absent'},
            'summary': summarize(rows, len(cases)), 'cases': rows}
    if args.previous_results:
        data['changeSummary'] = summarize_changes(rows)
    (args.out / 'regions.json').write_text(json.dumps(data, indent=2) + '\n')
    (args.out / 'index.html').write_text(render_report(data))
    print(json.dumps(data['summary'], indent=2))
    print(f'Separate unpublished region report: {args.out / "index.html"}')


if __name__ == '__main__':
    main()
