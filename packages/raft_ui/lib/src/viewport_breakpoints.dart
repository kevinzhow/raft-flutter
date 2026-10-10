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
