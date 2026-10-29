#!/usr/bin/env python3
"""Render docs/capability-parity.md from docs/capability-parity.json.

    python3 tool/capability_parity_report.py            # write docs/capability-parity.md
    python3 tool/capability_parity_report.py --check    # fail when the .md is stale
    python3 tool/capability_parity_report.py --out PATH # write somewhere else (e.g. /tmp)
"""
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'docs' / 'capability-parity.json'
DST = ROOT / 'docs' / 'capability-parity.md'

ICON = {'covered': '✅', 'partial': '⚠️', 'missing': '❌', 'na': '➖'}
ORDER = ['messages', 'threads', 'channels', 'dms', 'members-roles', 'server-settings-admin', 'billing',
         'agents-computers-runtimes', 'integrations-apps-mcp', 'tasks', 'files-attachments', 'search',
         'notifications', 'account-profile', 'onboarding-auth', 'joint-channels', 'public-guest', 'global-ui']
TITLES = {
    'messages': 'Messages', 'threads': 'Threads', 'channels': 'Channels', 'dms': 'DMs',
    'members-roles': 'Members and roles', 'server-settings-admin': 'Server settings and admin',
    'billing': 'Billing', 'agents-computers-runtimes': 'Agents, computers, runtimes',
    'integrations-apps-mcp': 'Integrations, apps, MCP', 'tasks': 'Tasks', 'files-attachments': 'Files and attachments',
    'search': 'Search', 'notifications': 'Notifications', 'account-profile': 'Account and profile',
    'onboarding-auth': 'Onboarding and auth', 'joint-channels': 'Joint channels',
    'public-guest': 'Public and guest', 'global-ui': 'Global UI and cross-cutting',
}


def cell(text: str) -> str:
    return (text or '').replace('|', '\\|').replace('\n', ' ').strip()


def render(doc: dict) -> str:
    entries = doc['entries']
    counts = Counter(e['status'] for e in entries)
    by_kind = Counter(e['kind'] for e in entries)
    lines = [
        '# Capability parity: Web vs Flutter',
        '',
        'Generated from `docs/capability-parity.json` by `tool/capability_parity_report.py`; edit the JSON, not this file.',
        f"Web reference: raft-source `{doc['webSource']['commit'][:9]}` (Web {doc['webSource']['version']}). "
        'Guard: `apps/raft_flutter/test/capability_parity_guard_test.dart` (run with `RAFT_WEB_SOURCE=<checkout>` to also '
        'fail on Web endpoints missing from the JSON). Extractor: `tool/capability_parity.py`.',
        '',
        'Pixel parity, field parity (`docs/field-parity.md`) and the page inventory (`docs/parity.md`) never compared '
        'what a user can do. This document does: every Web client-to-server call and every client-side action, mapped to Flutter.',
        '',
        '## Summary',
        '',
        f"Total capabilities: {len(entries)} ({by_kind['endpoint']} endpoint/network keys, {by_kind['ui']} client-side).",
        '',
        '| Status | Count |', '| --- | ---: |',
    ]
    for s in ('covered', 'partial', 'missing', 'na'):
        lines.append(f"| {ICON[s]} {s} | {counts[s]} |")
    lines += ['', '| Area | ✅ | ⚠️ | ❌ | ➖ |', '| --- | ---: | ---: | ---: | ---: |']
    per = defaultdict(Counter)
    for e in entries:
        per[e['area']][e['status']] += 1
    for area in ORDER:
        if area in per:
            c = per[area]
            lines.append(f"| {TITLES.get(area, area)} | {c['covered']} | {c['partial']} | {c['missing']} | {c['na']} |")
    top = sorted((e for e in entries if e.get('topGap')), key=lambda e: e['topGap'])
    lines += ['', '### Top gaps by user impact', '',
              '| # | Status | Capability | Who hits it / how often | Size |', '| ---: | --- | --- | --- | :-: |']
    for e in top:
        lines.append(f"| {e['topGap']} | {ICON[e['status']]} | {cell(e['capability'])} (`{cell(e['id'])}`) | "
                     f"{cell(e.get('impact', ''))} | {e.get('size', '')} |")
    lines += ['', 'Sizes: S under a day over an existing endpoint, M one to three days (new screen or flow), '
              'L over three days (new subsystem, realtime, native integration).', '',
              'Legend: ✅ covered (endpoint called and a reachable entry point with equivalent options and gating), '
              '⚠️ partial, ❌ missing, ➖ intentionally not applicable (reason given). '
              '`bg` marks calls that are not user-initiated (polling, prefetch, telemetry).', '']
    for area in ORDER:
        rows = [e for e in entries if e['area'] == area]
        if not rows:
            continue
        rows.sort(key=lambda e: (e['kind'] != 'endpoint', e['id']))
        lines += [f"## {TITLES.get(area, area)}", '',
                  '| | Capability | Id | Web entry | Flutter entry | Notes |', '| --- | --- | --- | --- | --- | --- |']
        for e in rows:
            note = []
            if e['status'] in ('partial', 'missing') and e.get('impact'):
                note.append(f"Impact: {e['impact']}")
            if e.get('justification'):
                note.append(e['justification'] if e['status'] != 'na' else f"N/A: {e['justification']}")
            if e['status'] in ('partial', 'missing') and e.get('size'):
                note.append(f"Size {e['size']}")
            gate = f" [gate: {e['gate']}]" if e.get('gate') else ''
            bg = ' (bg)' if e.get('background') else ''
            lines.append(f"| {ICON[e['status']]} | {cell(e['capability'])}{bg} | `{cell(e['id'])}` | "
                         f"{cell(e['webEntry'])}{cell(gate)} | {cell(e.get('flutterEntry', ''))} | {cell(' '.join(note))} |")
        lines.append('')
    return '\n'.join(lines).rstrip() + '\n'


def main(argv: list[str]) -> int:
    doc = json.loads(SRC.read_text(encoding='utf-8'))
    text = render(doc)
    if '--check' in argv:
        if not DST.exists() or DST.read_text(encoding='utf-8') != text:
            print('docs/capability-parity.md is stale: run python3 tool/capability_parity_report.py')
            return 1
        return 0
    out = Path(argv[argv.index('--out') + 1]) if '--out' in argv else DST
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding='utf-8')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
