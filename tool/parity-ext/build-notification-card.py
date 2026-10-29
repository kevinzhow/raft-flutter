#!/usr/bin/env python3
"""Append the Settings -> Notifications desktop card cases to
the run-time manifest ($PARITY_EXT_MANIFEST).

Run after build-cases.py (build-cases.py rewrites
the manifest from scratch); idempotent: every `components.notifications.*` case
is replaced, all other cases are kept, and new ids are appended after them.

Derivation (raft-source packages/web/src):
  components/settings/SettingsPanel.tsx  NotificationsSection ->
    DesktopNativeNotificationsCard (data-testid desktop-notifications-card)
  utils/notificationChannel.ts / desktopNativeNotifications.ts
    (available = Electron shell + Notification API)
  i18n/messages/en.ts settings.notifications.desktop.*
Ids: components.notifications.desktop.<available|unavailable>.<theme>.
The capture is the SectionHeader + card block of the 640px settings column.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
VIEWPORT = {'width': 640, 'height': 600, 'density': 1}
SELECTOR = 'div:has(> [data-testid="desktop-notifications-card"])'
HINT = ('packages/web/src/components/settings/SettingsPanel.tsx '
        '#DesktopNativeNotificationsCard (rendered through SettingsPanel tab=notifications)')

cases = []
for kind, available in [('available', True), ('unavailable', False)]:
    for suffix, theme in THEMES.items():
        cid = f'components.notifications.desktop.{kind}.{suffix}'
        props = {'extCase': f'desktop.{kind}', 'extKind': 'notification', 'parityTheme': theme,
                 'platform': 'desktop', 'available': available}
        cases.append({
            'id': cid,
            'title': f'Settings desktop notifications card {kind} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'notifications',
            'category': 'extension/notifications',
            'suite': 'raft-flutter-extension',
            'viewport': VIEWPORT,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': {'selector': SELECTOR, 'crop': 'element', 'contract': 'component-bounds',
                        'androidKey': 'notification-settings-card', 'interactions': [],
                        'androidInteractions': []},
            'reactPathHint': HINT,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_notifications.dart 'desktop.{kind}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.notifications.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} notification card cases appended ({len(manifest["cases"])} total)')
