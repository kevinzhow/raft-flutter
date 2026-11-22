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
            'GET /servers': shell['servers'],
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
    route_sets['fr-bell'] = {'GET /servers/visual-server/machines': {'machines': []}}
    sidebar_order = 'GET /servers/visual-server/sidebar-order'
    avatar_order = {
        **route_sets['fr-mobile'][sidebar_order],
        'pinned': [],
        'sectionOrder': ['system:dms', 'system:pinned', 'system:joint', 'system:channels'],
    }
    route_sets['fr-avatar-reset'] = {
        **route_sets['fr-mobile'],
        sidebar_order: avatar_order,
        'GET /agents': [],
    }
    route_sets['fr-topbar-drag'] = {
        **route_sets['fr-mobile'],
        'GET /servers': shell['servers'],
    }
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
DS4 = [
    ('phone', 'bell-open', 'notification-trigger-mobile', 'mobile-home-notifications', []),
    ('desktop', 'bell-open', 'notification-trigger-top-bar', 'topbar-notifications', []),
    ('desktop', 'tasks-header', 'channel-tasks-panel-header', 'channel-side-card-tasks-header',
     [('channel-tasks-toggle', 'channel-tasks-toggle'), ('channel-files-toggle', 'channel-files-toggle')]),
    ('desktop', 'files-folded-header', 'channel-files-card-header', 'channel-side-card-files-header',
     [('channel-tasks-toggle', 'channel-tasks-toggle'), ('channel-files-toggle', 'channel-files-toggle'),
      ('channel-files-card-collapse', 'channel-side-card-files-collapse')]),
    ('desktop', 'tasks-expanded-header', 'channel-tasks-panel-header', 'channel-side-card-tasks-header',
     [('channel-tasks-toggle', 'channel-tasks-toggle'), ('channel-files-toggle', 'channel-files-toggle'),
      ('channel-tasks-panel-expand', 'channel-side-card-tasks-expand')]),
]
SPECS = [
    # phone: Home tab = the sidebar as the home list + the in-flow tab bar
    whole('phone', 'home', 'Phone Home tab (sidebar list + tab bar)', 'home', '', 'mobile', LAYOUT + ' (mobileShowSidebarInline)'),
    part('phone', 'tabbar', 'Phone tab bar (Home active)', 'home', '', 'mobile', LAYOUT + ' (MobileTabBar)',
         (0, PHONE['height'] - TAB_H, PHONE['width'], TAB_H)),
    whole('phone', 'agent-avatar-reset', 'Phone agent DM after avatar reset', 'home', '', 'mobile',
          SRC + 'layout/dmPeerAvatar.ts', {'avatarReset': True, 'routeSet': 'fr-avatar-reset'}),
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
    part('desktop', 'topbar-drag', 'Desktop top bar during workspace reorder', 'home', '', 'mobile',
         SRC + 'topbar/WorkspaceStrip.tsx', (0, 0, DESKTOP['width'], TOP_H), {'routeSet': 'fr-topbar-drag'}),
    whole('desktop', 'agent-avatar-reset', 'Desktop agent DM after avatar reset', 'home', '', 'mobile',
          SRC + 'layout/dmPeerAvatar.ts', {'avatarReset': True, 'routeSet': 'fr-avatar-reset'}),
    part('desktop', 'rail', 'Desktop left rail', 'home', '', 'mobile', SRC + 'layout/LeftRail.tsx',
         (0, TOP_H, RAIL_W, DESKTOP['height'] - TOP_H)),
    part('desktop', 'sidebar', 'Desktop sidebar column', 'home', '', 'mobile', SRC + 'layout/Sidebar.tsx',
         (RAIL_W, TOP_H, SIDEBAR_W, DESKTOP['height'] - TOP_H)),
    *[
        whole(platform, key, f'{platform} {key}', 'channel' if clicks else 'home',
              '/channel/shell-design' if clicks else '', 'default' if clicks else 'mobile',
              SRC + ('task/ChannelSideCard.tsx' if clicks else 'layout/NotificationTrigger.tsx'),
              {'routeSet': 'fr-channel', 'sidePanels': True} if clicks else {'routeSet': 'fr-bell'})
        for platform, key, _, _, clicks in DS4
    ],
]


def build_cases():
    cases = []
    for s in SPECS:
        vp = VIEWPORTS[s['platform']]
        if s['platform'] == 'desktop' and s['key'] in ('topbar-drag', 'agent-avatar-reset'):
            vp = {**vp, 'height': 900}
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
            if s['key'] == 'agent-avatar-reset':
                capture.update({
                    'selector': '[data-sidebar-channel-id="shell-dm-cindy"]',
                    'androidKey': 'sidebar-channel-shell-dm-cindy',
                    'androidInteractions': [{'type': 'wait', 'ms': 300}],
                })
            if s['key'] == 'topbar-drag':
                strip = '[data-testid="desktop-workspace-strip"]'
                origin = f'{strip} [data-workspace-id="shell-server-acme"]'
                destination = f'{strip} [data-workspace-id="shell-server-side"]'
                capture['interactions'] += [
                    {'type': 'hold', 'target': origin},
                    {'type': 'hover', 'target': destination},
                    {'type': 'reveal', 'target': f'{origin}[data-drag-origin]'},
                ]
            ds4 = next((item for item in DS4 if item[:2] == (s['platform'], s['key'])), None)
            if ds4:
                _, key, web, flutter, clicks = ds4
                bell = key == 'bell-open'
                if bell:
                    clicks = [(web, flutter)]
                selector = lambda test_id: f'[data-testid="{test_id}"]'
                capture['interactions'] += [
                    step for web_key, _ in clicks
                    for step in [{'type': 'click', 'target': selector(web_key)}, {'type': 'wait', 'ms': 200}]
                ]
                capture['androidInteractions'] = [
                    step for _, flutter_key in clicks
                    for step in [{'type': 'tap', 'key': flutter_key, 'mouse': s['platform'] == 'desktop', 'scroll': False},
                                 {'type': 'wait', 'ms': 200}]
                ]
                if bell:
                    capture['interactions'].append(
                        {'type': 'reveal', 'target': selector(web) + '[data-state="open"][data-has-unread="false"]'})
                else:
                    if key == 'files-folded-header':
                        capture['interactions'].append(
                            {'type': 'reveal', 'target': selector('channel-files-card') + '[data-collapsed="true"]'})
                    capture['interactions'].append(
                        {'type': 'reveal', 'target': selector(web.removesuffix('-header') + '-expand')
                         + ('[aria-pressed="true"]' if key == 'tasks-expanded-header' else '')})
                    capture['interactions'].append({'type': 'hover', 'target': selector(web)})
                    capture['androidInteractions'].append({'type': 'hover', 'key': flutter})
                capture.update({'selector': selector(web), 'androidKey': flutter})
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
