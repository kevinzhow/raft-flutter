import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'message_context_transition_test.dart' show row;
import 'task_content_slot_test.dart' show v2Task;

const _destination = 'abcd1234';
const _exactId = 'fedc1234';
const _exactText = 'Exact destination message body';
const _link =
    'https://app.slock.ai/s/alpha/channel/$_destination?msg=$_exactId';
const _discussion = 'task-conv';
const _thread = 'activity-target-thread';
const _threadParent = 'a54321dd';
const _threadReply = 'a54321ee';
const _threadText = 'Exact reply in the channel thread';
const _threadLink =
    'https://app.slock.ai/s/alpha/channel/ca?thread=ca:$_threadParent&msg=$_threadReply';
const _human = {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob'};
const _agent = {
  'id': 'a1',
  'name': 'cindy',
  'displayName': 'Cindy',
  'status': 'active',
  'runtime': 'claude',
  'model': 'sonnet',
};
const _senders = [
  (
    messageId: 'human-reply',
    kind: 'human',
    senderType: 'user',
    id: 'bob',
    name: 'Bob',
  ),
  (
    messageId: 'agent-reply',
    kind: 'agent',
    senderType: 'agent',
    id: 'a1',
    name: 'Cindy',
  ),
];

RootFixture _fixture({String? replyContent}) {
  final f = RootFixture();
  final task = {
    ...v2Task,
    'channelId': 'ca',
    'conversationReplyCount': _senders.length,
  };
  final replies = [
    for (final (index, reply) in _senders.indexed)
      {
        ...row(reply.messageId, _discussion, 14 + index),
        'seq': 14 + index,
        'content': index == 0 && replyContent != null
            ? replyContent
            : '${reply.name} task discussion reply',
        'senderId': reply.id,
        'senderType': reply.senderType,
        'senderName': reply.name,
        'createdAt': '2026-11-18T12:00:${14 + index}Z',
        'conversationContext': {
          'channelType': 'task',
          'taskId': 'task-1',
          'parentChannelId': 'ca',
        },
      },
  ];
  f.overrides.addAll({
    'GET /channels/inbox': (_) => {
      'items': [
        {
          'kind': 'task',
          'threadChannelId': _discussion,
          'parentChannelId': 'ca',
          'parentChannelName': 'general-a',
          'parentChannelType': 'channel',
          'parentMessageId': null,
          'taskId': 'task-1',
          'taskTitle': task['title'],
          'taskNumber': 8,
          'taskStatus': 'todo',
          'latestActivityPreview': 'Task row preview',
          'latestActivityMessageId': replies.last['id'],
          'latestActivitySeq': '${replies.last['seq']}',
          'lastActivityAt': replies.last['createdAt'],
          'replyCount': replies.length,
          'unreadCount': 0,
          'isFollowing': true,
        },
      ],
      'totalCount': 1,
      'totalUnreadCount': 0,
      'hasMore': false,
    },
    'GET /tasks/task-1': (_) => {'task': task},
    'GET /tasks/channel/ca': (_) => {
      'tasks': [task],
    },
    'GET /tasks/channel/ca/number/8': (_) => {'task': task},
    'GET /tasks/task-1/history': (_) => {'events': []},
    'GET /channels': (_) => [
      _channel('ca', 'general-a'),
      _channel(_destination, 'destination'),
    ],
    'GET /messages/channel/$_destination': (_) => {
      'messages': [
        {...row('latest', _destination, 3), 'content': 'Destination tail'},
      ],
      'hasMore': false,
    },
    'GET /messages/context/$_exactId': (_) => {
      'channelId': _destination,
      'targetMessageId': _exactId,
      'messages': [
        {...row(_exactId, _destination, 1), 'content': _exactText},
      ],
      'hasMore': false,
      'hasNewer': true,
    },
    'GET /channels/ca/threads/$_threadParent': (_) => {
      'threadChannelId': _thread,
    },
    'GET /messages/context/$_threadParent': (_) => {
      'messages': [row(_threadParent, 'ca', 2)],
    },
    'GET /messages/context/$_threadReply': (_) => {
      'channelId': _thread,
      'targetMessageId': _threadReply,
      'messages': [
        {...row(_threadReply, _thread, 3), 'content': _threadText},
      ],
    },
    'POST /channels/$_thread/read': (_) => {},
    'POST /channels/$_destination/read': (_) => {},
    'GET /channels/$_destination/members': (_) => {
      'humans': [],
      'agents': [],
      'externalMembers': [],
    },
    'GET /channels/ca': (_) => {
      'id': 'ca',
      'name': 'general-a',
      'type': 'channel',
      'serverId': 'a',
      'joined': true,
      'latestSeq': '1',
    },
    'GET /channels/$_discussion': (_) => {
      'id': _discussion,
      'type': 'task',
      'serverId': 'a',
      'taskId': 'task-1',
      'parentChannelId': 'ca',
    },
    'GET /messages/channel/$_discussion': (_) => {
      'messages': replies,
      'hasMore': false,
      'hasNewer': false,
    },
    'GET /messages/sync': (_) => [],
    'POST /channels/$_discussion/read': (_) => {},
    'POST /channels/$_discussion/read-all': (_) => {},
    'POST /feature-flags/evaluate': (_) => {'evaluations': []},
    'GET /announcements/active': (_) => {'announcements': []},
    'GET /agents': (_) => [_agent],
    'GET /agents/a1': (_) => _agent,
    'GET /agents/a1/skills': (_) => {'global': [], 'workspace': []},
    'GET /servers/a/machines': (_) => {'machines': []},
    'GET /servers/a/members': (_) => [_human],
    'GET /servers/a/members/bob/profile': (_) => _human,
  });
  return f;
}

Map<String, dynamic> _channel(String id, String name) => {
  'id': id,
  'name': name,
  'type': 'channel',
  'serverId': 'a',
  'joined': true,
  'latestSeq': '3',
};

final _task = find.byType(SourceTaskSurface);
final _timeline = _in(_task, find.byType(RaftChatView));
final _panel = find.byKey(const Key('profile-panel'));
Finder _in(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);
Finder _text(String text) => find.text(text, findRichText: true);

Future<void> _openActivityTask(
  WidgetTester t,
  RootFixture f, {
  Size viewport = const Size(1440, 900),
}) async {
  await f.mount(
    t,
    'light',
    viewport.width,
    uri: Uri.parse('/s/alpha/activity'),
  );
  if (t.view.physicalSize != viewport) {
    t.view.physicalSize = viewport;
    await f.flush(t);
  }
  await _tap(t, f, find.byKey(const Key('activity-thread-$_discussion')));
}

Future<void> _tap(WidgetTester t, RootFixture f, Finder target) async {
  expect(target.hitTestable(), findsOneWidget);
  await t.tap(
    target.hitTestable(),
    kind: defaultTargetPlatform == TargetPlatform.linux
        ? PointerDeviceKind.mouse
        : PointerDeviceKind.touch,
  );
  await f.flush(t);
}

void main() {
  setUpAll(() {
    // The native title-bar notifier lives for the process, outside each mount.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final _ = DesktopTitleBarController.platform.state;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final (sender, viewport, platform) in [
    for (final sender in _senders)
      (sender, const Size(1440, 900), TargetPlatform.linux),
    (_senders.last, const Size(856, 944), TargetPlatform.android),
    (_senders.first, const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets(
      'Activity task reply opens and closes the ${sender.kind} profile at ${viewport.width}×${viewport.height}',
      (t) async {
        final f = _fixture();
        try {
          await _openActivityTask(t, f, viewport: viewport);
          final reply = _in(
            _timeline,
            _text('${sender.name} task discussion reply'),
          );
          expect(reply, findsOneWidget);
          expect(_panel, findsNothing);
          await _tap(
            t,
            f,
            _in(
              _timeline,
              find.byKey(ValueKey('sender-avatar-${sender.messageId}')),
            ),
          );

          final profile = _in(
            _panel,
            find.byKey(ValueKey('profile-${sender.kind}-${sender.id}')),
          );
          expect(
            _in(profile, find.text(sender.name)).hitTestable(),
            findsWidgets,
          );
          expect(reply, findsOneWidget);
          await _tap(t, f, _in(profile, find.byTooltip('Close Profile')));
          expect(_panel, findsNothing);
          expect(reply.hitTestable(), findsOneWidget);
        } finally {
          await f.close(t);
        }
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final quote in [false, true]) {
    testWidgets(
      'Activity task ${quote ? 'quoted card' : 'permalink'} opens the exact message',
      (t) async {
        final f = _fixture(replyContent: 'See $_link');
        try {
          await _openActivityTask(t, f);
          final card = _in(
            _timeline,
            find.byKey(const Key('quoted-message-card')),
          );
          expect(card, findsOneWidget);
          await _tap(
            t,
            f,
            quote ? card : _in(_timeline, _text('#destination')),
          );
          expect(_task, findsNothing);
          final message = _in(find.byType(RaftChatView), _text(_exactText));
          expect(message.hitTestable(), findsOneWidget);
          expect(
            f.router(t).currentConfiguration.toString(),
            '/s/alpha/channel/$_destination?msg=$_exactId',
          );
        } finally {
          await f.close(t);
        }
      },
    );
  }

  testWidgets('Activity task opens the exact reply in a same-channel thread', (
    t,
  ) async {
    final f = _fixture(replyContent: 'See $_threadLink');
    try {
      await _openActivityTask(t, f);
      await _tap(t, f, _in(_timeline, _text('#general-a')));
      expect(_task, findsNothing);
      final thread = find.byWidgetPredicate(
        (widget) => widget is RaftChatView && widget.thread,
      );
      expect(_in(thread, _text(_threadText)).hitTestable(), findsOneWidget);
    } finally {
      await f.close(t);
    }
  });

  testWidgets(
    'Tasks detail slot opens its reply mention in the workspace profile',
    (t) async {
      final f = _fixture(replyContent: 'Ask @cindy');
      try {
        await f.mount(
          t,
          'light',
          1440,
          uri: Uri.parse('/s/alpha/tasks?open=task:task-1&task=ca:task:task-1'),
        );
        final mention = _in(_timeline, _text('@Cindy'));
        await _tap(t, f, mention);
        final profile = _in(_panel, find.byKey(const Key('profile-agent-a1')));
        expect(_in(profile, find.text('Cindy')).hitTestable(), findsWidgets);
        expect(mention.hitTestable(), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await f.flush(t);
        expect(_panel, findsNothing);
        expect(mention.hitTestable(), findsOneWidget);
      } finally {
        await f.close(t);
      }
    },
  );

  testWidgets('Activity task channel reference opens its channel timeline', (
    t,
  ) async {
    final f = _fixture(replyContent: 'See #destination');
    try {
      await _openActivityTask(t, f);
      await _tap(t, f, _in(_timeline, _text('#destination')));
      expect(_task, findsNothing);
      expect(
        _in(find.byType(RaftChatView), _text('Destination tail')).hitTestable(),
        findsOneWidget,
      );
    } finally {
      await f.close(t);
    }
  });

  for (final (width, platform) in [
    (390.0, TargetPlatform.android),
    (390.0, TargetPlatform.linux),
    (1440.0, TargetPlatform.linux),
  ]) {
    final dismiss = width < 768 ? 'Back' : 'Close Profile';
    testWidgets('Task profile $dismiss returns to the discussion at $width', (
      t,
    ) async {
      final f = _fixture();
      try {
        await f.mount(
          t,
          'light',
          width,
          uri: Uri.parse(
            '/s/alpha/channel/ca?task=ca:task:task-1&taskConversation=$_discussion',
          ),
        );
        if (width < 768) {
          t.view.physicalSize = Size(width, 844);
          await f.flush(t);
        }
        final reply = _in(_timeline, _text('Bob task discussion reply'));
        expect(reply, findsOneWidget);
        await _tap(
          t,
          f,
          _in(_timeline, find.byKey(const Key('sender-avatar-human-reply'))),
        );
        final profile = _in(_panel, find.byKey(const Key('profile-human-bob')));
        expect(_in(profile, find.text('Bob')).hitTestable(), findsWidgets);
        await _tap(t, f, _in(profile, find.byTooltip(dismiss)));
        expect(_panel, findsNothing);
        expect(reply.hitTestable(), findsOneWidget);
      } finally {
        await f.close(t);
      }
    }, variant: TargetPlatformVariant.only(platform));
  }
}
