import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show
        ActivityClient,
        ActivityWorkspace,
        activityFixture,
        channelRow,
        skeleton;

/// The Pinned scope and filtered Saved answer with their own rows.
class FilterWorkspace extends ActivityWorkspace {
  FilterWorkspace(super.client);
  final pinnedQueries = <Map<String, dynamic>>[];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/inbox' && query?['scope'] == 'pinned') {
      pinnedQueries.add({...?query});
      final gate = hold;
      if (gate != null) await gate.future;
      return {
        'items': [for (var i = 100; i < 104; i++) channelRow(i)],
        'hasMore': false,
        'totalCount': 4,
      };
    }
    if (path == '/channels/saved' && query?['q'] == 'needle') {
      savedQueries.add({...?query});
      final gate = hold;
      if (gate != null) await gate.future;
      return {
        'saved': [
          {...saved[3], 'content': 'Saved body needle'},
        ],
        'total': 1,
        'hasMore': false,
      };
    }
    return super.query(path, query: query);
  }
}

void main() {
  late ActivityClient client;
  late FilterWorkspace w;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    final (c, base) = activityFixture();
    client = c;
    w = FilterWorkspace(c)
      ..server = base.server
      ..channels = [
        ...base.channels,
        for (var i = 100; i < 104; i++)
          RaftChannel({'id': 'ch$i', 'name': 'Channel $i', 'joined': true}),
      ];
    base.dispose();
  });
  tearDown(() async {
    DevicePreferences.reset();
    w.dispose();
    await client.dispose();
  });

  Future<dynamic> mount(WidgetTester tester, String section) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: section,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(ResourceView));
  }

  testWidgets('legacy Activity switches back to a visited filter at once', (
    tester,
  ) async {
    final dynamic state = await mount(tester, 'activity');
    final allRow = find.byKey(const ValueKey('activity-channel-ch0'));
    final pinnedRow = find.byKey(const ValueKey('activity-channel-ch100'));
    final placeholders = find.byType(RaftInboxItemSkeleton);

    Future<void> selectWhileHeld(String label) async {
      await tester.tap(
        find.byKey(const ValueKey('inbox-filter-button')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      w.hold = Completer<void>();
      await tester.tap(
        find.text(label).hitTestable(),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
    }

    Future<void> finishRead() async {
      w.hold!.complete();
      w.hold = null;
      await tester.pumpAndSettle();
    }

    expect(state.rows, hasLength(50));
    expect(allRow.hitTestable(), findsOneWidget);
    final first = state.rows.first;

    // Cold Pinned starts empty and paints its placeholders after the delay.
    await selectWhileHeld('Pinned');
    expect(ActivityFilterPreference.read('s1'), ActivityFilterChoice.pinned);
    expect(w.pinnedQueries.single, containsPair('scope', 'pinned'));
    expect(state.rows, isEmpty);
    expect(allRow, findsNothing);
    expect(pinnedRow, findsNothing);
    expect(skeleton, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 999));
    expect(placeholders, findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(placeholders, findsNWidgets(10));
    await finishRead();
    expect(placeholders, findsNothing);
    expect(state.rows, hasLength(4));
    expect(pinnedRow.hitTestable(), findsOneWidget);

    // Back to All: the accepted window is on screen in the first frame.
    final requests = w.inboxQueries.length;
    await selectWhileHeld('All');
    expect(ActivityFilterPreference.read('s1'), ActivityFilterChoice.all);
    expect(skeleton, findsNothing);
    expect(allRow.hitTestable(), findsOneWidget);
    expect(pinnedRow, findsNothing);
    expect(state.rows, hasLength(50));
    expect(state.loading, isFalse);
    expect(w.inboxQueries, hasLength(requests + 1));
    expect(w.inboxQueries.last, containsPair('filter', 'all'));
    expect(w.inboxQueries.last.containsKey('scope'), isFalse);
    await finishRead();
    expect(state.rows, hasLength(50));
    expect(state.rows.first, same(first));

    // Pinned is now cached too, while its new request is still held.
    await selectWhileHeld('Pinned');
    expect(w.pinnedQueries, hasLength(2));
    expect(skeleton, findsNothing);
    expect(pinnedRow.hitTestable(), findsOneWidget);
    expect(allRow, findsNothing);
    expect(state.rows, hasLength(4));
    await finishRead();
    expect(state.rows, hasLength(4));
  });

  testWidgets('Saved keeps the unfiltered rows while a query is revalidated', (
    tester,
  ) async {
    final dynamic state = await mount(tester, 'saved');
    expect(state.rows, hasLength(30));

    state.query.text = 'needle';
    w.hold = Completer<void>();
    unawaited(state.load());
    await tester.pump();
    expect(state.rows, isEmpty, reason: 'a new query has nothing cached');
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(state.rows, hasLength(1));

    state.query.text = '';
    w.hold = Completer<void>();
    unawaited(state.load());
    await tester.pump();
    expect(skeleton, findsNothing);
    expect(state.rows, hasLength(30));
    expect(find.text('Saved body 0'), findsOneWidget);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(state.rows, hasLength(30));
  });

  testWidgets('visited filter windows survive leaving the page', (
    tester,
  ) async {
    dynamic state = await mount(tester, 'activity');
    state.filter = 'pinned';
    await state.load();
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'activity',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    state = tester.state(find.byType(ResourceView));
    // The snapshot opens on the Pinned view; the All window is kept beside it.
    expect(state.filter, 'pinned');
    state.filter = 'all';
    w.hold = Completer<void>();
    unawaited(state.load());
    await tester.pump();
    expect(skeleton, findsNothing);
    expect(state.rows, hasLength(50));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
  });
}
