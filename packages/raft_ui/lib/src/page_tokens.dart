// Page-level theme tokens (Web v1.21.23 page alignment). The numbers, options
// and roles are declared in tool/theme-adapters/pages_lane.py; a page reads
// them here and never asks which theme is active. Every default is the Raft
// value (the pack of the look a missing token falls back to).
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'theme.dart';

extension RaftPageTokens on RaftTokens {
  /// `bg-layer-sidebar` of a standalone page (splash, server not found), or
  /// the canvas the pre-theme app painted there.
  Color get standaloneSurface => option('standalone.surface', or: 'sidebar') ==
          'sidebar'
      ? colors['layer-sidebar']!
      : canvas;

  /// The label of a standalone page (`text-headline text-foreground-muted`).
  TextStyle splashLabel() => RaftTypography.body(
    this,
    size: size('type.splash.size', fallback: 17),
    line: size('type.splash.line', fallback: 22),
    weight: FontWeight.w700,
    color: colors['foreground-splash'],
  );

  /// SectionEyebrow (`text-footnote font-bold text-foreground-hint`).
  TextStyle sectionEyebrow({Color? color}) => TextStyle(
    fontSize: size('type.sectionEyebrow.size', fallback: 13),
    height:
        size('type.sectionEyebrow.line', fallback: 18) /
        size('type.sectionEyebrow.size', fallback: 13),
    fontWeight: FontWeight.w700,
    color: color ?? colors['foreground-eyebrow'],
  );

  /// TextLink v1.21.23: always underlined, ink primary.
  bool get textLinksUnderlined =>
      option('auth.links', or: 'underlined') == 'underlined';
}
