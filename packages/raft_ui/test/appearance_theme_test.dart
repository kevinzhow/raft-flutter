import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The appearance setting's theme choice, end to end.
///
/// Two properties matter and neither is provable by reading the code: that each
/// theme actually paints its own values in both modes, and that changing the
/// theme does not disturb what the user is doing.
void main() {
  group('theme choice', () {
    test('each built-in theme paints its own values in both modes', () {
      // The three looks differ first and foremost in ink; a theme that resolved
      // to the same ink as another would mean the pack was not reaching the
      // token set.
      for (final dark in [false, true]) {
        final inks = <String, Color>{
          for (final theme in builtInAppearanceThemes)
            theme.id: RaftTokens.theme(dark: dark, pack: packForThemeId(theme.id))
                .ink,
        };
        expect(inks, hasLength(3));
        // Distinct within a mode: any two themes painting the same ink means
        // one of them silently fell back to another.
        final distinct = inks.values.toSet();
        expect(
          distinct.length,
          inks.length,
          reason: '${dark ? 'dark' : 'light'} inks collide: $inks',
        );
      }
    });

    test('the chosen pack supplies the values, not the default pack', () {
      final raft = RaftTokens.theme(pack: packForThemeId(raftThemePackId));
      final elegant = RaftTokens.theme(pack: packForThemeId(elegantThemePackId));
      final brutal = RaftTokens.theme(pack: packForThemeId(brutalThemePackId));

      // Values taken from the contract tables for each family.
      expect(elegant.ink, isNot(raft.ink));
      expect(brutal.ink, isNot(raft.ink));

      // Radius is the clearest structural tell: Raft 8, Elegant 6, Brutal 0.
      expect(raft.radius, 8);
      expect(elegant.radius, 6);
      expect(brutal.radius, 0);
      // Stroke widths come from the same pack: Raft 1, Brutal 2.
      expect(raft.border, 1);
      expect(brutal.border, 2);
    });

    test('Brutal dark uses the Elegant dark values, as decided', () {
      // Kevin's decision recorded in the contract: Brutal has no dark look of
      // its own. The pack writes its light column twice, so Brutal dark equals
      // Brutal light rather than falling back to Raft dark.
      final brutalDark = RaftTokens.theme(dark: true, pack: packForThemeId(brutalThemePackId));
      final brutalLight = RaftTokens.theme(pack: packForThemeId(brutalThemePackId));
      expect(brutalDark.ink, brutalLight.ink);

      final raftDark = RaftTokens.theme(dark: true, pack: packForThemeId(raftThemePackId));
      expect(brutalDark.ink, isNot(raftDark.ink));
    });

    test('an unknown theme id falls back to Raft instead of failing', () {
      // A stored id can outlive the theme it names; painting the default look
      // beats a blank window.
      final fallback = packForThemeId('no-such-theme');
      expect(fallback.id, raftThemePackId);
      expect(packForThemeId(null).id, raftThemePackId);
    });

    test('theme and mode are independent', () {
      const appearance = RaftAppearance(
        mode: ThemeMode.dark,
        themeId: elegantThemePackId,
      );
      expect(appearance.copyWith(mode: ThemeMode.light).themeId,
          elegantThemePackId);
      expect(appearance.copyWith(themeId: brutalThemePackId).mode,
          ThemeMode.dark);
      // The default is the Raft look in System mode, so existing call sites and
      // every stored profile from before this change keep their appearance.
      const defaults = RaftAppearance();
      expect(defaults.themeId, raftThemePackId);
      expect(defaults.mode, ThemeMode.system);
    });
  });

  group('switching themes keeps the session intact', () {
    testWidgets('an open route and its entered text survive a theme change',
        (tester) async {
      // MaterialApp swaps `theme`/`darkTheme` in place; the Navigator and the
      // fields under it must not be rebuilt from scratch, or a user changing
      // the theme mid-message would lose the draft and the page behind it.
      final text = TextEditingController();
      addTearDown(text.dispose);
      var themeId = raftThemePackId;
      late StateSetter setOuter;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return MaterialApp(
              theme: raftTheme(pack: packForThemeId(themeId)),
              home: const Scaffold(body: Text('root page')),
            );
          },
        ),
      );

      // Open a second route the way the app does, then type into it.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Column(
              children: [
                const Text('composer page'),
                TextField(controller: text, key: const Key('draft-field')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('composer page'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('draft-field')), 'half a message');
      await tester.pump();

      // Change the theme while the composer is open.
      setOuter(() => themeId = elegantThemePackId);
      await tester.pumpAndSettle();

      // The pushed route is still on top, not popped back to the root.
      expect(find.text('composer page'), findsOneWidget);
      expect(find.text('root page'), findsNothing);
      // And the draft is still there.
      expect(text.text, 'half a message');
      expect(find.text('half a message'), findsOneWidget);
    });
  });
}
