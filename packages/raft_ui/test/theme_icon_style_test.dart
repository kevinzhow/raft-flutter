import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

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

BoxDecoration _paint(WidgetTester t) {
  final old = find.descendant(
    of: find.byType(RaftIconButton),
    matching: find.byType(AnimatedContainer),
  );
  if (old.evaluate().isNotEmpty)
    return t.widget<AnimatedContainer>(old.first).decoration! as BoxDecoration;
  final root = find.descendant(
    of: find.byType(RaftIconButton),
    matching: find.byType(DecoratedBox),
  );
  final decoration =
      t.widget<DecoratedBox>(root.first).decoration as BoxDecoration;
  final shadows = t
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(RaftIconButton),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((paint) => paint.painter)
      .whereType<RaftOuterShadowPainter>()
      .expand((p) => p.shadows)
      .toList();
  return decoration.copyWith(boxShadow: shadows);
}

Matrix4 _transform(WidgetTester t) {
  final old = find.byType(AnimatedContainer);
  if (old.evaluate().isNotEmpty)
    return t.widget<AnimatedContainer>(old.first).transform!;
  return t
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(RaftIconButton),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;
}

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
      expect(_transform(t).entry(1, 3), -1);
      final down = await t.startGesture(
        t.getCenter(find.byType(RaftIconButton)),
      );
      await t.pump(const Duration(milliseconds: 500));
      expect(_paint(t).boxShadow!.single.offset, const Offset(1, 1));
      final transform = _transform(t);
      expect(transform.entry(0, 0), 1);
      expect(transform.entry(0, 3), 1);
      expect(transform.entry(1, 3), 1);
      await down.cancel();
      await mouse.removePointer();
      await t.pumpWidget(const SizedBox.shrink());
    },
    skip: raftLookSkip(raftLookBrutal),
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
    skip: raftLookSkip(raftLookBrutal),
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
    final transform = _transform(t);
    expect(transform.entry(0, 0), 1);
    expect(transform.entry(1, 1), 1);
    expect(transform.entry(0, 3), 0);
    expect(transform.entry(1, 3), 0);
    await down.cancel();
    await mouse.removePointer();
    await t.pumpWidget(const SizedBox.shrink());
  }, skip: raftLookSkip(raftLookBrutal));

  test('dark hover ink preserves the original calibrated float components', () {
    // a57b9dab semantic_colors.g.dart:1111; not values.json's display rounding.
    for (final pack in [builtInElegantTheme, builtInBrutalTheme]) {
      final ink = RaftTokens.theme(pack: pack, dark: true).colors['ink-4']!;
      expect(ink.a, closeTo(.039203, 1e-12));
      expect(ink.r, closeTo(.954685, 1e-12));
      expect(ink.g, closeTo(.954685, 1e-12));
      expect(ink.b, closeTo(.969524, 1e-12));
    }
  }, skip: raftLookSkip(raftLookElegant, raftLookBrutal));

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
              'options': {
                'press.effect': 'offsetShadow',
                'iconButton.surface': 'raised',
              },
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
  for (final configuration in [
    (surface: 'generic', effect: 'offsetShadow'),
    (surface: 'raised', effect: 'scale'),
  ]) {
    testWidgets(
      '${configuration.surface} surface and ${configuration.effect} press are independent',
      (t) async {
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        final pack = RaftThemePack.parse(
          jsonEncode({
            'format': raftThemePackFormat,
            'id': 'user:mixed-icon',
            'name': {'en': 'Mixed icon'},
            'version': '1',
            'extends': 'raft',
            'modes': {
              'light': {
                'options': {
                  'iconButton.surface': configuration.surface,
                  'press.effect': configuration.effect,
                },
                'geometry': {'stroke.control': 2, 'radius.controlSmall': 7},
                'shadows': {'sm': '5px 6px 0px 0px #123456'},
              },
              'dark': {},
            },
          }),
        );
        await t.pumpWidget(_host(pack: pack));
        await t.pumpAndSettle();
        final tokens = RaftTokens.of(t.element(find.byType(RaftIconButton)));
        final generic = RaftControlRecipe(
          tokens,
          variant: RaftControlVariant.outline,
          visualHeight: 24,
        );
        final raised = configuration.surface == 'raised';
        expect(_paint(t).border?.top.width ?? 0, raised ? 2 : 0);
        expect(
          _paint(t).borderRadius,
          raised ? BorderRadius.circular(7) : generic.radius,
        );
        expect(
          _paint(t).boxShadow,
          raised
              ? [
                  const BoxShadow(
                    offset: Offset(5, 6),
                    color: Color(0xff123456),
                  ),
                ]
              : generic.shadows(),
        );
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(t.getCenter(find.byType(RaftIconButton)));
        await t.pumpAndSettle();
        final down = await t.startGesture(
          t.getCenter(find.byType(RaftIconButton)),
        );
        await t.pump(const Duration(milliseconds: 500));
        final transform = _transform(t);
        final offset = configuration.effect == 'offsetShadow';
        expect(transform.entry(0, 0), offset ? 1 : .985);
        expect(transform.entry(0, 3), offset ? 1 : 0);
        expect(transform.entry(1, 3), offset ? 1 : 0);
        await down.cancel();
        await mouse.removePointer();
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
