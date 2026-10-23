import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host({
  RaftThemePack? pack,
  RaftControlVariant variant = RaftControlVariant.outline,
  bool reducedMotion = false,
}) => MaterialApp(
  themeAnimationDuration: Duration.zero,
  theme: raftTheme(pack: pack ?? builtInBrutalTheme),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: RaftDensityScope(
        density: RaftDensity.desktop,
        child: RaftIconButton(
          visualSize: 24,
          glyph: RaftGlyph.plus,
          variant: variant,
          onPressed: () {},
        ),
      ),
    ),
  ),
);

BoxDecoration _paint(WidgetTester t) =>
    t.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration!
        as BoxDecoration;

void main() {
  testWidgets(
    'source small square icon border and hard shadow respond to input',
    (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      await t.pumpWidget(_host());
      await t.pumpAndSettle();
      expect(_paint(t).border!.top.width, 2);
      expect(_paint(t).border!.top.style, BorderStyle.solid);
      expect(_paint(t).borderRadius, BorderRadius.zero);
      expect(_paint(t).boxShadow!.single.offset, const Offset(2, 2));
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(find.byType(RaftIconButton)));
      await t.pumpAndSettle();
      expect(_paint(t).boxShadow!.single.offset, const Offset(4, 4));
      expect(
        t
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .transform!
            .entry(1, 3),
        -1,
      );
      final down = await t.startGesture(
        t.getCenter(find.byType(RaftIconButton)),
      );
      await t.pump(const Duration(milliseconds: 500));
      expect(_paint(t).boxShadow!.single.offset, const Offset(1, 1));
      final transform = t
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .transform!;
      expect(transform.entry(0, 0), 1);
      expect(transform.entry(0, 3), 1);
      expect(transform.entry(1, 3), 1);
      await down.cancel();
      await mouse.removePointer();
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'source small square ghost reserves its border and has no hover fill',
    (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      await t.pumpWidget(_host(variant: RaftControlVariant.ghost));
      await t.pumpAndSettle();
      expect(_paint(t).border!.top.width, 2);
      expect(_paint(t).border!.top.color, Colors.transparent);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(find.byType(RaftIconButton)));
      await t.pumpAndSettle();
      final tokens = RaftTokens.of(t.element(find.byType(RaftIconButton)));
      expect(_paint(t).border!.top.color, tokens.colors['line-strong']);
      expect(_paint(t).color, Colors.transparent);
      expect(_paint(t).boxShadow, isEmpty);
      await mouse.removePointer();
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reduced motion keeps the offset-shadow surface stationary', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(_host(reducedMotion: true));
    await t.pumpAndSettle();
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.byType(RaftIconButton)));
    await t.pumpAndSettle();
    final down = await t.startGesture(t.getCenter(find.byType(RaftIconButton)));
    await t.pump();
    final transform = t
        .widget<AnimatedContainer>(find.byType(AnimatedContainer))
        .transform!;
    expect(transform.entry(0, 0), 1);
    expect(transform.entry(1, 1), 1);
    expect(transform.entry(0, 3), 0);
    expect(transform.entry(1, 3), 0);
    await down.cancel();
    await mouse.removePointer();
    await t.pumpWidget(const SizedBox.shrink());
  });

  test('dark hover ink preserves the original calibrated float components', () {
    // a57b9dab semantic_colors.g.dart:1111; not values.json's display rounding.
    for (final pack in [builtInElegantTheme, builtInBrutalTheme]) {
      final ink = RaftTokens.theme(pack: pack, dark: true).colors['ink-4']!;
      expect(ink.a, closeTo(.039203, 1e-12));
      expect(ink.r, closeTo(.954685, 1e-12));
      expect(ink.g, closeTo(.954685, 1e-12));
      expect(ink.b, closeTo(.969524, 1e-12));
    }
  });

  testWidgets(
    'custom small icon structure reads authored border radius and shadow',
    (t) async {
      final pack = RaftThemePack.parse(
        jsonEncode({
          'format': raftThemePackFormat,
          'id': 'user:small-square',
          'name': {'en': 'Small square'},
          'version': '1',
          'extends': 'raft',
          'modes': {
            'light': {
              'options': {'press.effect': 'offsetShadow'},
              'geometry': {'stroke.control': 3, 'radius.controlSmall': 7},
              'shadows': {'sm': '5px 6px 0px 0px #123456'},
            },
            'dark': {},
          },
        }),
      );
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      await t.pumpWidget(_host(pack: pack));
      await t.pumpAndSettle();
      expect(_paint(t).border!.top.width, 3);
      expect(_paint(t).borderRadius, BorderRadius.circular(7));
      expect(_paint(t).boxShadow!.single.offset, const Offset(5, 6));
      expect(_paint(t).boxShadow!.single.color, const Color(0xff123456));
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
