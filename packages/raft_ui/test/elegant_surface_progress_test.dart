import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Pinned Source SurfaceListItem.tsx 17–39, ProgressBar.tsx 47–66,
// raft-ui 0.5.27 input/progress recipes. Actual SDK components; these do not
// count as product-page or native-platform evidence.
Widget host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 310, child: child),
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
      '$family/$dark real surface preserves caller text, selection and hover',
      (tester) async {
        var taps = 0;
        final theme = raftTheme(family, dark: dark);
        await tester.pumpWidget(
          host(
            theme,
            RaftSurfaceListItem(
              selected: true,
              onTap: () => taps++,
              child: const Text(
                'Actual caller text',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
        );
        final box = tester.widget<RaftRecipeBox>(find.byType(RaftRecipeBox));
        final tokens = theme.extension<RaftTokens>()!;
        if (family == RaftFamily.elegant) {
          expect(box.style.borderWidth, const EdgeInsets.all(1));
          expect(box.style.borderRadius, BorderRadius.circular(8));
          expect(
            box.style.border(tokens.recipeTokens)!.top.color,
            dark ? Colors.transparent : tokens.semantic.info,
          );
          expect(box.style.classes, contains('shadow-raft-sm'));
          expect(box.style.classes, isNot(contains('shadow-raft-xs')));
          expect(box.decorationOverride, isNull);
        }
        expect(
          tester.widget<Text>(find.text('Actual caller text')).style!.color,
          Colors.black,
        );
        await tester.tap(find.text('Actual caller text'));
        expect(taps, 1);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(600, 600));
        await mouse.moveTo(tester.getCenter(find.byType(RaftSurfaceListItem)));
        await tester.pump();
        await mouse.moveTo(const Offset(600, 600));
        await tester.pump();
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$family/$dark real progress paints inherited variable shadows and clamps',
      (tester) async {
        final theme = raftTheme(family, dark: dark);
        await tester.pumpWidget(
          host(
            theme,
            const RaftProgressBar(
              value: 64,
              label: 'Download',
              showPercent: true,
            ),
          ),
        );
        final boxes = tester
            .widgetList<RaftRecipeBox>(find.byType(RaftRecipeBox))
            .toList();
        final track = boxes.first;
        expect(track.clip, !dark);
        if (dark) {
          final indicator = boxes.last;
          final tokens = theme.extension<RaftTokens>()!;
          final shadows = indicator.style.cssShadows(tokens.recipeTokens);
          expect(shadows.where((layer) => layer.inset), hasLength(1));
          expect(
            shadows.where((layer) => !layer.inset && layer.color.a > 0),
            hasLength(2),
          );
        }
        expect(find.text('64%'), findsOneWidget);
        await tester.pumpWidget(
          host(theme, const RaftProgressBar(value: 120, showPercent: true)),
        );
        expect(find.text('100%'), findsOneWidget);
        expect(
          tester
              .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
              .widthFactor,
          1,
        );
        await tester.pumpWidget(
          host(theme, const RaftProgressBar(value: -3, showPercent: true)),
        );
        expect(find.text('0%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$family/$dark autofocus ring retains live editing across focus and theme',
      (tester) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        final themes = [
          raftTheme(family, dark: dark),
          raftTheme(RaftFamily.elegant, dark: !dark),
        ];
        Widget input(ThemeData theme) => host(
          theme,
          RaftTextInput(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            hintText: 'Search',
          ),
        );
        await tester.pumpWidget(input(themes.first));
        await tester.pump();
        expect(focus.hasFocus, true);
        final state = tester.state(find.byType(EditableText));
        final initial = tester.widget<RaftRecipeBox>(
          find.byType(RaftRecipeBox),
        );
        if (family == RaftFamily.elegant) {
          final layers = initial.style.cssShadows(
            themes.first.extension<RaftTokens>()!.recipeTokens,
          );
          expect(
            layers.any(
              (layer) =>
                  !layer.inset &&
                  layer.spread == (dark ? 2 : 1) &&
                  layer.color.a > 0,
            ),
            true,
            reason: 'Source editable inputs match :focus-visible on autofocus.',
          );
        }
        await tester.showKeyboard(find.byType(TextField));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'ni',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(input(themes.last));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.state(find.byType(EditableText)), same(state));
        expect(controller.value.composing, const TextRange(start: 0, end: 2));
        expect(controller.selection, const TextSelection.collapsed(offset: 2));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '你',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        expect(controller.text, '你');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(controller.selection.baseOffset, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        focus.dispose();
        controller.dispose();
      },
    );
  }
}
