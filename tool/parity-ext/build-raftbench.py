#!/usr/bin/env python3
"""Append the RaftBench page cases (Web v1.21.23 raftbench/*) to the run-time
manifest ($PARITY_EXT_MANIFEST) and write tool/parity-ext/fixtures/raftbench.json.

Run after build-cases.py (append-only for the other families; idempotent: every
`components.raftbench.*` case is replaced).

Ids (append-only, never rename): components.raftbench.<state>[.<region>].<theme>

React (host/RaftBenchCases.tsx) mounts the real settings rail and RaftBenchPage
in the ext-settings frame (1216 wide; the bare page at 390 on mobile) for an
owner on a server enrolled in `raftbench_overview_v0`; Flutter
(cases/ext_raftbench.dart) mounts WorkspaceSettings on tab `raftbench` with the
same routes. Every route lives in a `routeSets` entry so no other family sees it.
The page reads the fixture clock (2026-06-19T12:30Z): the task and spend windows
are the UTC days 06-05 .. 06-19.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)

THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.raftbench.'
PANEL = "[data-parity-region='settings-panel']"
SCROLL = '[data-testid="raftbench-page"] > div.overflow-y-auto'
HINT = 'packages/web/src/raftbench/RaftBenchPage.tsx (+ ManagerOverview.tsx, HostedAnalysis.tsx)'

# The fixture channels the page lists: `design` and `android-artifacts`.
CH_DESIGN = 'channel-design'
CH_ANDROID = 'channel-android'
AGENT = 'agent-raftbench-service'
M1 = '3f9c1a77-5b2e-4d8a-a1c3-0e9d8c7b6a51'
M2 = '8e2d4b10-6c3f-4a9b-b2d4-1f0e9d8c7b63'
START = '2026-06-12T00:00:00.000Z'
NOW = '2026-06-19T12:30:00.000Z'


def pattern(kind, explanation, evidence, counter=(), level='conversation_only', intent='active', suggestion=''):
    return {'kind': kind, 'explanation': explanation,
            'evidence': [{'target': t, 'messageId': m} for t, m in evidence],
            'counterevidence': [{'target': t, 'messageId': m} for t, m in counter],
            'evidenceLevel': level, 'intent': intent, 'suggestion': suggestion}


PATTERNS = [
    pattern('unsupported_completion', 'The agent said the deploy finished but no later message confirms it.',
            [('#design', M1[:8]), ('#design', M2)], [('#android-artifacts', M2)],
            suggestion='Ask the agent to post the deploy link before closing the task.'),
    pattern('repeated_attempt', 'Three attempts at the same migration with the same error text.',
            [('#android-artifacts', M2)], level='insufficient', intent='unknown'),
]
COVERAGE = {'totalMessages': 412, 'windowMessages': 189, 'earliestAt': '2026-05-02T08:11:00.000Z',
            'latestAt': '2026-06-18T22:40:12.000Z', 'from': START, 'to': NOW, 'checkedAt': NOW}


def run(n, status, fetched, report, *, stop='window_end', exhausted=True, failure=None, skipped=(), frm=START):
    return {'runId': f'c6b0e6a2-0f4e-4b3a-8f7e-2d1c0b9a8f7{n}', 'status': status, 'from': frm, 'to': NOW,
            'updatedAt': NOW, 'fetchedMessages': fetched, 'skippedRanges': list(skipped), 'stopReason': stop,
            'exhausted': exhausted, 'skippedChunks': len(skipped), 'failureReason': failure, 'report': report}


def report(status, reason, gaps, patterns):
    return {'status': status, 'reason': reason, 'gaps': gaps, 'patterns': patterns}


def dashboard(*, enabled=True, revision=3, run_=None, coverage=COVERAGE, progress=None, pages=(1, 1, 0),
              provisioning='active'):
    return {'historyFrom': START if enabled or revision else None, 'coverage': coverage if enabled else None,
            'progress': progress or {'readMessages': 0, 'completedBatches': 0, 'scannedThroughAt': None},
            'enabled': enabled, 'revision': revision if revision else 0,
            'channelIds': [CH_DESIGN] if revision else [], 'agentId': AGENT if revision else None,
            'intervalMinutes': 15,
            'provisioning': ({'state': provisioning, 'error': None, 'profile': 'raftbench_service',
                              'providerTarget': 'default'} if revision else None),
            'run': run_, 'pagination': {'page': pages[0], 'pageCount': pages[1], 'total': pages[2], 'pageSize': 5}}


SERVICE_AGENTS = {'agents': [{'agentId': AGENT, 'name': 'raftbench-service', 'state': 'active', 'ready': True},
                             {'agentId': 'agent-raftbench-second', 'name': 'raftbench-service-a1b2c3',
                              'state': 'provisioning', 'ready': False}]}
STATES = {
    'disabled': dashboard(enabled=False, revision=0, run_=None),
    'running': dashboard(run_=run(1, 'running', 41, report('incomplete', None, ['partial_scan'], []),
                                  stop='more_pages', exhausted=False),
                         progress={'readMessages': 96, 'completedBatches': 2,
                                   'scannedThroughAt': '2026-06-16T11:03:00.000Z'}),
    'ready': dashboard(run_=run(2, 'ready', 33, report('complete', None, ['missing_tool_outcomes'], PATTERNS)),
                       progress={'readMessages': 189, 'completedBatches': 4,
                                 'scannedThroughAt': '2026-06-18T22:40:12.000Z'}, pages=(1, 2, 7)),
    'stale': dashboard(run_=run(3, 'stale', 33, None)),
    'skipped': dashboard(run_=run(4, 'ready', 12, report('incomplete', 'A chunk was skipped.',
                                                          ['partial_scan'], PATTERNS[:1]),
                                  skipped=[{'from': '2026-06-14T00:00:00.000Z', 'to': '2026-06-15T00:00:00.000Z',
                                            'messages': 44}], frm='2026-06-16T11:03:00.000Z'),
                         progress={'readMessages': 96, 'completedBatches': 2,
                                   'scannedThroughAt': '2026-06-16T11:03:00.000Z'}, pages=(1, 1, 1)),
    'failed': dashboard(run_=run(5, 'failed', 0, None, stop='more_pages', exhausted=False,
                                 failure='The cloud analysis did not finish within 30 minutes. '
                                         'No completed result was accepted.')),
    'outside-window': dashboard(coverage={**COVERAGE, 'windowMessages': 0},
                                run_=run(6, 'ready', 0, report('incomplete', 'No messages were read in this window; nothing was analyzed.',
                                                               ['missing_tool_outcomes'], []))),
}
SNAPSHOT = {'surfaces': 3, 'total': 10, 'todo': 2, 'inProgress': 3, 'inReview': 1, 'done': 3, 'closed': 1,
            'humanCreated': 6, 'agentCreated': 4, 'durationSamples': 3, 'medianHours': 5.5, 'p90Hours': 26.25,
            'firstCreatedAt': '2026-05-02T08:30:00.000Z', 'latestCreatedAt': '2026-06-18T09:00:00.000Z',
            'latestUpdatedAt': '2026-06-18T22:00:00.000Z'}
PERIODS = {'surfaces': 3, 'from': '2026-06-05T00:00:00.000Z', 'midpoint': '2026-06-12T00:00:00.000Z',
           'to': '2026-06-19T00:00:00.000Z',
           'current': {'completed': 4, 'durationSamples': 3, 'meanHours': 8.25, 'medianHours': 5.5},
           'previous': {'completed': 1, 'durationSamples': 1, 'meanHours': 30, 'medianHours': 30}}
USAGE = {'currency': 'USD', 'estimated': True, 'bucket': 'day', 'from': '2026-06-05T00:00:00.000Z',
         'to': '2026-06-19T00:00:00.000Z',
         'periods': [{'start': f'2026-06-{d:02d}T00:00:00.000Z', 'totalUsd': u, 'unpriced': []}
                     for d, u in [(5, 0.5), (7, 0.25), (12, 0.125), (15, 1.5), (18, 0.0049)]]}

fixture = {
    'name': 'raft-flutter parity extension: RaftBench (Web v1.21.23)',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': 'db5e399f017d584e49597e3a28757645d6807893',
    'routes': {},
    'routeSets': {},
}
COMMON = {
    'GET /raftbench/agents': SERVICE_AGENTS,
    'GET /tasks/server/snapshot-metrics': SNAPSHOT,
    'GET /tasks/server/period-metrics': PERIODS,
    'GET /billing/hosted-runtime-usage': USAGE,
    f'GET /agents/{AGENT}/hosted-runtime/model': {'label': 'DeepSeek Flash'},
}
for name, body in STATES.items():
    fixture['routeSets'][f'raftbench-{name}'] = {**COMMON, 'GET /raftbench': body}
# Nothing answers yet: every section shows its loading line.
fixture['routeSets']['raftbench-loading'] = {key: {'$pending': True} for key in [*COMMON, 'GET /raftbench']}
# Every read fails: the generic dashboard error and the three aggregate errors.
fixture['routeSets']['raftbench-error'] = {key: {'$status': 500} for key in [*COMMON, 'GET /raftbench']}

cases = []


def add(key, title, *, state, platform='desktop', scroll=0, hint=HINT):
    mobile = platform == 'mobile'
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{key}.{suffix}'
        props = {'extCase': key, 'extKind': 'raftbench', 'parityTheme': theme, 'platform': platform,
                 'tab': 'raftbench', 'role': 'owner', 'flags': 'raftbench', 'routeSet': f'raftbench-{state}'}
        interactions = [{'type': 'wait', 'ms': 1200}]
        android = []
        if scroll:
            interactions.append({'type': 'scroll', 'target': SCROLL, 'y': scroll})
            interactions.append({'type': 'wait', 'ms': 300})
            android.extend({'type': 'scroll', 'key': 'raftbench-scroll', 'dy': 1000} for _ in range(scroll // 1000))
        capture = {'selector': "[data-visual-case='%s']" % cid if mobile else PANEL, 'crop': 'element',
                   'contract': 'component-bounds', 'interactions': interactions, 'androidInteractions': android}
        if not mobile:
            capture['androidKey'] = 'settings-panel'
        cases.append({
            'id': cid,
            'title': f'RaftBench {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'raftbench',
            'category': 'extension/raftbench',
            'suite': 'raft-flutter-extension',
            'viewport': MOBILE if mobile else DESKTOP,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': capture,
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_raftbench.dart '{key}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })


for state, label in [('disabled', 'not enabled yet'), ('running', 'analysis running'),
                     ('ready', 'findings ready'), ('stale', 'results stale'),
                     ('skipped', 'a skipped window'), ('failed', 'run failed'),
                     ('outside-window', 'messages outside the range')]:
    add(f'page.{state}', f'page, {label}', state=state)
    add(f'page.{state}-insights', f'page scrolled to the insights, {label}', state=state, scroll=4000)
add('page.loading', 'page, loading', state='loading')
add('page.loading-insights', 'page scrolled to the insights, loading', state='loading', scroll=4000)
add('page.error', 'page, every read failed', state='error')
add('page.error-insights', 'page scrolled to the insights, every read failed', state='error', scroll=4000)
for state in ('disabled', 'ready'):
    add(f'page.{state}-mobile', f'page on a phone, {state}', state=state, platform='mobile')
    add(f'page.{state}-insights-mobile', f'page on a phone scrolled to the insights, {state}', state=state,
        platform='mobile', scroll=4000)

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/raftbench.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} raftbench cases appended -> the run-time manifest; fixture -> tool/parity-ext/fixtures/raftbench.json')
