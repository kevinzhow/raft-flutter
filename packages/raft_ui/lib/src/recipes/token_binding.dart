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
  RaftRecipeTokens(this.tokens);

  final RaftTokens tokens;

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
    final m = tokens.metrics;
    return switch (name) {
      'headingFont' || 'fontHeading' => m.headingFont,
      'sansFont' || 'fontSans' => m.sansFont,
      'monoFont' || 'fontMono' => m.monoFont,
      _ => null,
    };
  }
}
