import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// Typography and spacing helpers for Account Settings' sign-in section
/// aligned to Web v1.24 (`AccountSection.tsx` + `ProviderAccountRow.tsx`).
class RaftAccountSignInRecipe {
  const RaftAccountSignInRecipe(this.tokens);

  final RaftTokens tokens;

  static const gap = 12.0;

  TextStyle get heading => tokens.scale(
    RaftTypeScale.callout,
    weight: FontWeight.w700,
    color: tokens.ui.foreground,
  );

  TextStyle get providerTitle => tokens.scale(
    RaftTypeScale.footnote,
    weight: FontWeight.w700,
    color: tokens.ui.foreground,
  );

  TextStyle get detail =>
      tokens.scale(RaftTypeScale.caption, color: tokens.ui.foregroundMuted);

  TextStyle get passwordDetail =>
      tokens.scale(RaftTypeScale.caption, color: tokens.ui.foregroundMuted);
}
