import 'package:flutter/widgets.dart';

import '../platform/system_gesture_exclusion.dart';

/// Keeps the system back gesture off a rail on the window's right edge: while
/// [enabled], the rail's item area (to the window edge, at most 200 dp tall)
/// is reported as a gesture exclusion rect while this page is the visible one;
/// otherwise nothing is excluded.
/// Measured after each frame, so rotation and resizing follow.
class RailGestureExclusion extends StatefulWidget {
  const RailGestureExclusion({
    super.key,
    required this.itemArea,
    required this.enabled,
    required this.child,
  });
  final GlobalKey itemArea;
  final bool enabled;
  final Widget child;

  @override
  State<RailGestureExclusion> createState() => _RailGestureExclusionState();
}

class _RailGestureExclusionState extends State<RailGestureExclusion> {
  bool queued = false;

  /// False while a page covers this one (its tickers stop): the covered page
  /// keeps its rail mounted but must not keep the gesture off the page above.
  bool active = true;
  late final SystemGestureExclusion exclusion = SystemGestureExclusion.instance;

  void measure() {
    if (queued) return;
    queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queued = false;
      if (!mounted) return;
      final box = widget.itemArea.currentContext?.findRenderObject();
      if (!widget.enabled ||
          !active ||
          box is! RenderBox ||
          !box.attached ||
          !box.hasSize) {
        exclusion.clear();
        return;
      }
      final area = box.localToGlobal(Offset.zero) & box.size;
      final width =
          View.of(context).physicalSize.width /
          View.of(context).devicePixelRatio;
      // The strip runs from the item area to the right window edge.
      exclusion.set([
        SystemGestureExclusion.clip(
          Rect.fromLTRB(area.left, area.top, width, area.bottom),
        ),
      ], devicePixelRatio: View.of(context).devicePixelRatio);
    });
  }

  @override
  void dispose() {
    exclusion.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    active = TickerMode.valuesOf(context).enabled;
    measure();
    return widget.child;
  }
}
