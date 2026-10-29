import 'dart:ui' show PointerDeviceKind, SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'profile SVG follows tab size (16px, stroke 2) and selection ${dark ? 'dark' : 'light'}',
      (tester) async {
        var selected = 'profile';
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) => RaftPanelTabBar<String>(
                  tabs: [
                    const RaftPanelTab('profile', 'Profile', RaftGlyph.bot),
                    RaftPanelTab.custom(
                      'chat',
                      'Chat',
                      iconBuilder: (size, color, strokeWidth) => RaftChatIcon(
                        size: size,
                        color: color,
                        strokeWidth: strokeWidth,
                      ),
                    ),
                  ],
                  value: selected,
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final svg = find.byType(RaftChatIcon);
        expect(tester.getSize(svg), const Size.square(16));
        expect(tester.widget<RaftChatIcon>(svg).strokeWidth, 2);
        final row = tester.getRect(find.byType(RaftPanelTabBar<String>));
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();
        expect(selected, 'chat');
        expect(tester.getRect(find.byType(RaftPanelTabBar<String>)), row);
        final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await hover.addPointer(location: tester.getCenter(svg));
        await tester.pumpAndSettle();
        expect(tester.getSize(svg), const Size.square(16));
        await hover.removePointer();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'legacy card keeps field state and button input ${dark ? 'dark' : 'light'}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final controller = TextEditingController(text: 'draft');
        addTearDown(controller.dispose);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        var saved = 0;
        Future<void> mount(bool nextDark) => tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: nextDark),
            home: Scaffold(
              body: SizedBox(
                width: 310,
                child: RaftPanel(
                  style: RaftPanelStyle.legacyCard,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: controller),
                      RaftButton(
                        label: 'Save changes',
                        focusNode: focus,
                        onPressed: () => saved++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await mount(dark);
        await tester.pumpAndSettle();
        final fieldState = tester.state(find.byType(EditableText));
        await tester.enterText(find.byType(TextField), 'kept draft');
        controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 7,
        );
        for (final nextDark in [true, false]) {
          await mount(nextDark);
          await tester.pumpAndSettle();
          expect(tester.state(find.byType(EditableText)), same(fieldState));
          expect(controller.text, 'kept draft');
          expect(
            controller.selection,
            const TextSelection(baseOffset: 2, extentOffset: 7),
          );
        }
        focus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(saved, 2);
        final node = tester.getSemantics(find.byType(RaftButton));
        tester.binding.performSemanticsAction(
          SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: node.id,
            type: SemanticsAction.tap,
          ),
        );
        await tester.pumpAndSettle();
        expect(saved, 3);
        await tester.tap(find.text('Save changes'));
        expect(saved, 4);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('Dark legacy card has no inset or outer shadow layers', (
    tester,
  ) async {
    // shadow-raft-md is empty in Raft: the card casts no shadow, and with no
    // inset layers the painter falls back to a plain BoxDecoration.
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: true),
        home: const Scaffold(
          body: RaftPanel(
            style: RaftPanelStyle.legacyCard,
            child: SizedBox(width: 200, height: 100),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(RaftPanel),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is RaftLayeredDecoration,
        ),
      ),
      findsNothing,
    );
    final box = tester.widget<RaftRecipeBox>(find.byType(RaftRecipeBox));
    final t = RaftTokens.of(tester.element(find.byType(RaftPanel)));
    expect(box.style.cssShadows(t.recipeTokens), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
