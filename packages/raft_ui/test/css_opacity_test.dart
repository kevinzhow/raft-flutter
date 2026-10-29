import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'control_transition_paint_test.dart' show pixel;

void main() {
  testWidgets(
    'Source 0.7.0 disabled buttons and Composer use opaque muted fill',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: RepaintBoundary(
            key: const ValueKey('paint'),
            child: ColoredBox(
              color: Colors.white,
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 330,
                      child: RaftButton(
                        label: 'Create Cindy',
                        tone: RaftButtonRecipeVariant.accent,
                        size: RaftButtonRecipeSize.lg,
                        expand: true,
                        opacityCompositing: RaftOpacityCompositing.alphaFilter,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 330,
                      child: RaftButton(
                        label: 'Create Agent',
                        tone: RaftButtonRecipeVariant.accent,
                        size: RaftButtonRecipeSize.lg,
                        expand: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const RaftComposerAction(
                      glyph: RaftGlyph.send,
                      tooltip: 'Send',
                      onPressed: null,
                      submit: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Pinned raft-ui 0.7.0 Button: disabled:bg-fill-muted and opacity-100
      // also apply to the native composer Submit. Keep exact sampled bytes.
      final cindy = tester.getTopLeft(find.byType(RaftButton).first);
      final dialog = tester.getTopLeft(
        find.widgetWithText(RaftButton, 'Create Agent'),
      );
      final send = tester.getTopLeft(find.byType(RaftComposerAction));
      expect(
        await pixel(tester, dialog + const Offset(12, 12)),
        // 0.7.0: a disabled button is fill-muted, not a translucent accent.
        const Color(0xfff3f3f3),
      );
      expect(
        await pixel(tester, cindy + const Offset(12, 12)),
        const Color(0xfff3f3f3),
      );
      expect(
        await pixel(tester, send + const Offset(5, 8)),
        const Color(0xfff3f3f3),
      );
      expect(
        tester.widget<RaftButton>(find.byType(RaftButton).first).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} alpha changes retain editor, focus and IME',
      (tester) async {
        final alpha = ValueNotifier<double>(1);
        final controller = TextEditingController(text: 'Draft 中文');
        final focus = FocusNode();
        addTearDown(alpha.dispose);
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: ValueListenableBuilder<double>(
                  valueListenable: alpha,
                  builder: (_, value, _) => RaftCssOpacity(
                    opacity: value,
                    child: Semantics(
                      label: 'Visible editor',
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byType(TextField));
          await tester.pump();
          final state = tester.state<EditableTextState>(
            find.byType(EditableText),
          );
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: 'Draft 日本語',
              selection: TextSelection.collapsed(offset: 9),
              composing: TextRange(start: 6, end: 9),
            ),
          );
          await tester.pump();
          for (final value in [.4, 0.0, 1.0]) {
            alpha.value = value;
            await tester.pump();
            expect(
              tester.state<EditableTextState>(find.byType(EditableText)),
              same(state),
            );
            expect(
              controller.value.composing,
              const TextRange(start: 6, end: 9),
            );
            expect(controller.text, 'Draft 日本語');
            expect(focus.hasFocus, true);
            final root = tester
                .binding
                .renderViews
                .single
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!;
            final labels = <String>[];
            void visit(SemanticsNode node) {
              labels.add(node.getSemanticsData().label);
              node.visitChildren((child) {
                visit(child);
                return true;
              });
            }

            visit(root);
            expect(
              labels.any((label) => label.contains('Visible editor')),
              value != 0,
            );
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
