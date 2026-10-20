import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web v1.21.12 LeftRail publicProjection: the public server rail runs the same
// AppRail chrome as the signed-in rail on every theme (the soft-signal strip and
// the black logo block are gone).
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('[$family/$dark] public rail is the app rail', (tester) async {
      var chat = 0, settings = 0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 700);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RaftPublicRail(
                header: const SizedBox(
                  key: ValueKey('header'),
                  width: 40,
                  height: 40,
                ),
                chatLabel: 'Chat',
                settingsLabel: 'Settings',
                chatSelected: true,
                settingsSelected: false,
                onChat: () => chat++,
                onSettings: () => settings++,
              ),
            ),
          ),
        ),
      );
      final tokens = RaftTokens.of(tester.element(find.byType(RaftPublicRail)));
      expect(find.byType(RaftWorkspaceRail), findsOneWidget);
      expect(find.byKey(const ValueKey('header')), findsOneWidget);
      expect(find.byKey(const ValueKey('rail-chat')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('public-rail-settings')),
        findsOneWidget,
      );
      // The rail's own ground, on every theme: not the brand strip.
      final ground = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .whereType<Color>();
      expect(ground, isNot(contains(tokens.product.softSignal)));

      await tester.tap(find.byKey(const ValueKey('rail-chat')));
      await tester.tap(find.byKey(const ValueKey('public-rail-settings')));
      expect(chat, 1);
      expect(settings, 1);
      // The signed-in rail's width for the theme, not the old fixed 64.
      expect(
        tester.getSize(find.byType(RaftWorkspaceRail)).width,
        RaftRailRecipe(tokens, viewportHeight: 700).width,
      );
    });
  }
}
