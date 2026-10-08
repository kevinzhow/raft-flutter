import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/workspace_controller.dart';

/// All application overlays belong to the account/workspace authority in which
/// they opened. Remove them directly on revocation, including busy PopScopes.
class PrivateRouteGuard extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  final Map<String, String> _scopes = {};
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
  }

  void scopeChanged(String next, {String domain = 'workspace'}) {
    if (_scopes[domain] == next) return;
    final previous = _scopes[domain];
    _scopes[domain] = next;
    if (previous == null) return;
    final stale = _routes.skip(1).toList().reversed.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in stale) {
        if (_routes.contains(route) && route.isActive) {
          navigator?.removeRoute(route);
        }
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}

String workspaceAuthority(WorkspaceController w) => jsonEncode([
  w.client.generation,
  w.client.user?.id,
  w.server?.id,
  w.server?.string('role'),
  w.channel?.id,
  w.channel?.joined,
  w.channel?.archived,
  w.channel?.json['channelCapabilities'],
]);

/// A newly loaded projection or an archive flag does not revoke visibility.
/// Only an explicit membership/permission reduction closes channel overlays.
bool channelAuthorityReduced(
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
) {
  if (before == null) return false;
  if (after == null) return true;
  if (before['joined'] == true && after['joined'] == false) return true;
  final prior = before['channelCapabilities'],
      next = after['channelCapabilities'];
  if (prior is Map && next is Map) {
    for (final entry in prior.entries) {
      if (entry.value == true && next[entry.key] == false) return true;
    }
  }
  return false;
}
