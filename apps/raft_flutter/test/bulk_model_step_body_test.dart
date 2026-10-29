import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/bulk_model_step_body.dart';

/// Web StepBody: a step slides 16px in while it fades in (200ms ease-out) and
/// the shell's height follows its content; reduced motion is instant.
Widget _app(String step, double height, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: BulkModelStepBody(
            stepKey: step,
            child: SizedBox(key: ValueKey('content-$step'), height: height),
          ),
        ),
      ),
    ),
  ),
);

double _opacity(WidgetTester tester, String step) => tester
    .widget<Opacity>(
      find.ancestor(
        of: find.byKey(ValueKey('content-$step')),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

double _dx(WidgetTester tester, String step) =>
    tester.getTopLeft(find.byKey(ValueKey('content-$step'))).dx;

void main() {
  testWidgets('a new step starts 16px right and transparent, then settles', (
    tester,
  ) async {
    await tester.pumpWidget(_app('choose', 100));
    final left = tester.getTopLeft(find.byType(BulkModelStepBody)).dx;
    expect(_opacity(tester, 'choose'), 0);
    expect(_dx(tester, 'choose') - left, 16);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester, 'choose'), inExclusiveRange(0, 1));
    expect(_dx(tester, 'choose') - left, inExclusiveRange(0, 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester, 'choose'), 1);
    expect(_dx(tester, 'choose') - left, 0);

    await tester.pumpWidget(_app('review', 100));
    expect(find.byKey(const ValueKey('content-choose')), findsNothing);
    expect(_opacity(tester, 'review'), 0);
    expect(_dx(tester, 'review') - left, 16);
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'review'), 1);
  });

  testWidgets('the shell height follows the content over 200ms', (
    tester,
  ) async {
    await tester.pumpWidget(_app('choose', 100));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BulkModelStepBody)).height, 100);
    await tester.pumpWidget(_app('review', 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byType(BulkModelStepBody)).height,
      inExclusiveRange(100, 300),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BulkModelStepBody)).height, 300);
  });

  testWidgets('reduced motion shows the step at once', (tester) async {
    await tester.pumpWidget(_app('choose', 100, reduced: true));
    final left = tester.getTopLeft(find.byType(BulkModelStepBody)).dx;
    expect(_opacity(tester, 'choose'), 1);
    expect(_dx(tester, 'choose') - left, 0);
    await tester.pumpWidget(_app('review', 300, reduced: true));
    expect(_opacity(tester, 'review'), 1);
    expect(tester.getSize(find.byType(BulkModelStepBody)).height, 300);
  });
}
