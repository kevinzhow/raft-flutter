import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

RaftThemePack _pack(double radius) => RaftThemePack.parse(
  jsonEncode({
    'format': 'raft-theme/1',
    'id': 'input-widget-test',
    'name': {'en': 'Input test'},
    'version': '1.0.0',
    'extends': 'raft',
    'modes': {
      for (final mode in ['light', 'dark'])
        mode: {
          'geometry': {'radius.control': radius, 'radius.field': 17},
        },
    },
  }),
);

void main() {
  testWidgets(
    'existing input repaints from a changed pack without losing editing state',
    (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
      });
      const retainedText = 'Retained text';
      const retainedSelection = TextSelection(baseOffset: 0, extentOffset: 8);
      var hasEdited = false;
      for (final dark in [false, true]) {
        for (final radius in [39.0, 23.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: _pack(radius), dark: dark),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 300,
                    child: RaftRecipeInput(
                      controller: controller,
                      focusNode: focus,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final field = find.byType(TextField);
          if (!hasEdited) {
            await tester.tap(field);
            await tester.enterText(field, retainedText);
            controller.selection = retainedSelection;
            await tester.pumpAndSettle();
            hasEdited = true;
          }
          // A later theme rebuild must retain state before any new input.
          expect(controller.text, retainedText);
          expect(controller.selection, retainedSelection);
          expect(focus.hasFocus, isTrue);
          final decorations = tester
              .widgetList<Container>(
                find.descendant(
                  of: find.byType(RaftRecipeInput),
                  matching: find.byType(Container),
                ),
              )
              .map((c) => c.decoration)
              .whereType<BoxDecoration>();
          expect(
            decorations.any(
              (d) => d.borderRadius == BorderRadius.circular(radius),
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
