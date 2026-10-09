#!/usr/bin/env python3
"""Build the current behavior checklist with explicit frozen visual evidence."""
import argparse
from collections import Counter
import datetime as dt
import hashlib
import html
import importlib.machinery
import importlib.util
import json
import shutil
from pathlib import Path
from evidence import evaluate_item, read_runs

HERE = Path(__file__).resolve().parent
loader = importlib.machinery.SourceFileLoader('checklist_visual_renderer', str(HERE / 'legacy-render.py'))
spec = importlib.util.spec_from_loader(loader.name, loader)
visual = importlib.util.module_from_spec(spec)
loader.exec_module(visual)
esc = lambda value: html.escape(str(value or ''))


def render_item(item):
    label, color, _ = visual.STATUS[item['status']]
    details = []
    for check in item['checks']:
        c_label, c_color, _ = visual.STATUS[check['status']]
        proofs = ''.join(f'<li>{esc(p["name"])} · {esc(p["layer"])} · '
                         f'{esc(p["result"])}{" / skipped" if p["skipped"] else ""}'
                         f' · <a href="{esc(p["receipt"])}">运行证明</a></li>'
                         for p in check['proofs']) or '<li>尚无当前代码的带编号测试结果</li>'
        details.append(f'<details><summary>{esc(check["id"])} · '
                       f'{esc(check.get("title_zh"))} <span class="pill" style="background:{c_color}">{c_label}</span>'
                       f' · {check["passed"]}/{check["minimum_passes"]} 条页面或原生证明</summary>'
                       f'<ul>{proofs}</ul></details>')
    return (f'<tr id="{esc(item["id"])}"><td>{esc(item["id"])}</td>'
            f'<td><span class="pill" style="background:{color}">{label}</span></td>'
            f'<td>{esc(item["title_zh"])}<div class="src">Web：{esc(item["web_source"])}</div>'
            f'{"".join(details)}<details><summary>初次审计说明（历史）</summary>'
            f'{esc(item["audit_note"])}</details></td></tr>')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-hash', required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--receipt', action='append', default=[])
    parser.add_argument('--visual-receipt', action='append', default=[])
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    runs = read_runs(args.receipt, args.source_hash)
    args.out.mkdir(parents=True, exist_ok=True)
    for run in runs:
        source = Path(run['path'])
        target = args.out / 'evidence' / run['machineLogSha'][:16]
        target.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target / 'receipt.json')
        shutil.copy2(source.parent / run['machineLog'], target / run['machineLog'])
        run['path'] = str((target / 'receipt.json').relative_to(args.out))
    groups = []
    for name in ('nav', 'loading'):
        for item in json.loads((HERE / 'data' / f'{name}.json').read_text()):
            groups.append(evaluate_item(item, runs))
    counts = Counter(item['status'] for item in groups)
    sections = []
    for title in ('导航', '加载', 'Kevin 反馈'):
        items = [item for item in groups if item.get('group', '导航') == title]
        sections.append(f'<h2>{title} · 已验证 {sum(i["status"] == "verified" for i in items)}/{len(items)}</h2>'
                        '<table><tr><th>编号</th><th>状态</th><th>要对齐的行为和当前证明</th></tr>'
                        + ''.join(render_item(item) for item in items) + '</table>')
    visuals = []
    for path in args.visual_receipt:
        manifest = json.loads(Path(path).read_text())
        cases_path = Path(path).parent / manifest['casesPath']
        if hashlib.sha256(cases_path.read_bytes()).hexdigest() != manifest['casesSha']:
            raise ValueError('Frozen visual cases changed')
        cases = json.loads(cases_path.read_text())
        passed = sum(row['status'] in ('pass', 'basic-pass') for row in cases)
        visuals.append(f'<h2>{esc(manifest["title"])} · {passed}/{len(cases)}</h2>'
                       f'<p>截图代码 {esc(manifest["flutterCommit"])} · '
                       f'输入 {esc(manifest["sourceHash"])}。这是独立冻结的视觉结果。</p>'
                       + visual.visual_table(cases))
    baseline = json.loads((HERE / 'data' / 'baseline-audit.json').read_text())
    old_verified = sum(row['status'] == 'verified' for row in baseline['items'])
    receipt = {'flutterCommit': args.commit, 'sourceHash': args.source_hash,
               'generatedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
               'counts': dict(counts), 'total': len(groups), 'items': groups,
               'testReceipts': [run['path'] for run in runs],
               'historicalAudit': {'flutterCommit': baseline['flutterCommit'],
                                   'verified': old_verified, 'total': len(baseline['items'])}}
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'progress.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    page = f'''<!doctype html><html lang="zh"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Raft Flutter 对齐清单</title>
<style>body{{font:14px/1.6 system-ui,sans-serif;max-width:1180px;margin:24px auto;padding:0 16px;color:#1c1917}}
table{{border-collapse:collapse;width:100%}}td,th{{border-bottom:1px solid #e7e5e4;padding:8px;text-align:left;vertical-align:top}}
h2{{margin-top:28px}}.pill{{color:white;border-radius:99px;padding:1px 8px;font-size:12px;white-space:nowrap}}
.src,details{{font-size:12px;color:#57534e}}.note{{background:#fef9c3;padding:12px}}.bar{{display:inline-block;width:90px;height:8px;background:#eee}}.bar div{{height:8px;background:#15803d}}</style>
<h1>Raft Flutter 对齐清单</h1><p>当前测试代码 {esc(args.commit)} · 输入 {esc(args.source_hash)}</p>
<h2>当前自动验证：{counts.get('verified', 0)}/{len(groups)} 项</h2>
<div class="note">只计算与当前输入哈希一致、完整通过的带编号测试。纯模型或控制器测试最多记“部分完成”；
每个子项都需要页面或原生证明，失败、跳过、缺少子项都不会自动变成已验证。
“未开始”在自动表中表示尚未接入当前带编号证明，不代表历史代码从未改过。</div>
<details><summary>历史人工审计和验证规则</summary><p>初次人工审计（历史代码 {esc(baseline['flutterCommit'][:7])}）：{old_verified}/{len(baseline['items'])}。
旧审计状态保留在历史记录中，不充当当前测试证明。当前尚未接入的测试会逐项补上编号。</p></details>
{''.join(sections)}{''.join(visuals)}
<p><a href="progress.json">查看全部测试结果和输入版本</a></p></html>'''
    (args.out / 'index.html').write_text(page)
    print(json.dumps({'verified': counts.get('verified', 0), 'total': len(groups), 'out': str(args.out)}))


if __name__ == '__main__':
    main()
