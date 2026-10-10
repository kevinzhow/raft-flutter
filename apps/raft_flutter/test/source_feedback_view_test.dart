import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'source_feedback_store_test.dart' as fixture;

void main() {
  testWidgets(
    'inbox uses updated milliseconds/date-year-time, first-line title/aria and unread zero badge',
    (tester) async {
      final created = DateTime(2026, 10, 7, 1, 2),
          updated = DateTime(2026, 10, 8, 15, 42);
      final raw = fixture.ticket(fixture.first)
        ..['message'] = 'First line 中文\nSecond line 日本語'
        ..['created_at'] = created.millisecondsSinceEpoch
        ..['updated_at'] = updated.millisecondsSinceEpoch
        ..['unread_count'] = 0;
      final store = SourceFeedbackStore(
        authority: () => 'current',
        get: (_, {query}) async => fixture.page([raw]),
      );
      await store.loadList();
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SourceFeedbackProjectionView(store: store)),
          ),
        );
        String format(DateTime value) =>
            '${DateFormat.yMMMd('en').format(value)}, '
            '${DateFormat.jm('en').format(value)}';
        expect(find.text(format(updated)), findsOneWidget);
        expect(find.text(format(created)), findsNothing);
        expect(find.text('First line 中文'), findsOneWidget);
        expect(find.text('First line 中文\nSecond line 日本語'), findsNothing);
        final card = tester.widget<RaftFeedbackTicketCard>(
          find.byKey(const ValueKey('feedback-ticket-${fixture.first}')),
        );
        expect(card.ticket.title, 'First line 中文');
        expect(find.bySemanticsLabel('First line 中文'), findsOneWidget);
        expect(find.bySemanticsLabel('1 unread'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
        store.dispose();
      }
    },
  );
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark real ticket action opens GET replies and back preserves inbox',
      (tester) async {
        final counts = <int>[];
        final store = SourceFeedbackStore(
          authority: () => 'current',
          onUnreadChanged: counts.add,
          get: (path, {query}) async => path == '/product-feedback/tickets'
              ? fixture.page([fixture.ticket(fixture.first)])
              : fixture.detail(
                  fixture.first,
                  comments: [fixture.reply('reply', 3000, body: '团队回复 中文 日本語')],
                ),
        );
        await store.loadList();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: SourceFeedbackProjectionView(store: store)),
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('feedback-ticket-${fixture.first}')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Feedback ticket'), findsOneWidget);
        expect(find.text('团队回复 中文 日本語'), findsOneWidget);
        expect(counts, [2, 0]);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('feedback-inbox')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('feedback-comment-reply')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }

  testWidgets(
    '503-equivalent is visible retry error, not an empty feedback inbox',
    (tester) async {
      var calls = 0;
      final store = SourceFeedbackStore(
        authority: () => 'current',
        get: (_, {query}) async {
          if (++calls == 1) {
            throw const SourceFeedbackFailure(SourceFeedbackError.unavailable);
          }
          return fixture.page([]);
        },
      );
      await store.loadList();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SourceFeedbackProjectionView(store: store)),
        ),
      );
      expect(find.text("Couldn't load feedback. Try again."), findsOneWidget);
      expect(find.byKey(const Key('feedback-empty')), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No feedback yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'authority listener removes private body before delayed detail settles',
    (tester) async {
      String? scope = 'alice';
      final pending = Completer<dynamic>();
      final store = SourceFeedbackStore(
        authority: () => scope,
        get: (_, {query}) => pending.future,
      );
      final loading = store.openTicket(fixture.first);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SourceFeedbackProjectionView(store: store)),
        ),
      );
      scope = null;
      store.syncAuthority();
      await tester.pump();
      pending.complete(
        fixture.detail(
          fixture.first,
          comments: [fixture.reply('private', 3000)],
        ),
      );
      await loading;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('feedback-comment-private')),
        findsNothing,
      );
      expect(
        find.text(
          'Your feedback session expired. Reopen feedback and try again.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
