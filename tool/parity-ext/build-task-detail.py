#!/usr/bin/env python3
"""Append the Tasks board page and task detail modal cases to
the run-time manifest ($PARITY_EXT_MANIFEST) and write tool/parity-ext/fixtures/taskdetail.json.

Run last of the chain (build-cases.py ->
build-channel-header.py -> build-announcements.py -> this); idempotent: every
`components.taskspage.*` / `components.taskdetail.*` case is replaced, all
other cases are kept in place (append-only for the other families).

Derivation (raft-source 26f77ef, packages/web/src/components):
  task/TasksPanel.tsx        Tasks page (header, toolbar chips, Board/List,
                             status lanes; done/closed start collapsed; mobile
                             defaults to the list view)
  task/TaskCard.tsx, task/StatusBadge.tsx
  task/TaskModalHead.tsx     title (3-line clamp), description (+ Show more),
                             TaskProperties
  task/TaskProperties.tsx    History timeline, Status / Assignee / Created by
  layout/MainLayout.tsx      RightPanel -> Modal + ThreadPanelWrapper
                             presentation="modal" (desktop) / "mobile-modal",
                             TaskModalBar (+ ThreadPanel hideHeader,
                             hideParentMessage, parentSlot = TaskModalHead)
  Modal.tsx                  backdrop (bg-layer-backdrop, blur 2px)

Ids (append-only, never rename):
  components.taskspage.<platform>.<state>.<theme>
  components.taskdetail.<platform>.<state>.<theme>

React (host/TaskDetailCases.tsx) mounts the real MainLayout on the Tasks route
(`/s/<slug>/tasks`), primes the stores from fixtures/taskdetail.json and, for a
detail case, calls the same `openThread({intent: "task"})` the board card does;
Flutter (cases/ext_task_detail.dart) mounts the real WorkspaceView on the same
data (section tasks, navigateTask for the detail).
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
PAGE_PREFIX = 'components.taskspage.'
DETAIL_PREFIX = 'components.taskdetail.'
SID = 'visual-server'
CH = 'channel-design'
CH_NAME = 'design'
CH2 = 'channel-android'
CH2_NAME = 'android-artifacts'

OWNER = {'type': 'user', 'id': 'visual-user', 'name': 'artin'}
DESIGNER = {'type': 'user', 'id': 'visual-human-designer', 'name': 'designer'}
CINDY = {'type': 'agent', 'id': 'agent-cindy', 'name': 'Cindy'}
PRODUCT_UX = {'type': 'agent', 'id': 'agent-product-ux', 'name': 'Product-UX-Designer'}
ANDROID = {'type': 'agent', 'id': 'agent-android-dev-4', 'name': 'Android-Developer-4'}

LONG_TITLE = ('Rewrite the first-run onboarding checklist so every step explains what it does, what it costs, '
              'and how to undo it, including the keyboard path for people who never touch a mouse, and keep '
              'the wording identical across the web app, the desktop shell, and the Android client')
CJK_TITLE = '整理视觉测试基线：补齐任务看板与任务详情的截图对比'
LONG_DESCRIPTION = (
    'Capture the task board and the task detail modal in all three themes on desktop and mobile, then diff '
    'them against the production Web build.\n\n'
    'Acceptance: every lane (todo, in progress, in review, done, closed) renders with the same card height, '
    'badge colour and spacing; the detail modal keeps the title clamp, the Show more toggle, the History '
    'timeline and the Status / Assignee / Created by row aligned to the same pixel grid as Web. '
    'Record any remaining difference with the case id, the screenshot path and the owner of the fix, and do '
    'not mark the task done before the elegant-dark pass has been reviewed by a second person.')


def iso(day, hhmm):
    return f'2026-06-{day:02d}T{hhmm}:00.000Z'


def task(number, title, status, *, claimed=None, creator=OWNER, channel=CH, desc=None, day=20, tid=None,
         mid=None, thread=None):
    cname = CH_NAME if channel == CH else CH2_NAME
    row = {
        'id': tid or f'task-td-{number}',
        'messageId': mid or f'msg-td-{number}',
        'threadChannelId': thread or f'thread-td-{number}',
        'channelId': channel,
        'channelName': cname,
        'channelType': 'channel',
        'taskNumber': number,
        'title': title,
        'status': status,
        'claimedByType': claimed['type'] if claimed else None,
        'claimedById': claimed['id'] if claimed else None,
        'claimedByName': claimed['name'] if claimed else None,
        'claimedAt': iso(day, '09:30') if claimed else None,
        'completedAt': iso(day + 1, '11:00') if status == 'done' else None,
        'createdById': creator['id'],
        'createdByType': creator['type'],
        'createdByName': creator['name'],
        'createdAt': iso(day, '08:00'),
        'updatedAt': iso(day, '10:00'),
        'source': 'message',
        'revision': 1,
    }
    if desc:
        row['description'] = desc
    return row


# Board: all five statuses, assigned + unassigned, long and CJK titles.
board = [
    task(23, 'Wire the Tasks board to the new status lanes', 'todo', day=24),
    task(22, LONG_TITLE, 'todo', claimed=DESIGNER, creator=CINDY, day=23),
    task(21, CJK_TITLE, 'todo', claimed=CINDY, channel=CH2, day=23),
    task(20, 'Audit elegant-dark tokens on the settings pages', 'in_progress', claimed=CINDY, day=22),
    task(19, 'Fix the mobile thread composer keyboard inset', 'in_progress', claimed=ANDROID, creator=DESIGNER,
         channel=CH2, day=22),
    task(18, 'Unassigned follow-up: collect Android baselines', 'in_progress', day=21),
    task(17, 'Review the release notes for 0.5.31', 'in_review', claimed=PRODUCT_UX, creator=CINDY, day=21),
    task(16, '修复深色主题下的任务徽章对比度', 'in_review', claimed=DESIGNER, channel=CH2, day=20),
    task(15, 'Ship the conversation header parity pass', 'done', claimed=CINDY, day=19),
    task(14, 'Document the extension suite runner', 'done', claimed=ANDROID, creator=CINDY, day=18),
    task(13, 'Replace the placeholder avatars in the member list', 'done', claimed=DESIGNER, channel=CH2, day=17),
    task(12, 'Duplicate of the announcement modal task', 'closed', day=16),
    task(11, 'Drop the legacy sidebar spacing experiment', 'closed', claimed=PRODUCT_UX, creator=DESIGNER, day=15),
]
board_row_by_id = {t['id']: t for t in board}


def event(i, etype, actor, day, hhmm, payload):
    return {'id': f'evt-{i}', 'eventType': etype, 'actorType': actor['type'], 'actorName': actor['name'],
            'createdAt': iso(day, hhmm), 'payload': payload}


def msg(mid, thread, seq, sender, content, day, hhmm):
    return {'id': mid, 'seq': seq, 'channelId': thread, 'messageType': 'chat',
            'senderType': sender['type'], 'senderId': sender['id'], 'senderName': sender['name'],
            'content': content, 'createdAt': iso(day, hhmm), 'reactions': []}


def parent_message(t):
    return {'id': t['messageId'], 'seq': 1, 'channelId': t['channelId'], 'messageType': 'chat',
            'senderType': t['createdByType'], 'senderId': t['createdById'], 'senderName': t['createdByName'],
            'content': t['title'], 'createdAt': t['createdAt'], 'threadId': t['threadChannelId'],
            'reactions': []}


def detail(key, number, title, status, *, claimed=None, creator=OWNER, desc=None, replies=0, history=None,
           interactions=None):
    t = task(number, title, status, claimed=claimed, creator=creator, desc=desc, day=24)
    thread = t['threadChannelId']
    texts = [
        (DESIGNER, 'Picked this up from the design review. The lane order matches the Web board, so I only '
                   'need to check the card spacing.', '09:40'),
        (CINDY, 'Captured the baselines on desktop and mobile. Two cards wrap to three lines in the narrow '
                'lane; the rest are pixel-identical.', '10:05'),
        (OWNER, '收到，先把换行的两张卡片对齐，再处理深色主题。', '10:12'),
        (CINDY, 'Follow-up: the long title case still clamps at three lines in the modal, but the Show more '
                'toggle is missing when the description is exactly three lines long, which makes the layout '
                'jump by one line when the real description loads after the first paint. I will keep this '
                'thread updated with screenshots for every theme until the diff is below the tolerance and '
                'the elegant-dark pass has been reviewed by a second person on the team.', '10:40'),
    ]
    reply_rows = [msg(f'msg-td-{key}-r{i}', thread, 10 + i, s, c, 24, hhmm)
                  for i, (s, c, hhmm) in enumerate(texts[:replies])]
    return {'key': key, 'task': t, 'parent': parent_message(t), 'replies': reply_rows,
            'history': history or []}


history_full = [
    event(1, 'created', OWNER, 24, '08:00', {'taskNumber': 31, 'status': 'todo'}),
    event(2, 'status_changed', CINDY, 24, '09:30', {'from': 'todo', 'to': 'in_progress'}),
    event(3, 'assignee_changed', OWNER, 24, '09:31', {'assigneeType': 'agent', 'assigneeId': CINDY['id']}),
    event(4, 'amended', OWNER, 24, '10:15', {'changes': {'title': {'from': 'Capture task board baselines',
                                                                   'to': 'Capture task board and detail baselines'}}}),
]

details = {
    'empty': detail('empty', 30, 'Wire the Tasks board to the new status lanes', 'todo', claimed=CINDY),
    'replies': detail('replies', 31, 'Align the card spacing with the Web board', 'in_progress', claimed=CINDY,
                      replies=4),
    'replies-short': detail('replies-short', 41, 'Align the card spacing with the Web board', 'in_progress',
                            claimed=CINDY, replies=2),
    'history': detail('history', 31, 'Capture task board and detail baselines', 'in_progress', claimed=CINDY,
                      history=history_full),
    'todo': detail('todo', 32, 'Draft the status lane copy', 'todo', claimed=DESIGNER),
    'in-progress': detail('in-progress', 33, 'Audit elegant-dark tokens', 'in_progress', claimed=CINDY,
                          replies=1),
    'in-review': detail('in-review', 34, 'Review the release notes for 0.5.31', 'in_review', claimed=PRODUCT_UX,
                        creator=CINDY, replies=1),
    'done': detail('done', 35, 'Ship the conversation header parity pass', 'done', claimed=CINDY, replies=1),
    'closed': detail('closed', 36, 'Duplicate of the announcement modal task', 'closed', creator=DESIGNER),
    'unassigned': detail('unassigned', 37, 'Collect Android baselines for the task board', 'todo'),
    'assigned': detail('assigned', 38, 'Collect Android baselines for the task board', 'in_progress',
                       claimed=ANDROID, creator=DESIGNER),
    'long-title': detail('long-title', 39, LONG_TITLE, 'in_progress', claimed=CINDY),
    'description': detail('description', 40, 'Capture the task board and detail baselines', 'in_progress',
                          claimed=CINDY, desc=LONG_DESCRIPTION),
}

fixture = {
    'name': 'raft-flutter parity extension: tasks board + task detail',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'serverId': SID,
    'channels': [
        {'id': CH, 'serverId': SID, 'name': CH_NAME, 'description': 'Product and UI decisions', 'type': 'channel',
         'createdAt': '2026-06-18T00:00:00.000Z', 'joined': True},
        {'id': CH2, 'serverId': SID, 'name': CH2_NAME, 'description': 'Builds and screenshots', 'type': 'channel',
         'createdAt': '2026-06-18T00:00:00.000Z', 'joined': True},
    ],
    'board': board,
    'details': details,
    # Channel roster both providers serve for `GET /channels/<id>/members`
    # (assignee candidates, created-by display names).
    'members': {
        'humans': [
            {'id': 'visual-user', 'name': 'artin', 'displayName': 'artin', 'description': 'Owner',
             'avatarUrl': None, 'gravatarHash': '', 'role': 'owner', 'serverRole': 'owner',
             'channelRole': 'member', 'effectiveChannelRole': 'member', 'channelAdminBasis': 'none',
             'canChangeChannelRole': False},
            {'id': 'visual-human-designer', 'name': 'designer', 'displayName': 'Designer',
             'description': 'Product design', 'avatarUrl': None, 'gravatarHash': '', 'role': 'member',
             'serverRole': 'member', 'channelRole': 'member', 'effectiveChannelRole': 'member',
             'channelAdminBasis': 'none', 'canChangeChannelRole': False},
        ],
        'agents': [
            {'id': 'agent-cindy', 'serverId': SID, 'name': 'Cindy', 'displayName': 'Cindy',
             'avatarUrl': 'pixel:robot', 'description': 'Keeps visual testing release notes aligned.',
             'status': 'active', 'serverRole': 'member', 'deletedAt': None},
            {'id': 'agent-product-ux', 'serverId': SID, 'name': 'Product-UX-Designer',
             'displayName': 'Product UX Designer', 'avatarUrl': 'pixel:robot',
             'description': 'Turns product feedback into UX specs.', 'status': 'active',
             'serverRole': 'member', 'deletedAt': None},
            {'id': 'agent-android-dev-4', 'serverId': SID, 'name': 'Android-Developer-4',
             'displayName': 'Android Developer 4', 'avatarUrl': 'pixel:robot',
             'description': 'Implements shared Android/KMP UI fixes.', 'status': 'active',
             'serverRole': 'member', 'deletedAt': None},
        ],
        'externalMembers': [],
    },
}

# Endpoints both providers answer from this fixture. Web: page.route (provider
# spec patch `parityExtRoutes`, `routes` + the case's `routeSet`); Flutter:
# the fixture client in cases/ext_task_detail.dart.
routes = {
    'GET /channels': fixture['channels'],
    'GET /channels/dm': [],
    f'GET /channels/{CH}/members': fixture['members'],
    f'GET /channels/{CH2}/members': fixture['members'],
    'GET /agents': fixture['members']['agents'],
    'GET /tasks/server': {'tasks': board},
    'GET /channels/threads/followers': {'threads': []},
}
route_sets = {}
for key, d in details.items():
    t = d['task']
    route_sets[f'td-{key}'] = {
        f'GET /tasks/channel/{CH}': {'tasks': [t]},
        f'GET /tasks/{t["id"]}/history': {'events': d['history']},
        f'GET /channels/{CH}/threads/{t["messageId"]}': {'threadChannelId': t['threadChannelId']},
        f'GET /messages/context/{t["messageId"]}': {'messages': [d['parent']], 'targetMessageId': t['messageId']},
        f'GET /messages/channel/{t["threadChannelId"]}': {'messages': d['replies'], 'hasMore': False},
    }
fixture['routes'] = routes
fixture['routeSets'] = route_sets

cases = []


def base_case(cid, title, surface, platform, theme, props, capture, hint, android_hint):
    return {
        'id': cid,
        'title': title,
        'captureType': 'component-fixture',
        'surface': surface,
        'category': f'extension/{surface}',
        'suite': 'raft-flutter-extension',
        'viewport': DESKTOP if platform == 'desktop' else MOBILE,
        'theme': theme,
        'locale': 'en',
        'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
        'capture': capture,
        'reactPathHint': hint,
        'androidCaseHint': android_hint,
        'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
    }


def add_page(platform, state, title, *, interactions=(), android=(), notes=None):
    for suffix, theme in THEMES.items():
        cid = f'{PAGE_PREFIX}{platform}.{state}.{suffix}'
        props = {'extCase': f'{platform}.{state}', 'extKind': 'taskspage', 'parityTheme': theme,
                 'platform': platform, 'state': state}
        # Desktop crops the Tasks column (the main column right of the rail),
        # mobile the whole page (the floating tab bar overlays the list).
        capture = {
            'selector': '[data-testid="thread-main-column"]' if platform == 'desktop' else 'body',
            'crop': 'element' if platform == 'desktop' else 'viewport',
            'contract': 'component-bounds' if platform == 'desktop' else 'viewport-with-portal',
            'interactions': list(interactions), 'androidInteractions': list(android),
        }
        c = base_case(cid, f'Tasks page {platform} {title} ({theme})', 'taskspage', platform, theme, props, capture,
                      'packages/web/src/components/task/TasksPanel.tsx (+ TaskCard, layout/MainLayout.tsx)',
                      f"apps/raft_flutter/test/parity/cases/ext_task_detail.dart '{platform}.{state}'")
        if notes:
            c['notes'] = notes
        cases.append(c)


def add_detail(platform, state, key, title, *, interactions=(), android=(), notes=None):
    for suffix, theme in THEMES.items():
        cid = f'{DETAIL_PREFIX}{platform}.{state}.{suffix}'
        props = {'extCase': f'{platform}.{state}', 'extKind': 'taskdetail', 'parityTheme': theme,
                 'platform': platform, 'state': state, 'detail': key, 'routeSet': f'td-{key}'}
        # The selector only gates the capture (Playwright waits for the lazy
        # TaskModalHead title); the `viewport-with-portal` contract still captures
        # the whole viewport, like Flutter.
        capture = {'selector': '[data-testid="task-modal-title"]', 'crop': 'viewport',
                   'contract': 'viewport-with-portal',
                   'interactions': list(interactions), 'androidInteractions': list(android)}
        c = base_case(cid, f'Task detail {platform} {title} ({theme})', 'taskdetail', platform, theme, props,
                      capture,
                      'packages/web/src/components/task/TaskModalHead.tsx + layout/MainLayout.tsx '
                      '(TaskModalBar, ThreadPanelWrapper)',
                      f"apps/raft_flutter/test/parity/cases/ext_task_detail.dart '{platform}.{state}'")
        if notes:
            c['notes'] = notes
        cases.append(c)


EXPAND = [{'type': 'click', 'target': f'[aria-label="Show {label}"]'} for label in ('Done', 'Closed')]
EXPAND_ANDROID = [{'type': 'tap', 'key': f'task-group-{s}'} for s in ('done', 'closed')]
for platform in ['desktop', 'mobile']:
    add_page(platform, 'board', 'board (platform default view; done/closed collapsed)',
             notes='Web opens in board view on desktop and list view on mobile; Done and Closed start collapsed.')
    # Mobile (list view) is not covered: the Done / Closed triggers sit far below
    # the first screen and the final scroll offset after the two taps differs
    # between Playwright's scrollIntoView and the lazy Flutter list.
    if platform == 'desktop':
        add_page(platform, 'expanded', 'with Done and Closed expanded', interactions=EXPAND,
                 android=EXPAND_ANDROID)

HISTORY_TOGGLE = [{'type': 'click', 'target': 'button:has-text("History")'}]
STATES = [
    ('empty', 'empty', 'no replies', ()),
    ('replies', 'replies', 'replies from a human and an agent', ()),
    ('replies-short', 'replies-short', 'two short replies (no scrolling)', ()),
    ('history-open', 'history', 'History expanded', HISTORY_TOGGLE),
    ('status-todo', 'todo', 'status todo', ()),
    ('status-in-progress', 'in-progress', 'status in progress', ()),
    ('status-in-review', 'in-review', 'status in review', ()),
    ('status-done', 'done', 'status done (assignee read-only)', ()),
    ('status-closed', 'closed', 'status closed', ()),
    ('unassigned', 'unassigned', 'unassigned', ()),
    ('assigned', 'assigned', 'assigned', ()),
    ('long-title', 'long-title', 'long title (three-line clamp)', ()),
    ('description', 'description', 'long description (Show more)', ()),
]
for platform in ['desktop', 'mobile']:
    for state, key, title, interactions in STATES:
        android = [{'type': 'tap', 'key': 'task-properties-history'}] if state == 'history-open' else []
        add_detail(platform, state, key, title, interactions=interactions, android=android)

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases']
                     if not c['id'].startswith((PAGE_PREFIX, DETAIL_PREFIX))] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/taskdetail.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} task board / detail cases appended -> the run-time manifest ($PARITY_EXT_MANIFEST); '
      'fixture -> tool/parity-ext/fixtures/taskdetail.json')
