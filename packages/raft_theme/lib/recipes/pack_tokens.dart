import 'package:flutter/painting.dart';

import '../src/brutal_pack.g.dart' show brutalThemePackId;
import '../src/elegant_pack.g.dart' show elegantThemePackId;
import '../src/theme_pack.dart';
import 'recipe_runtime.dart';

/// The recipe set a theme pack paints with. This is the one place the mapping
/// is decided: the frozen looks (the built-in Elegant and Brutal packs) keep the
/// 0.5.52 set from `recipes_legacy.dart`; every other pack, Raft and user packs
/// extending it, uses the current raft-ui set.
extension RaftThemePackRecipes on RaftThemePack {
  RaftRecipeSet get recipeSet =>
      builtIn && (id == elegantThemePackId || id == brutalThemePackId)
      ? RaftRecipeSet.legacy
      : RaftRecipeSet.raft;
}

/// Resolves recipe values directly from a resolved theme pack.
///
/// Applications may override foundation lookups to supply platform font names
/// or compatibility aliases. Component bindings always use the pack's role
/// names, independently of the application adapter.
class RaftThemeRecipeTokens extends RaftTokenResolver {
  RaftThemeRecipeTokens(
    this.values, {
    this.textLocale,
    this.bindComponents = true,
    this.recipeSet = RaftRecipeSet.raft,
  });

  final RaftModeValues values;
  final bool bindComponents;
  @override
  final RaftRecipeSet recipeSet;
  @override
  final Locale? textLocale;

  @override
  CssValue? recipeValue(RaftRecipeTokenKind kind, String name) {
    if (!bindComponents) return null;
    switch (kind) {
      case RaftRecipeTokenKind.number:
        final value = values.geometry[name];
        return value == null ? null : CssNum(value);
      case RaftRecipeTokenKind.color:
        final value = values.colors[name] ?? values.palette[name];
        return value == null ? null : CssColor(value.toARGB32(), null, value);
      case RaftRecipeTokenKind.shadow:
        final layers = values.shadows[name];
        if (layers == null) return null;
        return CssList([
          for (final layer in layers)
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
    final colors = values.colors;
    final palette = values.palette;
    final alternate = css.startsWith('color-')
        ? css.substring(6)
        : 'color-$css';
    return colors[css] ??
        palette[css] ??
        colors[alternate] ??
        palette[alternate] ??
        (throw ArgumentError('Unknown colour token "$name" ($css)'));
  }

  @override
  List<BoxShadow> shadow(String name) {
    final role = cssName(name)
        .replaceFirst(RegExp(r'^(theme-shadow-|shadow-raft-)'), '');
    final layers = values.shadows[role];
    if (layers == null)
      throw ArgumentError('Unknown shadow token "$name" ($role)');
    return [
      for (final layer in layers.reversed)
        if (!layer.inset)
          BoxShadow(
            color: layer.color,
            offset: layer.offset,
            blurRadius: layer.blur,
            spreadRadius: layer.spread,
          ),
    ];
  }

  @override
  double? number(String name) =>
      values.geometry[switch (name) {
        'fieldFontSize' => 'type.field.size',
        'fieldFontWeight' => 'type.field.weight',
        'fieldLineHeight' => 'type.field.line',
        'cardTitleFontSize' => 'type.cardTitle.size',
        'cardTitleFontWeight' => 'type.cardTitle.weight',
        'cardTitleLineHeight' => 'type.cardTitle.line',
        _ => name,
      }];

  @override
  String? fontFamily(String name) => values
      .fonts[switch (name) {
        'headingFont' || 'fontHeading' => 'heading',
        'sansFont' || 'fontSans' => 'sans',
        'monoFont' || 'fontMono' => 'mono',
        _ => name,
      }]
      ?.family;
}
