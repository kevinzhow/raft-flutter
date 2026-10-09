#!/usr/bin/env python3
"""Public DTO fixtures for cold metadata/tail and stale context ownership.

Known metadata opens a cold tail through the real sidebar. Unknown metadata
opens through a valid Activity focus anchor and holds its context separately.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('channel_fixture', TOOLS / 'build-fixture.py')
channel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(channel)
MODES = ('cold-known', 'cold-unknown', 'stale-back-retarget-success', 'stale-back-retarget-error')

def build(mode):
    if mode not in MODES:
        raise ValueError(f'Unknown loading flow: {mode}')
    fixture = channel.build()
    routes, flow = fixture['routes'], fixture['process']
    flow.update(flow=mode, requirement=f'Loading/{mode}', sourceRoute='/s/visual/activity',
                activation='canonical', channelName='android-artifacts',
                metadataHold='GET /channels/channel-android',
                tailHold='GET /messages/channel/channel-android',
                builderSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                contract='Source MainLayout.tsx:394–440; ChatPanel.tsx:1345–1534; messageStore.ts:643–655,2374–2486; ThreadsInbox.tsx:1020–1176')
    inbox = copy.deepcopy(routes['GET /channels/inbox']['items'][0])
    if mode.startswith('cold-'):
        # InboxItem.lastMessageId is a required string (inboxStore.ts:133).
        # A no-anchor cold tail therefore opens through the real sidebar, not
        # an invalid Activity row. Unknown identity uses its valid focus anchor
        # and independently gates metadata and context, rather than a fake row.
        if mode == 'cold-known':
            flow.update(opener='sidebar', sourceRoute='/s/visual/channel/channel-design',
                        prelude='sidebar-ready', window='tail')
        else:
            flow.update(opener='activity-focused', prelude='activity-ready', window='context',
                        tailHold=flow['hold'])
            fixture['context']['channels'] = [r for r in fixture['context']['channels'] if r['id'] != flow['channelId']]
            for key in ('GET /channels', 'GET /channels/public'):
                if isinstance(routes.get(key), list):
                    routes[key] = [r for r in routes[key] if r['id'] != flow['channelId']]
        flow['hold'] = flow['tailHold']
        if mode == 'cold-known':
            flow['targetMessageId'] = flow['acceptedMessageId']
            flow['targetSeq'] = flow['acceptedSeq']
        else:
            flow['acceptedMessageId'] = flow['targetMessageId']
            flow['acceptedSeq'] = flow['targetSeq']
    else:
        # Two destinations really own two channel buckets and independent HTTP
        # endpoints. Releasing the superseded response cannot update new rows,
        # focus, URI or the accepted read frontier (success OR fallback error).
        flow.update(sourceRoute='/s/visual/channel/channel-android',
                    replacementChannelId='channel-design', replacementName='design',
                    replacementTargetId='process-replacement-target', replacementSeq=400,
                    replacementHold='GET /messages/context/process-replacement-target',
                    lateResponse='error' if mode.endswith('-error') else 'success')
        template = copy.deepcopy(routes[flow['hold']]['messages'][0])
        replacement = {**template, 'id': flow['replacementTargetId'], 'channelId': flow['replacementChannelId'], 'seq': 400,
                       'content': 'Accepted replacement target after Back; superseded response must stay fenced.'}
        routes[flow['replacementHold']] = {
            'messages': [{**template, 'channelId': flow['replacementChannelId'], 'id': f'process-replacement-{seq}',
                          'seq': seq, 'content': f'Replacement context {seq}.'} if seq != 400 else replacement
                         for seq in range(390, 411)],
            'targetMessageId': flow['replacementTargetId'], 'hasOlder': True, 'hasNewer': True,
            'historyLimited': False, 'threadSummariesByParentMessageId': {}}
        if mode.endswith('-error'):
            routes[flow['hold']] = {'__status': 500, 'body': {'message': 'Controlled superseded context failure'}}
        replacement_inbox = {**inbox, 'channelId': flow['replacementChannelId'], 'channelName': flow['replacementName'],
                             'lastMessageId': flow['replacementTargetId'], 'firstUnreadMessageId': flow['replacementTargetId'],
                             'lastMessagePreview': replacement['content']}
        inbox_items = [inbox, replacement_inbox]
    if mode.startswith('cold-'):
        inbox_items = [inbox]
    payload = {'items': inbox_items, 'hasMore': False, 'totalCount': len(inbox_items), 'totalUnreadCount': sum(r['unreadCount'] for r in inbox_items)}
    routes['GET /channels/inbox'] = copy.deepcopy(payload)
    routes['GET /channels/inbox?offset=0'] = payload
    return fixture

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--flow', choices=MODES, required=True)
    p.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    if args.out.exists():
        raise SystemExit(f'Refusing to overwrite immutable fixture: {args.out}')
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(build(args.flow), indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({'fixture': str(args.out), 'sha256': hashlib.sha256(args.out.read_bytes()).hexdigest()}))
