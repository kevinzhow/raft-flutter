#!/usr/bin/env python3
"""Capture the production v1.24 Tasks route using one API fixture on both providers."""

import json
from pathlib import Path

from builders import manifest_path

PREFIX = 'components.pages.tasks-v124.'
FIXTURE = 'tasks-v124'
SERVER = 'visual-server'
OWNER = 'visual-user'
CHANNEL = 'channel-tasks-v124'
AGENT = 'agent-tasks-v124'
STAMP = '2026-06-17T12:30:00.000Z'


def task(number, title, *, author=OWNER, assignee=None, status='todo', **details):
    tid = f'visual-task-{number}'
    return {
        'id': tid,
        'channelId': CHANNEL,
        'channelName': 'workbench',
        'channelType': 'channel',
        'taskNumber': number,
        'title': title,
        'status': status,
        'messageId': tid,
        'conversationChannelId': f'conversation-{tid}',
        'conversationAnchored': True,
        'conversationReplyCount': 0,
        'sourceRecorded': True,
        'hasDescription': False,
        'description': None,
        'createdByType': 'user',
        'createdById': author,
        'createdByName': 'artin' if author == OWNER else 'designer',
        'claimedByType': 'agent' if assignee == AGENT else 'user' if assignee else None,
        'claimedById': assignee,
        'claimedByName': 'Workbench Assistant' if assignee == AGENT else None,
        'createdAt': STAMP,
        'updatedAt': STAMP,
        'lastActivityAt': STAMP,
        'revision': 1,
        **details,
    }


assigned = [
    task(4, '移动端工作台需要保留讨论位置：检查 Android 和 Safari 的滚动行为、输入法焦点、'
         '列表回跳与历史记录。Compare viewport changes before and after switching between longer tasks. '
         'Close the pane, then reopen it to confirm the selected task and reading position remain stable.',
         author='visual-human-designer', assignee=OWNER, status='in_progress'),
]
started = [
    task(16, 'Check the task detail layout'),
    task(1, 'Investigate sidebar flicker when switching channels with the keyboard, '
         'restoring the active thread, changing the window width and returning to the Tasks list',
         assignee=AGENT, status='in_progress', hostMessageId='earlier-task-message',
         hasDescription=True, description='Compare the sidebar at normal and narrow widths. '
         'Keep an open thread and a draft in the composer while switching channels. '
         'Record the result after the sidebar settles and after returning to the list.'),
]
other = [
    task(15, 'Review the onboarding checklist', author='visual-human-designer', assignee=AGENT),
    task(7, 'Update the keyboard shortcuts guide', author='visual-human-designer', status='backlog'),
    task(3, 'Review archived conversations', author='visual-human-designer', assignee=AGENT, status='closed'),
]
tasks = assigned + started + other
channel = {
    'id': CHANNEL, 'serverId': SERVER, 'name': 'workbench',
    'type': 'channel', 'createdAt': STAMP, 'description': None, 'joined': True,
}
agent = {
    'id': AGENT, 'serverId': SERVER, 'name': 'Workbench-Assistant',
    'displayName': 'Workbench Assistant', 'avatarUrl': 'pixel:robot',
    'createdAt': STAMP, 'activity': 'offline', 'deletedAt': None,
}


def lane_query(encode):
    return {
        '$when': [
            {'query': {'relation': 'assigned_to_me'}, 'answer': encode(assigned)},
            {'query': {'relation': 'created_by_me'}, 'answer': encode(started)},
            {'query': {'relation': 'from_my_message'}, 'answer': encode([])},
        ],
        '$default': encode(tasks),
    }


def counts(rows):
    return {'counts': {
        status: sum(row['status'] == status for row in rows)
        for status in ('backlog', 'todo', 'in_progress', 'done', 'closed')
    }, 'relations': {}}


owner = {'id': OWNER, 'userId': OWNER, 'serverId': SERVER, 'name': 'artin',
         'displayName': 'artin', 'avatarUrl': None, 'role': 'owner'}
routes = {
    'GET /channels': [channel],
    f'GET /channels/{CHANNEL}': channel,
    'GET /channels/threads/followers': {'threads': []},
    'GET /tasks/server': lane_query(lambda rows: {'tasks': rows, 'next_cursor': None}),
    'GET /tasks/server/counts': lane_query(counts),
    f'GET /tasks/channel/{CHANNEL}': {'tasks': tasks},
    f'GET /channels/{CHANNEL}/members': {'humans': [owner], 'agents': [agent]},
    'GET /agents': [agent],
}
for row in tasks:
    tid = row['id']
    conversation = row['conversationChannelId']
    routes[f"GET /tasks/channel/{CHANNEL}/number/{row['taskNumber']}"] = {'task': row}
    routes[f'GET /tasks/{tid}/history'] = {'events': []}
    routes[f'GET /messages/channel/{conversation}'] = {'messages': [], 'hasMore': False}
    routes[f'POST /channels/{conversation}/read'] = {}
    routes[f'GET /channels/{conversation}'] = {
        'id': conversation, 'serverId': SERVER, 'type': 'task',
        'name': conversation, 'parentChannelId': CHANNEL, 'parentTaskId': tid,
        'createdAt': STAMP, 'joined': True,
    }

fixture = {'channel': channel, 'agent': agent, 'routes': routes}
Path(__file__).with_name('fixtures').joinpath(f'{FIXTURE}.json').write_text(
    json.dumps(fixture, indent=2, ensure_ascii=False) + '\n',
)

OPEN = ('[data-task-id="visual-task-16"]', 'tasks-page-row-open-visual-task-16')
SWITCH = ('[data-task-id="visual-task-1"]', 'tasks-page-row-open-visual-task-1')
FOCUS = ('[data-testid="task-focus-mode"]', 'task-focus-mode')


def case(platform, state, suffix, theme):
    phone = platform == 'phone'
    close_key = 'task-modal-mobile-back' if phone else 'task-modal-close'
    close = (f'[data-testid="{close_key}"]', close_key)
    actions = {
        'list-mine': (),
        'list-all': (),
        'detail-open': (OPEN,),
        'detail-switch': (OPEN, SWITCH),
        'detail-close': (OPEN, close),
        'detail-focus': (OPEN, FOCUS),
    }[state]
    opened = state in ('detail-open', 'detail-switch', 'detail-focus')
    web_actions = [{'type': 'click', 'target': web} for web, _ in actions]
    flutter_actions = [
        {'type': 'tap', 'key': flutter, 'scroll': False, 'mouse': not phone}
        for _, flutter in actions
    ]
    if state == 'list-all':
        if phone:
            web_actions = [
                {'type': 'click', 'target': '[data-testid="tasks-page-scope-select"]'},
                {'type': 'click', 'target': '[data-testid="tasks-page-scope-select-all"]'},
            ]
            flutter_actions = [
                {'type': 'tap', 'key': 'tasks-page-scope-select', 'scroll': False},
                {'type': 'tapText', 'text': 'All'},
            ]
        else:
            web_actions = [{'type': 'click', 'target': '[data-testid="tasks-page-tab-all"]'}]
            flutter_actions = [
                {'type': 'tap', 'key': 'tasks-page-tab-all', 'scroll': False, 'mouse': True},
            ]
    visible = (
        '[data-testid="task-modal-title"]' if opened else
        '[data-testid="tasks-page-list-all"] [data-task-id="visual-task-15"]'
        if state == 'list-all' else '[data-task-id="visual-task-16"]'
    )
    if theme.endswith('-dark'):
        visible = f'html.dark {visible}'
    return {
        'id': f'{PREFIX}{platform}.{state}.{suffix}',
        'title': f'Tasks v1.24 {platform} {state} ({theme})',
        'captureType': 'component-fixture',
        'surface': 'tasks-v124',
        'category': 'extension/tasks-v124',
        'suite': 'raft-flutter-extension',
        'viewport': {'width': 390 if phone else 1280,
                     'height': 844 if phone else 900, 'density': 1, 'touch': phone},
        'theme': theme,
        'locale': 'en',
        'variants': [{'id': 'default', 'name': 'Default', 'props': {
            'extFixture': FIXTURE,
            'parityTheme': theme,
            'state': state,
            'platform': platform,
        }}],
        'capture': {
            'selector': visible,
            'crop': 'viewport',
            'contract': 'viewport-with-portal',
            'interactions': web_actions,
            'androidInteractions': flutter_actions,
        },
        'reactPathHint': 'packages/web/src/components/layout/TasksRoute.tsx',
        'androidCaseHint': 'apps/raft_flutter/test/parity/cases/ext_tasks_v124.dart',
        'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
    }


manifest = manifest_path()
data = json.loads(manifest.read_text())
cases = data['cases'] if isinstance(data, dict) else data
cases[:] = [entry for entry in cases if not entry['id'].startswith(PREFIX)]
for platform, states in {
    'desktop': ('list-mine', 'list-all', 'detail-open', 'detail-switch', 'detail-close', 'detail-focus'),
    'phone': ('list-mine', 'list-all', 'detail-open', 'detail-close'),
}.items():
    for state in states:
        for suffix, theme in (('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')):
            cases.append(case(platform, state, suffix, theme))
manifest.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
