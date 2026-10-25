import 'package:flutter/painting.dart';

import '../theme.dart';
import 'recipe_runtime.dart';

/// Binds generated recipes to the generated foundation tokens of one theme.
///
/// Recipe token names are the CSS custom property names in lowerCamelCase
/// (`--layer-panel` → `layerPanel`, `--theme-shadow-sm` → `themeShadowSm`);
/// lookups go through the CSS-keyed maps so both generators stay the single
/// source of their names.
class RaftRecipeTokens extends RaftTokenResolver {
  RaftRecipeTokens(this.tokens) : _bindComponents = true;

  /// Resolve the frozen source recipe for a renderer that only borrows its
  /// original rings or sheens. Foundation colors and fonts still use [tokens].
  RaftRecipeTokens.source(this.tokens) : _bindComponents = false;

  final bool _bindComponents;

  final RaftTokens tokens;

  @override
  Locale? get textLocale => tokens.textLocale;

  @override
  CssValue? recipeValue(RaftRecipeTokenKind kind, String name) {
    if (!_bindComponents) return null;
    switch (kind) {
      case RaftRecipeTokenKind.number:
        final value = tokens.size(name, fallback: double.nan);
        return value.isNaN ? null : CssNum(value);
      case RaftRecipeTokenKind.color:
        final value = tokens.colors[name];
        return value == null ? null : CssColor(value.toARGB32(), null, value);
      case RaftRecipeTokenKind.shadow:
        if (!tokens.hasShadowRole(name)) return null;
        return CssList([
          for (final layer in tokens.shadowLayers(name))
            CssSeq([
              if (layer.inset) const CssKeyword('inset'),
              CssNum(layer.offset.dx, 'px'),
              CssNum(layer.offset.dy, 'px'),
              CssNum(layer.blur, 'px'),
              CssNum(layer.spread, 'px'),
              CssColor(layer.color.toARGB32(), null, layer.color),
            ]),
        ]);
    }
  }

  static final _cssNames = <String, String>{};

  static String cssName(String camel) => _cssNames.putIfAbsent(
    camel,
    () => camel
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '-${m[0]!.toLowerCase()}')
        .replaceAllMapped(RegExp(r'(?<=[a-z])(\d)'), (m) => '-${m[1]}'),
  );

  @override
  Color color(String name) {
    final css = cssName(name);
    final c =
        tokens.colors[css] ??
        tokens.colors[css.startsWith('color-')
            ? css.substring(6)
            : 'color-$css'];
    if (c == null) throw ArgumentError('Unknown colour token "$name" ($css)');
    return c;
  }

  @override
  List<BoxShadow> shadow(String name) {
    final s = tokens.themeShadows;
    final shadow = switch (cssName(name)) {
      'theme-shadow-xs' || 'shadow-raft-xs' => s.xs,
      'theme-shadow-sm' || 'shadow-raft-sm' => s.sm,
      'theme-shadow-md' || 'shadow-raft-md' => s.md,
      'theme-shadow-lg' || 'shadow-raft-lg' => s.lg,
      'theme-shadow-xl' || 'shadow-raft-xl' => s.xl,
      final other => throw ArgumentError(
        'Unknown shadow token "$name" ($other)',
      ),
    };
    return shadow.paintOrder;
  }

  @override
  double? number(String name) {
    final m = tokens.metrics;
    return switch (name) {
      'fieldFontSize' => m.fieldFontSize,
      'fieldFontWeight' => m.fieldFontWeight,
      'fieldLineHeight' => m.fieldLineHeight,
      'cardTitleFontSize' => m.cardTitleFontSize,
      'cardTitleFontWeight' => m.cardTitleFontWeight,
      'cardTitleLineHeight' => m.cardTitleLineHeight,
      _ => null,
    };
  }

  @override
  String? fontFamily(String name) {
    return switch (name) {
      'headingFont' || 'fontHeading' => tokens.headingFont,
      'sansFont' || 'fontSans' => tokens.bodyFont,
      'monoFont' || 'fontMono' => tokens.monoFont,
      _ => null,
    };
  }
}
