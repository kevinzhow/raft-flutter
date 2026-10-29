import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'interaction.dart';

/// The host's pointer capability, independent of the viewport width. Native
/// touch hosts disable hover for their entire navigator, including overlays.
/// Layout density does not change pointer capability. Previews opt in explicitly.
class RaftHoverScope extends InheritedWidget {
  const RaftHoverScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  factory RaftHoverScope.forPlatform({Key? key, required Widget child}) =>
      RaftHoverScope(
        key: key,
        enabled: !RaftInteraction.platformIsTouch(defaultTargetPlatform),
        child: child,
      );

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftHoverScope>()?.enabled ??
      true;

  /// Preserve the Material default for fine input and suppress only its hover
  /// overlay on touch hosts. Focus and pressed overlays keep their defaults.
  static Color? materialHoverColor(BuildContext context) =>
      of(context) ? null : Colors.transparent;

  @override
  bool updateShouldNotify(RaftHoverScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// A mouse region that does not turn compatibility mouse events into hover on
/// touch surfaces. Tap, long press, keyboard focus and explicit popup commands
/// stay with the child. Changing input mode retires an already entered region.
class RaftHoverRegion extends StatefulWidget {
  const RaftHoverRegion({
    super.key,
    this.onEnter,
    this.onExit,
    this.onHover,
    this.cursor = MouseCursor.defer,
    this.opaque = true,
    this.hitTestBehavior,
    this.enabled = true,
    this.child,
  });

  final ValueChanged<PointerEnterEvent>? onEnter;
  final ValueChanged<PointerExitEvent>? onExit;
  final ValueChanged<PointerHoverEvent>? onHover;
  final MouseCursor cursor;
  final bool opaque, enabled;
  final HitTestBehavior? hitTestBehavior;
  final Widget? child;

  @override
  State<RaftHoverRegion> createState() => _RaftHoverRegionState();
}

class _RaftHoverRegionState extends State<RaftHoverRegion> {
  bool scopeEnabled = true;
  PointerEvent? lastEvent;
  int epoch = 0;
  bool get allowed => widget.enabled && scopeEnabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scopeEnabled = RaftHoverScope.of(context);
    retireDisabled();
  }

  @override
  void didUpdateWidget(RaftHoverRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    retireDisabled();
  }

  void retireDisabled() {
    final event = lastEvent;
    if (allowed || event == null) return;
    lastEvent = null;
    final ticket = ++epoch;
    // Consumers commonly setState in onExit. A dependency change is inside
    // their build, so deliver that retirement once after the current frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !allowed && ticket == epoch) {
        widget.onExit?.call(PointerExitEvent.fromMouseEvent(event));
      }
    });
  }

  void enter(PointerEnterEvent event) {
    if (!allowed) return;
    epoch++;
    lastEvent = event;
    widget.onEnter?.call(event);
  }

  void hover(PointerHoverEvent event) {
    if (!allowed) return;
    if (lastEvent == null) enter(PointerEnterEvent.fromMouseEvent(event));
    lastEvent = event;
    widget.onHover?.call(event);
  }

  void exit(PointerExitEvent event) {
    if (lastEvent == null) return;
    epoch++;
    lastEvent = null;
    widget.onExit?.call(event);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: enter,
    onHover: hover,
    onExit: exit,
    cursor: widget.cursor,
    opaque: widget.opaque,
    hitTestBehavior: widget.hitTestBehavior,
    child: widget.child,
  );
}
