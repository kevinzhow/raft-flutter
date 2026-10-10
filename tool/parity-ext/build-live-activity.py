#!/usr/bin/env python3
"""Append the live agent activity bar cases to tool/parity-ext/cases.json.

Run after build-cases.py (which regenerates the Computers cases); idempotent:
every `components.liveactivity.*` case is replaced, all other cases are kept.

Derivation (raft-source packages/web/src):
  components/layout/LiveAgentActivityBar.tsx  (LiveAgentActivityBarPresentation)
  raft-ui live-agent-activity-bar recipe       (root/row/avatar/content/status/text)
  layout/MainLayout.tsx + MobileBottomBarStack.tsx  (placement)
  utils/liveAgentActivity.ts                   (only working/thinking show)
Ids: components.liveactivity.<platform>.<kind>.<theme>. Props `activity`,
`text` (raw detail) and `descriptor` (i18n id) drive both providers.
"""
import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 240, 'height': 400, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
LONG = ('Reading apps/raft_flutter/lib/features/chat_agent_presentation.dart and comparing it with the '
        'Web LiveAgentActivityBar source before changing the recipe')
KINDS = {
    'tool-finished': {'activity': 'working', 'text': 'Tool finished'},
    'working': {'activity': 'working', 'text': 'Capturing visual testing baselines'},
    'thinking': {'activity': 'thinking', 'text': 'Thinking…', 'descriptor': 'activity.status.thinkingEllipsis'},
    'compacting': {'activity': 'working', 'text': 'Compacting context…',
                   'descriptor': 'activity.status.compactingContextEllipsis'},
    'long': {'activity': 'working', 'text': LONG},
}
PLATFORMS = {
    'desktop': (DESKTOP, ['tool-finished', 'working', 'thinking', 'compacting', 'long']),
    'mobile': (MOBILE, ['tool-finished', 'thinking', 'long']),
}
HINT = ('packages/web/src/components/layout/LiveAgentActivityBar.tsx '
        '+ raft-ui live-agent-activity-bar recipe')

cases = []
for platform, (viewport, kinds) in PLATFORMS.items():
    for kind in kinds:
        for suffix, theme in THEMES.items():
            cid = f'components.liveactivity.{platform}.{kind}.{suffix}'
            props = {'extCase': f'{platform}.{kind}', 'extKind': 'live', 'parityTheme': theme,
                     'platform': platform, **KINDS[kind]}
            cases.append({
                'id': cid,
                'title': f'Live agent activity bar {platform} {kind} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'live-activity',
                'category': 'extension/live-activity',
                'suite': 'raft-flutter-extension',
                'viewport': viewport,
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': {'selector': '[data-testid="live-agent-activity-bar"]', 'crop': 'element',
                            'contract': 'component-bounds', 'androidKey': 'live-agent-activity-bar',
                            'interactions': [], 'androidInteractions': []},
                'reactPathHint': HINT,
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_live_activity.dart '{platform}.{kind}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })

path = here / 'cases.json'
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.liveactivity.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} live activity cases appended ({len(manifest["cases"])} total)')
