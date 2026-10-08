import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_primitives.dart';

/// Source mermaid.css12–37/186–214: one responsive toolbar geometry contract.
/// Native touch targets occupy real layout space; squeezed targets wrap rather
/// than intercept adjacent content. Container fit is a native adaptation to the
/// source viewport-only breakpoint, including measured translated tab labels.
@immutable
class RaftMermaidToolbarRecipe {
  const RaftMermaidToolbarRecipe({
    required this.viewportWidth,
    required this.availableWidth,
    required this.density,
    required this.showSource,
    required this.diagramTabWidth,
    required this.sourceTabWidth,
  });
  final double viewportWidth, availableWidth, diagramTabWidth, sourceTabWidth;
  final RaftDensity density;
  final bool showSource;

  static const desktopBreakpoint = 640.0;
  static const inset = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
  static const compactGap = 8.0, desktopGap = 4.0;

  double targetSize(double visual) => density == RaftDensity.touch
      ? math.max(RaftMetrics.touchTarget, visual)
      : visual;
  int get compactCount => showSource ? 4 : 5;
  int get desktopIconCount => showSource ? 2 : 5;
  double get desktopBudget =>
      inset.horizontal +
      targetSize(diagramTabWidth) +
      targetSize(sourceTabWidth) +
      desktopIconCount * targetSize(RaftMetrics.buttonSm) +
      (desktopIconCount + 1) * desktopGap;
  double get compactBudget =>
      inset.horizontal +
      compactCount * targetSize(RaftMetrics.buttonSm) +
      (compactCount - 1) * compactGap;
  bool get desktop =>
      viewportWidth >= desktopBreakpoint && availableWidth >= desktopBudget;
  double get gap => desktop ? desktopGap : compactGap;
  double get tabVisualHeight =>
      desktop ? RaftMetrics.buttonXs : RaftMetrics.buttonSm;
  bool get wrap => !desktop && availableWidth < compactBudget;
}
