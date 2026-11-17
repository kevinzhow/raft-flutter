import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/features/activity_first_unread.dart';
import 'package:raft_flutter/features/activity_swipe_actions.dart';
import 'package:raft_flutter/features/activity_undo.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/stale_counts_notice.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/activity_list_harness.dart';

void main() {
  late ServerClient client;
  late ActivityWorkspace w;

  setUp(() {
    final (c, base) = serverFixture();
    client = c;
    w = base..inbox = [for (var i = 0; i < 40; i++) dayRow(i, unread: i == 30 ? 1 : 0)];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Finder rowOf(String key) => find.byKey(ValueKey(key));

  group('pure rules', () {
    test('swipeDoneCommitItem: unchanged, moved on, unlisted, object', () {
      final swiped = dayRow(1, seq: 10);
      expect(swipeDoneCommitItem(swiped, null), swiped);
      expect(swipeDoneCommitItem(swiped, dayRow(1, seq: 10)), isNotNull);
      expect(swipeDoneCommitItem(swiped, dayRow(1, seq: 11)), isNull);
      final obj = {'kind': 'object', 'objectKind': 'artifact', 'objectId': 'o', 'doneFrontierSeq': '3'};
      expect(swipeDoneCommitItem(obj, {...obj}), isNotNull);
      expect(swipeDoneCommitItem(obj, {...obj, 'doneFrontierSeq': '4'}), isNull);
      final mention = {'kind': 'mention_action', 'channelId': 'c'};
      expect(swipeDoneCommitItem(mention, {...mention, 'x': 1}), isNotNull);
    });

    test('who can swipe what (Web inboxRowActions)', () {
      final thread = threadRow(1);
      expect(canUnfollowActivityRow(thread), isTrue);
      expect(canUnfollowActivityRow({...thread, 'isFollowing': false}), isFalse);
      expect(canUnfollowActivityRow(dayRow(1)), isFalse);
      expect(canSwipeActivityRowRead(dayRow(1), muted: false), isTrue);
      expect(canSwipeActivityRowRead(dayRow(1), muted: true), isFalse);
      expect(canSwipeActivityRowRead({'kind': 'mention_action'}, muted: false), isFalse);
      expect(canSwipeActivityRowRead({'kind': 'object', 'objectId': 'o'}, muted: false), isFalse);
      expect(canSwipeActivityRowRead({...thread, 'isFollowing': false}, muted: false), isFalse);
    });
  });

  testWidgets('Newer activity on a waiting Done calls it off: nothing is written', (t) async {
    await mountActivity(t, w, phoneTouch);
    await t.drag(rowOf('activity-channel-ch1'), const Offset(-220, 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable());
    await t.pump();
    expect(rowOf('activity-channel-ch1'), findsNothing);
    final dynamic state = t.state(find.byType(ResourceView));
    state.rows = <Map<String, dynamic>>[
      for (final r in state.rows)
        if (r['channelId'] == 'ch1') {...r, 'latestActivitySeq': '5000', 'doneFrontierSeq': '5000'} else r,
    ];
    t.element(find.byType(ResourceView)).markNeedsBuild();
    await t.pump();
    expect(rowOf('activity-channel-ch1'), findsOneWidget);
    await t.pump(const Duration(seconds: 10));
    expect(client.posts.where((p) => p.endsWith('/done')), isEmpty);
  });

  testWidgets('a filter change while Done waits still writes it', (t) async {
    await mountActivity(t, w, desktop);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: t.getCenter(rowOf('activity-channel-ch1')));
    await t.pump();
    await t.tap(find.descendant(of: rowOf('activity-channel-ch1'), matching: find.byKey(const ValueKey('inbox-row-done'))));
    await t.pump();
    final dynamic state = t.state(find.byType(ResourceView));
    state.chooseActivityFilter(ActivityFilterChoice.unread);
    await t.pump();
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(client.posts.where((p) => p.endsWith('/channels/inbox/done')), hasLength(1));
  });

  testWidgets('the stale-counts notice is not mounted with the load-failed banner', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Column(children: [
        activityStaleNotice(w, const Text('head'), loadFailed: true),
        activityStaleNotice(w, const Text('head2')),
      ]),
    ));
    expect(find.byType(StaleCountsNotice), findsOneWidget);
  });

  testWidgets('paging asks for the next page within two viewports of the end', (t) async {
    w.inbox = [for (var i = 0; i < 120; i++) dayRow(i)];
    await mountActivity(t, w, desktop);
    final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
    // 1500 from the end is inside two viewports (about 1700), outside 240.
    scroll.position.jumpTo(scroll.position.maxScrollExtent - 1500);
    await t.pumpAndSettle();
    expect(w.inboxQueries.length, greaterThan(1));
  });

}

class _FailingWorkspace extends ActivityWorkspace {
  _FailingWorkspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/inbox') {
      throw const RaftApiException('boom', status: 500);
    }
    return super.query(path, query: query);
  }
}
