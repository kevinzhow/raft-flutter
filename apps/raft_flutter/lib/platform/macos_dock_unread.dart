import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:raft_client/raft_client.dart';

import '../data/account_activity_unread.dart';
import '../data/workspace_controller.dart';
import 'windows_tray.dart';

/// Native icon writer for the account's shared Activity count. Android keeps
/// its existing notification-number path and borrows [counts] through its
/// notification reconciler instead of invoking AppBadgePlus.
class MacOSDockUnread {
  MacOSDockUnread({
    TargetPlatform? platform,
    Future<void> Function(int)? write,
    Duration refreshInterval = const Duration(seconds: 30),
  }) : supported =
           !kIsWeb &&
           const {
             TargetPlatform.macOS,
             TargetPlatform.iOS,
             TargetPlatform.windows,
           }.contains(platform ?? defaultTargetPlatform),
       _accountSupported =
           !kIsWeb &&
           const {
             TargetPlatform.android,
             TargetPlatform.iOS,
             TargetPlatform.macOS,
             TargetPlatform.windows,
           }.contains(platform ?? defaultTargetPlatform),
       counts = AccountActivityUnread(refreshInterval: refreshInterval),
       _write =
           write ??
           ((platform ?? defaultTargetPlatform) == TargetPlatform.windows
               ? WindowsTray.writeUnread
               : _writeNative) {
    counts.addListener(_publish);
    counts.successfulRefresh.addListener(_publish);
  }

  static Future<void> _writeNative(int count) =>
      AppBadgePlus.updateBadge(count);
  final bool supported;
  final bool _accountSupported;
  final AccountActivityUnread counts;
  final Future<void> Function(int) _write;
  bool _closed = false, _accountManaged = false, _resyncPending = false;
  int? _wanted, _written, _pendingCount;
  int _revision = 0;
  Object? _account;
  Future<void> _tail = Future.value();
  Future<void> get settled async {
    while (true) {
      final pending = _tail;
      await pending;
      if (identical(pending, _tail)) return;
    }
  }

  /// Settings and resume are explicit native visibility boundaries: a native
  /// success before permission was granted may still have painted no badge.
  Future<void> resync() async {
    final account = counts.authority;
    if (_closed || !supported || account == null || counts.total == null) {
      return;
    }
    if (!_resyncPending) {
      _resyncPending = true;
      _tail = _tail
          .then((_) {
            if (_closed || account != counts.authority) return;
            _written = _pendingCount = null;
            _publish();
          })
          .whenComplete(() => _resyncPending = false);
    }
    await settled;
  }

  /// The app root, rather than its selected workspace, owns this lifetime.
  void bindAccount(RaftClient? client) {
    _accountManaged = true;
    counts.bindClient(_accountSupported ? client : null);
  }

  void bind(WorkspaceController? next) {
    if (_closed || !supported && !_accountManaged) return;
    if (!_accountManaged) counts.bindClient(next?.client, refreshNow: false);
    counts.bindWorkspace(next);
    _publish();
  }

  Future<void> refresh() => counts.refresh();

  void _publish() {
    if (_closed || !supported) return;
    final next = counts.authority;
    if (next == null || _account != null && next != _account) _set(0);
    _account = next;
    final total = counts.total;
    if (total != null) _set(total);
  }

  void _set(int count) {
    if (_wanted == count && (_written == count || _pendingCount == count)) {
      return;
    }
    _wanted = count;
    _pendingCount = count;
    final ticket = ++_revision;
    _tail = _tail.then((_) async {
      if (ticket != _revision) return;
      try {
        await _write(count);
        _written = count;
      } catch (_) {
        _written = null; // Retry on the next accepted account update.
      } finally {
        if (ticket == _revision) _pendingCount = null;
      }
    });
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    counts.removeListener(_publish);
    counts.successfulRefresh.removeListener(_publish);
    counts.dispose();
    if (supported) _set(0);
    await _tail;
  }
}
