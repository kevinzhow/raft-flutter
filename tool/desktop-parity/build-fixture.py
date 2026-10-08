#!/usr/bin/env python3
"""Build the shared desktop parity API fixture (desktop-fixture.json).

One JSON file answers every API call for BOTH providers:
  - Web: web-runtime.mjs serves it under /api/* to the real Raft Web app.
  - Flutter: integration_test/desktop_screens_test.dart loads it into a
    fixture RaftClient (request() override) driving the real WorkspaceView.

Route keys: "METHOD /path" or "METHOD /path?k=v&k2=v2". A query-constrained
key matches when every listed param equals the request's param; the most
specific match wins, then the bare "METHOD /path" key. Values are response
bodies, or {"__status": n, "body": ...}.

Inputs (public test data only, no credentials):
  inputs/cody-v5-api-fixture.json   - prior matched chat/thread fixture
  inputs/*Fixture.json              - raft-source visual-testing shared rows
"""
import copy
import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
inp = here / 'inputs'
base = json.loads((inp / 'cody-v5-api-fixture.json').read_text())
tasks = json.loads((inp / 'tasksFixture.json').read_text())
saved = json.loads((inp / 'savedMessagesFixture.json').read_text())
search = json.loads((inp / 'searchResultsFixture.json').read_text())
activity = json.loads((inp / 'activityResultsFixture.json').read_text())

routes = {}
for row in base['responses']:
    key = f"{row['method']} {row['path'][4:]}"
    q = row.get('query') or {}
    if q:
        key += '?' + '&'.join(f'{k}={v}' for k, v in sorted(q.items()))
    routes[key] = row['body'] if not row.get('status') else {'__status': row['status'], 'body': row['body']}

ctx = base['context']
user = ctx['user']
server = ctx['server']
sid = server['id']
agents = ctx['agents']
cindy = agents[0]

# --- auth / account -------------------------------------------------------
routes['GET /auth/me'] = user
routes['GET /auth/identities'] = {'passwordConfigured': True, 'identities': []}
routes['GET /auth/providers'] = {'providers': []}

# --- server ----------------------------------------------------------------
routes[f'GET /servers/{sid}'] = server
routes[f'GET /servers/{sid}/notification-settings'] = {'serverPushMuted': False}
routes[f'GET /servers/{sid}/invites'] = []
routes[f'GET /servers/{sid}/join-links'] = []
routes[f'GET /servers/{sid}/settings'] = {}
routes[f'GET /servers/{sid}/model-label-catalog'] = {'labels': []}

# --- DM with Cindy -------------------------------------------------------
dm_id = 'dm-agent-cindy-artin'
dm = {
    'id': dm_id, 'serverId': sid, 'name': cindy['displayName'], 'description': None,
    'type': 'dm', 'peerId': cindy['id'], 'peerName': cindy['name'],
    'peerDisplayName': cindy['displayName'], 'peerType': 'agent',
    'peerAvatarUrl': cindy['avatarUrl'], 'createdAt': '2026-06-19T12:24:00.000Z', 'joined': True,
}
routes['GET /channels/dm'] = [dm]
routes[f'GET /channels/{dm_id}'] = dm
routes[f'GET /messages/channel/{dm_id}'] = {
    'messages': [
        {'id': 'msg-dm-1', 'channelId': dm_id, 'serverId': sid, 'seq': 1,
         'senderType': 'user', 'senderId': user['id'], 'senderName': user['name'],
         'content': 'Can you capture the desktop tasks route next?',
         'threadId': None, 'createdAt': '2026-06-19T12:20:00.000Z'},
        {'id': 'msg-visual-activity-dm', 'channelId': dm_id, 'serverId': sid, 'seq': 2,
         'senderType': 'agent', 'senderId': cindy['id'], 'senderName': cindy['name'],
         'content': 'On it. Desktop tasks, search and settings are queued.',
         'threadId': None, 'createdAt': '2026-06-19T12:24:00.000Z'},
    ],
    'historyLimited': False,
    'threadSummariesByParentMessageId': {},
}
routes[f'POST /channels/{dm_id}/read'] = {'maxReadSeq': '2', 'readStateVersion': '1'}
routes[f'GET /tasks/channel/{dm_id}'] = {'tasks': []}
routes[f'GET /channels/{dm_id}/files'] = {'files': [], 'hasMore': False}
routes[f'GET /channels/{dm_id}/members'] = routes.get(f'GET /channels/channel-design/members', [])
routes[f'GET /channels/{dm_id}/notification-settings'] = routes['GET /channels/channel-design/notification-settings']
routes[f'GET /channels/{dm_id}/message-display-settings'] = routes['GET /channels/channel-design/message-display-settings']
routes[f'GET /attachments/upload-sessions/{dm_id}/active'] = routes['GET /attachments/upload-sessions/channel-design/active']

# Second channel: empty but valid so sidebar hover/selection can target it.
android = next(c for c in ctx['channels'] if c['id'] == 'channel-android')
routes['GET /channels/channel-android'] = android
routes['GET /messages/channel/channel-android'] = {'messages': [], 'historyLimited': False, 'threadSummariesByParentMessageId': {}}
routes['POST /channels/channel-android/read'] = {'maxReadSeq': '0', 'readStateVersion': '1'}
routes['GET /tasks/channel/channel-android'] = {'tasks': []}

# --- channel task lanes: honour ?status= like the real API ----------------
for ch in ('channel-design', 'channel-android', dm_id):
    body = routes.get(f'GET /tasks/channel/{ch}', {'tasks': []})
    for status in ('todo', 'in_progress', 'in_review', 'done', 'closed'):
        routes[f'GET /tasks/channel/{ch}?status={status}'] = {**body, 'tasks': [t for t in body.get('tasks', []) if t.get('status') == status]}

# --- tasks (server board): one lane per status ----------------------------
all_tasks = tasks['tasks']
routes['GET /tasks/server'] = {'tasks': all_tasks}
for status in ('todo', 'in_progress', 'in_review', 'done', 'closed'):
    routes[f'GET /tasks/server?status={status}'] = {'tasks': [t for t in all_tasks if t['status'] == status]}

# --- saved / search / activity --------------------------------------------
# The shared rows claim hasMore/total=5 but only carry 3 rows; make the page
# self-consistent so infinite scroll stops (offset>0 -> empty page).
saved_body = {'saved': saved['saved'], 'total': len(saved['saved']), 'hasMore': False}
routes['GET /channels/saved'] = {'saved': [], 'total': len(saved['saved']), 'hasMore': False}
routes['GET /channels/saved?offset=0'] = saved_body
routes['GET /channels/saved/count'] = {'count': saved_body['total']}
routes['GET /messages/search'] = {k: v for k, v in search.items() if k != 'comment'}
activity_body = {k: v for k, v in activity.items() if k != 'comment'}
routes['GET /channels/inbox'] = {**activity_body, 'items': []}
routes['GET /channels/inbox?offset=0'] = activity_body
routes['GET /channels/inbox/done'] = {'items': [], 'hasMore': False, 'totalCount': 0, 'totalUnreadCount': 0}
routes['GET /channels/inbox/unfollowed'] = {'items': [], 'hasMore': False, 'totalCount': 0, 'totalUnreadCount': 0}

# --- computers ---------------------------------------------------------------
machines = [
    {'id': 'computer-mbp', 'name': 'Jiachengs-MacBook-Pro', 'hostname': 'Jiachengs-MacBook-Pro.local',
     'os': 'darwin', 'status': 'online', 'statusVersion': 7, 'apiKeyPrefix': 'slk_vis',
     'runtimes': ['codex', 'claude'], 'daemonVersion': '0.65.0', 'computerVersion': '0.0.48',
     'isComputer': True, 'lastHeartbeat': '2026-06-19T12:28:00.000Z', 'createdAt': '2026-06-18T00:00:00.000Z'},
    {'id': 'computer-studio', 'name': 'Studio Test Rig', 'hostname': 'studio-test-rig.local',
     'os': 'linux', 'status': 'offline', 'statusVersion': 3, 'apiKeyPrefix': 'slk_off',
     'runtimes': ['codex'], 'daemonVersion': '0.65.0', 'computerVersion': '0.0.50',
     'isComputer': True, 'lastHeartbeat': None, 'createdAt': '2026-06-18T00:00:00.000Z'},
]
# Real server shape (web machineStore.ts:280): {machines, latestComputerVersion,
# latestComputerReleaseNotes}. A bare array is accepted by Web but not by every
# Flutter consumer, so use the production shape.
routes[f'GET /servers/{sid}/machines'] = {'machines': machines, 'latestComputerVersion': '0.0.50', 'latestComputerReleaseNotes': None}

# --- members / agents detail ------------------------------------------------
for a in agents:
    routes[f"GET /agents/{a['id']}"] = a
for m in ctx['members']:
    routes[f"GET /servers/{sid}/members/{m['userId']}/profile"] = m


# --- settings / agent-detail auxiliaries (bodies mirror raft-source
# visual-testing react-provider.spec.ts mocks) -------------------------------
routes[f'GET /servers/{sid}/usage'] = {'agents': 2, 'machines': 1, 'channels': 4}
routes[f'GET /servers/{sid}/agreement'] = {'enabled': False, 'agreement': None}
routes['GET /integrations/clients'] = []
routes['GET /integrations/marketplace'] = []
routes['GET /integrations/overview'] = []
routes['GET /reminders'] = {'reminders': []}
for a in agents:
    routes[f"GET /agents/{a['id']}/skills"] = {'global': [], 'workspace': []}
    routes[f"GET /agents/{a['id']}/runtime-options"] = {'context': 'existing_agent', 'machineId': a.get('machineId'), 'options': []}
    routes[f"GET /agents/{a['id']}/agent-dms"] = []
    routes[f"GET /agents/{a['id']}/channels"] = []
routes['GET /push/vapid-key'] = {'__status': 404, 'body': {'error': 'push disabled in fixture'}}
routes['GET /product-events/config'] = {'enabled': False}

fixture = {
    'name': 'raft desktop parity fixture',
    'scope': 'Public deterministic test data for Web vs Flutter desktop real-screen captures. No credentials, no backend.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'context': ctx,
    'locale': base['locale'],
    'delays': {},
    'routes': dict(sorted(routes.items())),
}
(here / 'desktop-fixture.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(routes)} routes -> desktop-fixture.json')
