import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_theme/raft_theme.dart' show RaftFontSpec, builtInRaftTheme;
import 'package:raft_ui/test_themes.dart';

/// Each theme paints its own typeface.
///
/// `RaftTokenSet.fromPack` used to ignore the pack's `fonts`, so every theme drew
/// the built-in Raft stack (Space Grotesk / Space Mono). Page scores exposed it:
/// `elegant-dark` measured 17.9% pixel-perfect against the a57b9dab baseline while
/// `elegant` measured 72.4%, and the only difference in the capture metadata was
/// `fontFamily: Inter -> SpaceGrotesk`. The fonts were already bundled; nothing
/// read them.
///
/// These tests pin both halves: each look gets its own families, and Raft's are
/// untouched.
RaftTokens _tokens(String id) => RaftTokens.theme(pack: packForThemeId(id));

void main() {
  group('theme fonts come from the theme pack', () {
    test('Raft keeps Space Grotesk and Space Mono', () {
      final t = _tokens(raftThemePackId);
      expect(t.headingFont, 'packages/raft_ui/SpaceGrotesk');
      expect(t.bodyFont, 'packages/raft_ui/SpaceGrotesk');
      expect(t.monoFont, 'packages/raft_ui/SpaceMono');
    });

    test('Elegant uses its own Geist / Inter families', () {
      final t = _tokens(elegantThemePackId);
      expect(t.headingFont, 'packages/raft_ui/Inter');
      expect(t.bodyFont, 'packages/raft_ui/Geist');
      expect(t.monoFont, 'packages/raft_ui/GeistMono');
    }, skip: raftLookSkip(raftLookElegant));

    test('Brutal uses HankenGrotesk, as a57b9dab did', () {
      // Corrected: the pack first claimed Space Grotesk, but a57b9dab's generated
      // metrics set headingFont and sansFont to HankenGrotesk, and a Brutal page
      // in the P2 baseline reports exactly that family. Brutal is not Raft with a
      // dark palette -- its typeface differs too.
      final t = _tokens(brutalThemePackId);
      expect(t.headingFont, 'packages/raft_ui/HankenGrotesk');
      expect(t.bodyFont, 'packages/raft_ui/HankenGrotesk');
      expect(t.monoFont, 'packages/raft_ui/GeistMono');
    }, skip: raftLookSkip(raftLookBrutal));

    test('unknown user font families are not rewritten', () {
      final set = RaftTokenSet.fromPack(
        RaftThemeId.light,
        mode: builtInRaftTheme.light,
        fonts: const {
          'heading': RaftFontSpec(family: 'User Serif', stack: ['User Serif']),
        },
      );
      expect(set.metrics.headingFont, 'User Serif');
    });

    test('the three themes do not all share one heading family', () {
      // The bug was that they did. A single family across all three looks means
      // the pack fonts stopped being read.
      final families = {
        for (final id in [
          raftThemePackId,
          elegantThemePackId,
          brutalThemePackId,
        ])
          _tokens(id).headingFont,
      };
      expect(families, isNot(hasLength(1)), reason: 'families: $families');
    }, skip: raftLookSkip(raftLookElegant, raftLookBrutal));

    test('the stacks carry the declared family first', () {
      // A family name without its stack would fall back to the platform default
      // for every glyph the family misses.
      final t = _tokens(elegantThemePackId);
      expect(t.metrics.headingFontStack.first, 'Inter');
      expect(t.metrics.sansFontStack.first, 'Geist');
      expect(t.metrics.monoFontStack.first, 'Geist Mono');
    }, skip: raftLookSkip(raftLookElegant));

    testWidgets('the first painted frame already uses the theme font', (
      tester,
    ) async {
      // docs/theme-flash.md: a frame painted in the previous look is a flash.
      // Reading the pack fonts synchronously is what prevents it, so the very
      // first frame -- one pump, no settle -- must carry the right family.
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
          home: const Scaffold(body: Text('Settings')),
        ),
      );
      final text = tester.widget<Text>(find.text('Settings'));
      final style = DefaultTextStyle.of(tester.element(find.text('Settings')))
          .style
          .merge(text.style);
      expect(style.fontFamily, isNot('Space Grotesk'));
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .textTheme
            .titleLarge!
            .fontFamily,
        'packages/raft_ui/Inter',
      );
    }, skip: raftLookSkip(raftLookElegant));
  });
}
