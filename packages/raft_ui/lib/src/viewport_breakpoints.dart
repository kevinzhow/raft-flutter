import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// Viewport width reduced to the reference Web breakpoints that recipes
/// compare against (640, 768, 1024, 1280).
///
/// Message rows and bodies only branch on these breakpoints. Reading the raw
/// `MediaQuery.sizeOf(context).width` made every mounted row rebuild on every
/// frame of a window resize; this scope notifies dependents only when a
/// breakpoint is crossed.
class RaftViewportBreakpointScope extends StatelessWidget {
  const RaftViewportBreakpointScope({super.key, required this.child});
  final Widget child;

  static const breakpoints = <double>[640, 768, 1024, 1280];

  /// A width inside the same breakpoint band as [width].
  static double bandWidth(double width) {
    for (final limit in breakpoints) {
      if (width < limit) return limit - 1;
    }
    return breakpoints.last;
  }

  @override
  Widget build(BuildContext context) => _RaftViewportBand(
    width: bandWidth(MediaQuery.sizeOf(context).width),
    child: child,
  );
}

class _RaftViewportBand extends InheritedWidget {
  const _RaftViewportBand({required this.width, required super.child});
  final double width;
  @override
  bool updateShouldNotify(_RaftViewportBand oldWidget) =>
      width != oldWidget.width;
}

/// Breakpoint-band viewport width for recipe decisions. Falls back to the
/// band of the raw media width when no [RaftViewportBreakpointScope] exists.
double raftBreakpointWidth(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_RaftViewportBand>()?.width ??
    RaftViewportBreakpointScope.bandWidth(MediaQuery.sizeOf(context).width);

/// Where the phone layout (below the 768 dp desktop cut) puts its root
/// navigation.
enum RaftNavigationPlacement {
  /// The bottom tab bar (Elegant floating capsule, Brutal in-flow bar).
  bottom,

  /// The desktop left rail (`RaftWorkspaceRail`), on the leading edge.
  rail,
}

/// Which side of the window the phone layout's rail takes, in leading /
/// trailing terms so right-to-left locales mirror it.
enum RaftRailSide { start, end }

/// The device's rail side choice for everything below it. Defaults to
/// [RaftRailSide.start] without a scope.
class RaftRailSideScope extends InheritedWidget {
  const RaftRailSideScope({
    super.key,
    required this.side,
    required super.child,
  });
  final RaftRailSide side;

  static RaftRailSide of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftRailSideScope>()?.side ??
      RaftRailSide.start;

  /// Whether the rail sits on the physical right under [direction].
  static bool onRight(RaftRailSide side, TextDirection direction) =>
      (side == RaftRailSide.end) != (direction == TextDirection.rtl);

  @override
  bool updateShouldNotify(RaftRailSideScope oldWidget) =>
      side != oldWidget.side;
}

/// Set around a rail so what it opens (server menu, notification centre)
/// goes to the side the window has room: toward the content.
///
/// This is not [RaftNavigationColumnScope]. That scope wraps the content
/// column and tells a panel whether the navigation column is on the right.
/// This one wraps only the rail.
class RaftRailEdgeScope extends InheritedWidget {
  const RaftRailEdgeScope({
    super.key,
    required this.onRight,
    required super.child,
  });
  final bool onRight;

  /// False without a scope: the desktop rail is always on the left.
  static bool onRightOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RaftRailEdgeScope>()
          ?.onRight ??
      false;

  @override
  bool updateShouldNotify(RaftRailEdgeScope oldWidget) =>
      onRight != oldWidget.onRight;
}

/// Window-shape thresholds that choose [RaftNavigationPlacement]. Tune them
/// here only: the layout, the host and the tests all read this one place.
///
/// The rail replaces the bottom bar when the window is wide enough for it to
/// be useful ([railMinWidth]) or short and wide like a wide foldable inner
/// screen (440x707) or any landscape phone: height / width below
/// [wideAspectMaxHeightRatio] with at least [wideAspectMinWidth] of width.
/// Ordinary tall phones (390x844, 430x932) keep the bottom bar. This decides
/// navigation chrome only; routes, dialogs and the page stack still follow
/// `RaftAdaptiveWorkspace.compactOf` (768).
abstract final class RaftWindowClass {
  /// Windows at least this wide (dp) use the rail whatever their height.
  static const double railMinWidth = 600;

  /// Narrower windows use the rail when height / width is below this ...
  static const double wideAspectMaxHeightRatio = 1.75;

  /// ... and the width is at least this (dp).
  static const double wideAspectMinWidth = 360;

  /// Widest the rail ever is (Brutal, regular height) plus its system inset
  /// allowance; a separating fold inside this strip, on the rail's side of
  /// the window, would cut the rail.
  static const double railStripWidth = 72;

  /// Hinges and half-opened folds split the window into two panes (Jetpack
  /// WindowManager `FoldingFeature.isSeparating`). Flat folds and cutouts do
  /// not. Reported by the platform in `MediaQuery.displayFeatures`; the
  /// decision here stays size / aspect based, never device-model based.
  static bool isSeparating(DisplayFeature feature) =>
      feature.type == DisplayFeatureType.hinge ||
      feature.type == DisplayFeatureType.fold &&
          feature.state == DisplayFeatureState.postureHalfOpened;

  /// A fold running top to bottom (the panes sit side by side).
  static bool isVertical(DisplayFeature feature) =>
      feature.bounds.height >= feature.bounds.width;

  /// The separating vertical folds / hinges of the window.
  static List<DisplayFeature> separatingVerticalFolds(
    Iterable<DisplayFeature> features,
  ) => [
    for (final feature in features)
      if (isSeparating(feature) && isVertical(feature)) feature,
  ];

  /// Whether a window of [size] is wide enough for the rail (a fold can still
  /// keep the bottom bar). Portrait phones never are.
  static bool isRailSized(Size size) =>
      size.width >= railMinWidth ||
      size.width >= wideAspectMinWidth &&
          size.height / size.width < wideAspectMaxHeightRatio;

  static RaftNavigationPlacement phoneNavigationFor(
    Size size, {
    Iterable<DisplayFeature> displayFeatures = const [],
    TextDirection textDirection = TextDirection.ltr,
    RaftRailSide railSide = RaftRailSide.start,
  }) {
    if (!isRailSized(size)) return RaftNavigationPlacement.bottom;
    // A separating fold inside the rail's edge strip would cut it in two:
    // keep the bottom bar there.
    final strip = RaftRailSideScope.onRight(railSide, textDirection)
        ? Rect.fromLTRB(size.width - railStripWidth, 0, size.width, size.height)
        : Rect.fromLTWH(0, 0, railStripWidth, size.height);
    for (final fold in separatingVerticalFolds(displayFeatures)) {
      if (fold.bounds.overlaps(strip)) return RaftNavigationPlacement.bottom;
    }
    return RaftNavigationPlacement.rail;
  }

  /// Whether the desktop layout's navigation column (rail and sidebar, one
  /// unit) sits on the physical right of a window of [size]. Only touch-first
  /// devices follow the side choice ([followsSide]); computers keep it on the
  /// left. A separating fold inside the column's strip ([columnWidth] wide)
  /// would cut it, so the column stays on the left there.
  static bool desktopNavigationOnRight(
    Size size, {
    required bool followsSide,
    required RaftRailSide railSide,
    required TextDirection textDirection,
    required double columnWidth,
    Iterable<DisplayFeature> Function()? displayFeatures,
  }) {
    if (!followsSide || !RaftRailSideScope.onRight(railSide, textDirection)) {
      return false;
    }
    final strip = Rect.fromLTRB(
      size.width - columnWidth,
      0,
      size.width,
      size.height,
    );
    for (final fold in separatingVerticalFolds(
      displayFeatures?.call() ?? const [],
    )) {
      if (fold.bounds.overlaps(strip)) return false;
    }
    return true;
  }

  static RaftNavigationPlacement phoneNavigationOf(BuildContext context) =>
      phoneNavigationFor(
        MediaQuery.sizeOf(context),
        displayFeatures: MediaQuery.displayFeaturesOf(context),
        textDirection: Directionality.of(context),
        railSide: RaftRailSideScope.of(context),
      );
}
