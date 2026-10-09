// Official cases owned by this group (default selection):
//   components.thread.message.row
//   components.thread.message-row.deleted-human
//   components.thread.message-menu.default
//   components.thread.message-menu.task
//   components.thread.message-share.selection
//   components.thread.forward-modal
//   components.thread.comment-anchor
//   components.thread.message-row.rich-content
//   components.thread.message-row.long-inline-code
//   components.thread.message-row.md-link-ref
//   components.thread.message-row.md-latest-release
//   components.thread.message-row.md-wrap-slice1
//   components.thread.message-row.md-wrap-clarify
//   components.thread.message-row.md-wrap-adjacent
//   components.thread.message-row.md-wrap-status606
//   components.thread.message-row.md-wrap-task607
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [threadMessageUncovered] with an honest reason.
//
// Most message rows are mounted via RaftChatView (features/
// chat_view.dart) over a canned RaftClient (thread_messages/chat_stage.dart)
// fed the same Message/Task/threadSummary values VisualTestingCases.tsx
// passes to MessageItem. Element crops window onto the mounted
// RaftMessageRow box, sized to React's MessageItem width.
// The linked-only task case mounts the real RaftMessageTile/MessagePresentation
// directly: Source supplies linkedTask without seeding channelTasks, so that
// task must not enter the bare-reference directory used by Markdown labels.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_comments_view.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/forward_messages_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'thread_messages/chat_stage.dart';

const _rowWidgets = [
  'raft_flutter:RaftChatView',
  'raft_flutter:MessagePresentation',
  'raft_ui:RaftMessageTile',
  'raft_ui:RaftMessageRow',
  'raft_ui:RaftMessageBody',
  'raft_ui:RaftAvatar',
  'raft_ui:RaftMountedMessageTaskChip',
  'raft_ui:RaftMountedReaction',
];

const _clockNote =
    'SourceTimeFormatter.messageTime reads DateTime.now() (no injectable '
    'clock); fixture dates are in the same year as both the fixture now and '
    'the host clock, so the label format matches.';

Map<String, dynamic> _fx(ParityContext ctx) => ctx.fixtureData;
String _msg(ParityContext ctx, String key) =>
    _fx(ctx)['messages'][key] as String;
Map<String, dynamic> _cindy(ParityContext ctx) =>
    Map.from(_fx(ctx)['agents']['cindy']);
Map<String, dynamic> _owner(ParityContext ctx) =>
    Map.from(_fx(ctx)['humans']['owner']);

Map<String, dynamic> _cindyMessage(
  ParityContext ctx, {
  required String id,
  required String content,
  required String createdAt,
  String channelId = 'channel-design',
  String? threadId,
  List<Map<String, dynamic>> mentions = const [],
  List<Map<String, dynamic>> attachments = const [],
  List<Map<String, dynamic>> reactions = const [],
}) => {
  'id': id,
  'channelId': channelId,
  'senderType': 'agent',
  'senderId': _cindy(ctx)['id'],
  'senderName': _cindy(ctx)['displayName'],
  'content': content,
  'threadId': threadId,
  'createdAt': createdAt,
  if (mentions.isNotEmpty) 'mentions': mentions,
  if (attachments.isNotEmpty) 'attachments': attachments,
  if (reactions.isNotEmpty) 'reactions': reactions,
};

Map<String, dynamic> _thumbs(ParityContext ctx, int count) => {
  'emoji': '👍',
  'count': count,
  'reactorIds': [_owner(ctx)['id']],
  'reactorNames': [_owner(ctx)['name']],
};

Map<String, dynamic> _summary(
  ParityContext ctx, {
  required String threadChannelId,
  required int replyCount,
  required int unreadCount,
  required String? firstUnread,
  required String lastReplyAt,
}) => {
  'threadChannelId': threadChannelId,
  'replyCount': replyCount,
  'lastReplyAt': lastReplyAt,
  'participantIds': [_owner(ctx)['id'], _cindy(ctx)['id']],
  'unreadCount': unreadCount,
  'firstUnreadMessageId': firstUnread,
};

Map<String, dynamic> _task(
  ParityContext ctx, {
  required String id,
  required String messageId,
  required int number,
  required String title,
  required String status,
  String channelId = 'channel-design',
  String channelName = 'design',
  required String createdAt,
}) => {
  'id': id,
  'messageId': messageId,
  'channelId': channelId,
  'channelName': channelName,
  'channelType': 'channel',
  'taskNumber': number,
  'title': title,
  'status': status,
  'claimedByType': 'agent',
  'claimedById': _cindy(ctx)['id'],
  'claimedByName': _cindy(ctx)['displayName'],
  'createdById': _owner(ctx)['id'],
  'createdByType': 'user',
  'createdByName': _owner(ctx)['name'],
  'createdAt': createdAt,
};

/// A single-row element case: React `<main p-4|p-0><div width=W>` holding one
/// MessageItem.
ParityCase _rowCase({
  required ChatStage Function(ParityContext ctx) stage,
  String notes = '',
}) => ParityCase(
  widgets: _rowWidgets,
  notes: [_clockNote, if (notes.isNotEmpty) notes].join(' '),
  build: (ctx) => stageFor(ctx, () => stage(ctx)).build(),
  interact: (t, ctx) => stageFor(ctx, () => stage(ctx)).alignRow(t),
);

const _noRepliesChip =
    'The mounted Flutter row draws no thread "N replies · M new" footer chip '
    '(RaftMessageTile only shows a thread label when no hover toolbar is '
    'supplied, and the summary carries no latestReplies for an inline '
    'preview); React MessageItem does.';

const _markdownChannel = (
  id: 'channel-markdown',
  name: 'markdown专修',
  desc: 'Markdown parity fixtures',
);
const _conversationChannel = (
  id: 'channel-conversation-flow',
  name: '对话流专修',
  desc: 'Conversation stream fixes',
);

Map<String, dynamic> _extra(
  ParityContext ctx,
  ({String id, String name, String desc}) c,
) => ParityIdentities(ctx).extraChannel(c.id, c.name, c.desc);

/// thread-message / thread-message-menu fixtures share one Message shape.
ChatStage _agentReplyStage(
  ParityContext ctx, {
  required String id,
  required String content,
  required String threadId,
  required Map<String, dynamic> summary,
  Map<String, dynamic>? task,
  bool targetRow = true,
  Color? backgroundColor,
}) => ChatStage(
  ctx,
  rowWidth: 390,
  rowOrigin: const Offset(16, 16),
  targetRow: targetRow,
  backgroundColor: backgroundColor,
  messages: [
    _cindyMessage(
      ctx,
      id: id,
      content: content,
      threadId: threadId,
      createdAt: '2026-06-22T02:30:00.000Z',
      reactions: [_thumbs(ctx, 2)],
    ),
  ],
  threadSummaries: {id: summary},
  tasks: [?task],
);

ChatStage _menuStage(ParityContext ctx) {
  final task = ctx.id.endsWith('.task');
  final id = task ? 'msg-menu-task' : 'msg-menu-default';
  final threadId = task ? 'thread-msg-menu-task' : 'thread-msg-menu-default';
  return _agentReplyStage(
    ctx,
    id: id,
    targetRow: false,
    // Source VisualTestingCases.tsx3500: fixed white caller, including dark.
    backgroundColor: Colors.white,
    content: task
        ? 'Task conversion follow-up for #design: capture the grouped menu '
              'before publish.'
        : _msg(ctx, 'threadDefault'),
    threadId: threadId,
    summary: {
      'threadChannelId': threadId,
      'replyCount': 3,
      'participantIds': [_cindy(ctx)['id'], _owner(ctx)['id']],
      'unreadCount': 0,
      'firstUnreadMessageId': null,
      'lastReplyAt': '2026-06-22T02:35:00.000Z',
    },
    task: task
        ? _task(
            ctx,
            id: 'task-menu-246',
            messageId: id,
            number: 246,
            title: 'Message context menu visual coverage',
            status: 'in_progress',
            createdAt: '2026-06-22T02:30:00.000Z',
          )
        : null,
  );
}

/// Long-press on the row's avatar gutter: the body sits in a SelectionArea,
/// so a long-press on text starts text selection (product behavior) instead
/// of RaftMessageRow.onLongPress → actions sheet.
Future<void> _longPressRow(WidgetTester t, int index) async {
  final avatar = find.descendant(
    of: find.byType(RaftMessageRow).at(index),
    matching: find.byType(RaftAvatar),
  );
  await t.longPress(avatar.first, warnIfMissed: false);
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// React dispatches `contextmenu` at the centre of `#message-<id>` (the
/// MessageItem box inside its margins); Flutter right-clicks the same point,
/// which opens the same RaftMessageContextMenu as a touch long-press.
Future<void> _contextMenuRow(WidgetTester t, int index) async {
  // A device runs resumed: the body's SelectableRegion clears its collapsed
  // right-click selection when the opened menu takes focus.
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final row = find.byType(RaftMessageRow).at(index);
  final box = find.descendant(of: row, matching: find.byType(Container)).first;
  await t.tapAt(
    t.getCenter(box),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

final ParityCase _menu = ParityCase(
  widgets: [
    ..._rowWidgets,
    'raft_flutter:RaftChatView.actions',
    'raft_ui:RaftMessageContextMenu',
    'raft_ui:showRaftMessageContextMenu',
  ],
  notes: _clockNote,
  build: (ctx) => stageFor(ctx, () => _menuStage(ctx)).build(),
  interact: (t, ctx) async {
    final stage = stageFor(ctx, () => _menuStage(ctx));
    await stage.alignRow(t);
    await _contextMenuRow(t, 0);
  },
);

ChatStage _shareStage(ParityContext ctx) => ChatStage(
  ctx,
  messages: [
    _cindyMessage(
      ctx,
      id: 'msg-share-selection-1',
      content: _msg(ctx, 'threadDefault'),
      threadId: 'thread-msg-share-selection-1',
      createdAt: _fx(ctx)['times']['threadMessageAtIso'],
      reactions: [_thumbs(ctx, 2)],
    ),
    {
      'id': 'msg-share-selection-2',
      'channelId': 'channel-design',
      'senderType': 'user',
      'senderId': _owner(ctx)['id'],
      'senderName': _owner(ctx)['displayName'],
      'content': _msg(ctx, 'composerSeed'),
      'threadId': 'thread-msg-share-selection-2',
      'createdAt': _fx(ctx)['times']['threadReplyAtIso'],
    },
  ],
);

final ParityCase _shareSelection = ParityCase(
  widgets: [
    ..._rowWidgets,
    'raft_flutter:MessageSelection',
    'raft_ui:RaftSelectionToolbar',
  ],
  notes:
      '$_clockNote Selection entered through the real path: long-press row '
      '1 → "Select Message", tap row 2. The whole mounted RaftChatView is '
      'the viewport (timeline header/day divider included); React stacks two '
      'MessageItems over SelectModeToolbar.',
  build: (ctx) => stageFor(ctx, () => _shareStage(ctx)).build(),
  interact: (t, ctx) async {
    final stage = stageFor(ctx, () => _shareStage(ctx));
    await stage.settle(t, rows: 2);
    await _longPressRow(t, 0);
    await t.tap(
      find.text(
        raftText(t.element(find.byType(Scaffold).first), 'Select Message'),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.tap(find.byType(RaftMessageRow).at(1));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  },
);

ChatStage _forwardStage(ParityContext ctx) => ChatStage(
  ctx,
  // VisualTestingCases.tsx thread-forward-modal seeds dmChannels artin/Cindy.
  dms: [
    for (final (id, name) in [('dm-artin', 'artin'), ('dm-cindy', 'Cindy')])
      {
        'id': id,
        'serverId': ParityIdentities(ctx).serverId,
        'name': name,
        'description': null,
        'type': 'dm',
        'createdAt': '2026-06-18T00:00:00.000Z',
      },
  ],
  messages: [
    {
      'id': 'msg-forward-source',
      'channelId': 'channel-design',
      'senderType': 'user',
      'senderId': _owner(ctx)['id'],
      'senderName': _owner(ctx)['name'],
      'content': "Let's forward this to the right place.",
      'threadId': 'thread-forward-source',
      'createdAt': '2026-06-25T05:55:00.000Z',
    },
    {
      'id': 'msg-forward-source-2',
      'channelId': 'channel-design',
      'senderType': 'user',
      'senderId': _owner(ctx)['id'],
      'senderName': _owner(ctx)['name'],
      'content': 'Second forwarded message.',
      'threadId': 'thread-forward-source',
      'createdAt': '2026-06-25T05:55:00.000Z',
    },
  ],
);

final ParityCase _forward = ParityCase(
  widgets: const [
    'raft_flutter:forwardMessages',
    'raft_flutter:ForwardComposerPage',
    'raft_ui:RaftIconButton',
    'raft_ui:RaftControl',
  ],
  notes:
      'forwardMessages() on a 390px viewport opens ForwardComposerPage (Web '
      'ForwardComposerMobile target step) over the mounted #design chat.',
  build: (ctx) => stageFor(ctx, () => _forwardStage(ctx)).build(),
  interact: (t, ctx) async {
    final stage = stageFor(ctx, () => _forwardStage(ctx));
    await stage.settle(t, rows: 2);
    final context = t.element(find.byType(RaftChatView));
    forwardMessages(context, stage.w, stage.w.messages);
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  },
);

final Map<String, ParityCase> threadMessageCases = {
  'components.thread.message.row': _rowCase(
    notes: _noRepliesChip,
    stage: (ctx) => _agentReplyStage(
      ctx,
      id: 'msg-agent-reply',
      content: _msg(ctx, 'threadDefault'),
      threadId: 'thread-msg-agent-reply',
      summary: _summary(
        ctx,
        threadChannelId: 'thread-msg-agent-reply',
        replyCount: 5,
        unreadCount: 2,
        firstUnread: 'msg-agent-reply-4',
        lastReplyAt: '2026-06-22T03:05:00.000Z',
      ),
      task: _task(
        ctx,
        id: 'msg-agent-reply',
        messageId: 'msg-agent-reply',
        number: 10,
        title: _msg(ctx, 'threadDefault'),
        status: 'in_progress',
        createdAt: '2026-06-22T02:30:00.000Z',
      ),
    ),
  ),
  'components.thread.message-row.deleted-human': _rowCase(
    notes:
        'React hideThreadActions has no Flutter equivalent (the mounted row '
        'has no visible thread action on touch anyway).',
    stage: (ctx) => ChatStage(
      ctx,
      rowWidth: 390,
      rowOrigin: const Offset(16, 16),
      messages: [
        {
          'id': 'msg-deleted-human',
          'channelId': 'channel-design',
          'senderType': 'user',
          'senderId': 'visual-human-deleted',
          'senderName': 'Former Teammate',
          'senderDescription': 'Guest',
          'senderMembershipStatus': 'removed',
          'content': _msg(ctx, 'threadDeletedHuman'),
          'threadId': 'thread-msg-deleted-human',
          'createdAt': '2026-06-22T03:10:00.000Z',
          'reactions': [_thumbs(ctx, 1)],
        },
      ],
    ),
  ),
  'components.thread.message-menu.default': _menu,
  'components.thread.message-menu.task': _menu,
  'components.thread.message-share.selection': _shareSelection,
  'components.thread.forward-modal': _forward,
  'components.thread.comment-anchor': _commentAnchor,
  'components.thread.message-row.rich-content': _rowCase(
    notes: _noRepliesChip,
    stage: (ctx) => ChatStage(
      ctx,
      rowWidth: 342,
      rowOrigin: const Offset(16, 16),
      messages: [
        _cindyMessage(
          ctx,
          id: 'msg-rich-visual',
          content:
              'Rich fixture for #design: @artin please compare the Android '
              'capture against task #222 before publishing. Keep '
              'https://raft.build/visual-testing in the body so markdown '
              'links and long wrapping stay covered.',
          mentions: [
            {'type': 'user', 'id': _owner(ctx)['id'], 'name': 'artin'},
          ],
          threadId: 'thread-msg-rich-visual',
          createdAt: '2026-06-22T15:30:00.000Z',
          attachments: [
            {
              'id': 'att-visual-spec',
              'filename': 'visual-parity-notes.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 188416,
              'commentCount': 3,
            },
            {
              'id': 'att-thread-preview',
              'filename': 'thread-screen-preview.html',
              'mimeType': 'text/html',
              'sizeBytes': 32768,
            },
          ],
          reactions: [_thumbs(ctx, 3)],
        ),
      ],
      threadSummaries: {
        'msg-rich-visual': {
          'threadChannelId': 'thread-msg-rich-visual',
          'replyCount': 7,
          'participantIds': [_cindy(ctx)['id'], _owner(ctx)['id']],
          'unreadCount': 2,
          'firstUnreadMessageId': 'reply-rich-2',
          'lastReplyAt': '2026-06-22T15:32:00.000Z',
        },
      },
      tasks: [
        _task(
          ctx,
          id: 'task-222',
          messageId: 'msg-rich-visual',
          number: 222,
          title: 'Thread screens + rich message row fixture',
          status: 'in_progress',
          createdAt: '2026-06-22T15:28:00.000Z',
        ),
      ],
    ),
  ),
  'components.thread.message-row.long-inline-code': _rowCase(
    notes: _noRepliesChip,
    stage: (ctx) => ChatStage(
      ctx,
      rowWidth: 390,
      channelId: _markdownChannel.id,
      extraChannels: [_extra(ctx, _markdownChannel)],
      messages: [
        _cindyMessage(
          ctx,
          id: 'msg_long_inline_code_visual',
          channelId: _markdownChannel.id,
          content:
              'Plain text baseline before bold.\n\n'
              'Normal: regular markdown bold sample abcdefg 123.\n\n'
              '**Bold: regular markdown bold sample abcdefg 123.**\n\n'
              'Normal CN: 中文粗体 对照样本 123.\n\n'
              '**粗体 Bold: 中文粗体 markdown bold sample 123.**\n\n'
              'Tag chip coverage: mention @artin, channel #markdown专修, '
              'thread #markdown专修:692d9e88, tasks task #42 and task #43.\n\n'
              'Ordinary mention regression: @KMP-专家 #520 Phase 5: delete remaining ConversationSummary launch compatibility helpers.\n\n'
              'Short code should stay compact: `CODE_SPAN`, `raft.build.markdown.inlineCode`, `go test ./...`, and `git commit -s`.\n\n'
              'Long path should wrap inline without ellipsis: `reply/channel-markdown/msg-inline-visual/composer-draft-scroll-realtime-read-receipt/owner-key-consumes-thread-route-identity-only/without-source-thread-fallback/max-width-wrap-proof-alpha-beta-gamma-delta-epsilon-zeta-eta-theta-iota-kappa-lambda-mu`.\n\n'
              'Command should wrap with the same yellow fill and black frame: `./gradlew :shared:testDebugUnitTest --tests build.raft.app.markdown.SlockMarkdownTest --tests build.raft.app.visual.KmpVisualScreenshotCaptureTest.captureThreadMessageRowLongInlineCode`.\n\n'
              '> Quote block keeps normal markdown flow beside inline `code` and Slock tags.\n\n'
              '- Link: https://raft.build/visual-testing\n'
              '- File: `compose/shared/src/commonMain/kotlin/build/raft/app/markdown/SlockMarkdown.kt`',
          mentions: [
            {'type': 'user', 'id': _owner(ctx)['id'], 'name': 'artin'},
          ],
          threadId: 'thread-msg-long-inline-code-visual',
          createdAt: '2026-06-25T05:55:00.000Z',
          attachments: [
            {
              'id': 'att-markdown-fixture',
              'filename': 'standard-markdown-fixture.md',
              'mimeType': 'text/markdown',
              'sizeBytes': 6144,
            },
          ],
          reactions: [
            _thumbs(ctx, 3),
            {
              'emoji': '✅',
              'count': 1,
              'reactorIds': [_cindy(ctx)['id']],
              'reactorNames': [_cindy(ctx)['displayName']],
            },
          ],
        ),
      ],
      threadSummaries: {
        'msg_long_inline_code_visual': {
          'threadChannelId': 'thread-msg-long-inline-code-visual',
          'replyCount': 4,
          'participantIds': [_cindy(ctx)['id'], _owner(ctx)['id']],
          'unreadCount': 1,
          'firstUnreadMessageId': 'reply_long_inline_code_1',
          'lastReplyAt': '2026-06-25T05:57:00.000Z',
        },
      },
      tasks: [
        _task(
          ctx,
          id: 'task_42',
          messageId: 'msg_long_inline_code_visual',
          channelId: _markdownChannel.id,
          channelName: 'markdown',
          number: 42,
          title: 'Markdown inline code uses standard CODE_SPAN renderer',
          status: 'in_review',
          createdAt: '2026-06-25T05:50:00.000Z',
        ),
      ],
    ),
  ),
  'components.thread.message-row.md-link-ref': _linkedTaskCase,
  'components.thread.message-row.md-latest-release': _mdCase(
    id: 'msg_md_latest_release_visual',
    width: 390,
    createdAt: '2026-07-19T13:03:00.000Z',
    content:
        '---\n\n'
        '明白，是我理解错了。你要的是一个**不需要先创建 share token 的稳定 latest release landing page**，'
        '类似 `/apps/<app>/latest`，打开永远展示当前最新版并可下载；不是让某条 `/share/<token>` 变成 rolling。\n\n'
        '我撤掉 PR #318 这套 rolling-share 设计，改做 app latest landing page，并复用现有 share 页的版本信息/下载体验。',
  ),
  'components.thread.message-row.md-wrap-slice1': _mdCase(
    id: 'msg_md_wrap_slice1_visual',
    width: 260,
    createdAt: '2026-07-13T05:55:00.000Z',
    extra: (
      id: 'channel-raft-mobile-reconcile',
      name: 'raft-mobile-reconcile',
      desc: 'Mobile V2 canonical envelope reconcile',
    ),
    mentions: (ctx) => [
      {'type': 'user', 'id': _owner(ctx)['id'], 'name': 'artin'},
      {'type': 'user', 'id': 'human-mahua', 'name': 'Mahua'},
      {'type': 'user', 'id': 'human-zhaoziqi', 'name': '赵梓淇'},
    ],
    content:
        '@artin **slice-1 已合入 main** —— PR #791 squash → `80e3162da`。\n\n'
        '- 重跑那个 flaky job **绿了**（`realtimeReadStatePreservesPartialSummaryAndReconcilesAcceptedRewind` 重跑即过，坐实是 flake 不是我的），Android/OHOS host/OHOS shared 三端 compile+test 全绿、sign-off 过、iOS skip。\n'
        '- **披露 merge actor**：走 `gh` 身份 `bytemain`（≠ commit author `HanXin`），squash-merge、删了分支。\n'
        '- 落地形态：flag `sync_core_messages_v0` **默认关 = 零行为变化**；开了才在旁边 shadow fold+persist（不可见、fail-open、eligibility 仍 false）。真实用户完全无感。\n'
        '- **AD2 的 mapper 解耦设计点**按你说的转 post-merge follow-up，我留着 observer-routed 方案等他定。\n'
        '- 我另外给 @Mahua 报了那个 flaky 测试（#787 的，main 上间歇误挂无关 PR）。\n\n'
        '**数据流接线地基这块落了。** 下一步 V2 归一化信封在 #raft-mobile-reconcile 跟 @赵梓淇 对齐字段（他是 canonical DRI）——赵定了形状我就落 mobile V2，然后翻 eligibility 就到你能"试效果"那步。',
  ),
  'components.thread.message-row.md-wrap-clarify': _mdCase(
    id: 'msg_md_wrap_clarify_visual',
    width: 260,
    createdAt: '2026-07-13T05:56:00.000Z',
    mentions: (ctx) => [
      {
        'type': 'agent',
        'id': _fx(ctx)['agents']['androidDev4']['id'],
        'name': _fx(ctx)['agents']['androidDev4']['name'],
      },
    ],
    content: '另外帮一个澄清避免混淆：#31（read-state→Activity，我的）和 @Android-Developer-4 的 **task #521**（`message:new`→Activity 即时新增，artin 原话"新消息来了 activity 没刷新"）是两个不同 gap，不是重复——Codex 早前建议的"#521 判重关闭"是把两者混了，AD4 已更正。#31 复用 versioned read-state fact，#521 是 SharedActivityStore 缺 message:new realtime，两条链路各修各的。',
  ),
  'components.thread.message-row.md-wrap-adjacent': _mdCase(
    id: 'msg_md_wrap_adjacent_visual',
    width: 390,
    createdAt: '2026-07-13T05:56:00.000Z',
    extra: _conversationChannel,
    content: '对照：#31 / #521 两块同行。\n\n紧凑：#31/#521。\n\n尾宽对照：task #607 与 #对话流专修。',
  ),
  'components.thread.message-row.md-wrap-status606': _mdCase(
    id: 'msg_md_wrap_status606_visual',
    width: 390,
    createdAt: '2026-07-13T11:25:00.000Z',
    extra: _conversationChannel,
    mentions: (ctx) => [
      {'type': 'user', 'id': _owner(ctx)['id'], 'name': 'artin'},
    ],
    content: 'Task #606 新真机基线已就绪：PR #785 exact `0e5a82b02` Alpha 已附在 #对话流专修:661a12bf，SHA-256 `db01c5e5b91f3696bfda64edde2fc31b3a40ffe9b508813d651a6de735e8a85b`。这是 process-owned decoded auth-session snapshot 根修包，不是日志抑制包；`8a5e542f4` 作废。\n\n等待 @artin 验普通导航/滚动及 `#/@` suggestion。若仍卡，以新 Hands 对比 auth durable cold-read 次数和 traversal/layout/draw；task #606 保持 In Progress，PR 不合。',
  ),
  'components.thread.message-row.md-wrap-task607': _mdCase(
    id: 'msg_md_wrap_task607_visual',
    width: 260,
    createdAt: '2026-07-13T05:57:00.000Z',
    extra: _conversationChannel,
    mentions: (ctx) => [
      {'type': 'user', 'id': _owner(ctx)['id'], 'name': 'artin'},
      {
        'type': 'agent',
        'id': 'agent-android-dev-2',
        'name': 'Android-Developer-2',
      },
    ],
    content: '@artin 建好了：**task #607**（#对话流专修，我已 claim）——slice-1 那个 mapper→network.sync 解耦 follow-up。scope + @Android-Developer-2 的 A/B 设计选择（接受耦合 vs observer-routed 重构）我贴在 task thread 了。AD2 定 A 我 close 成 by-design，定 B 我实现。V2 那条独立、等赵定信封。',
  ),
};

/// Source md-link-ref supplies only MessageItem.linkedTask, not channelTasks.
/// Mount the same real row/presentation widgets with that prop distinction;
/// other cases retain the complete chat/store host.
final _linkedTaskCase = ParityCase(
  widgets: const [
    'raft_flutter:MessagePresentation',
    'raft_ui:RaftMessageTile',
    'raft_ui:RaftMessageRow',
    'raft_ui:RaftMessageBody',
    'raft_ui:RaftAvatar',
    'raft_ui:RaftMountedMessageTaskChip',
  ],
  notes: 'Matches Source MessageItem linkedTask input separately from its known channel/server task directory. The task is available to explicit references and the footer; its bare number in an authored link remains external link text.',
  build: (ctx) {
    final ids = ParityIdentities(ctx);
    final channel = ids.extraChannel(
      'channel-visual-testing',
      'visual-testing',
      'Visual parity fixtures',
    );
    final w = WorkspaceController(ParityRaftClient({}, user: ids.user))
      ..server = RaftRecord(ids.server)
      ..channel = RaftChannel(channel)
      ..channels = [RaftChannel(channel)];
    addTearDown(w.dispose);
    final message = RaftMessage(
      _cindyMessage(
        ctx,
        id: 'msg_md_link_ref_visual',
        channelId: 'channel-visual-testing',
        content:
            'Review [#1487 feat(search): pin entities from long-press and channel settings](https://github.com/botiverse/mobile/pull/1487) then follow task #1487.\n\n'
            'Channel ref in label: [notes in #visual-testing](https://raft.build/visual-testing) and outside #visual-testing.\n\n'
            'Mention in label: [ping @artin](https://raft.build/mentions) and outside @artin.',
        mentions: [
          {'type': 'user', 'id': _owner(ctx)['id'], 'name': 'artin'},
        ],
        threadId: 'thread-msg-md-link-ref-visual',
        createdAt: '2026-07-25T08:20:00.000Z',
      ),
    );
    final task = _task(
      ctx,
      id: 'task_1487',
      messageId: message.id,
      channelId: message.channelId,
      channelName: 'visual-testing',
      number: 1487,
      title: 'feat(search): pin entities from long-press and channel settings',
      status: 'in_review',
      createdAt: '2026-07-25T07:50:00.000Z',
    );
    return Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: ctx.target(
          SizedBox(
            width: 390,
            child: RaftMessageTile(
              author: message.author,
              content: message.content,
              timestamp: SourceTimeFormatter(
                preferredTimezone: ids.owner['timezone'],
                preferredTimeFormat: sourceTimeFormatPreference(
                  ids.owner['timeFormat'],
                ),
              ).messageTime(message.createdAt),
              modelLabel: 'GPT-5 Codex',
              subtitle: ids.cindy['description'],
              collapseLongMessages: false,
              coarsePointer: true,
              hoverToolbar: const RaftMessageToolbar(children: []),
              avatar: RaftAvatar(
                name: ids.cindy['displayName'],
                kind: RaftAvatarKind.agent,
                mountedContext: RaftMountedAvatarContext.panelHeader,
                presence: const RaftAvatarPresence(
                  activity: RaftAvatarActivity.working,
                ),
                content: RaftAvatarContent(
                  name: ids.cindy['displayName'],
                  kind: RaftAvatarContentKind.agent,
                  pixelKey: (ids.cindy['avatar'] as String).substring(6),
                ),
              ),
              body: MessagePresentation(
                controller: w,
                message: message,
                onExternalLink: (_) {},
                taskByNumber: (n) => n == 1487 ? task : null,
                knownTaskNumber: (_) => false,
              ),
              taskReference: RaftMountedMessageTaskChip(
                number: 1487,
                status: RaftMessageTaskStatus.inReview,
                claimant: 'Cindy',
                title: task['title'],
                openLabel: 'Open task',
                tooltipLabel: task['title'],
                onOpen: () {},
              ),
            ),
          ),
        ),
      ),
    );
  },
);

/// Narrow/standard markdown rows: React `<main p-0><div width=W>` with one
/// Cindy MessageItem in channel-markdown, no task/summary/reactions.
ParityCase _mdCase({
  required String id,
  required double width,
  required String createdAt,
  required String content,
  ({String id, String name, String desc})? extra,
  List<Map<String, dynamic>> Function(ParityContext ctx)? mentions,
}) => _rowCase(
  notes:
      'Both providers receive the complete owner-authorized public task '
      'fixture (787/31/521/607/606), replacing the reference host\'s '
      'invalid number-only records. Original message bodies and widths '
      'remain unchanged; prior defective React captures are archived.',
  stage: (ctx) => ChatStage(
    ctx,
    rowWidth: width,
    channelId: _markdownChannel.id,
    extraChannels: [
      _extra(ctx, _markdownChannel),
      if (extra != null) _extra(ctx, extra),
    ],
    tasks: [
      for (final task in ctx.fixtures['markdownTasksFixture']['tasks'] as List)
        Map<String, dynamic>.from(task as Map),
    ],
    messages: [
      _cindyMessage(
        ctx,
        id: id,
        channelId: _markdownChannel.id,
        content: content,
        mentions: mentions?.call(ctx) ?? const [],
        threadId: 'thread-${id.replaceAll('_', '-')}',
        createdAt: createdAt,
      ),
    ],
  ),
);

final Map<String, ParityUncovered> threadMessageUncovered = {};

/// VisualTestingCases.tsx thread-comment-anchor: AttachmentCommentsPanel for
/// att-anchor-1 (390x844) with an md-section pending anchor; the comments
/// come from react-provider.spec's /attachments/att-anchor-1/comments stub.
final ParityCase _commentAnchor = ParityCase(
  widgets: const [
    'raft_flutter:AttachmentCommentsView',
    'raft_ui:RaftAttachmentCommentsPanel',
    'raft_ui:RaftCommentAnchorChip',
    'raft_ui:RaftComposer(compact)',
  ],
  notes: 'Same comment payload as the React spec stub, served by the canned client.',
  build: (ctx) {
    final ids = ParityIdentities(ctx);
    final client = ParityRaftClient({
      'GET /attachments/att-anchor-1/comments': (_) => {
        'comments': [
          {
            'id': 'comment-anchor-1',
            'channelId': 'channel-anchor-1',
            'senderType': 'user',
            'senderId': 'user-anchor-2',
            'senderName': 'Artea',
            'content':
                'Please keep the tag inset consistent with the field below.',
            'createdAt': '2026-06-25T10:32:00.000Z',
            'reactions': [],
            'anchor': {
              'type': 'md-section',
              'data': {
                'headingId': 'agent-tabs-full-page-review',
                'headingTitle': 'agent-tabs-full-page-review.mp4',
              },
            },
            'senderAvatarUrl': null,
            'senderGravatarHash': null,
          },
        ],
        'threadChannelId': 'channel-anchor-1',
        'viewer': {'canComment': true},
      },
    }, user: ids.user);
    final w = WorkspaceController(client)
      ..server = RaftRecord(ids.server)
      ..channels = [RaftChannel(ids.channel('design'))];
    return Scaffold(
      body: ctx.target(
        SizedBox(
          width: 390,
          height: 844,
          child: AttachmentCommentsView(
            controller: w,
            attachmentId: 'att-anchor-1',
            filename: 'agent-tabs-full-page-review.mp4',
            pendingAnchor: const {
              'type': 'md-section',
              'data': {
                'headingId': 'agent-tabs-full-page-review',
                'headingTitle': 'agent-tabs-full-page-review.mp4',
              },
            },
          ),
        ),
      ),
    );
  },
);
