import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

/// The Activity list's "Load More": a real tap fetches the next page, the rows
/// are appended, and the button is gone at the end of the data. A list that
/// fits in one page never shows it.

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

  testWidgets('tapping Load more appends the next page, then no button', (
    t,
  ) async {
    final dynamic state = await mount(t);
    expect(state.rows, hasLength(30));
    expect(find.text('Load More'), findsOneWidget);
    await t.tap(find.text('Load More'));
    await t.pumpAndSettle();
    expect(w.inboxQueries.last['offset'], 30);
    expect(state.rows, hasLength(60));
    expect(state.hasMore, isFalse);
    expect(find.text('Load More'), findsNothing);
    // A refresh of the loaded window keeps the whole list and does not bring
    // the button back.
    await state.load(keep: true);
    await t.pumpAndSettle();
    expect(state.rows, hasLength(60));
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('a list of exactly one page never shows Load more', (t) async {
    w.inbox = [for (var i = 0; i < 30; i++) channelRow(i)];
    final dynamic state = await mount(t);
    expect(state.rows, hasLength(30));
    expect(state.hasMore, isFalse);
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('reopening the page keeps the loaded window and no button', (
    t,
  ) async {
    final dynamic first = await mount(t);
    await t.tap(find.text('Load More'));
    await t.pumpAndSettle();
    expect(first.rows, hasLength(60));
    await t.pumpWidget(const SizedBox());
    final dynamic second = await mount(t);
    expect(second.rows, hasLength(60));
    expect(find.text('Load More'), findsNothing);
  });
}
