import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;

class _SearchWorkspace extends WorkspaceController {
  _SearchWorkspace(super.client);
  final searches = <Map<String, dynamic>>[];
  Completer<void>? hold;
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/search') {
      searches.add({...?query});
      final gate = hold;
      if (gate != null) await gate.future;
      return {
        'results': [
          for (var i = 0; i < 40; i++)
            {
              'id': 'hit$i',
              'channelId': 'ch${i % 4}',
              'channelName': 'Channel ${i % 4}',
              'channelType': 'channel',
              'senderId': 'bob',
              'senderType': 'user',
              'senderName': 'Bob',
              'content': 'Search body $i',
              'createdAt': '2026-10-10T00:00:00Z',
            },
        ],
        'hasMore': false,
      };
    }
    if (path == '/agents') return [];
    return [];
  }
}

void main() {
  late ActivityClient client;
  late _SearchWorkspace w;
  RaftChannel channel(int i, {Map<String, dynamic> extra = const {}}) =>
      RaftChannel({
        'id': 'ch$i',
        'name': 'Channel $i',
        'joined': true,
        ...extra,
      });
  setUp(() {
    client = ActivityClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    w = _SearchWorkspace(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channels = [
        for (var i = 0; i < 4; i++)
          channel(i, extra: {if (i == 2) 'isPrivate': true}),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<dynamic> mountWithResults(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'search',
            restoreSearchState: false,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'body');
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(ResourceView));
    state.advanced.timeRange = '7d';
    await state.load();
    await tester.pumpAndSettle();
    expect(state.rows, hasLength(40));
    return state;
  }

  ScrollPosition results(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ResourceSearchResults),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  testWidgets(
    'a channel:updated event keeps the query, filters, results and scroll position',
    (tester) async {
      final dynamic state = await mountWithResults(tester);
      final rows = state.rows;
      results(tester).jumpTo(600);
      await tester.pump();
      final searches = w.searches.length;

      w.channels = [
        channel(0),
        channel(1, extra: {'name': 'Renamed', 'description': 'new'}),
        channel(2, extra: {'isPrivate': true}),
        channel(3),
      ];
      client.emit('channel:updated', {'id': 'ch1'});
      w.notifyListeners();
      await tester.pumpAndSettle();

      expect(state.query.text, 'body');
      expect(state.advanced.timeRange, '7d');
      expect(identical(state.rows, rows), isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(results(tester).pixels, 600);
      // Source search results do not depend on the channel directory.
      expect(w.searches, hasLength(searches));
    },
  );

  testWidgets(
    'a channel the user can no longer see removes only its hits',
    (tester) async {
      final dynamic state = await mountWithResults(tester);
      final kept = state.rows.firstWhere((r) => r['channelId'] == 'ch0');
      final searches = w.searches.length;

      w.channels = [
        channel(0),
        channel(1),
        // The principal left this private channel: it is no longer visible.
        channel(2, extra: {'isPrivate': true, 'joined': false}),
        channel(3),
      ];
      client.emit('channel:updated', {'id': 'ch2'});
      w.notifyListeners();
      await tester.pumpAndSettle();

      expect(state.rows, hasLength(30));
      expect(state.rows.where((r) => r['channelId'] == 'ch2'), isEmpty);
      expect(identical(state.rows.first, kept), isTrue);
      expect(find.text('Search body 2'), findsNothing);
      expect(state.query.text, 'body');
      expect(state.advanced.timeRange, '7d');
      expect(w.searches, hasLength(searches));

      // A channel removed from the directory drops its hits the same way.
      w.channels = [channel(0), channel(1), channel(3)];
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(state.rows, hasLength(30));
      expect(state.query.text, 'body');
    },
  );

  testWidgets('a search in flight during a channel change still lands', (
    tester,
  ) async {
    final dynamic state = await mountWithResults(tester);
    w.hold = Completer<void>();
    await tester.enterText(find.byType(TextField), 'other');
    await tester.pump(const Duration(milliseconds: 210));
    final searches = w.searches.length;
    client.emit('channel:updated', {'id': 'ch1'});
    await tester.pump();
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(w.searches, hasLength(searches + 1));
    expect(w.searches.last['q'], 'other');
    expect(state.query.text, 'other');
    expect(state.rows, hasLength(40));
  });

  testWidgets('a pending debounced search survives a channel change', (
    tester,
  ) async {
    final dynamic state = await mountWithResults(tester);
    await tester.enterText(find.byType(TextField), 'later');
    await tester.pump(const Duration(milliseconds: 100));
    client.emit('channel:updated', {'id': 'ch1'});
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pumpAndSettle();
    expect(w.searches.last['q'], 'later');
    expect(state.rows, hasLength(40));
  });

  testWidgets('a server switch resets the query, filters and results', (
    tester,
  ) async {
    final dynamic state = await mountWithResults(tester);
    client.selectServer('s2');
    w.server = RaftRecord({'id': 's2', 'role': 'owner'});
    w.notifyListeners();
    await tester.pumpAndSettle();
    expect(state.query.text, '');
    expect(state.advanced.timeRange, 'any');
    expect(state.rows, isEmpty);
    expect(find.text('Search body 0'), findsNothing);
  });

  testWidgets('a role change resets the query and results', (tester) async {
    final dynamic state = await mountWithResults(tester);
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.notifyListeners();
    await tester.pumpAndSettle();
    expect(state.query.text, '');
    expect(state.rows, isEmpty);
  });
}
