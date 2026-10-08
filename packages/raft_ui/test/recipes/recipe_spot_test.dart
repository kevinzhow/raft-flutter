import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/recipes.dart';

class _FakeTokens extends RaftTokenResolver {
  const _FakeTokens();
  static const colors = {
    'primary400': Color(0xFFF5C518),
    'foreground': Color(0xFF111111),
    'lineStrong': Color(0xFF000000),
  };
  @override
  Color color(String name) => colors[name] ?? const Color(0xFF808080);
  @override
  List<BoxShadow> shadow(String name) => [BoxShadow(color: const Color(0xFF000000), offset: Offset(name == 'themeShadowSm' ? 2 : 4, 2))];
}

int _utility(String name) => raftRecipeUtilities.indexWhere((u) => u.name == name);

void main() {
  RaftButtonRecipeStyle button(RaftRecipeTheme theme,
          {RaftButtonRecipeVariant? variant, RaftButtonRecipeSize? size, Set<String> states = const {}}) =>
      RaftButtonRecipe.resolve(theme: theme, variant: variant, size: size, states: RaftRecipeStates(states));

  group('Button recipe', () {
    for (final theme in RaftRecipeTheme.values) {
      test('${theme.name} md metrics', () {
        final root = button(theme, size: RaftButtonRecipeSize.md).root;
        expect(root.height, 32);
        expect(root.padding.left, 12);
        expect(root.padding.right, 12);
        expect(root.fontSize, 14);
        expect(root.lineHeight, closeTo(20 / 14, 1e-9));
      });

      test('${theme.name} xs metrics', () {
        final root = button(theme, size: RaftButtonRecipeSize.xs).root;
        expect(root.height, 24);
        expect(root.fontSize, 11);
        expect(root.padding.horizontal, 16);
      });

      test('${theme.name} default size is md', () {
        expect(button(theme).root.height, 32);
      });

      test('${theme.name} disabled opacity', () {
        final root = button(theme, variant: RaftButtonRecipeVariant.primary, states: {RaftRecipeStates.disabled}).root;
        expect(root.opacity, 0.4);
        expect(button(theme, states: {RaftRecipeStates.ariaDisabled}).root.opacity, 0.4);
        // data-loading=true keeps full opacity even when disabled.
        expect(button(theme, states: {RaftRecipeStates.disabled, RaftRecipeStates.loading}).root.opacity, 1);
      });
    }

    test('primary base classes compile to primary400 / hover primary500', () {
      final classes = [_utility('bg-primary-400'), _utility('hover:bg-primary-500')];
      expect(classes, isNot(contains(-1)));
      final base = raftRecipeEngine.resolveSlot(classes, RaftRecipeStates.none);
      expect(base.backgroundColor?.tokenName, 'primary400');
      final hover = raftRecipeEngine.resolveSlot(classes, const RaftRecipeStates({RaftRecipeStates.hover}));
      expect(hover.backgroundColor?.tokenName, 'primary500');
    });

    test('primary after tailwind-merge with theme compound variants', () {
      // brutal: compound `bg-brutal-yellow hover:bg-brutal-yellow` replaces
      // bg-primary-400; the Web's @theme sets --color-brutal-yellow: #FFD440.
      final brutal = button(RaftRecipeTheme.brutal, variant: RaftButtonRecipeVariant.primary).root;
      expect(brutal.classes, isNot(contains('bg-primary-400')));
      expect(brutal.classes, contains('bg-brutal-yellow'));
      expect(brutal.backgroundColor, const RaftLiteralColor(Color(0xFFFFD440)));
      // elegant: compound `bg-primary-soft hover:bg-primary-hover`.
      final elegant = button(RaftRecipeTheme.elegant, variant: RaftButtonRecipeVariant.primary);
      expect(elegant.root.backgroundColor?.tokenName, 'primarySoft');
      final hovered = button(RaftRecipeTheme.elegant, variant: RaftButtonRecipeVariant.primary, states: {RaftRecipeStates.hover});
      expect(hovered.root.backgroundColor?.tokenName, 'primaryHover');
    });

    test('brutal border width 2, elegant none', () {
      final brutal = button(RaftRecipeTheme.brutal).root;
      expect(brutal.borderWidth, const EdgeInsets.all(2));
      expect(brutal.borderColor?.tokenName, 'lineStrong');
      expect(button(RaftRecipeTheme.elegant).root.borderWidth, EdgeInsets.zero);
    });

    test('elegant active scale 0.985; brutal active translate', () {
      expect(button(RaftRecipeTheme.elegant, states: {RaftRecipeStates.active}).root.scale, 0.985);
      expect(button(RaftRecipeTheme.elegant).root.scale, isNull);
      expect(button(RaftRecipeTheme.brutal, states: {RaftRecipeStates.active}).root.translate, const Offset(1, 1));
      expect(button(RaftRecipeTheme.brutal, states: {RaftRecipeStates.hover}).root.translate, const Offset(0, -1));
    });

    test('shadow tokens and transitions', () {
      final brutal = button(RaftRecipeTheme.brutal).root;
      expect(brutal.boxShadow, [const RaftTokenShadow(TokenRef('themeShadowSm'))]);
      expect(button(RaftRecipeTheme.brutal, states: {RaftRecipeStates.hover}).root.boxShadow,
          [const RaftTokenShadow(TokenRef('themeShadowMd'))]);
      expect(brutal.transitionDuration, const Duration(milliseconds: 100));
      final curve = brutal.transitionCurve! as Cubic;
      expect([curve.a, curve.b, curve.c, curve.d], [0.4, 0, 0.2, 1]);
      expect(brutal.fontWeight, FontWeight.w700);
      expect(button(RaftRecipeTheme.elegant).root.fontWeight, FontWeight.w500);
    });

    test('elegant focus ring is a spread box-shadow', () {
      final root = button(RaftRecipeTheme.elegant, states: {RaftRecipeStates.focusVisible}).root;
      final spreads = root.boxShadow.whereType<RaftLiteralShadow>().map((s) => s.spread).toList();
      expect(spreads, containsAll([1.0, 3.0])); // ring-offset-1 + ring-2
    });

    test('elegant radius by size, brutal square', () {
      expect(button(RaftRecipeTheme.elegant).root.borderRadius, BorderRadius.circular(6));
      expect(button(RaftRecipeTheme.elegant, size: RaftButtonRecipeSize.xs).root.borderRadius, BorderRadius.circular(4));
      expect(button(RaftRecipeTheme.brutal).root.borderRadius, BorderRadius.zero);
    });

    test('decoration resolves tokens', () {
      const tokens = _FakeTokens();
      final root = button(RaftRecipeTheme.brutal).root;
      final deco = root.decoration(tokens);
      expect(deco.border, Border.all(width: 2, color: const Color(0xFF000000)));
      expect(deco.boxShadow, tokens.shadow('themeShadowSm'));
    });

    test('pseudo-element and descendant targets', () {
      final root = button(RaftRecipeTheme.elegant).root;
      expect(root.before?.position, 'absolute');
      expect(root.target("& svg:not([class*='size-'])")?.width, 16);
    });
  });

  test('every recipe resolves its default combination', () {
    for (final MapEntry(key: name, value: resolve) in raftRecipes.entries) {
      for (final theme in ['brutal', 'elegant']) {
        final slots = resolve({'theme': theme});
        expect(slots, isNotEmpty, reason: name);
      }
    }
  });

  test('color-mix of a token resolves at runtime', () {
    const mix = RaftMixedColor('oklch', RaftTokenColor(TokenRef('primary400')), 0.8, RaftLiteralColor(Color(0x00000000)), null);
    final c = mix.resolve(const _FakeTokens());
    expect((c.a * 255).round(), (0.8 * 255).round());
    final rgb = c.withAlpha(255).toARGB32();
    for (final shift in [16, 8, 0]) {
      expect(((rgb >> shift) & 255) - ((0xFFF5C518 >> shift) & 255), inInclusiveRange(-1, 1));
    }
  });
}
