import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The appearance setting, end to end: Raft is the only look, and the user picks
/// Light, Dark or System.
void main() {
  group('appearance', () {
    test('Raft paints its own values in both modes', () {
      final light = RaftTokens.theme(pack: packForThemeId(raftThemePackId));
      final dark = RaftTokens.theme(
        dark: true,
        pack: packForThemeId(raftThemePackId),
      );
      expect(light.dark, isFalse);
      expect(dark.dark, isTrue);
      expect(light.ink, isNot(dark.ink));
      // Radius and stroke widths come from the Raft pack.
      expect(light.radius, 8);
      expect(light.border, 1);
    });

    test('an unknown theme id falls back to Raft instead of failing', () {
      // A stored id can outlive the theme it names; painting the default look
      // beats a blank window.
      final fallback = packForThemeId('no-such-theme');
      expect(fallback.id, raftThemePackId);
      expect(packForThemeId(null).id, raftThemePackId);
      expect(packForThemeId('elegant').id, raftThemePackId);
      expect(packForThemeId('brutal').id, raftThemePackId);
    });

    test('the appearance is the mode; the pack is always Raft', () {
      const appearance = RaftAppearance(mode: ThemeMode.dark);
      expect(appearance.copyWith(mode: ThemeMode.light).mode, ThemeMode.light);
      expect(appearance.copyWith().mode, ThemeMode.dark);
      expect(appearance.pack.id, raftThemePackId);
      // The default is the Raft look in System mode.
      const defaults = RaftAppearance();
      expect(defaults.mode, ThemeMode.system);
      expect(defaults.pack.id, raftThemePackId);
    });
  });

  group('switching modes keeps the session intact', () {
    testWidgets('an open route and its entered text survive a mode change', (
      tester,
    ) async {
      // MaterialApp swaps `theme`/`darkTheme` in place; the Navigator and the
      // fields under it must not be rebuilt from scratch, or a user changing
      // the mode mid-message would lose the draft and the page behind it.
      final text = TextEditingController();
      addTearDown(text.dispose);
      var dark = false;
      late StateSetter setOuter;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return MaterialApp(
              theme: raftTheme(dark: dark),
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

      await tester.enterText(
        find.byKey(const Key('draft-field')),
        'half a message',
      );
      await tester.pump();

      // Change the mode while the composer is open.
      setOuter(() => dark = true);
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
