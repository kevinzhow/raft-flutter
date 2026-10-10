import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;
import 'task_snapshot_navigation_test.dart' show taskRow;

class _ChannelTasks extends WorkspaceController {
  _ChannelTasks(super.client);
  final queries = <(String, Map<String, dynamic>)>[];
  Completer<void>? hold;
  List<Map<String, dynamic>> tasks = [
    for (var n = 12; n > 0; n--) taskRow(n, 'todo'),
  ];
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (!path.startsWith('/tasks/')) return [];
    queries.add((path, {...?query}));
    final gate = hold;
    if (gate != null) await gate.future;
    final status = query?['status'];
    return {
      'tasks': [
        for (final row in tasks)
          if (status == null || row['status'] == status)
            Map<String, dynamic>.of(row),
      ],
      'next_cursor': null,
    };
  }
}

void main() {
  late ActivityClient client;
  late _ChannelTasks w;
  setUp(() {
    client = ActivityClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    w = _ChannelTasks(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
        RaftChannel({'id': 'c2', 'name': 'Other', 'joined': true}),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Widget page(String channel) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: RaftDensityScope(
      density: RaftDensity.desktop,
      child: Scaffold(
        body: ResourceView(
          key: ValueKey('tab-$channel'),
          controller: w,
          section: 'tasks',
          channelId: channel,
          onMessage: (_, _) async {},
        ),
      ),
    ),
  );
  final away = MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: const Scaffold(body: SizedBox.expand()),
  );
  final spinner = find.byType(CircularProgressIndicator);

  testWidgets(
    'a channel Tasks tab revisit shows its cached board at the first frame and revalidates silently',
    (tester) async {
      await tester.pumpWidget(page('c1'));
      await tester.pumpAndSettle();
      expect(find.text('Task 12'), findsOneWidget);
      await tester.pumpWidget(away);
      await tester.pumpAndSettle();

      final before = w.queries.length;
      w.hold = Completer<void>();
      await tester.pumpWidget(page('c1'));
      expect(spinner, findsNothing);
      expect(find.text('Task 12'), findsOneWidget);
      expect(w.queries.skip(before).map((q) => q.$1).toSet(), {
        '/tasks/channel/c1',
      });
      w.tasks[0] = {...w.tasks[0], 'title': 'Fresh 12'};
      w.hold!.complete();
      w.hold = null;
      await tester.pumpAndSettle();
      expect(spinner, findsNothing);
      expect(find.text('Fresh 12'), findsOneWidget);
    },
  );

  testWidgets('channel snapshots never cross channels', (tester) async {
    await tester.pumpWidget(page('c1'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away);
    w.tasks = [for (var n = 3; n > 0; n--) taskRow(n, 'todo', channel: 'c2')];
    w.hold = Completer<void>();
    await tester.pumpWidget(page('c2'));
    // Cold: c1's rows are not shown for c2.
    expect(find.text('Task 12'), findsNothing);
    expect(spinner, findsWidgets);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(find.text('Task 3'), findsOneWidget);
    expect(find.text('Task 12'), findsNothing);
  });

  testWidgets('a channel lost while away does not show cached tasks', (
    tester,
  ) async {
    await tester.pumpWidget(page('c1'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away);
    w.channels = w.channels.where((c) => c.id != 'c1').toList();
    await tester.pumpWidget(page('c1'));
    expect(find.text('Task 12'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('This channel is not available.'), findsOneWidget);
  });
}
