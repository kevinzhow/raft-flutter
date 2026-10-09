import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/workspace_shell_previews.dart';

import 'task_typography_test.dart' show loadTaskFonts;

// Source26f77ef Sidebar335–371/460–513/4092–4100/4203, LeftRail1012–1098.
// Real DOM DPR1: two-line Pinned body45+mb4; Joint empty drag bucket28.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark actual empty sidebar wrappers retain Source boxes and collapse',
      (t) async {
        await loadTaskFonts(t);
        var expanded = true;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: family == RaftFamily.brutal ? 222 : 223,
                  child: StatefulBuilder(
                    builder: (context, update) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RaftChatSidebarGroup(
                          kind: RaftChatSidebarGroupKind.pinned,
                          label: 'Pinned',
                          count: 0,
                          expanded: expanded,
                          hideEmpty: false,
                          emptyLabel: 'Drag channels or DMs here to pin',
                          onExpandedChanged: (v) => update(() => expanded = v),
                          children: const [],
                        ),
                        RaftChatSidebarGroup(
                          kind: RaftChatSidebarGroupKind.joint,
                          label: 'Joint channels',
                          count: 0,
                          expanded: expanded,
                          hideEmpty: false,
                          emptyLabel: 'No joint channels yet',
                          onExpandedChanged: (v) => update(() => expanded = v),
                          children: const [],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.getSize(find.byType(RaftChatSidebarGroup).first).height, 89);
        expect(t.getSize(find.byType(RaftChatSidebarGroup).last).height, 68);
        expect(t.getRect(find.byType(RaftChatSidebarGroup).last).top, 89);
        final semantics = t.ensureSemantics();
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(expanded, false);
        expect(find.text('Drag channels or DMs here to pin'), findsNothing);
        expect(find.text('No joint channels yet'), findsNothing);
        expect(t.getSize(find.byType(RaftChatSidebarGroup).first).height, 40);
        expect(t.takeException(), isNull);
        semantics.dispose();
      },
    );
    testWidgets(
      '$family/$dark footer honors the real SVG descendant size and keyboard activation',
      (t) async {
        var calls = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: RaftWorkspaceRailAction(
                label: 'Enter Workspace',
                glyph: RaftGlyph.squareSplitHorizontal,
                onPressed: () => calls++,
              ),
            ),
          ),
        );
        await t.pump();
        final glyph = t.widget<RaftIcon>(find.byType(RaftIcon));
        expect(glyph.size, family == RaftFamily.brutal ? 18 : 16);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(calls, 1);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$family/$dark interactive footer Preview keeps the unseen mask until actual Mobile App selection',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: workspaceRailFooterPreview()),
          ),
        );
        await t.pumpAndSettle();
        final help = find.byType(RaftWorkspaceHelpMenu);
        expect(t.widget<RaftWorkspaceHelpMenu>(help).attention, true);
        final mask = find.descendant(
          of: help,
          matching: find.byType(RaftRailAttention),
        );
        expect(mask, findsOneWidget);
        for (final icon in t.widgetList<RaftIcon>(
          find.descendant(of: mask, matching: find.byType(RaftIcon)),
        )) {
          expect(
            icon.color,
            isNull,
            reason: 'Source attention currentColor is inherited from the mask',
          );
        }
        await t.tap(help);
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(t.widget<RaftWorkspaceHelpMenu>(help).attention, true);
        await t.tap(help);
        await t.pumpAndSettle();
        await t.tap(find.text('Mobile app'));
        await t.pumpAndSettle();
        expect(t.widget<RaftWorkspaceHelpMenu>(help).attention, false);
        expect(mask, findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
}
