#!/usr/bin/env python3
"""Control STATES of the app frame and the key pages (owner scope 2026-10-24, levels L1 / L2).

Ids: components.states.<platform>.<control>.<state>.<theme>   (platform = desktop | phone; 3 theme names each)
React:   tool/parity-ext/host/FrameCases.tsx (the real MainLayout on a frame scene) + Playwright interactions
Flutter: apps/raft_flutter/test/parity/cases/ext_frame.dart (the real WorkspaceView on the same scene) + the
         `androidInteractions` of parity_harness.dart (hover / hold / focus / tap by ValueKey)

One case = one control in one state, cropped to the control plus PAD px (`mark` step: a transparent marker over the control's
box, the capture selector / androidKey is `states-crop`). The states a control can show on the Web:

  default   resting; selected  the current item (rail tab, sidebar row, conversation tab, phone tab);
  hover     pointer over it (desktop only; a touch host has none);
  pressed   pointer down, not released (`hold`);
  focus     keyboard focus ring (`focus`: locator.focus() on the Web, FocusNode.requestFocus under the traditional highlight);
  disabled  composer submit with an empty draft;  checked  the As Task toggle after a tap.

The coverage map (tool/parity-ext/coverage_map.py) reads CONTROLS below for its "states" column: which states the Web has per
control and which are captured. Web-only controls (the top bar search / bell: Flutter has no top bar yet) carry flutter=None and
are listed as not capturable.
"""
ORDER = 2000  # after every builder that creates the base cases the settings states clone

import copy
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
PREFIX = 'components.states.'
PAD = 6
MACHINERY_REV = '1'  # bump when the Web `hold` / `focus` / `mark` steps (run: SPEC_STATES_PATCHES) change
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
PHONE = {'width': 390, 'height': 844, 'density': 3, 'touch': True}

# scene -> (platform, viewport, frame props)
SCENES = {
    'channel': ('desktop', DESKTOP, {'scene': 'channel', 'route': '/channel/shell-design', 'preset': 'default', 'routeSet': 'fr-channel'}),
    'activity': ('desktop', DESKTOP, {'scene': 'activity', 'route': '/activity', 'preset': 'mobile', 'routeSet': 'fr-activity'}),
    'phone-home': ('phone', PHONE, {'scene': 'home', 'route': '', 'preset': 'mobile', 'routeSet': 'fr-mobile'}),
}
DESKTOP_STATES = ('default', 'hover', 'pressed', 'focus')
SRC = 'packages/web/src/components/'
SIDEBAR_CHANNELS = '[data-testid="sidebar-section-block-channels"]'
# control id, scene, level, Web locator, Flutter ValueKey (None: no Flutter surface), states, extra, hint
CONTROLS = [
    ('rail-tab', 'channel', 'frame', '[data-testid="left-rail-tab-activity"]', 'rail-activity', DESKTOP_STATES, {}, 'layout/LeftRail.tsx'),
    ('rail-tab-selected', 'channel', 'frame', '[data-testid="left-rail-tab-chat"]', 'rail-chat', ('selected', 'hover', 'focus'), {}, 'layout/LeftRail.tsx'),
    ('rail-settings', 'channel', 'frame', '[data-testid="left-rail-settings"]', 'rail-settings', DESKTOP_STATES, {}, 'layout/LeftRail.tsx'),
    ('sidebar-row', 'channel', 'frame', f'{SIDEBAR_CHANNELS} [data-slot="sidebar-item"] >> nth=2', 'sidebar-channel-shell-leadership', DESKTOP_STATES, {}, 'layout/Sidebar.tsx'),
    ('sidebar-row-selected', 'channel', 'frame', f'{SIDEBAR_CHANNELS} [data-slot="sidebar-item"] >> nth=1', 'sidebar-channel-shell-design', ('selected', 'hover', 'focus'), {}, 'layout/Sidebar.tsx'),
    ('sidebar-row-unread', 'channel', 'frame', f'{SIDEBAR_CHANNELS} [data-slot="sidebar-item"] >> nth=0', 'sidebar-channel-shell-general', ('default', 'hover', 'pressed'), {}, 'layout/Sidebar.tsx'),
    ('sidebar-sort', 'channel', 'frame', f'{SIDEBAR_CHANNELS} [data-testid="sidebar-sort-menu-button"]', 'sidebar-sort-system:channels', DESKTOP_STATES, {}, 'layout/Sidebar.tsx'),
    ('sidebar-section-toggle', 'channel', 'frame', '[data-testid="sidebar-section-toggle-channels"]', 'sidebar-disclosure-system:channels', ('default', 'hover', 'focus'), {}, 'layout/Sidebar.tsx'),
    ('sidebar-saved', 'channel', 'frame', '[data-testid="sidebar-saved-entry"]', 'nav-saved', ('default', 'hover', 'focus'), {}, 'layout/Sidebar.tsx'),
    ('header-search', 'channel', 'frame', '[data-testid="channel-topbar-search"]', 'channel-topbar-search', DESKTOP_STATES, {}, 'message/ChatPanel.tsx'),
    ('header-overflow', 'channel', 'frame', '[data-testid="channel-overflow-trigger"]', 'channel-overflow-trigger', DESKTOP_STATES, {}, 'message/ChatPanel.tsx'),
    ('conversation-tab', 'channel', 'frame', '[data-testid="panel-tab-tasks"]', 'panel-tab-tasks', DESKTOP_STATES, {}, 'message/ChatPanel.tsx'),
    ('conversation-tab-selected', 'channel', 'frame', '[data-testid="panel-tab-chat"]', 'panel-tab-chat', ('selected', 'hover', 'focus'), {}, 'message/ChatPanel.tsx'),
    ('topbar-search', 'channel', 'frame', '[data-testid="app-top-bar-search"]', None, DESKTOP_STATES, {}, 'topbar/AppTopBar.tsx'),
    ('topbar-bell', 'channel', 'frame', '[data-testid="notification-trigger-top-bar"]', None, DESKTOP_STATES, {}, 'topbar/TopBarGlobalActions.tsx'),
    ('topbar-workspace', 'channel', 'frame', '[data-testid="desktop-workspace-trigger"]', None, ('default', 'hover', 'focus'), {}, 'topbar/AppTopBar.tsx'),
    ('composer-submit', 'channel', 'page', '[data-testid="composer-as-task-toggle"] ~ button', 'composer-submit',
     ('disabled', 'enabled', 'hover', 'pressed', 'focus'), {'prefill': 'Looks good to me'}, 'message/MessageInput.tsx'),
    ('composer-as-task', 'channel', 'page', '[data-testid="composer-as-task-toggle"]', 'composer-as-task-toggle', ('default', 'hover', 'focus', 'checked'), {}, 'message/MessageInput.tsx'),
    # Activity page (ThreadsInbox rows; the Done check appears on row hover)
    ('activity-row', 'activity', 'page', '[data-testid="inbox-row"] >> nth=1', 'activity-channel-channel-android', DESKTOP_STATES, {}, 'thread/ThreadsInbox.tsx'),
    # Flutter: RaftConversationCard builds the Done action only after a hover its RaftHoverRegion accepts; the harness mouse
    # hover leaves it unbuilt (checked 2026-10-24), so there is no Flutter capture yet (flutter=None -> not covered).
    ('activity-row-done', 'activity', 'page', '[data-testid="inbox-row-done"] >> nth=1', None,
     ('revealed', 'hover', 'pressed', 'focus'), {'reveal': ('[data-testid="inbox-row"] >> nth=1', 'activity-channel-channel-android')}, 'thread/ThreadsInbox.tsx'),
    ('phone-tab', 'phone-home', 'frame', '[data-slot="mobile-nav-item"] >> nth=1', 'mobile-tab-tasks', ('default', 'pressed'), {}, 'layout/MainLayout.tsx (MobileTabBar)'),
    ('phone-tab-selected', 'phone-home', 'frame', '[data-slot="mobile-nav-item"] >> nth=0', 'mobile-tab-home', ('selected', 'pressed'), {}, 'layout/MainLayout.tsx (MobileTabBar)'),
    ('phone-sidebar-row', 'phone-home', 'frame', '[data-testid="sidebar-section-block-channels"] [data-slot="sidebar-item"] >> nth=2', 'sidebar-channel-shell-leadership', ('default', 'pressed'), {}, 'layout/Sidebar.tsx'),
]


def flutter_target(flutter):
    """A ValueKey string, or {'key', 'in'} (a keyed control inside a keyed row) -> the interaction's target fields."""
    if flutter is None:
        return {}
    return {'finder': flutter} if isinstance(flutter, dict) else {'key': flutter}


def steps(state, web, flutter, extra):
    """-> (web interactions, flutter interactions) putting the control into `state`, then marking it."""
    prefill = extra.get('prefill')
    if prefill and state != 'disabled':
        # a draft in the composer enables Send (same typing steps as build-composer-states.py)
        pre_w = [{'type': 'click', 'target': 'textarea'}, {'type': 'fill', 'target': 'textarea', 'value': prefill}, {'type': 'wait', 'ms': 400}]
        pre_f = [{'type': 'tap', 'key': 'composer-editor-slot', 'scroll': False}, {'type': 'enterText', 'key': 'composer-editor-slot', 'text': prefill},
                 {'type': 'wait', 'ms': 400}]
        web_steps, flutter_steps = steps(state, web, flutter, {k: v for k, v in extra.items() if k != 'prefill'})
        return pre_w + web_steps, pre_f + flutter_steps
    wt = {'target': web}
    ft = flutter_target(flutter)
    mark_w, mark_f = {'type': 'mark', 'target': web, 'pad': PAD}, {'type': 'mark', 'pad': PAD, **ft}
    reveal = extra.get('reveal')
    if reveal:  # the control only exists on screen while its row is hovered
        reveal_w, reveal_f = {'type': 'hover', 'target': reveal[0]}, {'type': 'hover', 'key': reveal[1]}
        if state == 'revealed':
            return [reveal_w, mark_w], [reveal_f, mark_f]
        if state == 'hover':
            return [reveal_w, {'type': 'hover', **wt}, mark_w], [reveal_f, {'type': 'hover', **ft}, mark_f]
        if state == 'pressed':
            return [reveal_w, {'type': 'hover', **wt}, {'type': 'hold', **wt}, mark_w], [reveal_f, {'type': 'hold', **ft}, mark_f]
    if state in ('default', 'selected', 'disabled', 'enabled'):
        return [mark_w], [mark_f]
    if state == 'hover':
        return [{'type': 'hover', **wt}, mark_w], [{'type': 'hover', **ft}, mark_f]
    if state == 'pressed':
        return [{'type': 'hover', **wt}, {'type': 'hold', **wt}, mark_w], [{'type': 'hold', **ft}, mark_f]
    if state == 'focus':
        return [{'type': 'focus', **wt}, mark_w], [{'type': 'focus', **ft}, mark_f]
    if state == 'checked':
        # the tap moves the pointer onto the control: park it by hovering the same control in both, then focus-free mark
        # This frame control is already visible. ensureVisible would scroll its
        # ancestor PageViews and switch away from the conversation after the tap.
        return [{'type': 'click', **wt}, {'type': 'hover', **wt}, mark_w], [{'type': 'tap', 'mouse': True, 'scroll': False, **ft}, {'type': 'hover', **ft}, mark_f]
    if state == 'toggled':
        return [{'type': 'click', **wt}, mark_w], [{'type': 'tap', 'mouse': True, **ft}, mark_f]
    raise ValueError(state)


def build_cases():
    cases = []
    for control, scene, level, web, flutter, states, extra, hint in CONTROLS:
        platform, viewport, frame_props = SCENES[scene]
        for state in states:
            web_steps, flutter_steps = steps(state, web, flutter, extra)
            for suffix, theme in THEMES.items():
                props = {'extCase': f'{platform}.{control}.{state}', 'extKind': 'states', 'parityTheme': theme,
                         'platform': 'mobile' if platform == 'phone' else 'desktop', 'frameWidth': platform,
                         'extFixture': 'frame', 'machineryRev': MACHINERY_REV, 'control': control, 'state': state, **frame_props}
                cases.append({
                    'id': f'{PREFIX}{platform}.{control}.{state}.{suffix}',
                    'title': f'{control} control, {state} state, {platform} ({theme})',
                    'captureType': 'component-fixture',
                    'surface': 'states',
                    'category': 'extension/states',
                    'suite': 'raft-flutter-extension',
                    'viewport': viewport,
                    'theme': theme,
                    'locale': 'en',
                    'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                    'capture': {'selector': '[data-testid="states-crop"]', 'crop': 'element', 'contract': 'component-bounds',
                                'androidKey': 'states-crop', 'interactions': [{'type': 'wait', 'ms': 1200}, *web_steps],
                                'androidInteractions': [{'type': 'wait', 'ms': 1500}, *flutter_steps]},
                    'reactPathHint': SRC + hint,
                    'androidCaseHint': "apps/raft_flutter/test/parity/cases/ext_frame.dart (states)",
                    'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
                    'flutterSurface': flutter is not None,
                })
    return cases


# Controls of settings pages: clones of an existing ext-settings case (same host and Flutter builder, new id and steps).
# base case suffix (without theme), clone area, control, Web locator, Flutter ValueKey, states
SETTINGS_CONTROLS = [
    ('components.ext-settings.appearance.page', 'switch', '[data-slot="switch"] >> nth=0', 'appearance-live-activity',
     ('default', 'hover', 'pressed', 'focus', 'toggled'), 'settings/SettingsPanel.tsx (AppearanceSection)'),
    ('components.ext-settings.appearance.page', 'switch-mid', '[data-slot="switch"] >> nth=1', 'appearance-agent-model',
     ('default', 'hover', 'focus'), 'settings/SettingsPanel.tsx (AppearanceSection)'),
]


def settings_clones(manifest_cases):
    by_id = {c['id']: c for c in manifest_cases}
    clones, keys = [], []
    for base, control, web, flutter, states, hint in SETTINGS_CONTROLS:
        for state in states:
            web_steps, flutter_steps = steps(state, web, flutter, {})
            area = base.rsplit('.', 1)[0]  # components.ext-settings.appearance
            for suffix, theme in THEMES.items():
                src = by_id.get(f'{base}.{suffix}')
                if src is None:
                    continue
                c = copy.deepcopy(src)
                c['id'] = f'{area}.states-{control}.{state}.{suffix}'
                c['title'] = f'{src["title"]}: {control} control, {state} state'
                c['variants'][0]['props'].update({'machineryRev': MACHINERY_REV, 'control': control, 'state': state})
                c['capture'] = {'selector': '[data-testid="states-crop"]', 'crop': 'element', 'contract': 'component-bounds',
                                'androidKey': 'states-crop',
                                'interactions': [*(src['capture'].get('interactions') or []), {'type': 'wait', 'ms': 600}, *web_steps],
                                'androidInteractions': [*(src['capture'].get('androidInteractions') or []), {'type': 'wait', 'ms': 600}, *flutter_steps]}
                c['androidCaseHint'] = src.get('androidCaseHint', '') + ' (control state)'
                clones.append(c)
            keys.append((f'{area}.states-{control}.{state}', f'{base}'))
    return clones, keys


def write_keys(cases, settings_keys=()):
    ids = sorted({c['id'][len(PREFIX):].rsplit('.', 1)[0] for c in cases if c['flutterSurface']})
    body = ',\n'.join(f"  '{i}'" for i in ids)
    out = here.parents[1] / 'apps/raft_flutter/test/parity/cases/ext_frame_keys.g.dart'
    alias = ''.join(f"  (\n    '{new}',\n    '{base}',\n  ),\n" for new, base in settings_keys)
    out.write_text('// GENERATED by tool/parity-ext/build-states-cases.py; do not edit.\n'
                   f'const extStatesKeys = <String>[\n{body},\n];\n\n'
                   '/// (new id without theme, base ext-settings id without theme): clones of an existing case.\n'
                   f'const extStatesSettingsAliases = <(String, String)>[\n{alias}];\n')


if __name__ == '__main__':
    cases = build_cases()
    path = manifest_path()
    manifest = json.loads(path.read_text())
    clones, settings_keys = settings_clones(manifest['cases'])
    write_keys(cases, settings_keys)
    for c in cases:
        c.pop('flutterSurface')
    manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX) and '.states-' not in c['id']] + cases + clones
    cases = cases + clones
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
    print(f'{len(cases)} control-state cases appended ({len(manifest["cases"])} total)')
