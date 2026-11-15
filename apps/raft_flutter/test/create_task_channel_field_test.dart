// Web v1.24 CreateTaskDialog without a channelId (the Tasks page's New task):
// a Post in / Channel field, "Pick a channel" under it when none is picked.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final body = switch (o.path) {
      '/auth/login' => {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      },
      _ => {'tasks': <dynamic>[]},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(WorkspaceController, _Adapter)> _fixture({required bool v2}) async {
  final a = _Adapter();
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channels = [
    RaftChannel({'id': 'c2', 'name': 'beta', 'joined': true}),
    RaftChannel({'id': 'c1', 'name': 'alpha', 'joined': true}),
    RaftChannel({
      'id': 'c3',
      'name': 'old',
      'joined': true,
      'archivedAt': '2026-01-01',
    }),
    RaftChannel({'id': 'c4', 'name': 'away', 'joined': false}),
    RaftChannel({
      'id': 'c5',
      'name': 'quiet',
      'joined': true,
      'canPost': false,
    }),
  ];
  if (v2) TaskV2ConversationsFlag.of(w).markEnabled();
  return (w, a);
}

Future<void> _open(WidgetTester t, WorkspaceController w) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1280, 900);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: CreateTaskDialog.forChannel(
          controller: w,
          channelId: null,
          defaultChannelId: null,
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Iterable<RequestOptions> _posts(_Adapter a) =>
    a.calls.where((c) => c.method == 'POST' && c.path.startsWith('/tasks/'));

Future<void> _pick(WidgetTester t, String id) async {
  await t.tap(find.byKey(const ValueKey('create-task-channel')));
  await t.pump(const Duration(milliseconds: 300));
  expect(find.byKey(ValueKey('create-task-channel-$id')), findsOneWidget);
  await t.tap(find.byKey(ValueKey('create-task-channel-$id')));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('task v2, no channel: Post in field, none picked is refused '
      'under the field, a pick sends status and sourceRandomId', (t) async {
    final (w, a) = (await t.runAsync(() => _fixture(v2: true)))!;
    addTearDown(w.dispose);
    await _open(t, w);
    expect(find.byKey(const ValueKey('create-task-message-dialog')), findsOne);
    expect(find.text('Post in'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-task-posts-in')), findsNothing);
    expect(find.text('Choose a channel'), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('create-task-message')),
      'Ship it\nthe details',
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('create-task-submit')));
    await _settle(t);
    expect(find.text('Pick a channel'), findsOneWidget);
    expect(_posts(a), isEmpty);
    // Own, joined, live, postable channels only, sorted by name.
    await t.tap(find.byKey(const ValueKey('create-task-channel')));
    await t.pump(const Duration(milliseconds: 300));
    for (final id in ['c1', 'c2']) {
      expect(find.byKey(ValueKey('create-task-channel-$id')), findsOneWidget);
    }
    for (final id in ['c3', 'c4', 'c5']) {
      expect(find.byKey(ValueKey('create-task-channel-$id')), findsNothing);
    }
    expect(
      t.getTopLeft(find.byKey(const ValueKey('create-task-channel-c1'))).dy,
      lessThan(
        t.getTopLeft(find.byKey(const ValueKey('create-task-channel-c2'))).dy,
      ),
    );
    await t.tap(find.byKey(const ValueKey('create-task-channel-c2')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Pick a channel'), findsNothing);
    await t.tap(find.byKey(const ValueKey('create-task-message')));
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(t);
    final post = _posts(a).single;
    expect(post.path, '/tasks/channel/c2');
    final data = post.data as Map;
    expect(data['status'], 'todo');
    expect(data['sourceRandomId'], isA<String>());
    expect(data['tasks'], [
      {'title': 'Ship it', 'description': 'the details'},
    ]);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('flag off, no channel: titles dialog with a Channel field and '
      'no status; Enter in a title row submits', (t) async {
    final (w, a) = (await t.runAsync(() => _fixture(v2: false)))!;
    addTearDown(w.dispose);
    await _open(t, w);
    expect(find.byKey(const ValueKey('create-task-dialog')), findsOneWidget);
    expect(find.text('Channel'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-task-status')), findsNothing);
    await t.enterText(
      find.byKey(const ValueKey('create-task-title-0')),
      'First',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _settle(t);
    expect(find.text('Pick a channel'), findsOneWidget);
    expect(_posts(a), isEmpty);
    await _pick(t, 'c1');
    expect(find.text('Pick a channel'), findsNothing);
    await t.tap(find.byKey(const ValueKey('create-task-title-0')));
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _settle(t);
    final post = _posts(a).single;
    expect(post.path, '/tasks/channel/c1');
    expect(post.data, {
      'tasks': [
        {'title': 'First'},
      ],
    });
    await t.pumpWidget(const SizedBox());
  });
}
