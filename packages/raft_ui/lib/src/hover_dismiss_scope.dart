import 'package:flutter/widgets.dart';

import 'pointer_intent.dart';

/// Retires hover overlays when their navigation context changes. Only
/// active hover triggers and pending/open popups subscribe; idle rows do not listen to navigation.
/// Install this observer on the root Navigator and [RaftHoverDismissScope]
/// above it. Menus and dialogs retain their own dismissal contracts.
class RaftHoverDismissController extends NavigatorObserver
    implements Listenable {
  final Set<VoidCallback> _listeners = {};

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Closes hover overlays, including pending opens, and requires fresh
  /// pointer movement before a retained or newly exposed trigger can open.
  void dismiss() {
    RaftPointerIntent.requireMovement();
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  @override
  void didChangeTop(
    Route<dynamic> topRoute,
    Route<dynamic>? previousTopRoute,
  ) => dismiss();

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) => dismiss();
}

/// Shares hover dismissal across route pushes/pops and a router's logical
/// location (panels and page selections can change without pushing a route).
/// [location] must return an immutable value with value equality. Data-only
/// [navigation] notifications do not close a popup when that value is equal.
class RaftHoverDismissScope extends StatefulWidget {
  const RaftHoverDismissScope({
    super.key,
    required this.controller,
    required this.navigation,
    required this.location,
    required this.child,
  });
  final RaftHoverDismissController controller;
  final Listenable navigation;
  final Object? Function() location;
  final Widget child;

  static RaftHoverDismissController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_HoverDismissScope>()
      ?.controller;

  @override
  State<RaftHoverDismissScope> createState() => _RaftHoverDismissScopeState();
}

class _RaftHoverDismissScopeState extends State<RaftHoverDismissScope> {
  Object? location;
  @override
  void initState() {
    super.initState();
    location = widget.location();
    widget.navigation.addListener(changed);
  }

  void changed() {
    final next = widget.location();
    if (location == next) return;
    location = next;
    widget.controller.dismiss();
  }

  @override
  void didUpdateWidget(RaftHoverDismissScope old) {
    super.didUpdateWidget(old);
    if (old.navigation != widget.navigation) {
      old.navigation.removeListener(changed);
      widget.navigation.addListener(changed);
    }
    changed();
  }

  @override
  void dispose() {
    widget.navigation.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _HoverDismissScope(controller: widget.controller, child: widget.child);
}

class _HoverDismissScope extends InheritedWidget {
  const _HoverDismissScope({required this.controller, required super.child});
  final RaftHoverDismissController controller;
  @override
  bool updateShouldNotify(_HoverDismissScope old) =>
      controller != old.controller;
}
