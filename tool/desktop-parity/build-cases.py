#!/usr/bin/env python3
"""Generate docs/desktop-cases.json (sharedCases.json schema, ids screens.desktop.*).

Derivation (not hand-picked): every destination of the Web desktop shell at
raft-source 26f77ef -
  * LeftRail.tsx:573-762 rail tabs: search, chat, activity, tasks, members,
    computers, notification bell, settings;
  * MainLayout.tsx:2439-2464 nested routes: channel/:id, dm/:id, saved, tasks,
    search, activity, members, agent/:id, human/:id, computers,
    computer/:id, settings/:tab;
  * ChatPanel tabs (Chat/Tasks/Files) and the ?thread= right column;
  * settingsNavigation.ts:25-75 personal + workspace tabs;
plus the interaction states requested for desktop parity (hover sidebar row,
selected row, rail hover tooltip, message hover toolbar, reaction picker,
composer focus, channel loading).

Each case carries, in variants[0].props:
  route   - Web URL the real app is opened at
  web     - Playwright ready/steps (tool/desktop-parity/capture-web.mjs)
  flutter - flow id implemented in integration_test/desktop_screens_test.dart
  hold    - API calls that never answer (loading-state cases), both sides
"""
import json
import pathlib

repo = pathlib.Path(__file__).resolve().parents[2]
THEMES = ['brutal', 'elegant-light', 'elegant-dark']
S = '/s/visual'

CHAT_READY = [{'action': 'waitFor', 'selector': '#message-msg-agent-reply'}]
MSG = '#message-msg-agent-reply'


def case(key, title, surface, route, flow, hint, ready=None, steps=None, hold=None, notes=None, sizes=((1280, 800),)):
    return dict(key=key, title=title, surface=surface, route=route, flow=flow, hint=hint,
                ready=ready or [], steps=steps or [], hold=hold or [], notes=notes, sizes=sizes)


BOTH = ((1280, 800), (1440, 900))
routes = [
    # ---- chat (rail: Chat) ------------------------------------------------
    case('chat.channel', 'Channel chat (selected sidebar row)', 'chat', f'{S}/channel/channel-design', 'channel',
         'packages/web/src/components/message/ChatPanel.tsx', CHAT_READY, sizes=BOTH),
    case('chat.dm', 'Direct message with agent', 'chat', f'{S}/dm/dm-agent-cindy-artin', 'dm',
         'packages/web/src/components/message/ChatPanel.tsx',
         [{'action': 'waitFor', 'selector': '#message-msg-visual-activity-dm'}]),
    case('chat.thread-open', 'Channel with thread side column open', 'thread', f'{S}/channel/channel-design', 'thread-open',
         'packages/web/src/components/layout/MainLayout.tsx (SideThreadColumn)', CHAT_READY,
         [{'action': 'click', 'selector': '#message-msg-agent-reply [data-slot="message-embed"]'},
          {'action': 'waitFor', 'testId': 'thread-side-column'},
          {'action': 'waitFor', 'selector': '[data-testid="thread-side-column"] #message-public-thread-reply-2'}], sizes=BOTH),
    case('chat.channel-tasks-tab', 'Channel Tasks tab', 'chat', f'{S}/channel/channel-design', 'channel-tasks-tab',
         'packages/web/src/components/message/ChatPanel.tsx', CHAT_READY,
         [{'action': 'click', 'role': 'tab', 'name': 'Tasks'}, {'action': 'wait', 'ms': 600}]),
    case('chat.channel-files-tab', 'Channel Files tab', 'chat', f'{S}/channel/channel-design', 'channel-files-tab',
         'packages/web/src/components/message/ChatPanel.tsx', CHAT_READY,
         [{'action': 'click', 'role': 'tab', 'name': 'Files'}, {'action': 'waitFor', 'text': 'Android visual notes.pdf'}]),
    case('chat.saved', 'Saved (sidebar Saved row)', 'saved', f'{S}/saved', 'saved',
         'packages/web/src/components/saved/SavedPanel.tsx',
         [{'action': 'waitFor', 'text': 'Publish preflight is green'}]),
    # ---- tasks ----------------------------------------------------------
    case('tasks.board', 'Tasks board (rail: Tasks)', 'tasks', f'{S}/tasks', 'tasks-board',
         'packages/web/src/components/task/TasksPanel.tsx',
         [{'action': 'waitFor', 'text': 'Align the tabbar capture crops'}], sizes=BOTH),
    case('tasks.list', 'Tasks list layout', 'tasks', f'{S}/tasks', 'tasks-list',
         'packages/web/src/components/task/TasksPanel.tsx',
         [{'action': 'waitFor', 'text': 'Align the tabbar capture crops'}],
         [{'action': 'click', 'testId': 'channel-task-view-list'}, {'action': 'wait', 'ms': 600}]),
    # ---- search ---------------------------------------------------------
    case('search.empty', 'Search home (rail: Search)', 'search', f'{S}/search', 'search-empty',
         'packages/web/src/components/search/MessageSearchPage.tsx',
         [{'action': 'waitFor', 'text': 'Search everything'}]),
    case('search.results', 'Search results for "visual"', 'search', f'{S}/search', 'search-results',
         'packages/web/src/components/search/MessageSearchPage.tsx',
         [{'action': 'waitFor', 'text': 'Search everything'}],
         [{'action': 'type', 'selector': 'input[type="search"], input[placeholder^="Search"]', 'value': 'visual'},
          {'action': 'wait', 'ms': 900}]),
    # ---- activity -------------------------------------------------------
    case('activity.inbox', 'Activity inbox (rail: Activity)', 'activity', f'{S}/activity', 'activity',
         'packages/web/src/components/thread/ThreadsInbox.tsx',
         [{'action': 'waitFor', 'text': 'android-artifacts'}]),
    # ---- members --------------------------------------------------------
    case('members.index', 'Members directory (rail: Members)', 'members', f'{S}/members', 'members',
         'packages/web/src/components/layout/Sidebar.tsx (members mode)',
         [{'action': 'waitFor', 'text': 'Product UX Designer'}]),
    case('members.agent', 'Agent detail: Cindy', 'members', f'{S}/agent/agent-cindy', 'members-agent',
         'packages/web/src/components/agent/AgentDetailPanel.tsx',
         [{'action': 'waitFor', 'text': 'Keeps visual testing release notes aligned.'}, {'action': 'wait', 'ms': 600}]),
    case('members.human', 'Human detail: Designer', 'members', f'{S}/human/visual-human-designer', 'members-human',
         'packages/web/src/components/layout/MainLayout.tsx (HumanDetailPanel)',
         [{'action': 'waitFor', 'text': 'Designer'}, {'action': 'wait', 'ms': 600}]),
    # ---- computers ------------------------------------------------------
    case('computers.index', 'Computers list (rail: Computers)', 'computers', f'{S}/computers', 'computers',
         'packages/web/src/components/layout/Sidebar.tsx (computers mode)',
         [{'action': 'waitFor', 'text': 'Studio Test Rig'}]),
    case('computers.detail', 'Computer detail', 'computers', f'{S}/computer/computer-mbp', 'computers-detail',
         'packages/web/src/components/machine/MachineDetailPanel.tsx',
         [{'action': 'waitFor', 'text': 'Studio Test Rig'}, {'action': 'wait', 'ms': 600}]),
    # ---- settings (rail: Settings) ----------------------------------------
    case('settings.account', 'Settings: Account', 'settings', f'{S}/settings/account', 'settings:account',
         'packages/web/src/components/settings/SettingsPanel.tsx',
         [{'action': 'waitFor', 'text': 'Display Name'}], sizes=BOTH),
    case('settings.language', 'Settings: Language & Region', 'settings', f'{S}/settings/language-region', 'settings:language',
         'packages/web/src/components/settings/SettingsPanel.tsx', [{'action': 'wait', 'ms': 800}]),
    case('settings.appearance', 'Settings: Appearance', 'settings', f'{S}/settings/appearance', 'settings:appearance',
         'packages/web/src/components/settings/SettingsPanel.tsx', [{'action': 'wait', 'ms': 800}]),
    case('settings.notifications', 'Settings: Notifications', 'settings', f'{S}/settings/notifications', 'settings:notifications',
         'packages/web/src/components/settings/SettingsPanel.tsx', [{'action': 'wait', 'ms': 800}]),
    case('settings.server', 'Settings: Server Profile', 'settings', f'{S}/settings/server', 'settings:server',
         'packages/web/src/components/settings/SettingsPanel.tsx', [{'action': 'wait', 'ms': 800}]),
    case('settings.billing', 'Settings: Plan & Billing', 'settings', f'{S}/settings/billing', 'settings:billing',
         'packages/web/src/components/settings/SettingsPanel.tsx', [{'action': 'wait', 'ms': 800}]),
    case('settings.administration', 'Settings: Administration', 'settings', f'{S}/settings/administration', 'settings:administration',
         'packages/web/src/components/settings/SettingsPanel.tsx', [{'action': 'wait', 'ms': 800}]),
    case('settings.applications', 'Settings: Applications', 'settings', f'{S}/settings/applications', 'settings:applications',
         'packages/web/src/components/settings/SettingsPanel.tsx', [{'action': 'wait', 'ms': 800}]),
    # ---- notification center ----------------------------------------------
    case('notification-center.open', 'Notification center open (rail bell hover)', 'notification-center',
         f'{S}/channel/channel-design', 'notification-center',
         'packages/web/src/components/layout/NotificationCenter.tsx', CHAT_READY,
         [{'action': 'hover', 'testId': 'notification-trigger-rail'},
          {'action': 'waitFor', 'testId': 'notification-center'}]),
    # ---- interaction states ----------------------------------------------
    case('state.sidebar-row-hover', 'Hover on unselected sidebar row (#android-artifacts)', 'chat',
         f'{S}/channel/channel-design', 'hover-sidebar-row',
         'raft-ui sidebarItemRecipe', CHAT_READY,
         [{'action': 'hover', 'selector': '[data-sidebar-channel-id="channel-android"]'}]),
    case('state.rail-hover', 'Hover on rail Tasks button (tooltip)', 'chat',
         f'{S}/channel/channel-design', 'hover-rail-tasks',
         'packages/web/src/components/layout/LeftRail.tsx', CHAT_READY,
         [{'action': 'hover', 'testId': 'left-rail-tab-tasks'}, {'action': 'wait', 'ms': 1200}]),
    case('state.message-hover', 'Message hover toolbar (Cindy message)', 'chat',
         f'{S}/channel/channel-design', 'hover-message',
         'packages/web/src/components/message/MessageHoverToolbar.tsx', CHAT_READY,
         [{'action': 'hover', 'selector': MSG}]),
    case('state.reaction-picker', 'Reaction picker open from hover toolbar', 'chat',
         f'{S}/channel/channel-design', 'reaction-picker',
         'packages/web/src/components/message/MessageItem.tsx', CHAT_READY,
         [{'action': 'hover', 'selector': MSG},
          {'action': 'click', 'selector': f'{MSG} [data-message-affordance="reaction"]'},
          {'action': 'waitFor', 'selector': '[data-message-affordance="reaction-picker"]'}]),
    case('state.composer-focused', 'Composer focused (empty)', 'chat',
         f'{S}/channel/channel-design', 'composer-focused',
         'packages/web/src/components/message/MessageInput.tsx', CHAT_READY,
         [{'action': 'focus', 'testId': 'composer-textarea'}]),
    case('state.channel-loading', 'Channel while message page is pending', 'chat',
         f'{S}/channel/channel-design', 'channel-loading',
         'packages/web/src/components/message/ChatPanel.tsx',
         [{'action': 'waitFor', 'testId': 'composer-textarea'}, {'action': 'wait', 'ms': 1500}],
         hold=['GET /messages/channel/channel-design'],
         notes='GET /messages/channel/channel-design never answers on either side.'),
]

cases = []
for r in routes:
    for (w, h) in r['sizes']:
        for theme in THEMES:
            size = '' if (w, h) == (1280, 800) else f'.{w}x{h}'
            cid = f"screens.desktop.{r['key']}{size}.{theme}"
            props = {'route': r['route'], 'flutter': r['flow'], 'web': {'ready': r['ready'], 'steps': r['steps']}}
            if r['hold']:
                props['hold'] = r['hold']
            c = {
                'id': cid,
                'title': f"Desktop {w}x{h} {theme}: {r['title']}",
                'captureType': 'real-screen',
                'surface': r['surface'],
                'category': f"app/desktop/{r['surface']}",
                'baselineStatus': 'pending',
                'viewport': {'width': w, 'height': h, 'density': 1},
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': {'selector': 'viewport', 'crop': 'viewport', 'contract': 'screen-route'},
                'reactPathHint': r['hint'],
                'androidCaseHint': f"apps/raft_flutter/integration_test/desktop_screens_test.dart flow '{r['flow']}' (provider android, source flutter-linux)",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            }
            if r['notes']:
                c['notes'] = r['notes']
            cases.append(c)

doc = {
    'version': 1,
    'name': 'raft-flutter desktop real-screen parity cases',
    'description': 'Generated by tool/desktop-parity/build-cases.py from the Web desktop route table (raft-source 26f77ef). '
                   'Same schema as raft-source packages/visual-testing/shared/sharedCases.json; theme is encoded in the id suffix.',
    'cases': cases,
}
out = repo / 'docs/desktop-cases.json'
out.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + '\n')
print(f'{len(routes)} routes/states -> {len(cases)} cases -> {out.relative_to(repo)}')
