import 'package:flutter/material.dart';
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
      testWidgets('$pack/$dark adjacent entries retain CSS flow margins', (
        t,
      ) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var activity = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack), dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  RaftNavItem(
                    label: 'Search',
                    glyph: RaftGlyph.search,
                    role: RaftNavItemRole.search,
                    onTap: () {},
                  ),
                  RaftNavItem(
                    label: 'Activity',
                    glyph: RaftGlyph.activity,
                    role: RaftNavItemRole.activity,
                    precededByEntry: true,
                    onTap: () => activity++,
                  ),
                  RaftNavItem(
                    label: 'Saved',
                    glyph: RaftGlyph.bookmark,
                    role: RaftNavItemRole.saved,
                    precededByEntry: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        final controls = find.byType(RaftControl);
        final tokens = RaftTokens.of(t.element(controls.first));
        final top = tokens.size('space.sidebarEntryMarginTop', fallback: 0);
        final bottom = tokens.size(
          'space.sidebarEntryMarginBottom',
          fallback: 4,
        );
        final gap = top > bottom ? top : bottom;
        for (var i = 1; i < 3; i++) {
          expect(
            t.getRect(controls.at(i)).top -
                t.getRect(controls.at(i - 1)).bottom,
            gap,
          );
        }
        // Frozen Elegant/Brutal have only a 4px bottom margin. Their original
        // bounds stay unchanged when the host opts into block flow.
        if (pack != raftThemePackId) {
          expect(top, 0);
          expect(bottom, 4);
        }
        await t.tap(controls.at(1));
        expect(activity, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }
}
