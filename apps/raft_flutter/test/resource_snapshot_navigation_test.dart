import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/resource_snapshot_cache.dart';
import 'package:raft_flutter/data/server_saved_window.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/saved_sidebar_entry.dart';
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
    theme: raftTheme(),
    home: Scaffold(
      body: ResourceView(
        key: key,
        controller: w,
        section: section,
        onMessage: (_, _) async {},
      ),
    ),
  );
  ServerSavedWindow? heldSaved() {
    final slot = w.resourceSnapshots.serverPage(serverSavedPage);
    return slot is ServerSavedWindow ? slot : null;
  }

  Widget away() => MaterialApp(
    theme: raftTheme(),
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
    final held = heldSaved();
    expect(held, isNotNull);
    expect(w.resourceSnapshots.read('saved', held!.snapshot.identity), isNull);
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

  testWidgets('an unsave while away leaves on the first frame and a new save is revalidated', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final queries = w.savedQueries.length;
    final window = heldSaved();
    w.saved.insert(0, {
      ...w.saved.first,
      'messageId': 'fresh',
      'content': 'Fresh saved',
    });
    await SavedCountStore.of(w).setSaved('saved0', false);
    await SavedCountStore.of(w).setSaved('fresh', true);
    expect(w.savedQueries, hasLength(queries));
    expect(window?.needsRevalidate, isTrue);
    expect(
      window?.snapshot.rows.any((row) => row['messageId'] == 'saved0'),
      isFalse,
    );
    expect(
      window?.snapshot.rows.any((row) => row['messageId'] == 'fresh'),
      isFalse,
    );
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    expect(skeleton, findsNothing);
    expect(find.text('Saved body 0'), findsNothing);
    expect(find.text('Fresh saved'), findsNothing);
    expect(w.savedQueries, hasLength(queries + 1));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(find.text('Fresh saved'), findsOneWidget);
    expect(w.savedQueries, hasLength(queries + 1));
  });

  testWidgets('deleted messages and lost channels leave the saved window open or closed', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    final queries = w.savedQueries.length;
    client.emit('message:deleted', {'id': 'saved0'});
    await tester.pump();
    expect(find.text('Saved body 0'), findsNothing);
    expect(w.savedQueries, hasLength(queries));
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final awayQueries = w.savedQueries.length;
    client.emit('message:deleted', {'id': 'saved1', 'channelId': 'ch1'});
    client.emit('channel:removed', {'id': 'ch0'});
    client.emit('channel:authority-updated', {'id': 'ch7'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(w.savedQueries, hasLength(awayQueries));
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    expect(find.text('Saved body 1'), findsNothing);
    expect(find.text('Saved body 10'), findsNothing);
    expect(find.text('Saved body 7'), findsNothing);
    expect(find.text('Saved body 17'), findsNothing);
    expect(w.savedQueries, hasLength(awayQueries + 1));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(w.savedQueries, hasLength(awayQueries + 1));
  });

  testWidgets('an edit while away patches the held saved row and does not fetch', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final queries = w.savedQueries.length;
    client.emit('message:updated', {
      'id': 'saved0',
      'channelId': 'ch0',
      'content': 'Edited away',
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(w.savedQueries, hasLength(queries));
    expect(
      heldSaved()?.snapshot.rows.first['content'],
      'Edited away',
    );
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    expect(find.text('Edited away'), findsOneWidget);
    expect(w.savedQueries, hasLength(queries + 1));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });

  testWidgets('a reconnect while away marks saved for one return revalidation', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final queries = w.savedQueries.length;
    client.emit('connected', const {});
    await tester.pump(const Duration(milliseconds: 300));
    expect(heldSaved()?.needsRevalidate, isTrue);
    expect(w.savedQueries, hasLength(queries));
    expect(find.text('Saved body 0'), findsNothing);
  });

  testWidgets('presence while away does not mark the saved window', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final queries = w.savedQueries.length;
    client.emit('agent:seen', {'id': 'a1'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(heldSaved()?.needsRevalidate, isFalse);
    expect(w.savedQueries, hasLength(queries));
  });

  testWidgets('a late saved revalidation cannot rewrite the window after the page leaves', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    await tester.pump();
    w.saved[0] = {...w.saved[0], 'content': 'Should not land'};
    await tester.pumpWidget(away());
    await tester.pump();
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(
      heldSaved()?.snapshot.rows.any(
        (row) => row['content'] == 'Should not land',
      ),
      isFalse,
    );
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    expect(find.text('Saved body 0'), findsOneWidget);
    expect(find.text('Should not land'), findsNothing);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });

  testWidgets('a channel lost while away is absent from saved on the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final queries = w.savedQueries.length;
    w.channels = w.channels.where((channel) => channel.id != 'ch1').toList();
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    expect(find.text('Saved body 1'), findsNothing);
    expect(find.text('Saved body 11'), findsNothing);
    expect(w.savedQueries, hasLength(queries + 1));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(w.savedQueries, hasLength(queries + 1));
  });

  testWidgets('logout drops saved and a later event cannot recreate it', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    final queries = w.savedQueries.length;
    w.revokeServer('s1');
    expect(heldSaved(), isNull);
    client.emit('message:deleted', {'id': 'saved1'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(heldSaved(), isNull);
    expect(w.savedQueries, hasLength(queries));
  });

  testWidgets('an account change does not show the previous saved rows', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    client.user = RaftRecord({'id': 'bob'});
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    await tester.pump();
    expect(find.text('Saved body 0'), findsNothing);
    expect(heldSaved(), isNull);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });

  testWidgets('a role change while away does not show the previous saved rows', (
    tester,
  ) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.hold = Completer<void>();
    await tester.pumpWidget(page('saved'));
    expect(skeleton, findsOneWidget);
    expect(find.text('Saved body 0'), findsNothing);
    expect(heldSaved(), isNull);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });

  testWidgets('a server switch drops the saved window', (tester) async {
    await tester.pumpWidget(page('saved'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(away());
    await tester.pumpAndSettle();
    expect(heldSaved(), isNotNull);
    unawaited(w.selectServer(RaftRecord({'id': 's2', 'role': 'owner'})));
    expect(heldSaved(), isNull);
    await tester.pumpAndSettle();
  });
}
