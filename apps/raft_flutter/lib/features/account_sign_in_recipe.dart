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
    color: tokens.brutal ? Colors.white : tokens.panel,
    border: Border.all(
      color: tokens.brutal
          ? Colors.black.withValues(alpha: .3)
          : tokens.colors['line-muted']!,
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
    color: tokens.brutal ? Colors.black : tokens.strong,
  );
  // `truncate text-xs text-foreground-muted theme-brutal:text-black/50`
  TextStyle get detail => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    color: tokens.brutal ? Colors.black.withValues(alpha: .5) : tokens.muted,
  );
  // `mt-1 text-xs text-foreground-muted theme-brutal:text-black/60`
  TextStyle get passwordDetail => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    color: tokens.brutal ? Colors.black.withValues(alpha: .6) : tokens.muted,
  );
  // `border-t-2 border-line-muted theme-brutal:border-black`
  Color get dividerColor =>
      tokens.brutal ? Colors.black : tokens.colors['line-muted']!;
  double get dividerWidth => 2;
}
