import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// Component-layer recipe, SettingsPanel.tsx Account connected-provider rows,
/// pinned26f77ef: border-line-muted/bg-layer-panel/p-3 and text-xs hierarchy.
class RaftAccountSignInRecipe {
  const RaftAccountSignInRecipe(this.tokens);
  final RaftTokens tokens;
  static const gap = 12.0;
  static const rowInset = EdgeInsets.all(12);
  // `border border-line-muted theme-brutal:border-2 theme-brutal:border-black/30
  // bg-layer-panel theme-brutal:bg-white p-3`
  BoxDecoration get providerDecoration => BoxDecoration(
    color: RaftSettingsText(tokens).panel,
    border: Border.all(
      color: RaftSettingsText(tokens).softEdge,
      width: tokens.brutal ? 2 : 1,
    ),
  );
  TextStyle get heading =>
      RaftTypography.body(tokens, size: 14, line: 20, weight: FontWeight.w700);
  TextStyle get providerTitle => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    weight: FontWeight.w700,
    color: RaftSettingsText(tokens).strong,
  );
  // `truncate text-xs text-foreground-muted theme-brutal:text-black/50`
  TextStyle get detail => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    color: RaftSettingsText(tokens).faint,
  );
  // `mt-1 text-xs text-foreground-muted theme-brutal:text-black/60`
  TextStyle get passwordDetail => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    color: RaftSettingsText(tokens).muted,
  );
  // `border-t-2 border-line-muted theme-brutal:border-black`
  Color get dividerColor => RaftSettingsText(tokens).edge;
  double get dividerWidth => 2;
}
