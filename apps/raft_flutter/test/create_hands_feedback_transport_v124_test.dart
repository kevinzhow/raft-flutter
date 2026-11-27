import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';

import 'source_feedback_store_test.dart' as fixture;

void main() {
  testWidgets('latest reply preview survives opening and returning', (
    tester,
  ) async {
    final ticket = fixture.ticket(fixture.first)
      ..['latest_comment'] = {
        'author_type': 'staff',
        'body_preview': 'We **found** the problem.\nA fix is in progress.',
        'created_at': 3000,
      };
    final store = SourceFeedbackStore(
      authority: () => 'current',
      get: (path, {query}) async => path == '/product-feedback/tickets'
          ? fixture.page([ticket])
          : fixture.detail(fixture.first),
    );
    addTearDown(store.dispose);
    await store.loadList();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceFeedbackProjectionView(store: store)),
      ),
    );

    final preview = find.text(
      'Team: We found the problem. A fix is in progress.',
    );
    try {
      expect(preview, findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('feedback-ticket-${fixture.first}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feedback-back')));
      await tester.pumpAndSettle();
      expect(preview, findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
