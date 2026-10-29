import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/activity_attention.dart';
import 'account_activity_unread.dart';
import '../data/resource_row_reconcile.dart' show activityScopeId;
import '../data/source_activity_unread_store.dart';
import '../data/workspace_controller.dart';
import 'background_inbox.dart';
import 'background_notifications.dart' show notificationPayload;
import 'native_notifications.dart';

/// Keeps the system notifications equal to the server's Activity unread state.
///
/// The accepted Activity window (the one the in-app badge paints) is the single
/// source of truth. Whatever reads a conversation (this app, the Web, another
/// device, "mark all read") changes that window, and this class follows it:
///
/// * a conversation whose row is read (`unreadCount` 0, or Done) loses its
///   notification at once; a server total of 0 removes every one;
/// * a conversation whose count moved is refreshed in place, without an alert;
/// * Android only: unread conversations that have no notification yet (backlog
///   from before the app started, or from a missed push) get a quiet one when
///   the app is in the background, so the launcher's icon badge (the sum of
///   the notifications' numbers) equals the Activity total. iOS and macOS set
///   the icon badge explicitly instead ([MacOSDockUnread]).
///
/// A conversation the window does not list is left alone: the window is
/// bounded, so absence is not a read receipt.
class NotificationReconciler {
  NotificationReconciler({
    required this.notifications,
    DateTime Function()? clock,
    AccountActivityUnread? accountUnread,
  }) : _clock = clock ?? DateTime.now,
       _ownsAccountUnread = accountUnread == null,
       accountUnread = accountUnread ?? AccountActivityUnread() {
    this.accountUnread.addListener(_changed);
    this.accountUnread.successfulRefresh.addListener(_accountRefreshed);
  }

  final NativeNotificationService notifications;
  final AccountActivityUnread accountUnread;
  final bool _ownsAccountUnread;
  final DateTime Function() _clock;
  WorkspaceController? _workspace;
  SourceActivityUnreadStore? _store;
  bool _closed = false, _dirty = false;
  Future<void>? _running;
  int _epoch = 0;
  ({DateTime at, Object? value, Object scope})? _settings;

  /// Notification settings are read again after this long.
  static const settingsFreshness = Duration(seconds: 30);

  /// Completes when the reconciliation in flight (and any it owes) is done.
  Future<void> get settled async {
    while (_running != null) {
      await _running;
    }
  }

  void bind(WorkspaceController? next) {
    if (_closed || identical(next, _workspace)) return;
    _detach();
    _workspace = next;
    if (_ownsAccountUnread) {
      accountUnread.bindClient(next?.client, refreshNow: false);
    }
    accountUnread.bindWorkspace(next);
    _epoch++;
    _settings = null;
    if (next == null) return;
    next.addListener(_attach);
    next.foregroundChanges.addListener(_changed);
    _attach();
  }

  /// Borrows the session's existing projection without creating or starting it.
  void _attach() {
    final w = _workspace;
    if (_closed || w == null) return;
    final bound = w.services.activityUnreadIfBound;
    if (!identical(bound, _store)) {
      _store?.removeListener(_changed);
      _store = bound?..addListener(_changed);
    }
    _changed();
  }

  void _detach() {
    final w = _workspace;
    final store = _store;
    _store = null;
    _workspace = null;
    // The workspace may already be disposed when the app tears down.
    try {
      store?.removeListener(_changed);
      w?.removeListener(_attach);
      w?.foregroundChanges.removeListener(_changed);
    } catch (_) {}
  }

  /// The notification service changed (initialized, enabled, disabled).
  void notificationsChanged() => _changed();

  void _accountRefreshed() {
    if (_workspace == null) _changed();
  }

  void _changed() {
    if (_closed) return;
    _dirty = true;
    _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    while (_dirty && !_closed) {
      _dirty = false;
      try {
        await reconcile();
      } catch (_) {
        // A failed pass is retried by the next window change.
      }
    }
  }

  @visibleForTesting
  Future<void> reconcile() async {
    final w = _workspace, store = _store, epoch = _epoch;
    if (!notifications.initialized) return;
    if (w == null) {
      final account = accountUnread.notificationAccount,
          total = accountUnread.total;
      if (account != null && total != null) {
        await notifications.maintainAccountUnread(
          account: account,
          total: total,
          members: accountUnread.memberIds ?? const {},
          residualKey: moreKey,
          residualPayload: moreNotificationPayload,
        );
      }
      return;
    }
    if (store == null) return;
    // Until a window is accepted nothing is known: never cancel on a guess.
    if (!store.hasAcceptedWindow) return;
    final total = store.totalUnreadCount!;
    final rows = store.acceptedRows;
    final scope = store.scope, authority = store.authorityEpoch;
    bool stale() =>
        _closed ||
        epoch != _epoch ||
        !identical(_workspace, w) ||
        !identical(w.services.activityUnreadIfBound, store) ||
        scope != store.scope ||
        authority != store.authorityEpoch ||
        !store.hasAcceptedWindow;

    final live = notifications.liveUnread;
    final read = <String>[];
    final moved = <String>[];
    for (final entry in live.entries) {
      if (entry.key == moreKey) continue;
      if (total == 0) {
        read.add(entry.key);
        continue;
      }
      final unread = activityRowUnread(rows, entry.key);
      if (unread == null) continue;
      if (unread == 0) {
        read.add(entry.key);
      } else if (unread != entry.value) {
        moved.add(entry.key);
      }
    }
    if (read.isNotEmpty) await notifications.cancelConversations(read);
    if (stale()) return;

    // Posting restores shade state only where the launcher badge is built from
    // it, and only if the member enabled alerts for this server.
    if (notifications.platform != TargetPlatform.android ||
        !notifications.enabled) {
      return;
    }
    final serverId = w.client.serverId;
    if (serverId == null || w.client.user == null) return;
    final background = !w.foreground;
    final wanted = <String>{...moved};
    if (background) {
      for (final row in rows) {
        final id = activityScopeId(row);
        if (id != null && !live.containsKey(id)) wanted.add(id);
      }
    }
    String? mode;
    var modeRead = false;
    Future<String?> pushMode() async {
      if (!modeRead) {
        mode = await _pushMode(w);
        modeRead = true;
      }
      return mode;
    }

    if (wanted.isNotEmpty) {
      if (await pushMode() == null || stale()) return;
      for (final row in rows) {
        final id = activityScopeId(row);
        if (id == null || !wanted.contains(id)) continue;
        final alert = BackgroundInboxAlert.fromRow(
          row,
          serverId,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          mentionsOnly: mode == 'mentions',
        );
        if (alert == null) continue;
        await notifications.show(
          title: alert.title,
          body: alert.body,
          payload: notificationPayload(w.client, alert.target),
          unread: alert.unread,
          quiet: true,
        );
        if (stale()) return;
      }
    }

    if (stale()) return;
    final appTotal = accountUnread.total;
    if (appTotal == null) return;
    // The window is bounded (first page), the total is not: what the
    // conversation notifications do not account for is one more quiet
    // notification, so the launcher's sum is the Activity total.
    var accounted = 0;
    final now = notifications.liveUnread;
    for (final entry in now.entries) {
      if (entry.key == moreKey) continue;
      accounted += activityRowUnread(rows, entry.key) ?? entry.value;
    }
    final residual = appTotal - accounted > 0 ? appTotal - accounted : 0;
    final had = now[moreKey];
    if (residual == 0) {
      if (had != null) await notifications.cancelConversations([moreKey]);
    } else if (had != residual && (had != null || background)) {
      if (await pushMode() != 'all' || stale()) return;
      await notifications.show(
        title: 'Raft',
        body: notifications
            .localize('{count} unread')
            .replaceAll('{count}', '$residual'),
        payload: moreNotificationPayload,
        conversation: moreKey,
        unread: residual,
        quiet: true,
      );
    }
  }

  /// The pseudo-conversation of unread messages beyond the Activity window.
  static const moreKey = '*more*';

  /// Opens the app, nothing else (it carries no target).
  static const moreNotificationPayload = 'raft-activity';

  /// `all`, `mentions`, or null when the member muted this server's push or
  /// the setting cannot be read.
  Future<String?> _pushMode(WorkspaceController w) async {
    Object currentScope() => (
      notificationScope(w.client),
      w.services.activityUnreadIfBound?.scope,
      w.services.activityUnreadIfBound?.authorityEpoch,
    );
    final scope = currentScope();
    final cached = _settings;
    Object? value;
    if (cached != null &&
        cached.scope == scope &&
        _clock().difference(cached.at) < settingsFreshness) {
      value = cached.value;
    } else {
      value = await w.sharedQuery(
        '/servers/${w.client.serverId}/notification-settings',
      );
      if (!_closed && identical(_workspace, w) && scope == currentScope()) {
        _settings = (at: _clock(), value: value, scope: scope);
      }
    }
    if (value is! Map || value['serverPushMuted'] == true) return null;
    final mode = value['serverPushMode'];
    return mode == 'all' || mode == 'mentions' ? mode as String : null;
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    accountUnread.removeListener(_changed);
    accountUnread.successfulRefresh.removeListener(_accountRefreshed);
    if (_ownsAccountUnread) accountUnread.dispose();
    _epoch++;
    _detach();
  }
}
