// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the channel's
// "Earliest / Next unread thread" pill (Web v1.21.23 ThreadUnreadJumpPill,
// `thread_unread_badge_v0`). Ids `components.thread-pill.<top|bottom>.<theme>`,
// dispatched on props.variant like tool/parity-ext/host/ThreadPillCases.tsx.
//
// The real ChatBottomControls is mounted in a 420x200 Stack (the chat's message
// surface) over the shell workspace with the followed-thread list seeded: `top`
// has its parents before every loaded message, `bottom` after the newest loaded
// one while newer ones exist (so the pill sits beside Back to bottom).
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:raft_flutter/features/thread_unread_jump.dart';

import '../parity_harness.dart';
import 'ext_shell.dart' show shellWorkspace;

Map<String, dynamic> _thread(String id, String parentAt) => {
  'threadChannelId': 'thread-$id',
  'parentMessageId': 'msg-$id',
  'parentChannelId': 'channel-pill',
  'parentChannelName': 'pill',
  'parentChannelType': 'channel',
  'parentMessagePreview': 'Parent text',
  'parentMessageSenderType': 'user',
  'parentMessageSenderId': 'visual-human-jiacheng',
  'parentMessageCreatedAt': parentAt,
  'latestActivitySeq': '10',
  'replyCount': 2,
  'lastReplyAt': '2026-06-19T11:00:00.000Z',
  'unreadCount': 1,
  'hasMention': false,
  'firstUnreadMessageId': 'reply-$id',
  'taskNumber': null,
};

Widget _build(ParityContext ctx) {
  final bottom = ctx.props['variant'] == 'bottom';
  final parentAt = bottom
      ? '2026-06-19T13:00:00.000Z'
      : '2026-06-19T08:00:00.000Z';
  final w = shellWorkspace(
    ctx,
    routes: {
      'POST /feature-flags/evaluate': {
        'evaluations': [
          {'key': 'thread_unread_badge_v0', 'enabled': true},
        ],
      },
      'GET /channels/threads/followed': {
        'threads': [_thread('a', parentAt), _thread('b', parentAt)],
      },
    },
  );
  w.channel = RaftChannel({
    'id': 'channel-pill',
    'name': 'pill',
    'type': 'channel',
    'joined': true,
  });
  // The shell asks for the flags as it draws the sidebar; here nothing does.
  ActivityRolloutFlags.of(w);
  final rows = [
    RaftMessage({'id': 'm-first', 'createdAt': '2026-06-19T09:00:00.000Z'}),
    RaftMessage({'id': 'm-last', 'createdAt': '2026-06-19T12:00:00.000Z'}),
  ];
  return ctx.frame(
    width: 420,
    height: 200,
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.white,
      child: SizedBox(
        key: const ValueKey('thread-pill-case'),
        width: 420,
        height: 200,
        child: Stack(
          children: [
            ChatBottomControls(
              controller: w,
              rows: rows,
              hasNewer: bottom,
              scroll: ChangeNotifier(),
              showBottom: bottom,
              bottomCount: 0,
              onBottom: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

ParityCase _case() => const ParityCase(
  widgets: [
    'raft_flutter:ChatBottomControls',
    'raft_ui:RaftThreadUnreadJumpPill',
  ],
  notes: 'Extension suite (not official).',
  settle: Duration(milliseconds: 900),
  build: _build,
);

/// Every extension thread-pill case, keyed by id (3 themes each).
final Map<String, ParityCase> extThreadPillCases = {
  for (final variant in const ['top', 'bottom'])
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.thread-pill.$variant.$theme': _case(),
};
