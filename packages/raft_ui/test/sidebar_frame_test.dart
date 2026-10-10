import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        'mounted group $family/$dark/$width surface, geometry and keyboard',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          var expanded = true;
          var selected = 0;
          const disclosure = ValueKey('computer-disclosure');
          final theme = raftTheme(family, dark: dark);
          final semantics = t.ensureSemantics();
          try {
            await t.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 240,
                      child: StatefulBuilder(
                        builder: (context, update) => RaftMountedSidebarFrame(
                          header: const RaftChatSidebarHeading(
                            label: 'Members',
                          ),
                          body: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              RaftSidebarMachineGroup(
                                name: 'K8-Plus',
                                count: 1,
                                expanded: expanded,
                                disclosureKey: disclosure,
                                onExpandedChanged: (value) =>
                                    update(() => expanded = value),
                                children: [
                                  RaftNavItem(
                                    label: 'Kevin',
                                    labelSuffix: '(you)',
                                    description: 'Shared human description',
                                    glyph: RaftGlyph.user,
                                    conversationKind:
                                        RaftConversationNavKind.directory,
                                    onTap: () => selected++,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            final tokens = theme.extension<RaftTokens>()!;
            final frame = find.byType(RaftMountedSidebarFrame);
            final fill = find
                .descendant(of: frame, matching: find.byType(ColoredBox))
                .first;
            expect(
              t.widget<ColoredBox>(fill).color,
              RaftSidebarRecipe(
                tokens,
                viewportWidth: width,
                viewportHeight: 844,
                variant: RaftSidebarVariant.mountedProduct,
              ).bodyBackground,
            );
            final toggle = find.byKey(disclosure);
            expect(t.getSize(toggle), const Size(240, 15));
            final name = find.text('k8-plus');
            expect(t.widget<Text>(name).style!.fontSize, 10);
            expect(t.widget<Text>(name).style!.height, 1.5);
            final glyphs = find.descendant(
              of: toggle,
              matching: find.byType(RaftIcon),
            );
            expect(glyphs, findsNWidgets(2));
            expect(t.getSize(glyphs.first), const Size(9, 9));
            expect(t.getRect(glyphs.first).left - t.getRect(toggle).left, 8);
            final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
            await mouse.addPointer(location: t.getCenter(toggle));
            await mouse.moveTo(t.getCenter(toggle));
            await t.pumpAndSettle();
            expect(
              t.widget<Text>(name).style!.color,
              family == RaftFamily.brutal
                  ? Colors.black.withValues(alpha: .6)
                  : tokens.muted,
            );
            await mouse.removePointer();
            await t.pumpAndSettle();
            final row = find.byType(RaftNavItem);
            expect(t.getRect(row).top - t.getRect(toggle).bottom, 2);
            expect(
              find.text('Kevin (you)', findRichText: true),
              findsOneWidget,
            );
            expect(find.text('Shared human description'), findsOneWidget);
            expect(
              t
                  .getSemantics(toggle)
                  .getSemanticsData()
                  .flagsCollection
                  .isExpanded
                  .toBoolOrNull(),
              true,
            );
            await t.tap(toggle);
            await t.pumpAndSettle();
            expect(row, findsNothing);
            expect(selected, 0);
            expect(
              t
                  .getSemantics(toggle)
                  .getSemanticsData()
                  .flagsCollection
                  .isExpanded
                  .toBoolOrNull(),
              false,
            );
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.pumpAndSettle();
            expect(row, findsOneWidget);
            await t.sendKeyEvent(LogicalKeyboardKey.tab);
            await t.sendKeyEvent(LogicalKeyboardKey.space);
            expect(selected, 1);
            expect(t.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
