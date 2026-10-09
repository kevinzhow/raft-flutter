#!/usr/bin/env python3
"""Build an isolated process fixture from the committed public DTO fixture.

The accepted tail and requested context are deliberate different server windows;
no production fixture or Source file is changed. Output is a standalone artifact.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'tool/desktop-parity/desktop-fixture.json'
TARGET = 'msg-visual-activity-android'
OLD = 'process-accepted-tail'
CHANNEL = 'channel-android'

def build():
    raw = BASE.read_bytes()
    fixture = json.loads(raw)
    routes = fixture['routes']
    inbox = copy.deepcopy(routes['GET /channels/inbox?offset=0'])
    inbox['items'] = [i for i in inbox['items'] if i.get('channelId') == CHANNEL]
    inbox.update(totalCount=1, totalUnreadCount=1, hasMore=False)
    routes['GET /channels/inbox'] = copy.deepcopy(inbox)
    routes['GET /channels/inbox?offset=0'] = inbox
    # Use the exact canonical message DTO, with explicit older/tail windows.
    template = copy.deepcopy(routes['GET /messages/context/msg-agent-reply']['messages'][1])
    template.update(channelId=CHANNEL, serverId='visual-server', threadId=None,
                    threadChannelId=None)
    template.pop('reactions', None)
    tail = {**template, 'id': OLD, 'seq': 200,
            'content': 'Accepted tail before Activity target navigation.'}
    target = {**template, 'id': TARGET, 'seq': 300,
              'content': inbox['items'][0]['lastMessagePreview']}
    for suffix in ('members', 'notification-settings', 'message-display-settings'):
        routes[f'GET /channels/{CHANNEL}/{suffix}'] = copy.deepcopy(routes[f'GET /channels/channel-design/{suffix}'])
    routes[f'GET /attachments/upload-sessions/{CHANNEL}/active'] = copy.deepcopy(routes['GET /attachments/upload-sessions/channel-design/active'])
    routes[f'GET /messages/channel/{CHANNEL}'] = {
        'messages': [tail], 'historyLimited': False,
        'threadSummariesByParentMessageId': {}}
    routes[f'GET /messages/context/{TARGET}'] = {
        'messages': [{**template, 'id': f'process-context-{seq}', 'seq': seq, 'content': f'Context row {seq} around the real Activity target.'} if seq != 300 else target for seq in range(290, 311)], 'targetMessageId': TARGET, 'hasOlder': True,
        'hasNewer': True, 'historyLimited': False,
        'threadSummariesByParentMessageId': {}}
    fixture['process'] = {
        'flow': 'activity-uncached-channel-target', 'channelId': CHANNEL,
        'targetMessageId': TARGET, 'targetSeq': 300, 'acceptedMessageId': OLD, 'acceptedSeq': 200,
        'hold': f'GET /messages/context/{TARGET}',
        'sourceRoute': '/s/visual/channel/channel-android',
        'activityRoute': '/s/visual/activity',
        'baseFixtureSha256': hashlib.sha256(raw).hexdigest(),
        'builderSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'contract': 'Source messageStore.ts:2374–2460; ChatPanel.tsx:581–597,1484–1534',
    }
    return fixture

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--out', required=True)
    args = p.parse_args()
    out = Path(args.out)
    if out.exists():
        raise SystemExit(f'Refusing to overwrite immutable fixture: {out}')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(build(), indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({'fixture': str(out), 'sha256': hashlib.sha256(out.read_bytes()).hexdigest()}))
