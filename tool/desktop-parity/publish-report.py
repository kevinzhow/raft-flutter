#!/usr/bin/env python3
"""Build an unpublished full-frame desktop comparison report.

Only equal-sized original rasters are compared. Delta-24 is diagnostic,
never a visual acceptance threshold. Retry captures supplement missing first
captures; first failures and each batch's different source binding survive.
Dependencies: Pillow, numpy (same as compare.py). No browser/SDK required.
"""
import argparse
import hashlib
import html
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def copy_asset(path, out, relative):
    destination = out / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, destination)
    assert sha(destination) == sha(path), f'Copy mismatch: {relative}'
    return {'path': str(relative), 'sha256': sha(path), 'bytes': path.stat().st_size}


def compare_full_frames(web, native, diff, sheet):
    """Do not intersect/crop/resize. Return no metrics for unequal sizes."""
    with Image.open(web) as wi, Image.open(native) as ni:
        wi.load()
        ni.load()
        if wi.size != ni.size:
            return {'sizeEqual': False, 'webSize': list(wi.size), 'flutterSize': list(ni.size)}
        w, n = wi.convert('RGBA'), ni.convert('RGBA')
    wa, na = np.asarray(w), np.asarray(n)
    delta = np.abs(wa.astype(np.int16) - na.astype(np.int16))
    maximum = delta.max(axis=2)
    diagnostic = maximum > 24
    mask = np.where(diagnostic[..., None], [230, 40, 40], (wa[..., :3] // 3 + 170)).astype(np.uint8)
    Image.fromarray(mask).save(diff)
    width, height = w.size
    combined = Image.new('RGB', (width * 3 + 16, height + 28), 'white')
    combined.paste(w, (0, 28))
    combined.paste(n, (width + 8, 28))
    combined.paste(Image.fromarray(mask), (width * 2 + 16, 28))
    draw = ImageDraw.Draw(combined)
    draw.text((6, 8), 'SOURCE WEB - original full frame', fill='black')
    draw.text((width + 14, 8), 'FLUTTER LINUX - original full frame', fill='black')
    draw.text((width * 2 + 22, 8), 'DELTA > 24 DIAGNOSTIC ONLY - NOT ACCEPTANCE', fill='black')
    combined.save(sheet)
    return {
        'sizeEqual': True, 'webSize': list(w.size), 'flutterSize': list(n.size),
        'rgbaMeanAbsoluteDelta': float(delta.mean()),
        'exactPixelMismatchRatio': float((maximum != 0).mean()),
        'delta24MismatchRatio': float(diagnostic.mean()),
        'diagnosticThreshold': 24, 'acceptanceThreshold': None,
        'normalization': 'none; no resize, crop or min intersection',
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--first-results', type=Path, required=True)
    p.add_argument('--retry-results', type=Path, required=True)
    p.add_argument('--first-binding', type=Path, required=True)
    p.add_argument('--retry-commit', required=True)
    p.add_argument('--retry-source-hash', required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    if a.out.exists():
        p.error('Output already exists; choose a fresh directory to preserve prior evidence.')
    first = read(a.first_binding)
    for label, value, size in [
        ('first commit', first.get('commit', ''), 40),
        ('first source hash', first.get('inputHash', ''), 64),
        ('retry commit', a.retry_commit, 40), ('retry source hash', a.retry_source_hash, 64),
    ]:
        if not re.fullmatch('[a-f0-9]{' + str(size) + '}', value):
            p.error(f'{label} must be its full hexadecimal value')
    manifest = read(a.manifest)
    cases = manifest['cases']
    ids = [c['id'] for c in cases]
    if len(ids) != len(set(ids)) or any(not re.fullmatch(r'[a-zA-Z0-9._-]+', i) for i in ids):
        p.error('Case IDs must be unique safe filenames.')
    out = a.out
    out.mkdir(parents=True)
    for folder in ['web', 'flutter', 'diff', 'comparison', 'history/first-native-failures', 'provenance']:
        (out / folder).mkdir(parents=True, exist_ok=True)
    first_summary = read(a.first_results / 'android/_capture-summary.json')
    retry_summary = read(a.retry_results / 'android/_capture-summary.json')
    first_results = {r['id']: r for r in first_summary['results']}
    retry_results = {r['id']: r for r in retry_summary['results']}
    bindings = {
        'first': {
            'commit': first['commit'], 'sourceHash': first['inputHash'],
            'kind': 'batch owner input receipt; individual frames do not contain compiled hash',
            'receipt': copy_asset(a.first_binding, out, Path('provenance/first-input-receipt.json')),
        },
        'retry': {
            'commit': a.retry_commit, 'sourceHash': a.retry_source_hash,
            'kind': 'Root supplied begin/end readback; no dedicated retry binding receipt',
            'authority': 'Root task directive 2026-10-09; values explicitly supplied by owner',
            'individualFrameCompiledHash': None,
        },
    }
    copy_asset(a.manifest, out, Path('provenance/desktop-cases.json'))
    copy_asset(a.first_results / 'android/_capture-summary.json', out, Path('provenance/first-native-summary.json'))
    copy_asset(a.retry_results / 'android/_capture-summary.json', out, Path('provenance/retry-native-summary.json'))
    rows = []
    for case in cases:
        cid = case['id']
        row = {'id': cid, 'title': case['title'], 'theme': case['theme'],
               'platform': 'Linux desktop (Flutter integration-test; android is provider label only)',
               'expectedViewport': case['viewport'], 'category': case['category'],
               'status': 'pending', 'formalAccepted': False, 'admission': [],
               'firstCapture': first_results.get(cid), 'retryCapture': retry_results.get(cid)}
        failure = a.first_results / f'android/{cid}.failure.json'
        if failure.exists():
            row['firstFailure'] = copy_asset(failure, out, Path(f'history/first-native-failures/{cid}.failure.json'))
            row['firstFailureStatus'] = 'fail; immutable even after a successful retry'
        wp = a.first_results / f'react/{cid}.png'
        npth = a.first_results / f'android/{cid}.png'
        batch = 'first'
        if not npth.exists():
            npth = a.retry_results / f'android/{cid}.png'
            batch = 'retry'
        row['nativeBatch'] = batch
        row['nativeBinding'] = bindings[batch]
        for side, image, destination in [('web', wp, 'web'), ('flutter', npth, 'flutter')]:
            meta = image.with_suffix('.metadata.json')
            if not image.exists() or not meta.exists():
                row['admission'].append(f'{side}: missing actual image or metadata')
                continue
            data = read(meta)
            raw = copy_asset(image, out, Path(f'{destination}/{cid}.png'))
            raw['metadata'] = copy_asset(meta, out, Path(f'{destination}/{cid}.metadata.json'))
            raw.update({'capturedAt': data.get('capturedAt'), 'theme': data.get('theme'),
                        'provider': data.get('provider'), 'providerType': data.get('providerType'),
                        'source': data.get('source'), 'viewport': data.get('viewport'),
                        'fixtureSha256': data.get('fixtureSha256'),
                        'sourceCommit': data.get('sourceCommit'), 'regions': data.get('regions', {}),
                        'fixtureMisses': data.get('fixtureMisses', [])})
            with Image.open(image) as im:
                raw['size'] = list(im.size)
                density = case['viewport']['density']
                expected = [round(case['viewport'][k] * density) for k in ['width', 'height']]
                if list(im.size) != expected:
                    row['admission'].append(f'{side}: raw size does not equal declared full viewport')
            if data.get('caseId') != cid or data.get('theme') != case['theme']:
                row['admission'].append(f'{side}: case/theme metadata mismatch')
            if data.get('viewport') != case['viewport']:
                row['admission'].append(f'{side}: viewport metadata mismatch')
            if not data.get('capturedAt'):
                row['admission'].append(f'{side}: missing capture time')
            row[side] = raw
        if 'web' in row and 'flutter' in row:
            if row['web']['fixtureSha256'] != row['flutter']['fixtureSha256']:
                row['admission'].append('Source/native fixture hashes differ')
            if row['flutter']['source'] != 'flutter-linux':
                row['admission'].append('Native provider is not declared flutter-linux')
            diff = out / f'diff/{cid}.png'
            sheet = out / f'comparison/{cid}.png'
            metrics = compare_full_frames(wp, npth, diff, sheet)
            row['diagnostic'] = metrics
            if not metrics['sizeEqual']:
                row['admission'].append('Full-frame sizes differ: FAIL; metrics/diff withheld, no min crop')
            else:
                row['diff'] = {'path': f'diff/{cid}.png', 'sha256': sha(diff)}
                row['comparison'] = {'path': f'comparison/{cid}.png', 'sha256': sha(sheet)}
        if row['admission']:
            row['status'] = 'fail'
        rows.append(row)
    report = {
        'version': 1, 'generatedAt': datetime.now(timezone.utc).isoformat(),
        'scope': '105 declared desktop cases across three themes; screenshot inventory, not app acceptance',
        'published': False, 'mixedCommits': True, 'bindings': bindings,
        'metricsPolicy': 'Raw full-frame RGBA; delta24 diagnostic only; no formal PASS or normalization',
        'summary': {
            'declared': len(rows), 'actualPairs': sum('web' in r and 'flutter' in r for r in rows),
            'firstNative': sum('flutter' in r and r['nativeBatch'] == 'first' for r in rows),
            'retryNative': sum('flutter' in r and r['nativeBatch'] == 'retry' for r in rows),
            'preservedFirstFailures': sum('firstFailure' in r for r in rows),
            'admissionFailures': sum(r['status'] == 'fail' for r in rows),
            'formalAccepted': 0,
            'themes': {t: sum(r['theme'] == t for r in rows) for t in sorted({r['theme'] for r in rows})},
        }, 'cases': rows,
    }
    write(out / 'report.json', report)
    write(out / 'receipt.json', {
        'generatedAt': report['generatedAt'], 'generatorSha256': sha(Path(__file__)),
        'manifestSha256': sha(a.manifest), 'reportSha256': sha(out / 'report.json'),
        'summary': report['summary'], 'published': False,
        'rootInputs': {'firstResults': str(a.first_results), 'retryResults': str(a.retry_results)},
        'reproduce': ['python3', str(Path(__file__).resolve()), '--manifest', str(a.manifest),
                      '--first-results', str(a.first_results), '--retry-results', str(a.retry_results),
                      '--first-binding', str(a.first_binding), '--retry-commit', a.retry_commit,
                      '--retry-source-hash', a.retry_source_hash, '--out', 'CHOOSE_NEW_OUTPUT_DIRECTORY'],
    })
    cards = []
    esc = html.escape
    for r in rows:
        images = ''.join(f'<a href="{r[s]["path"]}" target="_blank"><b>{label}</b><img loading="lazy" src="{r[s]["path"]}" alt="{esc(r["id"])} {label}"></a>'
                         for s, label in [('web', '原版 Web 整幅'), ('flutter', 'Flutter Linux 整幅')] if s in r)
        links = ''.join(f'<a target="_blank" href="{r[k]["path"]}">{label}</a> · ' for k, label in [('diff', '差异图（诊断）'), ('comparison', '整幅三联图'), ('firstFailure', '首轮 FAIL 原始记录')] if k in r)
        d = r.get('diagnostic', {})
        text = '尺寸不等：FAIL，未计算像素指标。' if d and not d['sizeEqual'] else f'Δ24诊断差异 {d.get("delta24MismatchRatio", 0):.2%}；不作为通过门槛。'
        times = ' / '.join(f'{label}: {r[s].get("capturedAt")}' for s,label in [('web','Web'),('flutter','Linux')] if s in r)
        cards.append(f'<article data-theme="{esc(r["theme"])}" data-batch="{r["nativeBatch"]}" data-id="{esc(r["id"])}"><h2>{esc(r["title"])}</h2><p>{esc(r["id"])} · {esc(r["theme"])} · {r["status"].upper()}（正式验收未完成）</p><p>{esc(times)}</p><p>Native批次 {r["nativeBatch"]} / {r["nativeBinding"]["commit"][:7]} / 源码输入 {r["nativeBinding"]["sourceHash"][:12]}；每帧元数据不包含编译hash。</p><p>{esc(text)}</p><p>{esc("; ".join(r["admission"]))}</p><div class="images">{images}</div><p>{links}<a href="{r.get("flutter",{}).get("metadata",{}).get("path","report.json")}">Native元数据</a> · <a href="{r.get("web",{}).get("metadata",{}).get("path","report.json")}">Web元数据</a></p></article>')
    page = '''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>桌面105项三主题对照</title><style>body{font:15px system-ui;margin:24px;background:#f4f4f1;color:#171715}header{position:sticky;top:0;background:#fff;padding:14px;border:1px solid #ccc;z-index:1}h1{font-size:24px;margin:0 0 8px}h2{font-size:18px}.images{display:grid;grid-template-columns:1fr 1fr;gap:16px}img{width:100%;height:auto;display:block;border:1px solid #bbb}article{background:#fff;padding:16px;margin:18px 0;border:1px solid #ccc}p{overflow-wrap:anywhere}a{color:#154f96}select,input{font:inherit;padding:6px}article[hidden]{display:none}@media(max-width:700px){.images{grid-template-columns:1fr}}</style><header><h1>桌面整页105项 / 三主题</h1><p>原版105图 + 首轮Linux99图 + 补轮Linux6图；保留首轮6 FAIL。混合c826与ddc提交，不能当成全部最新。provider android是标签，实际是Linux Flutter引擎，不是Android设备。截图全覆盖不等于App验收通过。</p><p>正式通过：0；像素Δ24只作诊断。全幅尺寸不等直接FAIL，禁止裁剪/缩放来计算相似度。</p><label>主题 <select id="theme"><option value="">全部</option><option>brutal</option><option>elegant-light</option><option>elegant-dark</option></select></label> <label>批次 <select id="batch"><option value="">全部</option><option value="first">首轮99</option><option value="retry">补轮6（首轮FAIL保留）</option></select></label> <input id="search" placeholder="搜索case"> <span id="count"></span><p><a href="report.json">完整JSON</a> · <a href="receipt.json">SHA/复现回执</a> · <a href="provenance/first-input-receipt.json">首轮来源</a></p></header>'''
    page += '\n'.join(cards)
    page += '''<script>const theme=document.querySelector('#theme'),batch=document.querySelector('#batch'),search=document.querySelector('#search');function filter(){let n=0;document.querySelectorAll('article').forEach(a=>{a.hidden=(theme.value&&a.dataset.theme!==theme.value)||(batch.value&&a.dataset.batch!==batch.value)||!a.dataset.id.includes(search.value.toLowerCase());if(!a.hidden)n++});document.querySelector('#count').textContent=n+' / 105'}[theme,batch,search].forEach(x=>x.addEventListener('input',filter));filter();</script></html>'''
    (out / 'index.html').write_text(page)
    print(json.dumps(report['summary'], ensure_ascii=False))
    print(out)


if __name__ == '__main__':
    main()
