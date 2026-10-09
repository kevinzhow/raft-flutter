import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Source ServerSwitcherMenu.tsx120–185/242–307/363–448. Actual browser
// geometry/input receipts are in .local/k08-server-menu-v1, not inferred here.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark Source mobile Home menu uses full header anchor, viewport gutters and container keyboard focus',
      (t) async {
        t.view.physicalSize = const Size(390, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final controller = RaftMenuController();
        addTearDown(controller.dispose);
        var selected = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RaftServerSwitcher(
                  mobile: true,
                  controller: controller,
                  workspaceName: 'Visual Server',
                  label: 'Switch workspace',
                  rows: [
                    RaftServerMenuRow(
                      id: 'visual',
                      name: 'Visual Server',
                      slug: 'visual',
                      current: true,
                      onSelected: () => selected++,
                    ),
                  ],
                  actions: [
                    RaftMenuEntry(label: 'Join Community', onPressed: () {}),
                    RaftMenuEntry(
                      label: 'Switch or Create Server',
                      onPressed: () {},
                    ),
                    RaftServerMenuAction(
                      label: 'Invite human',
                      tone: RaftServerMenuActionTone.invite,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('mobile-server-selector')));
        await t.pumpAndSettle();
        expect(
          t.getRect(find.byKey(const Key('server-switcher-menu'))),
          Rect.fromLTWH(
            8,
            family == RaftFamily.brutal ? 64 : 59,
            374,
            family == RaftFamily.brutal ? 162 : 167,
          ),
        );
        expect(FocusManager.instance.primaryFocus!.skipTraversal, isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(selected, 1);
        expect(find.byKey(const Key('server-switcher-menu')), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      '$family/$dark Source pointer server handle requires distance6 then reorders the real list',
      (t) async {
        final controller = RaftMenuController();
        addTearDown(controller.dispose);
        var names = ['Alpha', 'Beta', 'Gamma'];
        final moves = <(int, int)>[];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 64,
                  child: StatefulBuilder(
                    builder: (context, update) => RaftServerSwitcher(
                      controller: controller,
                      workspaceName: 'Alpha',
                      label: 'Switch workspace',
                      rows: [
                        for (final name in names)
                          RaftServerMenuRow(
                            id: name,
                            name: name,
                            slug: name,
                            onSelected: () {},
                          ),
                      ],
                      actions: [
                        RaftMenuEntry(
                          label: 'Switch or Create Server',
                          onPressed: () {},
                        ),
                      ],
                      onReorder: (from, to) {
                        moves.add((from, to));
                        update(() {
                          final next = List<String>.of(names);
                          next.insert(to, next.removeAt(from));
                          names = next;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        final start = t.getCenter(
          find.byKey(const ValueKey('server-menu-reorder-Alpha')),
        );
        final mouse = await t.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await mouse.moveTo(start + const Offset(0, 3));
        await t.pump();
        expect(moves, isEmpty);
        expect(
          find
              .byType(Opacity)
              .evaluate()
              .where((e) => (e.widget as Opacity).opacity == .6),
          isEmpty,
        );
        final last = t.getRect(
          find.byKey(const ValueKey('server-menu-reorder-Gamma')),
        );
        final end = Offset(start.dx, last.bottom + last.height / 2);
        for (var step = 1; step <= 10; step++) {
          await mouse.moveTo(Offset.lerp(start, end, step / 10)!);
          await t.pump(const Duration(milliseconds: 32));
        }
        await t.pump(const Duration(milliseconds: 300));
        await mouse.up();
        await t.pumpAndSettle();
        expect(moves, [(0, 2)]);
        expect(names, ['Beta', 'Gamma', 'Alpha']);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      '$family/$dark Source server menu anchors, focuses, traverses, closes and keeps current unread hidden',
      (t) async {
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final controller = RaftMenuController();
        addTearDown(controller.dispose);
        var current = 0, global = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: family == RaftFamily.brutal ? 64 : 56,
                    child: RaftServerSwitcher(
                      controller: controller,
                      workspaceName: 'Visual Server',
                      label: 'Switch workspace',
                      rows: [
                        RaftServerMenuRow(
                          id: 'visual',
                          name: 'Visual Server',
                          slug: 'visual',
                          current: true,
                          activityUnreadCount: 88,
                          onSelected: () => current++,
                        ),
                      ],
                      actions: [
                        RaftMenuEntry(
                          label: 'Join Community',
                          glyph: RaftGlyph.plus,
                          onPressed: () {},
                        ),
                        RaftMenuEntry(
                          label: 'Switch or Create Server',
                          glyph: RaftGlyph.plus,
                          onPressed: () => global++,
                        ),
                        RaftServerMenuAction(
                          tone: RaftServerMenuActionTone.invite,
                          label: 'Invite human',
                          glyph: RaftGlyph.userPlus,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: Center(child: Text('Outside'))),
                ],
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        final menu = find.byKey(const Key('server-switcher-menu'));
        expect(
          t.getRect(menu),
          Rect.fromLTWH(
            family == RaftFamily.brutal ? 70 : 64,
            4,
            256,
            family == RaftFamily.brutal ? 162 : 167,
          ),
        );
        expect(find.text('88'), findsNothing);
        expect(FocusManager.instance.primaryFocus!.skipTraversal, isTrue);
        final invite = find.byWidgetPredicate(
          (w) => w is RaftInteractive && w.semanticLabel == 'Invite human',
        );
        final tokens = RaftTokens.of(t.element(menu));
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1000, 700));
        await mouse.moveTo(t.getCenter(invite));
        await t.pump();
        Color? actionBackground() => t
            .widgetList<Container>(
              find.descendant(of: invite, matching: find.byType(Container)),
            )
            .firstWhere((w) => w.constraints?.maxHeight == 36)
            .color;
        expect(
          actionBackground(),
          family == RaftFamily.brutal
              ? tokens.product.brutalPink
              : tokens.colors['primary-soft'],
        );
        await mouse.moveTo(const Offset(1000, 700));
        await mouse.removePointer();
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        final row = find.byKey(const ValueKey('server-menu-row-visual'));
        expect(t.getSize(row).height, 48);
        expect(
          t
              .widget<RaftInteractive>(
                find.descendant(
                  of: row,
                  matching: find.byType(RaftInteractive),
                ),
              )
              .semanticLabel,
          'Visual Server',
        );
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(current, 1);
        expect(menu, findsNothing);
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(menu, findsNothing);
        final trigger = t.widget<RaftInteractive>(
          find.byKey(const Key('rail-workspace')),
        );
        expect(trigger.focusNode!.hasFocus, isFalse);
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        await t.tap(find.text('Outside'));
        await t.pumpAndSettle();
        expect(menu, findsNothing);
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        await t.tap(find.text('Switch or Create Server'));
        await t.pumpAndSettle();
        expect(global, 1);
        expect(menu, findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      '$family/$dark long server list scrolls while Source footer stays reachable and Activity unknown remains absent',
      (t) async {
        t.view.physicalSize = const Size(1280, 240);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final controller = RaftMenuController();
        addTearDown(controller.dispose);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 64,
                  child: RaftServerSwitcher(
                    controller: controller,
                    workspaceName: 'Visual',
                    label: 'Switch workspace',
                    rows: [
                      for (var i = 0; i < 20; i++)
                        RaftServerMenuRow(
                          id: '$i',
                          name: 'Server $i',
                          slug: 'server-$i',
                          activityUnreadCount: i == 1 ? 101 : null,
                          pushMuted: i == 1,
                          onSelected: () {},
                        ),
                    ],
                    actions: [
                      RaftMenuEntry(
                        label: 'Switch or Create Server',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        final menu = t.getRect(find.byKey(const Key('server-switcher-menu')));
        expect(menu.height, 224);
        expect(
          menu.top,
          4,
        ); // Anchored top already inside Source's gutter rule.
        expect(find.text('99+'), findsOneWidget);
        final footer = t.getRect(find.text('Switch or Create Server'));
        expect(footer.bottom, lessThanOrEqualTo(240));
        await t.drag(
          find.byKey(const Key('server-menu-list')),
          const Offset(0, -400),
        );
        await t.pumpAndSettle();
        expect(
          t.getRect(find.text('Switch or Create Server')) == footer,
          isTrue,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
