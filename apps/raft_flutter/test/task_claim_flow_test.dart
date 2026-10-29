import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/task_status_request.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;

Map<String, dynamic> row(
  String id,
  String status, {
  String? claimedById,
  int number = 1,
}) => {
  'id': id,
  'taskNumber': number,
  'title': 'Task $id',
  'channelId': 'c1',
  'channelName': 'General',
  'channelType': 'channel',
  'status': status,
  'claimedById': claimedById,
  'claimedByType': claimedById == null ? null : 'user',
  'claimedByName': claimedById == null ? null : 'Alice',
  'createdByType': 'user',
  'createdById': 'alice',
  'createdByName': 'Alice',
};

class TaskPageWorkspace extends WorkspaceController {
  TaskPageWorkspace(super.client);
  late List<Map<String, dynamic>> tasks;
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path != '/tasks/server') return [];
    final status = query?['status'];
    return {
      'tasks': [
        for (final t in tasks)
          if (status == null || t['status'] == status) Map.of(t),
      ],
      'next_cursor': null,
    };
  }
}

void main() {
  test('only an unheld todo task moving to in_progress is a claim', () {
    expect(taskStatusRequest(row('t', 'todo'), 'in_progress'), (
      path: '/tasks/t/claim',
      data: null,
    ));
    // An empty holder id is no holder (the Web check is a falsy test).
    expect(
      taskStatusRequest(row('t', 'todo', claimedById: ''), 'in_progress'),
      (path: '/tasks/t/claim', data: null),
    );
    for (final other in [
      taskStatusRequest(row('t', 'todo', claimedById: 'bob'), 'in_progress'),
      taskStatusRequest(row('t', 'todo'), 'in_review'),
      taskStatusRequest(row('t', 'todo'), 'closed'),
      taskStatusRequest(row('t', 'closed'), 'in_progress'),
      taskStatusRequest(row('t', 'done'), 'in_progress'),
      taskStatusRequest(row('t', 'in_review'), 'in_progress'),
    ]) {
      expect(other.path, '/tasks/t/status');
    }
    expect(
      taskStatusRequest(
        row('t', 'todo', claimedById: 'bob'),
        'in_progress',
      ).data,
      {'status': 'in_progress'},
    );
  });

  group('server Tasks page', () {
    late ActivityClient client;
    late TaskPageWorkspace w;
    setUp(() {
      client = ActivityClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      w = TaskPageWorkspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
        ]
        ..tasks = [
          row('free', 'todo', number: 3),
          row('held', 'todo', claimedById: 'bob', number: 2),
        ];
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Widget page() => MaterialApp(
      theme: raftTheme(),
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

    Future<void> drag(WidgetTester tester, String title, String lane) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(title)),
      );
      await gesture.moveBy(const Offset(20, 20));
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(ValueKey('task-drop-$lane'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('dragging an unassigned task to In progress claims it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await drag(tester, 'Task free', 'in_progress');
      expect(client.posts, ['PATCH /tasks/free/claim']);
      expect(client.bodies.single, isNull);
    });

    testWidgets('an assigned task keeps the plain status write', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await drag(tester, 'Task held', 'in_progress');
      expect(client.posts, ['PATCH /tasks/held/status']);
      expect(client.bodies.single, {'status': 'in_progress'});
    });

    testWidgets(
      'an owner moving an unassigned task elsewhere is a status write',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        await drag(tester, 'Task free', 'in_review');
        expect(client.posts, ['PATCH /tasks/free/status']);
        expect(client.bodies.single, {'status': 'in_review'});
      },
    );

    testWidgets('the card status menu claims an unassigned task too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      w.tasks = [row('free', 'todo')];
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RaftInlineBadgeEditor).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(RaftInlineBadgeMenu),
          matching: find.byKey(const ValueKey('in_progress')),
        ),
      );
      await tester.pumpAndSettle();
      expect(client.posts, ['PATCH /tasks/free/claim']);
      expect(client.bodies.single, isNull);
    });

    testWidgets('a claim answer replaces the card in place', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      w.tasks = [row('free', 'todo')];
      client.responses['PATCH /tasks/free/claim'] = {
        'task': row('free', 'in_progress', claimedById: 'alice'),
      };
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ResourceView));
      await tester.tap(find.byType(RaftInlineBadgeEditor).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(RaftInlineBadgeMenu),
          matching: find.byKey(const ValueKey('in_progress')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (state.lanes['in_progress'] as List).single['claimedById'],
        'alice',
      );
      expect(state.lanes['todo'] as List, isEmpty);
    });
  });
}
