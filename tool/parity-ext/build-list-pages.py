#!/usr/bin/env python3
"""Append the LIST PAGES cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Run after build-cases.py (idempotent: every `components.list-pages.*` case is replaced, all other
cases are kept). Also writes tool/parity-ext/fixtures/listpages.json, the data both providers read.

Page-inventory rows covered (page inventory, tool/parity-ext/inventory.py): 2.05 2.10 2.11 2.12 4.02 4.03 4.06 4.07
5.02 5.03 5.04 5.06 5.07 5.08 5.09 5.10 5.11 6.04 6.05 6.06 6.10 8.02 8.03 8.04 8.05.

Derivation (raft-source packages/web/src/components):
  search/MessageSearchPage.tsx      full-page search (home, searching, empty, error, load more, too broad, beyond plan history)
  thread/ThreadsInbox.tsx           Activity list (filters, context menu, empty / loading / error)
  saved/SavedPanel.tsx              Saved list (item actions, empty / loading / error)
  task/TasksPanel.tsx               Tasks (filters, view toggle, status menu, loading, load more)
Ids: components.list-pages.<panel>.<key>.<theme>. React: tool/parity-ext/host/ListPagesCases.tsx; Flutter:
apps/raft_flutter/test/parity/cases/ext_list_pages.dart (keyed by the case's `extCase`).
"""
import json
import os
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.list-pages.'
SRC = 'packages/web/src/components/'
RAFT_SOURCE = pathlib.Path(os.environ.get(
    'PARITY_RAFT_SOURCE', '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source'))
SHARED = RAFT_SOURCE / 'packages/visual-testing/shared'


def shared(name):
    data = json.loads((SHARED / name).read_text())
    data.pop('comment', None)
    return data


SEARCH = shared('searchResultsFixture.json')
SAVED = shared('savedMessagesFixture.json')
ACTIVITY = shared('activityResultsFixture.json')
TASKS = shared('tasksFixture.json')
INBOX_EMPTY = {'items': [], 'hasMore': False, 'totalCount': 0, 'totalUnreadCount': 0}
SEARCH_EMPTY = {'results': [], 'hasMore': False}
SEARCH_MORE = {**SEARCH, 'hasMore': True}
# Hits older than the free plan's history window: the Web page flags them "beyond plan history".
SEARCH_OLD = {**SEARCH, 'results': [{**r, 'createdAt': r['createdAt'].replace('2026-06', '2025-06')}
                                    for r in SEARCH['results']]}
SAVED_ALL = {**SAVED, 'hasMore': False, 'total': 3}


def _thread_hit(base, hit_id, thread, content, snippet, sender, created):
    """A reply hit inside a thread: threadId + parentMessageId make the Web page group it (searchGrouping.ts)."""
    return {**base, 'id': hit_id, 'channelId': f'thread-{thread}', 'threadId': f'thread-{thread}',
            'parentMessageId': thread, 'channelType': 'thread', 'content': content, 'snippet': snippet,
            'senderName': sender, 'createdAt': created}


_HIT = SEARCH['results'][1]
_PARENT = ('We have no update prompt on any client yet. Look for a ready-made release channel we can plug in and '
           'check for a newer release on GitHub, then show a red dot after the user opens the app.')
# Query "appcast" matches no destination, so the first message hit is the selected result.
SEARCH_THREADS = {'hasMore': False, 'results': [
    _thread_hit({**_HIT, 'parentMessageContent': _PARENT}, 'msg-visual-thread-1', 'msg-agent-reply', 'a',
                'The appcast build is ready for the real-device check.', 'Cindy', '2026-06-19T10:00:00.000Z'),
    _thread_hit({**_HIT, 'parentMessageContent': _PARENT}, 'msg-visual-thread-2', 'msg-agent-reply', 'b',
                'The next release will carry the appcast files.', 'artin', '2026-06-19T09:30:00.000Z'),
    _thread_hit({**_HIT, 'parentMessageContent': 'Can the release notes mention the update prompt?'},
                'msg-visual-thread-3', 'msg-release-notes', 'c', 'Appcast notes updated.', 'Cindy',
                '2026-06-19T08:00:00.000Z'),
    {**SEARCH['results'][0], 'id': 'msg-visual-release-4', 'content': 'Tagged the appcast candidate.',
     'snippet': 'Tagged the appcast candidate.', 'createdAt': '2026-06-18T12:00:00.000Z'},
]}

NOTIFICATIONS = [
    {'id': 'visual-warning', 'kind': 'warning', 'title': 'Needs attention', 'body': 'Review this notification.'},
    {'id': 'visual-info', 'kind': 'info', 'title': 'All systems connected', 'body': 'No action is required.'},
]

FX = shared('fixtureData.json')
_cindy = FX['agents']['cindy']
_owner = FX['humans']['owner']
CHANNEL_ROSTER = {
    'agents': [{
        'id': _cindy['id'], 'serverId': FX['server']['id'], 'name': _cindy['name'],
        'displayName': _cindy['displayName'], 'avatarUrl': _cindy['avatar'], 'description': _cindy['description'],
        'status': _cindy['status'], 'model': _cindy['model'], 'runtime': _cindy['runtime'],
        'reasoningEffort': _cindy['reasoningEffort'], 'executionMode': _cindy['executionMode'], 'envVars': {},
        'machineId': FX['machines']['primary']['id'], 'sessionId': _cindy['sessionId'], 'runtimeProfile': None,
        'creatorType': 'user', 'creatorId': _owner['id'], 'creator': None, 'createdAgents': [], 'deletedAt': None,
        'createdAt': FX['times']['entityCreatedAtIso'], 'activity': _cindy['activity'],
        'activityDetail': _cindy['activityDetail'],
    }],
    'humans': [{
        'id': _owner['memberId'], 'userId': _owner['memberId'], 'serverId': FX['server']['id'],
        'name': _owner['name'], 'displayName': _owner['displayName'], 'description': _owner['description'],
        'avatarUrl': None, 'gravatarHash': '', 'email': _owner['email'], 'role': _owner['role'],
        'joinedAt': FX['times']['memberJoinedAtIso'],
    }],
    'externalMembers': [],
}

FIXTURE = {
    'name': 'raft-flutter parity extension: list pages',
    'notifications': NOTIFICATIONS,
    'routes': {
        'GET /messages/search': SEARCH,
        'GET /channels/saved': SAVED,
        'GET /channels/inbox': ACTIVITY,
        'GET /tasks/server': {'tasks': TASKS['tasks']},
        'GET /channels/channel-design/members': CHANNEL_ROSTER,
    },
    'routeSets': {
        'search-empty': {'GET /messages/search': SEARCH_EMPTY},
        'search-pending': {'GET /messages/search': {'$pending': True}},
        'search-error': {'GET /messages/search': {'$status': 500}},
        'search-broad': {'GET /messages/search': {'$status': 400, '$body': {'code': 'QUERY_TOO_BROAD',
                                                                            'error': 'Query too broad'}}},
        'search-more': {'GET /messages/search': SEARCH_MORE},
        'search-old': {'GET /messages/search': SEARCH_OLD},
        'search-threads': {'GET /messages/search': SEARCH_THREADS},
        'activity-empty': {'GET /channels/inbox': INBOX_EMPTY},
        'activity-loading': {'GET /channels/inbox': {'$pending': True}},
        'activity-error': {'GET /channels/inbox': {'$status': 500}},
        # activity_conversation_list_v0 on (the app evaluates it; the Web host sets the flag from `flags`).
        'activity-conversation-list': {'POST /feature-flags/evaluate': {
            'evaluations': [{'key': 'activity_conversation_list_v0', 'enabled': True}]}},
        'saved-empty': {'GET /channels/saved': {'saved': [], 'hasMore': False, 'total': 0}},
        'saved-loading': {'GET /channels/saved': {'$pending': True}},
        'saved-error': {'GET /channels/saved': {'$status': 500}},
        'saved-all': {'GET /channels/saved': SAVED_ALL},
        'create-archived': {'POST /channels': {'$status': 409, '$body': {
            'code': 'archived_name_collision', 'error': 'An archived channel already uses this name.',
            'archivedChannelId': 'channel-archived-design', 'archivedChannelName': 'android-artifacts',
            'archivedChannelType': 'channel', 'canUnarchiveArchivedChannel': True}}},
        'create-failed': {'POST /channels': {'$status': 500, '$body': {'error': 'Could not create the channel.'}}},
        'create-pending': {'POST /channels': {'$pending': True}},
        'tasks-loading': {'GET /tasks/server': {'$pending': True}},
        'tasks-empty': {'GET /tasks/server': {'tasks': []}},
        'tasks-more': {'GET /tasks/server': {'tasks': TASKS['tasks'], 'next_cursor': 'cursor-2'}},
    },
}

CASES = []


def tid(testid):
    return f'[data-testid="{testid}"]'


def add(key, title, kind, *, platform, hint, props=None, selector='[data-visual-case]', android_key=None,
        interactions=None, route_set=None, surface=None, android_interactions=None, extFixture='listpages',
        viewport_capture=False, viewport=None):
    """key = `<surface>.<name>`; one case per theme."""
    viewport = viewport or (MOBILE if platform == 'mobile' else DESKTOP)
    base = {'extCase': key, 'extKind': kind, 'platform': platform, 'extFixture': extFixture}
    base.update(props or {})
    if route_set:
        base['routeSet'] = route_set
    CASES.append({'key': key, 'title': title, 'viewport': viewport, 'selector': selector, 'android_key': android_key,
                  'hint': hint, 'props': base, 'interactions': interactions or [],
                  'android_interactions': android_interactions or [], 'viewport_capture': viewport_capture})


def fill(text, wait=850):
    return [{'type': 'fill', 'target': '[data-visual-case] input', 'value': text}, {'type': 'wait', 'ms': wait}]


def click(selector, wait=300):
    return [{'type': 'click', 'target': selector}, {'type': 'wait', 'ms': wait}]


# --------------------------------------------------------------------------- Search page (5.02 5.03 5.04)
SEARCH_HINT = SRC + 'search/MessageSearchPage.tsx'
HISTORY = 'android|visual parity|release notes'
for plat, box in (('phone', {'w': 390, 'h': 844}), ('desktop', {'w': 1208, 'h': 800})):
    platform = 'mobile' if plat == 'phone' else 'desktop'
    base = {'panel': 'search', 'route': '/search', **box}
    add(f'search.{plat}-home', f'Search page ({plat}): history tags and frequent', 'panel', platform=platform,
        hint=SEARCH_HINT, props={**base, 'searchHistory': HISTORY})
    add(f'search.{plat}-searching', f'Search page ({plat}): searching skeleton', 'panel', platform=platform,
        hint=SEARCH_HINT, props={**base, 'q': 'android'}, route_set='search-pending',
        interactions=[{'type': 'wait', 'ms': 850}])
    add(f'search.{plat}-results', f'Search page ({plat}): results', 'panel', platform=platform,
        hint=SEARCH_HINT, props={**base, 'q': 'android'},
        interactions=[{'type': 'wait', 'ms': 850}])
    add(f'search.{plat}-no-results', f'Search page ({plat}): no results', 'panel', platform=platform,
        hint=SEARCH_HINT, props={**base, 'q': 'zzzxq'}, route_set='search-empty',
        interactions=[{'type': 'wait', 'ms': 850}])
    add(f'search.{plat}-error', f'Search page ({plat}): search failed, retry', 'panel', platform=platform,
        hint=SEARCH_HINT, props={**base, 'q': 'zzzxq'}, route_set='search-error',
        interactions=[{'type': 'wait', 'ms': 1500}])
    add(f'search.{plat}-too-broad', f'Search page ({plat}): query too broad', 'panel', platform=platform,
        hint=SEARCH_HINT, props={**base, 'q': 'zzzxq'}, route_set='search-broad',
        interactions=[{'type': 'wait', 'ms': 1500}])
    add(f'search.{plat}-load-more', f'Search page ({plat}): load more', 'panel', platform=platform,
        hint=SEARCH_HINT, props={**base, 'q': 'android'}, route_set='search-more',
        interactions=[{'type': 'wait', 'ms': 850}])
    add(f'search.{plat}-beyond-history', f'Search page ({plat}): hits beyond plan history', 'panel',
        platform=platform, hint=SEARCH_HINT, props={**base, 'q': 'android'}, route_set='search-old',
        interactions=[{'type': 'wait', 'ms': 850}])
add('search.desktop-thread-group', 'Search page (desktop): thread hits grouped under their parent message', 'panel',
    platform='desktop', hint=SEARCH_HINT, route_set='search-threads',
    props={'panel': 'search', 'route': '/search', 'w': 1208, 'h': 800, 'q': 'appcast'},
    interactions=[{'type': 'wait', 'ms': 850}])
add('search.desktop-thread-selected', 'Search page (desktop): ArrowDown moves the selection to the second hit', 'panel',
    platform='desktop', hint=SEARCH_HINT, route_set='search-threads',
    props={'panel': 'search', 'route': '/search', 'w': 1208, 'h': 800, 'q': 'appcast'},
    interactions=[{'type': 'wait', 'ms': 850}, {'type': 'press', 'target': '[data-visual-case] input', 'key': 'ArrowDown'},
                  {'type': 'wait', 'ms': 150}],
    android_interactions=[{'type': 'key', 'key': 'arrowDown'}, {'type': 'wait', 'ms': 150}])
add('search.desktop-channel-filter', 'Search page (desktop): channel filter dropdown', 'panel', platform='desktop',
    hint=SEARCH_HINT, props={'panel': 'search', 'route': '/search', 'w': 1208, 'h': 800, 'q': 'android'},
    interactions=[{'type': 'wait', 'ms': 850}, *click("button[aria-label='Open channel filter']", 250)])


# --------------------------------------------------------------------------- Activity (5.06 5.07 5.08)
ACT_HINT = SRC + 'thread/ThreadsInbox.tsx'
ROW = '[data-visual-case] [data-testid="inbox-row"]'
for plat in ('phone', 'desktop'):
    platform = 'mobile' if plat == 'phone' else 'desktop'
    base = {'panel': 'activity'}
    if plat == 'phone':
        add('activity.phone-empty', 'Activity (phone): empty inbox', 'panel', platform=platform, hint=ACT_HINT,
            props={**base, 'state': 'empty'}, route_set='activity-empty')
        add('activity.phone-loading', 'Activity (phone): loading', 'panel', platform=platform, hint=ACT_HINT,
            props={**base, 'state': 'loading'}, route_set='activity-loading')
        add('activity.phone-error', 'Activity (phone): failed to load', 'panel', platform=platform, hint=ACT_HINT,
            props={**base, 'state': 'empty'}, route_set='activity-error')
    add(f'activity.{plat}-filter-unread', f'Activity ({plat}): Unread filter', 'panel', platform=platform,
        hint=ACT_HINT, props=base, interactions=[{'type': 'wait', 'ms': 850},
                                                 *click(tid('inbox-filter-unread'))])
    add(f'activity.{plat}-filter-mentions', f'Activity ({plat}): Mentions filter', 'panel', platform=platform,
        hint=ACT_HINT, props=base, interactions=[{'type': 'wait', 'ms': 850},
                                                 *click(tid('inbox-filter-mentions'))])
    add(f'activity.{plat}-context-menu', f'Activity ({plat}): row context menu', 'panel', platform=platform,
        hint=ACT_HINT, props=base, interactions=[{'type': 'wait', 'ms': 850},
                                                 {'type': 'rightclick', 'target': ROW},
                                                 {'type': 'wait', 'ms': 300}], viewport_capture=True)

# Activity as a conversation list (Web v1.21.23 `activity_conversation_list_v0`): one avatar row per
# conversation; the pinned variant pins the fixture's channel in the sidebar order.
add('activity.desktop-conversation-list', 'Activity (desktop): conversation list', 'panel', platform='desktop',
    hint=ACT_HINT, props={'panel': 'activity', 'flags': 'list'}, route_set='activity-conversation-list',
    interactions=[{'type': 'wait', 'ms': 850}])
add('activity.desktop-conversation-list-pinned', 'Activity (desktop): conversation list, a pinned channel first',
    'panel', platform='desktop', hint=ACT_HINT,
    props={'panel': 'activity', 'flags': 'list', 'pinned': 'channel-android'},
    route_set='activity-conversation-list', interactions=[{'type': 'wait', 'ms': 850}])

# --------------------------------------------------------------------------- Saved (5.09 5.10 5.11)
SAVED_HINT = SRC + 'saved/SavedPanel.tsx'
SAVED_ROW = '[data-visual-case] [role="button"]'
add('saved.desktop-list', 'Saved (desktop): saved messages list', 'panel', platform='desktop', hint=SAVED_HINT,
    props={'panel': 'saved'}, interactions=[{'type': 'wait', 'ms': 850}])
for plat in ('phone', 'desktop'):
    platform = 'mobile' if plat == 'phone' else 'desktop'
    base = {'panel': 'saved'}
    if plat == 'phone':
        add('saved.phone-empty', 'Saved (phone): empty', 'panel', platform=platform, hint=SAVED_HINT,
            props={**base, 'state': 'empty'}, route_set='saved-empty')
        add('saved.phone-loading', 'Saved (phone): loading', 'panel', platform=platform, hint=SAVED_HINT,
            props={**base, 'state': 'loading'}, route_set='saved-loading')
        add('saved.phone-error', 'Saved (phone): failed to load', 'panel', platform=platform, hint=SAVED_HINT,
            props={**base, 'state': 'empty'}, route_set='saved-error')
    add(f'saved.{plat}-actions', f'Saved ({plat}): item actions menu', 'panel', platform=platform, hint=SAVED_HINT,
        props={**base, 'state': 'results'}, route_set='saved-all',
        interactions=[{'type': 'wait', 'ms': 850}, {'type': 'rightclick', 'target': SAVED_ROW},
                      {'type': 'wait', 'ms': 300}], viewport_capture=True)

# --------------------------------------------------------------------------- Tasks (6.04 6.05 6.06 6.10)
TASKS_HINT = SRC + 'task/TasksPanel.tsx'
TASK_BOX = {'desktop': {'w': 1208, 'h': 800}, 'phone': {'w': 390, 'h': 844}}
CHIP = '[data-visual-case] button:has-text("%s")'
for plat in ('desktop', 'phone'):
    platform = 'mobile' if plat == 'phone' else 'desktop'
    base = {'panel': 'tasks', 'route': '/tasks', **TASK_BOX[plat]}
    wait = {'type': 'wait', 'ms': 850}
    if plat == 'desktop':
        add('tasks.desktop-board', 'Tasks (desktop): board view (default)', 'panel', platform=platform,
            hint=TASKS_HINT, props=base, interactions=[wait])
        add('tasks.desktop-list', 'Tasks (desktop): list view', 'panel', platform=platform, hint=TASKS_HINT,
            props={**base, 'view': 'list'}, interactions=[wait])
        add('tasks.desktop-status-menu', 'Tasks (desktop): status menu', 'panel', platform=platform,
            hint=SRC + 'task/StatusBadge.tsx, TasksPanel.tsx', props={**base, 'view': 'list'},
            interactions=[wait, *click('[data-visual-case] button[data-slot="badge"]', 300)])
    for key, label in (('assignee', 'Assignee'), ('creator', 'Creator'), ('channels', 'Channel')):
        add(f'tasks.{plat}-filter-{key}', f'Tasks ({plat}): {label} filter popover', 'panel', platform=platform,
            hint=TASKS_HINT, props=base, interactions=[wait, *click(CHIP % label, 300)])
    option = lambda label: f'button:has-text("{label}")'
    add(f'tasks.{plat}-filtered', f'Tasks ({plat}): Assignee filter applied, Clear All', 'panel', platform=platform,
        hint=TASKS_HINT, props=base,
        interactions=[wait, *click(CHIP % 'Assignee', 300), *click(option('Cindy'), 300)])
    add(f'tasks.{plat}-filtered-empty', f'Tasks ({plat}): Creator filter matches nothing', 'panel', platform=platform,
        hint=TASKS_HINT, props=base,
        interactions=[wait, *click(CHIP % 'Creator', 300), *click(option('Product UX Designer'), 300)])
    add(f'tasks.{plat}-loading', f'Tasks ({plat}): loading skeleton', 'panel', platform=platform, hint=TASKS_HINT,
        props=base, route_set='tasks-loading', interactions=[wait])
    add(f'tasks.{plat}-load-more', f'Tasks ({plat}): Load more per lane', 'panel', platform=platform,
        hint=TASKS_HINT, props=base, route_set='tasks-more', interactions=[wait])

# --------------------------------------------------------------------------- Notification center (2.05)
add('notification.desktop-center', 'Notification center popover from the rail bell (desktop)', 'notification',
    platform='desktop', hint=SRC + 'layout/NotificationCenter.tsx, NotificationTrigger.tsx',
    interactions=[{'type': 'hover', 'target': tid('notification-trigger-rail')}, {'type': 'wait', 'ms': 500}])

# --------------------------------------------------------------------------- Shell-derived dialogs (2.10 2.11 2.12)
SH = SRC + 'layout/'
CARD = '[data-slot="modal-backdrop"] [data-slot="dialog-card"]'
CONTENT = '[data-slot="dialog-content"]'
SEC = 'sidebar-section-toggle-channels'
CUSTOM_SEC = '[data-testid="sidebar-custom-section-sec-launch"] button[aria-expanded]'
ROW_GENERAL = '[data-sidebar-channel-id="shell-general"]'


def shell(key, title, surface, *, preset, interactions, android, selector, android_key, hint, shell_route='',
          viewport_capture=False, platform='mobile'):
    add(key, title, 'shell', platform=platform, hint=hint,
        props={'surface': surface, 'preset': preset, 'shellRoute': shell_route},
        selector='body' if viewport_capture else selector, android_key=None if viewport_capture else android_key,
        interactions=interactions, viewport_capture=viewport_capture, android_interactions=android)


def rc(sel, x=None, y=None):
    step = {'type': 'rightclick', 'target': sel}
    if x is not None:
        step.update(x=x, y=y)
    return step


def ck(sel):
    return {'type': 'click', 'target': sel}


def fsec(key, x, y):
    return {'type': 'secondaryTap', 'key': key, 'x': x, 'y': y}


def ftap(key):
    return {'type': 'tap', 'key': key}


MOBILE_ROUTE = ''
shell('dialogs.phone-new-section', 'New section dialog (phone)', 'dialog.new-section', preset='mobile',
      interactions=[rc(tid(SEC), 30, 12), ck('text=New section')],
      android=[fsec('sidebar-section-system:channels', 38, 24), ftap('sidebar-menu-new-section')],
      selector=CARD, android_key='sidebar-section-dialog', hint=SH + 'SidebarSectionDialog.tsx')
shell('dialogs.phone-edit-section', 'Rename section dialog (phone)', 'dialog.edit-section', preset='mobile-custom',
      interactions=[rc(CUSTOM_SEC, 30, 12), ck('text=Rename / change icon')],
      android=[fsec('sidebar-section-sec-launch', 38, 24), ftap('sidebar-menu-rename-section')],
      selector=CARD, android_key='sidebar-section-dialog', hint=SH + 'SidebarSectionDialog.tsx')
shell('dialogs.phone-delete-section', 'Delete section confirm (phone)', 'dialog.delete-section', preset='mobile-custom',
      interactions=[rc(CUSTOM_SEC, 30, 12), ck('text=Delete section')],
      android=[fsec('sidebar-section-sec-launch', 38, 24), ftap('sidebar-menu-delete-section')],
      selector=CONTENT, android_key='shell-dialog', hint=SRC + 'ConfirmDialog.tsx')
shell('dialogs.phone-archive-channel', 'Archive channel confirm (phone)', 'dialog.archive-channel', preset='mobile',
      interactions=[rc(ROW_GENERAL), ck('text=Archive')],
      android=[{'type': 'secondaryTap', 'key': 'sidebar-channel-shell-general', 'row': True},
               ftap('sidebar-menu-archive')],
      selector=CONTENT, android_key='shell-dialog', hint=SRC + 'ConfirmDialog.tsx')
shell('dialogs.phone-emoji-picker', 'Section emoji picker open (phone)', 'dialog.new-section', preset='mobile',
      interactions=[rc(tid(SEC), 30, 12), ck('text=New section'),
                    ck('button[aria-label="Choose section emoji"]'), {'type': 'wait', 'ms': 1500}],
      android=[fsec('sidebar-section-system:channels', 38, 24), ftap('sidebar-menu-new-section'),
               ftap('sidebar-section-emoji')],
      selector=CARD, android_key='sidebar-section-dialog', viewport_capture=True,
      hint=SH + 'SidebarSectionEmojiPicker.tsx')

shell('dialogs.desktop-emoji-picker', 'Section emoji picker open (desktop)', 'dialog.new-section', preset='default',
      interactions=[rc(tid(SEC), 30, 12), ck('text=New section'),
                    ck('button[aria-label="Choose section emoji"]'), {'type': 'wait', 'ms': 1500}],
      android=[fsec('sidebar-section-system:channels', 38, 24), ftap('sidebar-menu-new-section'),
               ftap('sidebar-section-emoji')],
      selector=CARD, android_key='sidebar-section-dialog', viewport_capture=True, platform='desktop',
      hint=SH + 'SidebarSectionEmojiPicker.tsx')

# --------------------------------------------------------------------------- Create channel states (4.02)
CC_HINT = SRC + 'channel/CreateChannelDialog.tsx'
SUBMIT = 'form button[type="submit"]'
for plat, box in (('desktop', {'w': 1280, 'h': 800}), ('phone', {'w': 390, 'h': 844})):
    platform = 'mobile' if plat == 'phone' else 'desktop'
    base = {**box, 'name': 'android-artifacts', 'description': 'Build reports, screenshots, release blockers'}
    add(f'create-channel.{plat}-name-error', f'Create channel ({plat}): invalid name error', 'create-channel',
        platform=platform, hint=CC_HINT, props={**box, 'name': 'Bad Name!'}, interactions=[*click(SUBMIT, 300)],
        viewport_capture=plat == 'desktop', selector='body' if plat == 'desktop' else '[data-visual-case]')
    add(f'create-channel.{plat}-archived-name', f'Create channel ({plat}): archived name held, Unarchive',
        'create-channel', platform=platform, hint=CC_HINT, props=base, route_set='create-archived',
        interactions=[*click(SUBMIT, 600)],
        viewport_capture=plat == 'desktop', selector='body' if plat == 'desktop' else '[data-visual-case]')
    add(f'create-channel.{plat}-failed', f'Create channel ({plat}): create failed', 'create-channel',
        platform=platform, hint=CC_HINT, props=base, route_set='create-failed',
        interactions=[*click(SUBMIT, 600)],
        viewport_capture=plat == 'desktop', selector='body' if plat == 'desktop' else '[data-visual-case]')
    add(f'create-channel.{plat}-creating', f'Create channel ({plat}): creating', 'create-channel',
        platform=platform, hint=CC_HINT, props=base, route_set='create-pending',
        interactions=[*click(SUBMIT, 600)],
        viewport_capture=plat == 'desktop', selector='body' if plat == 'desktop' else '[data-visual-case]')

# --------------------------------------------------------------------------- Phone Computers (8.02 8.03 8.04 8.05)
MC_HINT = SRC + 'machine/MobileComputersPanel.tsx'
MC_BODY = '[data-testid="mobile-computers-panel"] > div:nth-of-type(2)'
mc = {'route': '/computers', 'w': 390, 'h': 844}
add('computers.phone-list', 'Computers page (phone): list', 'm-computers', platform='mobile', hint=MC_HINT,
    props={**mc, 'list': 'states'}, selector=MC_BODY, android_key='mobile-computers-body')
add('computers.phone-attention', 'Computers page (phone): needs-attention filter', 'm-computers', platform='mobile',
    hint=MC_HINT, props={**mc, 'list': 'states', 'filter': 'attention'}, selector=MC_BODY,
    android_key='mobile-computers-body')
add('computers.phone-empty', 'Computers page (phone): empty', 'm-computers', platform='mobile', hint=MC_HINT,
    props={**mc, 'list': 'empty'}, selector=MC_BODY, android_key='mobile-computers-body')
add('computers.phone-loading', 'Computers page (phone): loading', 'm-computers', platform='mobile', hint=MC_HINT,
    props={**mc, 'list': 'default', 'loading': 'true', 'loadStatus': 'idle'}, selector=MC_BODY,
    android_key='mobile-computers-body')
add('computers.phone-load-error', 'Computers page (phone): load failed', 'm-computers', platform='mobile',
    hint=MC_HINT, props={**mc, 'list': 'empty', 'loadStatus': 'error', 'loadError': 'true'}, selector=MC_BODY,
    android_key='mobile-computers-body')
add('computers.phone-refresh-error', 'Computers page (phone): refresh failed, saved list kept', 'm-computers',
    platform='mobile', hint=MC_HINT, props={**mc, 'list': 'default', 'loadError': 'true'}, selector=MC_BODY,
    android_key='mobile-computers-body')

PHONE_CLONES = [  # desktop case key -> phone key (detail pages and dialogs, 8.03 / 8.04 / 8.05)
    ('detail.panel', 'detail.panel'), ('detail.identity', 'detail.identity'),
    ('detail.info', 'detail.info'), ('detail.agents', 'detail.agents'), ('detail.workspaces', 'detail.workspaces'),
    ('detail.service', 'detail.service'), ('detail.recovery-guide', 'detail.recovery-guide'),
    ('detail.delete', 'detail.delete'), ('detail.state.offline', 'detail.offline'),
    ('detail.state.up-to-date', 'detail.up-to-date'), ('detail.state.upgrading', 'detail.upgrading'),
    ('detail.state.disk-low', 'detail.disk-low'), ('detail.state.legacy', 'detail.legacy'),
    ('detail.edit-name', 'detail.edit-name'), ('detail.edit-description', 'detail.edit-description'),
    ('detail.select-mode', 'detail.select-mode'), ('detail.select-all', 'detail.select-all'),
    ('detail.workspaces-scanned', 'detail.workspaces-scanned'),
    ('detail.recovery-guide-open', 'detail.recovery-guide-open'),
    ('detail.restart-progress', 'detail.restart-progress'),
    ('add-dialog', 'add-dialog'), ('add-dialog.connect', 'add-dialog.connect'),
    ('dialog.bulk-restart', 'dialog.bulk-restart'), ('dialog.stop-agents', 'dialog.stop-agents'),
    ('dialog.delete-workspace', 'dialog.delete-workspace'), ('dialog.delete-blocked', 'dialog.delete-blocked'),
    ('dialog.delete', 'dialog.delete'),
]
CLONES = []  # (phone key, manifest case) filled in main() from the computers cases already in the manifest


def clone_phone_computers(manifest_cases):
    by_id = {c['id']: c for c in manifest_cases}
    for src, dst in PHONE_CLONES:
        c = by_id.get(f'components.computers.{src}.brutal')
        if c is None:
            raise SystemExit(f'phone computers: no desktop case components.computers.{src}.brutal in the manifest')
        props = c['variants'][0]['props']
        phone_props = {k: v for k, v in props.items() if k in ('machine', 'list', 'flags')}
        kind = 'm-add' if src.startswith('add-dialog') else 'm-detail'
        sel = c['capture'].get('selector') or ''
        if sel.startswith('[data-visual-case='):
            sel = '[data-visual-case]'
        tall = src.startswith(('detail.panel', 'detail.state')) or src.startswith('detail.')
        dialog = src.startswith(('dialog.', 'add-dialog'))
        # Detail sections stack taller than a phone screen: capture them in a tall viewport like the desktop TALL.
        height = 844 if dialog else 3400
        akey = c['capture'].get('androidKey')
        reveal = [{'type': 'reveal', 'key': akey}] if akey and akey.startswith('computer-section-') else []
        add(f'computers.phone-{dst}', 'Computer ' + dst.replace('.', ' ') + ' (phone)', kind, platform='mobile',
            hint=c['reactPathHint'], props={**phone_props, 'w': 390, 'h': height}, selector=sel or '[data-visual-case]',
            viewport={'width': 390, 'height': height, 'density': 3},
            android_key=c['capture'].get('androidKey'), interactions=c['capture']['interactions'],
            android_interactions=(c['capture'].get('androidInteractions') or []) + reveal, extFixture='computers',
            viewport_capture=False)

# --------------------------------------------------------------------------- Channel member dialogs (4.03 4.06 4.07)
CH = SRC + 'channel/'
for plat, box in (('desktop', {}), ('phone', {})):
    platform = 'mobile' if plat == 'phone' else 'desktop'
    caps = {'channelCaps': True}
    add(f'members.{plat}-remove-confirm', f'Remove channel member confirm ({plat})', 'remove-member',
        platform=platform, hint=CH + 'useChannelMemberRemoval.tsx (ChannelMembers panel)', props=caps,
        interactions=[*click("[data-testid='channel-members-open']", 400),
                      {'type': 'hover', 'target': 'text=Cindy'},
                      *click('button:has(svg.lucide-user-minus)', 400)], viewport_capture=True)
    add(f'members.{plat}-add-dialog', f'Add members to a channel dialog ({plat})', 'add-members',
        platform=platform, hint=CH + 'AddMembersDialog.tsx', props=caps,
        interactions=[{'type': 'wait', 'ms': 600}], viewport_capture=True)
    add(f'members.{plat}-create-joint', f'Create shared (joint) channel dialog ({plat})', 'create-joint',
        platform=platform, hint=CH + 'CreateJointChannelDialog.tsx',
        interactions=[{'type': 'wait', 'ms': 400}], viewport_capture=True)

def build_cases():
    out = []
    for c in CASES:
        panel_surface = c['key'].split('.')[0]
        for suffix, theme in THEMES.items():
            props = dict(c['props'])
            props['parityTheme'] = theme
            out.append({
                'id': f'{PREFIX}{c["key"]}.{suffix}',
                'title': f'{c["title"]} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'list-pages',
                'category': 'extension/list-pages',
                'suite': 'raft-flutter-extension',
                'viewport': c['viewport'],
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': ({'selector': 'body', 'crop': 'viewport', 'contract': 'viewport-with-portal',
                             'interactions': c['interactions'], 'androidInteractions': c['android_interactions']}
                            if c['viewport_capture'] else
                            {'selector': c['selector'], 'crop': 'element', 'contract': 'component-bounds',
                             **({'androidKey': c['android_key']} if c['android_key'] else {}),
                             'interactions': c['interactions'], 'androidInteractions': c['android_interactions']}),
                'reactPathHint': c['hint'],
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_list_pages.dart '{c['key']}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
    return out


def write_keys():
    """Case keys for ext_list_pages.dart (case_map registers one builder per key and theme)."""
    keys = ',\n'.join(f"  '{c['key']}'" for c in CASES)
    out = (here.parents[1] / 'apps/raft_flutter/test/parity/cases/ext_list_pages_keys.g.dart')
    out.write_text('// GENERATED by tool/parity-ext/build-list-pages.py; do not edit.\n'
                   '// Case key of every components.list-pages.* case.\n'
                   f'const extListPageKeys = [\n{keys},\n];\n')


def main():
    (here / 'fixtures' / 'listpages.json').write_text(json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n')
    path = manifest_path()
    manifest = json.loads(path.read_text())
    clone_phone_computers(manifest['cases'])
    write_keys()
    cases = build_cases()
    manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
    print(f'{len(cases)} list-pages cases appended ({len(manifest["cases"])} total)')


if __name__ == '__main__':
    main()
