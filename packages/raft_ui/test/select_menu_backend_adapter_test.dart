import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/select.g.dart';
import 'package:raft_ui/test_themes.dart';

const _items = [
  RaftSelectItem(
    value: 11,
    label: 'Alpha',
    cssText: true,
    labelKey: ValueKey('alpha-label'),
  ),
  RaftSelectItem(value: 22, label: 'Disabled', enabled: false),
  RaftSelectItem(value: 33, label: 'Gamma'),
];

Future<void> _host(
  WidgetTester tester,
  bool dark,
  Widget child, {
  RaftThemePack? pack,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(
        dark: dark,
        pack: pack,
      ).copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 240, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(RaftSelectField<int>));
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Select routes typed choices and generated slots through the shared backend dark=$dark',
      (tester) async {
        final calls = <int?>[];
        await _host(
          tester,
          dark,
          RaftSelectField<int>(value: 11, items: _items, onChanged: calls.add),
        );
        await _open(tester);
        final popup = find.byType(RaftMenuPopupBackend);
        expect(popup, findsOneWidget);
        final backend = tester.widget<RaftMenuPopupBackend>(popup);
        expect(backend.entries.map((e) => e.label), [
          'Alpha',
          'Disabled',
          'Gamma',
        ]);
        expect(backend.entries[0].labelChild, isA<RaftCssText>());
        expect(
          backend.entries[0].labelChild!.key,
          const ValueKey('alpha-label'),
        );
        expect(backend.entries[1].enabled, isFalse);
        expect(backend.selectionSemantics, isTrue);
        expect(backend.semanticRole, SemanticsRole.list);
        final t = RaftTokens.of(tester.element(popup));
        final surface = backend.resolveSlots(
          const RaftMenuPopupRowState(index: -1),
        );
        final expected = RaftSelectRecipe.resolve(
          theme: t.recipeTheme,
          tokens: t.recipeTokens,
          states: t.recipeStates(),
        );
        expect(surface.content.classes, expected.content.classes);
        expect(surface.list.classes, expected.list.classes);
        final state = backend.resolveSlots(
          const RaftMenuPopupRowState(
            index: 1,
            disabled: true,
            lastChild: true,
          ),
        );
        final disabled = RaftSelectRecipe.resolve(
          theme: t.recipeTheme,
          tokens: t.recipeTokens,
          states: t.recipeStates(extra: ['data-disabled', 'last-child']),
        );
        expect(
          state.item.properties.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
          disabled.item.properties.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
        );
        expect(state.itemText!.classes, disabled.itemText.classes);
        expect(state.itemLeading!.classes, disabled.itemLeading.classes);
        final check = tester.widget<RaftIcon>(
          find.descendant(
            of: popup,
            matching: find.byWidgetPredicate(
              (w) => w is RaftIcon && w.glyph == RaftGlyph.check,
            ),
          ),
        );
        expect(check.size, expected.itemIndicator.target('& > svg')!.width);
        await tester.tap(find.text('Disabled'));
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        await tester.tap(find.text('Gamma'));
        await tester.pumpAndSettle();
        expect(calls, [33]);
        expect(popup, findsNothing);
      },
    );

    testWidgets(
      'Select keyboard skips disabled entries and restores trigger focus dark=$dark',
      (tester) async {
        final calls = <int?>[];
        await _host(
          tester,
          dark,
          RaftSelectField<int>(value: 11, items: _items, onChanged: calls.add),
        );
        await _open(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, [33]);
        expect(find.byKey(const ValueKey('raft-select-popup')), findsNothing);
        final trigger = tester.widget<RaftInteractive>(
          find.descendant(
            of: find.byType(RaftSelectField<int>),
            matching: find.byType(RaftInteractive),
          ),
        );
        expect(trigger.focusNode!.hasFocus, isTrue);
        await _open(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(calls, [33, 11]);
      },
    );

    testWidgets(
      'Select unmatched values select an enabled row and all-disabled choices escape dark=$dark',
      (tester) async {
        final calls = <int?>[];
        await _host(
          tester,
          dark,
          RaftSelectField<int>(
            value: 99,
            unmatchedLabel: 'Missing',
            items: _items,
            onChanged: calls.add,
          ),
        );
        expect(find.text('Missing'), findsOneWidget);
        await _open(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, [11]);
        await _host(
          tester,
          dark,
          RaftSelectField<int>(
            value: null,
            items: const [
              RaftSelectItem(value: 1, label: 'Unavailable', enabled: false),
            ],
            onChanged: calls.add,
          ),
        );
        await _open(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(calls, [11]);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('raft-select-popup')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final pack in [builtInElegantTheme, builtInBrutalTheme]) {
    testWidgets('Frozen ${pack.id} keeps its existing popup implementation', (
      tester,
    ) async {
      final calls = <int?>[];
      await _host(
        tester,
        false,
        RaftSelectField<int>(value: 11, items: _items, onChanged: calls.add),
        pack: pack,
      );
      await _open(tester);
      expect(find.byType(RaftMenuPopupBackend), findsNothing);
      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();
      expect(calls, [33]);
    });
  }
}
