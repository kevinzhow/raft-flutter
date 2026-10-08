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
      if (event.name == 'server:updated') {
        scope = null;
        changed();
      }
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
  void changed() {
    final next = authority;
    if (scope == next || ended) return;
    scope = next;
    enabled = false;
    final ticket = ++request;
    notifyListeners();
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
      enabled =
          rows is List &&
          rows.whereType<Map>().any(
            (row) =>
                row['key'] == 'activity_sidebar_inbox_v0' &&
                row['enabled'] == true,
          );
      notifyListeners();
    } catch (_) {
      // A denied/unavailable flag is not permission to use the experimental opener.
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
