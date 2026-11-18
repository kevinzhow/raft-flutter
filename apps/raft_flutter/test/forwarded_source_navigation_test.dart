import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_ui/raft_ui.dart'
    show RaftTimelineBottomButtonBody, RaftToastHost;

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show MessageAdapter;
import 'support/history_paywall_fixture.dart' show hiddenMessage;
import 'task_content_slot_test.dart' show v2Task;
import 'task_surface_test.dart' show taskRoutes;
import 'workspace_source_location_contract_test.dart'
    show frames, mountPage, pageFixture, waitForPainted;

final _source = find.byKey(const Key('forwarded-bundle-source'));

const _thread = {
  'sourceTargetId': 'thread-1',
  'sourceThreadId': 'thread-1',
  'parentChannelId': 'c1',
  'sourceMessageId': 'old-reply',
  'sourceTargetSnapshot': {
    'id': 'c1',
    'type': 'thread',
    'label': '#test',
    'labelVisibility': 'public',
  },
};

const _task = {
  'sourceTargetId': 'task-conv',
  'parentChannelId': 'c1',
  'sourceTaskId': 'task-1',
  'sourceTaskNumber': 8,
  'sourceTaskTitle': 'Scoped actual task',
  'sourceMessageId': 'task-reply',
  'sourceTargetSnapshot': {
    'id': 'c1',
    'type': 'task',
    'label': '#test:#8',
    'labelVisibility': 'public',
  },
};

const _direct = {
  'sourceTargetId': 'c1',
  'sourceMessageId': 'channel-message',
  'sourceTargetSnapshot': {
    'id': 'c1',
    'type': 'channel',
    'label': '#test',
    'labelVisibility': 'public',
  },
};

Future<(WorkspaceController, MessageAdapter)> _forward(
  WidgetTester tester,
  Map<String, dynamic> source, {
  bool legacy = false,
}) async {
  final (w, api) = await pageFixture(tester, section: 'chat');
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  final destination = RaftChannel({
    'id': 'destination',
    'name': 'forward-destination',
    'type': 'channel',
    'joined': true,
  });
  w.channels = [...w.channels, destination];
  w.channel = destination;
  w.navigation.navigate(RaftLocation.parse('/s/demo/channel/destination'));
  final forwarded = {
    ...row('forward', destination.id, 1),
    'content': 'Forwarded 1 message',
    'actionMetadata': {
      'kind': 'forwarded-bundle',
      'version': 1,
      'forwardedItems': [
        {
          'index': 0,
          'sourceServerId': 's1',
          if (!legacy) 'provenanceState': 'available',
          'contentSnapshot': 'Forwarded reply snapshot',
          ...source,
        },
      ],
    },
  };
  api.routes['GET /messages/channel/destination'] = (_) => {
    'messages': [forwarded],
  };
  api.routes['GET /messages/channel/c1'] = (_) => {
    'messages': [row('thread-parent', 'c1', 1)],
  };
  api.routes['POST /channels/destination/read'] = (_) => {};
  api.routes['GET /announcements/active'] = (_) => {'announcements': []};
  w.messageDomain.ledger.ingest([
    forwarded,
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds[destination.id] = {'forward'};
  return (w, api);
}

void _taskRoutes(MessageAdapter api) {
  taskRoutes(api, v2Task);
  api.routes['GET /tasks/channel/c1'] = (_) => {
    'tasks': [v2Task],
  };
  api.routes['GET /tasks/task-1'] = (_) => {'task': v2Task};
  api.routes['GET /channels/task-conv'] = (_) => {
    'id': 'task-conv',
    'type': 'task',
    'taskId': 'task-1',
    'serverId': 's1',
    'parentChannelId': 'c1',
  };
  api.routes['GET /messages/context/task-reply'] = (_) => _taskReply();
  api.routes['GET /messages/channel/task-conv'] = (_) => {'messages': []};
  api.routes['POST /channels/task-conv/read'] = (_) => {};
}

Map<String, dynamic> _taskReply({bool deleted = false}) => {
  'channelId': 'task-conv',
  'targetMessageId': 'task-reply',
  'messages': [
    {
      ...row('task-reply', 'task-conv', 5),
      if (deleted) 'deletedAt': '2026-11-18T01:02:00Z',
    },
  ],
};

void main() {
  for (final (platform, width, height, fullPage) in [
    (TargetPlatform.linux, 1440.0, 900.0, false),
    (TargetPlatform.linux, 390.0, 844.0, false),
    (TargetPlatform.android, 856.0, 944.0, false),
    (TargetPlatform.android, 944.0, 856.0, false),
    (TargetPlatform.linux, 1440.0, 900.0, true),
  ]) {
    final pointer = platform == TargetPlatform.linux
        ? PointerDeviceKind.mouse
        : PointerDeviceKind.touch;
    testWidgets(
      fullPage
          ? 'a full visible page after a forwarded hidden reply can page newer'
          : 'forwarded old reply opens the history limit on $platform at $width',
      (t) async {
        final (w, api) = await _forward(t, _thread);
        api.routes['GET /messages/context/thread-parent'] = (_) => {
          'messages': [row('thread-parent', 'c1', 1)],
        };
        api.routes['GET /messages/context/old-reply'] = (_) => (
          404,
          {
            'error': 'Message not found',
            'code': 'history_limited',
            'channelId': 'thread-1',
            'targetMessageId': 'old-reply',
            'canonicalTarget': {
              'kind': 'thread',
              'channelId': 'c1',
              'threadChannelId': 'thread-1',
              'threadParentMessageId': 'thread-parent',
              'messageId': 'old-reply',
            },
            'hiddenTarget': {
              'target': {
                ...hiddenMessage('old-reply', text: 'The original older reply'),
                'seq': 5,
              },
              'before': [],
              'after': [],
              'thread': {
                'hiddenReplyCount': 1,
                'hiddenReplyCountCapped': false,
                'parentHidden': false,
              },
              'replies': null,
            },
          },
        );
        final last = fullPage ? 55 : 6;
        api.routes['GET /messages/channel/thread-1'] = (request) => {
          'messages': [
            if (fullPage && request.queryParameters['after'] != '5')
              row('newer-reply', 'thread-1', 56)
            else
              for (var seq = 6; seq <= last; seq++)
                row(
                  seq == last ? 'visible-reply' : 'reply-$seq',
                  'thread-1',
                  seq,
                ),
          ],
          'historyLimited': false,
        };
        api.routes['POST /channels/thread-1/read'] = (_) => {};
        await mountPage(
          t,
          w,
          false,
          width: width,
          height: height,
          platform: platform,
        );
        expect(_source.hitTestable(), findsOneWidget);
        await t.tap(_source, kind: pointer);
        await waitForPainted(t, 'visible-reply');
        expect(w.location.entityId, 'c1');
        expect(w.location.thread?.itemId, 'thread-parent');
        expect(w.threadChannelId, 'thread-1');
        expect(w.messageWindows.contextHasNewer('thread-1'), fullPage);
        if (!fullPage) {
          expect(
            find.byKey(const ValueKey('history-paywall-target')),
            findsOneWidget,
          );
          expect(find.text('The original older reply'), findsOneWidget);
        }
        expect(
          api.calls
              .where((r) => r.path == '/messages/context/old-reply')
              .map((r) => r.queryParameters['channelId']),
          ['c1', 'thread-1'],
        );
        expect(
          api.calls
              .singleWhere((r) => r.path == '/messages/channel/thread-1')
              .queryParameters['after'],
          '5',
        );
        if (fullPage) {
          await t.tap(
            find.byType(RaftTimelineBottomButtonBody).hitTestable().last,
            kind: pointer,
          );
          await waitForPainted(t, 'newer-reply');
          expect(w.messageWindows.contextHasNewer('thread-1'), isFalse);
        }
      },
    );

    if (fullPage) continue;
    testWidgets(
      'forwarded task reply opens in context on $platform at $width',
      (t) async {
        final (w, api) = await _forward(t, _task);
        _taskRoutes(api);
        await mountPage(
          t,
          w,
          false,
          width: width,
          height: height,
          platform: platform,
        );
        expect(_source.hitTestable(), findsOneWidget);
        await t.tap(_source, kind: pointer);
        await frames(t, () {});
        expect(w.location.query('task'), 'c1:task:task-1');
        await waitForPainted(t, 'task-reply');
        expect(w.location.taskFocusedConversationId, 'task-conv');
        expect(w.location.taskFocusedMessageId, 'task-reply');
        expect(w.location.entityId, 'destination');
        final reads = api.calls.where(
          (request) => request.path == '/messages/context/task-reply',
        );
        expect(reads, isNotEmpty);
        expect(
          reads.map((r) => r.queryParameters['channelId']),
          everyElement('task-conv'),
        );
      },
    );
  }

  for (final (name, source, channelType) in [
    (
      'redacted',
      <String, dynamic>{
        'sourceServerId': null,
        'sourceTargetSnapshot': {
          'id': null,
          'type': 'task',
          'label': '',
          'labelVisibility': 'restricted',
        },
      },
      'channel',
    ),
    ('missing task identity', {..._task, 'sourceTaskId': null}, 'channel'),
    (
      'unavailable',
      {..._task, 'provenanceState': 'original_unavailable'},
      'channel',
    ),
    ('private', _task, 'private'),
    ('revoked', _task, 'channel'),
  ]) {
    testWidgets('$name task source has no open affordance or source read', (
      t,
    ) async {
      final (w, api) = await _forward(t, source);
      w.channels = [
        RaftChannel({...w.channels.first.json, 'type': channelType}),
        w.channel!,
      ];
      if (name == 'revoked') w.sessionScope.revokeChannel('task-conv');
      await mountPage(t, w, false, platform: TargetPlatform.linux);
      await waitForPainted(t, 'forward');
      expect(_source, findsNothing);
      expect(
        api.calls.where(
          (r) =>
              r.path.endsWith('/task-conv') || r.path.endsWith('/task-reply'),
        ),
        isEmpty,
      );
    });
  }

  for (final (name, response) in [
    ('deleted', _taskReply(deleted: true)),
    ('denied', (403, {'error': 'Forbidden'})),
    ('missing', (404, {'error': 'Message not found'})),
  ]) {
    testWidgets('$name original task reply stays on the forward', (t) async {
      final (w, api) = await _forward(t, _task);
      _taskRoutes(api);
      api.routes['GET /messages/context/task-reply'] = (_) => response;
      await mountPage(
        t,
        w,
        false,
        platform: TargetPlatform.linux,
        builder: (_, child) => RaftToastHost(child: child!),
      );
      await t.tap(_source.hitTestable());
      await frames(t, () {});
      await t.pumpAndSettle();
      expect(
        find.text('Unable to open source. It may be unavailable or deleted.'),
        findsOneWidget,
      );
      expect(w.location.entityId, 'destination');
      expect(w.location.task, isNull);
      expect(
        api.calls.where((r) => r.path == '/messages/channel/task-conv'),
        isEmpty,
      );
    });
  }

  testWidgets('a revoked task conversation cannot open from a late reply', (
    t,
  ) async {
    final (w, api) = await _forward(t, _task);
    _taskRoutes(api);
    final reply = Completer<Map<String, dynamic>>();
    api.routes['GET /messages/context/task-reply'] = (_) => reply.future;
    addTearDown(() {
      if (!reply.isCompleted) reply.complete(_taskReply());
    });
    await mountPage(t, w, false, platform: TargetPlatform.linux);
    await t.tap(_source.hitTestable(), kind: PointerDeviceKind.mouse);
    await frames(t, () {});
    expect(
      api.calls.where((r) => r.path.endsWith('/task-reply')),
      hasLength(1),
    );
    w.sessionScope.revokeChannel('task-conv');
    reply.complete(_taskReply());
    await frames(t, () {});
    expect(w.location.entityId, 'destination');
    expect(w.location.task, isNull);
    if (_source.hitTestable().evaluate().isNotEmpty) {
      await t.tap(_source, kind: PointerDeviceKind.mouse);
      await frames(t, () {});
    }
    expect(api.calls.where((r) => r.path.endsWith('/task-conv')), hasLength(1));
    expect(w.location.task, isNull);
  });

  for (final legacy in [false, true]) {
    testWidgets(
      '${legacy ? 'Legacy' : 'Current'} public forward opens the direct source channel',
      (t) async {
        final (w, api) = await _forward(t, _direct, legacy: legacy);
        api.routes['GET /messages/context/channel-message'] = (_) => {
          'channelId': 'c1',
          'targetMessageId': 'channel-message',
          'messages': [row('channel-message', 'c1', 2)],
        };
        await mountPage(t, w, false, platform: TargetPlatform.linux);
        expect(_source.hitTestable(), findsOneWidget);
        await t.tap(_source);
        await frames(t, () {});
        await waitForPainted(t, 'channel-message');
        expect(w.location.entityId, 'c1');
        expect(w.location.thread, isNull);
        expect(w.location.task, isNull);
      },
    );
  }
}
