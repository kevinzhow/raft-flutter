import 'dart:ui' show PointerDeviceKind, SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'profile SVG follows tab size, stroke and selection $family/$dark',
      (tester) async {
        var selected = 'profile';
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
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
        expect(tester.getSize(svg), const Size.square(14));
        expect(
          tester.widget<RaftChatIcon>(svg).strokeWidth,
          family == RaftFamily.brutal ? 2.5 : 1.5,
        );
        final row = tester.getRect(find.byType(RaftPanelTabBar<String>));
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();
        expect(selected, 'chat');
        expect(tester.getRect(find.byType(RaftPanelTabBar<String>)), row);
        final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await hover.addPointer(location: tester.getCenter(svg));
        await tester.pumpAndSettle();
        expect(tester.getSize(svg), const Size.square(14));
        await hover.removePointer();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'legacy card keeps field state and button input $family/$dark',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final controller = TextEditingController(text: 'draft');
        addTearDown(controller.dispose);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        var saved = 0;
        Future<void> mount(RaftFamily next, bool nextDark) => tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(next, dark: nextDark),
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
        await mount(family, dark);
        await tester.pumpAndSettle();
        final fieldState = tester.state(find.byType(EditableText));
        await tester.enterText(find.byType(TextField), 'kept draft');
        controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 7,
        );
        for (final (next, nextDark) in [
          (RaftFamily.elegant, true),
          (RaftFamily.brutal, false),
          (RaftFamily.elegant, false),
        ]) {
          await mount(next, nextDark);
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

  testWidgets('Elegant dark legacy card retains inset shadow layers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant, dark: true),
        home: const Scaffold(
          body: RaftPanel(
            style: RaftPanelStyle.legacyCard,
            child: SizedBox(width: 200, height: 100),
          ),
        ),
      ),
    );
    final inset = tester.widget<Container>(
      find.descendant(
        of: find.byType(RaftPanel),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is RaftLayeredDecoration,
        ),
      ),
    );
    final decoration = inset.decoration! as RaftLayeredDecoration;
    expect(decoration.layers.length, 2);
    expect(decoration.layers.first.offset, const Offset(0, 1));
    expect(decoration.layers.first.color.a, closeTo(.05, .000001));
    expect(decoration.layers.last.spread, 1);
    expect(decoration.layers.last.color.a, closeTo(.03, .000001));
    expect(tester.takeException(), isNull);
  });
}
