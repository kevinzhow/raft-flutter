import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child, {RaftFamily family = RaftFamily.elegant}) =>
    MaterialApp(
      theme: raftTheme(family),
      home: Scaffold(body: child),
    );

const _ticket = RaftFeedbackTicketRow(
  id: 't1',
  title: 'Keep the app open',
  date: 'Oct 3, 2026, 10:00 AM',
  problem: false,
  status: RaftFeedbackStatus.inProgress,
  unreadLabel: '2',
  unreadSemantics: '2 unread',
);

void main() {
  for (final family in RaftFamily.values) {
    testWidgets('$family inbox: tabs, card chips, open and filter', (t) async {
      final opened = <String>[];
      final filters = <RaftFeedbackFilter>[];
      await t.pumpWidget(
        _host(
          RaftFeedbackInbox(
            tickets: const [_ticket],
            filter: RaftFeedbackFilter.all,
            onFilter: filters.add,
            onOpen: opened.add,
          ),
          family: family,
        ),
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Idea'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('feedback-ticket-t1')));
      expect(opened, ['t1']);
      await t.tap(find.text('Ended'));
      expect(filters, [RaftFeedbackFilter.ended]);
    });
  }

  testWidgets('no tickets: no tabs, the dashed empty state', (t) async {
    await t.pumpWidget(
      _host(
        RaftFeedbackInbox(
          tickets: const [],
          filter: RaftFeedbackFilter.all,
          onFilter: (_) {},
        ),
      ),
    );
    expect(find.text('All'), findsNothing);
    expect(find.text('No feedback yet'), findsOneWidget);
  });

  testWidgets('a filter with no matches keeps the tabs and its own copy', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        RaftFeedbackInbox(
          tickets: const [],
          anyTickets: true,
          filter: RaftFeedbackFilter.ended,
          onFilter: (_) {},
        ),
      ),
    );
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Nothing ended yet'), findsOneWidget);
  });

  testWidgets('error banner retries', (t) async {
    var retried = 0;
    await t.pumpWidget(
      _host(
        RaftFeedbackInbox(
          tickets: const [],
          filter: RaftFeedbackFilter.all,
          onFilter: (_) {},
          error: "Couldn't load feedback. Try again.",
          onRetry: () => retried++,
        ),
      ),
    );
    await t.tap(find.text('Try again'));
    expect(retried, 1);
    expect(find.text('No feedback yet'), findsNothing);
  });
}
