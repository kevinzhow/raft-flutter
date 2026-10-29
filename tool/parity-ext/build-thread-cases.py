#!/usr/bin/env python3
"""Append the thread / timeline cases to the run-time manifest ($PARITY_EXT_MANIFEST) and write
tool/parity-ext/fixtures/thread.json.

Run after build-cases.py, build-channel-header.py,
build-announcements.py, build-search-overlay-cases.py and the other builders;
idempotent: every `components.thread-ext.<scene>.*` case of THIS builder is
replaced, all other cases (including the sibling `components.thread-ext.*`
families written by build-thread-attachments.py / build-thread-messages.py) are
kept in place.

Derivation (raft-source 26f77ef, packages/web/src):
  components/message/ThreadPanel.tsx        side thread panel: parent slot,
                                             HistoryTopState + reply count, reply
                                             MessageTimeline, EmptyState, loading,
                                             HistoryLimitBanner, composer footer
  components/message/ThreadOverflowMenu.tsx  vertical-ellipsis DropdownMenu
  components/message/InlineThreadReplies.tsx the muted "N replies" preview surface
  components/message/ChatPanel.tsx           channel timeline, EmptyState, loading,
                                             HistoryLimitBanner / HistoryTopState,
                                             bottom button
  components/message/DateDivider.tsx         MessageListDateDivider
  components/message/SystemMessageGroupDisclosure.tsx
  components/thread/ThreadsInbox.tsx, ThreadAgentFollowers.tsx
Ids: components.thread-ext.<scene>.<platform>.<state>.<theme>. React mounts the
real ChatPanel / ThreadPanel in a column-sized box (like build-channel-header.py)
and clips a window; Flutter mounts the real WorkspaceView and clips the same
window. Data: tool/parity-ext/fixtures/thread.json (`routes` + `routeSets`,
answered identically by both providers). The React provider pins the clock to
the fixture instant (fixtureData locale.nowEpochMillis = 2026-06-19T12:30Z, i.e.
2026-06-19 20:30 Asia/Shanghai), so 2026-06-19 is "Today" and 2026-06-18
"Yesterday"; the Flutter builders install the same instant as `sourceTimeNow`.
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
PREFIX = 'components.thread-ext.'
# Scenes owned by this builder (the siblings own `attachment.` and `message.`).
OWN = ('thread.', 'timeline.', 'inline.', 'inbox.', 'followers.')
SID = 'visual-server'
CREATED = '2026-06-18T00:00:00.000Z'
# The Free plan's 30-day history cutoff applies after the full-featured trial
# (shared TRIAL_END_DATE 2026-06-23T12:00Z); the fixture instant is inside it.
AFTER_TRIAL = '2026-06-24T12:30:00.000Z'
CH = 'channel-design'
THREAD = 'thread-design-1'
PARENT = 'msg-thread-parent'

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


def system(mid, channel, content, created):
    Seq.n += 1
    return {'id': mid, 'seq': Seq.n, 'serverId': SID, 'channelId': channel, 'messageType': 'system',
            'senderType': 'user', 'senderId': OWNER['id'], 'senderName': OWNER['name'],
            'content': content, 'createdAt': created}


def page(messages, has_more=False, history_limited=False, summaries=None):
    return {'messages': messages, 'hasMore': has_more, 'historyLimited': history_limited,
            'threadSummariesByParentMessageId': summaries or {}}


def summary(thread_channel, count, last, participants, unread=0):
    return {'threadChannelId': thread_channel, 'replyCount': count, 'lastReplyAt': last,
            'participantIds': participants, 'unreadCount': unread, 'firstUnreadMessageId': None}


def channel(cid, name, description, ctype='channel'):
    return {'id': cid, 'serverId': SID, 'name': name, 'description': description, 'type': ctype,
            'createdAt': CREATED, 'joined': True}


# ---- thread content -------------------------------------------------------
T0 = '2026-06-22T02:30:00.000Z'
parent = msg(PARENT, CH, CINDY,
             'Captured the Android visual artifact for #product:f8e569cb and queued React parity.',
             T0, threadId=THREAD)
replies = [
    msg('msg-thread-r1', THREAD, OWNER, 'Looks good. Can you also attach the elegant-dark capture?', '2026-06-22T02:35:00.000Z'),
    msg('msg-thread-r2', THREAD, CINDY, 'Done: the dark baseline is attached to the task and the diff is under 2%.', '2026-06-22T02:41:00.000Z'),
    msg('msg-thread-r3', THREAD, DESIGNER, 'One spacing question on the composer: is the 12px gap intentional?', '2026-06-22T03:02:00.000Z'),
    msg('msg-thread-r4', THREAD, OWNER, 'Yes, it matches the Web panel padding.', '2026-06-22T03:05:00.000Z'),
]
thread_summary = summary(THREAD, 4, '2026-06-22T03:05:00.000Z', [OWNER['id'], CINDY['id'], DESIGNER['id']])
Seq.n = 0

# ---- timeline content -----------------------------------------------------
dated = [
    msg('msg-d1', CH, DESIGNER, 'Kicking off the release gate review for last year.', '2025-12-19T03:20:00.000Z'),
    msg('msg-d2', CH, CINDY, 'Baselines for the old gate are archived under the release folder.', '2025-12-19T03:24:00.000Z'),
    msg('msg-d3', CH, OWNER, 'Thanks. Starting the new run this week.', '2026-06-22T02:10:00.000Z'),
    msg('msg-d4', CH, CINDY, 'The first capture finished; 92 cases passed.', '2026-06-22T02:30:00.000Z'),
    msg('msg-d5', CH, DESIGNER, 'Reviewing the diffs after lunch.', '2026-06-18T05:12:00.000Z'),
    msg('msg-d6', CH, OWNER, 'Any blockers for the composer cases?', '2026-06-19T01:40:00.000Z'),
    msg('msg-d7', CH, CINDY, 'None so far. I will post the report here.', '2026-06-19T01:44:00.000Z'),
]
long_history = [
    msg('msg-h1', CH, OWNER, 'Plan limits apply to this channel history.', '2026-06-22T02:10:00.000Z'),
    msg('msg-h2', CH, CINDY, 'Older messages are hidden by the plan cutoff.', '2026-06-22T02:30:00.000Z'),
]
system_group = [
    msg('msg-s0', CH, OWNER, 'Welcome the new members to the design channel.', '2026-06-22T02:00:00.000Z'),
    system('msg-s1', CH, 'Cindy joined the channel.', '2026-06-22T02:05:00.000Z'),
    system('msg-s2', CH, 'Designer joined the channel.', '2026-06-22T02:06:00.000Z'),
    system('msg-s3', CH, 'artin renamed the channel to design.', '2026-06-22T02:07:00.000Z'),
    msg('msg-s4', CH, DESIGNER, 'Glad to be here.', '2026-06-22T02:20:00.000Z'),
]
Seq.n = 0
inline_parent = msg(PARENT, CH, CINDY,
                    'Captured the Android visual artifact for #product:f8e569cb and queued React parity.',
                    T0, threadId=THREAD)
inline_sum = summary(THREAD, 4, '2026-06-22T03:05:00.000Z', [OWNER['id'], CINDY['id'], DESIGNER['id']], unread=2)

Seq.n = 0
filler = [
    'Pulled the latest baselines and re-ran the composer cases.',
    'The thread header diff is down to text anti-aliasing only.',
    'Can someone double check the mobile spacing before we ship?',
    'Checked: the 12px gap matches the Web panel padding.',
    'Archiving the old captures so the report stays readable.',
    'Release notes draft is in the doc, please add your sections.',
    'Reactions row looks right now, I verified all three themes.',
    'Following up on the history banner copy with the design team.',
    'The timeline keeps its scroll anchor when new replies arrive.',
    'Merged the sidebar fix; rebasing the remaining branches.',
    'Dark mode borders were off by one level, fixed in the recipe.',
    'Posting the final comparison report in this channel shortly.',
]
long_list = [msg(f'msg-l{i}', CH, [OWNER, CINDY, DESIGNER][i % 3], text, f'2026-06-22T0{2 + i // 6}:{(i * 7) % 60:02d}:00.000Z')
             for i, text in enumerate(filler)]
CHANNEL_ROUTE = f'GET /messages/channel/{CH}'
THREAD_ROUTE = f'GET /messages/channel/{THREAD}'
CONTEXT_ROUTE = f'GET /messages/context/{PARENT}'

route_sets = {
    'thread': {
        THREAD_ROUTE: page(replies),
        CONTEXT_ROUTE: {'messages': [parent], 'hasMore': False, 'hasNewer': False},
        CHANNEL_ROUTE: page([parent], summaries={PARENT: thread_summary}),
    },
    'thread-empty': {
        THREAD_ROUTE: page([]),
        CONTEXT_ROUTE: {'messages': [parent], 'hasMore': False, 'hasNewer': False},
        CHANNEL_ROUTE: page([parent]),
    },
    'thread-loading': {
        THREAD_ROUTE: {'$pending': True},
        CONTEXT_ROUTE: {'messages': [parent], 'hasMore': False, 'hasNewer': False},
        CHANNEL_ROUTE: page([parent], summaries={PARENT: thread_summary}),
    },
    'thread-limited': {
        THREAD_ROUTE: page([], history_limited=True),
        CONTEXT_ROUTE: {'messages': [parent], 'hasMore': False, 'hasNewer': False},
        CHANNEL_ROUTE: page([parent], summaries={PARENT: thread_summary}),
    },
    'timeline-dates': {CHANNEL_ROUTE: page(dated)},
    'timeline-empty': {CHANNEL_ROUTE: page([])},
    'timeline-loading': {CHANNEL_ROUTE: {'$pending': True}},
    'timeline-limited': {CHANNEL_ROUTE: page(long_history, history_limited=True)},
    'timeline-top': {CHANNEL_ROUTE: page(long_history)},
    'timeline-system': {CHANNEL_ROUTE: page(system_group)},
    'inbox-empty': {'GET /channels/inbox': {'items': [], 'hasMore': False, 'totalCount': 0, 'totalUnreadCount': 0}},
    'timeline-long': {CHANNEL_ROUTE: page(long_list)},
    'inline': {
        CHANNEL_ROUTE: page([inline_parent], summaries={PARENT: inline_sum}),
        THREAD_ROUTE: page(replies),
        CONTEXT_ROUTE: {'messages': [inline_parent], 'hasMore': False, 'hasNewer': False},
    },
}

fixture = {
    'name': 'raft-flutter parity extension: thread and timeline',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'channels': [channel(CH, 'design', 'Visual testing release gates')],
    'dms': [],
    'thread': {'parentChannelId': CH, 'parentMessageId': PARENT, 'threadChannelId': THREAD},
    'routes': {
        'GET /channels/threads/followers': {'threads': []},
        'GET /channels/threads/followed': {'threads': []},
    },
    'routeSets': {f'thext-{k}': v for k, v in route_sets.items()},
}

cases = []


def add(scene, platform, state, title, *, route_set, props=None, win=(0, 120), interactions=(), android=(),
        notes=None, surface='thread'):
    """win = (y, height) in column coordinates; y < 0 counts from the bottom."""
    viewport = DESKTOP if platform == 'desktop' else MOBILE
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{scene}.{platform}.{state}.{suffix}'
        c = {
            'id': cid,
            'title': f'{title} {platform} ({theme})',
            'captureType': 'component-fixture',
            'surface': f'thread-ext-{scene}',
            'category': 'extension/thread',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': {
                'extCase': f'{scene}.{platform}.{state}', 'extKind': 'thread', 'parityTheme': theme,
                'platform': 'desktop' if platform == 'desktop' else 'mobile',
                'routeSet': f'thext-{route_set}', 'winY': win[0], 'winH': win[1], 'surface': surface,
                **(props or {})}}],
            'capture': {'selector': f"[data-visual-case='{cid}']", 'crop': 'element', 'contract': 'component-bounds',
                        'interactions': list(interactions), 'androidInteractions': list(android)},
            'reactPathHint': 'packages/web/src/components/message/ThreadPanel.tsx + ChatPanel.tsx',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_thread.dart '{scene}.{platform}.{state}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if notes:
            c['notes'] = notes
        cases.append(c)


FULL = (0, 800)
for platform, full in (('desktop', (0, 800)), ('mobile', (0, 844))):
    # ---- side thread panel ------------------------------------------------
    add('thread', platform, 'panel', 'Thread panel with replies', route_set='thread',
        props={'surface': 'thread'}, win=full)
    add('thread', platform, 'empty', 'Thread panel without replies', route_set='thread-empty',
        props={'surface': 'thread'}, win=full)
    add('thread', platform, 'loading', 'Thread panel loading replies', route_set='thread-loading',
        props={'surface': 'thread'}, win=full)
    add('thread', platform, 'history-limited', 'Thread panel behind the plan history cutoff',
        route_set='thread-limited', props={'surface': 'thread', 'clockIso': AFTER_TRIAL}, win=full)
    add('thread', platform, 'composer', 'Thread composer', route_set='thread',
        props={'surface': 'thread'}, win=(-140, 140))

SCROLL_UP = [{'type': 'wait', 'ms': 800}, {'type': 'scroll', 'target': '[data-testid="message-content-surface"]', 'y': -300}]
SCROLL_UP_ANDROID = [{'type': 'wait', 'ms': 800}, {'type': 'scroll', 'key': 'chat-list-channel', 'dy': -320}]
for platform, full in (('desktop', (0, 800)), ('mobile', (0, 844))):
    ch = {'surface': 'chat', 'channel': CH}
    # ---- channel timeline states ---------------------------------------
    add('timeline', platform, 'dates', 'Timeline date dividers', route_set='timeline-dates', props=ch, win=full)
    add('timeline', platform, 'empty', 'Empty channel', route_set='timeline-empty', props=ch, win=full)
    add('timeline', platform, 'loading', 'Channel loading', route_set='timeline-loading', props=ch, win=full)
    add('timeline', platform, 'history-limited', 'History limit banner', route_set='timeline-limited',
        props={**ch, 'clockIso': AFTER_TRIAL}, win=full)
    add('timeline', platform, 'history-top', 'Beginning of messages', route_set='timeline-top', props=ch, win=full)
    add('timeline', platform, 'system-collapsed', 'System message group', route_set='timeline-system',
        props=ch, win=full)
    add('timeline', platform, 'system-expanded', 'System message group expanded', route_set='timeline-system',
        props=ch, win=full,
        interactions=[{'type': 'click', 'target': '[data-testid="system-message-group-toggle"]'}],
        android=[{'type': 'tap', 'key': 'system-message-group-toggle'}])
    add('timeline', platform, 'back-to-bottom', 'Back to bottom button', route_set='timeline-long',
        props=ch, win=full, interactions=SCROLL_UP, android=SCROLL_UP_ANDROID)
    # ---- inline thread reply preview in the channel -----------------------
    add('inline', platform, 'preview', 'Inline thread replies preview', route_set='inline', props=ch, win=full)
# ---- threads inbox (the official 342x620 activity box) ---------------------
add('inbox', 'desktop', 'empty', 'Threads inbox empty', route_set='inbox-empty', props={'surface': 'inbox'},
    win=(0, 620))

# ---- thread overflow menu ---------------------------------------------------
for platform, win in (('desktop', (0, 240)), ('mobile', (0, 240))):
    add('thread', platform, 'overflow-menu', 'Thread overflow menu', route_set='thread',
        props={'surface': 'thread'}, win=win,
        interactions=[{'type': 'click', 'target': '[data-testid="thread-overflow-trigger"]'}],
        android=[{'type': 'tap', 'key': 'thread-options'}])

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
own = tuple(PREFIX + s for s in OWN)
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(own)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/thread.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} thread/timeline cases appended -> the run-time manifest ($PARITY_EXT_MANIFEST); '
      'fixture -> tool/parity-ext/fixtures/thread.json')
