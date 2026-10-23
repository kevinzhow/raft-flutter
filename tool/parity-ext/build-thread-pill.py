#!/usr/bin/env python3
"""Append the channel "Earliest / Next unread thread" pill cases to the run-time
manifest ($PARITY_EXT_MANIFEST). Idempotent: every `components.thread-pill.*` case
is replaced, all other cases are kept.

Derivation (raft-source packages/web/src):
  components/message/ThreadUnreadJumpPill.tsx  the pill (placement above -> top,
    below -> beside "Back to bottom"), flag `thread_unread_badge_v0`
  components/message/ChatPanel.tsx             bottomButton (Back to bottom)
Ids: components.thread-pill.<top|bottom>.<theme>; React: host/ThreadPillCases.tsx;
Flutter: apps/raft_flutter/test/parity/cases/ext_thread_pill.dart.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
VIEWPORT = {'width': 420, 'height': 200, 'density': 1}
HINT = 'packages/web/src/components/message/ThreadUnreadJumpPill.tsx'

cases = []
for variant, title in [('top', 'Earliest unread thread pill at the top'),
                       ('bottom', 'Next unread thread pill beside Back to bottom')]:
    for suffix, theme in THEMES.items():
        props = {'extCase': variant, 'extKind': 'thread-pill', 'parityTheme': theme, 'platform': 'desktop',
                 'variant': variant}
        cases.append({
            'id': f'components.thread-pill.{variant}.{suffix}',
            'title': f'{title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'thread-pill',
            'category': 'extension/thread-pill',
            'suite': 'raft-flutter-extension',
            'viewport': VIEWPORT,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': {'selector': '[data-visual-case]', 'crop': 'element', 'contract': 'component-bounds',
                        'androidKey': 'thread-pill-case', 'interactions': [], 'androidInteractions': []},
            'reactPathHint': HINT,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_thread_pill.dart '{variant}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.thread-pill.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} thread pill cases appended ({len(manifest["cases"])} total)')
