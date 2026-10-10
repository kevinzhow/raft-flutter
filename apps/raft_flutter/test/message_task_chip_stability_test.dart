import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_task_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;

/// Product rule: once a message row is on screen its layout is final. Task
/// chips come from the client-level task cache (first frame on revisit),
/// patch in place on task events and only clear on an identity change.
class _Client extends RaftClient {
  _Client(Dio dio)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: dio,
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  void emit(String name, Object? payload) =>
      ingress.add(RaftEvent(name, payload));
}

Map<String, dynamic> _message(String id, String channel, int seq) => {
  'id': id,
  'channelId': channel,
  'seq': seq,
  'senderId': 'agent',
  'senderType': 'agent',
  'senderName': 'Cindy',
  'content': 'Body $id',
  'createdAt': '2026-06-22T02:3$seq:00Z',
};

Map<String, dynamic> _task(String messageId, int number, String status) => {
  'id': messageId,
  'messageId': messageId,
  'channelId': 'c1',
  'taskNumber': number,
  'title': 'Task $number',
  'status': status,
  'claimedByName': 'Cindy',
};

Future<(WorkspaceController, _Client, MessageAdapter, List<String>)> _fixture(
  WidgetTester t,
) async {
  final api = MessageAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = (await t.runAsync(() async {
    final client = _Client(Dio()..httpClientAdapter = api);
    await client.login('fixture', 'fixture');
    return client;
  }))!;
  client.selectServer('s1');
  final w = WorkspaceController(client);
  final c1 = RaftChannel({'id': 'c1', 'name': 'one', 'joined': true});
  final c2 = RaftChannel({'id': 'c2', 'name': 'two', 'joined': true});
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channels = [c1, c2];
  w.channel = c1;
  w.ledger.switchServer('s1');
  final one = [
    _message('m1', 'c1', 1),
    _message('m2', 'c1', 2),
    _message('m3', 'c1', 3),
  ];
  final two = [_message('n1', 'c2', 1)];
  w.ledger.ingest([...one, ...two], expectedGeneration: w.ledger.generation);
  w.visibleIds['c1'] = {'m1', 'm2', 'm3'};
  w.visibleIds['c2'] = {'n1'};
  final reads = <String>[];
  api.routes['GET /messages/channel/c1'] = (_) => {'messages': one};
  api.routes['GET /messages/channel/c2'] = (_) => {'messages': two};
  api.routes['GET /tasks/channel/c1'] = (_) {
    reads.add('c1');
    return {
      'tasks': [_task('m1', 10, 'in_progress'), _task('m3', 12, 'todo')],
    };
  };
  api.routes['GET /tasks/channel/c2'] = (_) {
    reads.add('c2');
    return {'tasks': []};
  };
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  return (w, client, api, reads);
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
  await _settle(t);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }
  await t.pumpAndSettle();
}

final _row = {
  for (final id in ['m1', 'm2', 'm3']) id: find.byKey(ValueKey('message-$id')),
};
Finder _chip(String id) => find.byKey(ValueKey('message-task-$id'));

/// The rows' rects relative to the first row, plus each chip's presence.
Map<String, Object?> _layout(WidgetTester t) => {
  for (final MapEntry(key: id, value: row) in _row.entries)
    if (row.evaluate().isNotEmpty) ...{
      '$id.size': t.getSize(row),
      '$id.chip': _chip(id).evaluate().isEmpty
          ? null
          : t.getRect(_chip(id)).size,
    },
};

void main() {
  testWidgets(
    'switching away and back shows the cached chips at the first frame with stable rows',
    (t) async {
      final (w, client, api, reads) = await _fixture(t);
      addTearDown(w.dispose);
      await _mount(t, w);
      expect(_chip('m1'), findsOneWidget);
      expect(_chip('m3'), findsOneWidget);
      expect(_chip('m2'), findsNothing);
      final settled = _layout(t);
      expect(reads, ['c1']);
      // Any later read of c1 stays pending: a clear-and-refetch would show
      // rows without their chips.
      final gate = Completer<dynamic>();
      api.routes['GET /tasks/channel/c1'] = (_) {
        reads.add('c1');
        return gate.future;
      };

      unawaited(w.selectChannel(w.channels[1]));
      await _settle(t);
      expect(find.byKey(const ValueKey('message-n1')), findsOneWidget);
      expect(reads, ['c1', 'c2']);

      // Return: every frame from the first shows both chips at their size.
      unawaited(w.selectChannel(w.channels[0]));
      final frames = <Map<String, Object?>>[];
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 16));
        if (_row['m1']!.evaluate().isNotEmpty) frames.add(_layout(t));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      await _settle(t);
      frames.add(_layout(t));
      // The cached window is shown from the first frame after the switch.
      expect(frames, hasLength(13));
      expect(frames.first, settled, reason: 'first frame after return');
      for (final frame in frames) {
        expect(frame, settled);
      }
      // A fresh cached bucket is not cleared or refetched on revisit.
      expect(reads, ['c1', 'c2']);
      // A reconnect revalidates in the background without clearing.
      client.emit('connected', null);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(_layout(t), settled, reason: 'reconnect frame $i');
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(reads.where((r) => r == 'c1'), hasLength(2));
      gate.complete({
        'tasks': [_task('m1', 10, 'in_progress'), _task('m3', 12, 'todo')],
      });
      await _settle(t);
      expect(_layout(t), settled);
      await t.pumpWidget(const SizedBox());
      await _settle(t);
    },
  );

  testWidgets('task:updated changes only that chip in place', (t) async {
    final (w, client, _, reads) = await _fixture(t);
    addTearDown(w.dispose);
    await _mount(t, w);
    final before = _layout(t);
    final other = t.widget<RaftMountedMessageTaskChip>(_chip('m3'));
    expect(
      t.widget<RaftMountedMessageTaskChip>(_chip('m1')).status,
      RaftMessageTaskStatus.inProgress,
    );
    client.emit('task:updated', {
      'task': {'id': 'm1', 'channelId': 'c1', 'status': 'done'},
    });
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 16));
      expect(_chip('m1'), findsOneWidget, reason: 'frame $i');
      expect(_layout(t), before, reason: 'frame $i');
    }
    final chip = t.widget<RaftMountedMessageTaskChip>(_chip('m1'));
    expect(chip.status, RaftMessageTaskStatus.done);
    expect(chip.number, 10);
    expect(chip.claimant, 'Cindy');
    // The other task's chip is untouched; no task bucket is re-read.
    expect(
      t.widget<RaftMountedMessageTaskChip>(_chip('m3')).status,
      other.status,
    );
    expect(reads, ['c1']);
    // Footer chips carry no tooltip that repeats their visible text.
    expect(chip.tooltipLabel, isNull);
    expect(find.byType(Tooltip), findsNothing);

    // task:deleted removes just that chip; a foreign server's event is ignored.
    client.emit('task:deleted', {'taskId': 'm3', 'serverId': 'other'});
    await t.pump();
    expect(_chip('m3'), findsOneWidget);
    client.emit('task:deleted', {'taskId': 'm3'});
    await t.pump();
    expect(_chip('m3'), findsNothing);
    expect(_chip('m1'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a server role or principal change clears the cached chips', (
    t,
  ) async {
    final (w, _, api, reads) = await _fixture(t);
    addTearDown(w.dispose);
    final gate = Completer<dynamic>();
    await _mount(t, w);
    expect(_chip('m1'), findsOneWidget);
    final cache = MessageTaskCache.of(w.client);
    expect(cache.tasks(w, 'c1'), isNotNull);

    // Role change: the old role's facts are not shown while the new role's
    // bucket is read.
    api.routes['GET /tasks/channel/c1'] = (_) {
      reads.add('c1');
      return gate.future;
    };
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.notifyListeners();
    await t.pump();
    expect(_chip('m1'), findsNothing);
    expect(cache.tasks(w, 'c1'), isNull);
    for (var i = 0; i < 3; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 20));
      expect(_chip('m1'), findsNothing);
    }
    expect(reads, ['c1', 'c1']);
    gate.complete({
      'tasks': [_task('m1', 10, 'in_review')],
    });
    await _settle(t);
    expect(
      t.widget<RaftMountedMessageTaskChip>(_chip('m1')).status,
      RaftMessageTaskStatus.inReview,
    );

    // Principal change: every bucket of the old principal is dropped.
    w.client.user = RaftRecord({'id': 'someone-else'});
    w.notifyListeners();
    await t.pump();
    expect(_chip('m1'), findsNothing);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    final principal = w.client.user;
    w.client.user = RaftRecord({'id': 'alice'});
    expect(cache.tasks(w, 'c1'), isNull);
    w.client.user = principal;
    await t.pumpWidget(const SizedBox());
    await _settle(t);
  });

  testWidgets(
    'a message carrying task fields shows its chip, or reserves its space, from the first frame',
    (t) async {
      final (w, _, api, _) = await _fixture(t);
      addTearDown(w.dispose);
      final gate = Completer<dynamic>();
      api.routes['GET /tasks/channel/c1'] = (_) => gate.future;
      w.ledger.ingest([
        {..._message('m1', 'c1', 1), 'taskNumber': 10, 'taskStatus': 'todo'},
        {..._message('m3', 'c1', 3), 'taskNumber': 12},
      ], expectedGeneration: w.ledger.generation);
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
      await t.pump();
      // m1 is presented from its own fields; m3's status is pending, so its
      // footer line is reserved rather than inserted later.
      expect(
        t.widget<RaftMountedMessageTaskChip>(_chip('m1')).status,
        RaftMessageTaskStatus.todo,
      );
      expect(
        find.byKey(const ValueKey('message-task-reserved-m3')),
        findsOneWidget,
      );
      final sizes = {
        for (final id in ['m1', 'm3']) id: t.getSize(_row[id]!),
      };
      gate.complete({
        'tasks': [_task('m1', 10, 'in_progress'), _task('m3', 12, 'todo')],
      });
      await _settle(t);
      expect(
        t.widget<RaftMountedMessageTaskChip>(_chip('m1')).status,
        RaftMessageTaskStatus.inProgress,
      );
      expect(_chip('m3'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('message-task-reserved-m3')),
        findsNothing,
      );
      for (final id in ['m1', 'm3']) {
        expect(t.getSize(_row[id]!), sizes[id], reason: id);
      }
      await t.pumpWidget(const SizedBox());
    },
  );
}
