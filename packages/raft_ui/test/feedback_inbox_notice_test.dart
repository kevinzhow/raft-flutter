import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: child),
);

const _ticket = RaftFeedbackTicketRow(
  id: 't1',
  title: 'Crash on open',
  date: 'Oct 8, 2026',
  problem: true,
  status: RaftFeedbackStatus.open,
);

const _hint =
    'Did you know? Any agent can draft your feedback. Just ask, and you’ll review it before it’s sent.';

RaftFeedbackInbox _inbox({
  bool degraded = false,
  bool showAgentHint = true,
  List<RaftFeedbackTicketRow> tickets = const [_ticket],
  bool loading = false,
}) => RaftFeedbackInbox(
  tickets: tickets,
  filter: RaftFeedbackFilter.all,
  onFilter: (_) {},
  loading: loading,
  notice: RaftFeedbackInboxNotice(
    degraded: degraded,
    showAgentHint: showAgentHint,
  ),
);

void main() {
  testWidgets('the agent hint sits above the rows, with a bold lead', (
    t,
  ) async {
    await t.pumpWidget(_host(_inbox()));
    final hint = find.byKey(const ValueKey('settings-feedback-agent-hint'));
    expect(hint, findsOneWidget);
    expect(
      find.textContaining('Any agent can draft your feedback'),
      findsOneWidget,
    );
    expect(
      t.getBottomLeft(hint).dy,
      lessThanOrEqualTo(
        t.getTopLeft(find.byKey(const ValueKey('feedback-ticket-t1'))).dy,
      ),
    );
    final text = t.widget<Text>(
      find.descendant(of: hint, matching: find.byType(Text)).first,
    );
    final lead = (text.textSpan! as TextSpan).children!.first as TextSpan;
    expect(lead.text, 'Did you know?');
    expect(lead.style?.fontWeight, FontWeight.w700);
    expect(text.textSpan!.toPlainText(), _hint);
  });

  testWidgets('a degraded list shows the warning instead of the hint', (
    t,
  ) async {
    await t.pumpWidget(_host(_inbox(degraded: true, loading: true)));
    expect(
      find.byKey(const ValueKey('settings-feedback-list-degraded')),
      findsOneWidget,
    );
    expect(
      find.text("Feedback can't load right now. Retrying…"),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-feedback-agent-hint')),
      findsNothing,
    );
    // The list stays loading under it: never the "No feedback yet" state.
    expect(find.text('No feedback yet'), findsNothing);
  });

  testWidgets('the hint is gone once an agent draft was sent', (t) async {
    await t.pumpWidget(_host(_inbox(showAgentHint: false)));
    expect(
      find.byKey(const ValueKey('settings-feedback-agent-hint')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('feedback-ticket-t1')), findsOneWidget);
  });

  testWidgets('the hint also leads the empty state', (t) async {
    await t.pumpWidget(_host(_inbox(tickets: const [])));
    final hint = find.byKey(const ValueKey('settings-feedback-agent-hint'));
    expect(hint, findsOneWidget);
    expect(find.text('No feedback yet'), findsOneWidget);
    expect(
      t.getBottomLeft(hint).dy,
      lessThanOrEqualTo(t.getTopLeft(find.text('No feedback yet')).dy),
    );
  });

  testWidgets('no notice, no inset: the first row keeps its place', (t) async {
    await t.pumpWidget(
      _host(
        RaftFeedbackInbox(
          tickets: const [_ticket],
          filter: RaftFeedbackFilter.all,
          onFilter: (_) {},
        ),
      ),
    );
    final bare = t.getTopLeft(find.byKey(const ValueKey('feedback-ticket-t1')));
    await t.pumpWidget(_host(_inbox()));
    expect(
      t.getTopLeft(find.byKey(const ValueKey('feedback-ticket-t1'))).dy,
      greaterThan(bare.dy),
    );
  });
}
