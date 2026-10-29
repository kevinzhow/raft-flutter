import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The system gesture / 3-button bar height a surface that touches the bottom
/// edge must pad itself by. Mirrors Web `env(safe-area-inset-bottom)`.
///
/// Reads [MediaQuery.paddingOf], never `viewPadding - viewInsets`. The engine
/// already reports `padding = max(0, viewPadding - viewInsets)`, so this is the
/// nav-bar height at rest and 0 while the keyboard covers the bar. A surface
/// that pads by it can never double count with the keyboard, and it is already
/// correct under a resizing [Scaffold] (which strips it when the IME is up).
/// This is the single place to change if a future Flutter changes that.
double raftBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

/// The system bar height regardless of the keyboard. Only for bars that must
/// stay put when the keyboard opens (the root tab bar). Everything else uses
/// [raftBottomInset].
double raftSystemBottomInset(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom;

/// Web `.mobile-nav-clearance` (index.css): scroll surfaces on elegant tab
/// roots keep this much room under the floating capsule, plus the system inset.
double raftTabBarClearance() => 68;

/// Scroll padding that lets the last item scroll clear of the system bar (and,
/// on elegant tab roots, of the floating capsule via [clearance]).
///
/// `ListView` / `GridView` with `padding: null` already add
/// `MediaQuery.padding`; only lists with explicit padding need this.
EdgeInsets raftScrollPadding(
  BuildContext context, [
  EdgeInsetsGeometry base = EdgeInsets.zero,
  double clearance = 0,
]) {
  final resolved = base.resolve(Directionality.of(context));
  return resolved.copyWith(
    bottom: resolved.bottom + clearance + raftBottomInset(context),
  );
}

/// Sets the navigation bar icon brightness for the bottom-most surface. Flutter
/// samples the style at the window's bottom-centre pixel, so the surface that
/// reaches the bottom edge decides icon contrast (white icons on a white
/// composer would vanish). Only navigation fields are set; the status bar
/// comes from the top of the window.
class RaftNavigationBarStyle extends StatelessWidget {
  const RaftNavigationBarStyle({
    super.key,
    required this.background,
    required this.child,
  });

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: background.computeLuminance() < .5
          ? Brightness.light
          : Brightness.dark,
    ),
    child: child,
  );
}

/// A bottom-anchored control (composer, selection toolbar, forward footer,
/// comments footer, task bottom bar). Its own background paints to the screen
/// edge and the system inset is added as internal bottom padding; nothing is
/// painted by the host.
class RaftBottomInsetSurface extends StatelessWidget {
  const RaftBottomInsetSurface({
    super.key,
    this.color,
    this.decoration,
    this.padding = EdgeInsets.zero,
    required this.child,
  }) : assert(color == null || decoration == null);

  final Color? color;
  final BoxDecoration? decoration;

  /// Padding before the system inset is added.
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = decoration?.color ?? color;
    final surface = DecoratedBox(
      decoration: decoration ?? BoxDecoration(color: color),
      child: Padding(
        padding: padding.copyWith(
          bottom: padding.bottom + raftBottomInset(context),
        ),
        child: child,
      ),
    );
    return background == null
        ? surface
        : RaftNavigationBarStyle(background: background, child: surface);
  }
}
