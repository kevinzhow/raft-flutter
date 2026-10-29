import 'package:flutter/widgets.dart';

/// Escape closes the surface, whatever holds focus inside it.
///
/// Web `Modal` / `Lightbox` / `OverflowSheet` listen for Escape on the
/// document. A Flutter modal route only gets that for free when its
/// `barrierDismissible` is true, and the Web layers (`showRaftModal`, the
/// settings drawer, the confirm dialog) must not close on a scrim tap. This
/// scope binds the framework's `DismissIntent` (Escape in `WidgetsApp`'s
/// default shortcuts) for the whole subtree: a nested popup, select or text
/// field that handles Escape itself still wins, because the intent bubbles
/// from the focused node upwards and stops at the first enabled action.
///
/// [onDismiss] defaults to `Navigator.maybePop`, so `PopScope(canPop: false)`
/// (a busy submit, an unsaved draft guard) keeps deciding whether the close
/// happens. The nested [FocusScope] holds the route's initial focus, so
/// Escape reaches the action before the user has focused anything; a field
/// with `autofocus` inside still takes focus first.
class RaftDismissScope extends StatefulWidget {
  const RaftDismissScope({
    super.key,
    required this.child,
    this.onDismiss,
    this.enabled = true,
    this.takeFocus = false,
  });
  final Widget child;

  /// Replaces `Navigator.maybePop` (a guarded close that confirms first).
  final VoidCallback? onDismiss;
  final bool enabled;

  /// A popup inside an existing route (an `OverlayPortal` / `OverlayEntry`):
  /// the opener (a trigger) usually holds focus, and `autofocus` does not move
  /// it, so Escape would never reach this scope. Moves focus into the scope
  /// once it is built (a route-level dialog gets its focus from the route).
  final bool takeFocus;

  @override
  State<RaftDismissScope> createState() => _RaftDismissScopeState();
}

class _RaftDismissScopeState extends State<RaftDismissScope> {
  final node = FocusScopeNode(debugLabel: 'RaftDismissScope');

  /// Whether the scope takes the initial focus. Decided once, when it mounts.
  /// A scope that mounts inside a route that is already covered (the shell was
  /// rebuilt behind the expanded composer editor when the window crossed the
  /// phone / desktop breakpoint) must not pull the focus out of the route in
  /// front of it: autofocus moves the primary focus even from a scope that is
  /// not in the focus path.
  bool? autofocus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    autofocus ??= !_covered(context);
  }

  /// Route scopes only take part in focus traversal while their route is the
  /// topmost one, so a covered route has `skipTraversal` set.
  static bool _covered(BuildContext context) {
    final parent = Focus.maybeOf(
      context,
      scopeOk: true,
      createDependency: false,
    );
    if (parent == null) return false;
    return [
      parent,
      ...parent.ancestors,
    ].any((node) => node is FocusScopeNode && node.skipTraversal);
  }

  @override
  void initState() {
    super.initState();
    if (widget.takeFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !node.hasFocus) node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            if (widget.onDismiss != null) {
              widget.onDismiss!();
            } else {
              Navigator.maybePop(context);
            }
            return null;
          },
        ),
      },
      child: FocusScope(
        node: node,
        autofocus: autofocus ?? true,
        child: widget.child,
      ),
    );
  }
}

/// The system back gesture closes a transient popup instead of the page
/// under it.
///
/// A menu, select or picker lives in an `OverlayPortal`, so it is not a route
/// and Android Back would pop the page beneath it (or leave the app). While
/// this widget is mounted (build it only while the popup is open) it adds a
/// `LocalHistoryEntry` to the enclosing route. Back consumes that entry and
/// calls [onDismiss] once without leaving the page. A route that vetoes Back
/// with `PopScope` must call [raftDismissTopPopup] itself. Closing the popup
/// any other way removes the entry again.
///
/// An `OverlayEntry` builds above the routes; pass the opener's context as
/// [routeContext] there.
class RaftBackDismiss extends StatefulWidget {
  const RaftBackDismiss({
    super.key,
    required this.onDismiss,
    required this.child,
    this.routeContext,
  });
  final VoidCallback onDismiss;
  final Widget child;
  final BuildContext? routeContext;

  @override
  State<RaftBackDismiss> createState() => _RaftBackDismissState();
}

/// The popups that are open now, oldest first (see [raftDismissTopPopup]).
final _openBackPopups = <_RaftBackDismissState>[];

/// Closes the newest popup that belongs to the route of [context], and says
/// whether there was one.
///
/// A route holding `PopScope(canPop: false)` (the workspace shell with a panel
/// open, a dirty form) vetoes Back before the navigator looks at the route's
/// local history, so a popup's [RaftBackDismiss] entry is never reached. That
/// route's `onPopInvokedWithResult` calls this first and leaves its own
/// handling alone when it returns true.
bool raftDismissTopPopup(BuildContext context) {
  final route = ModalRoute.of(context);
  for (final popup in _openBackPopups.reversed.toList()) {
    if (!popup.mounted) continue;
    if (ModalRoute.of(popup.widget.routeContext ?? popup.context) != route) {
      continue;
    }
    popup.widget.onDismiss();
    return true;
  }
  return false;
}

class _RaftBackDismissState extends State<RaftBackDismiss> {
  ModalRoute<dynamic>? _route;
  LocalHistoryEntry? _entry;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _openBackPopups.add(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
  }

  void _attach() {
    if (_gone || !mounted || _entry != null) return;
    final route = ModalRoute.of(widget.routeContext ?? context);
    if (route == null || !route.isCurrent) return;
    final entry = LocalHistoryEntry(
      onRemove: () {
        final wasAttached = _entry != null;
        _entry = null;
        // Back popped the entry: the popup closes itself.
        if (wasAttached && !_gone) widget.onDismiss();
        _notifyNavigation();
      },
    );
    _route = route;
    _entry = entry;
    route.addLocalHistoryEntry(entry);
    _notifyNavigation();
  }

  void _notifyNavigation() {
    // Local history changes rebuild the route but do not notify an ancestor
    // NavigatorPopHandler. Publish them without waiting for an unrelated
    // Navigator rebuild; its listener also accounts for other routes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = _route;
      final context = route?.subtreeContext;
      if (route == null ||
          !route.isCurrent ||
          context == null ||
          !context.mounted) {
        return;
      }
      NavigationNotification(
        canHandlePop:
            route.willHandlePopInternally ||
            route.popDisposition == RoutePopDisposition.doNotPop,
      ).dispatch(context);
    });
  }

  @override
  void dispose() {
    _gone = true;
    _openBackPopups.remove(this);
    final entry = _entry, route = _route;
    _entry = null;
    if (entry != null && route != null) {
      // Removing it re-enters the route's state; do that after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          route.removeLocalHistoryEntry(entry);
        } catch (_) {
          // The route is already gone (it was popped with the popup open).
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// [builder] wrapped so the popup it builds closes on the system back gesture
/// (see [RaftBackDismiss]); for `OverlayPortal.overlayChildBuilder`.
Widget Function(BuildContext) raftBackDismissed(
  VoidCallback onDismiss,
  Widget Function(BuildContext) builder,
) =>
    (context) => RaftBackDismiss(onDismiss: onDismiss, child: builder(context));
