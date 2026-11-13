// Server v1.24.0 task v2 (`task_v2_conversations_v0`): POST
// /tasks/convert-message answers 409 `task_v2_use_create`; Web MessageItem
// offers "Create task from message" instead, a CreateTaskDialog whose tasks
// hang under the message (`POST /tasks/channel/:id`, `sourceMessageId`).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, (int, Object) Function(RequestOptions)>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final (status, body) = route == null
        ? (404, {'error': 'Unexpected endpoint'})
        : route(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(WorkspaceController, _Adapter)> _fixture() async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => (
    200,
    {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    },
  );
  a.routes['POST /tasks/convert-message'] = (_) => (
    409,
    {
      'error': 'Create a task from this message instead.',
      'code': 'task_v2_use_create',
    },
  );
  a.routes['POST /tasks/channel/c1'] = (o) => (
    200,
    {
      'tasks': [
        {'id': 't1', 'title': 'x', 'sourceMessageId': 'm'},
      ],
    },
  );
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  return (w, a);
}

Future<void> _openMenu(WidgetTester t, WorkspaceController w) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1280, 900);
  addTearDown(t.view.reset);
  w.messageDomain.ledger.switchServer('s1');
  w.messageDomain.ledger.ingest([
    {
      'id': 'm',
      'channelId': 'c1',
      'seq': '1',
      'messageType': 'chat',
      'content': 'Ship the   v1.24\ncompatibility patch',
      'senderName': 'Alice',
    },
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['c1'] = {'m'};
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(body: RaftChatView(controller: w)),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  t.widget<RaftMessageTile>(find.byType(RaftMessageTile)).onActions!();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _createFromDialog(WidgetTester t, _Adapter a) async {
  expect(find.text('Create task from message'), findsWidgets);
  expect(
    find.byKey(const ValueKey('create-task-source-message')),
    findsOneWidget,
  );
  final title = find.descendant(
    of: find.byKey(const ValueKey('create-task-title-0')),
    matching: find.byType(EditableText),
  );
  expect(
    t.widget<EditableText>(title).controller.text,
    'Ship the v1.24 compatibility patch',
  );
  await t.tap(find.byKey(const ValueKey('create-task-submit')));
  await _settle(t);
  final post = a.calls.singleWhere(
    (c) => c.method == 'POST' && c.path == '/tasks/channel/c1',
  );
  expect(post.data, {
    'tasks': [
      {'title': 'Ship the v1.24 compatibility patch', 'sourceMessageId': 'm'},
    ],
    'status': 'todo',
  });
}

void main() {
  testWidgets('task v2: 409 task_v2_use_create creates the task from the '
      'message', (t) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    await _openMenu(t, w);
    await t.tap(find.text('Convert to Task'));
    await _settle(t);
    expect(
      a.calls.where((c) => c.path == '/tasks/convert-message'),
      hasLength(1),
    );
    await _createFromDialog(t, a);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('task v2 flag on: the menu creates from the message, never '
      'converts', (t) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    a.routes['POST /feature-flags/evaluate'] = (_) => (
      200,
      {
        'evaluations': [
          {'key': 'task_v2_conversations_v0', 'enabled': true},
        ],
      },
    );
    await _openMenu(t, w);
    // Opening a menu sends nothing; the action reads the flag first and, on a
    // task v2 server, creates from the message without converting.
    expect(a.calls.where((c) => c.path == '/feature-flags/evaluate'), isEmpty);
    await t.tap(find.text('Convert to Task'));
    await _settle(t);
    await _createFromDialog(t, a);
    expect(a.calls.where((c) => c.path == '/tasks/convert-message'), isEmpty);
    // Known now: the next menu offers it by its task v2 name.
    t.widget<RaftMessageTile>(find.byType(RaftMessageTile)).onActions!();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Convert to Task'), findsNothing);
    expect(find.text('Create task from message'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
