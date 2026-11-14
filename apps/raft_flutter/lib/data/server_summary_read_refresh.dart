// Source: packages/web/src/store/serverUnreadSummaryRefresh.ts at v1.24.0-source.1
import 'dart:async';

/// A read the server saved (on this device or another one): the cross-server
/// unread summary (tab title, app badge, rail count) is read again 300 ms
/// later rather than at the next 2-minute sweep. The delay lets the read land
/// first, so the summary cannot still count what was just read. A burst of
/// frames is one request: while one is pending, later calls are ignored.
///
/// Holds a timer only between a frame and its refresh; [dispose] cancels it.
class ServerSummaryReadRefresh {
  ServerSummaryReadRefresh(this._refresh);

  static const delay = Duration(milliseconds: 300);

  final void Function() _refresh;
  Timer? _pending;
  bool _disposed = false;

  void afterRead() {
    if (_disposed || _pending != null) return;
    _pending = Timer(delay, () {
      _pending = null;
      if (!_disposed) _refresh();
    });
  }

  /// Whether a frame's scope is complete enough for Web's
  /// `normalizeReadStateUpdated` to accept it (a bulk frame refreshes
  /// whatever its entries were, like Web's loop-then-refresh).
  static bool acceptsSingle(Object? payload) =>
      payload is Map &&
      payload['serverId'] is String &&
      (payload['serverId'] as String).isNotEmpty &&
      payload['scopeId'] is String &&
      (payload['scopeId'] as String).isNotEmpty &&
      payload['readStateVersion'] is int;

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _pending = null;
  }
}
