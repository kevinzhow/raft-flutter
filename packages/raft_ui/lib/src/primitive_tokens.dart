// Non-colour motion/layout atoms kept for API compatibility.
// Colours, shadows, fonts and metrics come from the generated tiers in
// tokens/ (tool/gen-tokens, docs/design-tokens.md).
import 'package:flutter/animation.dart';

import 'tokens/tokens.dart';

abstract final class RaftPrimitives {
  // raft-ui switch recipe: `duration-180 ease-out`. Tailwind 4's `ease-out`
  // utility is `var(--ease-out)` = cubic-bezier(0, 0, 0.2, 1), not the CSS
  // `ease-out` keyword.
  static const Duration switchDuration = Duration(milliseconds: 180);
  static final Curve switchCurve = RaftScale.ease['out']!;
  static const Duration controlDuration = Duration(milliseconds: 100);

  /// Tailwind `--ease-in-out` (`--default-transition-timing-function`).
  static const Curve controlCurve = RaftScale.defaultTransitionCurve;

  /// Web `element.scrollTo({behavior: "smooth"})` (e.g. the Activity "new
  /// updates" pill). The browser owns that animation; this is a short
  /// ease-in-out of comparable length.
  static const Duration smoothScrollDuration = Duration(milliseconds: 300);
  static const Curve smoothScrollCurve = RaftScale.defaultTransitionCurve;

  /// fonts.css `--sans-font` / `--heading-font` (Brutal) bundled family.
  static String get brutalFont => RaftThemeMetrics.brutal.sansFont;

  /// fonts.css Elegant `--sans-font` bundled family.
  static String get elegantBodyFont => RaftThemeMetrics.elegantLight.sansFont;

  /// fonts.css Elegant `--heading-font` bundled family.
  static String get elegantHeadingFont =>
      RaftThemeMetrics.elegantLight.headingFont;

  /// fonts.css `--mono-font` bundled family.
  static String get monoFont => RaftThemeMetrics.brutal.monoFont;
  static const spacing = <double>[
    0,
    2,
    4,
    6,
    8,
    10,
    12,
    14,
    16,
    20,
    24,
    28,
    32,
    36,
    40,
    44,
    48,
    56,
    62,
    64,
  ];
  static const radii = <double>[0, 2, 4, 6, 8];
}
