#!/usr/bin/env python3
"""Append the composed-screen cases to the run-time manifest ($PARITY_EXT_MANIFEST) and write
tool/parity-ext/fixtures/screens.json.

Run after build-shell-cases.py (the sidebar, rail and unread data come from
fixtures/shell.json, `preset` default); idempotent: every `components.screens-ext.*`
case is replaced, all other cases are kept in place.

Derivation (raft-source 26f77ef, packages/web/src):
  components/layout/MainLayout.tsx   AppShellRoot > LeftRail + Sidebar + AppShellMainSlot
                                     (thread-main-column) > ChannelRoute / DmRoute > ChatPanel;
                                     InboxContentRoute > ThreadsInbox (Activity)
  components/message/ChatPanel.tsx   header + Chat/Files/Tasks tabs + timeline + MessageInput
  components/message/MessageInput.tsx, mentionCandidates.ts   @member / #channel popovers
  components/thread/ThreadsInbox.tsx populated Activity list
Ids: components.screens-ext.<surface>.<platform>.<state>.<theme>. React composes the
real LeftRail / Sidebar / ChatPanel in the AppShell slots at the case viewport; Flutter
mounts the real WorkspaceView. A transparent marker (`screen-window`) crops windowed
cases. Data: fixtures/screens.json (`scenes` + the shared shell workspace), answered
identically by both providers. The clock is the fixture instant 2026-06-19T12:30Z.
"""
import json
import os
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.screens-ext.'
SID = 'visual-server'
RAFT_SOURCE = pathlib.Path(os.environ.get(
    'PARITY_RAFT_SOURCE', '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source'))

shell = json.loads((here / 'fixtures/shell.json').read_text())
ACTIVITY = json.loads((RAFT_SOURCE / 'packages/visual-testing/shared/activityResultsFixture.json').read_text())
ACTIVITY.pop('comment', None)

OWNER = {'id': 'visual-user', 'name': 'artin', 'display': 'artin', 'type': 'user'}
DESIGNER = {'id': 'visual-human-designer', 'name': 'designer', 'display': 'Designer', 'type': 'user'}
CINDY = {'id': 'agent-cindy', 'name': 'Cindy', 'display': 'Cindy', 'type': 'agent'}
PRODUCT = {'id': 'agent-product-ux', 'name': 'Product-UX-Designer', 'display': 'Product UX Designer',
           'type': 'agent'}


class Seq:
    n = 0


def msg(mid, channel, sender, content, created, **extra):
    Seq.n += 1
    m = {'id': mid, 'seq': Seq.n, 'serverId': SID, 'channelId': channel, 'messageType': 'chat',
         'senderType': sender['type'], 'senderId': sender['id'], 'senderName': sender['name'],
         'senderDisplayName': sender['display'], 'content': content, 'createdAt': created}
    m.update(extra)
    return m


def system(mid, channel, content, created):
    Seq.n += 1
    return {'id': mid, 'seq': Seq.n, 'serverId': SID, 'channelId': channel, 'messageType': 'system',
            'senderType': 'user', 'senderId': OWNER['id'], 'senderName': OWNER['name'],
            'content': content, 'createdAt': created}


def reaction(emoji, who):
    return {'emoji': emoji, 'count': len(who), 'reactorIds': [w['id'] for w in who],
            'reactorNames': [w['name'] for w in who]}


def page(messages, summaries=None):
    return {'messages': messages, 'hasMore': False, 'historyLimited': False,
            'threadSummariesByParentMessageId': summaries or {}}


# ---- #design: a realistic channel mix (two days, human + agent, markdown, code, mention,
# reactions, an inline thread, a system line) ------------------------------------------------
CH = 'shell-design'
THREAD = 'thread-screens-1'
Seq.n = 0
TREE = ('Kicking off the sidebar polish pass. The plan:\n\n'
        '- **Rail** spacing and the active indicator\n'
        '- Sidebar *unread* badges and drafts\n'
        '- The `ChatPanel` header and tab strip\n\n'
        'Owners are listed in the doc.')
CODE = ('Baselines are regenerated. Run the focused cases with:\n\n'
        '```bash\ntool/parity-ext/run run --cases \'components.screens-ext.*\'\n```\n\n'
        'Then open the side-by-side report.')
channel_messages = [
    msg('scr-m1', CH, DESIGNER, TREE, '2026-06-18T09:20:00.000Z',
        reactions=[reaction('\U0001F44D', [OWNER, CINDY])]),
    msg('scr-m2', CH, CINDY, CODE, '2026-06-18T09:34:00.000Z'),
    msg('scr-m3', CH, OWNER, '@Cindy can you re-run the parity suite for the desktop shell? '
        'I want the channel screen and the Activity list in the same report.', '2026-06-19T04:10:00.000Z',
        mentions=[{'type': 'agent', 'id': CINDY['id'], 'name': CINDY['name']}]),
    msg('scr-m4', CH, CINDY, 'On it. The first capture finished with 92 cases passing; I am attaching the '
        'report to this thread.', '2026-06-19T04:14:00.000Z', threadId=THREAD,
        reactions=[reaction('\U0001F680', [OWNER]), reaction('✅', [DESIGNER, OWNER])]),
    msg('scr-m5', CH, DESIGNER, 'Thanks! I will review the diffs after lunch.', '2026-06-19T04:20:00.000Z'),
    msg('scr-m6', CH, DESIGNER, 'One question on the header: is the description meant to clamp at two lines?',
        '2026-06-19T04:21:00.000Z'),
    system('scr-m7', CH, 'Product-UX-Designer joined the channel.', '2026-06-19T08:05:00.000Z'),
    msg('scr-m8', CH, PRODUCT, 'Hi all. I wrote up the spacing spec for the composer and the timeline; '
        'feedback welcome before we freeze it.', '2026-06-19T08:12:00.000Z'),
    msg('scr-m9', CH, OWNER, 'Looks good to me. Let us ship the screens this week.', '2026-06-19T12:05:00.000Z'),
]
thread_replies = [
    msg('scr-t1', THREAD, OWNER, 'Great, thanks for posting it here.', '2026-06-19T04:30:00.000Z'),
    msg('scr-t2', THREAD, CINDY, 'Report attached: every case is above the threshold.', '2026-06-19T04:41:00.000Z'),
]
thread_summary = {'threadChannelId': THREAD, 'replyCount': 2, 'lastReplyAt': '2026-06-19T04:41:00.000Z',
                  'participantIds': [OWNER['id'], CINDY['id']], 'unreadCount': 0, 'firstUnreadMessageId': None}

# ---- DMs ------------------------------------------------------------------------------------
Seq.n = 0
DM_H = 'shell-dm-designer'
dm_human = [
    msg('scr-h1', DM_H, DESIGNER, 'Hey, do you have a minute to look at the new rail icons?', '2026-06-18T10:00:00.000Z'),
    msg('scr-h2', DM_H, OWNER, 'Sure. Send me the Figma link.', '2026-06-18T10:03:00.000Z'),
    msg('scr-h3', DM_H, DESIGNER, 'Here it is: https://example.com/design/rail-icons (page 3 has the states).',
        '2026-06-19T03:15:00.000Z'),
    msg('scr-h4', DM_H, OWNER, 'Got it. The active indicator reads well. I will comment on the hover state.',
        '2026-06-19T03:20:00.000Z', reactions=[reaction('\U0001F44D', [DESIGNER])]),
    msg('scr-h5', DM_H, DESIGNER, 'Perfect, thank you.', '2026-06-19T03:22:00.000Z'),
]
Seq.n = 0
DM_A = 'shell-dm-cindy'
dm_agent = [
    msg('scr-a1', DM_A, OWNER, 'Can you summarise yesterday\'s visual testing run?', '2026-06-18T09:00:00.000Z'),
    msg('scr-a2', DM_A, CINDY, 'Yesterday\'s run:\n\n1. 92 cases passed\n2. 3 cases need a second look\n'
        '3. The `elegant-dark` baseline is attached to the task\n\nI will keep the release notes aligned.',
        '2026-06-18T09:02:00.000Z'),
    msg('scr-a3', DM_A, OWNER, 'Thanks. Please re-run the three flagged cases today.', '2026-06-19T03:00:00.000Z'),
    msg('scr-a4', DM_A, CINDY, 'Done. All three are inside the tolerance now.', '2026-06-19T03:12:00.000Z',
        reactions=[reaction('\U0001F389', [OWNER])]),
]

ROUTE = lambda cid: f'GET /messages/channel/{cid}'
scenes = {
    'channel': {'selected': CH, 'routes': {ROUTE(CH): page(channel_messages, {'scr-m4': thread_summary}),
                                           ROUTE(THREAD): page(thread_replies)}},
    'dm-human': {'selected': DM_H, 'routes': {ROUTE(DM_H): page(dm_human)}},
    'dm-agent': {'selected': DM_A, 'routes': {ROUTE(DM_A): page(dm_agent)}},
    # Activity: no conversation selected, the populated inbox (official activityResultsFixture rows).
    'activity': {'selected': None, 'routes': {'GET /channels/inbox': ACTIVITY}},
}

fixture = {
    'name': 'raft-flutter parity extension: composed screens',
    'scope': 'Public deterministic test data; no credentials. Sidebar/rail data = fixtures/shell.json preset default.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'scenes': scenes,
    # Endpoints the mounted shell reads (same as the shell family), answered by both providers.
    'routes': {**shell['routes'], 'GET /channels/threads/followers': {'threads': []},
               'GET /channels/threads/followed': {'threads': []}},
    'routeSets': {f'scr-{k}': v['routes'] for k, v in scenes.items()},
}

cases = []


def add(surface, platform, state, title, *, scene, win='full', interactions=(), android=(), notes=None):
    viewport = DESKTOP if platform == 'desktop' else MOBILE
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{surface}.{platform}.{state}.{suffix}'
        windowed = win != 'full'
        c = {
            'id': cid,
            'title': f'{title} {platform} ({theme})',
            'captureType': 'component-fixture',
            'surface': f'screens-ext-{surface}',
            'category': 'extension/screens',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': {
                'extCase': f'{surface}.{platform}.{state}', 'extKind': 'screens', 'extFixture': 'screens',
                'parityTheme': theme, 'platform': platform, 'scene': scene, 'routeSet': f'scr-{scene}',
                'win': win}}],
            'capture': {'selector': '[data-testid="screen-window"]' if windowed else f"[data-visual-case='{cid}']",
                        'crop': 'element', 'contract': 'component-bounds',
                        'interactions': list(interactions), 'androidInteractions': list(android),
                        **({'androidKey': 'screen-window'} if windowed else {})},
            'reactPathHint': 'packages/web/src/components/layout/MainLayout.tsx + message/ChatPanel.tsx',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_screens.dart '{surface}.{platform}.{state}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if notes:
            c['notes'] = notes
        cases.append(c)


# 3.01 channel screen, 3.02 DM screens (the phone screens.thread.* official cases are still pending).
# Web ChatPanel autofocuses the composer on a hover-capable desktop (MessageInput autoFocus; the headless
# phone render is hover-capable too); the Flutter channel composer does not autofocus (product decision,
# chat_timeline_composition_test), so the desktop cases tap the composer to compare the same focused state.
FOCUS = [{'type': 'enterText', 'key': 'composer-editor-slot', 'text': ''}]
FOCUS_NOTE = ('Web autofocuses the desktop composer (focused brutal shadow); Flutter does not, so the '
              'Flutter side taps the composer.')
add('channel', 'desktop', 'full', 'Channel screen (rail, sidebar, header, tabs, timeline, composer)', scene='channel',
    android=FOCUS, notes=FOCUS_NOTE)
add('channel', 'mobile', 'full', 'Channel screen (header, tabs, timeline, composer)', scene='channel')
add('dm', 'desktop', 'human', 'Human DM screen', scene='dm-human', android=FOCUS, notes=FOCUS_NOTE)
add('dm', 'desktop', 'agent', 'Agent DM screen', scene='dm-agent', android=FOCUS, notes=FOCUS_NOTE)
add('dm', 'mobile', 'agent', 'Agent DM screen', scene='dm-agent')
# 3.20 composer suggestion popovers (the phone cases are the official components.thread.composer.*-suggestions).
POP_WAIT = {'type': 'wait', 'ms': 300}
add('composer', 'desktop', 'mention', 'Composer @mention suggestions', scene='channel', win='composer',
    interactions=[{'type': 'click', 'target': 'textarea'}, {'type': 'fill', 'target': 'textarea', 'value': '@'}, POP_WAIT],
    android=[{'type': 'tap', 'key': 'composer-editor-slot'},
             {'type': 'enterText', 'key': 'composer-editor-slot', 'text': '@'}])
add('composer', 'desktop', 'channel', 'Composer #channel suggestions', scene='channel', win='composer',
    interactions=[{'type': 'click', 'target': 'textarea'}, {'type': 'fill', 'target': 'textarea', 'value': '#'}, POP_WAIT],
    android=[{'type': 'tap', 'key': 'composer-editor-slot'},
             {'type': 'enterText', 'key': 'composer-editor-slot', 'text': '#'}])
# 5.05 Activity inbox, populated list (rail + the 560px master column of the Activity page).
add('activity', 'desktop', 'list', 'Activity inbox, populated list', scene='activity', win='activity')

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/screens.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} composed-screen cases appended -> the run-time manifest ($PARITY_EXT_MANIFEST); '
      'fixture -> tool/parity-ext/fixtures/screens.json')
