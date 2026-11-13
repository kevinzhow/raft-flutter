import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';

import 'source_feedback_store_test.dart' as fixture;

/// The inbox filters the loaded pages locally. When the pages loaded so far
/// hold nothing for the chosen filter but the server has more, the user must
/// still be able to load them instead of reading "nothing here" with no way on.
/// Known failing: the empty state replaces the list, and Load more lives only
/// in the list (packages/raft_ui feedback_inbox.dart).

void main() {
  testWidgets('a filter with no loaded match still offers Load more', (t) async {
    final store = SourceFeedbackStore(
      authority: () => 'current',
      get: (_, {query}) async {
        final cursor = query?['cursor'] as String?;
        return cursor == null
            ? fixture.page([
                fixture.ticket(fixture.first, status: 'closed'),
              ], cursor: 'p2')
            : fixture.page([fixture.ticket(fixture.second)]);
      },
    );
    await store.loadList();
    store.setFilter(SourceFeedbackFilter.open);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceFeedbackProjectionView(store: store)),
      ),
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      store.dispose();
    });
    expect(find.text('Load more'), findsOneWidget);
    await t.tap(find.text('Load more'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('feedback-ticket-${fixture.second}')),
      findsOneWidget,
    );
  });
}
