#!/usr/bin/env python3
"""Append the conversation header cases to tool/parity-ext/cases.json and write
tool/parity-ext/fixtures/channelheader.json.

Run after build-cases.py (which regenerates the Computers cases); idempotent:
every `components.channelheader.*` case is replaced, all other cases are kept
in place (append-only for the other families).

Derivation (raft-source 26f77ef, packages/web/src):
  components/message/ChatPanel.tsx      header (PanelHeader icon/title/subtitle,
                                         DM titleSlot, ChannelOverflowMenu
                                         actions) + ConversationPanelTabs
  components/ui/PanelHeader.tsx         raft-ui PanelHeader composition
  components/channel/ChannelDescription.tsx  line-clamp-2 description
  components/ui/OverflowSheet.tsx       OverflowMenuTrigger (Button icon-sm outline + Tooltip)
  components/message/ThreadPanel.tsx    side thread header (title, parent label,
                                         ThreadOverflowMenu, Close)
  raft-ui 0.5.27 panel-header / conversation-panel recipes
Ids: components.channelheader.<platform>.<state>.<theme>. Each case captures a
window at the top of the conversation column (or the side thread column):
React mounts the real ChatPanel / ThreadPanel in a column-sized box, Flutter
mounts the real WorkspaceView and clips the same window.
"""
import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.channelheader.'
SID = 'visual-server'
CREATED = '2026-06-18T00:00:00.000Z'

SHORT = 'Visual testing release gates'
LONG = ('日语 lost and found 单词 App 结合了 crowded scene 的特性: every channel description that is longer '
        'than the header can show is clamped to two lines on Web, so this sentence keeps going with more '
        'release notes, review links, owners, and the reasons the team created the channel in the first '
        'place, until it is far longer than two lines at any desktop or mobile width.')


def channel(cid, name, description, ctype='channel'):
    return {'id': cid, 'serverId': SID, 'name': name, 'description': description, 'type': ctype,
            'createdAt': CREATED, 'joined': True}


fixture = {
    'name': 'raft-flutter parity extension: conversation headers',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'channels': [
        channel('channel-colvalley', 'colvalley', SHORT),
        channel('channel-colvalley-long', 'colvalley', LONG),
        channel('channel-colvalley-none', 'colvalley', None),
        channel('channel-colvalley-private', 'colvalley-private', SHORT, 'private'),
        # The reported channel: an authored newline inside the description.
        channel('channel-colvalley-newline', 'colvalley', '日语 lost and found 单词 App\n结合了 crowded scene 的特性'),
    ],
    'dms': [
        {**channel('dm-agent-cindy', 'dm-agent-cindy', None, 'dm'), 'peerType': 'agent',
         'peerId': 'agent-cindy', 'peerName': 'Cindy', 'peerDisplayName': 'Cindy',
         'peerAvatarUrl': 'pixel:robot'},
        {**channel('dm-human-designer', 'dm-human-designer', None, 'dm'), 'peerType': 'user',
         'peerId': 'visual-human-designer', 'peerName': 'designer', 'peerDisplayName': 'Designer',
         'peerAvatarUrl': None, 'peerGravatarHash': None},
    ],
    # Endpoints the mounted panels read after the first render (both providers).
    'routes': {'GET /channels/threads/followers': {'threads': []}},
    'thread': {'parentChannelId': 'channel-colvalley', 'parentMessageId': 'msg-colvalley-thread-parent',
               'threadChannelId': 'thread-colvalley-1'},
}

cases = []


def add(platform, state, title, *, props, height=120, interactions=(), android=(), notes=None):
    viewport = DESKTOP if platform == 'desktop' else MOBILE
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{platform}.{state}.{suffix}'
        c = {
            'id': cid,
            'title': f'Conversation header {platform} {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'channel-header',
            'category': 'extension/channel-header',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': {
                'extCase': f'{platform}.{state}', 'extKind': 'channelheader', 'parityTheme': theme,
                'platform': 'desktop' if platform == 'desktop' else 'mobile',
                'windowHeight': height, **props}}],
            'capture': {'selector': f"[data-visual-case='{cid}']", 'crop': 'element', 'contract': 'component-bounds',
                        'interactions': list(interactions), 'androidInteractions': list(android)},
            'reactPathHint': 'packages/web/src/components/message/ChatPanel.tsx + ui/PanelHeader.tsx',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_channel_header.dart '{platform}.{state}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if notes:
            c['notes'] = notes
        cases.append(c)


for platform in ['desktop', 'mobile']:
    add(platform, 'short', 'channel, short description', props={'channel': 'channel-colvalley'})
    add(platform, 'long', 'channel, long description (two-line clamp)', props={'channel': 'channel-colvalley-long'})
    add(platform, 'none', 'channel, no description', props={'channel': 'channel-colvalley-none'})
    add(platform, 'private', 'private channel', props={'channel': 'channel-colvalley-private'})
    add(platform, 'dm-agent', 'agent DM', props={'channel': 'dm-agent-cindy'})
    add(platform, 'thread', 'side thread panel header', props={'channel': 'channel-colvalley', 'thread': 'true'},
        height=64)
add('desktop', 'dm-human', 'human DM', props={'channel': 'dm-human-designer'})
add('desktop', 'hover-search', 'channel, hovered Search button', props={'channel': 'channel-colvalley'},
    interactions=[{'type': 'hover', 'target': '[data-testid="channel-topbar-search"]'}],
    android=[{'type': 'hover', 'key': 'channel-topbar-search'}],
    notes='Pointer rests on the Search icon button (hover fill; the tooltip opens after the provider delay).')
for platform in ['desktop', 'mobile']:
    add(platform, 'newline', 'channel, description with an authored newline',
        props={'channel': 'channel-colvalley-newline'})

manifest_path = here / 'cases.json'
manifest = json.loads(manifest_path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/channelheader.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} channel header cases appended -> tool/parity-ext/cases.json; '
      'fixture -> tool/parity-ext/fixtures/channelheader.json')
