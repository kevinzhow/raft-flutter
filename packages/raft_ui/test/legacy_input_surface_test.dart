import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/legacy_input_previews.dart';
import 'package:raft_ui/test_themes.dart';

import 'agent_surface_cascade_test.dart' as cascade;

void main() {
  testWidgets('actual dark legacy input paints no inset band', (tester) async {
    const boundaryKey = ValueKey('legacy-input-paint');
    await tester.pumpWidget(
      cascade.host(
        raftTheme(dark: true),
        const Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 300,
              child: RaftTextInput(
                initialValue: '',
                readOnly: true,
                chrome: RaftInputChrome.legacy,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final raster = (await tester.runAsync(
      () => boundary.toImage(pixelRatio: 3),
    ))!;
    final bytes = (await tester.runAsync(
      () => raster.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    int red(int y) =>
        bytes.getUint8((y * raster.width + raster.width ~/ 2) * 4);
    // Raft dark inputs carry no inset highlight (field-inset-* are
    // transparent), so the band just inside the border is the plain fill.
    expect(red(4), red(60));
    raster.dispose();
    expect(tester.takeException(), isNull);
  });
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} Source legacy input retains default and focus shadows',
      (tester) async {
        await cascade.loadFonts(tester);
        final theme = raftTheme(dark: dark);
        final t = theme.extension<RaftTokens>()!;
        await tester.pumpWidget(
          cascade.host(
            theme,
            const Center(
              child: SizedBox(
                width: 300,
                child: RaftTextInput(
                  initialValue: 'draft',
                  chrome: RaftInputChrome.legacy,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        RaftRecipeBox box() =>
            tester.widget<RaftRecipeBox>(find.byType(RaftRecipeBox));
        // Raft inputs have no inset layers in either mode.
        expect(
          box().style.cssShadows(t.recipeTokens).where((s) => s.inset).length,
          0,
        );
        final neutral = tester.getSize(find.byType(RaftTextInput));
        await tester.tapAt(tester.getRect(find.byType(RaftTextInput)).center);
        await tester.pump();
        expect(
          tester
              .state<EditableTextState>(find.byType(EditableText))
              .widget
              .focusNode
              .hasFocus,
          true,
        );
        expect(
          box().style.cssShadows(t.recipeTokens).where((s) => s.inset).length,
          0,
        );
        expect(box().style.classes.contains('shadow-raft-sm'), true);
        expect(tester.getSize(find.byType(RaftTextInput)), neutral);
        final override = box().decorationOverride!(const BoxDecoration());
        expect(
          override.border!.dimensions.resolve(TextDirection.ltr),
          const EdgeInsets.all(1),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} legacy repaint preserves IME, selection and caller geometry',
      (tester) async {
        await cascade.loadFonts(tester);
        final controller = TextEditingController(text: 'draft');
        final theme = raftTheme(dark: dark);
        late StateSetter update;
        var invalid = false;
        var alternateTheme = false;
        var submitted = '';
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return cascade.host(
                alternateTheme ? raftTheme(dark: !dark) : theme,
                Center(
                  child: SizedBox(
                    width: 300,
                    child: RaftTextInput(
                      controller: controller,
                      chrome: RaftInputChrome.legacy,
                      invalid: invalid,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      semanticLabel: 'Name',
                      onSubmitted: (v) => submitted = v,
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: tester.getCenter(find.byType(RaftTextInput)),
        );
        await tester.pump();
        await tester.tapAt(tester.getRect(find.byType(RaftTextInput)).center);
        await tester.pump();
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '日本語 input',
            selection: TextSelection(baseOffset: 1, extentOffset: 3),
            composing: TextRange(start: 0, end: 3),
          ),
        );
        await tester.pump();
        final value = controller.value;
        update(() {
          invalid = true;
          alternateTheme = true;
        });
        for (final elapsed in [
          Duration.zero,
          const Duration(milliseconds: 16),
          const Duration(milliseconds: 16),
        ]) {
          await tester.pump(elapsed);
          expect(tester.state(find.byType(EditableText)), same(state));
          expect(controller.value, value);
          expect(state.widget.focusNode.hasFocus, true);
          expect(tester.testTextInput.hasAnyClients, true);
        }
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(EditableText)), same(state));
        expect(controller.value, value);
        expect(state.widget.focusNode.hasFocus, true);
        expect(tester.testTextInput.hasAnyClients, true);
        expect(
          tester.widget<RaftRecipeBox>(find.byType(RaftRecipeBox)).padding,
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(controller.selection.isCollapsed, true);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(submitted, value.text);
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} readonly and disabled legacy inputs retain their actual contracts',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final controller = TextEditingController(text: 'read only');
          Widget field({required bool enabled}) => cascade.host(
            raftTheme(dark: dark),
            Center(
              child: SizedBox(
                width: 280,
                child: RaftTextInput(
                  controller: controller,
                  chrome: RaftInputChrome.legacy,
                  readOnly: true,
                  enabled: enabled,
                  semanticLabel: 'Read only name',
                ),
              ),
            ),
          );
          await tester.pumpWidget(field(enabled: true));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(RaftTextInput));
          await tester.pump();
          final editable = tester.widget<EditableText>(
            find.byType(EditableText),
          );
          final node = tester.getSemantics(find.byType(EditableText));
          expect(node.flagsCollection.isReadOnly, true);
          expect(node.flagsCollection.isTextField, true);
          expect(editable.readOnly, true);
          expect(editable.focusNode.hasFocus, true);
          expect(controller.text, 'read only');
          expect(tester.testTextInput.hasAnyClients, false);
          await tester.pumpWidget(field(enabled: false));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(RaftTextInput));
          await tester.pump();
          expect(
            tester.widget<TextField>(find.byType(TextField)).enabled,
            false,
          );
          expect(controller.text, 'read only');
          expect(tester.testTextInput.hasAnyClients, false);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        } finally {
          semantics.dispose();
        }
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} actual legacy preview keeps editing while caller switches',
      (tester) async {
        await cascade.loadFonts(tester);
        await tester.pumpWidget(
          cascade.host(raftTheme(dark: dark), const LegacyInputPreview()),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Product-QA');
        await tester.pump();
        await tester.tap(find.text('Mark Invalid'));
        await tester.pump();
        await tester.tap(find.text('Caller Inset'));
        await tester.pump();
        expect(
          tester.widget<RaftTextInput>(find.byType(RaftTextInput)).invalid,
          true,
        );
        expect(
          tester
              .widget<RaftTextInput>(find.byType(RaftTextInput))
              .controller!
              .text,
          'Product-QA',
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(
          find.byWidgetPredicate((w) => w is Text && w.data == 'Product-QA'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
