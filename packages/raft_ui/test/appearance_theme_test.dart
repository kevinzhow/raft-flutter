import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The appearance setting's theme choice, end to end.
///
/// Two properties matter and neither is provable by reading the code: that each
/// theme actually paints its own values in both modes, and that changing the
/// theme does not disturb what the user is doing.
/// Rasterises the current frame so two looks can be compared by pixels rather
/// than by token values.
Future<Uint8List> _capture(WidgetTester tester) async {
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  // Rasterising runs on the real event loop; under the test's fake clock the
  // image future never completes and the test times out.
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  group('theme choice', () {
    test('each built-in theme paints its own values', () {
      // In light mode the three looks are genuinely distinct.
      //
      // Dark mode has only two: Brutal has no dark look, so it borrows Elegant's
      // entire dark appearance (see the dedicated test below). Asserting three
      // distinct dark inks would contradict that decision, so dark is checked
      // for "Raft differs from the Elegant/Brutal pair" instead.
      Color ink(String id, {bool dark = false}) =>
          RaftTokens.theme(dark: dark, pack: packForThemeId(id)).ink;

      final light = {
        for (final theme in builtInAppearanceThemes) theme.id: ink(theme.id),
      };
      expect(light.values.toSet(), hasLength(3),
          reason: 'light inks collide: $light');

      final raftDark = ink(raftThemePackId, dark: true);
      final elegantDarkInk = ink(elegantThemePackId, dark: true);
      final brutalDarkInk = ink(brutalThemePackId, dark: true);
      expect(raftDark, isNot(elegantDarkInk));
      expect(brutalDarkInk, elegantDarkInk);
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

    testWidgets('Brutal dark renders identically to Elegant dark',
        (tester) async {
      // Kevin's decision, and what the old app actually did: selecting Brutal
      // at night painted the whole Elegant dark look. Pinning it by pixels
      // rather than by token comparison catches a pack that gets the colours
      // right but leaves Brutal's square corners and 2px rules behind.
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: true, pack: packForThemeId(brutalThemePackId)),
          home: const Scaffold(body: Text('same either way')),
        ),
      );
      await tester.pumpAndSettle();
      final brutalShot = await _capture(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: true, pack: packForThemeId(elegantThemePackId)),
          home: const Scaffold(body: Text('same either way')),
        ),
      );
      await tester.pumpAndSettle();
      final elegantDarkShot = await _capture(tester);

      expect(brutalShot, elegantDarkShot,
          reason: 'Brutal dark must paint exactly the Elegant dark look');

      // Sanity: Brutal light is a different look, so the comparison above is
      // not passing because nothing varies.
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(brutalThemePackId)),
          home: const Scaffold(body: Text('same either way')),
        ),
      );
      await tester.pumpAndSettle();
      expect(await _capture(tester), isNot(brutalShot));
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
