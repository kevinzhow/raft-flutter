import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget menuHost(Widget child, {RaftFamily family = RaftFamily.elegant}) =>
    MaterialApp(
      theme: raftTheme(family),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );

bool focused(WidgetTester tester, String label) => tester
    .widget<RaftMenuItem>(find.widgetWithText(RaftMenuItem, label))
    .focusNode!
    .hasFocus;

void main() {
  for (final family in RaftFamily.values) {
    testWidgets(
      '$family dropdown keyboard owns selection and restores trigger',
      (tester) async {
        var copied = 0;
        var deleted = 0;
        final controller = RaftMenuController();
        await tester.pumpWidget(
          menuHost(
            RaftDropdownMenu(
              label: 'Actions',
              controller: controller,
              entries: [
                RaftMenuEntry(label: 'Copy', onPressed: () => copied++),
                const RaftMenuEntry(label: 'Unavailable'),
                const RaftMenuEntry.separator(),
                RaftMenuEntry(label: 'Delete', onPressed: () => deleted++),
              ],
            ),
            family: family,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(controller.isOpen, isTrue);
        expect(focused(tester, 'Copy'), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focused(tester, 'Delete'), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focused(tester, 'Copy'), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(copied, 1);
        expect(deleted, 0);
        expect(controller.isOpen, isFalse);
        expect(find.byType(RaftMenuItem), findsNothing);
        // Escape closes an independently reopened popup and returns keyboard
        // ownership, so the next ArrowUp can open at its last enabled action.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(focused(tester, 'Delete'), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(controller.isOpen, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(focused(tester, 'Copy'), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        controller.close();
        controller.open();
        expect(tester.takeException(), isNull);
        controller.dispose();
      },
    );
  }

  testWidgets(
    'outside click dismisses and external close cancels queued focus',
    (tester) async {
      final controller = RaftMenuController();
      await tester.pumpWidget(
        menuHost(
          RaftDropdownMenu(
            label: 'Actions',
            controller: controller,
            entries: [RaftMenuEntry(label: 'Copy', onPressed: () {})],
          ),
        ),
      );
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      controller.open();
      controller.close();
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('control never disposes its externally owned focus node', (
    tester,
  ) async {
    final focus = FocusNode();
    await tester.pumpWidget(
      menuHost(
        RaftControl(
          focusNode: focus,
          onPressed: () {},
          child: const Text('One'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      menuHost(Focus(focusNode: focus, child: const Text('Two'))),
    );
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
  });

  testWidgets('keyboard menu focus projects on actionable semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        menuHost(
          RaftDropdownMenu(
            label: 'Actions',
            entries: [
              RaftMenuEntry(label: 'Copy', onPressed: () {}),
              RaftMenuEntry(label: 'Delete', onPressed: () {}),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester
            .getSemantics(find.widgetWithText(RaftMenuItem, 'Copy'))
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester
            .getSemantics(find.widgetWithText(RaftMenuItem, 'Copy'))
            .flagsCollection
            .isFocused,
        Tristate.isFalse,
      );
      expect(
        tester
            .getSemantics(find.widgetWithText(RaftMenuItem, 'Delete'))
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(RaftMenuItem), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      handle.dispose();
    }
  });

  for (final density in RaftDensity.values) {
    testWidgets(
      'task status uses $density layout without losing its callback',
      (tester) async {
        String? changed;
        await tester.pumpWidget(
          menuHost(
            RaftDensityScope(
              density: density,
              child: RaftTaskCard(
                title: 'Review',
                number: '214',
                status: 'todo',
                statusOptions: const ['done'],
                onStatus: (value) => changed = value,
              ),
            ),
          ),
        );
        final trigger = find.byType(RaftInlineBadgeEditor);
        // Touch density widens the hit/semantics target, never the badge.
        expect(
          tester.getSize(trigger).height,
          lessThan(RaftMetrics.touchTarget),
        );
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(changed, 'done');
      },
    );
  }
  testWidgets(
    'custom trigger top/end uses logical RTL edge and restores its owned focus',
    (t) async {
      final controller = RaftMenuController();
      addTearDown(controller.dispose);
      FocusNode? trigger;
      var activated = 0;
      await t.pumpWidget(
        menuHost(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: RaftDropdownMenu(
                  label: 'RTL actions',
                  controller: controller,
                  side: RaftDropdownSide.top,
                  align: RaftDropdownAlign.end,
                  sideOffset: 8,
                  triggerBuilder: (context, node, pressed) {
                    trigger = node;
                    return RaftButton(
                      label: 'RTL custom trigger',
                      focusNode: node,
                      onPressed: pressed,
                    );
                  },
                  entries: [
                    RaftMenuEntry(
                      label: 'Copy current',
                      onPressed: () => activated++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final rect = t.getRect(find.text('RTL custom trigger'));
      final box = t.getRect(find.byType(RaftButton));
      await t.tapAt(rect.center);
      await t.pumpAndSettle();
      final menu = t.getRect(find.byType(RaftMenuPanel));
      expect(menu.left, closeTo(box.left, .01));
      expect(menu.bottom, closeTo(box.top - 8, .01));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(activated, 1);
      expect(controller.isOpen, isFalse);
      expect(trigger!.hasFocus, isTrue);
      expect(t.takeException(), isNull);
    },
  );
}
