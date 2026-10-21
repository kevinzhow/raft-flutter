import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web Stepper: "1 Choose model ── 2 Review"; while reviewing, step 1 is a
/// check mark.
Widget _app(bool reviewing, RaftFamily family) => MaterialApp(
  theme: raftTheme(family),
  home: Scaffold(
    body: SizedBox(
      width: 500,
      child: RaftBulkModelStepper(reviewing: reviewing),
    ),
  ),
);

void main() {
  testWidgets('choosing shows both numbers and no check', (tester) async {
    await tester.pumpWidget(_app(false, RaftFamily.elegant));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Choose model'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.byType(RaftIcon), findsNothing);
  });

  testWidgets('reviewing replaces the 1 with a check mark', (tester) async {
    await tester.pumpWidget(_app(true, RaftFamily.elegant));
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(RaftIcon), findsOneWidget);
  });

  testWidgets('brutal writes the labels in capitals', (tester) async {
    await tester.pumpWidget(_app(false, RaftFamily.brutal));
    expect(find.text('CHOOSE MODEL'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);
  });

  testWidgets('the rule fills the space between the steps', (tester) async {
    await tester.pumpWidget(_app(false, RaftFamily.elegant));
    final box = tester.getRect(
      find.byKey(const ValueKey('bulk-model-stepper')),
    );
    expect(box.width, 500);
    final first = tester.getRect(find.text('Choose model'));
    final second = tester.getRect(find.text('Review'));
    expect(second.left - first.right, greaterThan(100));
  });
}
