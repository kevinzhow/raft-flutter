import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart' show RaftEvent;
import 'package:raft_sync/raft_sync.dart' show readNotificationPrefsUpdate;
import 'package:raft_ui/raft_ui.dart' show RaftForegroundPeriodic;

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

  DateTime? _startedAt;
  int _reading = 0;
  Future<void>? _inFlight;
  String? _inFlightScope;

  /// Sidebar.tsx's 2-minute catch-all sweep: the socket cannot tell the
  /// selected server about the other servers, so their badges are re-read on
  /// this interval (live edges refresh sooner).
  static const sweepInterval = Duration(minutes: 2);
  RaftForegroundPeriodic? _sweep;
  StreamSubscription<RaftEvent>? _prefsEvents;

  /// Armed by the first read, which the shell starts once the member and
  /// servers are known (Sidebar.tsx's effect needs both): the interval sweep
  /// and the server-level notification-prefs refresh
  /// (`SERVER_NOTIFICATION_PREFS_UPDATED_EVENT`: channel-level prefs do not
  /// touch the summary).
  void _keepFresh() {
    if (_disposed) return;
    // Stops while the app is hidden or paused, like every other poll; the
    // resume refresh and live edges catch up.
    _sweep ??= RaftForegroundPeriodic(
      sweepInterval,
      () => unawaited(refresh()),
    );
    _prefsEvents ??= workspace.client.events.listen((event) {
      if (event.name != 'notification_prefs:updated') return;
      final update = readNotificationPrefsUpdate(event.payload);
      if (update != null && update['type'] == 'server') unawaited(refresh());
    });
  }

  /// The time source of the freshness guard; tests that pump fake time
  /// replace it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;
  static const freshness = Duration(seconds: 5);

  /// Sidebar.tsx reloads the summary when the window gains focus or becomes
  /// visible: the same on return to the foreground, unless it was read within
  /// [freshness] (rapid app switches, or the resume handshake's own refresh).
  Future<void> refreshOnResume() {
    final at = _startedAt;
    if (_disposed ||
        _reading > 0 ||
        at != null && clock().difference(at) < freshness) {
      return Future.value();
    }
    return refresh();
  }

  /// Concurrent callers share one read (Web `coalesce`).
  Future<void> refresh() {
    synchronize();
    _keepFresh();
    final pending = _inFlight;
    if (pending != null && _inFlightScope == _scope) return pending;
    _inFlightScope = _scope;
    final read = _inFlight = _read();
    unawaited(
      read.whenComplete(() {
        if (identical(_inFlight, read)) _inFlight = null;
      }),
    );
    return read;
  }

  Future<void> _read() async {
    final authority = _scope, ticket = ++_request;
    _startedAt = clock();
    _reading++;
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
    } finally {
      _reading--;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    _sweep?.dispose();
    unawaited(_prefsEvents?.cancel());
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
