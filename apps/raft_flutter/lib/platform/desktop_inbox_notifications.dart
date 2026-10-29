import 'dart:async';

import '../data/source_activity_unread_store.dart';
import '../data/workspace_controller.dart';
import 'background_inbox.dart';
import 'background_notifications.dart' show notificationPayload;
import 'native_notifications.dart';

/// OS alerts from the same accepted, socket-driven inbox as Activity's badge.
/// No second connection, inbox request or periodic polling owner is created.
class DesktopInboxNotifications {
  DesktopInboxNotifications({
    required this.notifications,
    BackgroundInboxStore? storage,
    DateTime Function()? clock,
  }) : _store = storage ?? BackgroundInboxStore(),
       clock = clock ?? DateTime.now {
    notifications.addListener(sync);
  }

  final NativeNotificationService notifications;
  final DateTime Function() clock;
  final BackgroundInboxStore _store;
  WorkspaceController? workspace;
  SourceActivityUnreadStore? _activity;
  Object? identity;
  int epoch = 0;
  bool closed = false, dirty = false;
  Future<void> prepared = Future.value();
  Future<void>? delivering;

  Object? activeIdentity(WorkspaceController? w) {
    final activity = w?.services.activityUnreadIfBound;
    if (w == null ||
        activity?.scope == null ||
        !notifications.enabled ||
        notifications.deliveryAllowed?.call() == false ||
        w.foreground ||
        !w.client.signedIn ||
        w.server?.id != w.client.serverId ||
        w.client.serverId == null) {
      return null;
    }
    return (
      w,
      w.client.generation,
      notificationScope(w.client),
      w.server?.string('role'),
      activity!.scope,
      activity.authorityEpoch,
    );
  }

  void bind(WorkspaceController? next) {
    if (!identical(next, workspace)) {
      workspace?.removeListener(sync);
      workspace?.foregroundChanges.removeListener(sync);
      _activity?.removeListener(inboxChanged);
      _activity = null;
      workspace = next;
      next?.addListener(sync);
      next?.foregroundChanges.addListener(sync);
    }
    sync();
  }

  void sync() {
    if (closed) return;
    final w = workspace;
    final activity = w?.services.activityUnreadIfBound;
    if (!identical(activity, _activity)) {
      _activity?.removeListener(inboxChanged);
      _activity = activity?..addListener(inboxChanged);
    }
    final next = activeIdentity(w);
    if (identity == next) return;
    identity = next;
    final revision = ++epoch;
    if (next == null || w == null) return;
    final scope = notificationScope(w.client);
    prepared = () async {
      final old = await _store.state(scope);
      if (!valid(w, revision)) return;
      // Never turn foreground arrivals or old unread backlog into new alerts.
      await _store.save(scope, {
        'since': clock().toUtc().toIso8601String(),
        'seen': old?['seen'] ?? <String>[],
      });
    }().catchError((Object _) {});
  }

  bool valid(WorkspaceController w, int revision) =>
      !closed &&
      epoch == revision &&
      identity != null &&
      identical(workspace, w) &&
      identity == activeIdentity(w);

  void inboxChanged() {
    sync();
    if (closed || identity == null) return;
    dirty = true;
    unawaited(deliverPending());
  }

  Future<void> deliverPending() => delivering ??= _drain().whenComplete(() {
    delivering = null;
    if (dirty && !closed) unawaited(deliverPending());
  });

  Future<void> _drain() async {
    while (dirty && !closed) {
      dirty = false;
      final w = workspace, revision = epoch;
      if (w == null || !valid(w, revision)) continue;
      await prepared;
      if (!valid(w, revision)) continue;
      try {
        final scope = notificationScope(w.client);
        final state = await _store.state(scope);
        final since = DateTime.tryParse('${state?['since']}');
        if (since == null || !valid(w, revision)) continue;
        final candidates = <BackgroundInboxAlert>[];
        for (final row in w.services.activityUnreadIfBound?.acceptedRows ?? const []) {
          final alert = BackgroundInboxAlert.fromRow(
            row,
            w.client.serverId!,
            since,
          );
          if (alert != null &&
              !await _store.seen(scope, alert.target.messageId!)) {
            candidates.add(alert);
          }
        }
        if (candidates.isEmpty || !valid(w, revision)) continue;
        await notifications.refreshPermission();
        if (!valid(w, revision)) continue;
        // Unread data is already accepted by the shared inbox owner. Only the
        // OS push policy needs its separate mounted settings contract.
        final preferences = await w.sharedQuery(
          '/servers/${w.client.serverId}/notification-settings',
        );
        if (!valid(w, revision) ||
            preferences is! Map ||
            preferences['serverPushMuted'] == true) {
          continue;
        }
        final mode = preferences['serverPushMode'];
        if (mode != 'all' && mode != 'mentions') continue;
        var count = 0;
        for (final alert in candidates) {
          if (!valid(w, revision)) break;
          final stillUnread = w.services.activityUnreadIfBound?.acceptedRows.any(
            (latest) =>
                BackgroundInboxAlert.fromRow(
                  latest,
                  w.client.serverId!,
                  since,
                  mentionsOnly: mode == 'mentions',
                )?.target.messageId ==
                alert.target.messageId,
          );
          if (stillUnread != true) continue;
          await notifications.show(
            title: alert.title,
            body: alert.body,
            payload: notificationPayload(w.client, alert.target),
            unread: alert.unread,
          );
          if (!valid(w, revision)) break;
          if (notifications.error == null) {
            await _store.mark(scope, alert.target.messageId!);
          }
          if (++count >= 5) break;
        }
      } catch (_) {
        // Transient errors retry on the next accepted socket-driven window.
      }
    }
  }

  void dispose() {
    if (closed) return;
    closed = true;
    ++epoch;
    dirty = false;
    notifications.removeListener(sync);
    workspace?.removeListener(sync);
    workspace?.foregroundChanges.removeListener(sync);
    _activity?.removeListener(inboxChanged);
    _activity = null;
  }
}
