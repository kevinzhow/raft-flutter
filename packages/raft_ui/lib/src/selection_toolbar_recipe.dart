// Source: message/SelectModeToolbar.tsx (26f77ef), not a generic toolbar.
// It consumes the generated raft-ui Button sizes/variants and shared roles.
import 'package:flutter/material.dart';

import 'theme.dart';

class RaftSelectionToolbarRecipe {
  const RaftSelectionToolbarRecipe(this.tokens, {required this.viewportWidth});
  final RaftTokens tokens;
  final double viewportWidth;
  EdgeInsets get inset => const EdgeInsets.all(8);
  double get gap => viewportWidth >= 640 ? 6 : 4;
  Color get background =>
      tokens.colors[tokens.brutal ? 'color-soft-signal' : 'primary-soft']!;
  Color get border =>
      tokens.brutal ? Colors.black : tokens.colors['primary-edge']!;
  double get borderWidth => tokens.brutal ? 2 : 1;
  TextStyle get count => TextStyle(
    fontFamily: tokens.monoFont,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
    color: (tokens.brutal ? Colors.black : tokens.colors['primary-strong']!)
        .withValues(alpha: .7),
    leadingDistribution: TextLeadingDistribution.even,
  );
}
