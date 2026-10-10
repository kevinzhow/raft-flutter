import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show
        ActivityClient,
        ActivityWorkspace,
        activityFixture,
        activityScroll,
        channelRow,
        shown;

/// Web ThreadsInbox: a reader scrolled away from the top keeps their place
/// when rows land above them, and an "N new updates" pill leads back up.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    final label = '${family.name}${dark ? ' dark' : ''}';
    late ActivityClient client;
    late ActivityWorkspace w;
    setUp(() => (client, w) = activityFixture());
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Future<dynamic> mount(
      WidgetTester tester, {
      String section = 'activity',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: section,
              activitySidebarEnabled: true,
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state(find.byType(ResourceView));
    }

    Finder card(String title) => find.ancestor(
      of: shown(title),
      matching: find.byType(RaftConversationCard),
    );

    Rect listRect(WidgetTester tester) =>
        tester.getRect(find.byType(Scrollable).last);

    /// The first row fully inside the list viewport.
    int firstVisible(WidgetTester tester, {String prefix = 'Channel '}) {
      final list = listRect(tester);
      for (var i = 0; i < 60; i++) {
        final row = card('$prefix$i');
        if (row.evaluate().isEmpty) continue;
        final rect = tester.getRect(row);
        if (rect.top >= list.top && rect.bottom <= list.bottom) return i;
      }
      fail('no visible row');
    }

    Map<String, dynamic> live(String id, int channel, int seq) => {
      'id': id,
      'channelId': 'ch$channel',
      'seq': seq,
      'content': 'Live $id',
      'senderId': 'carol',
      'senderType': 'user',
      'senderName': 'Carol',
      'createdAt': '2026-10-10T01:00:00Z',
    };

    /// Mirrors the server inbox after [channel] got a newer message.
    void serverMoves(int channel, int seq, String id) {
      final at = w.inbox.indexWhere((r) => r['channelId'] == 'ch$channel');
      final row = w.inbox.removeAt(at);
      w.inbox.insert(0, {
        ...row,
        'lastMessageId': id,
        'lastMessagePreview': 'Live $id',
        'latestActivitySeq': '$seq',
        'doneFrontierSeq': '$seq',
      });
    }

    testWidgets(
      '[$label] scrolled down: a socket row moved to the top keeps the reading row in place every frame and counts one update',
      (tester) async {
        final dynamic state = await mount(tester);
        final scroll = activityScroll(tester);
        scroll.position.jumpTo(700);
        await tester.pump();
        final anchor = firstVisible(tester);
        final before = tester.getRect(card('Channel $anchor'));
        expect(find.byType(RaftNewUpdatesButton), findsNothing);

        // A row far below the viewport advances and moves to the top.
        client.emit('message:new', live('n1', 25, 2000));
        await tester.pump();
        expect(state.rows.first['channelId'], 'ch25');
        expect(tester.getRect(card('Channel $anchor')), before);
        expect(scroll.position.pixels, greaterThan(700));
        expect(find.text('1 new update'), findsOneWidget);
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(card('Channel $anchor')), before);
        }

        // The canonical reconcile accepts the same order: nothing moves.
        serverMoves(25, 2000, 'n1');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(tester.getRect(card('Channel $anchor')), before);
        expect(find.text('1 new update'), findsOneWidget);

        // A visible row moving to the top is not the anchor; the reader's row
        // still stays where it was.
        final visibleMover = anchor + 1;
        client.emit('message:new', live('n2', visibleMover, 2001));
        await tester.pump();
        expect(state.rows.first['channelId'], 'ch$visibleMover');
        expect(tester.getRect(card('Channel $anchor')), before);
        expect(find.text('2 new updates'), findsOneWidget);

        // The pill sits at the top centre of the list (Web `sticky top-0
        // left-1/2 -translate-x-1/2`).
        final list = listRect(tester);
        final pill = tester.getRect(
          find.descendant(
            of: find.byType(RaftNewUpdatesButton),
            matching: find.byType(RaftRecipeButton),
          ),
        );
        expect(pill.top, list.top);
        expect(pill.center.dx, closeTo(list.center.dx, .5));

        serverMoves(visibleMover, 2001, 'n2');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        // When the reader's own first row moves to the top, the next visible
        // row holds its place instead.
        final next = card('Channel ${anchor + 2}');
        final nextBefore = tester.getRect(next);
        client.emit('message:new', live('n3', anchor, 2002));
        await tester.pump();
        expect(state.rows.first['channelId'], 'ch$anchor');
        expect(tester.getRect(next), nextBefore);
        expect(find.text('3 new updates'), findsOneWidget);
        serverMoves(anchor, 2002, 'n3');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(tester.getRect(next), nextBefore);

        // Tapping the pill returns to the top and clears it.
        await tester.tap(find.text('3 new updates'));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, 0);
        expect(find.byType(RaftNewUpdatesButton), findsNothing);
        expect(
          tester.getRect(card('Channel $visibleMover')).top,
          lessThan(tester.getRect(card('Channel 25')).top),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[$label] at the top a new row inserts normally without a pill; reaching the top clears the count',
      (tester) async {
        final dynamic state = await mount(tester);
        final scroll = activityScroll(tester);
        expect(scroll.position.pixels, 0);
        client.emit('message:new', live('t1', 20, 2000));
        await tester.pump();
        expect(state.rows.first['channelId'], 'ch20');
        expect(scroll.position.pixels, 0);
        expect(find.byType(RaftNewUpdatesButton), findsNothing);
        final list = listRect(tester);
        expect(tester.getRect(card('Channel 20')).top, list.top + 16);
        serverMoves(20, 2000, 't1');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(find.byType(RaftNewUpdatesButton), findsNothing);

        // Scrolled down, an update shows the pill; scrolling back to the top
        // by hand clears it (Web `handleScroll`: scrollTop < 50).
        scroll.position.jumpTo(500);
        await tester.pump();
        client.emit('message:new', live('t2', 22, 2001));
        await tester.pump();
        expect(find.text('1 new update'), findsOneWidget);
        serverMoves(22, 2001, 't2');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        scroll.position.jumpTo(60);
        await tester.pump();
        expect(find.text('1 new update'), findsOneWidget);
        scroll.position.jumpTo(40);
        await tester.pump();
        expect(find.byType(RaftNewUpdatesButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[$label] a reconcile that brings a new conversation above the reader keeps their row',
      (tester) async {
        w.channels = [
          ...w.channels,
          RaftChannel({'id': 'ch60', 'name': 'Channel 60', 'joined': true}),
        ];
        final dynamic state = await mount(tester);
        final scroll = activityScroll(tester);
        scroll.position.jumpTo(900);
        await tester.pump();
        final anchor = firstVisible(tester);
        final before = tester.getRect(card('Channel $anchor'));
        w.inbox.insert(0, channelRow(60, seq: 3000));
        client.emit('thread:updated', {'threadChannelId': 'elsewhere'});
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();
        expect(state.rows.first['channelId'], 'ch60');
        expect(tester.getRect(card('Channel $anchor')), before);
        expect(find.text('1 new update'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.getRect(card('Channel $anchor')), before);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('[$label] Saved keeps the reader in place and shows the pill', (
      tester,
    ) async {
      final dynamic state = await mount(tester, section: 'saved');
      final scroll = activityScroll(tester);
      scroll.position.jumpTo(600);
      await tester.pump();
      final list = listRect(tester);
      Finder saved(int i) => find.byKey(ValueKey('saved-saved$i'));
      final anchor = [
        for (var i = 0; i < 30; i++)
          if (saved(i).evaluate().isNotEmpty &&
              tester.getRect(saved(i)).top >= list.top)
            i,
      ].first;
      final before = tester.getRect(saved(anchor));
      w.saved.insert(0, {
        ...w.saved.first,
        'messageId': 'savedNew',
        'content': 'Newly saved',
      });
      await state.reconcile();
      await tester.pump();
      expect(state.rows.first['messageId'], 'savedNew');
      expect(tester.getRect(saved(anchor)), before);
      expect(find.text('1 new update'), findsOneWidget);
      await tester.tap(find.text('1 new update'));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, 0);
      expect(find.byType(RaftNewUpdatesButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
