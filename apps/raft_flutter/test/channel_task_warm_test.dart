import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;

/// Source ChatPanel loads a channel's tasks together with its messages. The
/// bucket read starts when the channel is selected or prefetched, in parallel
/// with the first message page, so the rows' task chips are in the first frame
/// that shows the rows. Nothing waits for the bucket.
Map<String, dynamic> _message(String id, int seq) => {
  'id': id,
  'channelId': 'c2',
  'seq': seq,
  'senderId': 'agent',
  'senderType': 'agent',
  'senderName': 'Cindy',
  'content': 'Body $id',
  'createdAt': '2026-06-22T02:3$seq:00Z',
};

Map<String, dynamic> _task(String messageId, int number) => {
  'id': 't-$messageId',
  'messageId': messageId,
  'channelId': 'c2',
  'taskNumber': number,
  'title': 'Task $number',
  'status': 'todo',
};

Future<(WorkspaceController, MessageAdapter, List<String>)> _fixture(
  WidgetTester t,
) async {
  final api = MessageAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = (await t.runAsync(() async {
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = api,
    );
    await client.login('fixture', 'fixture');
    return client;
  }))!;
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channels = [
    RaftChannel({'id': 'c1', 'name': 'one', 'joined': true}),
    RaftChannel({'id': 'c2', 'name': 'two', 'joined': true}),
  ];
  w.channel = w.channels.first;
  w.ledger.switchServer('s1');
  final reads = <String>[];
  api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
  api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
  api.routes['POST /channels/c2/read'] = (_) => {};
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  return (w, api, reads);
}

Future<void> _mount(WidgetTester t, WorkspaceController w) async {
  t.view.physicalSize = const Size(900, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: RaftChatView(controller: w),
        ),
      ),
    ),
  );
}

Future<void> _real(WidgetTester t, [int ms = 20]) =>
    t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

Future<void> _spin(WidgetTester t, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await _real(t, 5);
    await t.pump(const Duration(milliseconds: 16));
  }
}

Finder _row(String id) => find.byKey(ValueKey('message-$id'));
Finder _chip(String id) => find.byKey(ValueKey('message-task-$id'));

/// Pumps frames until [id]'s row paints; the chip must be in that frame.
Future<void> _firstFrameWithRow(WidgetTester t, String id) async {
  for (var i = 0; i < 40; i++) {
    await _real(t, 5);
    await t.pump(const Duration(milliseconds: 16));
    if (_row(id).evaluate().isNotEmpty) {
      expect(_chip(id), findsOneWidget, reason: 'chip in the first row frame');
      return;
    }
  }
  fail('row $id never painted');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final tasksFirst in [true, false]) {
    testWidgets(
      'first open: the task bucket and the message page start together and '
      'the chips are in the first frame with the rows '
      '(${tasksFirst ? 'tasks' : 'messages'} released first)',
      (t) async {
        final (w, api, _) = await _fixture(t);
        addTearDown(w.dispose);
        final page = Completer<dynamic>(), tasks = Completer<dynamic>();
        final started = <String>[];
        api.routes['GET /messages/channel/c2'] = (_) {
          started.add('page');
          return page.future;
        };
        api.routes['GET /tasks/channel/c2'] = (_) {
          started.add('tasks');
          return tasks.future;
        };
        await _mount(t, w);
        await _real(t);
        await t.pump();
        unawaited(w.selectChannel(w.channels[1]));
        await _spin(t);
        // Both reads are in flight before either answers.
        expect(started, containsAll(['page', 'tasks']));
        expect(started.where((s) => s == 'tasks'), hasLength(1));
        expect(_row('n1'), findsNothing);

        final pageBody = {
          'messages': [_message('n1', 1), _message('n2', 2)],
        };
        final tasksBody = {
          'tasks': [_task('n1', 7), _task('n2', 8)],
        };
        if (tasksFirst) {
          tasks.complete(tasksBody);
          page.complete(pageBody);
        } else {
          page.complete(pageBody);
          tasks.complete(tasksBody);
        }
        await _firstFrameWithRow(t, 'n1');
        expect(_chip('n2'), findsOneWidget);
        // The projection did not issue a second read of the same bucket.
        expect(started.where((s) => s == 'tasks'), hasLength(1));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      },
    );
  }

  testWidgets(
    'a slow task bucket never holds the timeline: rows paint without chips '
    'and the chips arrive in place',
    (t) async {
      final (w, api, _) = await _fixture(t);
      addTearDown(w.dispose);
      final tasks = Completer<dynamic>();
      api.routes['GET /messages/channel/c2'] = (_) => {
        'messages': [_message('n1', 1)],
      };
      api.routes['GET /tasks/channel/c2'] = (_) => tasks.future;
      await _mount(t, w);
      unawaited(w.selectChannel(w.channels[1]));
      for (var i = 0; i < 20 && _row('n1').evaluate().isEmpty; i++) {
        await _real(t, 5);
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(_row('n1'), findsOneWidget);
      expect(_chip('n1'), findsNothing);
      tasks.complete({
        'tasks': [_task('n1', 7)],
      });
      await _spin(t, 4);
      expect(_chip('n1'), findsOneWidget);
      expect(_row('n1'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'a channel selected while no chat is mounted has its chips when the rows '
    'first render',
    (t) async {
      final (w, api, _) = await _fixture(t);
      addTearDown(w.dispose);
      final page = Completer<dynamic>(), tasks = Completer<dynamic>();
      api.routes['GET /messages/channel/c2'] = (_) => page.future;
      // Only a read made before the release (at select time) answers; one
      // made when the chat mounts would hang.
      api.routes['GET /tasks/channel/c2'] = (_) =>
          tasks.isCompleted ? Completer<dynamic>().future : tasks.future;
      unawaited(w.selectChannel(w.channels[1]));
      await _spin(t);
      page.complete({
        'messages': [_message('n1', 1)],
      });
      tasks.complete({
        'tasks': [_task('n1', 7)],
      });
      await _spin(t);
      expect(w.messages.map((m) => m.id), ['n1']);
      await _mount(t, w);
      await _firstFrameWithRow(t, 'n1');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'a prefetched channel opens with its chips in the first frame of its rows',
    (t) async {
      final (w, api, _) = await _fixture(t);
      addTearDown(w.dispose);
      w.unread = {'c2': 2};
      final page = Completer<dynamic>();
      var pages = 0;
      final taskReads = <String>[];
      api.routes['GET /messages/channel/c2'] = (_) {
        // The first read is the prefetch; the open's own page is held.
        return ++pages == 1
            ? {
                'messages': [_message('n1', 1), _message('n2', 2)],
              }
            : page.future;
      };
      api.routes['GET /tasks/channel/c2'] = (_) {
        taskReads.add('c2');
        return {
          'tasks': [_task('n1', 7), _task('n2', 8)],
        };
      };
      await _mount(t, w);
      await _real(t);
      await t.runAsync(w.prefetchLikelyChannels);
      await _real(t);
      expect(pages, 1);
      expect(taskReads, ['c2']);
      expect(w.channel?.id, 'c1', reason: 'Prefetch never selects');

      unawaited(w.selectChannel(w.channels[1]));
      await _firstFrameWithRow(t, 'n1');
      expect(_chip('n2'), findsOneWidget);
      // A fresh cached bucket is not read again on open.
      expect(taskReads, ['c2']);
      page.complete({
        'messages': [_message('n1', 1), _message('n2', 2)],
      });
      await _spin(t, 4);
      expect(_chip('n1'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );
}
