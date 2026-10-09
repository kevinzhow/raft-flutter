import 'package:flutter/gestures.dart';

import 'dart:ui' show Tristate, SemanticsRole;

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
    Future<void> mount(
      WidgetTester tester,
      Widget child, {
      double height = 800,
    }) async {
      tester.view.physicalSize = Size(800, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(body: child),
        ),
      );
      await tester.pump();
    }

    testWidgets('$family/$dark Source heading owns its border-box height', (
      tester,
    ) async {
      await mount(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 280,
            child: RaftChatSidebarHeading(label: 'Chat'),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(RaftChatSidebarHeading)).height,
        family == RaftFamily.brutal ? 62 : 56,
      );
      final text = tester.widget<Text>(find.text('Chat'));
      expect(text.style!.fontWeight, FontWeight.w700);
      expect(text.style!.fontSize, 18);
      expect(find.byType(RaftDropdownMenu), findsNothing);
    });

    testWidgets(
      '$family/$dark Source rail slots, short size and depressed semantics',
      (tester) async {
        var clicks = 0;
        Widget footer() => Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: 64,
            child: RaftWorkspaceRailFooter(
              children: [
                RaftWorkspaceRailAction(
                  label: 'Workspace',
                  glyph: RaftGlyph.squareSplitHorizontal,
                  selected: true,
                  depressed: true,
                  onPressed: () => clicks++,
                ),
                RaftWorkspaceRailAction(
                  label: 'Settings',
                  glyph: RaftGlyph.settings,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        await mount(tester, footer());
        expect(
          tester.getSize(find.byType(RaftWorkspaceRailFooter)).height,
          102,
        );
        final action = find.bySemanticsLabel('Workspace');
        final semantics = tester.ensureSemantics();
        expect(
          tester.getSemantics(action).flagsCollection.isSelected,
          Tristate.isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(clicks, 1);
        final box = find.descendant(
          of: find.byType(RaftWorkspaceRailAction).first,
          matching: find.byType(RaftRecipeBox),
        );
        expect(tester.getSize(box), const Size(40, 40));
        await mount(tester, footer(), height: 600);
        expect(tester.getSize(box), const Size(36, 36));
        semantics.dispose();
      },
    );

    testWidgets(
      '$family/$dark actual editor tabs expose selected state on their tab role',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var selected = 'one';
        await mount(
          tester,
          StatefulBuilder(
            builder: (context, setState) => RaftEditorGroups(
              groups: [
                RaftEditorGroup(
                  id: 'g',
                  selected: selected,
                  tabs: const [
                    RaftEditorTab(
                      id: 'one',
                      label: 'One',
                      child: Text('First body'),
                    ),
                    RaftEditorTab(
                      id: 'two',
                      label: 'Two',
                      child: Text('Second body'),
                    ),
                  ],
                ),
              ],
              onSelect: (_, id) => setState(() => selected = id),
              onClose: (_) {},
              onMove: (_, __) {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final one = find.byKey(const ValueKey('editor-tab-one')),
            two = find.byKey(const ValueKey('editor-tab-two'));
        expect(
          tester.getSemantics(one).getSemanticsData().role,
          SemanticsRole.tab,
        );
        expect(
          tester.getSemantics(one).flagsCollection.isSelected,
          Tristate.isTrue,
        );
        expect(
          tester.getSemantics(two).flagsCollection.isSelected,
          Tristate.isFalse,
        );
        await tester.tap(two);
        await tester.pump();
        expect(selected, 'two');
        expect(
          tester.getSemantics(two).flagsCollection.isSelected,
          Tristate.isTrue,
        );
        expect(
          tester.getSemantics(one).flagsCollection.isSelected,
          Tristate.isFalse,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      },
    );

    testWidgets(
      '$family/$dark Help right/end placement, hover grace and keyboard action',
      (tester) async {
        final controller = RaftMenuController(), editorFocus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(editorFocus.dispose);
        var selected = 0;
        await mount(
          tester,
          Stack(
            fit: StackFit.expand,
            children: [
              Focus(focusNode: editorFocus, child: const Text('Editor')),
              Positioned(
                left: 12,
                bottom: 44,
                child: RaftWorkspaceHelpMenu(
                  label: 'Help',
                  heading: 'Help & resources',
                  controller: controller,
                  entries: [
                    RaftMenuEntry(
                      label: 'Documentation',
                      leading: const RaftIcon(RaftGlyph.bookOpenText, size: 14),
                      trailing: const RaftIcon(
                        RaftGlyph.arrowUpRight,
                        size: 14,
                      ),
                      onPressed: () => selected++,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        editorFocus.requestFocus();
        await tester.pump();
        expect(
          editorFocus.hasFocus,
          isTrue,
          reason: "editor starts focused before hover",
        );
        final trigger = find.byType(RaftWorkspaceRailAction);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(780, 20));
        await mouse.moveTo(tester.getCenter(trigger));
        await tester.pumpAndSettle();
        expect(controller.isOpen, isTrue);
        expect(editorFocus.hasFocus, isTrue);
        final menu = find.byType(RaftMenuPanel);
        final triggerRect = tester.getRect(trigger),
            menuRect = tester.getRect(menu);
        expect(menuRect.width, 320);
        expect(menuRect.left, triggerRect.right + 8);
        expect(menuRect.bottom, triggerRect.bottom);
        await mouse.moveTo(tester.getCenter(menu));
        await tester.pump(const Duration(milliseconds: 150));
        expect(controller.isOpen, isTrue);
        await mouse.moveTo(const Offset(780, 20));
        await tester.pump(const Duration(milliseconds: 119));
        expect(controller.isOpen, isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        expect(controller.isOpen, isFalse);
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(controller.isOpen, isTrue);
        final control = tester.widget<RaftInteractive>(
          find.descendant(of: trigger, matching: find.byType(RaftInteractive)),
        );
        expect(
          control.focusNode!.hasFocus,
          isTrue,
          reason: 'Source pointer-open keeps trigger focus',
        );
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        editorFocus.requestFocus();
        await tester.pump();
        await mouse.removePointer();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(controller.isOpen, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(controller.isOpen, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(controller.isOpen, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
