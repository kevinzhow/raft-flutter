// Task v2 (`task_v2_conversations_v0`, Web v1.24 TaskConversationDialog):
// a task made the v2 way opens on its own conversation (channels.type =
// 'task'), keyed by the task, never its host message's thread. The first
// send creates it (POST /tasks/:id/conversation); the head edits the title
// over PATCH /tasks/:id with the "someone else changed this" stale warning;
// moving into Backlog and handing it to someone else ask for a reason;
// Delete task asks first; a deleted task closes the dialog.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, FutureOr<(int, Object?)> Function(RequestOptions)>{};
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
        : await route(o);
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

/// A client whose socket events the test plays.
class _Client extends RaftClient {
  _Client(Dio transport)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: transport,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void play(String name, Object payload) =>
      stream.add(RaftEvent(name, payload));
}

/// A task made the v2 way, no conversation yet (created lazily).
Map<String, dynamic> v2Task() => {
  'id': 'task-7',
  'taskNumber': 7,
  'title': 'Ship task v2',
  'channelId': 'c1',
  'channelName': 'test',
  'channelType': 'channel',
  'messageId': 'task-7',
  'hostMessageId': null,
  'sourceMessageId': 'src',
  'sourceRecorded': true,
  'conversationAnchored': true,
  'conversationChannelId': null,
  'conversationReplyCount': 0,
  'status': 'todo',
  'revision': 2,
  'createdByType': 'user',
  'createdById': 'alice',
  'createdByName': 'alice',
  'createdAt': '2026-11-14T10:00:00.000Z',
};

Future<(WorkspaceController, _Adapter, Map<String, dynamic>)> _fixture() async {
  final a = _Adapter();
  final task = v2Task();
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
        {'key': 'task_v2_conversations_v0', 'enabled': true},
      ],
    },
  );
  a.routes['GET /servers/s1/members'] = (_) => (200, <dynamic>[]);
  a.routes['GET /agents'] = (_) => (200, <dynamic>[]);
  a.routes['GET /tasks/server'] = (r) => (
    200,
    {
      'tasks':
          r.queryParameters['status'] == null ||
              r.queryParameters['status'] == task['status']
          ? [task]
          : [],
      'next_cursor': null,
    },
  );
  a.routes['GET /tasks/channel/c1/number/7'] = (_) => (200, {'task': task});
  a.routes['GET /tasks/task-7/history'] = (_) => (200, {'events': <dynamic>[]});
  a.routes['GET /messages/context/src'] = (_) => (
    200,
    {
      'messages': [
        {
          'id': 'src',
          'channelId': 'c1',
          'seq': '1',
          'senderId': 'bob',
          'senderType': 'user',
          'senderName': 'Bob',
          'content': 'Please ship it\nwith notes',
          'createdAt': '2026-11-14T09:00:00.000Z',
        },
      ],
    },
  );
  final client = _Client(Dio()..httpClientAdapter = a);
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
  return (w, a, task);
}

Future<void> _flush(WidgetTester t, [int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<TaskSurfaceControllerProbe> _open(
  WidgetTester t,
  WorkspaceController w,
) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1280, 900);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: ResourceView(
          controller: w,
          section: 'tasks',
          onMessage: (_, _) async => fail('No main redirect'),
        ),
      ),
    ),
  );
  await _flush(t);
  await t.tap(find.text('Ship task v2'));
  await _flush(t, 8);
  return TaskSurfaceControllerProbe(t);
}

/// Closes the task dialog, as the reader does (its owner is disposed).
Future<void> _close(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('task-modal-close')));
  await _flush(t);
  expect(find.byType(SourceTaskSurface), findsNothing);
}

/// Reads the mounted task owner.
class TaskSurfaceControllerProbe {
  TaskSurfaceControllerProbe(this.t);
  final WidgetTester t;
  bool get mounted => find.byType(SourceTaskSurface).evaluate().isNotEmpty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a task v2 task opens on its own conversation; the first send '
      'creates it', (t) async {
    final (w, a, _) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    a.routes['POST /tasks/task-7/conversation'] = (_) =>
        (200, {'conversationChannelId': 'conv-7', 'created': true});
    a.routes['POST /v2/messages'] = (o) => (
      200,
      {
        'id': 'reply-1',
        'channelId': (o.data as Map)['channelId'],
        'seq': '1',
        'senderId': 'alice',
        'content': (o.data as Map)['content'],
      },
    );
    a.routes['GET /messages/channel/conv-7'] = (_) =>
        (200, {'messages': <dynamic>[]});
    a.routes['POST /channels/conv-7/read'] = (_) => (200, {});
    await _open(t, w);
    // The bar names the task by its ref; the head shows the dialog's facts.
    expect(find.byKey(const ValueKey('task-modal-bar-ref')), findsOneWidget);
    expect(find.text('#test:#7'), findsOneWidget);
    expect(find.text('Task #7'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Please ship it'), findsOneWidget);
    expect(find.text('Created at'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task-conversation-empty')),
      findsOneWidget,
    );
    expect(find.text('No discussion in this task yet'), findsOneWidget);
    // Never the pre-v2 paths: no host-thread lookup, no parent read.
    expect(
      a.calls.where(
        (c) =>
            c.path.contains('/threads/') ||
            c.path == '/messages/context/task-7' ||
            c.path == '/tasks/task-7/conversation',
      ),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('task-modal-view-in-thread')),
      findsNothing,
    );
    final composer = t.widget<RaftComposer>(find.byType(RaftComposer));
    await t.runAsync(() async => composer.onSend('First reply'));
    await _flush(t);
    expect(
      a.calls.where((c) => c.path == '/tasks/task-7/conversation'),
      hasLength(1),
    );
    final send = a.calls.lastWhere((c) => c.path == '/v2/messages');
    expect((send.data as Map)['channelId'], 'conv-7');
    expect((send.data as Map)['content'], 'First reply');
    await _close(t);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('editing the title saves it with the revision; someone '
      "else's edit keeps the draft and says so", (t) async {
    final (w, a, task) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    final patches = <Map>[];
    var conflict = true;
    a.routes['PATCH /tasks/task-7'] = (o) {
      patches.add(o.data as Map);
      if (conflict) {
        conflict = false;
        return (
          409,
          {
            'error':
                'task changed concurrently; read the current card and retry',
            'currentRevision': 5,
          },
        );
      }
      return (
        200,
        {
          'task': {...task, 'title': 'Ship task v2 now', 'revision': 6},
        },
      );
    };
    await _open(t, w);
    await t.tap(find.byKey(const ValueKey('task-modal-title-edit')));
    await t.pump();
    final input = find.descendant(
      of: find.byKey(const ValueKey('task-head-title-input')),
      matching: find.byType(EditableText),
    );
    await t.enterText(input, 'Ship task v2 now');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _flush(t);
    expect(patches.single, {
      'title': 'Ship task v2 now',
      'expectedRevision': 2,
    });
    // The lost race: the draft stays, with the warning under it.
    expect(find.byKey(const ValueKey('task-head-edit-notice')), findsOneWidget);
    expect(
      t
          .widget<RaftBanner>(
            find.byKey(const ValueKey('task-head-edit-notice')),
          )
          .description,
      startsWith('Someone else changed this while you were editing.'),
    );
    expect(t.widget<EditableText>(input).controller.text, 'Ship task v2 now');
    // Saving again replaces their version, against the revision they made.
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _flush(t);
    expect(patches.last, {'title': 'Ship task v2 now', 'expectedRevision': 5});
    expect(find.byKey(const ValueKey('task-head-title-input')), findsNothing);
    expect(find.text('Ship task v2 now'), findsWidgets);
    await _close(t);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('moving into Backlog and handing it over ask for the reason', (
    t,
  ) async {
    final (w, a, task) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    a.routes['GET /channels/c1/members'] = (_) => (
      200,
      {
        'humans': [
          {'id': 'carol', 'displayName': 'Carol'},
        ],
        'agents': <dynamic>[],
      },
    );
    a.routes['PATCH /tasks/task-7/status'] = (o) => (
      200,
      {
        'task': {...task, 'status': (o.data as Map)['status']},
      },
    );
    a.routes['PATCH /tasks/task-7/assignee'] = (o) => (
      200,
      {
        'task': {...task, 'claimedById': 'carol', 'claimedByType': 'user'},
      },
    );
    await _open(t, w);
    await t.tap(find.byKey(const ValueKey('task-properties-status')));
    await _flush(t);
    // Task v2: in_review is retired; Backlog is offered.
    final menu = find.byType(RaftInlineBadgeMenu);
    expect(
      find.descendant(
        of: menu,
        matching: find.byKey(const ValueKey('in_review')),
      ),
      findsNothing,
    );
    await t.tap(
      find.descendant(
        of: menu,
        matching: find.byKey(const ValueKey('backlog')),
      ),
    );
    await _flush(t);
    expect(find.byKey(const ValueKey('task-backlog-reason')), findsOneWidget);
    // A popover under the status chip, not a dialog over the task.
    expect(find.text('Move to Backlog'), findsWidgets);
    expect(
      t.getTopLeft(find.byKey(const ValueKey('task-backlog-reason'))).dy,
      greaterThanOrEqualTo(
        t
            .getBottomLeft(find.byKey(const ValueKey('task-properties-status')))
            .dy,
      ),
    );
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('task-backlog-reason-input')),
        matching: find.byType(EditableText),
      ),
      ' waiting on design ',
    );
    await t.tap(find.byKey(const ValueKey('task-backlog-reason-confirm')));
    await _flush(t);
    final status = a.calls.lastWhere((c) => c.path == '/tasks/task-7/status');
    expect(status.data, {'status': 'backlog', 'reason': 'waiting on design'});
    expect(find.byKey(const ValueKey('task-backlog-reason')), findsNothing);

    await t.tap(find.byKey(const ValueKey('task-properties-assignee')));
    await _flush(t);
    await t.tap(find.text('Carol'));
    await _flush(t);
    // The step shows inside the picker, in place of its list.
    expect(
      find.byKey(const ValueKey('task-handoff-reason-panel')),
      findsOneWidget,
    );
    expect(find.byType(RaftSelectionPopover), findsNothing);
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('task-handoff-reason-input')),
        matching: find.byType(EditableText),
      ),
      'Review the copy',
    );
    await t.tap(find.byKey(const ValueKey('task-handoff-reason-confirm')));
    await _flush(t);
    final assign = a.calls.lastWhere((c) => c.path == '/tasks/task-7/assignee');
    expect(assign.data, {
      'assignee': {'type': 'user', 'id': 'carol'},
      'expectedRevision': 2,
      'reason': 'Review the copy',
    });
    await _close(t);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Delete task asks first and closes the dialog; a task deleted '
      'elsewhere closes it too', (t) async {
    final (w, a, _) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    a.routes['DELETE /tasks/task-7'] = (_) => (200, {'ok': true});
    final probe = await _open(t, w);
    await t.tap(find.byKey(const ValueKey('task-overflow-trigger')));
    await _flush(t);
    await t.tap(find.text('Delete task'));
    await _flush(t);
    expect(find.byKey(const ValueKey('task-delete-confirm')), findsOneWidget);
    expect(find.text('Delete task #7?'), findsOneWidget);
    expect(a.calls.where((c) => c.method == 'DELETE'), isEmpty);
    await t.tap(find.byKey(const ValueKey('task-delete-confirm-action')));
    await _flush(t, 8);
    expect(a.calls.where((c) => c.method == 'DELETE'), hasLength(1));
    expect(find.byKey(const ValueKey('task-delete-confirm')), findsNothing);
    expect(probe.mounted, isFalse);

    // Deleted by someone else while it is open: its conversation is gone,
    // the dialog closes (threadStore.dropDeletedTaskConversation).
    await t.tap(find.text('Ship task v2'));
    await _flush(t, 8);
    expect(probe.mounted, isTrue);
    (w.client as _Client).play('task:deleted', {
      'taskId': 'task-7',
      'channelId': 'c1',
      'serverId': 's1',
    });
    await _flush(t);
    expect(probe.mounted, isFalse);
    await t.pumpWidget(const SizedBox());
  });
}
