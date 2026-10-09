#!/usr/bin/env python3
"""Derive independent Activity thread gates without overwriting channel evidence."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'tool/desktop-parity/desktop-fixture.json'

def build(base_path, after_thread=False, activation='single', short_thread=False):
    raw = base_path.read_bytes()
    fixture = json.loads(raw)
    original = fixture['process'].copy()
    public = json.loads(BASE.read_bytes())['routes']
    routes = fixture['routes']
    thread = copy.deepcopy(next(row for row in public['GET /channels/inbox?offset=0']['items'] if row['kind'] == 'thread'))
    # The parent is intentionally absent from accepted windows. Source loads
    # its context independently from a focused reply's context.
    parent = copy.deepcopy(public['GET /channels/channel-design/threads/msg-agent-reply']['parentMessage'])
    reply_id = thread['firstUnreadMessageId']
    thread_id = thread['threadChannelId']
    reply_template = copy.deepcopy(public['GET /messages/context/public-thread-reply-1']['messages'][0])
    reply_template['conversationContext'] = {
        'channelType': 'thread', 'parentMessageId': parent['id'],
        'parentChannelId': parent['channelId'], 'parentChannelType': 'channel'}
    reply = {**reply_template, 'id': reply_id, 'seq': 300,
             'content': thread['latestActivityPreview']}
    channel_item = copy.deepcopy(routes['GET /channels/inbox?offset=0']['items'][0])
    inbox = {'items': [thread, channel_item], 'totalCount': 2,
             'totalUnreadCount': 3, 'hasMore': False}
    routes['GET /channels/inbox'] = copy.deepcopy(inbox)
    routes['GET /channels/inbox?offset=0'] = inbox
    # Canonical/mobile route mounts an outer channel loader. Keep its real
    # system DTO, while ensuring that loader cannot satisfy parent hydration.
    outer = copy.deepcopy(public['GET /messages/context/msg-agent-reply']['messages'][0])
    for key in list(routes):
        if key.startswith('GET /messages/channel/channel-design'):
            routes[key] = {'messages': [outer], 'historyLimited': False,
                           'threadSummariesByParentMessageId': {}}
    routes[f"GET /messages/context/{parent['id']}"] = {
        'messages': [parent], 'targetMessageId': parent['id'],
        'hasOlder': False, 'hasNewer': False, 'historyLimited': False,
        'threadSummariesByParentMessageId': {}}
    routes[f'GET /messages/context/{reply_id}'] = {
        'messages': [reply if seq == 300 else {**reply_template,
            'id': f'process-thread-context-{seq}', 'seq': seq,
            'content': f'Thread context row {seq} around the Activity reply.'}
            for seq in ([300] if short_thread else range(290, 311))],
        'targetMessageId': reply_id, 'hasOlder': True, 'hasNewer': True,
        'historyLimited': False, 'threadSummariesByParentMessageId': {}}
    routes[f'GET /messages/channel/{thread_id}'] = {
        'messages': [reply], 'historyLimited': False,
        'threadSummariesByParentMessageId': {}}
    for suffix in ('members', 'notification-settings', 'message-display-settings'):
        routes[f'GET /channels/{thread_id}/{suffix}'] = copy.deepcopy(routes[f'GET /channels/channel-design/{suffix}'])
    routes[f'GET /attachments/upload-sessions/{thread_id}/active'] = copy.deepcopy(routes['GET /attachments/upload-sessions/channel-design/active'])
    routes[f'POST /channels/{thread_id}/read'] = {'ok': True}
    routes['GET /channels/threads/followers'] = copy.deepcopy(public['GET /channels/threads/followers?threadChannelIds=thread-msg-agent-reply'])
    fixture['process'] = {**original,
        'flow': 'activity-channel-after-thread' if after_thread else 'activity-thread-target',
        'requirement': f"N24/{'channel-after-thread' if after_thread else 'thread'}-{activation}",
        'activation': activation, 'focusExpectation': 'clamped-short-window' if short_thread else 'center', 'threadChannelId': thread_id,
        'parentChannelId': parent['channelId'], 'parentMessageId': parent['id'],
        'threadTargetMessageId': reply_id, 'threadTargetSeq': 300,
        'threadRowText': thread['latestActivityPreview'],
        'parentHold': f"GET /messages/context/{parent['id']}",
        'resolutionHold': f"GET /channels/{parent['channelId']}/threads/{parent['id']}",
        'repliesHold': f'GET /messages/context/{reply_id}',
        'originalChannelFixtureSha256': hashlib.sha256(raw).hexdigest(),
        'threadBuilderSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'contract': 'Source ThreadsInbox.tsx:1036–1179; threadStore.ts:337–454; ThreadPanel.tsx:1275–1510'}
    return fixture

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--base', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--after-thread', action='store_true')
    p.add_argument('--short-thread', action='store_true')
    p.add_argument('--activation', choices=('single', 'double'), default='single')
    args = p.parse_args()
    if args.out.exists():
        raise SystemExit('Refusing to overwrite immutable thread fixture')
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(build(args.base, args.after_thread, args.activation, args.short_thread), indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({'fixture': str(args.out), 'sha256': hashlib.sha256(args.out.read_bytes()).hexdigest()}))
