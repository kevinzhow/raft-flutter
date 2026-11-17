import 'dart:async';

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
        channelRow,
        skeleton;

/// The Pinned scope and filtered Saved answer with their own rows.
class FilterWorkspace extends ActivityWorkspace {
  FilterWorkspace(super.client);
  final doneQueries = <Map<String, dynamic>>[];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/inbox' && query?['scope'] == 'pinned') {
      doneQueries.add({...?query});
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
  setUp(() {
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
    expect(state.rows, hasLength(50));
    final first = state.rows.first;

    // Cold Pinned: nothing to show yet, so the skeleton is right.
    state.filter = 'pinned';
    w.hold = Completer<void>();
    unawaited(state.load());
    await tester.pump();
    expect(state.rows, isEmpty);
    expect(skeleton, findsOneWidget);
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(state.rows, hasLength(4));

    // Back to All: the accepted window is on screen in the first frame.
    state.filter = 'all';
    w.hold = Completer<void>();
    final requests = w.inboxQueries.length;
    unawaited(state.load());
    await tester.pump();
    expect(skeleton, findsNothing);
    expect(state.rows, hasLength(50));
    expect(state.loading, isFalse);
    expect(w.inboxQueries, hasLength(requests + 1));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
    expect(state.rows, hasLength(50));
    expect(identical(state.rows.first, first), isTrue);

    // And Pinned again, without a second skeleton.
    state.filter = 'pinned';
    w.hold = Completer<void>();
    unawaited(state.load());
    await tester.pump();
    expect(skeleton, findsNothing);
    expect(state.rows, hasLength(4));
    w.hold!.complete();
    w.hold = null;
    await tester.pumpAndSettle();
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
