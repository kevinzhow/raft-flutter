// Task v2 (Web v1.24 ChatPanel `taskListsByMessageId` + TaskChipList): a
// message may be the source of many tasks; they hang under it as one list,
// replacing the single footer chip. With the flag off a pre-v2 task keeps its
// single chip, and a task made the v2 way still lists under its source. A
// task in Backlog is shown, not dropped. New task without a source message
// is a message the person sends (CreateTaskMessageDialog).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, (int, Object?) Function(RequestOptions)>{};
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

Map<String, dynamic> _task(
  String id,
  int number,
  String status, {
  bool v2 = true,
  String? source = 'm',
}) => {
  'id': id,
  'taskNumber': number,
  'title': 'Task $number',
  'status': status,
  'channelId': 'c1',
  'messageId': v2 ? id : 'm',
  'hostMessageId': v2 ? null : 'm',
  'sourceMessageId': source,
  'conversationAnchored': v2,
  'conversationChannelId': v2 ? 'conv-$id' : null,
  'conversationReplyCount': v2 ? 3 : 0,
  'isLegacy': false,
};

Future<(WorkspaceController, _Adapter)> _fixture({
  required bool flag,
  required List<Map<String, dynamic>> tasks,
}) async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => (
    200,
    {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    },
  );
  a.routes['POST /feature-flags/evaluate'] = (_) => (
    200,
    {
      'evaluations': [
        {'key': 'task_v2_conversations_v0', 'enabled': flag},
      ],
    },
  );
  a.routes['GET /tasks/channel/c1'] = (_) => (200, {'tasks': tasks});
  a.routes['GET /channels/c1/threads/m'] = (_) => (
    404,
    {'code': 'THREAD_NOT_FOUND', 'error': 'No thread found for this message'},
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
  w.channel = RaftChannel({
    'id': 'c1',
    'name': 'test',
    'type': 'channel',
    'joined': true,
  });
  w.channels = [w.channel!];
  return (w, a);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<List<Map<String, dynamic>>> _chat(
  WidgetTester t,
  WorkspaceController w, {
  Size size = const Size(1280, 900),
  String content = 'Plan the release',
}) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(t.view.reset);
  w.messageDomain.ledger.switchServer('s1');
  w.messageDomain.ledger.ingest([
    {
      'id': 'm',
      'channelId': 'c1',
      'seq': '1',
      'messageType': 'chat',
      'content': content,
      'senderName': 'Alice',
    },
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['c1'] = {'m'};
  final opened = <Map<String, dynamic>>[];
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftChatView(
          controller: w,
          onTask: (task, _) => opened.add(task),
        ),
      ),
    ),
  );
  await _settle(t);
  return opened;
}

void main() {
  for (final (platform, size) in [
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
    (TargetPlatform.linux, const Size(390, 844)),
  ]) {
    final touch = platform == TargetPlatform.android;
    final kind = touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse;
    final variant = TargetPlatformVariant({platform});

    testWidgets('task navigation stays on the chip at $size', (t) async {
      final (w, _) = (await t.runAsync(
        () => _fixture(
          flag: true,
          tasks: [_task('t1', 11, 'todo'), _task('t2', 12, 'backlog')],
        ),
      ))!;
      addTearDown(w.dispose);
      final opened = await _chat(t, w, size: size);
      final body = find.text('Plan the release', findRichText: true);
      final firstChip = find.byKey(const ValueKey('message-task-chip-t1'));
      final secondChip = find.byKey(const ValueKey('message-task-chip-t2'));
      expect(body, findsOneWidget);
      expect(firstChip, findsOneWidget);
      expect(secondChip, findsOneWidget);
      try {
        final prose = t.getRect(body);
        final chip = t.getRect(firstChip);
        final down = Offset(prose.left + 10, chip.top + 1);
        final up = Offset(down.dx, prose.bottom - 1);
        expect(chip.contains(down), isTrue);
        expect(prose.contains(up), isTrue);
        expect((down - up).distance, lessThan(kTouchSlop));
        final gesture = await t.startGesture(down, kind: kind);
        await gesture.moveTo(up);
        await gesture.up();
        await t.pump(const Duration(milliseconds: 300));
        expect(
          opened.map((task) => task['id']),
          isEmpty,
          reason: 'A press on the chip released over prose must cancel.',
        );
        expect(w.threadIdentity, isNull);

        await t.tap(secondChip, kind: kind);
        await t.pump(const Duration(milliseconds: 300));
        expect(opened.map((task) => task['id']), ['t2']);
        expect(w.threadIdentity, isNull);

        final first = t.getRect(firstChip);
        await t.tapAt(Offset(first.center.dx, first.bottom - 1), kind: kind);
        await t.pump(const Duration(milliseconds: 300));
        expect(opened.map((task) => task['id']), ['t2', 't1']);
      } finally {
        await t.pumpWidget(const SizedBox());
      }
    }, variant: variant);

    testWidgets('the message body keeps its own gestures at $size', (t) async {
      final (w, _) = (await t.runAsync(
        () => _fixture(
          flag: true,
          tasks: [_task('t1', 11, 'todo'), _task('t2', 12, 'backlog')],
        ),
      ))!;
      addTearDown(w.dispose);
      final opened = await _chat(
        t,
        w,
        size: size,
        content: 'Plan the release #11\n\n[Notes](obsidian://open?vault=work)',
      );
      try {
        final taskRef = find.byWidgetPredicate(
          (widget) =>
              widget is RaftReferenceChip &&
              widget.appearance.kind == RaftReferenceKind.task,
        );
        final paragraph = find
            .ancestor(of: taskRef, matching: find.byType(RichText))
            .first;
        final prose = t.getRect(paragraph);
        final plain = Offset(prose.left + 10, prose.center.dy);
        expect(t.getRect(taskRef).contains(plain), isFalse);
        await t.tapAt(plain, kind: kind);
        await t.pump(const Duration(milliseconds: 300));
        expect(
          opened,
          isEmpty,
          reason: 'A stationary tap on prose opens no task.',
        );
        expect(w.threadIdentity?.parentMessageId, touch ? 'm' : null);
        expect(w.threadIdentity?.taskId, isNull);
        if (touch) {
          w.closeThread();
          await _settle(t);
        }

        await t.tap(taskRef, kind: kind);
        await t.pump(const Duration(milliseconds: 300));
        expect(opened.map((task) => task['id']), ['t1']);
        expect(w.threadIdentity, isNull);
        await t.tap(find.text('Notes', findRichText: true), kind: kind);
        await t.pumpAndSettle();
        expect(find.text('Open external link?'), findsOneWidget);
        expect(opened.map((task) => task['id']), ['t1']);
        expect(w.threadIdentity, isNull);
        await t.tap(find.text('Cancel'), kind: kind);
        await t.pumpAndSettle();

        final row = t.getRect(find.byKey(const ValueKey('message-m')));
        final gutter = Offset(row.left + 2, row.center.dy);
        if (touch) {
          await t.longPressAt(gutter);
        } else {
          await t.tapAt(gutter, kind: kind, buttons: kSecondaryMouseButton);
        }
        await t.pumpAndSettle();
        expect(find.text('Select message'), findsOneWidget);
        expect(opened.map((task) => task['id']), ['t1']);
        expect(w.threadIdentity, isNull);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();

        final currentProse = t.getRect(paragraph);
        final start = Offset(currentProse.left + 1, currentProse.center.dy);
        if (touch) {
          await t.longPressAt(start);
          await t.pumpAndSettle();
          expect(find.byType(RaftTextSelectionToolbar), findsOneWidget);
        } else {
          final clipboard = <String>[];
          final messenger = t.binding.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform, (
            call,
          ) async {
            if (call.method == 'Clipboard.setData') {
              clipboard.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
          addTearDown(
            () => messenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            ),
          );
          final selection = await t.startGesture(start, kind: kind);
          await t.pump();
          final end = Offset(t.getRect(taskRef).left - 3, start.dy);
          await selection.moveTo(
            end,
            timeStamp: const Duration(milliseconds: 100),
          );
          await t.pump();
          await selection.moveBy(const Offset(1, 0));
          await t.pump();
          await selection.up();
          await t.pump();
          await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await t.sendKeyEvent(LogicalKeyboardKey.keyC);
          await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await t.pump();
          expect(clipboard.single, startsWith('Plan the'));
          expect(w.threadIdentity, isNull);
        }
        expect(opened.map((task) => task['id']), ['t1']);
      } finally {
        await t.pumpWidget(const SizedBox());
      }
    }, variant: variant);
  }

  testWidgets('task v2: every task created from a message hangs under it, '
      'Backlog included', (t) async {
    final (w, _) = (await t.runAsync(
      () => _fixture(
        flag: true,
        tasks: [_task('t2', 12, 'backlog'), _task('t1', 11, 'todo')],
      ),
    ))!;
    addTearDown(w.dispose);
    final opened = await _chat(t, w);
    final list = find.byType(RaftTaskChipList);
    expect(list, findsOneWidget);
    expect(find.byType(RaftMountedMessageTaskChip), findsNothing);
    // By task number, each with its own conversation's size.
    final rows = t.widget<RaftTaskChipList>(list).tasks;
    expect([for (final r in rows) r.number], [11, 12]);
    expect([for (final r in rows) r.status], ['todo', 'backlog']);
    expect([for (final r in rows) r.replyCount], [3, 3]);
    expect(find.text('Task 11'), findsOneWidget);
    expect(find.text('Backlog'), findsOneWidget);
    await t.tap(find.text('Task 12'));
    await t.pump();
    expect(opened.single['id'], 't2');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a Backlog task\'s footer chip says Backlog, not Todo', (
    t,
  ) async {
    final (w, _) = (await t.runAsync(
      () =>
          _fixture(flag: false, tasks: [_task('t1', 11, 'backlog', v2: false)]),
    ))!;
    addTearDown(w.dispose);
    await _chat(t, w);
    expect(
      t
          .widget<RaftMountedMessageTaskChip>(
            find.byType(RaftMountedMessageTaskChip),
          )
          .status,
      RaftMessageTaskStatus.backlog,
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('flag off: a pre-v2 task keeps its single chip; one made the '
      'v2 way still lists under its source', (t) async {
    final (w, _) = (await t.runAsync(
      () => _fixture(flag: false, tasks: [_task('t1', 11, 'todo', v2: false)]),
    ))!;
    addTearDown(w.dispose);
    await _chat(t, w);
    expect(find.byType(RaftTaskChipList), findsNothing);
    expect(find.byType(RaftMountedMessageTaskChip), findsOneWidget);
    await t.pumpWidget(const SizedBox());

    final (w2, _) = (await t.runAsync(
      () => _fixture(flag: false, tasks: [_task('t3', 13, 'in_progress')]),
    ))!;
    addTearDown(w2.dispose);
    await _chat(t, w2);
    expect(find.byType(RaftTaskChipList), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('task v2 New task is a message: first line title, the rest '
      'description, the chosen status and a reusable source key', (t) async {
    final (w, a) = (await t.runAsync(() => _fixture(flag: true, tasks: [])))!;
    addTearDown(w.dispose);
    var fail = true;
    a.routes['POST /tasks/channel/c1'] = (o) {
      if (fail) {
        fail = false;
        return (500, {'error': 'Temporary failure'});
      }
      return (200, {'tasks': <dynamic>[]});
    };
    await _chat(t, w);
    final context = t.element(find.byType(RaftChatView));
    unawaited(CreateTaskDialog.show(context, controller: w, channelId: 'c1'));
    await _settle(t);
    expect(
      find.byKey(const ValueKey('create-task-message-dialog')),
      findsOneWidget,
    );
    expect(find.text('In #test'), findsOneWidget);
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('create-task-message')),
        matching: find.byType(EditableText),
      ),
      'Ship it\nwith release notes',
    );
    await t.tap(find.byKey(const ValueKey('create-task-status')));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('create-task-status-backlog')).last);
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('create-task-submit')));
    await _settle(t);
    // A failed send stays, with the reason; the retry reuses the key so the
    // message the server may have posted is not posted twice.
    expect(
      find.byKey(const ValueKey('create-task-message-dialog')),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('create-task-submit')));
    await _settle(t);
    final posts = [
      for (final c in a.calls)
        if (c.method == 'POST' && c.path == '/tasks/channel/c1') c.data as Map,
    ];
    expect(posts, hasLength(2));
    expect(posts.first['tasks'], [
      {'title': 'Ship it', 'description': 'with release notes'},
    ]);
    expect(posts.first['status'], 'backlog');
    expect(posts.first['sourceRandomId'], isA<String>());
    expect(posts.last['sourceRandomId'], posts.first['sourceRandomId']);
    expect(
      find.byKey(const ValueKey('create-task-message-dialog')),
      findsNothing,
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('create from message: the status applies to every title', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(() => _fixture(flag: true, tasks: [])))!;
    addTearDown(w.dispose);
    a.routes['POST /tasks/channel/c1'] = (_) => (200, {'tasks': <dynamic>[]});
    await _chat(t, w);
    final context = t.element(find.byType(RaftChatView));
    unawaited(
      CreateTaskDialog.show(
        context,
        controller: w,
        channelId: 'c1',
        sourceMessage: (id: 'm', senderName: 'Alice', text: 'Plan it'),
      ),
    );
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('create-task-add-row')));
    await t.pump();
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('create-task-title-1')),
        matching: find.byType(EditableText),
      ),
      'Write notes',
    );
    await t.pump();
    expect(find.text('Status applies to all 2 tasks.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('create-task-status')));
    await _settle(t);
    await t.tap(
      find.byKey(const ValueKey('create-task-status-in_progress')).last,
    );
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('create-task-submit')));
    await _settle(t);
    final post = a.calls.lastWhere((c) => c.path == '/tasks/channel/c1');
    expect(post.data, {
      'tasks': [
        {'title': 'Plan it', 'sourceMessageId': 'm'},
        {'title': 'Write notes', 'sourceMessageId': 'm'},
      ],
      'status': 'in_progress',
    });
    await t.pumpWidget(const SizedBox());
  });
}
