#!/usr/bin/env python3
"""Append the conversation-page cases (inventory area 3, the rows that had no case) to the run-time
manifest ($PARITY_EXT_MANIFEST) and write tool/parity-ext/fixtures/conversation.json.

Run after build-cases.py and the other builders; idempotent: every `components.conversation.*`
case is replaced, all other cases are kept.

Derivation (raft-source 26f77ef, packages/web/src):
  components/message/ChatPanel.tsx   "Select a channel" empty main (channel=null); the footer state
                                     banners (archived + Unarchive, guest read-only, guest / member
                                     Join CTA, joint locked, joint over-limit grace), the "message not
                                     found" banner above the timeline
Not reachable in the pinned Web source, so no case (inventory 3.06): read-only quota (shared
PLAN_CONFIG maxChannels is -1 for every plan, so isReadOnlyByQuota is always false) and "Chat is
unavailable" (ChatPanel `readOnly` is passed by the visual-testing host only).
Ids: components.conversation.<scene>.<platform>.<state>.<theme>. React mounts the real ChatPanel /
ThreadPanel / MessageItem; Flutter mounts the real WorkspaceView / RaftChatView and clips the same window.
Data: tool/parity-ext/fixtures/conversation.json (`routes` + `routeSets`, answered identically by both
providers; every case pins `extFixture` so the other families' routes do not shadow them).
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
PREFIX = 'components.conversation.'
SID = 'visual-server'
CREATED = '2026-06-18T00:00:00.000Z'
OWNER = {'id': 'visual-user', 'name': 'artin', 'displayName': 'artin', 'type': 'user'}
DESIGNER = {'id': 'visual-human-designer', 'name': 'designer', 'displayName': 'Designer', 'type': 'user'}
CINDY = {'id': 'agent-cindy', 'name': 'Cindy', 'displayName': 'Cindy', 'type': 'agent'}


class Seq:
    n = 0


def msg(mid, channel, sender, content, created, **extra):
    Seq.n += 1
    m = {
        'id': mid, 'seq': Seq.n, 'serverId': SID, 'channelId': channel, 'messageType': 'chat',
        'senderType': sender['type'], 'senderId': sender['id'], 'senderName': sender['name'],
        'content': content, 'createdAt': created,
    }
    m.update(extra)
    return m


def page(messages, has_more=False, history_limited=False, summaries=None):
    return {'messages': messages, 'hasMore': has_more, 'historyLimited': history_limited,
            'threadSummariesByParentMessageId': summaries or {}}


def channel(cid, name, description='Visual testing release gates', ctype='channel', **extra):
    c = {'id': cid, 'serverId': SID, 'name': name, 'description': description, 'type': ctype,
         'createdAt': CREATED, 'joined': True}
    c.update(extra)
    return c


# ---- channels (one per footer state) --------------------------------------
GRACE_ENDS = '2026-06-21T09:00:00.000Z'
QUOTE_CH = 'cafe0000-0000-0000-0000-0000000000a1'
QUOTE_CH_ARCHIVED = 'cafe0000-0000-0000-0000-0000000000a2'
QUOTE_MSG = {k: f'beef0000-0000-0000-0000-00000000000{i}' for i, k in enumerate(['text', 'attachment', 'archived'], 1)}
channels = [
    channel('channel-cv-open', 'design'),
    channel('channel-cv-archived', 'design-archive', archivedAt='2026-06-10T08:00:00.000Z'),
    channel('channel-cv-guest', 'guest-room'),
    channel('channel-cv-guest-join', 'guest-lobby', guestJoinable=True, joined=False),
    channel('channel-cv-join', 'product', joined=False),
    channel('channel-cv-joint-locked', 'joint-design', ctype='joint', jointBillingLocked=True),
    channel('channel-cv-joint-grace', 'joint-review', ctype='joint', jointOverLimitGraceEndsAt=GRACE_ENDS),
    channel(QUOTE_CH, 'product', 'Release tracking and acceptance'),
    channel(QUOTE_CH_ARCHIVED, 'old-product', 'Release tracking and acceptance', archivedAt='2026-06-10T08:00:00.000Z'),
]
T = '2026-06-22T02:30:00.000Z'


def channel_page(cid):
    Seq.n = 0
    return page([
        msg(f'msg-{cid}-1', cid, OWNER, 'Release gates are green for the Android capture.', '2026-06-22T02:10:00.000Z'),
        msg(f'msg-{cid}-2', cid, CINDY, 'Captured the visual baselines and queued React parity.', T),
    ])


routes = {
    'GET /channels/threads/followers': {'threads': []},
    'GET /channels/threads/followed': {'threads': []},
}
for c in channels:
    routes[f'GET /messages/channel/{c["id"]}'] = channel_page(c['id'])
    routes[f'GET /tasks/channel/{c["id"]}'] = {'tasks': []}

# ---- message rows (view=row: one MessageItem on a panel-coloured box) -----------
ROW_AT = '2026-06-22T02:30:00.000Z'


def row_msg(mid, sender, content, **extra):
    return {'id': mid, 'seq': 1, 'serverId': SID, 'channelId': 'channel-design', 'messageType': 'chat',
            'senderType': sender['type'], 'senderId': sender['id'], 'senderName': sender['name'],
            'content': content, 'createdAt': ROW_AT, **extra}


rows = {
    'profile-agent': {'message': row_msg('msg-cv-profile-agent', CINDY, 'Captured the visual baselines and queued React parity.')},
    'profile-human': {'message': row_msg('msg-cv-profile-human', DESIGNER, 'Reviewing the diffs after lunch.')},
}


def action_row(mid, content, action, state='prepared', **meta):
    return {'message': row_msg(mid, CINDY, content, actionMetadata={
        'kind': 'action-card', 'sourceServerId': SID, 'action': action, 'state': state,
        'confirmationVersion': 1, **meta})}


rows['action-install-app'] = action_row(
    'msg-cv-action-install', 'I prepared the install so you can approve it.',
    {'type': 'integration:install_marketplace_app', 'clientId': 'client-acme-notes', 'clientKey': 'acme-notes',
     'clientName': 'Acme Notes', 'clientNameSha256': 'a' * 64, 'agentId': CINDY['id'], 'agentName': 'Cindy',
     'scopes': ['openid', 'profile', 'agent:read']})
rows['action-create-agent'] = action_row(
    'msg-cv-action-agent', 'Here is the agent I would like to create.',
    {'type': 'agent:create', 'name': 'release-bot', 'description': 'Watches the release gates and posts diff links.',
     'suggestedComputer': 'computer-mbp'})
rows['action-channel-members'] = action_row(
    'msg-cv-action-members', 'These people should be in the channel.',
    {'type': 'channel:add_member', 'channel': 'channel-design', 'humans': [DESIGNER['id']], 'agents': [CINDY['id']]})
rows['action-owner-recovery'] = action_row(
    'msg-cv-action-recovery', 'The app owner needs to be recovered.',
    {'type': 'integration:recover_app_owner', 'clientKey': 'acme-notes', 'targetAgent': CINDY['id']})
rows['action-executed'] = action_row(
    'msg-cv-action-done', 'Here is the agent I would like to create.',
    {'type': 'agent:create', 'name': 'release-bot', 'description': 'Watches the release gates and posts diff links.'},
    state='executed', executedAt='2026-06-22T02:40:00.000Z', executedByUserId='visual-user',
    executedByUserName='artin', result={'kind': 'agent', 'id': 'agent-release-bot', 'name': 'release-bot'})

# message context menu rows (same message / thread / task as the official menu cases)
MENU_THREAD = {'threadChannelId': 'thread-cv-menu', 'replyCount': 3, 'participantIds': [CINDY['id'], OWNER['id']],
               'unreadCount': 0, 'firstUnreadMessageId': None, 'lastReplyAt': '2026-06-22T02:35:00.000Z'}
rows['menu-default'] = {'message': row_msg('msg-cv-menu-default', CINDY, 'Captured the visual baselines and queued React parity.',
                                           threadId='thread-cv-menu', reactions=[{'emoji': '\U0001F44D', 'count': 2, 'reactorIds': [OWNER['id']], 'reactorNames': [OWNER['name']]}]),
                        'threadSummary': MENU_THREAD}
rows['menu-task'] = {'message': rows['menu-default']['message'] | {'id': 'msg-cv-menu-task'},
                     'threadSummary': MENU_THREAD,
                     'linkedTask': {'id': 'task-cv-246', 'messageId': 'msg-cv-menu-task', 'channelId': 'channel-design',
                                    'channelName': 'design', 'channelType': 'channel', 'taskNumber': 246,
                                    'title': 'Message context menu visual coverage', 'status': 'in_progress',
                                    'claimedByType': 'agent', 'claimedById': CINDY['id'], 'claimedByName': CINDY['displayName'],
                                    'claimedAt': '2026-06-22T02:31:00.000Z', 'completedAt': None, 'createdById': OWNER['id'],
                                    'createdByType': 'user', 'createdByName': OWNER['name'],
                                    'createdAt': '2026-06-22T02:30:00.000Z', 'updatedAt': '2026-06-22T02:31:00.000Z'}}

# reaction chip rows
rows['reactions-single'] = {'message': row_msg('msg-cv-react-single', CINDY, 'Captured the visual baselines and queued React parity.',
                                               reactions=[{'emoji': '\U0001F44D', 'count': 2, 'reactorIds': [OWNER['id'], DESIGNER['id']],
                                                           'reactorNames': [OWNER['name'], DESIGNER['displayName']]}])}
rows['reactions-multi'] = {'message': row_msg('msg-cv-react-multi', CINDY, 'Captured the visual baselines and queued React parity.',
                                              reactions=[
                                                  {'emoji': '\U0001F44D', 'count': 2, 'reactorIds': [OWNER['id'], DESIGNER['id']],
                                                   'reactorNames': [OWNER['name'], DESIGNER['displayName']]},
                                                  {'emoji': '\U0001F389', 'count': 1, 'reactorIds': [DESIGNER['id']],
                                                   'reactorNames': [DESIGNER['displayName']]},
                                                  {'emoji': '\u2764\ufe0f', 'count': 12, 'reactorIds': [DESIGNER['id']],
                                                   'reactorNames': [DESIGNER['displayName']]},
                                                  {'emoji': '\U0001F680', 'count': 3, 'reactorIds': [CINDY['id']],
                                                   'reactorNames': [CINDY['displayName']]}])}

# quoted message permalink rows (the preview card under a message that links another message)
def permalink(channel_id, message_id):
    return f'__ORIGIN__/s/visual/channel/{channel_id}?msg={message_id}'


QUOTE_TARGETS = {
    'text': (QUOTE_CH, row_msg(QUOTE_MSG['text'], DESIGNER, 'The release gates are green for the Android capture, so we can publish the baselines.') | {'channelId': QUOTE_CH}),
    'attachment': (QUOTE_CH, row_msg(QUOTE_MSG['attachment'], CINDY, 'Notes attached.') | {'channelId': QUOTE_CH,
        'attachments': [{'id': 'att-cv-q1', 'filename': 'visual-parity-notes.pdf', 'mimeType': 'application/pdf', 'sizeBytes': 188416}]}),
    'archived': (QUOTE_CH_ARCHIVED, row_msg(QUOTE_MSG['archived'], OWNER, 'This thread moved to the new channel.') | {'channelId': QUOTE_CH_ARCHIVED}),
}
for key, (qch, target) in QUOTE_TARGETS.items():
    routes[f'GET /messages/context/{target["id"]}'] = {
        'messages': [target], 'targetMessageId': target['id'], 'hasOlder': False, 'hasNewer': False,
        'channelArchived': key == 'archived'}
    rows[f'quote-{key}'] = {'message': row_msg(f'msg-cv-quote-{key}', OWNER, 'Context for this change: ' + permalink(qch, target['id']))}
rows['quote-loading'] = {'message': row_msg('msg-cv-quote-loading', OWNER, 'Context for this change: ' + permalink(QUOTE_CH, QUOTE_MSG['text']))}
rows['quote-unavailable'] = {'message': row_msg('msg-cv-quote-unavailable', OWNER, 'Context for this change: ' + permalink(QUOTE_CH, QUOTE_MSG['text']))}

# external (Slack-projected) sender
EXTERNAL_AUTHOR = {'provider': 'slack', 'appRegistrationId': 'cv-slack-app', 'installId': 'cv-slack-install',
                   'workspaceId': 'opaque-workspace-id-not-rendered', 'workspaceName': 'Acme Product Studio',
                   'externalActorId': 'cv-slack-actor', 'externalConversationId': 'cv-slack-channel',
                   'externalMessageId': 'cv-slack-message', 'displayName': 'Ada Lovelace', 'actorKind': 'human',
                   'avatarUrl': None, 'avatarDigest': None, 'actorProjectionRevision': 1}
rows['external-slack'] = {'message': row_msg('msg-cv-external', {'type': 'external_projection', 'id': 'cv-slack-actor',
                                                                  'name': 'Ada Lovelace'},
                                              'Posted from Slack: the staging build is ready for review.',
                                              externalAuthor=EXTERNAL_AUTHOR)}

rows['translate'] = {'message': row_msg('msg-cv-translate', CINDY, 'Captured the visual baselines and queued React parity.')}

rows['mermaid'] = {'message': row_msg('msg-cv-mermaid', CINDY, 'The capture flow:\n\n```mermaid\nflowchart LR\n  A[Capture] --> B{Match?}\n  B -->|yes| C[Ship]\n  B -->|no| D[Fix]\n```')}


def attach_row(name, filename, mime, size, **extra):
    return {'message': row_msg(f'msg-cv-attach-{name}', CINDY, 'Attached for review.', attachments=[
        {'id': f'att-cv-{name}', 'filename': filename, 'mimeType': mime, 'sizeBytes': size, **extra}])}


rows['attach-audio'] = attach_row('audio', 'standup-recording.mp3', 'audio/mpeg', 2411520)
rows['attach-video'] = attach_row('video', 'capture-walkthrough.mp4', 'video/mp4', 18874368, width=1280, height=720)
# Message video card states (components.conversation.attach.<platform>.video-*): a playable portrait
# clip (a flat-colour 360x640 WebM the Web <video> decodes; the Flutter case draws the same colour in a
# fake player) and an undecodable one. The data: URL answers GET /attachments/<id>/url.
import base64  # noqa: E402
VIDEO_OK = base64.b64encode((here / 'fixtures/message-video-portrait.webm').read_bytes()).decode()
rows['attach-video-ok'] = attach_row('video-ok', 'phone-clip.webm', 'video/webm', 9000, width=360, height=640)
rows['attach-video-bad'] = attach_row('video-bad', 'broken-clip.mp4', 'video/mp4', 4096)
routes['GET /attachments/att-cv-video-ok/url'] = {'url': f'data:video/webm;base64,{VIDEO_OK}'}
routes['GET /attachments/att-cv-video-bad/url'] = {'url': 'data:video/mp4;base64,AAAAAAAA'}
rows['attach-pdf'] = attach_row('pdf', 'visual-parity-notes.pdf', 'application/pdf', 188416, commentCount=2)
rows['attach-patch'] = attach_row('patch', 'composer-spacing.patch', 'text/x-diff', 6144)
ACTIVITY_LOG = [
    {'timestamp': 1782095100000, 'entry': {'kind': 'thinking', 'text': 'Planning the Android capture run'}},
    {'timestamp': 1782095160000, 'entry': {'kind': 'tool_start', 'toolName': 'Bash'}},
    {'timestamp': 1782095220000, 'entry': {'kind': 'text', 'text': 'Captured 42 cases, 3 need review'}},
    {'timestamp': 1782095280000, 'entry': {'kind': 'tool_start', 'toolName': 'Read'}},
    {'timestamp': 1782095340000, 'entry': {'kind': 'thinking', 'text': 'Comparing the elegant-dark borders'}},
]

route_sets = {
    'quote-loading': {f'GET /messages/context/{QUOTE_MSG["text"]}': {'$pending': True}},
    'quote-unavailable': {f'GET /messages/context/{QUOTE_MSG["text"]}': {'$status': 404, '$body': {'error': 'Message not found'}}},
    'activity': {'GET /agents/agent-cindy/activity-log': ACTIVITY_LOG},
    # ?msg=<missing id>: the message context 404s -> "message not found" banner.
    'msg-missing': {'GET /messages/context/msg-missing': {'$status': 404, '$body': {'error': 'Message not found'}}},
}

# ---- channel Files / Tasks tabs ---------------------------------------------------------------
def file_entry(i, name, mime, size, at, uploader=OWNER):
    return {'id': f'file-cv-{i}', 'messageId': f'msg-cv-file-{i}', 'channelId': 'channel-cv-open', 'filename': name,
            'mimeType': mime, 'sizeBytes': size, 'width': None, 'height': None, 'thumbnailUrl': None, 'createdAt': at,
            'uploader': {'type': uploader['type'], 'id': uploader['id'], 'name': uploader['name'],
                         'displayName': uploader['displayName']},
            'source': {'type': 'channel', 'channelId': 'channel-cv-open', 'parentMessageId': None,
                       'parentMessageShortId': None}}


FILES = [
    file_entry(1, 'visual-parity-notes.pdf', 'application/pdf', 188416, '2026-06-22T02:30:00.000Z'),
    file_entry(2, 'release-checklist.md', 'text/markdown', 4096, '2026-06-21T09:10:00.000Z', CINDY),
    file_entry(3, 'android-baselines.zip', 'application/zip', 52428800, '2026-06-20T15:45:00.000Z', DESIGNER),
    file_entry(4, 'capture-log.txt', 'text/plain', 1536, '2026-06-19T11:00:00.000Z', CINDY),
]
FILES_ROUTE = 'GET /channels/channel-cv-open/files'
TASKS_ROUTE = 'GET /tasks/channel/channel-cv-open'


def task_row(i, number, title, status, claimed=True, at='2026-06-22T02:30:00.000Z'):
    return {'id': f'task-cv-{i}', 'messageId': f'msg-cv-task-{i}', 'channelId': 'channel-cv-open', 'channelName': 'design',
            'channelType': 'channel', 'taskNumber': number, 'title': title, 'status': status,
            'claimedByType': 'agent' if claimed else None, 'claimedById': CINDY['id'] if claimed else None,
            'claimedByName': CINDY['displayName'] if claimed else None, 'claimedAt': at if claimed else None,
            'completedAt': at if status == 'done' else None, 'createdById': OWNER['id'], 'createdByType': 'user',
            'createdByName': OWNER['name'], 'createdAt': at, 'updatedAt': at}


TASKS = [
    task_row(1, 41, 'Compare the elegant-dark borders', 'in_progress'),
    task_row(2, 42, 'Review the composer attachment cases', 'todo', claimed=False),
    task_row(3, 43, 'Publish the parity report', 'in_review'),
    task_row(4, 40, 'Capture the Android baselines', 'done'),
]
route_sets.update({
    'files-list': {FILES_ROUTE: {'files': FILES, 'nextCursor': None}},
    'files-more': {FILES_ROUTE: {'files': FILES, 'nextCursor': 'cursor-2'}},
    'files-empty': {FILES_ROUTE: {'files': [], 'nextCursor': None}},
    'files-loading': {FILES_ROUTE: {'$pending': True}},
    'files-error': {FILES_ROUTE: {'$status': 500, '$body': {'error': 'Internal Server Error'}}},
    'tasks-list': {TASKS_ROUTE: {'tasks': TASKS}},
    'tasks-empty': {TASKS_ROUTE: {'tasks': []}},
})

# ---- threads (3.37 states, 3.38 search, 3.39 followers) -----------------------------------------
THREADS = {
    'main': {'parentChannelId': 'channel-cv-open', 'parentMessageId': 'msg-cv-tp', 'threadChannelId': 'thread-cv-1'},
    'joint': {'parentChannelId': 'channel-cv-joint-locked', 'parentMessageId': 'msg-cvj-tp', 'threadChannelId': 'thread-cvj-1'},
    'join': {'parentChannelId': 'channel-cv-join', 'parentMessageId': 'msg-cvn-tp', 'threadChannelId': 'thread-cvn-1'},
}
THREAD_SET = {}
for key, t in THREADS.items():
    Seq.n = 0
    # Server order (seq) follows the timestamps: the plain messages come first.
    extras = [msg('msg-cv-sel-1', t['parentChannelId'], OWNER, 'Release gates are green for the Android capture.',
                  '2026-06-22T02:10:00.000Z'),
              msg('msg-cv-sel-2', t['parentChannelId'], DESIGNER, 'Reviewing the diffs after lunch.',
                  '2026-06-22T02:20:00.000Z')] if key == 'main' else []
    parent = msg(t['parentMessageId'], t['parentChannelId'], CINDY,
                 'Captured the Android visual artifact for the parity run and queued React parity.',
                 '2026-06-22T02:30:00.000Z', threadId=t['threadChannelId'])
    replies = [
        msg(f'{t["parentMessageId"]}-r1', t['threadChannelId'], OWNER, 'Looks good. Can you also attach the elegant-dark capture?', '2026-06-22T02:35:00.000Z'),
        msg(f'{t["parentMessageId"]}-r2', t['threadChannelId'], CINDY, 'Done: the dark baseline is attached to the task and the parity diff is under 2%.', '2026-06-22T02:41:00.000Z'),
        msg(f'{t["parentMessageId"]}-r3', t['threadChannelId'], DESIGNER, 'One spacing question on the composer: is the 12px gap intentional?', '2026-06-22T03:02:00.000Z'),
    ]
    summary = {'threadChannelId': t['threadChannelId'], 'replyCount': 3, 'lastReplyAt': '2026-06-22T03:02:00.000Z',
               'participantIds': [OWNER['id'], CINDY['id'], DESIGNER['id']], 'unreadCount': 0, 'firstUnreadMessageId': None}
    THREAD_SET.update({
        f'GET /messages/channel/{t["threadChannelId"]}': page(replies),
        f'GET /messages/context/{t["parentMessageId"]}': {'messages': [parent], 'hasMore': False, 'hasNewer': False},
        f'GET /messages/channel/{t["parentChannelId"]}': page(
            extras + [parent],
            summaries={t['parentMessageId']: summary}),
    })
routes.update(THREAD_SET)
FOLLOWERS = {'GET /channels/threads/followers': {'threads': [{
    'threadChannelId': 'thread-cv-1', 'canManage': True,
    'agents': [{'id': CINDY['id'], 'name': 'Cindy', 'displayName': 'Cindy', 'status': 'active', 'avatarUrl': 'pixel:robot',
                'isCurrentServer': True, 'canRemove': True},
               {'id': 'agent-product-ux', 'name': 'product-ux', 'displayName': 'Product UX', 'status': 'active',
                'avatarUrl': 'pixel:robot', 'isCurrentServer': True, 'canRemove': True}]}]}}
route_sets.update({
    # The thread open (resolution) fails: Flutter's ThreadPanel shows its load error with Retry.
    'thread-failed': {'GET /channels/channel-cv-open/threads/msg-cv-tp': {'$status': 500, '$body': {'error': 'Internal Server Error'}}},
    'translation': {
        'GET /servers/visual-server/translation-settings': {'translationEnabled': True, 'translationAvailable': True,
                                                            'canManageTranslation': False},
        'POST /message-translations:batch': {'results': [{
            'messageId': 'msg-cv-translate', 'status': 'translated', 'sourceLanguage': 'en', 'targetLanguage': 'zh-cn',
            'translatedContent': '已截取视觉基线，并将 React 对照排入队列。'}]}},
    'translation-pending': {
        'GET /servers/visual-server/translation-settings': {'translationEnabled': True, 'translationAvailable': True,
                                                            'canManageTranslation': False},
        'POST /message-translations:batch': {'$pending': True}},
    'translation-failed': {
        'GET /servers/visual-server/translation-settings': {'translationEnabled': True, 'translationAvailable': True,
                                                            'canManageTranslation': False},
        'POST /message-translations:batch': {'$status': 500, '$body': {'error': 'provider', 'reason': 'provider'}}},
    'followers': FOLLOWERS,
    'followers-error': {'GET /channels/threads/followers': {'$status': 500, '$body': {'error': 'Internal Server Error'}}},
    'followers-remove': {**FOLLOWERS,
                         'DELETE /channels/threads/thread-cv-1/followers/agents/agent-product-ux': {'removed': True, 'undoToken': 'undo-1'}},
})

fixture = {
    'name': 'raft-flutter parity extension: conversation pages',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'channels': channels,
    'dms': [],
    'threads': THREADS,
    'externalProfile': EXTERNAL_AUTHOR,
    'rows': rows,
    'routes': routes,
    'routeSets': {f'cv-{k}': v for k, v in route_sets.items()},
}

cases = []


def add(scene, platform, state, title, *, props=None, win=(0, 120), interactions=(), android=(), view='window',
        notes=None, route_set=None, hint=None, selector=None, android_key=None):
    """win = (y, height) in column coordinates; y < 0 counts from the bottom."""
    viewport = DESKTOP if platform == 'desktop' else MOBILE
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{scene}.{platform}.{state}.{suffix}'
        p = {'extCase': f'{scene}.{platform}.{state}', 'extKind': 'conversation', 'extFixture': 'conversation',
             'parityTheme': theme, 'platform': platform, 'view': view, 'winY': win[0], 'winH': win[1]}
        if route_set:
            p['routeSet'] = f'cv-{route_set}'
        p.update(props or {})
        c = {
            'id': cid,
            'title': f'{title} {platform} ({theme})',
            'captureType': 'component-fixture',
            'surface': f'conversation-{scene}',
            'category': 'extension/conversation',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': p}],
            'capture': {'selector': selector or f"[data-visual-case='{cid}']", 'crop': 'element',
                        'contract': 'component-bounds', 'interactions': list(interactions),
                        'androidInteractions': list(android)},
            'reactPathHint': hint or 'packages/web/src/components/message/ChatPanel.tsx',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_conversation_pages.dart '{scene}.{platform}.{state}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if android_key:
            c['capture']['androidKey'] = android_key
        if notes:
            c['notes'] = notes
        cases.append(c)


# ---- 3.03 no conversation selected (desktop main column) ---------------------
add('empty', 'desktop', 'no-channel', 'No conversation selected', props={'surface': 'chat', 'chan': ''},
    win=(0, 800), notes='ChatPanel channel=null: the centred "Select a channel" line.')

# ---- 3.06 channel state banners ----------------------------------------------
for platform in ('desktop', 'mobile'):
    footer = (-140, 140)
    chat = {'surface': 'chat'}
    add('banner', platform, 'archived', 'Archived channel footer', props={**chat, 'chan': 'channel-cv-archived'},
        win=footer)
    add('banner', platform, 'archived-header', 'Archived channel header badge',
        props={**chat, 'chan': 'channel-cv-archived'}, win=(0, 120))
    add('banner', platform, 'guest-readonly', 'Guest read-only footer',
        props={**chat, 'chan': 'channel-cv-guest', 'serverRole': 'guest'}, win=footer)
    add('banner', platform, 'guest-join', 'Guest join footer',
        props={**chat, 'chan': 'channel-cv-guest-join', 'serverRole': 'guest'}, win=footer)
    add('banner', platform, 'join', 'Join channel footer', props={**chat, 'chan': 'channel-cv-join'},
        win=footer)
    add('banner', platform, 'joint-locked', 'Joint channel locked footer',
        props={**chat, 'chan': 'channel-cv-joint-locked'}, win=footer)
    add('banner', platform, 'joint-grace', 'Joint channel over-limit grace banner above the composer',
        props={**chat, 'chan': 'channel-cv-joint-grace'}, win=(-240, 240))
    add('banner', platform, 'message-not-found', 'Message not found banner',
        props={**chat, 'chan': 'channel-cv-open', 'msg': 'msg-missing'}, win=(0, 240),
        route_set='msg-missing')

# ---- 3.27 profile preview card / 3.28 mention hover activity preview (desktop: hover only) --------
CARD = '[data-slot="preview-card-content"]'


def avatar(row_id, kind):
    return f'#message-{row_id} [data-avatar-kind="{kind}"]'


for state, row, kind, rs in (('agent', 'profile-agent', 'agent', None), ('agent-activity', 'profile-agent', 'agent', 'activity'),
                              ('human', 'profile-human', 'human', None)):
    rid = rows[row]['message']['id']
    add('profile', 'desktop', state, f'Profile preview card ({state})', view='row',
        props={'row': row, 'boxWidth': 440, 'boxHeight': 112}, route_set=rs, selector=CARD,
        android_key='raft-hover-card-surface', hint='packages/web/src/components/message/ProfilePreviewCardContent.tsx',
        interactions=[{'type': 'hover', 'target': avatar(rid, kind)}, {'type': 'wait', 'ms': 700}],
        notes='Pointer rests on the sender avatar; the 280px hover card (delay 200ms).')

# ---- 3.31 action card in a message (desktop 560 box / phone 390) ----------------
for state, row in (('install-app', 'action-install-app'), ('create-agent', 'action-create-agent'),
                   ('channel-members', 'action-channel-members'), ('owner-recovery', 'action-owner-recovery'),
                   ('executed', 'action-executed')):
    add('action', 'desktop', state, f'Action card ({state})', view='row',
        props={'row': row, 'boxWidth': 560, 'padX': 16, 'padTop': 8}, hint='packages/web/src/components/actions/ActionCard.tsx')
    add('action', 'mobile', state, f'Action card ({state})', view='row',
        props={'row': row, 'boxWidth': 390, 'padX': 24, 'padTop': 8}, hint='packages/web/src/components/actions/ActionCard.tsx')

# ---- 3.11 message context menu (desktop right-click; the phone long-press is official) ---------
MENU = '[role="menu"][aria-label="Message context menu"]'
for state, row in (('default', 'menu-default'), ('task', 'menu-task')):
    rid = rows[row]['message']['id']
    add('menu', 'desktop', state, f'Message context menu ({state})', view='row',
        props={'row': row, 'boxWidth': 560, 'boxHeight': 520, 'padX': 16, 'padTop': 32}, selector=MENU,
        android_key='raft-message-context-menu', hint='packages/web/src/components/message/MessageItem.tsx',
        interactions=[{'type': 'rightclick', 'target': f'#message-{rid}'}, {'type': 'wait', 'ms': 300}])

# ---- 3.12 reaction chips row and the reactors tooltip ------------------------------------
CHIP = 'span.inline-flex > button.inline-flex.h-5'
for platform, box, padx in (('desktop', 560, 16), ('mobile', 390, 24)):
    add('reactions', platform, 'single', 'Reaction chips (one)', view='row',
        props={'row': 'reactions-single', 'boxWidth': box, 'padX': padx, 'padTop': 8})
    add('reactions', platform, 'multi', 'Reaction chips (several)', view='row',
        props={'row': 'reactions-multi', 'boxWidth': box, 'padX': padx, 'padTop': 8})
add('reactions', 'desktop', 'tooltip', 'Reactors tooltip on a chip', view='row',
    props={'row': 'reactions-single', 'boxWidth': 560, 'boxHeight': 140, 'padX': 16, 'padTop': 8},
    selector='[data-message-affordance="reaction-reactors-popover"]', android_key='reaction-reactors-popover',
    interactions=[{'type': 'hover', 'target': f'#message-{rows["reactions-single"]["message"]["id"]} {CHIP}'},
                  {'type': 'wait', 'ms': 400}])

# ---- 3.07 channel Files tab / 3.08 channel Tasks tab (desktop main column / phone page) -------
TAB = lambda name: [{'type': 'click', 'target': f'[data-testid="panel-tab-{name}"]'}, {'type': 'wait', 'ms': 700}]
for platform, full in (('desktop', (0, 800)), ('mobile', (0, 844))):
    chat = {'surface': 'chat', 'chan': 'channel-cv-open'}
    for state in ('list', 'more', 'empty', 'loading', 'error'):
        add('files', platform, state, f'Channel Files tab ({state})', props={**chat, 'convTab': 'files'}, win=full,
            route_set=f'files-{state}', interactions=TAB('files'), hint='packages/web/src/components/message/ChannelFilesPanel.tsx')
    for state in ('list', 'empty'):
        add('tasks', platform, state, f'Channel Tasks tab ({state})', props={**chat, 'convTab': 'tasks'}, win=full,
            route_set=f'tasks-{state}', interactions=TAB('tasks'), hint='packages/web/src/components/task/TasksPanel.tsx')

# ---- 3.37 thread states, 3.38 in-thread search, 3.39 thread agent followers ---------------------
OVERFLOW = '[data-testid="thread-overflow-trigger"]'
SEARCH_OPEN = [{'type': 'click', 'target': OVERFLOW}, {'type': 'click', 'target': '[data-testid="thread-overflow-search"]'},
               {'type': 'wait', 'ms': 400}]
for platform, full in (('desktop', (0, 800)), ('mobile', (0, 844))):
    th = {'surface': 'thread', 'chan': 'channel-cv-open', 'threadKey': 'main'}
    add('threadstate', platform, 'load-failed', 'Thread load failed (Retry)', props={**th, 'resolveFailed': True}, win=full, route_set='thread-failed',
        hint='packages/web/src/components/message/ThreadPanel.tsx')
    add('threadstate', platform, 'guest-readonly', 'Thread guest read-only footer', props={**th, 'serverRole': 'guest'},
        win=(-140, 140), hint='packages/web/src/components/message/ThreadPanel.tsx')
    add('threadstate', platform, 'joint-locked', 'Thread joint locked footer',
        props={**th, 'chan': 'channel-cv-joint-locked', 'threadKey': 'joint'}, win=(-180, 180),
        hint='packages/web/src/components/message/ThreadPanel.tsx')
    add('threadstate', platform, 'join-parent', 'Thread join parent channel footer',
        props={**th, 'chan': 'channel-cv-join', 'threadKey': 'join'}, win=(-140, 140),
        hint='packages/web/src/components/message/ThreadPanel.tsx')
    add('threadsearch', platform, 'open', 'In-thread search bar', props=th, win=(0, 260), interactions=SEARCH_OPEN,
        hint='packages/web/src/components/message/ThreadPanel.tsx')
    add('threadsearch', platform, 'matches', 'In-thread search with matches', props=th, win=(0, 360),
        interactions=SEARCH_OPEN + [{'type': 'fill', 'target': '[data-testid="thread-search-input"]', 'value': 'parity'},
                                    {'type': 'wait', 'ms': 600}],
        hint='packages/web/src/components/message/ThreadPanel.tsx')
    add('threadsearch', platform, 'none', 'In-thread search without matches', props=th, win=(0, 260),
        interactions=SEARCH_OPEN + [{'type': 'fill', 'target': '[data-testid="thread-search-input"]', 'value': 'zzzz'},
                                    {'type': 'wait', 'ms': 600}],
        hint='packages/web/src/components/message/ThreadPanel.tsx')
    add('followers', platform, 'header', 'Thread agent followers trigger', props=th, win=(0, 120), route_set='followers',
        hint='packages/web/src/components/thread/ThreadAgentFollowers.tsx')
    add('followers', platform, 'popover', 'Thread agent followers list', props=th, win=(0, 340), route_set='followers',
        interactions=[{'type': 'click', 'target': '[data-testid="thread-followers-header-trigger"]'}, {'type': 'wait', 'ms': 500}],
        hint='packages/web/src/components/thread/ThreadAgentFollowers.tsx')
    add('followers', platform, 'error', 'Thread agent followers load failed', props=th, win=(0, 340),
        route_set='followers-error',
        interactions=[{'type': 'click', 'target': '[data-testid="thread-followers-header-trigger"]'}, {'type': 'wait', 'ms': 500}],
        hint='packages/web/src/components/thread/ThreadAgentFollowers.tsx')

# ---- 3.13 message selection mode (desktop main column; the phone toolbar is the official share case) --------
ROW1, ROW2 = 'msg-cv-sel-1', 'msg-cv-sel-2'
SELECT = [{'type': 'rightclick', 'target': f'#message-{ROW1}'},
          {'type': 'click', 'target': '[role="menu"] >> text=Select Message'}, {'type': 'wait', 'ms': 300}]
add('selection', 'desktop', 'one', 'Selection mode, one message', props={'surface': 'chat', 'chan': 'channel-cv-open'},
    win=(0, 800), interactions=SELECT, hint='packages/web/src/components/message/SelectModeToolbar.tsx')
add('selection', 'desktop', 'two', 'Selection mode, two messages', props={'surface': 'chat', 'chan': 'channel-cv-open'},
    win=(0, 800), interactions=SELECT + [{'type': 'click', 'target': f'#message-{ROW2}'}, {'type': 'wait', 'ms': 300}],
    hint='packages/web/src/components/message/SelectModeToolbar.tsx')

# ---- 3.16 quoted message permalink preview (React only: Flutter renders the URL as a plain link) -------------
for platform, box, padx in (('desktop', 560, 16), ('mobile', 390, 24)):
    for state, rs in (('text', None), ('attachment', None), ('archived', None), ('loading', 'quote-loading'),
                      ('unavailable', 'quote-unavailable')):
        add('quote', platform, state, f'Quoted message permalink preview ({state})', view='row',
            props={'row': f'quote-{state}', 'boxWidth': box, 'padX': padx, 'padTop': 8}, route_set=rs,
            hint='packages/web/src/components/message/QuotedMessagePermalinkPreview.tsx')

# ---- 3.29 external identity preview card (hover) and detail panel ---------------------------------
add('external', 'desktop', 'card', 'External identity preview card', view='row',
    props={'row': 'external-slack', 'boxWidth': 440, 'boxHeight': 112, 'padX': 16, 'padTop': 32},
    selector='[data-slot="preview-card-content"]', android_key='raft-hover-card-surface',
    hint='packages/web/src/components/message/ExternalIdentityPreviewCard.tsx',
    interactions=[{'type': 'hover', 'target': '#message-msg-cv-external [data-avatar-kind="external"]'},
                  {'type': 'wait', 'ms': 700}])
add('external', 'desktop', 'detail', 'External identity detail panel', view='external-detail',
    props={'boxWidth': 380, 'boxHeight': 640}, hint='packages/web/src/components/profile/ExternalIdentityDetailPanel.tsx')
add('external', 'mobile', 'detail', 'External identity detail page', view='external-detail',
    props={'boxWidth': 390, 'boxHeight': 844}, hint='packages/web/src/components/profile/ExternalIdentityDetailPanel.tsx')

# ---- 3.34 translation in message rows (auto translation to zh-CN) -----------------------------------
for platform, box, padx in (('desktop', 560, 16), ('mobile', 390, 24)):
    for state, rs in (('translating', 'translation-pending'), ('translated', 'translation'), ('bilingual', 'translation'),
                      ('failed', 'translation-failed')):
        add('translate', platform, state, f'Message translation ({state})', view='row',
            props={'row': 'translate', 'translate': state, 'boxWidth': box, 'padX': padx, 'padTop': 8}, route_set=rs,
            hint='packages/web/src/components/message/MessageItem.tsx')

# ---- 3.18 Mermaid full-screen viewer (React only: Flutter has no viewer) ----------------------------
for platform, box, padx in (('desktop', 560, 16), ('mobile', 390, 24)):
    add('mermaid', platform, 'fullscreen', 'Mermaid full-screen viewer', view='row',
        props={'row': 'mermaid', 'boxWidth': box, 'padX': padx, 'padTop': 8},
        selector='[data-testid="mermaid-fullscreen"]', android_key='mermaid-fullscreen',
        interactions=[{'type': 'wait', 'ms': 900},
                      {'type': 'click', 'target': '[aria-label="Open Mermaid diagram fullscreen"]'},
                      {'type': 'wait', 'ms': 1200}],
        hint='packages/web/src/components/mermaid/MermaidDiagramViewer.tsx')

# ---- 3.26 audio / video / PDF / patch attachment rows ---------------------------------------------
for platform, box, padx in (('desktop', 560, 16), ('mobile', 390, 24)):
    for kind in ('audio', 'video', 'pdf', 'patch'):
        add('attach', platform, kind, f'Message attachment preview ({kind})', view='row',
            props={'row': f'attach-{kind}', 'boxWidth': box, 'padX': padx, 'padTop': 8},
            hint='packages/web/src/components/message/MessageItem.tsx')

# ---- 3.26b message video card: idle poster, hover, playing, error ------------------------------------------
VIDEO_CARD = '[data-message-affordance="inline-video-preview"]'
for platform, box, padx in (('desktop', 560, 16), ('mobile', 390, 24)):
    base = {'boxWidth': box, 'padX': padx, 'padTop': 8}
    add('attach', platform, 'video-poster', 'Message video card, first-frame poster', view='row',
        props={**base, 'row': 'attach-video-ok'},
        interactions=[{'type': 'wait', 'ms': 1500}],
        hint='packages/web/src/components/message/MessageItem.tsx InlineVideoAttachmentCard')
    add('attach', platform, 'video-error', 'Message video card, codec failure', view='row',
        props={**base, 'row': 'attach-video-bad'},
        interactions=[{'type': 'wait', 'ms': 1500}],
        hint='packages/web/src/components/message/MessageItem.tsx InlineVideoAttachmentCard')
add('attach', 'desktop', 'video-hover', 'Message video card, pointer over the picture', view='row',
    props={'boxWidth': 560, 'padX': 16, 'padTop': 8, 'row': 'attach-video-ok'},
    interactions=[{'type': 'wait', 'ms': 1500}, {'type': 'hover', 'target': VIDEO_CARD}, {'type': 'wait', 'ms': 600}],
    notes='Web shows the browser-native media controls on hover; Flutter draws its own bar (play, time, seek, volume) '
          'plus the centred Play button, so the control strip differs by design.',
    hint='packages/web/src/components/message/MessageItem.tsx InlineVideoAttachmentCard')
add('attach', 'desktop', 'video-playing', 'Message video card, playing', view='row',
    props={'boxWidth': 560, 'padX': 16, 'padTop': 8, 'row': 'attach-video-ok'},
    interactions=[{'type': 'wait', 'ms': 1500}, {'type': 'click', 'target': VIDEO_CARD}, {'type': 'wait', 'ms': 900}],
    notes='Clicking the picture plays it inline. Web shows the browser-native control bar; Flutter its own bar.',
    hint='packages/web/src/components/message/MessageItem.tsx InlineVideoAttachmentCard')

# ---- 3.14 forward composer dialog (desktop; the phone dialog is the official case) ----------------------
FORWARD = SELECT + [{'type': 'click', 'target': f'#message-{ROW2}'}, {'type': 'wait', 'ms': 300},
                    {'type': 'click', 'target': 'role=button[name="Forward"]'}, {'type': 'wait', 'ms': 900}]
add('forward', 'desktop', 'dialog', 'Forward composer dialog', props={'surface': 'chat', 'chan': 'channel-cv-open'},
    win=(0, 800), interactions=FORWARD, selector='[data-testid="forward-composer-dialog"]', android_key='forward-dialog',
    hint='packages/web/src/components/message/ForwardComposerDesktop.tsx')

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/conversation.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} conversation page cases appended -> the run-time manifest ($PARITY_EXT_MANIFEST); '
      'fixture -> tool/parity-ext/fixtures/conversation.json')
