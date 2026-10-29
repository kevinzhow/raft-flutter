#!/usr/bin/env python3
"""L1 FRAME cases: the app frame at phone / tablet / desktop widths (owner scope 2026-10-24).

Ids: components.frame.<platform>.<key>.<theme>   (platform = phone | tablet | desktop; 3 theme names each)
React:   tool/parity-ext/host/FrameCases.tsx (the real MainLayout on the case route, shell fixture data)
Flutter: apps/raft_flutter/test/parity/cases/ext_frame.dart (the real WorkspaceView, same fixtures)

Whole-window cases capture the window; the part cases (top bar, rail, sidebar, tab bar) crop a keyed rectangle so a
frame regression is scored on its own and does not hide behind page content. Web v1.21.23 geometry (from the DOM of
the pinned host, tool/parity-ext/run dom-dump): the yellow frame's top bar is TOP_H tall at 768 px and wider, the rail
is RAIL_W wide, the sidebar column is SIDEBAR_W.

Web components (packages/web/src/components): layout/MainLayout.tsx (MobileTabBar, panel layout), topbar/*,
layout/LeftRail.tsx, layout/Sidebar.tsx.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
PHONE = {'width': 390, 'height': 844, 'density': 3, 'touch': True}
TABLET = {'width': 820, 'height': 1180, 'density': 1}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
VIEWPORTS = {'phone': PHONE, 'tablet': TABLET, 'desktop': DESKTOP}
PREFIX = 'components.frame.'
FIXTURES = here / 'fixtures'
SRC = 'packages/web/src/components/'

# Web geometry (px) at width >= 768; filled from the DOM dump of the v1.21.23 host.
TOP_H = 48
RAIL_W = 56
SIDEBAR_W = 240
TAB_H = 52


def build_fixture():
    """fixtures/frame.json: the API answers the real MainLayout needs for the shell data (the Flutter provider reads
    fixtures/shell.json + screens.json directly; the React host fetches the same records over the API)."""
    shell = json.loads((FIXTURES / 'shell.json').read_text())
    screens = json.loads((FIXTURES / 'screens.json').read_text())
    records = {c['id']: c for c in shell['channels'] + shell['dms']}
    route_sets = {}
    for name in ('mobile', 'default'):
        preset = shell['presets'][name]
        sort = preset['sortModes']
        routes = {
            # the sidebar order and the unread snapshot the Flutter provider builds its workspace from (ext_shell.dart)
            'GET /servers/visual-server/sidebar-order': {
                'pinned': preset['pinned'], 'customSections': preset['customSections'],
                'sectionOrder': preset['sectionOrder'], 'sectionPlacements': preset['placements'],
                'channelSortMode': sort.get('channels', 'manual'), 'jointChannelSortMode': sort.get('joint', 'manual'),
                'dmSortMode': sort.get('dms', 'manual'), 'pinnedSortMode': sort.get('pinned', 'manual')},
            'GET /channels/unread': {'channels': {
                i: {'unreadCount': n, 'hasMention': i in preset['mentions'], 'hasAnyMention': i in preset['mentions']}
                for i, n in preset['unread'].items() if i != preset['selected']}},
            'GET /channels': [records[i] for i in preset['channels'] + preset['joint']],
            'GET /channels/dm': [records[i] for i in preset['dms']],
            **{f'GET /channels/{i}': records[i] for i in records},
        }
        route_sets[f'fr-{name}'] = routes
    route_sets['fr-channel'] = {
        **route_sets['fr-default'], **screens['routeSets']['scr-channel'],
        # The mounted task endpoint returns an object, not the old fallback array.
        f"GET /tasks/channel/{screens['scenes']['channel']['selected']}": {'tasks': []},
    }
    route_sets['fr-activity'] = {**route_sets['fr-mobile'], **screens['routeSets']['scr-activity']}
    doc = {'name': 'frame cases', 'scope': 'tool/parity-ext/build-frame-cases.py (generated; derived from shell.json and screens.json)',
           'routes': shell['routes'], 'routeSets': route_sets}
    (FIXTURES / 'frame.json').write_text(json.dumps(doc, indent=1) + '\n')


def whole(platform, key, title, scene, route, preset, hint, props=None, settle=None):
    return {'platform': platform, 'key': key, 'title': title, 'scene': scene, 'route': route, 'preset': preset,
            'hint': hint, 'crop': None, 'props': props or {}}


def part(platform, key, title, scene, route, preset, hint, rect, props=None):
    return {'platform': platform, 'key': key, 'title': title, 'scene': scene, 'route': route, 'preset': preset,
            'hint': hint, 'crop': rect, 'props': props or {}}


LAYOUT = SRC + 'layout/MainLayout.tsx'
SPECS = [
    # phone: Home tab = the sidebar as the home list + the in-flow tab bar
    whole('phone', 'home', 'Phone Home tab (sidebar list + tab bar)', 'home', '', 'mobile', LAYOUT + ' (mobileShowSidebarInline)'),
    part('phone', 'tabbar', 'Phone tab bar (Home active)', 'home', '', 'mobile', LAYOUT + ' (MobileTabBar)',
         (0, PHONE['height'] - TAB_H, PHONE['width'], TAB_H)),
    # tablet: >= 768 uses the desktop frame (top bar, rail, sidebar) in a narrower window
    whole('tablet', 'home', 'Tablet window, no conversation', 'home', '', 'mobile', LAYOUT),
    whole('tablet', 'channel', 'Tablet window, channel open', 'channel', '/channel/shell-design', 'default', LAYOUT,
          {'routeSet': 'fr-channel'}),
    part('tablet', 'topbar', 'Tablet top bar', 'home', '', 'mobile', SRC + 'topbar/AppTopBar.tsx', (0, 0, TABLET['width'], TOP_H)),
    # desktop
    whole('desktop', 'home', 'Desktop window, no conversation', 'home', '', 'mobile', LAYOUT),
    whole('desktop', 'channel', 'Desktop window, channel open', 'channel', '/channel/shell-design', 'default', LAYOUT,
          {'routeSet': 'fr-channel'}),
    part('desktop', 'topbar', 'Desktop top bar (workspace strip, search, actions)', 'home', '', 'mobile',
         SRC + 'topbar/AppTopBar.tsx', (0, 0, DESKTOP['width'], TOP_H)),
    part('desktop', 'rail', 'Desktop left rail', 'home', '', 'mobile', SRC + 'layout/LeftRail.tsx',
         (0, TOP_H, RAIL_W, DESKTOP['height'] - TOP_H)),
    part('desktop', 'sidebar', 'Desktop sidebar column', 'home', '', 'mobile', SRC + 'layout/Sidebar.tsx',
         (RAIL_W, TOP_H, SIDEBAR_W, DESKTOP['height'] - TOP_H)),
]


def build_cases():
    cases = []
    for s in SPECS:
        vp = VIEWPORTS[s['platform']]
        for suffix, theme in THEMES.items():
            props = {'extCase': f'{s["platform"]}.{s["key"]}', 'extKind': 'frame', 'parityTheme': theme,
                     'platform': 'mobile' if s['platform'] == 'phone' else 'desktop', 'frameWidth': s['platform'], 'scene': s['scene'], 'route': s['route'], 'preset': s['preset'],
                     'extFixture': 'frame', 'routeSet': f'fr-{s["preset"]}', **s['props']}
            capture = {'selector': '[data-visual-case]', 'crop': 'element', 'contract': 'component-bounds'}
            if s['crop']:
                x, y, w, h = s['crop']
                props.update({'cx': x, 'cy': y, 'cw': w, 'ch': h})
                capture = {'selector': '[data-testid="frame-crop"]', 'crop': 'element', 'contract': 'component-bounds',
                           'androidKey': 'frame-crop'}
            capture['interactions'] = [{'type': 'wait', 'ms': 1200}]
            cases.append({
                'id': f'{PREFIX}{s["platform"]}.{s["key"]}.{suffix}',
                'title': f'{s["title"]} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'frame',
                'category': 'extension/frame',
                'suite': 'raft-flutter-extension',
                'viewport': vp,
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': capture,
                'reactPathHint': s['hint'],
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_frame.dart '{s['platform']}.{s['key']}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
    return cases


if __name__ == '__main__':
    build_fixture()
    cases = build_cases()
    path = manifest_path()
    manifest = json.loads(path.read_text())
    manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
    print(f'{len(cases)} frame cases appended ({len(manifest["cases"])} total)')
