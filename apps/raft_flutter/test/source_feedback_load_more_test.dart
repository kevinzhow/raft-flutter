import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';

import 'source_feedback_store_test.dart' as fixture;

/// The feedback inbox's "Load More": tapping it appends the next page, and it
/// is gone once the last page is in.

const _third = '33333333-3333-4333-8333-333333333333';

Future<SourceFeedbackStore> _mount(
  WidgetTester t,
  List<Map<String, dynamic>> Function(String? cursor) pages,
  String? Function(String? cursor) next,
) async {
  final store = SourceFeedbackStore(
    authority: () => 'current',
    get: (_, {query}) async {
      final cursor = query?['cursor'] as String?;
      return fixture.page(pages(cursor), cursor: next(cursor));
    },
  );
  await store.loadList();
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SourceFeedbackProjectionView(store: store)),
    ),
  );
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    store.dispose();
  });
  return store;
}

void main() {
  testWidgets('Load more appends the next page and then goes away', (t) async {
    await _mount(
      t,
      (cursor) => switch (cursor) {
        null => [fixture.ticket(fixture.first)],
        _ => [fixture.ticket(fixture.second), fixture.ticket(_third)],
      },
      (cursor) => cursor == null ? 'p2' : null,
    );
    expect(find.text('Load More'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('feedback-ticket-${fixture.second}')),
      findsNothing,
    );
    await t.tap(find.text('Load More'));
    await t.pumpAndSettle();
    for (final id in [fixture.first, fixture.second, _third]) {
      expect(find.byKey(ValueKey('feedback-ticket-$id')), findsOneWidget);
    }
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('a single page never offers Load more', (t) async {
    await _mount(t, (_) => [fixture.ticket(fixture.first)], (_) => null);
    expect(find.text('Load More'), findsNothing);
  });
}
