import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/device_preferences.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';

/// The three Web v1.21.23 flags that gate the unread surfaces of the sidebar
/// and Activity (`serverFeatureFlags.ts`): followed-thread unread folded onto
/// the parent channel, the sidebar "Mark All as Read" and the Activity
/// conversation list. Every one defaults off, so a server that does not name
/// the flag (or an older server) keeps today's rows exactly.
///
/// One evaluation per server identity, remembered on the device so the first
/// frame of the next launch already has the final layout. A transient failure
/// keeps the accepted value; a 401/403 turns the flags off.
class ActivityRolloutFlags extends ChangeNotifier {
  ActivityRolloutFlags._(this.w) {
    w.addListener(changed);
    _events = w.client.events.listen((event) {
      if (event.name == 'server:updated' || event.name == 'connected') {
        changed(reevaluate: true);
      }
    });
    w.services.disposeWithSession(dispose);
    changed();
  }

  static final _owners = Expando<ActivityRolloutFlags>();

  /// The flags of [w]'s presentation (created on first use).
  static ActivityRolloutFlags of(WorkspaceController w) =>
      _owners[w] ??= ActivityRolloutFlags._(w);

  /// The flags of [w] when something already asked for them; null before
  /// that. A page that only reads them (the Activity list, the timeline's
  /// controls) leaves the request to the shell, which asks as it draws the
  /// sidebar, so a surface mounted on its own makes no request.
  static ActivityRolloutFlags? peek(WorkspaceController w) => _owners[w];

  static const threadUnreadBadgeKey = 'thread_unread_badge_v0';
  static const sidebarMarkAllReadKey = 'sidebar_mark_all_read_v0';
  static const activityConversationListKey = 'activity_conversation_list_v0';
  static const keys = [
    threadUnreadBadgeKey,
    sidebarMarkAllReadKey,
    activityConversationListKey,
  ];

  final WorkspaceController w;
  StreamSubscription<RaftEvent>? _events;
  String? _scope;
  int _request = 0;
  bool _ended = false;
  Map<String, bool> _enabled = const {};

  bool get threadUnreadBadge => _enabled[threadUnreadBadgeKey] ?? false;
  bool get sidebarMarkAllRead => _enabled[sidebarMarkAllReadKey] ?? false;
  bool get activityConversationList =>
      _enabled[activityConversationListKey] ?? false;

  String get _authority => jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ]);

  /// Device-stable identity of the last evaluation (no session generation).
  List<Object?> get _memoryScope => [
    w.client.origin,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ];

  Map<String, bool> _remembered() => {
    for (final key in keys)
      if (w.server != null && w.client.user != null)
        key: FeatureFlagMemory.read(_memoryScope, key) ?? false,
  };

  /// A new principal, server or role retires the evaluated flags at once; a
  /// re-evaluation under the same identity keeps them until the answer lands.
  void changed({bool reevaluate = false}) {
    if (_ended || w.services.isDisposed()) {
      _retire();
      return;
    }
    final next = _authority;
    final same = _scope == next;
    if (same && !reevaluate) return;
    _scope = next;
    final ticket = ++_request;
    if (!same) {
      final remembered = _remembered();
      if (!mapEquals(remembered, _enabled)) {
        _enabled = remembered;
        notifyListeners();
      }
    }
    final server = w.server;
    if (server != null && w.client.user != null) {
      unawaited(_load(next, ticket, server.id));
    }
  }

  /// Evaluates again now, for example after the server answered 404
  /// `sidebar_mark_all_read_disabled` to a flag this client believed on.
  void reevaluate() => changed(reevaluate: true);

  Future<void> _load(String authority, int ticket, String server) async {
    try {
      final value = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: keys, serverId: server),
      );
      if (_ended || authority != _authority || ticket != _request) return;
      final rows = value is Map ? value['evaluations'] : null;
      _accept({
        for (final key in keys)
          key:
              rows is List &&
              rows.whereType<Map>().any(
                (row) => row['key'] == key && row['enabled'] == true,
              ),
      });
    } catch (error) {
      // Unknown is not permission: only a denial turns accepted flags off.
      if (!_ended &&
          authority == _authority &&
          ticket == _request &&
          error is RaftApiException &&
          [401, 403].contains(error.status)) {
        _accept({for (final key in keys) key: false});
      }
    }
  }

  void _accept(Map<String, bool> next) {
    FeatureFlagMemory.write(_memoryScope, next);
    if (mapEquals(next, _enabled)) return;
    _enabled = next;
    notifyListeners();
    // Surfaces that rebuild on the controller (the Activity list, the sidebar)
    // pick the new layout up with it.
    if (!w.services.isDisposed()) w.notifyListeners();
  }

  void _retire() {
    if (_ended) return;
    _ended = true;
    ++_request;
    w.removeListener(changed);
    unawaited(_events?.cancel());
    _events = null;
  }

  @override
  void dispose() {
    _retire();
    super.dispose();
  }
}
