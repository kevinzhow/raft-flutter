#!/usr/bin/env python3
"""Mounted phone tab roots and the server tab on the shared frame fixture."""
import json
from pathlib import Path

from builders import manifest_path, raft_source

HERE = Path(__file__).resolve().parent
FIXTURE = 'mobile-tabbar'
PREFIX = 'components.frame.phone.tabbar-'
THEMES = {'brutal': 'brutal-light', 'elegant-dark': 'elegant-dark'}
VIEWPORT = {'width': 390, 'height': 844, 'density': 2, 'touch': True}
FLAG = 'workspace_artifacts_v0'
BAR = '[data-testid="mobile-tab-bar"]'
POPOVER = '[data-testid="mobile-server-tab-popover"]'
ARTIFACTS = '[data-testid="mobile-server-tab-artifacts"]'


def tab(label):
    return f'{BAR} [data-slot="mobile-nav-item"][aria-label="{label}"]'


def build_case(key, theme_id, theme, ready, crop, steps, *, artifacts=False):
    x, y, width, height = crop
    return {
        'id': f'{PREFIX}{key}.{theme_id}',
        'title': f'Phone tab chrome: {key} ({theme})',
        'captureType': 'component-fixture',
        'surface': 'frame',
        'category': 'extension/frame',
        'suite': 'raft-flutter-extension',
        'viewport': VIEWPORT,
        'theme': theme,
        'locale': 'en',
        'variants': [{'id': 'default', 'name': 'Default', 'props': {
            'extKind': 'frame', 'extCase': f'phone.tabbar-{key}',
            'extFixture': FIXTURE, 'routeSet': f'fr-tabbar-{"on" if artifacts else "off"}',
            'parityTheme': theme, 'platform': 'mobile', 'scene': 'home', 'preset': 'mobile',
            'cx': x, 'cy': y, 'cw': width, 'ch': height,
        }}],
        'capture': {
            'selector': f'body{ready} [data-testid="frame-crop"][data-tabbar-flags-ready]',
            'crop': 'element', 'contract': 'component-bounds', 'androidKey': 'frame-crop',
            'interactions': [{'type': 'click', 'target': web} for web, _ in steps],
            'androidInteractions': [
                {'type': 'tap', 'finder': flutter, 'scroll': False} for _, flutter in steps
            ],
        },
        'reactPathHint': 'packages/web/src/components/layout/MainLayout.tsx (MobileTabBar and MobileServerTab)',
        'androidCaseHint': "apps/raft_flutter/test/parity/cases/ext_frame.dart 'phone.tabbar'",
        'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
    }


def build_cases():
    for theme_id, theme in THEMES.items():
        for label in ('Home', 'Activity', 'Tasks', 'Search'):
            name = label.lower()
            selected = f':has({tab(label)}[data-selected="true"])'
            steps = [] if name == 'home' else [(tab(label), {'key': f'mobile-tab-{name}'})]
            yield build_case(f'bar-{name}', theme_id, theme, selected, (0, 784, 390, 60), steps)
            yield build_case(f'header-{name}', theme_id, theme, f'{selected}:has([data-tab-root-bar])',
                             (0, 0, 390, 56), steps)
        open_server = [('[data-testid="mobile-tab-server"]', {'key': 'mobile-tab-server'})]
        for state, enabled in (('off', False), ('on', True)):
            entry = f':has({ARTIFACTS})' if enabled else f':not(:has({ARTIFACTS}))'
            yield build_case(f'popover-{state}', theme_id, theme, f':has({POPOVER}){entry}',
                             (0, 288, 390, 556), open_server, artifacts=enabled)
        yield build_case('artifacts-return', theme_id, theme,
                         f':has({tab("Tasks")}[data-selected="true"]):not(:has({POPOVER}))',
                         (0, 784, 390, 60), [
                             (tab('Tasks'), {'key': 'mobile-tab-tasks'}),
                             *open_server,
                             (ARTIFACTS, {'key': 'mobile-server-tab-artifacts'}),
                             ('[data-testid="artifacts-dashboard-header"] button[aria-label="Back"]',
                              {'tooltip': 'Back', 'in': 'artifacts-dashboard'}),
                         ], artifacts=True)


def main():
    # build-frame-cases.py runs first alphabetically. Keep the existing frame
    # fixture inputs and add only route sets specific to this mounted flow.
    directory = HERE / 'fixtures'
    frame = json.loads((directory / 'frame.json').read_text())
    shared = raft_source() / 'packages' / 'visual-testing' / 'shared'
    tasks = json.loads((shared / 'tasksFixture.json').read_text())['tasks']
    (directory / f'{FIXTURE}.json').write_text(json.dumps({
        'name': 'Phone tab bar on the mounted workspace frame',
        'routes': {
            **frame['routes'],
            **frame['routeSets']['fr-activity'],
            'GET /artifacts/dashboard/all': {'counts': {'total': 0, 'filtered': 0, 'relevant': 0}, 'rows': []},
            'GET /tasks/server': {'tasks': tasks},
        },
        'routeSets': {
            f'fr-tabbar-{state}': {
                'POST /feature-flags/evaluate': {'evaluations': [{'key': FLAG, 'enabled': enabled}]},
            }
            for state, enabled in (('off', False), ('on', True))
        },
    }, indent=1) + '\n')
    path = manifest_path()
    manifest = json.loads(path.read_text())
    manifest['cases'] = [
        case for case in manifest['cases'] if not case['id'].startswith(PREFIX)
    ] + list(build_cases())
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    main()
