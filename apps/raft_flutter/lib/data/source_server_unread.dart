import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'workspace_controller.dart';

@immutable
class SourceServerUnread {
  const SourceServerUnread({this.activityUnreadCount, required this.pushMuted});
  final int? activityUnreadCount;
  final bool pushMuted;
}

/// ServerUnreadSummary.ts: only the proven Activity count may paint a menu row.
/// This owner is independent of the current server's accepted inbox total.
class SourceServerUnreadStore extends ChangeNotifier {
  SourceServerUnreadStore(this.workspace);
  final WorkspaceController workspace;
  String? _scope;
  int _request = 0;
  bool _disposed = false;
  Map<String, SourceServerUnread> _accepted = {};
  SourceServerUnread? operator [](String serverId) => _accepted[serverId];
  String get scope => jsonEncode([
    workspace.client.origin,
    workspace.client.generation,
    workspace.client.user?.id,
    workspace.server?.id,
    workspace.server?.string('role'),
  ]);
  void synchronize() {
    if (_scope == scope) return;
    _scope = scope;
    ++_request;
    _accepted = {};
  }

  Future<void> refresh() async {
    synchronize();
    final authority = _scope, ticket = ++_request;
    try {
      final response = await workspace.query('/servers/unread-summary');
      if (_disposed || authority != scope || ticket != _request) return;
      final next = <String, SourceServerUnread>{};
      if (response is List) {
        for (final row in response) {
          if (row is! Map ||
              row['serverId'] is! String ||
              (row['serverId'] as String).isEmpty ||
              !_sourceNumber(row['unreadCount']).isFinite) {
            continue;
          }
          final activity = row['activityUnreadCount'];
          next[row['serverId']] = SourceServerUnread(
            activityUnreadCount:
                activity is num &&
                    activity.isFinite &&
                    activity >= 0 &&
                    activity % 1 == 0 &&
                    activity <= 9007199254740991
                ? activity.toInt()
                : null,
            pushMuted: row['serverPushMuted'] == true,
          );
        }
      }
      _accepted = next;
      notifyListeners();
    } catch (_) {
      // Source serverStore.ts699–720 retains accepted values on refresh error.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    super.dispose();
  }
}

// Number(row.unreadCount) validates only the legacy-summary receipt. It does
// not make that broader count eligible to paint an Activity badge.
num _sourceNumber(Object? value) => switch (value) {
  null => 0,
  num v => v,
  bool v => v ? 1 : 0,
  String v when v.trim().isEmpty => 0,
  String v => num.tryParse(v.trim()) ?? double.nan,
  _ => double.nan,
};
