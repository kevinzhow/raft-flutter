import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';

// The phone page stack's transition gate is read next to the route gate.
export 'route_transition_gate.dart';

/// Phone channel timeline and the thread opened from that page. Present only
/// while that page is the direct-read visit. Desktop, grid, task discussion
/// and agent chat do not wrap this.
class MobileChatDirectRead extends InheritedWidget {
  const MobileChatDirectRead({
    super.key,
    required this.channel,
    required this.thread,
    required super.child,
  });

  final bool channel, thread;

  static MobileChatDirectRead? maybeOf(BuildContext context) {
    final found = context
        .getElementForInheritedWidgetOfExactType<MobileChatDirectRead>()
        ?.widget;
    return found is MobileChatDirectRead ? found : null;
  }

  @override
  bool updateShouldNotify(MobileChatDirectRead oldWidget) =>
      channel != oldWidget.channel || thread != oldWidget.thread;
}

/// Live cover flag for one phone route. Set in the route's listener, which
/// runs before the page's listeners, so a covered chat does not apply the
/// workspace's new channel during that same notification.
class MobileRouteGate extends InheritedWidget {
  const MobileRouteGate({super.key, required super.child});

  static final _covered = Expando<bool>();
  static final _location = Expando<RaftLocation>();

  @override
  bool updateShouldNotify(MobileRouteGate oldWidget) => false;

  /// The route [State] is the parent of this gate. Element.parent is private
  /// in this Flutter version, so the walk starts at that parent.
  static State? _state(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<MobileRouteGate>();
    if (element == null) return null;
    State? route;
    element.visitAncestorElements((ancestor) {
      if (ancestor is StatefulElement) {
        route = ancestor.state;
        return false;
      }
      return true;
    });
    return route;
  }

  static void write(
    State state, {
    required bool covered,
    required RaftLocation location,
  }) {
    final changed = _covered[state] != covered;
    _covered[state] = covered;
    _location[state] = location;
    if (changed) _flips[state]?.notifyListeners();
  }

  /// The route's own answer, when it can give one on demand. The flag above is
  /// only written when the workspace notifies, and the workspace's own
  /// bookkeeping (the image repository judging its entries) runs before the
  /// route's listener, so readers ask the route when they can.
  static final _live = Expando<bool Function()>();

  static void follow(State state, bool Function() covered) =>
      _live[state] = covered;

  /// Notifies when the route's covered flag flips, so what was held while it
  /// was covered is built again the moment it is current, whether or not a
  /// ticker mode or an ancestor changes with it.
  static final _flips = Expando<_Flips>();

  static _Flips? _flipsOf(BuildContext context) {
    final state = _state(context);
    return state == null ? null : (_flips[state] ??= _Flips());
  }

  /// The location stored for the phone route that contains [context].
  static RaftLocation? locationOf(BuildContext context) {
    final state = _state(context);
    return state == null ? null : _location[state];
  }

  /// Reads whether the phone route containing [context] is not the page the
  /// workspace is on: covered by another page, or popped and animating out.
  /// The reader is safe to call at any time, including while the caller is
  /// being disposed, because it keeps the route [State] and never looks up
  /// the element tree again. Outside a phone route it always answers false.
  static bool Function() coveredReader(BuildContext context) {
    final state = _state(context);
    if (state == null) return _never;
    return () => _live[state]?.call() ?? _covered[state] == true;
  }

  static bool _never() => false;

  /// Covered phone routes pause. Desktop and grid have no gate, so a hidden
  /// conversation there still publishes its window.
  static bool paused(BuildContext context, WorkspaceController workspace) =>
      holds(context, workspace);

  /// The foreground phone page reads the shared window. A paused route keeps
  /// the controller projection.
  static bool sharedWindow(
    BuildContext context,
    WorkspaceController workspace, {
    required bool direct,
    required bool visible,
  }) => direct && visible && !paused(context, workspace);

  /// Covered, or a channel or DM page whose workspace channel is still the
  /// previous one.
  static bool holds(BuildContext context, WorkspaceController workspace) {
    final state = _state(context);
    if (state == null) return false;
    if (_covered[state] == true) return true;
    final location = _location[state];
    if (location == null) return false;
    if (location.route != RaftRoute.channel && location.route != RaftRoute.dm) {
      return false;
    }
    return workspace.channel?.id != location.entityId;
  }

  /// The shell keeps a covered channel page on its last frame. The page that
  /// owns the current location still rebuilds when that channel is missing,
  /// so loading can become the explicit unavailable state.
  static bool staleChannel(
    RaftLocation location,
    WorkspaceController workspace,
  ) {
    if (location.route != RaftRoute.channel && location.route != RaftRoute.dm) {
      return false;
    }
    if (workspace.missingConversationChannelId == location.entityId) {
      return false;
    }
    return workspace.channel?.id != location.entityId;
  }
}

/// What [retainWhileCovered] keeps for one owner. This hangs off the owner
/// instead of being fields of its state: the structure audit counts every new
/// instance field on those states.
final _retained = Expando<_Retained>();

class _Retained {
  Widget? last;
  bool Function()? covered;
  VoidCallback? release;
}

/// The listeners of one route's covered flag. Not a [ChangeNotifier]: the
/// route state that owns it has no place to dispose one.
class _Flips {
  final _listeners = <VoidCallback>[];
  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}

/// Builds [build] unless the phone page of [owner] is covered or leaving and
/// has built before: then the last result stays.
///
/// Back moves the workspace to the previous page at once, and the workspace's
/// thread, parent message and source channel follow its location. The page
/// being popped stays on screen for the whole slide and rebuilds when its
/// tickers turn off; reading that live state made its title lose the channel,
/// its parent message vanish and "1 replies" become "No replies yet" while it
/// slid away. A covered page repaints nothing and is built again, from the
/// workspace, when it is shown again. A page that was never built (born under
/// another one) builds normally. Outside a phone route nothing is retained.
Widget retainWhileCovered(
  State owner,
  BuildContext context,
  Widget Function(BuildContext context) build,
) {
  final held = _retained[owner] ??= _Retained();
  if (held.covered == null) {
    held.covered = MobileRouteGate.coveredReader(context);
    final flips = MobileRouteGate._flipsOf(context);
    if (flips != null) {
      void refresh() {
        if (!owner.mounted) {
          flips.removeListener(refresh);
        } else if (!held.covered!()) {
          void rebuild() {
            // ignore: invalid_use_of_protected_member
            if (owner.mounted) owner.setState(() {});
          }

          // The flag also flips while the tree builds (the route's widget
          // changed): that build reads the new flag on its own, so nothing
          // is marked dirty from inside it.
          if (SchedulerBinding.instance.schedulerPhase ==
              SchedulerPhase.persistentCallbacks) {
            SchedulerBinding.instance.addPostFrameCallback((_) => rebuild());
          } else {
            rebuild();
          }
        }
      }

      flips.addListener(refresh);
      held.release = () => flips.removeListener(refresh);
    }
  }
  final last = held.last;
  if (last != null && held.covered!()) return last;
  return held.last = build(context);
}

/// Stops [owner] listening to its route; called when its state is disposed.
void releaseRetained(Object owner) => _retained[owner]?.release?.call();

/// [retainWhileCovered] for a subtree that is built from a method.
class RetainWhileCovered extends StatefulWidget {
  const RetainWhileCovered({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<RetainWhileCovered> createState() => _RetainWhileCoveredState();
}

class _RetainWhileCoveredState extends State<RetainWhileCovered> {
  @override
  void dispose() {
    releaseRetained(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      retainWhileCovered(this, context, widget.builder);
}

/// The state of a page that sits in the phone Navigator: it observes the
/// bindings, and its [build] is [retainWhileCovered] of [buildLive].
abstract class PhonePageState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  Widget buildLive(BuildContext context);

  @override
  void dispose() {
    releaseRetained(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      retainWhileCovered(this, context, buildLive);
}
