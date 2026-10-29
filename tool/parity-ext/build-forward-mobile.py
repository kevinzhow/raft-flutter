#!/usr/bin/env python3
"""Append the phone forward page cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Run after build-cases.py; idempotent: every `components.forward-mobile.*` case is replaced,
all other cases are kept.

Derivation (raft-source 26f77ef, packages/web/src/components/message):
  ForwardComposerDialog.tsx -> ForwardComposerMobile.tsx (viewport < 768px): the full-screen
  "Select destinations" page (Recent list, search), "Select multiple" (checkbox rows, Done), and the
  single-select shortcut to the "Add a note" page; ForwardComposerTargetList.tsx rows and the
  search loading / failed / empty rows.
Ids: components.forward-mobile.page.<state>.<theme>; one surface, so the elegant themes are sampled
(first = targets, dense = multi); run with PARITY_EXT_ALL_THEMES=1 for every state in every theme.
React mounts the real ForwardComposerDialog (host/ForwardMobileCases.tsx); Flutter mounts the real
ForwardComposerPage (cases/ext_forward_mobile.dart) on the same fixture (fixtures/forwardmobile.json).
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.forward-mobile.'
SEARCH = 'input[placeholder="Search targets"]'
ROW = '[data-testid="forward-target-{}"]'
WAIT = {'type': 'wait', 'ms': 700}
MULTI = {'type': 'click', 'target': 'role=button[name="Select multiple"]'}

# state -> (title, routeSet, React interactions)
STATES = {
    'targets': ('Select destinations, Recent list', None, []),
    'search': ('Search results (channel, not joined, DM, new DM)', None,
               [{'type': 'fill', 'target': SEARCH, 'value': 'de'}, WAIT]),
    'search-empty': ('Search, no matching destinations', 'fm-empty',
                     [{'type': 'fill', 'target': SEARCH, 'value': 'zzzz'}, WAIT]),
    'search-error': ('Search failed (Try again)', 'fm-error',
                     [{'type': 'fill', 'target': SEARCH, 'value': 'de'}, WAIT]),
    'search-loading': ('Search in flight (spinner)', 'fm-loading',
                       [{'type': 'fill', 'target': SEARCH, 'value': 'de'}, WAIT]),
    'multi': ('Select multiple, two selected', None,
              [MULTI, {'type': 'click', 'target': ROW.format('channel-fm-general')},
               {'type': 'click', 'target': ROW.format('dm-fm-cindy')}, WAIT]),
    'note': ('Add a note page (single select)', None,
             [{'type': 'click', 'target': ROW.format('channel-fm-design')}, {'type': 'wait', 'ms': 900}]),
}

cases = []
for state, (title, route_set, interactions) in STATES.items():
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}page.{state}.{suffix}'
        props = {'extCase': f'page.{state}', 'extKind': 'forward-mobile', 'extFixture': 'forwardmobile',
                 'parityTheme': theme, 'platform': 'mobile', 'state': state}
        if route_set:
            props['routeSet'] = route_set
        cases.append({
            'id': cid,
            'title': f'Phone forward page: {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'forward-mobile',
            'category': 'extension/forward-mobile',
            'suite': 'raft-flutter-extension',
            'viewport': MOBILE,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            # The dialog is portaled out of the case box: capture the whole 390x844 viewport.
            'capture': {'selector': 'body', 'crop': 'viewport', 'contract': 'viewport-with-portal',
                        'interactions': interactions, 'androidInteractions': []},
            'reactPathHint': 'packages/web/src/components/message/ForwardComposerMobile.tsx',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_forward_mobile.dart 'page.{state}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} phone forward page cases appended ({len(manifest["cases"])} total)')
