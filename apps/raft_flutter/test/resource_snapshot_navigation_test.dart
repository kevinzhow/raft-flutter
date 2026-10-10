import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/resource_snapshot_cache.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show
        ActivityClient,
        ActivityWorkspace,
        activityFixture,
        activityScroll,
        shown,
        skeleton;

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() => (client, w) = activityFixture());
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Widget page(String section, {Key? key}) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: ResourceView(
        key: key,
        controller: w,
        section: section,
        onMessage: (_, _) async {},
      ),
    ),
  );
  Widget away() => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: const Scaffold(body: SizedBox.expand()),
  );

  testWidgets(
    'returning to Activity shows cached rows, loaded pages and scroll at once, then revalidates in place',
    (tester) async {
      await tester.pumpWidget(page('activity'));
      await tester.pumpAndSettle();
      dynamic state = tester.state(find.byType(ResourceView));
      await state.load(append: true);
      await tester.pumpAndSettle();
      expect(state.rows, hasLength(60));
      activityScroll(tester).position.jumpTo(1500);
      await tester.pump();
      final cachedRow = state.rows[40];

      await tester.pumpWidget(away());
      await tester.pumpAndSettle();
      final requests = w.inboxQueries.length;
      w.hold = Completer<void>();
      await tester.pumpWidget(page('activity'));
      // First frame: no skeleton, every loaded page, same scroll position.
      expect(skeleton, findsNothing);
      state = tester.state(find.byType(ResourceView));
      expect(state.rows, hasLength(60));
      expect(activityScroll(tester).position.pixels, 1500);
      expect(w.inboxQueries, hasLength(requests + 1));
      expect(w.inboxQueries.last['limit'], 60);
      await tester.pump(const Duration(milliseconds: 16));
      expect(skeleton, findsNothing);
      w.inbox[0] = {...w.inbox[0], 'lastMessagePreview': 'Fresh 0'};
      w.hold!.complete();
      w.hold = null;
      await tester.pumpAndSettle();
      expect(state.rows, hasLength(60));
      expect(state.rows.first['lastMessagePreview'], 'Fresh 0');
      expect(identical(state.rows[40], cachedRow), isTrue);
      expect(activityScroll(tester).position.pixels, 1500);
    },
  );

  testWidgets('a channel lost while away never reappears from the cache', (
    tester,
  ) async {
    await tester.pumpWidget(page('activity'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    w.channels = w.channels.where((c) => c.id != 'ch1').toList();
    w.hold = Completer<void>();
    await tester.pumpWidget(page('activity'));
    final dynamic state = tester.state(find.byType(ResourceView));
    expect(state.rows.where((r) => r['channelId'] == 'ch1'), isEmpty);
    expect(state.rows, hasLength(29));
    expect(shown('Channel 1'), findsNothing);
    w.hold!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a role or server change never serves the previous snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(page('activity'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.hold = Completer<void>();
    await tester.pumpWidget(page('activity'));
    final dynamic state = tester.state(find.byType(ResourceView));
    expect(state.rows, isEmpty);
    expect(skeleton, findsOneWidget);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(state.rows, hasLength(30));
    await tester.pumpWidget(away());
    expect(w.resourceSnapshots.read('activity', state.identityAuthority), isNotNull);
    // Server switch drops every page snapshot.
    unawaited(w.selectServer(RaftRecord({'id': 's2', 'role': 'owner'})));
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    client.selectServer('s1');
    expect(w.resourceSnapshots.read('activity', state.identityAuthority), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('Saved keeps its rows across navigation', (tester) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    dynamic state = tester.state(find.byType(ResourceView));
    expect(state.rows, hasLength(20));
    await tester.pumpWidget(away());
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    state = tester.state(find.byType(ResourceView));
    expect(skeleton, findsNothing);
    expect(state.rows, hasLength(20));
    expect(find.text('Saved body 0'), findsOneWidget);
    expect(w.savedQueries.last['limit'], 20);
    w.hold!.complete();
    await tester.pumpAndSettle();
    expect(state.rows, hasLength(20));
  });

  test('snapshots are bound to the identity that accepted them', () {
    final cache = ResourceSnapshotCache();
    cache.write(
      'activity',
      const ResourceSnapshot(
        identity: 'a',
        enabledActivity: false,
        view: 'v',
        rows: [],
        hasMore: false,
        filter: 'all',
        activeActivityFilter: 'all',
        query: '',
        channelId: null,
        direction: 'desc',
        totalCount: null,
        totalUnreadCount: null,
        activityAllCount: null,
        savedActivityTotal: 0,
        activityGroups: [],
        acceptedActivityItems: [],
        savedActivityItems: [],
        doneActivityItems: [],
        channelAccess: {},
        scrollOffset: 0,
      ),
    );
    expect(cache.read('activity', 'b'), isNull);
    expect(cache.read('activity', 'a'), isNull);
  });
}
