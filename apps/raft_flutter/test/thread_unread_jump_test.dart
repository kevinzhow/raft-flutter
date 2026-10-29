import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/thread_unread_jump.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

List<Map<String, dynamic>> _rows(int count) => [
  for (var i = 0; i < count; i++)
    {
      'id': 'm-$i',
      'channelId': 'c1',
      'seq': '${i + 1}',
      'senderId': 'alice',
      'createdAt': DateTime.utc(2026, 10, 1, 0, i).toIso8601String(),
      'content': List.filled(i % 3 + 1, 'message $i').join('\n'),
    },
];

Map<String, dynamic> _thread(int parent, {int unread = 1}) => {
  'threadChannelId': 't-$parent',
  'parentMessageId': 'm-$parent',
  'parentChannelId': 'c1',
  'unreadCount': unread,
  'hasMention': false,
  'parentMessageCreatedAt': DateTime.utc(
    2026,
    10,
    1,
    0,
    parent,
  ).toIso8601String(),
};

/// Web v1.21.23 `ThreadUnreadJumpPill` (`thread_unread_badge_v0`): one pill
/// for the unread followed threads whose parent message is off screen.
void main() {
  group('placing the jump targets', () {
    final range = LoadedRange(
      oldestAt: DateTime.utc(2026, 10, 1),
      newestAt: DateTime.utc(2026, 10, 2),
      hasNewer: false,
    );

    test('a parent on screen already shows its replies and is left out', () {
      final targets = placeJumpTargets(
        [_thread(1), _thread(2), _thread(3)],
        {
          'm-1': RowPlacement.above,
          'm-2': RowPlacement.visible,
          'm-3': RowPlacement.below,
        },
        range,
      );
      expect([for (final t in targets.above) t['parentMessageId']], ['m-1']);
      expect([for (final t in targets.below) t['parentMessageId']], ['m-3']);
      expect(targets.nearestBelow!['parentMessageId'], 'm-3');
      expect(targets.earliestAbove!['parentMessageId'], 'm-1');
    });

    test('a parent that is not built is placed by time against the view', () {
      final targets = placeJumpTargets(
        [_thread(2), _thread(30), _thread(60)],
        const {},
        range,
        viewTop: DateTime.utc(2026, 10, 1, 0, 20),
        viewBottom: DateTime.utc(2026, 10, 1, 0, 40),
      );
      expect([for (final t in targets.above) t['parentMessageId']], ['m-2']);
      expect([for (final t in targets.below) t['parentMessageId']], ['m-60']);
      // m-30 lies between the rows in view: on screen, so no pill for it.
    });

    test(
      'without a view, newer than the loaded window is below, the rest above',
      () {
        final reading = LoadedRange(
          oldestAt: DateTime.utc(2026, 10, 1),
          newestAt: DateTime.utc(2026, 10, 1, 0, 10),
          hasNewer: true,
        );
        final targets = placeJumpTargets(
          [
            _thread(5),
            _thread(50),
            {..._thread(7), 'parentMessageCreatedAt': null},
          ],
          const {},
          reading,
        );
        expect([for (final t in targets.below) t['parentMessageId']], ['m-50']);
        expect(
          [for (final t in targets.above) t['parentMessageId']],
          ['m-5', 'm-7'],
          reason: 'an older server sends no parent time: older history above',
        );
        // Not newer: nothing is below.
        expect(placeJumpTargets([_thread(50)], const {}, range).below, isEmpty);
      },
    );
  });

  group('in a channel', () {
    late WorkspaceController w;
    var threads = <Map<String, dynamic>>[];
    var flag = true;

    Future<void> mount(
      WidgetTester tester, {
      required List<Map<String, dynamic>> followed,
      int count = 80,
      bool enabled = true,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      threads = [...followed];
      flag = enabled;
      final (controller, api) = (await tester.runAsync(
        () => fixture('member'),
      ))!;
      w = controller;
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      // The shell asks for the flags as it draws the sidebar; here nothing does.
      ActivityRolloutFlags.of(w);
      final rows = _rows(count);
      w.messageDomain.ledger.ingest(
        rows,
        expectedGeneration: w.messageDomain.ledger.generation,
      );
      w.messageDomain.visibleIds['c1'] = {
        for (final r in rows) r['id'] as String,
      };
      api.routes['GET /channels/threads/followed'] = (_) => {
        'threads': threads,
      };
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          if (flag) {'key': 'thread_unread_badge_v0', 'enabled': true},
        ],
      };
      api.routes['GET /messages/context/m-3'] = (_) => {
        'messages': rows.take(20).toList(),
        'targetMessageId': 'm-3',
        'hasOlder': false,
        'hasNewer': true,
      };
      api.routes['POST /channels/c1/read'] = (_) => {};
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (var i = 0; i < 200; i++) {
          final on = ActivityRolloutFlags.peek(w)?.threadUnreadBadge == enabled;
          if (on && (!enabled || w.followedThreads.settled)) break;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    }

    Finder pill(String where) =>
        find.byKey(ValueKey('thread-unread-jump-pill-$where'));

    testWidgets(
      'only above the view: the Earliest pill sits at the top, the '
      'cross dismisses it until the count changes, a click flashes the parent',
      (tester) async {
        await mount(tester, followed: [_thread(3), _thread(70)]);
        // The newest messages are in view: m-3 is far above, m-70 is on screen
        // (its replies show on its own row).
        expect(pill('top'), findsOneWidget);
        expect(pill('bottom'), findsNothing);
        expect(find.text('Earliest unread thread (2)'), findsOneWidget);
        expect(find.text('Next unread thread (2)'), findsNothing);

        // Dismissed: gone while the number stays 2.
        await tester.tap(find.byKey(const ValueKey('thread-unread-dismiss')));
        await tester.pumpAndSettle();
        expect(pill('top'), findsNothing);
        w.notifyListeners();
        await tester.pumpAndSettle();
        expect(pill('top'), findsNothing);

        // A third unread thread changes the number: the pill comes back.
        threads = [...threads, _thread(5)];
        await tester.runAsync(w.followedThreads.refresh);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Earliest unread thread (3)'), findsOneWidget);

        // The click goes to the topmost parent and does not open the thread.
        await tester.tap(find.byKey(const ValueKey('thread-unread-jump')));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(w.messageDomain.state.highlightedMessageId, 'm-3');
        expect(w.threadChannelId, isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('a server with the flag off shows no pill', (tester) async {
      await mount(tester, followed: [_thread(3), _thread(4)], enabled: false);
      expect(pill('top'), findsNothing);
      expect(find.byType(RaftThreadUnreadJumpPill), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('read threads show no pill', (tester) async {
      await mount(
        tester,
        followed: [_thread(3, unread: 0), _thread(4, unread: 0)],
      );
      expect(pill('top'), findsNothing);
      expect(pill('bottom'), findsNothing);
      expect(find.byType(RaftThreadUnreadJumpPill), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('scrolled up: a parent below gets Next beside Back to Bottom', (
      tester,
    ) async {
      await mount(tester, followed: [_thread(3), _thread(78)]);
      expect(pill('top'), findsOneWidget);
      // Reading history: drag the timeline down so the newest rows leave the
      // view; Back to Bottom shows and m-78 is now below.
      final timeline = find.byType(RaftChatView);
      await tester.dragFrom(
        tester.getCenter(timeline),
        const Offset(0, 1400),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Back to Bottom'), findsOneWidget);
      expect(pill('bottom'), findsOneWidget);
      expect(pill('top'), findsNothing, reason: 'a parent below wins');
      expect(find.text('Next unread thread (2)'), findsOneWidget);
      // Both controls share one row, centred, 8 px apart.
      final back = tester.getRect(find.text('Back to Bottom'));
      final next = tester.getRect(find.text('Next unread thread (2)'));
      expect(next.left, greaterThan(back.right));
      expect((back.center.dy - next.center.dy).abs(), lessThan(2));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
