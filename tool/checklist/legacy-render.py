#!/usr/bin/env python3
"""Build the raft-flutter alignment checklist page.

Inputs: behaviour items (JSON lists with id/title_zh/web_source/status/evidence)
and the full visual matrix cases.json. Output: one static index.html.
"""
import argparse
import collections
import datetime
import html
import json
import pathlib

STATUS = {
    'verified': ('已验证', '#15803d', 1.0),
    'implemented_unverified': ('已修待验证', '#ca8a04', 0.5),
    'partial': ('部分完成', '#ea580c', 0.25),
    'not_started': ('未开始', '#b91c1c', 0.0),
}

AREAS = [
    ('components.ui', '基础组件'),
    ('components.navigation', '底栏'),
    ('components.auth', '登录注册'),
    ('screens.auth', '登录注册'),
    ('components.thread', '会话与消息'),
    ('components.home', '首页 / 搜索 / 动态 / 通知'),
    ('components.tasks', '任务'),
    ('components.channel', '频道设置与成员'),
    ('components.members', '成员 / Agent'),
    ('screens.members', '成员 / Agent'),
    ('components.settings', '设置'),
    ('screens.settings', '设置'),
    ('screens.home', '首页'),
    ('screens.desktop.chat', '桌面 · 聊天'),
    ('screens.desktop.activity', '桌面 · 动态'),
    ('screens.desktop.search', '桌面 · 搜索'),
    ('screens.desktop.tasks', '桌面 · 任务'),
    ('screens.desktop.members', '桌面 · 成员'),
    ('screens.desktop.computers', '桌面 · 电脑'),
    ('screens.desktop.settings', '桌面 · 设置'),
    ('screens.desktop.notification-center', '桌面 · 通知中心'),
    ('screens.desktop.state', '桌面 · 交互状态'),
]
THEMES = [('brutal', 'Brutal 浅色'), ('elegant-light', 'Elegant 浅色'),
          ('elegant-dark', 'Elegant 深色')]


def area(case_id):
    for prefix, name in AREAS:
        if case_id.startswith(prefix):
            return name
    return '其他'


def theme(row):
    t = row.get('matrixTheme') or row.get('baselineMetadata', {}).get('theme', '')
    return 'brutal' if t.startswith('brutal') else t


def esc(s):
    return html.escape(str(s or ''))


def bar(done, total):
    pct = 0 if not total else round(100 * done / total)
    return (f'<div class="bar"><div style="width:{pct}%"></div></div>'
            f'<span class="num">{done}/{total} · {pct}%</span>')


def visual_table(cases):
    cell = collections.defaultdict(lambda: [0, 0])
    order = []
    for r in cases:
        a = area(r['id'])
        if a not in order:
            order.append(a)
        k = (a, theme(r))
        cell[k][1] += 1
        cell[k][0] += r['status'] in ('pass', 'basic-pass')
    rows = []
    for a in order:
        tds = []
        for t, _ in THEMES:
            done, total = cell[(a, t)]
            tds.append(f'<td>{bar(done, total) if total else "—"}</td>')
        rows.append(f'<tr><th>{esc(a)}</th>{"".join(tds)}</tr>')
    head = ''.join(f'<th>{n}</th>' for _, n in THEMES)
    return f'<table class="vis"><tr><th>区域</th>{head}</tr>{"".join(rows)}</table>'


def item_table(items):
    out = []
    for it in items:
        label, color, _ = STATUS[it['status']]
        out.append(
            f'<tr><td class="id">{esc(it["id"])}</td>'
            f'<td><span class="pill" style="background:{color}">{label}</span></td>'
            f'<td>{esc(it["title_zh"])}</td>'
            f'<td class="ev">{esc(it.get("evidence"))}'
            f'<div class="src">Web：{esc(it.get("web_source"))}</div></td></tr>')
    return ('<table class="items"><tr><th>编号</th><th>状态</th><th>要对齐的行为</th>'
            '<th>依据</th></tr>' + ''.join(out) + '</table>')


def score(items):
    return sum(STATUS[i['status']][2] for i in items), len(items)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--group', action='append', nargs=2, metavar=('TITLE', 'JSON'),
                    required=True)
    ap.add_argument('--matrix', required=True)
    ap.add_argument('--commit', required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()

    groups = []
    for title, path in a.group:
        items = json.loads(pathlib.Path(path).read_text())
        by = collections.OrderedDict()
        for it in items:
            by.setdefault(it.get('group') or title, []).append(it)
        groups.extend(by.items())
    cases = json.loads(pathlib.Path(a.matrix).read_text())

    all_items = [i for _, items in groups for i in items]
    counts = collections.Counter(i['status'] for i in all_items)
    vdone = sum(r['status'] in ('pass', 'basic-pass') for r in cases)
    official = [r for r in cases if r.get('surface') != 'desktop' and theme(r) == 'brutal']

    summary = ''.join(
        f'<span class="pill" style="background:{STATUS[k][1]}">{STATUS[k][0]} {counts.get(k, 0)}</span> '
        for k in STATUS)
    sections = []
    for title, items in groups:
        s, n = score(items)
        done = sum(i['status'] == 'verified' for i in items)
        sections.append(f'<h2>{esc(title)} <small>已验证 {done}/{n}</small></h2>{item_table(items)}')

    now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC')
    page = f'''<!doctype html><html lang="zh"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Raft Flutter 对齐清单</title>
<style>
body{{font:14px/1.55 system-ui,'Noto Sans CJK SC',sans-serif;margin:24px auto;max-width:1180px;padding:0 16px;color:#1c1917}}
h1{{margin:0 0 4px}} h2{{margin:28px 0 8px;font-size:18px}} h2 small{{font-weight:400;color:#57534e}}
.meta{{color:#57534e;margin-bottom:16px}}
.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:12px}}
.card{{border:1px solid #d6d3d1;border-radius:8px;padding:12px}} .card b{{font-size:22px;display:block}}
table{{border-collapse:collapse;width:100%}} td,th{{border-bottom:1px solid #e7e5e4;padding:6px 8px;text-align:left;vertical-align:top}}
.pill{{color:#fff;border-radius:999px;padding:1px 8px;font-size:12px;white-space:nowrap}}
.id{{font-family:monospace;white-space:nowrap}} .ev{{color:#44403c;font-size:12px;max-width:420px}} .src{{color:#78716c;margin-top:2px}}
.bar{{display:inline-block;width:90px;height:8px;background:#e7e5e4;border-radius:4px;vertical-align:middle;margin-right:6px}}
.bar div{{height:8px;background:#15803d;border-radius:4px}} .num{{font-size:12px;color:#44403c}}
.note{{background:#fef9c3;border:1px solid #eab308;border-radius:8px;padding:10px 12px;margin:12px 0}}
</style>
<h1>Raft Flutter 对齐清单</h1>
<div class="meta">代码版本 {esc(a.commit)} · 生成于 {now}</div>
<div class="note">状态规则：<b>已验证</b> = 有测试在真实代码上证明了这条行为；<b>已修待验证</b> = 代码改了但还没有测试证明；
<b>部分完成</b> = 只做了一部分；<b>未开始</b> = 还是旧行为。只有“已验证”算完成。</div>
<div class="cards">
<div class="card">行为对齐（导航 / 加载 / 反馈问题）<b>{counts.get("verified", 0)}/{len(all_items)} 已验证</b>{summary}</div>
<div class="card">视觉对比（三主题手机 + 桌面）<b>{vdone}/{len(cases)} 通过</b>{bar(vdone, len(cases))}</div>
<div class="card">官方 99 个用例（本次完整矩阵运行）<b>{sum(r["status"] in ("pass", "basic-pass") for r in official)}/{len(official)} 通过</b>像素一致率 &gt; 96% 算通过</div>
</div>
{"".join(sections)}
<h2>视觉对比：各区域 × 主题 <small>手机用例 99 个 × 3 主题，桌面 35 个 × 3 主题</small></h2>
{visual_table(cases)}
</html>'''
    out = pathlib.Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page)
    print(out, len(all_items), dict(counts), vdone, len(cases))


if __name__ == '__main__':
    main()
