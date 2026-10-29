"""Nightly visual regression job (job 4 of tool/nightly-quality): the fast subset of the three-level suite.

Runs `tool/parity-ext/run regress --fast` (L1 frame cases + key L2 pages, phone and desktop widths, light mode) for the
three looks: Raft against the pinned Web v1.21.23 render, Elegant and Brutal against their frozen a57b9dab originals
(docs/parity.md "Visual suite levels"). The job needs the pinned Web source checkout (`RAFT_PARITY_SOURCE`, default
~/.cache/raft-flutter/raft-source-23) and the Node toolchain list (`PARITY_TOOLCHAIN_PATHS`); without them it records
why it did not run. The summary compares every score with the previous night's and lists the drops.
"""
import json
import os
import pathlib
import sys

DROP = 0.01  # a case that lost at least one point since the previous night is a regression to look at
PASS_LINE = 0.96


def source_dir(home):
    value = os.environ.get('RAFT_PARITY_SOURCE')
    path = pathlib.Path(value) if value else pathlib.Path(home) / '.cache/raft-flutter/raft-source-23'
    return path if (path / 'packages/visual-testing/shared/sharedCases.json').is_file() else None


def command(worktree, out):
    return [sys.executable, str(pathlib.Path(worktree) / 'tool/parity-ext/run'), 'regress', '--fast', '--theme', 'all',
            '--out', str(out)]


def environment(base_env, source):
    env = dict(base_env)
    env['PARITY_RAFT_SOURCE'] = str(source)
    return env


def summarize(summary_file, previous_scores=None):
    """-> compact dict stored in the nightly summary.json (cells, lowest cases, scores for tomorrow's comparison)."""
    rows = json.loads(pathlib.Path(summary_file).read_text())['rows']
    cells = {}
    for r in rows:
        cell = cells.setdefault(f"{r['level']}|{r['look']}-{r['mode']}", [0, 0, 0.0, 0])
        cell[1] += 1
        if r['score'] is None:
            cell[3] += 1
            continue
        cell[0] += r['score'] > PASS_LINE
        cell[2] += r['score']
    for cell in cells.values():
        scored = cell[1] - cell[3]
        cell[2] = round(cell[2] / scored, 4) if scored else None
    scores = {f"{r['look']}/{r['mode']}/{r['id']}": r['score'] for r in rows if r['score'] is not None}
    below = sorted(((r['score'], r) for r in rows if r['score'] is not None and r['score'] <= PASS_LINE), key=lambda x: x[0])
    drops = []
    for key, score in scores.items():
        before = (previous_scores or {}).get(key)
        if before is not None and before - score >= DROP:
            drops.append({'key': key, 'before': before, 'after': score})
    drops.sort(key=lambda d: d['before'] - d['after'], reverse=True)
    return {'cells': cells, 'cases': len(rows), 'unscored': sum(1 for r in rows if r['score'] is None),
            'below': [{'score': s, 'level': r['level'], 'look': r['look'], 'mode': r['mode'], 'id': r['id']} for s, r in below[:20]],
            'belowCount': len(below), 'drops': drops[:15], 'dropCount': len(drops), 'scores': scores,
            'previousCompared': previous_scores is not None}


def render(visual, add):
    """Chinese markdown lines (the nightly summary language) for the section body."""
    if not visual:
        add('- 未运行')
        return
    if visual.get('error'):
        add(f"- {visual['error']}")
        return
    add(f"- {visual['cases']} 个用例（L1 框架 + 关键 L2 页面，手机/桌面，浅色），96% 线以下 {visual['belowCount']} 个，无分数 {visual['unscored']} 个")
    add('- 单元格 = 过线数/总数（平均分）；Raft 对照 Web v1.21.23，Elegant/Brutal 对照 a57b9dab 冻结原图')
    add('')
    add('| 层级 | 主题 | 过线/总数 | 平均分 | 无分数 |')
    add('| --- | --- | --- | --- | --- |')
    for key, (ok, total, mean, none) in sorted(visual['cells'].items()):
        level, look = key.split('|')
        add(f"| {level} | {look} | {ok}/{total} | {'' if mean is None else f'{mean * 100:.1f}%'} | {none} |")
    if visual.get('previousCompared'):
        add('')
        add(f"- 与上一晚相比下降 ≥1 个百分点：**{visual['dropCount']} 个**")
        for d in visual['drops']:
            add(f"  - `{d['key']}` {d['before'] * 100:.1f}% → {d['after'] * 100:.1f}%")
    else:
        add('- 没有上一晚的分数可比（今晚是基准）')
    add('- 最低的用例：')
    for b in visual['below'][:10]:
        add(f"  - {b['score'] * 100:.1f}% `{b['look']}/{b['mode']}` {b['level']} `{b['id']}`")
