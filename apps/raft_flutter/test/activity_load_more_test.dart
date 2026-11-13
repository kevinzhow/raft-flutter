import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

/// Activity fills a short initial viewport, then preserves that accepted
/// window through refresh and reopening. Manual error retry is exercised by
/// activity_auto_pagination_test.dart.

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() => (client, w) = activityFixture());
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<dynamic> mount(WidgetTester t) async {
    t.view.physicalSize = const Size(1000, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'activity',
            activitySidebarEnabled: false,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return t.state(find.byType(ResourceView));
  }

  testWidgets('filling the viewport appends the next page, then no button', (
    t,
  ) async {
    final dynamic state = await mount(t);
    expect(w.inboxQueries.last['offset'], 30);
    expect(state.rows, hasLength(60));
    expect(state.hasMore, isFalse);
    expect(find.text('Load more'), findsNothing);
    // A refresh of the loaded window keeps the whole list and does not bring
    // the button back.
    await state.load(keep: true);
    await t.pumpAndSettle();
    expect(state.rows, hasLength(60));
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a list of exactly one page never shows Load more', (t) async {
    w.inbox = [for (var i = 0; i < 30; i++) channelRow(i)];
    final dynamic state = await mount(t);
    expect(state.rows, hasLength(30));
    expect(state.hasMore, isFalse);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('reopening the page keeps the loaded window and no button', (
    t,
  ) async {
    final dynamic first = await mount(t);
    expect(first.rows, hasLength(60));
    await t.pumpWidget(const SizedBox());
    final dynamic second = await mount(t);
    expect(second.rows, hasLength(60));
    expect(find.text('Load more'), findsNothing);
  });
}
