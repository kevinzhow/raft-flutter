import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/selection_popover_previews.dart';

Future<void> loadFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final name in ['HankenGrotesk', 'Inter', 'GeistMono']) {
    ByteData bytes;
    try {
      bytes = await rootBundle.load('packages/raft_ui/assets/fonts/$name.ttf');
    } on FlutterError {
      bytes = await rootBundle.load('assets/fonts/$name.ttf');
    }
    await (FontLoader(
      'packages/raft_ui/$name',
    )..addFont(Future.value(bytes))).load();
  }
});
Widget host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: DefaultTextStyle(
      // Actual caller <main class="font-display">, 16px/24px.
      style: TextStyle(
        fontFamily: theme.extension<RaftTokens>()!.headingFont,
        fontSize: 16,
        height: 1.5,
      ),
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark Source default and caller retain distinct surface and actual inline-input geometry',
      (tester) async {
        await loadFonts(tester);
        final theme = raftTheme(family, dark: dark),
            controller = TextEditingController(text: 'des');
        final tokens = theme.extension<RaftTokens>()!;
        Widget popup(bool caller) => host(
          theme,
          RaftSelectionPopover(
            title: 'Channels',
            width: 310,
            searchController: controller,
            onClear: () {},
            surfaceStyle: caller ? selectionPopoverCallerSurface(tokens) : null,
            options: List.generate(
              4,
              (i) => RaftSelectionOption(
                label: 'option $i',
                checked: i == 0,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpWidget(popup(false));
        await tester.pump();
        final original = tester.widget<RaftRecipeBox>(
          find.byType(RaftRecipeBox).first,
        );
        expect(original.style.minWidth, 220);
        expect(
          original.style.backgroundColor!.resolve(tokens.recipeTokens),
          family == RaftFamily.brutal
              ? Colors.white
              : tokens.semantic.layerPanel,
        );
        expect(
          original.style.borderWidth,
          EdgeInsets.all(family == RaftFamily.brutal ? 2 : 1),
        );
        expect(
          original.style.border(tokens.recipeTokens)!.top.color,
          dark
              ? Colors.transparent
              : family == RaftFamily.brutal
              ? Colors.black
              : tokens.semantic.lineMuted,
        );
        expect(
          original.style.borderRadius ?? BorderRadius.zero,
          BorderRadius.circular(family == RaftFamily.brutal ? 0 : 8),
        );
        expect(
          tester.getSize(find.byType(RaftSelectionPopover)),
          Size(310, family == RaftFamily.brutal ? 225 : 222),
        );
        final state = tester.state(find.byType(EditableText));
        await tester.pumpWidget(popup(true));
        await tester.pump();
        expect(tester.state(find.byType(EditableText)), same(state));
        final box = tester.widget<RaftRecipeBox>(
          find.byType(RaftRecipeBox).first,
        );
        expect(
          box.style.backgroundColor!.resolve(tokens.recipeTokens),
          Colors.white,
        );
        expect(box.style.borderWidth, const EdgeInsets.all(2));
        expect(
          box.style.border(tokens.recipeTokens)!.top.color,
          dark ? Colors.transparent : Colors.black,
        );
        expect(
          box.style.classes,
          contains(
            family == RaftFamily.brutal ? 'shadow-raft-md' : 'shadow-raft-xs',
          ),
        );
        expect(
          tester.getSize(find.byType(RaftSelectionPopover)),
          Size(310, family == RaftFamily.brutal ? 225 : 224),
        );
        expect(
          tester.getTopLeft(find.byType(RaftTextInput)) -
              tester.getTopLeft(find.byType(RaftSelectionPopover)),
          Offset(10, family == RaftFamily.brutal ? 42 : 43),
        );
        expect(
          tester.getSize(find.byType(RaftTextInput)).height,
          family == RaftFamily.brutal ? 28 : 26,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
    testWidgets(
      '$family/$dark popup search autofocus and Tab leave its last option',
      (tester) async {
        await loadFonts(tester);
        final controller = TextEditingController();
        var after = 0;
        await tester.pumpWidget(
          host(
            raftTheme(family, dark: dark),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftSelectionPopover(
                  title: 'Channels',
                  width: 310,
                  searchController: controller,
                  options: [
                    RaftSelectionOption(
                      label: 'last option',
                      checked: false,
                      onTap: () {},
                    ),
                  ],
                ),
                RaftButton(label: 'After popup', onPressed: () => after++),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          true,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(after, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
    testWidgets(
      '$family/$dark live popup retains focus IME selection and hit coordinates across caller and theme',
      (tester) async {
        await loadFonts(tester);
        final controller = TextEditingController(), focus = FocusNode();
        var selected = 0;
        Widget popup(RaftFamily next, bool nextDark, bool caller) {
          final theme = raftTheme(next, dark: nextDark);
          return host(
            theme,
            RaftSelectionPopover(
              title: 'Channels',
              width: 310,
              searchController: controller,
              searchFocusNode: focus,
              surfaceStyle: caller
                  ? selectionPopoverCallerSurface(
                      theme.extension<RaftTokens>()!,
                    )
                  : null,
              options: [
                RaftSelectionOption(
                  label: 'design',
                  checked: false,
                  onTap: () => selected++,
                ),
              ],
            ),
          );
        }

        await tester.pumpWidget(popup(family, dark, false));
        await tester.pump();
        await tester.showKeyboard(find.byType(TextField));
        final state = tester.state(find.byType(EditableText));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'ni',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(popup(family, dark, true));
        await tester.pump();
        await tester.pumpWidget(popup(RaftFamily.elegant, !dark, false));
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.state(find.byType(EditableText)), same(state));
        expect(focus.hasFocus, true);
        expect(controller.value.composing, const TextRange(start: 0, end: 2));
        expect(controller.selection, const TextSelection.collapsed(offset: 2));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '你好',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(controller.selection, const TextSelection.collapsed(offset: 1));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(
          controller.selection,
          const TextSelection(baseOffset: 1, extentOffset: 0),
        );
        await tester.tapAt(tester.getCenter(find.text('design')));
        await tester.pump();
        expect(selected, 1);
        await tester.tapAt(tester.getCenter(find.byType(TextField)));
        await tester.pump();
        expect(focus.hasFocus, true);
        expect(controller.text, '你好');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        focus.dispose();
        controller.dispose();
      },
    );
    testWidgets(
      '$family/$dark real preview owner closes outside and Escape while keyboard and disabled semantics work',
      (tester) async {
        await loadFonts(tester);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          host(raftTheme(family, dark: dark), selectionPopoverPreview()),
        );
        await tester.tap(find.text('Choose channel'));
        await tester.pumpAndSettle();
        expect(find.byType(EditableText), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          true,
        );
        final disabled = tester.getSemantics(find.text('archived channel'));
        expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
        await tester.tap(find.text('archived channel'));
        await tester.pump();
        expect(find.byType(RaftSelectionPopover), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(find.text('design selected'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('design')).flagsCollection.isChecked,
          CheckedState.isTrue,
        );
        await tester.tap(find.text('Clear'));
        await tester.pump();
        expect(
          tester.getSemantics(find.text('design')).flagsCollection.isChecked,
          CheckedState.isFalse,
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(RaftSelectionPopover), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(RaftSelectionPopover), findsOneWidget);
        await tester.tapAt(const Offset(650, 550));
        await tester.pumpAndSettle();
        expect(find.byType(RaftSelectionPopover), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
