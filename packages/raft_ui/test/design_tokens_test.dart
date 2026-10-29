import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  test('RaftTokens exposes every tier per theme', () {
    for (final (dark, id) in raftThemeMatrix([
      (false, RaftThemeId.light),
      (true, RaftThemeId.dark),
    ], full: true)) {
      final t = raftTheme(dark: dark).extension<RaftTokens>()!;
      final set = RaftTokenSet.of(id);
      expect(t.tokenSet, same(set));
      expect(t.semantic, same(set.colors));
      expect(t.themeShadows, same(set.shadows));
      expect(t.metrics, same(set.metrics));
      expect(t.colors['foreground'], set.colors.foreground);
      expect(t.colors['button-default-fill'], set.components.buttonDefaultFill);
      expect(
        t.colors['color-brutal-yellow-400'],
        RaftPrimitiveColors.brutalYellow400,
      );
    }
  });

  testWidgets('RaftTokens.of resolves the ThemeExtension', (tester) async {
    late RaftTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: true),
        home: Builder(
          builder: (context) {
            tokens = RaftTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tokens.tokenSet.id, RaftThemeId.dark);
    // The 0.7.1 field metrics (16/24) are applied; the card title keeps Elegant's 16/22/500 (see
    // raft_token_mapping.dart).
    expect(tokens.metrics.fieldFontSize, 16);
    expect(tokens.metrics.cardTitleLineHeight, 22);
  });

  test('inset shadow layers are separated from BoxShadows', () {
    const shadow = RaftShadow([
      RaftCssShadow(
        inset: true,
        offset: Offset(0, 1),
        blur: 0,
        spread: 0,
        color: Color(0x0dfafaf7),
      ),
      RaftCssShadow(
        inset: false,
        offset: Offset(0, 0),
        blur: 0,
        spread: 1,
        color: Color(0x66000000),
      ),
      RaftCssShadow(
        inset: false,
        offset: Offset(0, 1),
        blur: 3,
        spread: 0,
        color: Color(0x38000000),
      ),
    ]);
    expect(shadow.layers, hasLength(3));
    expect(shadow.inset, hasLength(1));
    expect(shadow.inset.single.offset, const Offset(0, 1));
    expect(shadow.outer, hasLength(2));
    expect(shadow.paintOrder, shadow.outer.reversed.toList());
  });

  test('raft-ui 0.7.1 elevation: controls cast nothing, overlays float', () {
    for (final id in RaftThemeId.values) {
      final set = RaftTokenSet.of(id);
      final float = id == RaftThemeId.dark
          ? RaftDark.elevationFloat
          : RaftLight.elevationFloat;
      for (final control in [set.shadows.xs, set.shadows.sm, set.shadows.md]) {
        expect(control.layers, isEmpty, reason: '$id');
      }
      // The pack builds its own shadow objects, so compare the layers rather
      // than the instance: the values are what a theme can change.
      String css(RaftShadow shadow) => [
        for (final layer in shadow.layers)
          '${layer.inset}|${layer.offset.dx},${layer.offset.dy}|'
              '${layer.blur}|${layer.spread}|${layer.color.toARGB32()}',
      ].join(',');
      expect(css(set.shadows.lg), css(float), reason: '$id');
      expect(css(set.shadows.xl), css(float), reason: '$id');
    }
  });

  test('metrics and Tailwind scale', () {
    final metrics = RaftTokenSet.light.metrics;
    expect(metrics.fieldFontSize, 16);
    expect(metrics.fieldLineHeight, 24);
    expect(metrics.cardTitleFontWeight, 500);
    // The Space Grotesk / Space Mono faces are a follow-up; Elegant's carry on.
    expect(metrics.headingFontStack.first, 'Space Grotesk');
    expect(metrics.sansFont, 'packages/raft_ui/SpaceGrotesk');
    expect(RaftScale.spacing, 4);
    expect(RaftScale.radius['md'], 6);
    expect(RaftScale.text['sm']!.fontSize, 14);
    expect(RaftScale.text['sm']!.lineHeight, 20);
    expect(RaftScale.ease['slide'], const Cubic(.32, .72, 0, 1));
  });
}
