#!/usr/bin/env python3
"""Append the sidebar row context-menu cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Run after build-shell-cases.py (it renders the shell host's view with the shell
fixture, fixtures/shell.json); idempotent: every `components.row-menus.*` case
is replaced, all other cases are kept.

Derivation (raft-source packages/web/src):
  components/layout/Sidebar.tsx   ctxMenu (channel / human / dm / agent rows),
                                  sectionCtxMenu, sidebarSurfaceCtxMenu,
                                  "Move to section" popup (placeSidebarContextSubmenu)
  hooks/useLongPress.ts           phone: a 500 ms touch hold opens the same
                                  anchored popover as the desktop right click
Ids: components.row-menus.<platform>.<surface>.<theme>. The Web side opens the
menu with its right click (the long press is a touch-only trigger of the same
popover); the Flutter side performs the real long press on the phone.
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
RAIL = 'shell-rail-sidebar'
MOBILE_HOME = 'shell-mobile-home'
EXTRA = {'extra': 280}
SECTION_TOGGLE = 'sidebar-section-toggle-'
HINT = 'packages/web/src/components/layout/Sidebar.tsx'


def tid(testid):
    return f'[data-testid="{testid}"]'


def row(channel_id):
    return f'[data-sidebar-channel-id="{channel_id}"]'


def rightclick(selector, x=None, y=None):
    step = {'type': 'rightclick', 'target': selector}
    if x is not None:
        step.update(x=x, y=y)
    return step


def click(selector):
    return {'type': 'click', 'target': selector}


def tap(key):
    return {'type': 'tap', 'key': key}


def press(kind, key, x=None, y=None):
    """The Flutter interaction opening the menu: native right click (the Web host right-clicks too),
    a touch long press for the phone's rows."""
    is_row = key.startswith(('sidebar-channel-', 'sidebar-agent:'))
    step = {'type': 'longPress' if kind != 'desktop' and is_row else 'secondaryTap', 'key': key}
    if is_row:
        step['row'] = True
    if x is not None:
        step.update(x=x, y=y)
    return step


def spec(platform, surface, *, preset, title, web, flutter):
    return {'platform': platform, 'surface': surface, 'preset': preset, 'title': title, 'web': web, 'flutter': flutter}


CHANNEL_ROW = lambda cid: ('sidebar-channel-' + cid, row(cid))
CINDY = '[data-slot="sidebar-item"]:has-text("Cindy")'
COLLAPSE_WEB = [click(tid(SECTION_TOGGLE + s)) for s in ('channels', 'dms', 'pinned')]
COLLAPSE_FLUTTER = [tap(f'sidebar-disclosure-system:{s}') for s in ('channels', 'dms', 'pinned')]

SPECS = []
for platform, preset in (('mobile', 'mobile'), ('desktop', 'default')):
    custom = 'mobile-custom' if platform == 'mobile' else 'custom'
    SPECS += [
        spec(platform, 'menu.channel-muted', preset=preset, title='Muted channel row menu',
             web=[rightclick(row('shell-random'))], flutter=[press(platform, 'sidebar-channel-shell-random')]),
        spec(platform, 'menu.dm', preset=preset, title='Human DM row menu',
             web=[*COLLAPSE_WEB[::2], rightclick(row('shell-dm-designer'))],
             flutter=[*COLLAPSE_FLUTTER[::2], press(platform, 'sidebar-channel-shell-dm-designer')]),
        spec(platform, 'menu.agent-dm', preset=preset, title='Pinned agent DM row menu',
             web=[rightclick(CINDY)], flutter=[press(platform, 'sidebar-agent:agent-cindy')]),
        spec(platform, 'menu.pinned-channel', preset=preset, title='Pinned channel row menu (Unpin)',
             web=[rightclick(row('shell-engineering'))], flutter=[press(platform, 'sidebar-channel-shell-engineering')]),
        spec(platform, 'menu.section', preset=preset, title='Channels section header menu',
             web=[rightclick(tid(SECTION_TOGGLE + 'channels'), 30, 12)],
             flutter=[press(platform, 'sidebar-section-system:channels', 38, 24)]),
        spec(platform, 'menu.section-custom', preset=custom, title='Custom section header menu',
             web=[rightclick('[data-testid="sidebar-custom-section-sec-launch"] button[aria-expanded]', 30, 12)],
             flutter=[press(platform, 'sidebar-section-sec-launch', 38, 24)]),
        spec(platform, 'menu.surface', preset=preset, title='Sidebar surface menu',
             web=[*COLLAPSE_WEB, rightclick(tid('sidebar-scroll-surface'), 120, 500)],
             flutter=[*COLLAPSE_FLUTTER, press(platform, 'workspace-sidebar', 120, 500)]),
        spec(platform, 'menu.move-to-section', preset=custom, title='Row menu with the Move to section popup',
             web=[rightclick(row('shell-general')), click('text=Move to section')],
             flutter=[press(platform, 'sidebar-channel-shell-general'), tap('sidebar-menu-move-to-section')]),
    ]
# The shell cases already hold the channel row on both platforms and every other desktop variant:
# desktop only lacks the pinned row (Unpin).
SPECS = [s for s in SPECS if s['platform'] == 'mobile' or s['surface'] == 'menu.pinned-channel']


def build_cases():
    cases = []
    for s in SPECS:
        mobile = s['platform'] == 'mobile'
        region = MOBILE_HOME if mobile else RAIL
        for suffix, theme in THEMES.items():
            cid = f'components.row-menus.{s["platform"]}.{s["surface"]}.{suffix}'
            props = {'extCase': f'{s["platform"]}.{s["surface"]}', 'extKind': 'row-menus', 'parityTheme': theme,
                     'platform': s['platform'], 'surface': s['surface'], 'preset': s['preset'],
                     **({} if mobile else EXTRA)}
            cases.append({
                'id': cid,
                'title': f'{s["title"]} {s["platform"]} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'row-menus',
                'category': 'extension/row-menus',
                'suite': 'raft-flutter-extension',
                'viewport': MOBILE if mobile else DESKTOP,
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': {
                    'selector': tid(region),
                    'crop': 'element',
                    'contract': 'component-bounds',
                    'androidKey': region,
                    'interactions': s['web'],
                    'androidInteractions': s['flutter'],
                },
                'reactPathHint': HINT,
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_row_menus.dart '{s['platform']}.{s['surface']}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
    return cases


cases = build_cases()
path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.row-menus.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} row-menu cases appended ({len(manifest["cases"])} total)')
