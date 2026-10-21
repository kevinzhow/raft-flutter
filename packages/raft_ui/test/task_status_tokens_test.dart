import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Every task-status surface reads the one `task-status-*` token family: the
/// status pill, the status editor trigger, the history markers and the from/to
/// badges of a status change. Web v1.21.12: `StatusBadge` is raft-ui's
/// `TaskStatusBadge` (icon + label), `TimelineItem taskStatus` paints the dot.
const _statuses = [
  ('todo', RaftMessageTaskStatus.todo, 'Todo'),
  ('in_progress', RaftMessageTaskStatus.inProgress, 'In Progress'),
  ('in_review', RaftMessageTaskStatus.inReview, 'In Review'),
  ('done', RaftMessageTaskStatus.done, 'Done'),
  ('closed', RaftMessageTaskStatus.closed, 'Closed'),
];

RaftTokens _tokens(WidgetTester tester) =>
    RaftTokens.of(tester.element(find.byType(Scaffold)));

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    );

/// The pill painted around [label]: the nearest decorated box above it.
BoxDecoration _pillOf(WidgetTester tester, Finder badge) {
  final box = find
      .descendant(of: badge, matching: find.byType(Container))
      .evaluate()
      .map((e) => e.widget as Container)
      .firstWhere(
        (c) => c.decoration is BoxDecoration && c.constraints != null,
      );
  return box.decoration! as BoxDecoration;
}

Widget _surface({
  required List<Map<String, dynamic>> history,
  String status = 'in_progress',
}) => SizedBox(
  width: 480,
  height: 700,
  child: RaftTaskSurface(
    task: {
      'id': 't1',
      'taskNumber': 8,
      'channelName': 'general',
      'title': 'Review the release',
      'status': status,
      'createdByName': 'Alice',
    },
    history: history,
    assignees: const [],
    legacy: false,
    loading: false,
    historyLoading: false,
    busy: false,
    canStatus: true,
    canAssign: false,
    canCleanupDelete: false,
    statusOptions: raftTaskStatuses,
    onClose: () {},
    onRetry: () async {},
    onLoadAssignees: () async {},
    onUpdate: (field, value) async {},
    formatTime: (_) => 'Oct 10, 2026, 09:00',
  ),
);

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    final theme = raftTheme(family, dark: dark);
    for (final (id, status, label) in _statuses) {
      testWidgets('$family/$dark $id pill is a TaskStatusBadge on the tokens', (
        tester,
      ) async {
        await _pump(tester, theme, RaftTaskStatus(status: id));
        final t = _tokens(tester);
        final token = RaftMessageTaskChipRecipe.tokenOf(status);
        final badge = find.byType(RaftTaskStatusBadge);
        expect(badge, findsOneWidget);
        expect(find.text(label), findsOneWidget);
        expect(
          find.descendant(
            of: badge,
            matching: find.byWidgetPredicate(
              (w) => w is RaftMessageTaskStatusIcon && w.status == status,
            ),
          ),
          findsOneWidget,
        );
        final decoration = _pillOf(tester, badge);
        expect(decoration.color, t.colors[t.brutal ? token : '$token-soft']);
        final side = (decoration.border! as Border).top;
        expect(
          side.color,
          t.brutal
              ? Colors.black
              : t.colors['$token-strong']!.withValues(
                  alpha: t.colors['$token-strong']!.a * .35,
                ),
        );
      });

      testWidgets(
        '$family/$dark $id editor trigger shows icon, label, pencil',
        (tester) async {
          await _pump(
            tester,
            theme,
            RaftTaskStatusEditor(
              status: id,
              options: raftTaskStatuses,
              onSelect: (_) {},
            ),
          );
          final badge = find.byType(RaftTaskStatusBadge);
          expect(badge, findsOneWidget);
          expect(tester.widget<RaftTaskStatusBadge>(badge).status, status);
          expect(find.text(label), findsOneWidget);
          expect(
            find.descendant(
              of: badge,
              matching: find.byType(RaftBadgeEditPencil),
            ),
            findsOneWidget,
          );
          final t = _tokens(tester);
          final token = RaftMessageTaskChipRecipe.tokenOf(status);
          expect(
            _pillOf(tester, badge).color,
            t.colors[t.brutal ? token : '$token-soft'],
          );
        },
      );
    }

    testWidgets('$family/$dark history markers use the task-status tokens', (
      tester,
    ) async {
      await _pump(
        tester,
        theme,
        _surface(
          history: const [
            {
              'eventType': 'created',
              'payload': {'status': 'todo'},
            },
            {'eventType': 'closed', 'payload': {}},
            {'eventType': 'reopened', 'payload': {}},
            {
              'eventType': 'status_changed',
              'payload': {'from': 'in_progress', 'to': 'done'},
            },
            {'eventType': 'assignee_changed', 'payload': {}},
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('task-properties-history')));
      await tester.pump();
      final t = _tokens(tester);
      Color token(RaftMessageTaskStatus s) =>
          t.colors[RaftMessageTaskChipRecipe.tokenOf(s)]!;
      final markers = find
          .descendant(
            of: find.byKey(const ValueKey('timeline')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).shape == BoxShape.circle,
            ),
          )
          .evaluate()
          .map((e) => (e.widget as Container).decoration! as BoxDecoration)
          .toList();
      expect(markers, hasLength(5));
      // Brutal fills the dot with the status token; elegant draws a hollow dot
      // ringed in it. Both read the same token.
      Color paint(BoxDecoration d) =>
          t.brutal ? d.color! : (d.border! as Border).top.color;
      expect(paint(markers[0]), token(RaftMessageTaskStatus.todo));
      // A closed event is `closed` (it used to be the neutral marker), a
      // reopened one `in_progress`.
      expect(paint(markers[1]), token(RaftMessageTaskStatus.closed));
      expect(paint(markers[2]), token(RaftMessageTaskStatus.inProgress));
      expect(paint(markers[3]), token(RaftMessageTaskStatus.done));
      // No status in the event: the neutral marker.
      expect(
        paint(markers[4]),
        t.colors[t.brutal ? 'layer-panel' : 'foreground-hint'],
      );
      // The from/to pair of a status change is two status badges.
      final badges = find.descendant(
        of: find.byKey(const ValueKey('timeline')),
        matching: find.byType(RaftTaskStatusBadge),
      );
      expect(
        [
          for (final b in badges.evaluate())
            (b.widget as RaftTaskStatusBadge).status,
        ],
        [RaftMessageTaskStatus.inProgress, RaftMessageTaskStatus.done],
      );
    });
  }
}
