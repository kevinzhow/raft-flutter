import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

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
          await tester.tap(field);
          await tester.enterText(field, 'Retained text');
          await tester.pumpAndSettle();
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
          expect(controller.text, 'Retained text');
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('all legacy Input declarations remain source exact in both modes', () {
    for (final pack in [builtInElegantTheme, builtInBrutalTheme]) {
      for (final dark in [false, true]) {
        final t = RaftTokens.theme(pack: pack, dark: dark);
        for (final flags in [
          <String>{},
          {'hover'},
          {'focus', 'focus-visible'},
          {'disabled'},
        ]) {
          final states = RaftRecipeStates({...flags, if (dark) 'dark'});
          final source = RaftInputRecipe.resolve(
            theme: raftRecipeTheme(t),
            states: states,
            tokens: t.recipeSourceTokens,
          ).root;
          final bound = RaftInputRecipe.resolve(
            theme: raftRecipeTheme(t),
            states: states,
            tokens: t.recipeTokens,
          ).root;
          Map<String, Object?> values(RaftSlotStyle s) => {
            'self': {
              for (final e in s.properties.entries)
                if (!e.key.startsWith('border-') || !e.key.endsWith('-radius'))
                  e.key: e.value.toJson(),
            },
            'targets': {
              for (final target in s.targets.entries)
                target.key: {
                  for (final e in target.value.entries) e.key: e.value.toJson(),
                },
            },
          };
          expect(
            bound.borderRadius ?? BorderRadius.zero,
            source.borderRadius ?? BorderRadius.zero,
            reason: 'zero radius may be omitted in source CSS',
          );
          expect(
            values(bound),
            values(source),
            reason: '${pack.id} dark=$dark $flags',
          );
        }
      }
    }
  });
}
