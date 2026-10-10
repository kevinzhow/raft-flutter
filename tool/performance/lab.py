#!/usr/bin/env python3
"""Raft perf lab: run the fixed profile-mode scenario suite, summarise every
frame against the 8.33 ms (120 Hz) target and the 16.7 ms (60 Hz) gate, and
compare two runs.

  python3 tool/performance/lab.py run --out .local/performance/lab/<name>
  python3 tool/performance/lab.py summarize <run-dir>
  python3 tool/performance/lab.py compare <base-dir> <candidate-dir>

See docs/performance-lab.md.
"""
import argparse
import datetime
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'apps/raft_flutter'
TARGET = 'integration_test/perf_lab_test.dart'
DRIVER = 'test_driver/perf_lab_driver.dart'
BUDGET_120 = 1e6 / 120  # 8333 us
BUDGET_60 = 1e6 / 60    # 16667 us
SCENARIO_ORDER = ['steady-scroll', 'fling', 'image-scroll', 'older-drag', 'arrival-scrolled-up', 'resize',
                  'open-cold', 'open-warm', 'channel-switch', 'thread-open']
ROW_KINDS = ['plain', 'markdown', 'code', 'image', 'attachments', 'reactions', 'thread-summary', 'task']


# ---------------------------------------------------------------- statistics

def pct(values, q):
    """Nearest-rank percentile; 0 for an empty list."""
    if not values:
        return 0
    s = sorted(values)
    return s[max(0, min(len(s) - 1, math.ceil(q * len(s)) - 1))]


def dist(values):
    return {'p50': pct(values, .5), 'p90': pct(values, .9), 'p99': pct(values, .99), 'max': max(values) if values else 0,
            'mean': sum(values) / len(values) if values else 0}


def ms(us):
    return round(us / 1000, 2)


def frames_in(record, t0, t1):
    return [f for f in record.get('frames', []) if t0 <= f['b'] < t1]


def stutters(record):
    """Frames that arrived more than 1.5 vsync periods after the previous one
    during a continuously animated scenario (dropped / doubled frame)."""
    if record.get('kind') not in ('continuous',):
        return 0
    rate = record.get('displayRefreshRate') or 60
    period = 1e6 / rate
    v = [f['v'] for f in record.get('frames', [])]
    return sum(1 for a, b in zip(v, v[1:]) if b - a > 1.5 * period)


def summarize_record(record, attribution=None):
    frames = record.get('frames', [])
    for f in frames:
        # UI thread time per frame: engine build span plus the semantics,
        # finalize-tree and post-frame work that runs after scene submission.
        f.setdefault('uit', f['ui'])
    ui = [f['uit'] for f in frames]
    raster = [f['r'] for f in frames]
    n = len(frames)
    over = lambda xs, b: sum(1 for x in xs if x > b)
    either8 = sum(1 for f in frames if f['uit'] > BUDGET_120 or f['r'] > BUDGET_120)
    phases = {}
    for f in frames:
        for k, v in (f.get('ph') or {}).items():
            phases[k] = phases.get(k, 0) + v
    ui_total = sum(ui) or 1
    row = {
        'theme': record['theme'], 'scenario': record['scenario'], 'kind': record.get('kind'),
        'frames': n, 'elapsedSeconds': record.get('elapsedSeconds'),
        'displayRefreshRate': record.get('displayRefreshRate'),
        'view': f"{record.get('viewWidth', 0):.0f}x{record.get('viewHeight', 0):.0f}",
        'uiUs': dist(ui), 'uiBuildUs': dist([f['ui'] for f in frames]), 'rasterUs': dist(raster),
        'over8Ui': over(ui, BUDGET_120), 'over8Raster': over(raster, BUDGET_120), 'over8Either': either8,
        'over8EitherPct': round(100 * either8 / n, 1) if n else 0,
        'over16Ui': over(ui, BUDGET_60), 'over16Raster': over(raster, BUDGET_60),
        'stutters': stutters(record),
        'phaseShare': {k: round(100 * v / ui_total, 1) for k, v in sorted(phases.items(), key=lambda kv: -kv[1])},
        'semanticsShare': round(100 * phases.get('semantics', 0) / ui_total, 1),
        'semanticsEnabled': record.get('semanticsEnabled'),
        'cpuSeconds': record.get('cpuSeconds'),
        'rssDeltaMb': round(((record.get('rssAfter') or 0) - (record.get('rssBefore') or 0)) / 2**20, 1),
        'clockMatched': record.get('clockMatched'),
        'failure': record.get('failure'),
    }
    row['gate60'] = n > 0 and row['over16Ui'] == 0 and row['over16Raster'] == 0 and row['stutters'] == 0 and not row['failure']
    worst = sorted(frames, key=lambda f: -f['uit'])[:3]
    row['worstUiFrames'] = [{'uiMs': ms(f['uit']), 'buildMs': ms(f['ui']), 'rasterMs': ms(f['r']), 'phasesMs': {k: ms(v) for k, v in sorted((f.get('ph') or {}).items(), key=lambda kv: -kv[1])[:4]}} for f in worst]
    blocks = record.get('blockTotalsUs') or {}
    row['topBlocksMs'] = {k: ms(v) for k, v in sorted(blocks.items(), key=lambda kv: -kv[1])[:10]}
    for key in ('movedPx', 'anchorDriftPx', 'anchorLostFrames', 'olderPagesServed', 'rowsBefore', 'rowsAfter', 'imageReads', 'arrivals', 'resizeSteps'):
        if key in record:
            row[key] = record[key]
    if 'opens' in record:
        opens = []
        for o in record['opens']:
            fs = frames_in(record, o['t0'], o['t1'])
            opens.append({'channel': o['channel'], 'visibleMs': round(o['visibleMs'], 1),
                          'worstUiMs': ms(max((f['uit'] for f in fs), default=0)),
                          'worstRasterMs': ms(max((f['r'] for f in fs), default=0)),
                          'uiSumMs': ms(sum(f['uit'] for f in fs)), 'frames': len(fs)})
        row['opens'] = opens
        vis = [o['visibleMs'] for o in opens if o['visibleMs'] >= 0]
        row['visibleMs'] = {'p50': pct(vis, .5), 'max': max(vis) if vis else -1}
    if 'steps' in record:
        per_row, mount_ui, follow, rows = [], [], [], []
        for s in record['steps']:
            fs = frames_in(record, s['t0'], s['t1'])
            if not fs:
                continue
            mount_ui.append(fs[0]['uit'])
            follow.append(sum(f['uit'] for f in fs[1:]))
            rows.append(s['newRows'])
            if s['newRows'] > 0:
                per_row.append(fs[0]['uit'] / s['newRows'])
        row['mount'] = {'rowKind': record.get('rowKind'), 'steps': len(mount_ui), 'rowsMounted': sum(rows),
                        'perRowUs': dist(per_row), 'mountFrameUs': dist(mount_ui), 'followUpUs': dist(follow),
                        'coldFirstStepUs': mount_ui[0] if mount_ui else 0}
    if attribution:
        worst_cpu = attribution.get('cpuWorstUiFrames') or {}
        total = worst_cpu.get('samples') or 0
        row['gcCount'] = attribution.get('gcCount')
        gc = attribution.get('gcEvents') or {}
        row['gcTimeMs'] = ms(sum(v.get('totalUs', 0) for v in gc.values()))
        row['gcInWorstUiFrames'] = len(attribution.get('gcInWorstUiFrames') or [])
        row['worstUiAttribution'] = {
            'samples': total,
            'categories': {k: round(100 * v / total, 1) for k, v in sorted((worst_cpu.get('categories') or {}).items(), key=lambda kv: -kv[1])} if total else {},
            'app': [{'name': e['name'], 'pct': round(100 * e['value'] / total, 1)} for e in (worst_cpu.get('appInclusive') or [])[:8]] if total else [],
            'all': [{'name': e['name'], 'pct': round(100 * e['value'] / total, 1)} for e in (worst_cpu.get('inclusive') or [])[:25]] if total else [],
            'self': [{'name': e['name'], 'pct': round(100 * e['value'] / total, 1)} for e in (worst_cpu.get('self') or [])[:8]] if total else [],
        }
        raster = (attribution.get('rasterWorstFrames') or {}).get('inclusiveUs') or []
        row['worstRasterAttribution'] = [{'name': e['name'], 'ms': ms(e['value'])} for e in raster[:8]]
    return row


def load_run(run):
    run = Path(run)
    records = []
    for path in sorted(run.glob('*.json')):
        if path.name.endswith('.attribution.json') or path.name.startswith(('lab-', 'env', 'summary', 'compare', 'driver-')):
            continue
        data = json.loads(path.read_text())
        if isinstance(data, dict) and 'scenario' in data and 'frames' in data:
            att = run / f"{data['theme']}-{data['scenario']}.attribution.json"
            records.append((data, json.loads(att.read_text()) if att.is_file() else None))
    return records


def order_key(row):
    s = row['scenario']
    if s.startswith('mount-'):
        k = s[6:]
        return (1, ROW_KINDS.index(k) if k in ROW_KINDS else 99, row['theme'])
    return (0, SCENARIO_ORDER.index(s) if s in SCENARIO_ORDER else 99, row['theme'])


def summarize(run):
    run = Path(run)
    rows = sorted((summarize_record(r, a) for r, a in load_run(run)), key=order_key)
    env = json.loads((run / 'env.json').read_text()) if (run / 'env.json').is_file() else {}
    names = ' '.join(e['name'] for _, a in load_run(run) if a for e in (a.get('rasterWorstFrames') or {}).get('inclusiveUs', []))
    backend = next((label for key, label in (('GLES', 'Impeller (OpenGLES)'), ('Vulkan', 'Impeller (Vulkan)'), ('VK', 'Impeller (Vulkan)'), ('Metal', 'Impeller (Metal)'), ('MTL', 'Impeller (Metal)')) if key in names), None)
    if backend or names:
        env['renderer'] = backend or 'Skia (no Impeller raster events)'
    hello = json.loads((run / 'lab-hello.json').read_text()) if (run / 'lab-hello.json').is_file() else {}
    notes = [json.loads(l) for l in (run / 'lab-notes.jsonl').read_text().splitlines()] if (run / 'lab-notes.jsonl').is_file() else []
    summary = {'format': 'raft-perf-lab-v1', 'run': run.name, 'env': env, 'hello': hello, 'notes': notes, 'scenarios': rows,
               'gate60Passed': bool(rows) and all(r['gate60'] for r in rows)}
    (run / 'summary.json').write_text(json.dumps(summary, indent=1, ensure_ascii=False) + '\n')
    (run / 'summary.md').write_text(markdown(summary))
    return summary


def fmt_dist(d):
    return f"{ms(d['p50'])} / {ms(d['p90'])} / {ms(d['p99'])} / {ms(d['max'])}"


def markdown(summary):
    env, hello = summary.get('env', {}), summary.get('hello', {})
    out = [f"# Perf lab run `{summary['run']}`", '']
    out.append(f"- Commit: `{env.get('commit', '?')}`{' (dirty)' if env.get('dirty') else ''}; fixture `{hello.get('fixtureVersion', '?')}`")
    out.append(f"- Engine: Flutter {env.get('flutter', {}).get('frameworkVersion', '?')} (engine `{str(env.get('flutter', {}).get('engineRevision', '?'))[:10]}`), renderer: {env.get('renderer', '?')}")
    out.append(f"- Host: {env.get('os', '?')}; CPU: {env.get('cpu', '?')}; GPU: {env.get('gpu', '?')}")
    load = lambda key: ', '.join(f'{v:.1f}' for v in env.get(key) or []) or '?'
    out.append(f"- Host load (1/5/15 min) at start: {load('loadavg')}; at end: {load('loadavgEnd')}" + (' — **NOISY HOST: other work was running; do not use these numbers as a baseline**' if env.get('noisyHost') else ''))
    first = summary['scenarios'][0] if summary['scenarios'] else {}
    out.append(f"- Display: {hello.get('displayRefreshRate', '?')} Hz, DPR {hello.get('devicePixelRatio', '?')}, view {first.get('view', '?')} physical px; semantics mode `{hello.get('semantics', '?')}` (embedder requested: {hello.get('platformSemanticsEnabled', '?')}); phase collection {'on' if hello.get('phases') else 'off'}")
    out.append(f"- Gate (60 Hz: no UI or raster frame over 16.7 ms, no stutter): **{'PASS' if summary['gate60Passed'] else 'FAIL'}**. Target: every frame within 8.33 ms (120 Hz).")
    out += ['', '## Frames (ms: p50 / p90 / p99 / max)', '',
            '| Scenario | Theme | Frames | UI thread (build+layout+paint+semantics) | Raster | >8.33 ms (UI/R, either %) | >16.7 ms (UI/R) | Stutter | GC | Semantics % | Gate 60 |',
            '|---|---|---|---|---|---|---|---|---|---|---|']
    for r in summary['scenarios']:
        out.append(f"| {r['scenario']} | {r['theme']} | {r['frames']} | {fmt_dist(r['uiUs'])} | {fmt_dist(r['rasterUs'])} | {r['over8Ui']}/{r['over8Raster']} ({r['over8EitherPct']}%) | {r['over16Ui']}/{r['over16Raster']} | {r['stutters']} | {r.get('gcCount', '-')} | {r['semanticsShare']} | {'pass' if r['gate60'] else 'FAIL'} |")
    mounts = [r for r in summary['scenarios'] if 'mount' in r]
    if mounts:
        out += ['', '## New-row mount cost (UI µs of the frame that mounts rows, divided by rows mounted)', '',
                '| Row kind | Theme | Rows | Per row p50 / p90 / max | Mount frame p50 / max (ms) | Follow-up frames p50 (ms) | First (cold) step (ms) |', '|---|---|---|---|---|---|---|']
        for r in mounts:
            m = r['mount']
            out.append(f"| {m['rowKind']} | {r['theme']} | {m['rowsMounted']} | {round(m['perRowUs']['p50'])} / {round(m['perRowUs']['p90'])} / {round(m['perRowUs']['max'])} | {ms(m['mountFrameUs']['p50'])} / {ms(m['mountFrameUs']['max'])} | {ms(m['followUpUs']['p50'])} | {ms(m['coldFirstStepUs'])} |")
    trans = [r for r in summary['scenarios'] if 'opens' in r]
    if trans:
        out += ['', '## Transitions', '', '| Scenario | Theme | Opens | Visible ms (p50 / max) | Worst UI frame per open (ms) |', '|---|---|---|---|---|']
        for r in trans:
            out.append(f"| {r['scenario']} | {r['theme']} | {len(r['opens'])} | {r['visibleMs']['p50']} / {r['visibleMs']['max']} | {', '.join(str(o['worstUiMs']) for o in r['opens'])} |")
    out += ['', '## Worst-frame attribution', '']
    for r in summary['scenarios']:
        att = r.get('worstUiAttribution') or {}
        phases = ', '.join(f"{k} {v}%" for k, v in list(r['phaseShare'].items())[:5])
        out.append(f"- **{r['scenario']} / {r['theme']}**: worst UI {', '.join(str(f['uiMs']) for f in r['worstUiFrames'])} ms; phase share {phases or 'n/a'}")
        if att.get('categories'):
            out.append('  - worst-frame CPU by category (inclusive %): ' + ', '.join(f"{k} {v}%" for k, v in att['categories'].items()))
        if att.get('app'):
            out.append('  - app code (inclusive % of worst-frame samples): ' + '; '.join(f"{e['name']} {e['pct']}%" for e in att['app'][:5]))
        if att.get('self'):
            out.append('  - hottest leaf functions: ' + '; '.join(f"{e['name']} {e['pct']}%" for e in att['self'][:4]))
        if r.get('worstRasterAttribution'):
            out.append('  - raster: ' + '; '.join(f"{e['name']} {e['ms']}ms" for e in r['worstRasterAttribution'][:4]))
        extra = {k: r[k] for k in ('movedPx', 'anchorDriftPx', 'olderPagesServed', 'imageReads', 'gcTimeMs', 'gcInWorstUiFrames') if k in r}
        if extra:
            out.append('  - ' + ', '.join(f"{k} {v}" for k, v in extra.items()))
    if summary.get('notes'):
        out += ['', '## Notes', ''] + [f"- {json.dumps(n, ensure_ascii=False)}" for n in summary['notes']]
    return '\n'.join(out) + '\n'


# ---------------------------------------------------------------- compare

COMPARED = [('uiUs', 'p90'), ('uiUs', 'p99'), ('uiUs', 'max'), ('rasterUs', 'p90'), ('rasterUs', 'p99'), ('rasterUs', 'max')]


def compare(base, cand, threshold=0.10, floor_us=500):
    b = {(r['theme'], r['scenario']): r for r in base['scenarios']}
    c = {(r['theme'], r['scenario']): r for r in cand['scenarios']}
    problems, rows = [], []
    if base.get('hello', {}).get('fixtureVersion') != cand.get('hello', {}).get('fixtureVersion'):
        problems.append('fixture versions differ; numbers are not comparable')
    views = lambda s: sorted({r.get('view') for r in s['scenarios']})
    if views(base) != views(cand):
        problems.append(f'view sizes differ: {views(base)} vs {views(cand)} (layout cost scales with width)')
    for name, run in (('base', base), ('candidate', cand)):
        if run.get('env', {}).get('noisyHost'):
            problems.append(f'{name} run was taken on a noisy host (load above limit)')
    for key in ('cpu', 'gpu', 'renderer', 'os'):
        if base.get('env', {}).get(key) != cand.get('env', {}).get(key):
            problems.append(f'environment differs: {key}')
    if base.get('env', {}).get('flutter', {}).get('engineRevision') != cand.get('env', {}).get('flutter', {}).get('engineRevision'):
        problems.append('environment differs: Flutter engine')
    for key in sorted(set(b) & set(c), key=lambda k: order_key({'theme': k[0], 'scenario': k[1]})):
        x, y = b[key], c[key]
        row = {'theme': key[0], 'scenario': key[1], 'regressions': [], 'improvements': [], 'metrics': {}}
        for group, q in COMPARED:
            old, new = x[group][q], y[group][q]
            row['metrics'][f'{group}.{q}'] = (old, new)
            # Single-frame maxima are reported but too noisy to flag; frames
            # beyond the 60 Hz budget are flagged through over16 counts.
            if q == 'max':
                continue
            if new > old * (1 + threshold) and new - old > floor_us:
                row['regressions'].append(f'{group[:-2]} {q} {ms(old)}→{ms(new)} ms')
            elif new < old * (1 - threshold) and old - new > floor_us:
                row['improvements'].append(f'{group[:-2]} {q} {ms(old)}→{ms(new)} ms')
        for metric in ('over16Ui', 'over16Raster', 'stutters'):
            row['metrics'][metric] = (x[metric], y[metric])
            if y[metric] > x[metric]:
                row['regressions'].append(f'{metric} {x[metric]}→{y[metric]}')
            elif y[metric] < x[metric]:
                row['improvements'].append(f'{metric} {x[metric]}→{y[metric]}')
        row['metrics']['over8EitherPct'] = (x['over8EitherPct'], y['over8EitherPct'])
        if y['over8EitherPct'] > x['over8EitherPct'] + 2:
            row['regressions'].append(f"frames over 8.33 ms {x['over8EitherPct']}%→{y['over8EitherPct']}%")
        elif y['over8EitherPct'] < x['over8EitherPct'] - 2:
            row['improvements'].append(f"frames over 8.33 ms {x['over8EitherPct']}%→{y['over8EitherPct']}%")
        if x['gate60'] and not y['gate60']:
            row['regressions'].append('60 Hz gate pass→FAIL')
        if 'mount' in x and 'mount' in y:
            old, new = x['mount']['perRowUs']['p50'], y['mount']['perRowUs']['p50']
            row['metrics']['mount.perRow.p50'] = (old, new)
            if new > old * (1 + threshold) and new - old > 100:
                row['regressions'].append(f'per-row mount p50 {round(old)}→{round(new)} µs')
            elif new < old * (1 - threshold) and old - new > 100:
                row['improvements'].append(f'per-row mount p50 {round(old)}→{round(new)} µs')
        if 'visibleMs' in x and 'visibleMs' in y:
            row['metrics']['visibleMs.p50'] = (x['visibleMs']['p50'], y['visibleMs']['p50'])
        rows.append(row)
    missing = sorted(set(b) ^ set(c))
    return {'problems': problems, 'missing': [list(k) for k in missing], 'rows': rows,
            'regressions': sum(len(r['regressions']) for r in rows)}


def compare_markdown(result, base_name, cand_name):
    out = [f'# Perf lab compare: `{base_name}` → `{cand_name}`', '']
    for p in result['problems']:
        out.append(f'- WARNING: {p}')
    if result['missing']:
        out.append(f"- Scenarios present in only one run: {', '.join('/'.join(k) for k in result['missing'])}")
    out += ['', '| Scenario | Theme | UI p99 (ms) | Raster p99 (ms) | >8.33 % | >16.7 UI/R | Regressions | Improvements |', '|---|---|---|---|---|---|---|---|']
    for r in result['rows']:
        m = r['metrics']
        out.append(f"| {r['scenario']} | {r['theme']} | {ms(m['uiUs.p99'][0])}→{ms(m['uiUs.p99'][1])} | {ms(m['rasterUs.p99'][0])}→{ms(m['rasterUs.p99'][1])} | {m['over8EitherPct'][0]}→{m['over8EitherPct'][1]} | {m['over16Ui'][0]}/{m['over16Raster'][0]}→{m['over16Ui'][1]}/{m['over16Raster'][1]} | {'**' + '; '.join(r['regressions']) + '**' if r['regressions'] else ''} | {'; '.join(r['improvements'])} |")
    out += ['', f"Total regressions: {result['regressions']}"]
    return '\n'.join(out) + '\n'


# ---------------------------------------------------------------- run

def capture(args, **kw):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=60, **kw).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ''


def environment(device):
    env = {'os': f'{platform.system()} {platform.release()}', 'machine': platform.machine(), 'device': device,
           'commit': capture(['git', 'rev-parse', 'HEAD'], cwd=ROOT),
           'dirty': bool(capture(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT)),
           'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'loadavg': os.getloadavg()}
    try:
        env['flutter'] = json.loads(capture([str(ROOT / 'tool/flutter'), '--version', '--machine']))
    except ValueError:
        env['flutter'] = {}
    if platform.system() == 'Linux':
        model = re.search(r'model name\s*:\s*(.+)', Path('/proc/cpuinfo').read_text())
        env['cpu'] = f"{model.group(1) if model else '?'} x{os.cpu_count()}"
        gov = Path('/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor')
        env['cpuGovernor'] = gov.read_text().strip() if gov.is_file() else None
        glx = capture(['glxinfo', '-B'])
        renderer = re.search(r'OpenGL renderer string:\s*(.+)', glx)
        env['gpu'] = renderer.group(1) if renderer else '?'
        env['session'] = os.environ.get('XDG_SESSION_TYPE')
    elif platform.system() == 'Darwin':
        env['cpu'] = f"{capture(['sysctl', '-n', 'machdep.cpu.brand_string'])} x{os.cpu_count()}"
        displays = capture(['system_profiler', 'SPDisplaysDataType'])
        chip = re.search(r'Chipset Model:\s*(.+)', displays)
        env['gpu'] = chip.group(1) if chip else '?'
        env['displays'] = re.findall(r'Resolution:\s*(.+)|UI Looks like:\s*(.+)', displays)
    return env


def other_instance():
    if platform.system() != 'Linux':
        return []
    lines = capture(['ps', '-eo', 'pid,args']).splitlines()
    return [l.strip() for l in lines if 'bundle/raft_flutter' in l]


def wait_for_display(args):
    waited = 0
    while other_instance():
        if not args.wait:
            sys.exit('Another raft_flutter bundle is running on this display:\n' + '\n'.join(other_instance()) + '\nRe-run with --wait to poll.')
        time.sleep(15)
        waited += 15
        if waited > args.wait:
            sys.exit('Timed out waiting for the other raft_flutter instance to exit')


def max_load(args):
    return args.max_load if args.max_load is not None else (os.cpu_count() or 4) * 0.35


def wait_for_quiet_host(args):
    """Frame times scale with host contention (other builds/test suites on
    the same machine). Wait for the 1-minute load to drop below the limit."""
    waited = 0
    while os.getloadavg()[0] > max_load(args):
        if waited >= args.wait_quiet:
            if args.allow_noisy:
                print(f'WARNING: host load {os.getloadavg()[0]:.1f} exceeds {max_load(args):.1f}; results will be marked noisy', flush=True)
                return
            sys.exit(f'Host load {os.getloadavg()[0]:.1f} exceeds {max_load(args):.1f}; wait (--wait-quiet) or pass --allow-noisy')
        time.sleep(15)
        waited += 15


def run(args):
    out = args.out.resolve()
    if out.exists():
        sys.exit(f'{out} exists; use a new output directory so earlier runs stay unchanged')
    device = args.device or ('macos' if platform.system() == 'Darwin' else 'linux')
    if device == 'linux' and not os.environ.get('DISPLAY'):
        sys.exit('DISPLAY must name the real X11 display (see docs/performance-lab.md)')
    wait_for_display(args)
    wait_for_quiet_host(args)
    out.mkdir(parents=True)
    env = environment(device)
    (out / 'env.json').write_text(json.dumps(env, indent=1) + '\n')
    defines = {'RAFT_LAB_THEMES': args.themes, 'RAFT_LAB_SCENARIOS': args.scenarios or '', 'RAFT_LAB_SECONDS': str(args.seconds),
               'RAFT_LAB_SEMANTICS': args.semantics, 'RAFT_LAB_PHASES': str(not args.no_trace).lower()}
    child = dict(os.environ, RAFT_PERF_OUT=str(out), RAFT_LAB_ROOT=str(ROOT), **defines)
    if device == 'linux':
        child['GDK_BACKEND'] = 'x11'
    argv = [str(ROOT / 'tool/flutter'), 'drive', '--profile', f'--driver={DRIVER}', f'--target={TARGET}', '-d', device, '--no-pub',
            *[f'--dart-define={k}={v}' for k, v in defines.items()], *args.flutter_args]
    print('Running:', ' '.join(argv), flush=True)
    for attempt in range(1, 4):
        wait_for_display(args)
        with (out / 'runner.log').open('w') as log:
            status = subprocess.run(argv, cwd=APP, env=child, stdout=log, stderr=subprocess.STDOUT).returncode
        text = (out / 'runner.log').read_text(errors='replace')
        # The desktop app is single-instance: a launch racing another
        # worktree's run exits at once. Keep the failed log and retry.
        if 'Application failed to start' not in text or (out / 'lab-hello.json').exists():
            break
        (out / 'runner.log').rename(out / f'runner-failed-start-{attempt}.log')
        time.sleep(20)
    impeller = re.search(r'Using the Impeller rendering backend \(([^)]+)\)', text)
    env['renderer'] = f'Impeller ({impeller.group(1)})' if impeller else 'unknown (derived from raster events in summarize)'
    env['exitCode'] = status
    env['endedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    env['loadavgEnd'] = os.getloadavg()
    env['maxLoad'] = max_load(args)
    env['noisyHost'] = max(env['loadavg'][0], env['loadavgEnd'][0]) > env['maxLoad']
    (out / 'env.json').write_text(json.dumps(env, indent=1) + '\n')
    summary = summarize(out)
    print((out / 'summary.md').read_text())
    if args.reference:
        return compare_cmd(argparse.Namespace(base=args.reference, candidate=out, out=None, no_fail=False))
    return 0 if status == 0 else 1


def compare_cmd(args):
    base, cand = Path(args.base), Path(args.candidate)
    sb = summarize(base) if not (base / 'summary.json').is_file() else json.loads((base / 'summary.json').read_text())
    sc = summarize(cand) if not (cand / 'summary.json').is_file() else json.loads((cand / 'summary.json').read_text())
    result = compare(sb, sc)
    text = compare_markdown(result, base.name, cand.name)
    target = Path(args.out) if args.out else cand / f'compare-{base.name}.md'
    target.write_text(text)
    target.with_suffix('.json').write_text(json.dumps(result, indent=1, ensure_ascii=False) + '\n')
    print(text)
    return 1 if result['regressions'] and not args.no_fail else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    r = sub.add_parser('run', help='run the suite in profile mode')
    r.add_argument('--out', type=Path, required=True)
    r.add_argument('--themes', default='brutal-light,elegant-light', help='comma list: brutal-light, brutal-dark, elegant-light, elegant-dark')
    r.add_argument('--scenarios', help='comma list; "mount-*" selects every row kind')
    r.add_argument('--seconds', type=int, default=8, help='duration of continuous scenarios')
    r.add_argument('--semantics', choices=['platform', 'on', 'off'], default='platform',
                   help='platform: as the embedder requests (Linux GTK: always on); on: forced (VoiceOver); off: forced off (usual macOS)')
    r.add_argument('--no-trace', action='store_true', help='disable framework phase collection and engine timeline (cleanest timings, no phase/raster attribution)')
    r.add_argument('--device', help='flutter device id (default: linux or macos)')
    r.add_argument('--reference', type=Path, help='compare against this earlier run directory')
    r.add_argument('--max-load', type=float, help='1-minute load average above which the host counts as noisy (default 0.35 x CPUs)')
    r.add_argument('--wait-quiet', type=int, default=1800, help='seconds to wait for a quiet host before giving up')
    r.add_argument('--allow-noisy', action='store_true', help='run anyway on a loaded host (summary is marked noisy)')
    r.add_argument('--wait', type=int, default=0, help='seconds to wait for another raft_flutter instance to exit (Linux)')
    r.add_argument('flutter_args', nargs='*', help='extra flutter drive arguments after --, e.g. -- --no-enable-impeller')
    s = sub.add_parser('summarize', help='rebuild summary.json/summary.md for a run')
    s.add_argument('run', type=Path)
    c = sub.add_parser('compare', help='before/after comparison against the budgets')
    c.add_argument('base', type=Path)
    c.add_argument('candidate', type=Path)
    c.add_argument('--out', type=Path)
    c.add_argument('--no-fail', action='store_true')
    args = parser.parse_args(argv)
    if args.command == 'run':
        return run(args)
    if args.command == 'summarize':
        summarize(args.run)
        print((args.run / 'summary.md').read_text())
        return 0
    return compare_cmd(args)


if __name__ == '__main__':
    raise SystemExit(main())
