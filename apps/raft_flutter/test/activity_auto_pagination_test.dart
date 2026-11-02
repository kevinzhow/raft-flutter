import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

class PagingWorkspace extends ActivityWorkspace {
  PagingWorkspace(super.client);
  bool failAppend = false, emptyAppend = false;

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    final result = await super.query(path, query: query);
    if (path == '/channels/inbox' && (query?['offset'] as int? ?? 0) > 0) {
      if (failAppend) {
        throw const RaftApiException('Page unavailable', status: 500);
      }
      if (emptyAppend) return {'items': [], 'hasMore': true};
    }
    return result;
  }
}

void main() {
  late ActivityClient client;
  late PagingWorkspace w;
  setUp(() {
    final (baseClient, baseWorkspace) = activityFixture();
    client = baseClient;
    w = PagingWorkspace(client)
      ..server = baseWorkspace.server
      ..channels = baseWorkspace.channels;
    baseWorkspace.dispose();
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<dynamic> mount(
    WidgetTester t, {
    Size size = const Size(856, 944),
    TargetPlatform platform = TargetPlatform.android,
    ValueNotifier<bool>? activity,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final mode = activity ?? ValueNotifier(true);
    if (activity == null) addTearDown(mode.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: mode,
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: ResourceView(
              controller: w,
              section: 'activity',
              onMessage: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return t.state(find.byType(ResourceView));
  }

  Finder getList() => find.byType(ListView).last;

  Future<void> reachEnd(WidgetTester t) async {
    await t.drag(getList(), const Offset(0, -6000));
    await t.pumpAndSettle();
  }

  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('near end appends automatically on $platform $size', (t) async {
      final dynamic state = await mount(t, size: size, platform: platform);
      expect(state.rows, hasLength(30));
      await reachEnd(t);
      expect(w.inboxQueries.last['offset'], 30);
      expect(state.rows, hasLength(60));
      expect(state.hasMore, isFalse);
      expect(find.text('Load More'), findsNothing);
    });
  }

  testWidgets('an initially undersized viewport loads without a scroll', (
    t,
  ) async {
    final dynamic state = await mount(t, size: const Size(1000, 4000));
    expect(w.inboxQueries.map((q) => q['offset']), [0, 30]);
    expect(state.rows, hasLength(60));
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('repeated end gestures cannot duplicate an in-flight page', (
    t,
  ) async {
    final dynamic state = await mount(t);
    w.hold = Completer<void>();
    await t.drag(getList(), const Offset(0, -6000));
    await t.pump();
    expect(w.inboxQueries.map((q) => q['offset']), [0, 30]);
    expect(find.text('Load More'), findsOneWidget);
    await t.tap(find.text('Load More'));
    await t.pump();
    expect(w.inboxQueries, hasLength(2));
    await t.drag(getList(), const Offset(0, -50));
    await t.pump(const Duration(milliseconds: 100));
    expect(w.inboxQueries, hasLength(2));
    w.hold!.complete();
    w.hold = null;
    await t.pumpAndSettle();
    expect(state.rows, hasLength(60));
  });

  testWidgets('a background refresh does not consume the near-end attempt', (
    t,
  ) async {
    final dynamic state = await mount(t);
    final gate = w.hold = Completer<void>();
    final Future<void> refresh = state.load(keep: true);
    await t.drag(getList(), const Offset(0, -6000));
    await t.pump();
    expect(w.inboxQueries.map((q) => q['offset']), [0, 0]);
    w.hold = null;
    gate.complete();
    await refresh;
    await t.pumpAndSettle();
    expect(w.inboxQueries.map((q) => q['offset']), [0, 0, 30]);
    expect(state.rows, hasLength(60));
  });

  testWidgets('failed append stays stopped until the user retries', (t) async {
    final dynamic state = await mount(t);
    w.failAppend = true;
    await reachEnd(t);
    expect(w.inboxQueries, hasLength(2));
    expect(state.rows, hasLength(30));
    await t.drag(getList(), const Offset(0, -50));
    await t.pumpAndSettle();
    expect(w.inboxQueries, hasLength(2));
    w.failAppend = false;
    await t.ensureVisible(find.text('Load More'));
    await t.tap(find.text('Load More'));
    await t.pumpAndSettle();
    expect(state.rows, hasLength(60));
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('empty hasMore response cannot cause a layout request loop', (
    t,
  ) async {
    final dynamic state = await mount(t);
    w.emptyAppend = true;
    await reachEnd(t);
    expect(w.inboxQueries, hasLength(2));
    expect(state.rows, hasLength(30));
    for (var frame = 0; frame < 10; frame++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(w.inboxQueries, hasLength(2));
  });

  testWidgets('returning to a filter revalidates before retrying its page', (
    t,
  ) async {
    final dynamic state = await mount(t);
    w.failAppend = true;
    await reachEnd(t);
    expect(w.inboxQueries, hasLength(2));
    state.selectActivitySection('unread', state.authority);
    await t.pumpAndSettle();
    w.failAppend = false;
    state.selectActivitySection('all', state.authority);
    await t.pumpAndSettle();
    expect(state.rows, hasLength(60));
    expect(w.inboxQueries.last['offset'], 30);
  });

  testWidgets('inactive retained Activity cannot fill its viewport', (t) async {
    final activity = ValueNotifier(false);
    addTearDown(activity.dispose);
    final dynamic state = await mount(
      t,
      size: const Size(1000, 4000),
      activity: activity,
    );
    expect(w.inboxQueries, hasLength(1));
    expect(state.rows, hasLength(30));
    activity.value = true;
    await t.pumpAndSettle();
    expect(state.rows, hasLength(60));
  });

  testWidgets('a complete first page never requests another page', (t) async {
    w.inbox = [for (var i = 0; i < 30; i++) channelRow(i)];
    await mount(t, size: const Size(1000, 4000));
    await reachEnd(t);
    expect(w.inboxQueries, hasLength(1));
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('prefetch begins within 240px, before reaching the footer', (
    t,
  ) async {
    final dynamic state = await mount(t);
    final ScrollController scroll = state.listScroll;
    scroll.jumpTo(200);
    await t.pumpAndSettle();
    expect(w.inboxQueries, hasLength(1));
    expect(scroll.position.extentAfter, greaterThan(240));
    scroll.jumpTo(scroll.position.maxScrollExtent - 120);
    expect(scroll.position.extentAfter, closeTo(120, 0.1));
    await t.pumpAndSettle();
    expect(w.inboxQueries.map((q) => q['offset']), [0, 30]);
    expect(state.rows, hasLength(60));
  });

  testWidgets('grouped Activity uses the same near-end paging', (t) async {
    final dynamic state = await mount(t);
    state.advanced.groupByChannel = true;
    state.setState(() {});
    await t.pumpAndSettle();
    await reachEnd(t);
    expect(w.inboxQueries.map((q) => q['offset']), [0, 30]);
    expect(state.rows, hasLength(60));
  });

  testWidgets('switching filter retires an in-flight old page and controller', (
    t,
  ) async {
    final dynamic state = await mount(t);
    final ScrollController oldScroll = state.listScroll;
    final gate = w.hold = Completer<void>();
    await t.drag(getList(), const Offset(0, -6000));
    await t.pump();
    expect(w.inboxQueries.map((q) => q['offset']), [0, 30]);
    state.selectActivitySection('unread', state.authority);
    await t.pump();
    expect(w.inboxQueries.last['offset'], 0);
    expect(w.inboxQueries.last['filter'], 'unread');
    gate.complete();
    w.hold = null;
    await t.pumpAndSettle();
    expect(state.rows, hasLength(30));
    expect(state.listScroll, isNot(same(oldScroll)));
    final count = w.inboxQueries.length;
    if (oldScroll.hasClients) {
      oldScroll.jumpTo(oldScroll.position.minScrollExtent);
    }
    await t.pumpAndSettle();
    expect(w.inboxQueries, hasLength(count));
    await reachEnd(t);
    expect(w.inboxQueries.last['filter'], 'unread');
    expect(w.inboxQueries.last['offset'], 30);
    expect(state.rows, hasLength(60));
  });
}
