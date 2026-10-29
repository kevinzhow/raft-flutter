"""One regression command over the three visual levels and the three looks (owner scope 2026-10-24).

  tool/parity-ext/run regress [--level frame|page|component|all] [--theme raft|elegant|brutal|all]
                              [--mode light|dark|all] [--fast] [--out DIR] [--cases GLOB[,GLOB]]
                              [--plan-only] [--summary-only]

Levels (tool/parity-ext/levels.py): frame (L1 app frame), page (L2 whole pages), component (L3 official component
cases + extension dialogs / menus / rows). Looks and what each is compared against:

  raft      Flutter rendered in the Raft look vs the pinned Web v1.21.23 render (React; the unmodified official
            pipeline for official ids, the extension pipeline for the rest)
  elegant   Flutter rendered in the Elegant look vs its frozen a57b9dab original (tool/parity-ext/frozen_ref.py)
  brutal    same for Brutal (light only; Brutal had no dark mode)

Every job is one pipeline run (`tool/parity` for the official ids, `tool/parity-ext/run run` for the extension ids)
written to <out>/<look>-<mode>/{official,ext}/; the command then writes <out>/regress-summary.{md,json}: one table
level x (look, mode) with pass/total at the tool's 96% line and the mean score, the cases without a reference, and
the full below-96 list. `--fast` is the nightly subset: the L1 frame cases and the key L2 pages (levels.FAST_PAGES),
phone and desktop widths, light mode.
"""
import argparse
import datetime as dt
import fnmatch
import json
import os
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tool'))
import builders  # noqa: E402
import frozen_ref  # noqa: E402
import levels  # noqa: E402
import sampling  # noqa: E402

PASS_LINE = 0.96
LOOKS = ('raft', 'elegant', 'brutal')
MODES = ('light', 'dark')
# The extension case name that renders each (look, mode). On the Web every light name renders the one Raft page and
# `elegant-dark` renders dark, so the Raft look reads one light and one dark name per case.
EXT_THEME = {
    'raft': {'light': 'brutal-light', 'dark': 'elegant-dark'},
    'elegant': {'light': 'elegant-light', 'dark': 'elegant-dark'},
    'brutal': {'light': 'brutal-light'},
}
OFFICIAL_THEME = {'elegant': {'light': 'elegant-light', 'dark': 'elegant-dark'}, 'brutal': {'light': 'brutal-light'}}
FAST_WIDTHS = (390, 1280)


def add_arguments(p):
    p.add_argument('--level', choices=[*levels.LEVELS, 'all'], default='all')
    p.add_argument('--theme', choices=[*LOOKS, 'all'], default='all', help='look (the Raft look is compared with the Web)')
    p.add_argument('--mode', choices=[*MODES, 'all'], default='all')
    p.add_argument('--fast', action='store_true',
                   help='nightly subset: L1 frame + key L2 pages (levels.FAST_PAGES), phone + desktop widths, light')
    p.add_argument('--out', default=os.environ.get('PARITY_REGRESS_OUT', str(ROOT / 'build/parity-regress')))
    p.add_argument('--cases', help='only ids matching these globs (comma list)')
    p.add_argument('--shards', type=int, default=int(os.environ.get('PARITY_SHARDS', '4')))
    p.add_argument('--no-official', action='store_true', help='skip the official ids (tool/parity)')
    p.add_argument('--no-ext', action='store_true', help='skip the extension ids')
    p.add_argument('--plan-only', action='store_true', help='print the plan (case counts per job), run nothing')
    p.add_argument('--summary-only', action='store_true', help='only rebuild the summary from the job directories in --out')
    p.add_argument('--also', action='append', default=[], metavar='DIR',
                   help='another --out directory whose job results join the summary (a later --also wins for a repeated case)')


# ------------------------------------------------------------------------------------------------ planning
def manifests(out):
    """-> (full manifest cases, sampled manifest cases) of the extension builders."""
    build = pathlib.Path(out) / '_manifest'
    build.mkdir(parents=True, exist_ok=True)
    builders.build_manifest(build)
    full = json.loads((build / 'cases.json').read_text())
    sampled = sampling.sample_themes(json.loads((build / 'cases.json').read_text()), env={})
    return full['cases'], sampled['cases']


def official_cases():
    import importlib.machinery
    import importlib.util
    loader = importlib.machinery.SourceFileLoader('parity_official_adapter', str(ROOT / 'tool/parity'))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod.manifest_cases()


def wanted(case, want_levels, a):
    cid = case['id']
    if levels.level_of(cid) not in want_levels:
        return False
    if a.cases and not any(fnmatch.fnmatchcase(cid, g) for g in a.cases.split(',')):
        return False
    if a.fast:
        width = (case.get('viewport') or {}).get('width')
        if width not in FAST_WIDTHS:
            return False
        lvl = levels.level_of(cid)
        if lvl == levels.COMPONENT:
            return False
        if lvl == levels.PAGE and not levels.is_fast_page(cid):
            return False
    return True


def plan(a):
    want_levels = set(levels.LEVELS if a.level == 'all' else [a.level])
    looks = LOOKS if a.theme == 'all' else (a.theme,)
    modes = MODES if a.mode == 'all' else (a.mode,)
    if a.fast:
        modes = ('light',)
    ext_full, ext_sampled = manifests(a.out)
    sampled_ids = {c['id'] for c in ext_sampled}
    official = official_cases()
    jobs = []
    for look in looks:
        for mode in modes:
            theme = EXT_THEME[look].get(mode)
            if theme is None:
                continue
            # Mounted framework cases declare their actual Raft identity,
            # while older builders still use the historical storage names.
            ext_themes = {theme, f'raft-{mode}'} if look == 'raft' else {theme}
            ext_ids = [c['id'] for c in ext_full if c['theme'] in ext_themes and wanted(c, want_levels, a)
                       # dark / non-Raft dark runs keep the surface sampling for L3 (docs/parity.md "Theme sampling")
                       and (mode == 'light' or levels.level_of(c['id']) != levels.COMPONENT or c['id'] in sampled_ids)]
            off_ids = [c['id'] for c in official if wanted(c, want_levels, a)] if mode == 'light' or look != 'raft' else []
            if look == 'raft' and mode == 'dark':
                off_ids = []  # no official case declares a dark variant
            if look != 'raft' and mode not in OFFICIAL_THEME[look]:
                off_ids = []
            jobs.append({'look': look, 'mode': mode, 'ext': [] if a.no_ext else ext_ids,
                         'official': [] if a.no_official else off_ids, 'dir': f'{look}-{mode}'})
    return jobs


# ------------------------------------------------------------------------------------------------ running
def run_job(job, a):
    out = pathlib.Path(a.out) / job['dir']
    env_base = {k: v for k, v in os.environ.items() if k != 'PARITY_THEME_OVERRIDE'}
    look, mode = job['look'], job['mode']
    failed = False
    for engine in ('official', 'ext'):
        ids = job[engine]
        if not ids:
            continue
        env = dict(env_base)
        cmd = [sys.executable, str(ROOT / ('tool/parity' if engine == 'official' else 'tool/parity-ext/run')), 'run',
               '--cases', ','.join(ids), '--shards', str(a.shards)]
        workdir = out / engine
        env['PARITY_OUT' if engine == 'official' else 'PARITY_EXT_OUT'] = str(workdir)
        if engine == 'ext':
            # the sampled manifest keeps 1-2 cases per surface for the non-default themes; the regression wants all
            env['PARITY_EXT_ALL_THEMES'] = '1'
            if not a.cases:
                cmd += ['--allow-structural-gaps']
        if look == 'raft':
            if engine == 'ext':
                env['PARITY_THEME_OVERRIDE'] = 'raft-case'  # official ids are the Raft look without an override
        else:
            if engine == 'official':
                theme = OFFICIAL_THEME[look][mode]
                env['PARITY_THEME_OVERRIDE'] = theme
                cmd += ['--frozen', theme]
            else:
                cmd += ['--frozen']  # extension ids name their look; the Flutter side needs no override
        print(f'[regress] {look}/{mode} {engine}: {len(ids)} case(s)', flush=True)
        log = pathlib.Path(a.out) / f'{job["dir"]}-{engine}.log'
        with open(log, 'w') as sink:
            r = subprocess.run(['nice', '-n', '15', *cmd], cwd=ROOT, env=env, stdout=sink, stderr=subprocess.STDOUT)
        print(f'[regress] {look}/{mode} {engine}: exit {r.returncode}, log {log}', flush=True)
        failed = failed or r.returncode != 0
    return int(failed)


# ------------------------------------------------------------------------------------------------ summary
def load_rows(a, ext_cases):
    width = {c['id']: (c.get('viewport') or {}).get('width') for c in ext_cases}
    selection = getattr(a, 'cases', None)
    rows = []
    roots = [pathlib.Path(a.out), *map(pathlib.Path, a.also)]
    jobdirs = [p for root in roots for p in sorted(root.iterdir()) if p.is_dir() and not p.name.startswith('_')]
    reasons = {}
    for jobdir in jobdirs:
        for engine in ('official', 'ext'):
            if (jobdir / engine).is_dir():
                reasons.update({(jobdir.name, engine, k): v for k, v in failure_reasons(jobdir / engine).items()})
    for jobdir in jobdirs:
        look, _, mode = jobdir.name.partition('-')
        if look not in LOOKS or mode not in MODES:
            continue
        for engine in ('official', 'ext'):
            f = jobdir / engine / 'summary.json'
            if not f.is_file():
                continue
            wanted_suffix = {'brutal-light': '.brutal', 'elegant-light': '.elegant', 'elegant-dark': '.elegant-dark'}[EXT_THEME[look][mode]]
            for r in json.loads(f.read_text())['cases']:
                cid = r['id']
                if selection and not any(fnmatch.fnmatchcase(cid, pattern) for pattern in selection.split(',')):
                    continue
                # an extension summary lists every manifest case; keep the ones this look / mode runs
                if engine == 'ext' and not cid.endswith(wanted_suffix):
                    continue
                if engine == 'ext' and wanted_suffix == '.elegant' and cid.endswith('.elegant-dark'):
                    continue
                score, why, verdict = r.get('pixelPerfectSimilarity'), reasons.get((jobdir.name, engine, cid), ''), r['verdict']
                if look == 'raft' and mode == 'dark' and score is not None and web_page_is_light(jobdir / engine, cid):
                    # the Web host of this family does not apply dark mode: the reference is a light page, so the score says nothing
                    score, verdict, why = None, 'web-not-dark', 'Web: the host rendered a light page in dark mode (no valid dark reference)'
                rows.append({
                    'id': cid, 'look': look, 'mode': mode, 'engine': engine, 'level': levels.level_of(cid),
                    'width': width.get(cid) or 390, 'verdict': verdict,
                    'score': score, 'nonText': r.get('nonTextSimilarity'), 'why': why})
    latest = {}
    for r in rows:  # a case reported by two directories keeps the later one
        latest[(r['look'], r['mode'], r['id'])] = r
    return list(latest.values())


def failure_reasons(jobdir):
    """case id -> why it has no score, read from the job's React capture log and Flutter shard logs."""
    import re
    reasons = {}
    log = jobdir / 'react-capture.log'
    if log.is_file():
        for block in re.split(r'\n\s+\d+\) ', log.read_text(errors='replace'))[1:]:
            m = re.match(r'.*react visual provider (\S+)', block.splitlines()[0])
            if not m:
                continue
            err = re.search(r'\n\s+(Error:[^\n]*|Test timeout[^\n]*)', block)
            loc = re.search(r'Locator: ([^\n]*)|waiting for ([^\n]*)', block)
            text = (err.group(1) if err else 'React capture failed')[:100]
            if loc:
                text += ' | ' + (loc.group(1) or loc.group(2))[:100]
            reasons[m.group(1)] = 'Web: ' + text
    for shard in sorted((jobdir / 'flutter-logs').glob('shard*.log')) if (jobdir / 'flutter-logs').is_dir() else []:
        text = shard.read_text(errors='replace')
        for m in re.finditer(r'Bad state: ([^\n]*)|(?:Exception|Error): ([^\n]*)', text):
            tail = text[m.end():m.end() + 2500]
            d = re.search(r'The test description was:\s+parity (\S+)', tail)
            if d:
                reasons.setdefault(d.group(1), 'Flutter: ' + (m.group(1) or m.group(2))[:130])
    return reasons


def web_page_is_light(jobdir, case_id):
    """True when the Web capture of a dark-mode case is a light page (mean luminance above 200 of 255)."""
    png = pathlib.Path(jobdir) / 'visual-testing-results/react' / f'{case_id}.png'
    if not png.is_file():
        return False
    from PIL import Image
    with Image.open(png) as image:
        small = image.convert('L').resize((48, 48))
        return sum(small.getdata()) / (48 * 48) > 200


def cell(rows):
    n = len(rows)
    if not n:
        return '-'
    scored = [r for r in rows if r['score'] is not None]
    passing = sum(1 for r in scored if r['score'] > PASS_LINE)
    nofix = n - len(scored)
    mean = sum(r['score'] for r in scored) / len(scored) if scored else 0
    return f'{passing}/{n} ({mean * 100:.1f}%)' + (f', {nofix} no capture/ref' if nofix else '')


def summarize(a, ext_cases):
    rows = load_rows(a, ext_cases)
    keys = sorted({(r['look'], r['mode']) for r in rows}, key=lambda k: (LOOKS.index(k[0]), MODES.index(k[1])))
    lines = [f'# Visual regression: levels x looks ({dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%MZ")})', '',
             'Cell = cases above the 96% line / cases in the cell (mean exact score of the captured pairs). '
             'raft = vs Web v1.21.23; elegant / brutal = vs the frozen a57b9dab render.', '',
             '| level | ' + ' | '.join(f'{l} {m}' for l, m in keys) + ' |', '| --- | ' + ' | '.join('---' for _ in keys) + ' |']
    for lvl in levels.LEVELS:
        lines.append(f'| {lvl} | ' + ' | '.join(cell([r for r in rows if r['level'] == lvl and (r['look'], r['mode']) == k])
                                                 for k in keys) + ' |')
    lines += ['', 'By width (phone 390 / other):', '', '| level | width | ' + ' | '.join(f'{l} {m}' for l, m in keys) + ' |',
              '| --- | --- | ' + ' | '.join('---' for _ in keys) + ' |']
    for lvl in levels.LEVELS:
        for w in sorted({r['width'] for r in rows if r['level'] == lvl}):
            lines.append(f'| {lvl} | {w} | ' + ' | '.join(
                cell([r for r in rows if r['level'] == lvl and r['width'] == w and (r['look'], r['mode']) == k]) for k in keys) + ' |')
    below = sorted((r for r in rows if r['score'] is not None and r['score'] <= PASS_LINE), key=lambda r: r['score'])
    lines += ['', f'## Below the 96% line ({len(below)})', '', '| score | level | look | mode | width | case |', '| --- | --- | --- | --- | --- | --- |']
    lines += [f"| {r['score'] * 100:.1f}% | {r['level']} | {r['look']} | {r['mode']} | {r['width']} | `{r['id']}` |" for r in below]
    missing = [r for r in rows if r['score'] is None]
    lines += ['', f'## No capture or no reference ({len(missing)})', '', '| verdict | level | look | mode | case | why |', '| --- | --- | --- | --- | --- | --- |']
    lines += [f"| {r['verdict']} | {r['level']} | {r['look']} | {r['mode']} | `{r['id']}` | {r.get('why', '')} |" for r in missing]
    root = pathlib.Path(a.out)
    (root / 'regress-summary.json').write_text(json.dumps({'rows': rows}, indent=1))
    (root / 'regress-summary.md').write_text('\n'.join(lines) + '\n')
    print(f'[regress] summary: {root / "regress-summary.md"} ({len(rows)} rows, {len(below)} below 96%, {len(missing)} without score)')
    return rows


def command(a):
    pathlib.Path(a.out).mkdir(parents=True, exist_ok=True)
    jobs = plan(a)
    for j in jobs:
        print(f"[regress] plan {j['look']}/{j['mode']}: official {len(j['official'])}, ext {len(j['ext'])}")
    if a.plan_only:
        return
    failed = False
    if not a.summary_only:
        for j in jobs:
            code = run_job(j, a)
            failed = failed or code != 0
    ext_full, _ = manifests(a.out)
    rows = summarize(a, ext_full)
    missing = sum(row['score'] is None for row in rows)
    structural = {'react-missing', 'not-covered', 'web-not-dark'}
    blocking = sum(row['score'] is None and (bool(getattr(a, 'cases', None)) or row.get('verdict') not in structural)
                   for row in rows)
    if failed or blocking or not rows or all(row['score'] is None for row in rows):
        print(f'[regress] FAILED: incomplete captures or failed jobs; {missing} case(s) without a score', file=sys.stderr)
        sys.exit(1)
