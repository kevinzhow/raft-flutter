import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/resource_snapshot_cache.dart';
import 'package:raft_flutter/data/server_task_window.dart';
import 'package:raft_flutter/data/task_board_reconcile.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;

Map<String, dynamic> taskRow(int n, String status, {String channel = 'c1'}) =>
    {
      'id': 't$n',
      'taskNumber': n,
      'title': 'Task $n',
      'channelId': channel,
      'channelName': channel == 'c1' ? 'General' : 'Secret',
      'channelType': 'channel',
      'status': status,
      'createdByType': 'user',
      'createdById': 'alice',
      'createdByName': 'Alice',
    };

class _TaskWorkspace extends WorkspaceController {
  _TaskWorkspace(super.client);
  final taskQueries = <Map<String, dynamic>>[];
  Completer<void>? hold;
  List<Map<String, dynamic>> tasks = [
    for (var n = 80; n > 0; n--) taskRow(n, 'todo', channel: n == 79 ? 'c2' : 'c1'),
    for (var n = 90; n > 85; n--) taskRow(n, 'in_progress'),
  ];
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path != '/tasks/server') return [];
    taskQueries.add({...?query});
    final gate = hold;
    if (gate != null) await gate.future;
    final status = query?['status'];
    final matching = tasks
        .where((t) => status == null || t['status'] == status)
        .toList();
    final offset = int.tryParse('${query?['cursor'] ?? 0}') ?? 0,
        limit = query?['limit'] as int? ?? 30;
    final page = matching.skip(offset).take(limit).toList();
    final end = offset + page.length;
    return {
      'tasks': [for (final row in page) Map<String, dynamic>.of(row)],
      'next_cursor': end < matching.length ? '$end' : null,
    };
  }
}

void main() {
  late ActivityClient client;
  late _TaskWorkspace w;
  setUp(() {
    client = ActivityClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    w = _TaskWorkspace(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
        RaftChannel({
          'id': 'c2',
          'name': 'Secret',
          'joined': true,
          'isPrivate': true,
        }),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Widget page() => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: RaftDensityScope(
      density: RaftDensity.desktop,
      child: Scaffold(
        body: ResourceView(
          controller: w,
          section: 'tasks',
          onMessage: (_, _) async {},
        ),
      ),
    ),
  );
  Widget away() => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: const Scaffold(body: SizedBox.expand()),
  );
  List lane(dynamic state, String status) => state.lanes[status] as List;
  final spinner = find.byType(CircularProgressIndicator);
  ServerTaskWindow? window() {
    final slot = w.resourceSnapshots.serverPage(serverTasksPage);
    return slot is ServerTaskWindow ? slot : null;
  }

  Future<dynamic> mountBoard(WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(ResourceView));
    expect(state.taskLayout, 'board');
    // The offscreen load-more control is mounted only when the lane reaches it.
    expect(state.laneCursors['todo'], '30');
    await state.moreLane('todo');
    await tester.pumpAndSettle();
    expect(lane(state, 'todo'), hasLength(60));
    return state;
  }

  testWidgets(
    'returning to Tasks shows the cached lanes and loaded pages on the first frame',
    (tester) async {
      dynamic state = await mountBoard(tester);
      final cached = lane(state, 'todo')[45];
      await tester.pumpWidget(away());
      await tester.pumpAndSettle();
      // The workspace page leaves its board on the session, not in the tasks slot.
      expect(w.resourceSnapshots.read('tasks', state.identityAuthority), isNull);
      expect(window(), isNotNull);
      final requests = w.taskQueries.length;
      w.hold = Completer<void>();
      await tester.pumpWidget(page());
      state = tester.state(find.byType(ResourceView));
      // First frame: cached board, both loaded Todo pages, no loading state.
      expect(spinner, findsNothing);
      expect(state.taskLayout, 'board');
      expect(lane(state, 'todo'), hasLength(60));
      expect(find.text('Task 80'), findsOneWidget);
      // Background revalidation spans each lane's loaded window.
      final revalidation = w.taskQueries.skip(requests).toList();
      expect(revalidation, hasLength(raftTaskStatuses.length));
      expect(
        revalidation.firstWhere((q) => q['status'] == 'todo')['limit'],
        60,
      );
      w.tasks[0] = {...w.tasks[0], 'title': 'Fresh 80'};
      w.hold!.complete();
      w.hold = null;
      await tester.pumpAndSettle();
      expect(spinner, findsNothing);
      expect(lane(state, 'todo'), hasLength(60));
      expect(state.laneCursors['todo'], '60');
      expect(find.text('Fresh 80'), findsOneWidget);
      expect(identical(lane(state, 'todo')[45], cached), isTrue);
    },
  );

  testWidgets(
    'task events update, move, create and delete one card in place',
    (tester) async {
      final dynamic state = await mountBoard(tester);
      final requests = w.taskQueries.length;
      final untouched = lane(state, 'todo')[10];

      // Same lane: patched where it is.
      client.emit('task:updated', {
        'channelId': 'c1',
        'task': {...taskRow(78, 'todo'), 'title': 'Renamed 78'},
      });
      await tester.pump();
      expect(lane(state, 'todo')[2]['title'], 'Renamed 78');
      expect(find.text('Renamed 78'), findsOneWidget);

      // Status change: moves to its lane at the task-number position.
      client.emit('task:updated', {
        'channelId': 'c1',
        'task': {...taskRow(77, 'in_progress'), 'title': 'Moved 77'},
      });
      await tester.pump();
      expect(lane(state, 'todo'), hasLength(59));
      expect(lane(state, 'todo').any((t) => t['id'] == 't77'), isFalse);
      expect(
        lane(state, 'in_progress').map((t) => t['id']),
        ['t90', 't89', 't88', 't87', 't86', 't77'],
      );

      // Created and deleted tasks.
      client.emit('task:created', {
        'channelId': 'c1',
        'tasks': [taskRow(95, 'in_review')],
      });
      client.emit('task:deleted', {'channelId': 'c1', 'taskId': 't76'});
      await tester.pump();
      expect(lane(state, 'in_review').single['id'], 't95');
      expect(lane(state, 'todo'), hasLength(58));
      expect(find.text('Task 95'), findsOneWidget);
      expect(find.text('Task 76'), findsNothing);

      // A created task past the loaded window of a lane with more pages is
      // left to that page.
      client.emit('task:created', {
        'channelId': 'c1',
        'tasks': [
          {...taskRow(0, 'todo'), 'id': 'old', 'title': 'Old todo'},
        ],
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(lane(state, 'todo').any((t) => t['id'] == 'old'), isFalse);

      // No lane was reloaded or reset to its first page.
      expect(w.taskQueries, hasLength(requests));
      expect(state.laneCursors['todo'], '60');
      expect(identical(lane(state, 'todo')[8], untouched), isTrue);
      expect(spinner, findsNothing);
    },
  );

  testWidgets('a task event arriving during a revalidation is not lost', (
    tester,
  ) async {
    final dynamic state = await mountBoard(tester);
    w.hold = Completer<void>();
    unawaited(state.load(keep: true));
    await tester.pump();
    client.emit('task:updated', {
      'channelId': 'c1',
      'task': {...taskRow(80, 'done'), 'title': 'Done live'},
    });
    await tester.pump();
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(lane(state, 'todo').any((t) => t['id'] == 't80'), isFalse);
    expect(lane(state, 'done').single['title'], 'Done live');
  });

  testWidgets('a drag in progress survives a background refresh', (
    tester,
  ) async {
    final dynamic state = await mountBoard(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Task 80')),
    );
    await gesture.moveBy(const Offset(20, 20));
    await tester.pump();
    // Reconnect catch-up replaces every row object while the card is held.
    final before = lane(state, 'todo').first;
    client.emit('connected', null);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(identical(lane(state, 'todo').first, before), isTrue);
    w.tasks[0] = {...w.tasks[0], 'title': 'Edited while dragging'};
    await state.load(keep: true);
    await tester.pump();
    expect(identical(lane(state, 'todo').first, before), isFalse);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('task-drop-in_progress'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    // Task 80 has no holder: starting it is the claim.
    expect(client.posts, contains('PATCH /tasks/t80/claim'));
    expect(client.posts, isNot(contains('PATCH /tasks/t80/status')));
  });

  testWidgets(
    'a channel the user can no longer see removes only its tasks without reloading',
    (tester) async {
      final dynamic state = await mountBoard(tester);
      final requests = w.taskQueries.length;
      w.channels = [
        w.channels.first,
        RaftChannel({
          'id': 'c2',
          'name': 'Secret',
          'joined': false,
          'isPrivate': true,
        }),
      ];
      client.emit('channel:updated', {'id': 'c2'});
      await tester.pumpAndSettle();
      expect(lane(state, 'todo'), hasLength(59));
      expect(lane(state, 'todo').any((t) => t['id'] == 't79'), isFalse);
      expect(state.laneCursors['todo'], '60');
      expect(w.taskQueries, hasLength(requests));
    },
  );

  testWidgets('a role or server change never serves the cached board', (
    tester,
  ) async {
    dynamic state = await mountBoard(tester);
    await tester.pumpWidget(away());
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.hold = Completer<void>();
    await tester.pumpWidget(page());
    await tester.pump();
    state = tester.state(find.byType(ResourceView));
    expect(state.rows, isEmpty);
    expect(state.lanes, isEmpty);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(lane(state, 'todo'), hasLength(30));
    await tester.pumpWidget(away());
    expect(w.resourceSnapshots.read('tasks', state.identityAuthority), isNull);
    expect(window()?.snapshot.identity, state.identityAuthority);
    unawaited(w.selectServer(RaftRecord({'id': 's2', 'role': 'owner'})));
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    client.selectServer('s1');
    expect(w.resourceSnapshots.read('tasks', state.identityAuthority), isNull);
    expect(w.resourceSnapshots.serverPage(serverTasksPage), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('a task event while the page is away patches one card and does not fetch', (
    tester,
  ) async {
    await mountBoard(tester);
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final requests = w.taskQueries.length;
    client.emit('task:updated', {
      'channelId': 'c1',
      'task': {...taskRow(80, 'todo'), 'title': 'Patched away'},
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(w.taskQueries, hasLength(requests));
    expect(window()?.needsRevalidate, isFalse);
    w.hold = Completer<void>();
    await tester.pumpWidget(page());
    expect(find.text('Patched away'), findsOneWidget);
    expect(spinner, findsNothing);
    expect(w.taskQueries, hasLength(requests + raftTaskStatuses.length));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });

  testWidgets('reconnect and an unnamed task while away only mark the window', (
    tester,
  ) async {
    await mountBoard(tester);
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final requests = w.taskQueries.length;
    client.emit('connected', null);
    client.emit('task:updated', {'channelId': 'c1'});
    client.emit('task:updated', {
      'serverId': 'other',
      'task': {...taskRow(80, 'todo'), 'title': 'Other server'},
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(w.taskQueries, hasLength(requests));
    expect(window()?.needsRevalidate, isTrue);
    expect(find.text('Other server'), findsNothing);
    w.hold = Completer<void>();
    await tester.pumpWidget(page());
    expect(find.text('Task 80'), findsOneWidget);
    expect(find.text('Other server'), findsNothing);
    expect(window()?.needsRevalidate, isFalse);
    expect(w.taskQueries, hasLength(requests + raftTaskStatuses.length));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });

  testWidgets('a late revalidation cannot rewrite the board after the page leaves', (
    tester,
  ) async {
    await mountBoard(tester);
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    w.hold = Completer<void>();
    await tester.pumpWidget(page());
    await tester.pump();
    w.tasks[0] = {...w.tasks[0], 'title': 'Should not land'};
    await tester.pumpWidget(away());
    await tester.pump();
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(
      window()?.snapshot.rows.any((row) => row['title'] == 'Should not land'),
      isFalse,
    );
    w.hold = Completer<void>();
    await tester.pumpWidget(page());
    expect(find.text('Task 80'), findsOneWidget);
    expect(find.text('Should not land'), findsNothing);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });

  testWidgets('a channel lost while away is absent on the first frame', (
    tester,
  ) async {
    await mountBoard(tester);
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final requests = w.taskQueries.length;
    w.channels = [
      w.channels.first,
      RaftChannel({
        'id': 'c2',
        'name': 'Secret',
        'joined': false,
        'isPrivate': true,
      }),
    ];
    w.hold = Completer<void>();
    await tester.pumpWidget(page());
    final dynamic state = tester.state(find.byType(ResourceView));
    expect(lane(state, 'todo'), hasLength(59));
    expect(lane(state, 'todo').any((row) => row['id'] == 't79'), isFalse);
    expect(w.taskQueries, hasLength(requests + raftTaskStatuses.length));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(w.taskQueries, hasLength(requests + raftTaskStatuses.length));
  });

  testWidgets('logout drops the board and a later event cannot recreate it', (
    tester,
  ) async {
    await mountBoard(tester);
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final requests = w.taskQueries.length;
    w.revokeServer('s1');
    expect(w.resourceSnapshots.serverPage(serverTasksPage), isNull);
    client.emit('task:updated', {
      'task': {...taskRow(80, 'todo'), 'title': 'After logout'},
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(w.resourceSnapshots.serverPage(serverTasksPage), isNull);
    expect(w.taskQueries, hasLength(requests));
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    client.selectServer('s1');
    w.channels = [
      RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
      RaftChannel({
        'id': 'c2',
        'name': 'Secret',
        'joined': true,
        'isPrivate': true,
      }),
    ];
    w.hold = Completer<void>();
    await tester.pumpWidget(page());
    expect(find.text('Task 80'), findsNothing);
    expect(find.text('After logout'), findsNothing);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });

  testWidgets('an account change does not show the previous board', (
    tester,
  ) async {
    await mountBoard(tester);
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    client.user = RaftRecord({'id': 'bob'});
    w.hold = Completer<void>();
    await tester.pumpWidget(page());
    await tester.pump();
    expect(find.text('Task 80'), findsNothing);
    expect(w.resourceSnapshots.serverPage(serverTasksPage), isNull);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(find.text('Task 80'), findsWidgets);
  });

  testWidgets('a mounted role change resets the board', (tester) async {
    final dynamic state = await mountBoard(tester);
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.notifyListeners();
    await tester.pumpAndSettle();
    expect(lane(state, 'todo'), hasLength(30));
    expect(state.laneCursors['todo'], '30');
  });

  testWidgets('the task list keeps its loaded lane pages across a task event', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(ResourceView));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    // Source serverTaskPages: the server-wide list walks one cursor per status
    // lane (a first page each), exactly like the board.
    expect(lane(state, 'todo'), hasLength(30));
    expect(lane(state, 'in_progress'), hasLength(5));
    expect(state.laneCursors['todo'], '30');
    expect(state.laneCursors['in_progress'], isNull);
    await state.moreLane('todo');
    await tester.pumpAndSettle();
    expect(state.rows, hasLength(65));
    final requests = w.taskQueries.length;
    client.emit('task:updated', {
      'channelId': 'c1',
      'task': {...taskRow(79, 'in_review'), 'title': 'Listed 79'},
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.rows, hasLength(65));
    expect(
      state.rows.firstWhere((t) => t['id'] == 't78')['status'],
      'todo',
    );
    expect(w.taskQueries, hasLength(requests));
    // Revalidation spans each lane's loaded window.
    await state.load(keep: true);
    await tester.pumpAndSettle();
    final todoQuery = w.taskQueries.lastWhere((q) => q['status'] == 'todo');
    // t79 moved to In Review: the Todo window is now 59 tasks.
    expect(todoQuery['limit'], 59);
    expect(lane(state, 'in_progress'), hasLength(5));
  });

  testWidgets('each status lane of the list has its own Load more', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(ResourceView));
    // Only Todo has another page; in-progress ends at five tasks.
    final more = find.byKey(const ValueKey('task-load-more-todo'));
    await tester.dragUntilVisible(
      more,
      find.byType(CustomScrollView).first,
      const Offset(0, -300),
    );
    expect(more, findsOneWidget);
    expect(find.byKey(const ValueKey('task-load-more-in_progress')), findsNothing);
    expect(find.text('Load more'), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(lane(state, 'todo'), hasLength(60));
    expect(
      w.taskQueries.last,
      containsPair('cursor', '30'),
    );
    expect(w.taskQueries.last['status'], 'todo');
  });

  group('task window helpers', () {
    test('partial facts never clobber known fields', () {
      final merged = mergeTaskFields(
        {'id': 't', 'title': 'A', 'descriptionPreview': 'old', 'x': 1},
        {'id': 't', 'title': 'B', 'description': 'full'},
      );
      expect(merged, {'id': 't', 'title': 'B', 'description': 'full', 'x': 1});
    });
    test('a revalidated window keeps rows pushed past it and the loaded tail', () {
      final current = [for (var n = 10; n > 0; n--) taskRow(n, 'todo')];
      final fetched = [
        for (var n = 11; n > 6; n--) taskRow(n, 'todo'),
      ];
      final result = reconcileTaskWindow(
        fetched: fetched,
        current: current,
        fetchedCursor: '5',
        currentCursor: '10',
        window: 5,
        fetchedIds: {for (final row in fetched) row['id']},
      );
      expect(result.rows.map((t) => t['taskNumber']), [
        11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, //
      ]);
      expect(identical(result.rows[1], current[0]), isTrue);
      expect(result.cursor, '10');
    });
  });
}
