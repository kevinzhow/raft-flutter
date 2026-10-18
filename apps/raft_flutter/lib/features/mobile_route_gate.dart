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
    _covered[state] = covered;
    _location[state] = location;
  }

  /// The location stored for the phone route that contains [context].
  static RaftLocation? locationOf(BuildContext context) {
    final state = _state(context);
    return state == null ? null : _location[state];
  }

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
