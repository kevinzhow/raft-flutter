import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Actual Source LeftRail.tsx567–630 + AppRailRoot, DPR1 DOM:
// Brutal width64/border-right2 => child width62, 40px button x11.
// Elegant width56/no border => child width56, 40px button x8.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} rail content honors its real CSS border box',
      (t) async {
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final theme = raftTheme(dark: dark);
        final tokens = theme.extension<RaftTokens>()!;
        final width = RaftRailRecipe(tokens, viewportHeight: 800).width;
        var routeCalls = 0, footerCalls = 0;
        final semantics = t.ensureSemantics();
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.desktop,
                child: RepaintBoundary(
                  key: const ValueKey('rail-paint'),
                  child: SizedBox(
                    width: width,
                    child: RaftWorkspaceRail(
                      workspaceName: 'Visual',
                      onWorkspace: () {},
                      selected: 'chat',
                      destinations: const [
                        RaftRailDestination(
                          id: 'chat',
                          label: 'Chat',
                          glyph: RaftGlyph.messageSquare,
                        ),
                      ],
                      onSelected: (_) => routeCalls++,
                      footer: RaftWorkspaceRailFooter(
                        children: [
                          RaftWorkspaceRailAction(
                            label: 'Settings',
                            glyph: RaftGlyph.settings,
                            onPressed: () => footerCalls++,
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
        final expected = 8.0;
        final primary = find.byKey(const ValueKey('rail-chat'));
        final footer = find.descendant(
          of: find.byType(RaftWorkspaceRailFooter),
          matching: find.byType(RaftWorkspaceRailAction),
        );
        expect(t.getRect(primary).left, expected);
        expect(t.getRect(footer).left, expected);
        expect(t.getSize(primary), const Size(40, 40));
        expect(t.getSize(footer), const Size(40, 40));
        expect(t.getSize(find.byType(RaftWorkspaceRail)).width, width);
        // Real AppRailRoot uses bg-primary -> --primary-400, not the
        // product's Button primary alias (#FFD440). Source blank-rail pixels:
        // Mounted Raft frame light #FFD440; dark #0D0D0B.
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('rail-paint')),
        );
        final pixel = await t.runAsync(() async {
          final image = await boundary.toImage();
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final offset = (100 * image.width + 2) * 4;
          final pixel = rgba.buffer.asUint8List(offset, 4).toList();
          image.dispose();
          return pixel;
        });
        expect(pixel, dark ? [13, 13, 11, 255] : [255, 212, 64, 255]);
        await t.tapAt(t.getCenter(primary));
        await t.tapAt(t.getCenter(footer));
        expect(routeCalls, 1);
        expect(footerCalls, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(t.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
  testWidgets(
    'theme change preserves the actual footer state owner while border width changes',
    (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Future<void> mount({bool dark = false}) => t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: RaftDensityScope(
              density: RaftDensity.desktop,
              child: SizedBox(
                width: 56,
                child: RaftWorkspaceRail(
                  workspaceName: 'Visual',
                  onWorkspace: () {},
                  selected: 'chat',
                  destinations: const [],
                  onSelected: (_) {},
                  footer: RaftWorkspaceRailFooter(
                    children: [
                      RaftWorkspaceHelpMenu(
                        label: 'Help',
                        heading: 'Resources',
                        entries: [
                          RaftMenuEntry(
                            label: 'Documentation',
                            onPressed: () {},
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
      );
      await mount();
      await t.pumpAndSettle();
      final state = t.state(find.byType(RaftWorkspaceHelpMenu));
      await mount();
      await t.pumpAndSettle();
      expect(t.state(find.byType(RaftWorkspaceHelpMenu)), same(state));
      await mount(dark: true);
      await t.pumpAndSettle();
      expect(t.state(find.byType(RaftWorkspaceHelpMenu)), same(state));
      await mount();
      await t.pumpAndSettle();
      expect(t.state(find.byType(RaftWorkspaceHelpMenu)), same(state));
      expect(t.takeException(), isNull);
    },
  );
}
