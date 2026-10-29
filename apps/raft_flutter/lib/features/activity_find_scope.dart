import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

/// ThreadsInbox `activitySearchScopeActiveRef` + `activityPanelRef`: Activity
/// owns Cmd/Ctrl+F while the keyboard scope is its own surface, and leaves an
/// opened conversation panel to that panel's finder.
///
/// Web decides on the event target: inside the panel, or `document.body`
/// (nothing focused) after the last pointerdown/focusin landed in the panel.
/// Flutter has no `document.body`: with nothing meaningful focused the primary
/// focus is the route's FocusScope, and key events never reach a widget that
/// merely sits in the panel. So the panel owns a focus node of its own. A
/// pointer-down inside the panel (and the first frame of the panel) claims it
/// when nothing inside has focus; a pointer-down anywhere else gives it up.
/// The key handler then sees Cmd/Ctrl+F exactly when the scope is active,
/// whether a row button, the find field or this node holds primary focus.
class ActivityFindScope extends StatefulWidget {
  const ActivityFindScope({
    super.key,
    required this.enabled,
    required this.onFind,
    required this.child,
  });

  /// Whether Activity find exists at all (flag on, desktop master-detail).
  final bool enabled;
  final VoidCallback onFind;
  final Widget child;

  @override
  State<ActivityFindScope> createState() => _ActivityFindScopeState();
}

class _ActivityFindScopeState extends State<ActivityFindScope> {
  final node = FocusNode(debugLabel: 'ActivityFindScope', skipTraversal: true);
  // Pointer that the panel's own Listener saw; the global route runs after
  // hit-test dispatch, so anything it did not see landed elsewhere (another
  // panel, an overlay above this one).
  int? insidePointer;
  bool routed = false;

  @override
  void initState() {
    super.initState();
    sync();
  }

  @override
  void didUpdateWidget(covariant ActivityFindScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) sync();
  }

  void sync() {
    if (widget.enabled == routed) return;
    routed = widget.enabled;
    if (routed) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(pointerEvent);
      // Opening Activity is the panel's first interaction: its find works
      // before the first click.
      SchedulerBinding.instance.addPostFrameCallback((_) => claim());
    } else {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(pointerEvent);
    }
  }

  /// Takes keyboard focus only from nothing: a focused control, a text field
  /// elsewhere or an open conversation keeps its own Cmd/Ctrl+F.
  void claim() {
    if (!mounted || !widget.enabled || node.hasFocus) return;
    final primary = FocusManager.instance.primaryFocus;
    // Activating Activity through the rail leaves its button focused. The
    // newly opened panel owns find; preserve focused editors and other panels.
    final navigation = primary?.context
        ?.findAncestorWidgetOfExactType<RaftWorkspaceRailAction>();
    if (primary == null ||
        primary is FocusScopeNode ||
        navigation?.navigation == true) {
      node.requestFocus();
    }
  }

  void pointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    final inside = insidePointer == event.pointer;
    insidePointer = null;
    if (inside || !node.hasFocus) return;
    // focusout: the click landed outside, so the panel no longer owns keys.
    FocusManager.instance.primaryFocus?.unfocus();
  }

  KeyEventResult key(FocusNode _, KeyEvent event) {
    if (!widget.enabled ||
        event is KeyUpEvent ||
        event.logicalKey != LogicalKeyboardKey.keyF ||
        !primaryShortcutModifierDown() ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    widget.onFind();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    if (routed) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(pointerEvent);
    }
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always the same wrapper, so toggling `enabled` (flag landing, a resize
    // across the breakpoint) never remounts the panel underneath.
    return Focus(
      focusNode: node,
      canRequestFocus: widget.enabled,
      onKeyEvent: key,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (!widget.enabled) return;
          insidePointer = event.pointer;
          // A click on the panel blurs whatever was focused elsewhere (a
          // thread composer, a field), as a click does in a browser; a
          // control inside the panel keeps its own focus.
          if (!node.hasFocus) node.requestFocus();
          // A field in the panel blurs itself on an outside tap (its own
          // TapRegion), and focus changes apply in a microtask: take the
          // focus it left behind once those have settled, so the click still
          // scopes find to the panel.
          // ignore: raft_lints/avoid_unreviewed_idle_work -- one-shot per pointer-down, claim() no-ops unless focus is nothing; nothing reschedules it
          Timer.run(claim);
        },
        child: widget.child,
      ),
    );
  }
}
