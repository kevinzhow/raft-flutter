import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(ThemeData theme, Widget child, {bool reduced = false}) =>
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 200, child: child),
          ),
        ),
      ),
    );

/// The sweep's current (translateX px, scaleX) on a 200px track.
(double, double) sweep(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey('progress-indeterminate-sweep')),
  );
  final shift = tester
      .widget<FractionalTranslation>(
        find.byKey(const ValueKey('progress-indeterminate-shift')),
      )
      .translation
      .dx;
  // The stripe is half of the 200px track.
  return (shift * 100, transform.transform.entry(0, 0));
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'raft-progress-indeterminate: -65% x .35 to 70% x .6 to 185% x .35 of the half-width stripe (dark=$dark)',
      (tester) async {
        await tester.pumpWidget(
          host(raftTheme(dark: dark), const RaftProgressBar()),
        );
        var (x, s) = sweep(tester);
        expect(x, closeTo(-65, 1e-6), reason: '0%: translateX(-65%) of 100px');
        expect(s, closeTo(.35, 1e-6));
        await tester.pump(const Duration(milliseconds: 700));
        (x, s) = sweep(tester);
        expect(x, closeTo(70, 1e-6), reason: '50% of 1.4s');
        expect(s, closeTo(.6, 1e-6));
        await tester.pump(const Duration(milliseconds: 350));
        (x, s) = sweep(tester);
        expect(x, greaterThan(70));
        expect(x, lessThan(185));
        await tester.pump(const Duration(milliseconds: 350));
        (x, s) = sweep(tester);
        expect(x, closeTo(-65, 1e-6), reason: 'the loop restarts');
      },
    );

    testWidgets(
      'reduced motion rests the stripe at its half-width base (dark=$dark)',
      (tester) async {
        await tester.pumpWidget(
          host(raftTheme(dark: dark), const RaftProgressBar(), reduced: true),
        );
        await tester.pump(const Duration(milliseconds: 1200));
        expect(
          find.byKey(const ValueKey('progress-indeterminate-shift')),
          findsNothing,
        );
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets('a determinate bar does not sweep (dark=$dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(raftTheme(dark: dark), const RaftProgressBar(value: 40)),
      );
      expect(
        find.byKey(const ValueKey('progress-indeterminate-sweep')),
        findsNothing,
      );
    });
  }
}
