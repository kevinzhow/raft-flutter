import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// Component-layer recipe, SettingsPanel.tsx Account connected-provider rows,
/// pinned26f77ef: border-line-muted/bg-layer-panel/p-3 and text-xs hierarchy.
class RaftAccountSignInRecipe {
  const RaftAccountSignInRecipe(this.tokens);
  final RaftTokens tokens;
  static const gap = 12.0;
  static const rowInset = EdgeInsets.all(12);
  BoxDecoration get providerDecoration => BoxDecoration(
    color: tokens.panel,
    border: Border.all(
      color: tokens.brutal ? tokens.strong.withValues(alpha: .3) : tokens.line,
      width: tokens.brutal ? 2 : 1,
    ),
  );
  TextStyle get heading =>
      RaftTypography.body(tokens, size: 14, line: 20, weight: FontWeight.w700);
  TextStyle get providerTitle =>
      RaftTypography.body(tokens, size: 12, line: 16, weight: FontWeight.w700);
  TextStyle get detail =>
      RaftTypography.body(tokens, size: 12, line: 16, color: tokens.muted);
  Color get dividerColor => tokens.brutal ? tokens.strong : tokens.line;
  double get dividerWidth => 2;
}
