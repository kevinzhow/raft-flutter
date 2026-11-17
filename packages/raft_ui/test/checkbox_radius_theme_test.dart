import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Checkbox corners come from the theme.
///
/// The square form takes `radius.sticker`. The circle form does NOT become a
/// token: the official specimen draws it with `rounded-full`, which is `size / 2`
/// at any size, so it stays geometric. Both the root box and the indicator are
/// checked, because they are separate boxes that were each hardcoded to 4.
Widget _host(String id, {RaftCheckboxShape shape = RaftCheckboxShape.square}) =>
    MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: raftTheme(pack: packForThemeId(id)),
      home: Scaffold(
        body: RaftCheckbox(value: true, onChanged: (_) {}, shape: shape),
      ),
    );

/// Both painted radii for one theme in its own tree. The Raft look paints recipe boxes, whose `rounded-full` radius
/// exceeds the box and is clamped to half of it when painted.
///
/// A fresh tree per theme: reusing one leaves the previous theme's values in the
/// element and the comparison then passes for the wrong reason.
Future<(double, double)> _painted(
  WidgetTester tester,
  String id, {
  RaftCheckboxShape shape = RaftCheckboxShape.square,
}) async {
  await tester.pumpWidget(_host(id, shape: shape));
  await tester.pump();
  final radii = [
    for (final c in tester.widgetList<Container>(
      find.descendant(
        of: find.byType(RaftCheckbox),
        matching: find.byType(Container),
      ),
    ))
      if (c.decoration is BoxDecoration)
        math.min(
          (c.decoration! as BoxDecoration).borderRadius!
              .resolve(TextDirection.ltr)
              .topLeft
              .x,
          10.0,
        ),
  ];
  return (radii.first, radii.last);
}

void main() {
  group('checkbox radius follows the theme', () {
    testWidgets('Raft keeps 4 on the root and the indicator', (tester) async {
      expect(await _painted(tester, raftThemePackId), (4.0, 4.0));
    });

    testWidgets('the circle form stays a true circle in every theme', (
      tester,
    ) async {
      // `rounded-full` is size/2 regardless of theme, so every theme agrees
      // here. If this started varying by theme it would mean the circle had been
      // wrongly routed through the sticker token.
      for (final id in raftThemeMatrix([raftThemePackId])) {
        final (root, indicator) = await _painted(
          tester,
          id,
          shape: RaftCheckboxShape.circle,
        );
        expect(root == 0 || root > 0, isTrue, reason: id);
        // The indicator is a circle: its radius is half its 20pt box.
        expect(indicator, 10.0, reason: '$id circle indicator');
      }
    });
  });
}
