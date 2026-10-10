import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, skeleton;

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() => (client, w) = activityFixture());
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<dynamic> mount(WidgetTester tester, String section) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: section,
            initialQuery: section == 'search' ? 'body' : null,
            restoreSearchState: false,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(ResourceView));
  }

  testWidgets('Saved patches an edited message in place without reloading', (
    tester,
  ) async {
    final dynamic state = await mount(tester, 'saved');
    final requests = w.savedQueries.length;
    final untouched = state.rows[1];
    client.emit('message:updated', {
      'id': 'saved0',
      'channelId': 'ch0',
      'content': 'Edited saved body',
    });
    await tester.pump();
    expect(skeleton, findsNothing);
    expect(find.text('Edited saved body'), findsOneWidget);
    expect(identical(state.rows[1], untouched), isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(w.savedQueries, hasLength(requests));
    // A partial (task-field) update leaves the body alone.
    client.emit('message:updated', {
      'id': 'saved0',
      'channelId': 'ch0',
      'taskStatus': 'done',
    });
    await tester.pump();
    expect(find.text('Edited saved body'), findsOneWidget);
    expect(state.rows, hasLength(20));
  });

  testWidgets(
    'Search patches results, ignores agent activity and keeps the sender filter',
    (tester) async {
      final dynamic state = await mount(tester, 'search');
      expect(state.rows, hasLength(5));
      final searches = w.searchQueries.length, catalogs = w.agentQueries;
      client.emit('message:updated', {
        'id': 'hit2',
        'channelId': 'ch2',
        'content': 'Edited search body',
      });
      await tester.pump(const Duration(milliseconds: 500));
      expect(state.rows[2]['content'], 'Edited search body');
      expect(w.searchQueries, hasLength(searches));

      client.emit('agent:activity', {'agentId': 'a1', 'activity': 'typing'});
      await tester.pump(const Duration(milliseconds: 500));
      expect(w.agentQueries, catalogs);

      final helper = (state.senders as List).firstWhere(
        (s) => s.key == 'agent:a1',
      );
      state.advanced.selectSender(helper);
      client.emit('agent:updated', {'id': 'a1'});
      await tester.pump();
      // The directory is not cleared while it refreshes.
      expect(state.searchAgents, isNotEmpty);
      expect(state.advanced.sender?.key, 'agent:a1');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(w.agentQueries, catalogs + 1);
      expect(state.advanced.sender?.key, 'agent:a1');
      expect(state.searchAgents, isNotEmpty);
      expect(w.searchQueries, hasLength(searches));
    },
  );
}
