import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';

/// ThreadsInbox's mounted activity_sidebar_inbox_v0 gate. Unknown/failed
/// evaluation keeps the executable legacy1024 opener, rather than assuming768.
class DesktopActivityFlag extends ChangeNotifier {
  DesktopActivityFlag(this.w) {
    w.addListener(changed);
    events = w.client.events.listen((event) {
      if (event.name == 'server:updated') changed(reevaluate: true);
    });
    changed();
  }
  final WorkspaceController w;
  StreamSubscription<RaftEvent>? events;
  String? scope;
  bool enabled = false, ended = false;
  int request = 0;
  String get authority => jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ]);
  bool masterDetail(double width) => width >= (enabled ? 768 : 1024);
  /// A new principal/server/role retires the evaluated presentation at once.
  /// [reevaluate] (server:updated under the same authority) keeps the
  /// accepted value until the fresh evaluation lands, so the Activity page is
  /// not flipped to the legacy layout and back.
  void changed({bool reevaluate = false}) {
    final next = authority;
    if (ended || scope == next && !reevaluate) return;
    final same = scope == next;
    scope = next;
    final ticket = ++request;
    if (!same) {
      enabled = false;
      notifyListeners();
    }
    if (w.server != null && w.client.user != null) {
      load(next, ticket, w.server!.id);
    }
  }

  Future<void> load(String sourceAuthority, int ticket, String server) async {
    try {
      final value = await w.client.post(
        '/feature-flags/evaluate',
        data: {
          'keys': ['activity_sidebar_inbox_v0'],
          'serverId': server,
          'platform':
              defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS
              ? 'mobile'
              : 'web',
        },
      );
      if (ended ||
          scope != sourceAuthority ||
          authority != sourceAuthority ||
          request != ticket) {
        return;
      }
      final rows = value is Map ? value['evaluations'] : null;
      final next =
          rows is List &&
          rows.whereType<Map>().any(
            (row) =>
                row['key'] == 'activity_sidebar_inbox_v0' &&
                row['enabled'] == true,
          );
      if (next == enabled) return;
      enabled = next;
      notifyListeners();
    } catch (error) {
      // A denied/unavailable flag is not permission to use the experimental
      // opener; a transient re-evaluation failure keeps the accepted value.
      if (!ended &&
          scope == sourceAuthority &&
          request == ticket &&
          enabled &&
          error is RaftApiException &&
          [401, 403].contains(error.status)) {
        enabled = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    ended = true;
    ++request;
    w.removeListener(changed);
    events?.cancel();
    super.dispose();
  }
}
