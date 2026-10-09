import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import 'control_transition_paint_test.dart' show pixel;

void main() {
  testWidgets('product radius override also changes inset shadow geometry', (
    tester,
  ) async {
    final theme = raftTheme(RaftFamily.elegant, dark: true);
    final tokens = theme.extension<RaftTokens>()!;
    final style = RaftSlotStyle(
      {
        'background-color': const CssColor(0xff000000),
        for (final corner in [
          'top-left',
          'top-right',
          'bottom-left',
          'bottom-right',
        ])
          'border-$corner-radius': const CssNum(20, 'px'),
        'box-shadow': const CssSeq([
          CssKeyword('inset'),
          CssNum(0, 'px'),
          CssNum(4, 'px'),
          CssNum(0, 'px'),
          CssNum(0, 'px'),
          CssColor(0xffffffff),
        ]),
      },
      const {},
      const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: const ValueKey('paint'),
            child: RaftRecipeBox(
              style: style,
              tokens: tokens.recipeTokens,
              width: 80,
              height: 40,
              decorationOverride: (decoration) =>
                  decoration.copyWith(borderRadius: BorderRadius.zero),
              child: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // A square CSS padding box has the same straight inset top-light at its
    // corner and center. Keeping the recipe's 20px radius drops the corner.
    expect(await pixel(tester, const Offset(1, 1)), Colors.white);
    expect(await pixel(tester, const Offset(40, 1)), Colors.white);
    expect(await pixel(tester, const Offset(40, 20)), Colors.black);
    expect(tester.takeException(), isNull);
  });
}
