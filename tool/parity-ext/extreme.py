"""Extreme-theme check: find what the Raft look paints without reading the theme pack.

  tool/parity-ext/run extreme [--level frame|page|component|all] [--mode light|dark|all] [--cases GLOB[,GLOB]]
                              [--out DIR] [--shards N] [--no-official] [--no-ext] [--looks LIST]
                              [--plan-only] [--analyze-only] [--report-only] [--limit N] [--top N]

Docs: docs/parity-ext-quickstart.md "Extreme-theme check"; contract: docs/theme-contract.md section 8.

Per case it renders the Flutter widget tree four times with the paint-op recorder on (apps/raft_flutter/test/support/
paint_ops.dart; the parity harness override `<look>-case`):

  raft      the normal Raft pack
  extreme   the test-only user pack tool/parity-ext/extreme_pack.py generates (`extends: raft`, every colour role, geometry
            token, type slot and font moved; shadows off), loaded by the real pack parser (`extreme-case`)
  elegant   the normal Elegant pack  } classification evidence (tool/parity-ext/extreme_diff.py: a / b / c); Brutal is
  brutal    the normal Brutal pack   } light only, it has no dark look of its own

then tool/parity-ext/extreme_diff.py compares raft with extreme (unchanged pixel regions mapped to the painting widget;
paint ops that kept their colour / radius / stroke / font size) and this module ranks the result by widget and file.
No Web capture is involved. The cases are the Raft look of the regression plan (tool/parity-ext/regress.py): the official
ids (light) and the extension ids (light and dark), frame / page / component levels. Output (default build/parity-extreme):

  <out>/<mode>-<engine>/<look>/visual-testing-results/android/<case>.{png,ops.json}   renders
  <out>/analysis/<case>.json                                                          per-case findings
  <out>/report/extreme-theme-report.{md,json}, <out>/report/shots/                    the report (keep it out of the repo)

Not part of the gate. Run it under `taskset -c ... nice -n 15` on a shared machine; every step resumes (existing renders
and analyses are kept; --force-render / --force-analysis redo them).
"""
import argparse
import collections
import concurrent.futures
import datetime as dt
import fnmatch
import json
import multiprocessing
import os
import pathlib
import re
import subprocess
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tool'))
import builders  # noqa: E402
import extreme_diff as ed  # noqa: E402
import levels  # noqa: E402
import regress  # noqa: E402

LOOK_OVERRIDE = {'raft': 'raft-case', 'extreme': 'extreme-case', 'elegant': 'elegant-case', 'brutal': 'brutal-case'}
DEFAULT_LOOKS = ('raft', 'extreme', 'elegant', 'brutal')
BATCH = 250


def add_arguments(p):
    p.add_argument('--level', choices=[*levels.LEVELS, 'all'], default='all')
    p.add_argument('--mode', choices=[*regress.MODES, 'all'], default='all')
    p.add_argument('--cases', help='only ids matching these globs (comma list)')
    p.add_argument('--out', default=os.environ.get('PARITY_EXTREME_OUT', str(ROOT / 'build/parity-extreme')))
    p.add_argument('--shards', type=int, default=int(os.environ.get('PARITY_SHARDS', '2')), help='parallel flutter test processes')
    p.add_argument('--looks', default=','.join(DEFAULT_LOOKS), help='renders to make (raft and extreme are required for the diff)')
    p.add_argument('--no-official', action='store_true')
    p.add_argument('--no-ext', action='store_true')
    p.add_argument('--limit', type=int, help='first N planned cases per job (smoke runs)')
    p.add_argument('--plan-only', action='store_true')
    p.add_argument('--analyze-only', action='store_true', help='skip the renders')
    p.add_argument('--report-only', action='store_true', help='rebuild the report from <out>/analysis')
    p.add_argument('--force-render', action='store_true')
    p.add_argument('--force-analysis', action='store_true')
    p.add_argument('--jobs', type=int, default=int(os.environ.get('PARITY_EXTREME_JOBS', '4')), help='analysis processes')
    p.add_argument('--top', type=int, default=25, help='entries in the short list')
    p.add_argument('--shots', type=int, default=24, help='side-by-sides of the worst cases')


# ------------------------------------------------------------------------------------------------ planning
def make_plan(a):
    ns = argparse.Namespace(level=a.level, theme='raft', mode=a.mode, fast=False, out=str(pathlib.Path(a.out) / '_plan'),
                            cases=a.cases, shards=a.shards, no_official=a.no_official, no_ext=a.no_ext,
                            plan_only=True, summary_only=False, also=[])
    jobs = regress.plan(ns)
    if a.limit:
        for j in jobs:
            j['ext'], j['official'] = j['ext'][:a.limit], j['official'][:a.limit]
    return jobs


def looks_for(job, a):
    out = [l for l in a.looks.split(',') if l]
    if job['mode'] == 'dark':
        out = [l for l in out if l != 'brutal']  # Brutal has no dark look (contract 2.1): its dark is Elegant dark
    return out


def job_dir(a, job, engine, look):
    return pathlib.Path(a.out) / f"{job['mode']}-{engine}" / look


def android_dir(a, job, engine, look):
    return job_dir(a, job, engine, look) / 'visual-testing-results/android'


# ------------------------------------------------------------------------------------------------ rendering
_PARITY = None


def shared_dir():
    """The Web source's visual-testing shared dir (fixtures and the official case list): tool/parity's SHARED
    ($PARITY_RAFT_SOURCE)."""
    global _PARITY
    if _PARITY is None:
        import importlib.machinery
        import importlib.util
        loader = importlib.machinery.SourceFileLoader('parity_extreme_adapter', str(ROOT / 'tool/parity'))
        _PARITY = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
        loader.exec_module(_PARITY)
    return _PARITY.SHARED


def render_env(a, job, engine, look, ids_file, manifest):
    env = {k: v for k, v in os.environ.items() if k != 'PARITY_THEME_OVERRIDE'}
    env.update({
        'TZ': 'Asia/Shanghai',
        'PARITY_SHARED_DIR': str(shared_dir()),
        'PARITY_RESULT_ROOT': str(job_dir(a, job, engine, look) / 'visual-testing-results'),
        'PARITY_THEME_OVERRIDE': LOOK_OVERRIDE[look],
        'PARITY_PAINT_OPS': '1',
        'PARITY_CASES_FILE': str(ids_file),
        'PARITY_SHARD_INDEX': '0',
        'PARITY_SHARD_TOTAL': '1',
        'PARITY_RUN_INFO': json.dumps({'flutterCommit': 'extreme-check'}),
        'PARITY_EXTREME_PACK': str(ROOT / 'apps/raft_flutter/test/parity/fixtures/extreme.theme.json'),
    })
    env.pop('PARITY_CASES', None)
    if engine == 'ext':
        env['PARITY_MANIFEST'] = str(manifest)
        env['PARITY_EXT_FIXTURES'] = str(HERE / 'fixtures')
    else:
        env.pop('PARITY_MANIFEST', None)
    return env


def run_batches(a, job, engine, look, ids, manifest):
    """Render [ids] in the look with `a.shards` parallel flutter test processes, BATCH cases per process run."""
    android = android_dir(a, job, engine, look)
    android.mkdir(parents=True, exist_ok=True)
    if not a.force_render:
        ids = [i for i in ids if not ((android / f'{i}.png').is_file() and (android / f'{i}.ops.json').is_file())]
    if not ids:
        return 0
    work = job_dir(a, job, engine, look) / '_work'
    work.mkdir(parents=True, exist_ok=True)
    lanes = [ids[i::a.shards] for i in range(a.shards)]
    logs = job_dir(a, job, engine, look) / 'flutter-logs'
    logs.mkdir(exist_ok=True)

    def lane(index):
        done = 0
        todo = lanes[index]
        for n in range(0, len(todo), BATCH):
            chunk = todo[n:n + BATCH]
            ids_file = work / f'ids-{index}-{n // BATCH}.txt'
            ids_file.write_text('\n'.join(chunk) + '\n')
            env = render_env(a, job, engine, look, ids_file, manifest)
            with open(logs / f'lane{index}-{n // BATCH}.log', 'w') as sink:
                try:
                    subprocess.run([str(ROOT / 'tool/flutter'), 'test', 'test/parity/parity_capture_test.dart', '--no-pub',
                                    '--track-widget-creation', '--reporter', 'expanded'],
                                   cwd=ROOT / 'apps/raft_flutter', env=env, stdout=sink, stderr=subprocess.STDOUT, timeout=3 * 3600)
                except subprocess.TimeoutExpired:
                    sink.write('\nTIMEOUT\n')
            done += len(chunk)
        return done

    with concurrent.futures.ThreadPoolExecutor(a.shards) as pool:
        total = sum(pool.map(lane, range(a.shards)))
    return total


def render_all(a, jobs, manifest):
    for job in jobs:
        for engine in ('official', 'ext'):
            ids = job[engine]
            if not ids:
                continue
            for look in looks_for(job, a):
                t = time.time()
                print(f"[extreme] render {job['mode']}/{engine}/{look}: {len(ids)} case(s)", flush=True)
                run_batches(a, job, engine, look, ids, manifest)
                have = sum((android_dir(a, job, engine, look) / f'{i}.ops.json').is_file() for i in ids)
                print(f'[extreme]   {have}/{len(ids)} rendered in {time.time() - t:.0f}s', flush=True)


# ------------------------------------------------------------------------------------------------ analysis
def analyse_case(task):
    cid, paths, root, force, out = task
    target = pathlib.Path(out) / 'analysis' / f'{cid}.json'
    if target.is_file() and not force:
        return cid, None
    try:
        normal = ed.Ops.load(paths['raft'] / f'{cid}.ops.json', root)
        extreme = ed.Ops.load(paths['extreme'] / f'{cid}.ops.json', root)
        result = ed.analyse_regions(paths['raft'] / f'{cid}.png', paths['extreme'] / f'{cid}.png', extreme, normal)
        findings = ed.paint_findings(normal, extreme, paths['extreme'] / f'{cid}.png', extreme.density)
        tables = {}
        for look in ('elegant', 'brutal'):
            f = paths.get(look)
            if f is not None and (f / f'{cid}.ops.json').is_file():
                tables[look] = ed.look_values(ed.Ops.load(f / f'{cid}.ops.json', root))
        for r in result['regions']:
            r['class'], r['evidence'] = ed.classify(ed.region_as_finding(r), tables)
        for f in findings:
            f['class'], f['evidence'] = ed.classify(f, tables)
        doc = {'case': cid, 'unchangedFraction': result['unchangedFraction'], 'regions': result['regions'],
               'ignored': result['ignored'], 'unattributed': result['unattributed'], 'findings': findings,
               'unsupportedLayers': extreme.doc.get('unsupportedLayers', {}),
               'paintError': extreme.doc.get('error') or normal.doc.get('error'),
               'looksCompared': sorted(tables),
               'recipes': recipe_records(cid, paths, root)}
    except Exception as error:  # noqa: BLE001 - one broken case must not stop the run
        doc = {'case': cid, 'error': f'{type(error).__name__}: {error}'}
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(doc))
    return cid, doc


def analyse_all(a, jobs):
    tasks = []
    missing = []
    for job in jobs:
        for engine in ('official', 'ext'):
            for cid in job[engine]:
                paths = {look: android_dir(a, job, engine, look) for look in DEFAULT_LOOKS}
                if (paths['raft'] / f'{cid}.ops.json').is_file() and (paths['extreme'] / f'{cid}.ops.json').is_file():
                    tasks.append((cid, paths, str(ROOT), a.force_analysis, a.out))
                else:
                    missing.append({'case': cid, 'mode': job['mode'],
                                    'missing': [l for l in ('raft', 'extreme') if not (paths[l] / f'{cid}.ops.json').is_file()]})
    print(f'[extreme] analyse {len(tasks)} case(s) with {a.jobs} process(es)', flush=True)
    with multiprocessing.Pool(a.jobs) as pool:
        for n, _ in enumerate(pool.imap_unordered(analyse_case, tasks, chunksize=4), 1):
            if n % 200 == 0:
                print(f'[extreme]   {n}/{len(tasks)}', flush=True)
    return missing


# ------------------------------------------------------------------------------------------------ recipe contexts
RECIPE_PROPS = ('background-color', 'color', 'border-top-color', 'border-top-width', 'border-top-left-radius',
                'box-shadow', 'font-size', 'padding-top', 'height')


def repo_frame(frame):
    """'Class.method.<closure> (package:raft_ui/src/x.dart:136:34)' -> ('Class.method', 'packages/raft_ui/lib/src/x.dart', 136)."""
    m = re.match(r'(.*?)\s*\(package:([^/]+)/(.*?\.dart):(\d+)(?::\d+)?\)', frame)
    if not m:
        return frame, None, None
    name, pkg, rest, line = m.groups()
    base = 'apps/raft_flutter/lib/' if pkg == 'raft_flutter' else f'packages/{pkg}/lib/'
    return name.replace('.<anonymous closure>', ''), base + rest, int(line)


def theme_expression(file, line):
    """The text of the `theme:` argument of the recipe call that starts at file:line (a few lines are searched)."""
    try:
        lines = (ROOT / file).read_text().splitlines()[line - 1:line + 14]
    except OSError:
        return None
    text = ' '.join(l.strip() for l in lines)
    m = re.search(r'\btheme:\s*', text)
    if not m:
        return None
    depth, out = 0, ''
    for ch in text[m.end():]:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            if depth == 0:
                break
            depth -= 1
        elif ch == ',' and depth == 0:
            break
        out += ch
    return out.strip()


def recipe_records(cid, paths, root):
    """The resolution context of every RaftRecipeBox of one case, paired across the looks.

    -> [{recipe, args (without theme), caller, callerFile, callerLine, themeExpr, site, states, ordinal, looks:
         {look: {theme, radiusControl, props, tokenProps, literalProps, classes}}}] for boxes traced in the Raft render."""
    looks = {}
    for look in DEFAULT_LOOKS:
        f = paths.get(look)
        if f is None or not (f / f'{cid}.ops.json').is_file():
            continue
        doc = json.loads((f / f'{cid}.ops.json').read_text())
        used = {o['node'] for o in doc['objects'] if o.get('node') is not None}
        parent = {n[0]: n[4] for n in doc['nodes']}
        painted = set()
        for node in used:
            while node is not None and node not in painted:
                painted.add(node)
                node = parent.get(node)
        boxes = [n for n in doc['nodes'] if len(n) > 5 and n[5].get('traced') and n[0] in painted]
        grouped = collections.defaultdict(list)
        for n in boxes:
            x = n[5]
            args = {k: v for k, v in x['args'].items() if k != 'theme'}
            key = (x['recipe'], json.dumps(args, sort_keys=True), (x['callers'] or [''])[0], tuple(x['states']), n[2], n[3])
            grouped[key].append((n, x))
        looks[look] = grouped
    out = []
    for key, items in looks.get('raft', {}).items():
        for ordinal, (n, x) in enumerate(items):
            name, file, line = repo_frame(key[2])
            rec = {'recipe': x['recipe'], 'args': json.loads(key[1]), 'caller': name, 'callerFile': file, 'callerLine': line,
                   'states': list(key[3]), 'site': f"{ed.Ops({'nodes': []}, root).rel(n[2])}:{n[3]}", 'ordinal': ordinal, 'looks': {}}
            for look, grouped in looks.items():
                peers = grouped.get(key, [])
                if ordinal < len(peers):
                    px = peers[ordinal][1]
                    rec['looks'][look] = {'theme': px['args'].get('theme'), 'radiusControl': px.get('radiusControl'),
                                          'props': px['props'], 'tokenProps': px['tokenProps'], 'literalProps': px['literalProps']}
            out.append(rec)
    return out


def write_recipe_samples(a, dest, cases, limit=6):
    """A few complete RaftRecipeBox resolution contexts, rendered as markdown (the settings page first)."""
    root = str(ROOT)
    L = ['# RaftRecipeBox resolution samples', '',
         'Each sample is one `RaftRecipeBox` painted in the Raft look, with what produced its `RaftSlotStyle`: the recipe class, the axis '
         'arguments passed (variant, size, theme), the states, the caller frame and the source text of its `theme:` argument, and the '
         'resolved value of the box properties in every look. A property printed `token(x)` reads the theme tokens (so a pack moves it); '
         'anything else is a literal baked into the generated recipe (so a pack cannot move it). `radius.control` is the pack value '
         '`raftRecipeTheme(t)` reads to choose the recipe theme.', '']
    taken = 0
    for cid in cases:
        paths = {look: android_dir_any(a, cid, look) for look in DEFAULT_LOOKS}
        if any(v is None for v in paths.values()):
            continue
        seen = set()
        for rec in recipe_records(cid, paths, root):
            key = (rec['recipe'], json.dumps(rec['args'], sort_keys=True), rec['callerLine'])
            if key in seen:
                continue
            seen.add(key)
            raft = rec['looks'].get('raft')
            ext = rec['looks'].get('extreme')
            if not raft or not ext:
                continue
            stuck = [p for p in RECIPE_PROPS if p in raft['props'] and raft['props'].get(p) == ext['props'].get(p)
                     and 'token(' not in raft['props'][p]]
            if not stuck:
                continue
            taken += 1
            L += [f"## Sample {taken}: `{rec['recipe']}` {json.dumps(rec['args'])} in `{cid}`", '',
                  f"- RaftRecipeBox created at `{rec['site']}`",
                  f"- recipe call: `{rec['recipe']}.resolve(...)` from `{rec['caller']}` at `{rec['callerFile']}:{rec['callerLine']}`",
                  f"- `theme:` argument in that source: `{theme_expression(rec['callerFile'], rec['callerLine']) if rec['callerFile'] else None}`",
                  f"- states: {rec['states'] or 'none'}", '',
                  '| | ' + ' | '.join(rec['looks']) + ' |', '| --- | ' + ' | '.join('---' for _ in rec['looks']) + ' |',
                  '| recipe `theme` axis value | ' + ' | '.join(str(v['theme']) for v in rec['looks'].values()) + ' |',
                  '| pack `radius.control` read by `raftRecipeTheme(t)` | ' + ' | '.join(str(v['radiusControl']) for v in rec['looks'].values()) + ' |',
                  '| properties reading tokens / literal | ' + ' | '.join(f"{v['tokenProps']} / {v['literalProps']}" for v in rec['looks'].values()) + ' |']
            for p in RECIPE_PROPS:
                if all(p in v['props'] for v in rec['looks'].values()):
                    L.append(f'| `{p}` | ' + ' | '.join(f"{v['props'][p]}" for v in rec['looks'].values()) + ' |')
            L += ['', f"Values the extreme pack could not move (literal and identical in Raft and extreme): {', '.join(f'`{p}`' for p in stuck)}.", '']
            if taken >= limit:
                break
        if taken >= limit:
            break
    pathlib.Path(dest).write_text('\n'.join(L) + '\n')
    return taken


def android_dir_any(a, cid, look):
    for mode in ('light', 'dark'):
        for engine in ('official', 'ext'):
            d = pathlib.Path(a.out) / f'{mode}-{engine}' / look / 'visual-testing-results/android'
            if (d / f'{cid}.ops.json').is_file():
                return d
    return None


# ------------------------------------------------------------------------------------------------ report
def class_index():
    """repo-relative file -> [(line, class name)] sorted, over the project's own lib directories."""
    index = {}
    pattern = re.compile(r'^(?:abstract |final |base |sealed |mixin )*(?:class|mixin|extension type) (\w+)\b', re.M)
    for lib in [*(ROOT / 'packages').glob('*/lib'), ROOT / 'apps/raft_flutter/lib']:
        for path in lib.rglob('*.dart'):
            if path.name.endswith('.g.dart'):
                continue
            text = path.read_text(errors='replace')
            found = [(text.count('\n', 0, m.start()) + 1, m.group(1)) for m in pattern.finditer(text)]
            if found:
                index[str(path.relative_to(ROOT))] = found
    return index


def component_of(site, classes):
    """The class whose code wrote the painting widget: the last class declared at or above the creation line."""
    owner = None
    for line, name in classes.get(site['file'], []):
        if line <= site['line']:
            owner = (name, site['file'], line)
    return owner or (site['type'], site['file'], site['line'])


def surface_of(cid):
    parts = cid.split('.')
    return '.'.join(parts[:3]) if len(parts) > 3 else cid


def collect(a):
    classes = class_index()
    entries = {}
    cases = {}
    for path in sorted((pathlib.Path(a.out) / 'analysis').glob('*.json')):
        doc = json.loads(path.read_text())
        cid = doc['case']
        if 'error' in doc:
            cases[cid] = {'error': doc['error']}
            continue
        items = [('region', r) for r in doc['regions']] + [('paint', f) for f in doc['findings']]
        cases[cid] = {'regions': len(doc['regions']), 'findings': len(doc['findings']), 'ignored': doc['ignored'],
                      'unattributed': len(doc['unattributed']), 'unchangedFraction': doc['unchangedFraction'],
                      'regionArea': round(sum(r['area'] for r in doc['regions']), 1),
                      'paintError': doc.get('paintError'), 'unsupportedLayers': doc.get('unsupportedLayers')}
        for source, item in items:
            site = item['site']
            comp, comp_file, comp_line = component_of(site, classes)
            key = (comp, comp_file)
            e = entries.setdefault(key, {
                'component': comp, 'definedAt': f'{comp_file}:{comp_line}', 'siteFile': site['file'],
                'cases': set(), 'regions': 0, 'findings': 0, 'attrs': collections.Counter(), 'classes': collections.Counter(),
                'sites': collections.Counter(), 'values': collections.defaultdict(collections.Counter),
                'surfaces': collections.Counter(), 'evidence': {}, 'chains': collections.Counter(), 'cases_by_mode': collections.Counter()})
            e['cases'].add(cid)
            e['surfaces'][surface_of(cid)] += 1
            if source == 'region':
                e['regions'] += 1
                attr = f"region:{item['op']}"
            else:
                e['findings'] += 1
                attr = item['attr']
            e['attrs'][attr] += 1
            e['classes'][item['class']] += 1
            e['sites'][f"{site['type']}@{site['file']}:{site['line']}"] += 1
            e['values'][attr][item['value'] if source == 'paint' else item.get('color') or item['pixel']] += 1
            e['chains'][' > '.join(c['type'] for c in item.get('chain', [])[:6])] += 1
            if item['class'] in ('a', 'b') and item['class'] not in e['evidence']:
                e['evidence'][item['class']] = {'case': cid, 'attr': attr, 'value': item['value'] if source == 'paint' else item.get('color'),
                                                'looks': item['evidence']}
    return entries, cases


def entry_class(e):
    if e['classes']['a']:
        return 'a'
    if e['classes']['b']:
        return 'b'
    return 'c'


CLASS_NAME = {'a': 'a likely defect', 'b': 'b possible shared form', 'c': 'c unknown'}


def finalize(entries):
    rows = []
    for e in entries.values():
        cls = entry_class(e)
        rows.append({
            'class': cls, 'component': e['component'], 'definedAt': e['definedAt'], 'siteFile': e['siteFile'],
            'cases': len(e['cases']), 'regions': e['regions'], 'findings': e['findings'],
            'attrs': dict(e['attrs'].most_common()), 'classes': dict(e['classes']),
            'sites': dict(e['sites'].most_common(5)),
            'values': {k: dict(v.most_common(4)) for k, v in e['values'].items()},
            'surfaces': dict(e['surfaces'].most_common(4)), 'evidence': e['evidence'],
            'chains': dict(e['chains'].most_common(2)), 'exampleCases': sorted(e['cases'])[:4],
        })
    rows.sort(key=lambda r: ('abc'.index(r['class']), -r['cases'], -(r['regions'] + r['findings']), r['component']))
    return rows


def short_attrs(attrs):
    return ', '.join(f'{k} x{v}' for k, v in list(attrs.items())[:4])


def short_values(values):
    out = []
    for attr, counter in list(values.items())[:3]:
        out.append(f"{attr}={'|'.join(list(counter)[:3])}")
    return '; '.join(out)


def site_hint(row):
    out = []
    for key in list(row['sites'])[:3]:
        type_, _, rest = key.partition('@')
        out.append(f"{type_}:{rest.rsplit(':', 1)[-1]}")
    return ', '.join(out)


def where_hint(row):
    return ', '.join(f"{k.replace('components.', '')} ({v})" for k, v in list(row['surfaces'].items())[:3])


def callout(rows, types, title):
    hit = [r for r in rows if any(t in ' '.join(r['chains']) or t in r['component'] for t in types)]
    lines = [f'### {title}', '']
    if not hit:
        lines.append('No unchanged region or unchanged paint op reached through these widgets in the cases rendered.')
        return lines
    lines += ['| class | widget | defined at | painting widgets (file:line) | kinds | values | cases |', '| --- | --- | --- | --- | --- | --- | --- |']
    for r in hit[:12]:
        lines.append(f"| {r['class']} | `{r['component']}` | {r['definedAt']} | {site_hint(r)} | {short_attrs(r['attrs'])} | "
                     f"{short_values(r['values'])} | {r['cases']} |")
    return lines


def settings_findings(a):
    """Type findings (font size / family / text colour) of the settings page cases, by case."""
    by_text = collections.defaultdict(lambda: collections.Counter())
    n_cases = 0
    for path in (pathlib.Path(a.out) / 'analysis').glob('*settings*.json'):
        doc = json.loads(path.read_text())
        if 'error' in doc:
            continue
        n_cases += 1
        for f in doc['findings']:
            if f['attr'] in ('fontSize', 'fontFamily', 'textColor'):
                by_text[(f['site']['type'], f['site']['file'], f['site']['line'])][f"{f['attr']}={f['value']}"] += 1
    return n_cases, by_text


def build_report(a, missing, plan_counts):
    entries, cases = collect(a)
    rows = finalize(entries)
    ok = {c: v for c, v in cases.items() if 'error' not in v}
    with_regions = [c for c, v in ok.items() if v['regions']]
    with_any = [c for c, v in ok.items() if v['regions'] or v['findings']]
    classes = collections.Counter()
    for e in entries.values():
        classes.update(e['classes'])
    total_regions = sum(v['regions'] for v in ok.values())
    total_findings = sum(v['findings'] for v in ok.values())
    ignored = collections.Counter()
    for v in ok.values():
        ignored.update(v['ignored'])
    summary = {
        'generatedAt': dt.datetime.now(dt.timezone.utc).isoformat(), 'commit': subprocess.run(
            ['git', 'rev-parse', '--short', 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.strip(),
        'plannedCases': plan_counts, 'casesAnalysed': len(ok), 'casesWithUnthemedRegions': len(with_regions),
        'casesWithAnyFinding': len(with_any), 'unthemedRegions': total_regions, 'paintFindings': total_findings,
        'casesNotRendered': len(missing), 'analysisErrors': len(cases) - len(ok), 'ignoredRegions': dict(ignored),
        'unattributedRegions': sum(v['unattributed'] for v in ok.values()),
        'findingClasses': dict(classes), 'entries': len(rows),
        'casesWithUnsupportedLayers': sum(1 for v in ok.values() if v.get('unsupportedLayers')),
    }
    out = pathlib.Path(a.out) / 'report'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'extreme-theme-report.json').write_text(json.dumps({
        'summary': summary, 'entries': rows, 'cases': cases, 'notRendered': missing}, indent=1))
    recipe_groups = collections.OrderedDict()
    for path in sorted((pathlib.Path(a.out) / 'analysis').glob('*.json')):
        doc = json.loads(path.read_text())
        for rec in doc.get('recipes', []):
            key = (rec['recipe'], json.dumps(rec['args'], sort_keys=True), rec['callerFile'], rec['callerLine'])
            g = recipe_groups.setdefault(key, {
                'recipe': rec['recipe'], 'args': rec['args'], 'caller': rec['caller'], 'callerFile': rec['callerFile'],
                'callerLine': rec['callerLine'], 'cases': set(), 'boxes': 0, 'theme': collections.defaultdict(collections.Counter),
                'radiusControl': collections.defaultdict(collections.Counter), 'stuck': collections.Counter(),
                'values': {}, 'themeExpr': None, 'sites': collections.Counter()})
            g['cases'].add(doc['case'])
            g['boxes'] += 1
            g['sites'][rec['site']] += 1
            for look, v in rec['looks'].items():
                g['theme'][look][v['theme']] += 1
                g['radiusControl'][look][v['radiusControl']] += 1
            raft, ext = rec['looks'].get('raft'), rec['looks'].get('extreme')
            if raft and ext:
                for p_ in RECIPE_PROPS:
                    if p_ in raft['props'] and raft['props'][p_] == ext['props'].get(p_) and 'token(' not in raft['props'][p_]:
                        g['stuck'][p_] += 1
                        g['values'].setdefault(p_, {look: v['props'].get(p_) for look, v in rec['looks'].items()})
    for g in recipe_groups.values():
        if g['callerFile']:
            g['themeExpr'] = theme_expression(g['callerFile'], g['callerLine'])
    recipe_rows = sorted(recipe_groups.values(), key=lambda g: (-len(g['stuck']) * 0 - len(g['cases']), g['recipe']))
    (out / 'recipebox-contexts.json').write_text(json.dumps([
        {**g, 'cases': len(g['cases']), 'theme': {k: dict(v) for k, v in g['theme'].items()},
         'radiusControl': {k: {str(a_): b_ for a_, b_ in v.items()} for k, v in g['radiusControl'].items()},
         'stuck': dict(g['stuck']), 'sites': dict(g['sites'].most_common(3))} for g in recipe_rows], indent=1))
    L = ['# Extreme-theme check: what the Raft look paints without reading the theme pack', '',
         f"Generated {summary['generatedAt'][:16]}Z from raft-flutter {summary['commit']}. Docs/theme-contract.md section 8.", '',
         'Method: every case is rendered in the normal Raft pack and in a test-only user pack (`extends: raft`) that moves every '
         'colour role, geometry token, type slot and font and removes shadows. A pixel region that is identical in both renders, or '
         'a paint op whose colour / corner radius / stroke / font size did not move, did not read the pack. Both are mapped to the '
         'widget that painted them (creation `file:line`, widget class and the file that declares it). Text glyph interiors and '
         'images are ignored; test-harness chrome is counted apart. An unchanged value is only a candidate: contract 3.3 allows a '
         'literal that Raft, Elegant and Brutal share, so each entry is classed against the normal Elegant and Brutal renders of '
         'the same cases.', '',
         '- class a, likely defect: the same widget at the same creation site paints a different value in Elegant or Brutal while the '
         'extreme pack could not move it (a look-specific literal, an Elegant-era recipe constant)',
         '- class b, possible shared form: every look that renders it paints the same value; check slot, variant and state before tokenizing',
         '- class c, unknown: the widget paints no such op in the other looks', '',
         '## Counts', '',
         '| | |', '| --- | --- |',
         f"| cases planned (Raft look, frame + page + component) | {plan_counts['total']} (light {plan_counts['light']}, dark {plan_counts['dark']}) |",
         f"| cases rendered and compared | {summary['casesAnalysed']} |",
         f"| cases not rendered (capture failed in Raft or extreme) | {summary['casesNotRendered']} |",
         f"| cases with unthemed regions (pixel level) | {summary['casesWithUnthemedRegions']} |",
         f"| cases with any finding (regions or unchanged paint ops) | {summary['casesWithAnyFinding']} |",
         f"| unthemed regions, total | {summary['unthemedRegions']} |",
         f"| unchanged paint-op findings, total | {summary['paintFindings']} |",
         f"| regions ignored: text / image / vector / harness | {ignored['text']} / {ignored['image']} / {ignored['vector']} / {ignored['harness']} |",
         f"| regions without an explaining paint op | {summary['unattributedRegions']} |",
         f"| findings by class (a / b / c) | {classes['a']} / {classes['b']} / {classes['c']} |",
         f"| widget / file entries | {len(rows)} ({sum(r['class'] == 'a' for r in rows)} a, {sum(r['class'] == 'b' for r in rows)} b, "
         f"{sum(r['class'] == 'c' for r in rows)} c) |", '']
    L += [f'## Fix list: top {a.top}, class a first, then by cases', '',
          '| # | class | widget | declared at | painting widgets (file:line) | kinds | values | cases | seen in |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    for i, r in enumerate(rows[:a.top], 1):
        L.append(f"| {i} | {r['class']} | `{r['component']}` | {r['definedAt']} | {site_hint(r)} | {short_attrs(r['attrs'])} | "
                 f"{short_values(r['values'])} | {r['cases']} | {where_hint(r)} |")
    L += [''] + callout(rows, ['RaftThreadOverflowAction', 'RaftPanelIconButton'], 'The thread panel header overflow button (⋮)')
    n_set, set_text = settings_findings(a)
    L += ['', f'### Settings pages typography ({n_set} settings cases)', '']
    if set_text:
        L += ['| text widget (creation site) | unchanged type values (count) |', '| --- | --- |']
        for site, c in sorted(set_text.items(), key=lambda kv: -sum(kv[1].values()))[:15]:
            L.append(f"| `{site[0]}@{site[1]}:{site[2]}` | {', '.join(f'{k} x{v}' for k, v in c.most_common(4))} |")
    else:
        L.append('No settings case reported an unchanged font size, family or text colour.')
    if not recipe_rows:
        L += ['', '## RaftRecipeBox resolution contexts', '',
              'No recipe context in this run: the renders carry none (`apps/raft_flutter/test/support/recipe_context.dart` reports no context '
              'until `RaftSlotStyle.context` exists). The paint-site findings above still name the widget and `file:line` of each RaftRecipeBox.']
    else:
        L += ['', '## RaftRecipeBox resolution contexts', '',
            'Every `RaftRecipeBox` painted in the Raft look, grouped by recipe class, axis arguments (without `theme`) and the caller frame that resolved it. '
            '`theme` is the recipe theme axis each look resolved (Raft and a user pack resolve `elegant` whenever the pack `radius.control` is above 0, see '
            '`raftRecipeTheme`); "literal, unmoved" lists box properties that are not `token(...)` in the recipe and stayed identical under the extreme pack '
            '(raft value shown; per-look values in recipebox-contexts.json).', '',
            '| recipe | args | resolved at | `theme:` source | theme raft / extreme / elegant / brutal | literal, unmoved | cases | boxes |',
            '| --- | --- | --- | --- | --- | --- | --- | --- |']
        for g in recipe_rows[:60]:
            themes = ' / '.join(','.join(sorted(map(str, g['theme'][look]))) or '-' for look in DEFAULT_LOOKS)
            stuck = ', '.join(f"{p_}={g['values'][p_].get('raft')}" for p_ in g['stuck'])
            L.append(f"| {g['recipe']} | {json.dumps(g['args'])} | {g['callerFile']}:{g['callerLine']} | `{g['themeExpr']}` | {themes} | {stuck[:240]} | {len(g['cases'])} | {g['boxes']} |")
    L += ['', '## All entries', '', '| # | class | widget | declared at | painting widgets (file:line) | kinds | cases | regions | paint ops | classes a/b/c |',
          '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    for i, r in enumerate(rows, 1):
        L.append(f"| {i} | {r['class']} | `{r['component']}` | {r['definedAt']} | {site_hint(r)} | {short_attrs(r['attrs'])} | {r['cases']} | "
                 f"{r['regions']} | {r['findings']} | {r['classes'].get('a', 0)}/{r['classes'].get('b', 0)}/{r['classes'].get('c', 0)} |")
    if missing:
        L += ['', f'## Cases not rendered ({len(missing)})', '', '| case | mode | missing render |', '| --- | --- | --- |']
        L += [f"| `{m['case']}` | {m['mode']} | {', '.join(m['missing'])} |" for m in missing[:400]]
    worst = sorted(((v['regionArea'], c) for c, v in ok.items() if v['regions']), reverse=True)[:a.shots]
    if worst:
        L += ['', '## Worst cases (left: Raft, middle: extreme pack, right: extreme with the unchanged regions boxed)', '']
        L += [f'- `{c}`: {ok[c]["regions"]} region(s), {ok[c]["regionArea"]:g} logical px2, shots/{c}.png' for _, c in worst]
    (out / 'extreme-theme-report.md').write_text('\n'.join(L) + '\n')
    return summary, rows, worst


def make_shots(a, jobs, worst):
    from PIL import Image, ImageDraw
    out = pathlib.Path(a.out) / 'report/shots'
    out.mkdir(parents=True, exist_ok=True)
    where = {}
    for job in jobs:
        for engine in ('official', 'ext'):
            for cid in job[engine]:
                where[cid] = (job, engine)
    for _, cid in worst:
        job, engine = where[cid]
        d = android_dir(a, job, engine, 'raft'), android_dir(a, job, engine, 'extreme')
        doc = json.loads((pathlib.Path(a.out) / 'analysis' / f'{cid}.json').read_text())
        n, e = Image.open(d[0] / f'{cid}.png').convert('RGB'), Image.open(d[1] / f'{cid}.png').convert('RGB')
        density = json.loads((d[1] / f'{cid}.ops.json').read_text()).get('density') or 1
        boxed = e.copy()
        draw = ImageDraw.Draw(boxed)
        for r in doc['regions']:
            x0, y0, x1, y1 = (v * density for v in r['bbox'])
            draw.rectangle([x0, y0, x1, y1], outline=(255, 0, 0), width=max(2, int(density * 2)))
        sheet = Image.new('RGB', (n.width * 3 + 20, n.height), (128, 128, 128))
        for i, img in enumerate((n, e, boxed)):
            sheet.paste(img, (i * (n.width + 10), 0))
        scale = min(1.0, 2400 / sheet.width, 2400 / sheet.height)
        if scale < 1:
            sheet = sheet.resize((int(sheet.width * scale), int(sheet.height * scale)), Image.LANCZOS)
        sheet.save(out / f'{cid}.png', optimize=True)


# ------------------------------------------------------------------------------------------------ command
def command(a):
    pathlib.Path(a.out).mkdir(parents=True, exist_ok=True)
    jobs = make_plan(a)
    plan_counts = {'light': 0, 'dark': 0, 'total': 0}
    for j in jobs:
        n = len(j['ext']) + len(j['official'])
        plan_counts[j['mode']] += n
        plan_counts['total'] += n
        print(f"[extreme] plan {j['mode']}: official {len(j['official'])}, ext {len(j['ext'])}; looks {','.join(looks_for(j, a))}")
    if a.plan_only:
        return
    manifest = pathlib.Path(a.out) / '_plan/_manifest/cases.json'
    if not manifest.is_file():
        builders.build_manifest(manifest.parent)
    missing = []
    if not a.report_only:
        if not a.analyze_only:
            render_all(a, jobs, manifest)
        missing = analyse_all(a, jobs)
        (pathlib.Path(a.out) / 'missing.json').write_text(json.dumps(missing))
    else:
        mf = pathlib.Path(a.out) / 'missing.json'
        missing = json.loads(mf.read_text()) if mf.is_file() else []
    summary, rows, worst = build_report(a, missing, plan_counts)
    make_shots(a, jobs, worst)
    print(json.dumps(summary, indent=1))
    print(f"[extreme] report: {pathlib.Path(a.out) / 'report/extreme-theme-report.md'}")
