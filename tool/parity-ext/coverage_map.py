#!/usr/bin/env python3
"""Coverage map: every Web surface of v1.21.23 -> the visual cases that cover it (generated).

  tool/parity-ext/coverage_map.py [--scores regress-summary.json] [--base-cases FILE] [--write-json F] [--write-md F]

Input data (committed): tool/parity-ext/coverage-surfaces.json = the surfaces the v1.21.12 -> v1.21.23 redesign touched
(raft-ui 0.5.52 -> 0.7.0 token / component changes, plus a walk of packages/web routes, pages and main components), each
with its level (1 frame, 2 page, 3 component), Web source files, lines changed and platforms, and the page-inventory rows
(tool/parity-ext/inventory.py) whose case ids cover it. The case ids come from the inventory row globs and from
EXTRA below (surfaces the inventory has no row for). Nothing here is hand-scored: a surface is covered when a case with
that id exists in the manifests the builders generate (official sharedCases.json + the extension builders), and the
scores come from the regression summary (tool/parity-ext/run regress), where a case counts only when both sides were
captured.

The "before" column is the state at the start of this audit: only the official cases that ran (the 97 non-pending ids)
were compared with the Raft look; the extension cases rendered the old Brutal / Elegant looks in Flutter against the
Raft Web page, and the shell family did not run at all (its host imported a Web file v1.21.23 removed).
"""
import argparse
import fnmatch
import importlib.util
import json
import os
import pathlib
import re
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tool'))
import builders  # noqa: E402
import inventory  # noqa: E402
import levels  # noqa: E402

LEVEL_NAME = {1: 'frame', 2: 'page', 3: 'component'}
THEME_SUFFIX = re.compile(r'\.(brutal|elegant-dark|elegant)$')

# Surfaces without an inventory row, or whose frame cases the inventory does not know (glob without theme suffix).
EXTRA = {
    'Top bar: AppTopBar': {'ext': ['components.frame.desktop.topbar', 'components.frame.tablet.topbar', 'components.frame.desktop.home']},
    'Top bar right region': {'ext': ['components.frame.desktop.topbar']},
    'Left rail': {'ext': ['components.frame.desktop.rail', 'components.frame.desktop.home']},
    'Sidebar': {'ext': ['components.frame.desktop.sidebar', 'components.frame.phone.home', 'components.frame.tablet.home']},
    'Phone Home / phone titlebar': {'ext': ['components.frame.phone.home']},
    'Phone bottom tab bar': {'ext': ['components.frame.phone.tabbar', 'components.frame.phone.home']},
    'Main layout / panel layout': {'ext': ['components.frame.desktop.channel', 'components.frame.desktop.home',
                                           'components.frame.tablet.channel', 'components.frame.tablet.home']},
    'Raftbench page': {'ext': ['components.raftbench.page.*']},
    'Settings: Appearance': {'ext': ['components.ext-settings.appearance.*']},
    'Settings: Notifications': {'ext': ['components.ext-settings.notifications.*']},
    'Settings: Account': {'ext': ['components.ext-settings.account.*']},
}
# Why a surface has no case at all (nothing to capture on one side).
NO_CASE_REASON = {
    'Window chrome / desktop title-bar host contract': 'Electron / host shell only; neither a browser nor a native client draws it (inventory excl host-only).',
    'Dev previews': 'Development route, redirected away in production.',
    'Palette audit page': 'Development route (/palette-audit); token audit covers it.',
    'Dev/e2e probe': 'Test probe, not a product surface.',
    'Settings: Agent JWT settings (removed)': 'Removed in v1.21.23 (the server answers 410).',
    'Server setup: display style': 'Web onboarding step added in v1.21.23; the Flutter app has no such step yet (no Flutter surface to capture).',
    'Agent archive': 'No Web host case yet: archive dialog + archived agents section need a fixture (candidate for the next batch).',
    'Computer bulk change model dialog': 'No case yet (flag-gated bulk action; candidate for the next batch).',
    'Live agent activity bar': 'Removed from the Web in v1.21.23 (WorkingNowSummary in the top bar replaces it).',
    'Legacy v1 task panel': 'Read-only legacy data only (inventory excl obsolete).',
}


def manifests():
    with tempfile.TemporaryDirectory() as tmp:
        builders.build_manifest(pathlib.Path(tmp))
        ext = json.loads((pathlib.Path(tmp) / 'cases.json').read_text())['cases']
    source = os.environ.get('PARITY_RAFT_SOURCE')
    if not source:
        sys.exit('set PARITY_RAFT_SOURCE to the pinned raft-source checkout')
    official = json.loads(pathlib.Path(source).joinpath('packages/visual-testing/shared/sharedCases.json').read_text())['cases']
    return ext, official


def strip(case_id):
    return THEME_SUFFIX.sub('', case_id)


def width_label(w):
    return 'phone' if w <= 480 else ('tablet' if w < 1000 else 'desktop')


def matches(glob_list, ids):
    pos = [g for g in glob_list if not g.startswith('!')]
    neg = [g[1:] for g in glob_list if g.startswith('!')]
    return sorted(i for i in ids if any(fnmatch.fnmatchcase(i, g) for g in pos) and not any(fnmatch.fnmatchcase(i, g) for g in neg))


def build(scores_file=None, base_ids_file=None):
    ext_cases, official_cases = manifests()
    inv = {r.num: r for s in inventory.SECTIONS for r in s[2]}
    surfaces = json.loads((HERE / 'coverage-surfaces.json').read_text())
    ext_by_stripped = {}
    for c in ext_cases:
        ext_by_stripped.setdefault(strip(c['id']), {})[c['theme']] = c
    official_ids = {c['id']: c for c in official_cases}
    pending = {c['id'] for c in official_cases if c.get('baselineStatus') == 'pending' or c.get('skip')}
    rows = json.loads(pathlib.Path(scores_file).read_text())['rows'] if scores_file else []
    scored = {}
    for r in rows:
        if r['look'] == 'raft' and r['score'] is not None:
            scored.setdefault(r['id'], {})[r['mode']] = r['score']
    out = []
    for s in surfaces:
        globs_ext, globs_off = [], []
        for num in s.get('inventoryRows') or []:
            row = inv.get(num)
            if row:
                globs_ext += list(row.d) + list(row.p)
                globs_off += list(row.off)
        for key, extra in EXTRA.items():
            if s['surface'].startswith(key):
                globs_ext += extra.get('ext', [])
        ext_ids = matches(globs_ext, ext_by_stripped)
        off_ids = matches(globs_off, official_ids)
        run_off = [i for i in off_ids if i not in pending]
        widths, modes = set(), set()
        score_light, score_dark = [], []
        for i in ext_ids:
            for theme, c in ext_by_stripped[i].items():
                widths.add(width_label(c['viewport']['width']))
                modes.add('dark' if theme == 'elegant-dark' else 'light')
                sc = scored.get(c['id'], {})
                if 'light' in sc and theme != 'elegant-dark':
                    score_light.append(sc['light'])
                if 'dark' in sc and theme == 'elegant-dark':
                    score_dark.append(sc['dark'])
        for i in run_off:
            widths.add('phone')
            modes.add('light')
            if 'light' in scored.get(i, {}):
                score_light.append(scored[i]['light'])
        reason = next((v for k, v in NO_CASE_REASON.items() if s['surface'].startswith(k)), None)
        out.append({
            'surface': s['surface'], 'level': LEVEL_NAME[s['level']], 'webFiles': s['webFiles'], 'linesChanged': s['linesChanged'],
            'platforms': s['platforms'], 'officialCases': off_ids, 'officialPending': [i for i in off_ids if i in pending],
            'extGlobs': sorted(set(g for g in globs_ext if not g.startswith('!'))), 'extCases': len(ext_ids),
            'extSample': ext_ids[:3], 'covered': widths_modes(widths, modes),
            'casesExist': bool(run_off or ext_ids),
            # with a regression summary a surface counts as covered only when a case of it was captured on both sides and scored
            'coveredBefore': bool(run_off),
            'coveredAfter': bool(score_light or score_dark) if rows else bool(run_off or ext_ids),
            'scoreLightMean': mean(score_light), 'scoreLightMin': min(score_light) if score_light else None,
            'scoreDarkMean': mean(score_dark), 'noCaseReason': reason if not (run_off or ext_ids) else None,
        })
    return out


# Web states per control kind (the states the Web style sheets define for it); `captured` comes from build-states-cases.py.
WEB_STATES = {
    'icon': ('default', 'hover', 'pressed', 'focus'),
    'selectable': ('default', 'hover', 'pressed', 'focus', 'selected'),
    'row': ('default', 'hover', 'pressed', 'focus', 'selected'),
    'toggle': ('default', 'hover', 'pressed', 'focus', 'checked', 'disabled'),
    'touch': ('default', 'pressed', 'selected'),
    'submit': ('default', 'hover', 'pressed', 'focus', 'disabled', 'loading'),
}
# control -> (family, kind): the cases of one family (a selected row and an unselected row) add up to the family's states.
CONTROL_KIND = {
    'rail-tab': ('rail tab', 'selectable'), 'rail-tab-selected': ('rail tab', 'selectable'),
    'rail-settings': ('rail settings button', 'icon'),
    'sidebar-row': ('sidebar row', 'row'), 'sidebar-row-selected': ('sidebar row', 'row'), 'sidebar-row-unread': ('sidebar row', 'row'),
    'sidebar-sort': ('sidebar section sort button', 'icon'), 'sidebar-section-toggle': ('sidebar section toggle', 'icon'),
    'sidebar-saved': ('sidebar Saved entry', 'row'),
    'header-search': ('channel header search button', 'icon'), 'header-overflow': ('channel header settings button', 'icon'),
    'conversation-tab': ('conversation tab (Chat / Tasks / Files)', 'selectable'),
    'conversation-tab-selected': ('conversation tab (Chat / Tasks / Files)', 'selectable'),
    'topbar-search': ('top bar search', 'icon'), 'topbar-bell': ('top bar bell', 'icon'), 'topbar-workspace': ('top bar workspace trigger', 'icon'),
    'composer-submit': ('composer send button', 'submit'), 'composer-as-task': ('composer As Task toggle', 'toggle'),
    'phone-tab': ('phone tab bar item', 'touch'), 'phone-tab-selected': ('phone tab bar item', 'touch'),
    'phone-sidebar-row': ('phone sidebar row', 'touch'),
    'activity-row': ('Activity row', 'row'), 'activity-row-done': ('Activity row Done button', 'icon'),
    'switch': ('settings switch', 'toggle'), 'switch-mid': ('settings switch', 'toggle'),
}
# Controls of the L1 / L2 surfaces that no state case covers yet, and why (the map lists them so the gap is visible).
FLUTTER_GAP = {
    'top bar search': 'no: Flutter has no top bar yet', 'top bar bell': 'no: Flutter has no top bar yet',
    'top bar workspace trigger': 'no: Flutter has no top bar yet',
    'Activity row Done button': 'not driven: the harness hover never builds the action',
}
STATE_GAPS = [
    ('Activity row: menu / saved actions, row selection', 'Activity (threads inbox) page', 'the row menu opens a popover; selected-row state needs the master-detail pane'),
    ('Message hover toolbar buttons (reply, react, more)', 'Channel page', 'appear only on message hover; Flutter shows them through a different gesture (long press / hover region)'),
    ('Composer attach image / file buttons, emoji, mention', 'Channel page', 'Flutter keys missing on these buttons; Web locators exist'),
    ('Settings select / combobox, segmented control, checkbox rows', 'Settings pages', 'Flutter settings page keys cover only the switches; Web theme picker is now a 3-card radio group (Flutter still a segmented control)'),
    ('List-row actions (members row, task card, computer row)', 'Members / Tasks / Computers pages', 'no state cases yet'),
    ('Dialog buttons (confirm / cancel / danger) in context', 'Dialogs', 'covered at component level by the official components.ui.button.states cases'),
    ('Loading state of buttons (spinner)', 'any', 'needs a pending fixture per button; official button states cover the primitive'),
    ('Keyboard focus of rows inside scroll views', 'Sidebar, Activity', 'focus ring is captured on the control itself; scroll-into-view focus is not'),
]


def states_table():
    spec = importlib.util.spec_from_file_location('build_states_cases', HERE / 'build-states-cases.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    families = {}
    entries = [(c[0], c[1], c[2], c[3], c[4], c[5], c[7]) for c in mod.CONTROLS] + \
              [(f'{c[1]}', 'settings appearance', 'page', c[2], c[3], c[4], c[5]) for c in mod.SETTINGS_CONTROLS]
    for control, scene, level, web, flutter, states, hint in entries:
        family, kind = CONTROL_KIND[control.replace('settings ', '')]
        f = families.setdefault(family, {'control': family, 'scene': scene, 'level': level, 'webFile': hint, 'kind': kind,
                                         'webStates': list(WEB_STATES[kind]), 'captured': [], 'flutterSurface': True, 'controls': []})
        canonical = {'revealed': 'default', 'toggled': 'checked', 'enabled': 'default'}
        f['captured'] = sorted(set(f['captured']) | {canonical.get(x, x) for x in states}, key=WEB_STATES[kind].index)
        f['controls'].append(control)
        f['flutterSurface'] = f['flutterSurface'] and flutter is not None
    for f in families.values():
        f['notCaptured'] = [x for x in f['webStates'] if x not in f['captured']]
    return list(families.values())


def mean(xs):
    return round(sum(xs) / len(xs), 4) if xs else None


def widths_modes(widths, modes):
    return {'widths': sorted(widths, key=['phone', 'tablet', 'desktop'].index), 'modes': sorted(modes)}


def skipped_table(rows_scores):
    skipped = json.loads((HERE / 'official-skipped.json').read_text())
    ext_ids = manifests()[0]
    stripped = {strip(c['id']): c for c in ext_ids}
    out = []
    for r in skipped:
        hits = matches(r['proxyGlobs'], list(stripped) + [c['id'] for c in manifests()[1]])
        scores = [rows_scores[h] for h in hits if h in rows_scores]
        out.append({**r, 'proxyCases': len(hits), 'proxyScoreMean': mean(scores), 'proxyScoreMin': min(scores) if scores else None})
    return out


def markdown(rows, states=None, skipped=None, uncaptured=None):
    pct = lambda v: '' if v is None else f'{v * 100:.1f}%'
    by_level = {}
    for r in rows:
        by_level.setdefault(r['level'], []).append(r)
    lines = ['# Visual coverage map: Raft Web v1.21.23 surfaces', '',
             'Generated by `tool/parity-ext/coverage_map.py` from `tool/parity-ext/coverage-surfaces.json` (surfaces), the page '
             'inventory rows and the case manifests; JSON twin: `tool/parity-ext/coverage-map.json`. Levels: **L1 frame** (app '
             'shell chrome), **L2 page** (whole pages), **L3 component** (see docs/parity.md "Visual suite levels").', '',
             f'Surfaces: **{len(rows)}** | covered before this audit: **{sum(r["coveredBefore"] for r in rows)}** | covered now: '
             f'**{sum(r["coveredAfter"] for r in rows)}** (a case exists for {sum(r["casesExist"] for r in rows)}; the rest of those could not be '
             'captured on both sides, see "Could not capture").', '',
             '| level | surfaces | covered before | covered now | below 96% (light mean) |', '| --- | --- | --- | --- | --- |']
    for lvl in ('frame', 'page', 'component'):
        rs = by_level.get(lvl, [])
        lines.append(f'| {lvl} | {len(rs)} | {sum(r["coveredBefore"] for r in rs)} | {sum(r["coveredAfter"] for r in rs)} | '
                     f'{sum(1 for r in rs if r["scoreLightMean"] is not None and r["scoreLightMean"] <= 0.96)} |')
    for lvl in ('frame', 'page', 'component'):
        lines += ['', f'## {lvl}', '',
                  '| surface | Web source | official case ids | extension cases | widths | modes | light mean (min) | dark mean |',
                  '| --- | --- | --- | --- | --- | --- | --- | --- |']
        for r in by_level.get(lvl, []):
            files = ', '.join(f'`{f}`' for f in r['webFiles'][:3]) + (f' (+{len(r["webFiles"]) - 3})' if len(r['webFiles']) > 3 else '')
            off = ', '.join(f'`{i}`' for i in r['officialCases'][:4]) + (f' (+{len(r["officialCases"]) - 4})' if len(r['officialCases']) > 4 else '')
            ext = f'{r["extCases"]} (`{r["extSample"][0]}`...)' if r['extCases'] else ''
            if r['noCaseReason']:
                ext = f'none: {r["noCaseReason"]}'
            score = '' if r['scoreLightMean'] is None else f'{pct(r["scoreLightMean"])} ({pct(r["scoreLightMin"])})'
            lines.append(f'| {r["surface"]} | {files} | {off} | {ext} | {", ".join(r["covered"]["widths"])} | '
                         f'{", ".join(r["covered"]["modes"])} | {score} | {pct(r["scoreDarkMean"])} |')
    if uncaptured:
        lines += ['', '## Could not capture', '',
                  'Cases of the regression run that have no score: no Web capture (`Web:`), no Flutter capture (`Flutter:`), no valid dark reference '
                  '(the Web host renders a light page in dark mode), or no Flutter surface. Counts per look / mode and reason.', '',
                  '| look | mode | reason | cases | example |', '| --- | --- | --- | --- | --- |']
        for (look, mode, why), ids in sorted(uncaptured.items(), key=lambda kv: -len(kv[1])):
            lines.append(f"| {look} | {mode} | {why} | {len(ids)} | `{ids[0]}` |")
    if states:
        lines += ['', '## Control states', '',
                  'States the Web defines per control kind (default / hover / pressed / focus / selected / checked / disabled / loading) and the ones '
                  'a state case captures (`tool/parity-ext/build-states-cases.py`): Raft vs Web, Elegant / Brutal vs their frozen originals.', '',
                  '| control | scene | level | Web source | Web states | captured | not captured | Flutter surface |',
                  '| --- | --- | --- | --- | --- | --- | --- | --- |']
        for c in states:
            lines.append(f"| `{c['control']}` | {c['scene']} | {c['level']} | `{c['webFile']}` | {', '.join(c['webStates'])} | {', '.join(c['captured'])} | "
                         f"{', '.join(c['notCaptured'])} | {'yes' if c['flutterSurface'] else FLUTTER_GAP.get(c['control'], 'no')} |")
        lines += ['', 'Control families without a state case yet:', '', '| controls | surface | why |', '| --- | --- | --- |']
        lines += [f'| {a} | {b} | {c} |' for a, b, c in STATE_GAPS]
    if skipped:
        lines += ['', '## Official cases the tool cannot run', '',
                  '119 cases in `sharedCases.json`; 99 run. The other 20 (18 `baselineStatus: pending`, 2 hidden upstream) have no React capture in the '
                  'official host (no fixture, no render route). Each is scored here through the extension cases that render the same Web page '
                  '(`tool/parity-ext/official-skipped.json`).', '',
                  '| official case | status | upstream reason | proxy cases | proxy mean (min) |', '| --- | --- | --- | --- | --- |']
        for r in skipped:
            sc = '' if r['proxyScoreMean'] is None else f"{r['proxyScoreMean'] * 100:.1f}% ({r['proxyScoreMin'] * 100:.1f}%)"
            lines.append(f"| `{r['id']}` | {r['officialStatus']} | {r['upstreamReason'][:90].replace('|', '/')} | {r['proxyCases']} ({', '.join('`' + g + '`' for g in r['proxyGlobs'][:2])}) | {sc or ('none: ' + (r['note'] or '')) } |")
    return '\n'.join(lines) + '\n'


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--scores', help='regress-summary.json of a tool/parity-ext/run regress run')
    p.add_argument('--write-json', default=str(HERE / 'coverage-map.json'))
    p.add_argument('--write-md', default=str(ROOT / 'docs/parity-coverage-map.md'))
    a = p.parse_args()
    rows = build(a.scores)
    states = states_table()
    rows_scores = {}
    if a.scores:
        for r in json.loads(pathlib.Path(a.scores).read_text())['rows']:
            if r['look'] == 'raft' and r['mode'] == 'light' and r['score'] is not None:
                rows_scores[strip(r['id'])] = r['score']
                rows_scores[r['id']] = r['score']
    skipped = skipped_table(rows_scores)
    pathlib.Path(a.write_json).write_text(json.dumps({'surfaces': rows, 'controlStates': states, 'stateGaps': STATE_GAPS,
                                                      'officialSkipped': skipped}, indent=1, ensure_ascii=False) + '\n')
    uncaptured = {}
    if a.scores:
        import re
        for r in json.loads(pathlib.Path(a.scores).read_text())['rows']:
            if r['score'] is None and r['look'] != 'raft' and r['engine'] == 'ext' and r['verdict'] == 'react-missing':
                key = (r['look'], r['mode'], 'no frozen reference image (case did not exist or did not render at a57b9dab)')
            elif r['score'] is None and r['verdict'] == 'not-covered':
                key = (r['look'], r['mode'], 'no Flutter surface / case builder (not covered)')
            elif r['score'] is None:
                why = re.sub(r'components\.[\w.-]+', '<id>', (r.get('why') or r['verdict']))[:110]
                key = (r['look'], r['mode'], why)
            else:
                continue
            uncaptured.setdefault(key, []).append(r['id'])
    pathlib.Path(a.write_md).write_text(markdown(rows, states, skipped, uncaptured))
    print(f'{len(rows)} surfaces; before {sum(r["coveredBefore"] for r in rows)}, now {sum(r["coveredAfter"] for r in rows)}')


if __name__ == '__main__':
    main()
