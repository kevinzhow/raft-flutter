import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final pack in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('$pack/$dark entry icon is independent of its label', (
        t,
      ) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack), dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  for (final role in [
                    RaftNavItemRole.search,
                    RaftNavItemRole.activity,
                    RaftNavItemRole.saved,
                  ])
                    RaftNavItem(
                      label: role.name,
                      role: role,
                      glyph: switch (role) {
                        RaftNavItemRole.search => RaftGlyph.search,
                        RaftNavItemRole.activity => RaftGlyph.activity,
                        _ => RaftGlyph.bookmark,
                      },
                      onTap: () {},
                    ),
                ],
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(380, 800));
        for (final glyph in [
          RaftGlyph.search,
          RaftGlyph.activity,
          RaftGlyph.bookmark,
        ]) {
          final icon = find.byWidgetPredicate(
            (w) => w is RaftIcon && w.glyph == glyph,
          );
          final tokens = RaftTokens.of(t.element(icon));
          expect(
            IconTheme.of(t.element(icon)).color,
            pack == raftThemePackId
                ? tokens.colors['foreground-hint']
                : glyph == RaftGlyph.bookmark
                ? tokens.muted
                : tokens.strong,
          );
          await mouse.moveTo(t.getCenter(icon));
          await t.pumpAndSettle();
          expect(
            IconTheme.of(t.element(icon)).color,
            pack == raftThemePackId
                ? tokens.colors['foreground-hint']
                : glyph == RaftGlyph.bookmark
                ? tokens.ink
                : tokens.strong,
          );
          await mouse.moveTo(const Offset(380, 800));
          await t.pumpAndSettle();
        }
        await mouse.removePointer();
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
      testWidgets('$pack/$dark section action uses its own foreground', (
        t,
      ) async {
        var actions = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack), dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 240,
                child: RaftSidebarSectionHeader(
                  label: 'Pinned',
                  expanded: true,
                  onExpandedChanged: (_) {},
                  actions: [
                    RaftSidebarSectionAction(
                      label: 'Sort',
                      glyph: RaftGlyph.arrowUpDown,
                      onPressed: () => actions++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final icon = find.byWidgetPredicate(
          (w) => w is RaftIcon && w.glyph == RaftGlyph.arrowUpDown,
        );
        final context = t.element(icon),
            tokens = RaftTokens.of(t.element(icon));
        // Mounted SidebarSectionControl's Button CSS overrides the Lucide
        // size={16} attribute to 18px. Frozen a57 controls keep 14px.
        expect(
          t.widget<RaftIcon>(icon).size,
          pack == raftThemePackId ? 18 : 14,
        );
        // Current SidebarSectionControl is a ghost Button; a57's btn-flat-sm
        // keeps its muted default and brightens on hover/focus.
        expect(
          IconTheme.of(context).color,
          pack == raftThemePackId ? tokens.strong : tokens.muted,
        );
        await t.tap(icon);
        expect(actions, 1);
        await t.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
