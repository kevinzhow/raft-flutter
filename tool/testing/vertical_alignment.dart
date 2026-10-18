import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts that the vertical centres of every widget in [children] are the
/// same, within [tolerance] logical pixels (default 0.5, half a physical pixel
/// at 1x).
///
/// A row whose children sit at different heights is the "the banner button is
/// 2px lower than its text" class of bug. Web aligns an action group with the
/// row (`items-center` on the row, or `self-center` on the group); the check
/// compares the laid-out boxes, so it needs no screenshot.
///
/// Each finder must match exactly one widget. [reason] names the surface in the
/// failure message. A finder list such as `[find.byKey(a), find.text('Save')]`
/// reads naturally; pass the *boxes that are meant to be centred together*, not
/// a container and its own child.
void expectVerticallyCentered(
  WidgetTester tester,
  Iterable<Finder> children, {
  double tolerance = 0.5,
  String? reason,
}) {
  final rects = <String, Rect>{};
  for (final finder in children) {
    expect(
      finder,
      findsOneWidget,
      reason: '${reason ?? 'row'}: ${finder.description} must match one widget',
    );
    rects[finder.description] = tester.getRect(finder);
  }
  expect(rects.length, greaterThanOrEqualTo(2), reason: 'need two children');
  final centres = {for (final e in rects.entries) e.key: e.value.center.dy};
  final lowest = centres.values.reduce((a, b) => a < b ? a : b);
  final highest = centres.values.reduce((a, b) => a > b ? a : b);
  expect(
    highest - lowest,
    lessThanOrEqualTo(tolerance),
    reason:
        '${reason ?? 'row'}: children are not vertically centred together '
        '(spread ${(highest - lowest).toStringAsFixed(2)}px > $tolerance px):\n'
        '${[for (final e in rects.entries) '  ${e.key}: ${e.value} centre y ${e.value.center.dy}'].join('\n')}',
  );
}

/// Asserts that every child in [children] is vertically centred in [row]
/// (the container the Web `items-center` / `self-center` aligns them in),
/// within [tolerance]. Use it when the row's padding is symmetric.
void expectCenteredIn(
  WidgetTester tester,
  Finder row,
  Iterable<Finder> children, {
  double tolerance = 0.5,
  String? reason,
}) {
  expect(row, findsOneWidget, reason: '${reason ?? 'row'}: row not found');
  final rowCentre = tester.getRect(row).center.dy;
  for (final finder in children) {
    expect(
      finder,
      findsOneWidget,
      reason: '${reason ?? 'row'}: ${finder.description} must match one widget',
    );
    final centre = tester.getRect(finder).center.dy;
    expect(
      (centre - rowCentre).abs(),
      lessThanOrEqualTo(tolerance),
      reason:
          '${reason ?? 'row'}: ${finder.description} centre y $centre is '
          '${(centre - rowCentre).toStringAsFixed(2)}px from the row centre '
          '$rowCentre (tolerance $tolerance)',
    );
  }
}
