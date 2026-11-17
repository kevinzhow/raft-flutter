// Source: packages/web/src/components/thread/activitySwipeActions.ts at v1.24.0.
// Done and Unfollow take the row out of the list at once and are written when
// their Undo toast closes; Mute applies at once and Undo un-mutes. The same on
// every route: swipe, the row's Done button and the row menu.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart' show RaftChannel;
import 'package:raft_ui/raft_ui.dart';

import '../data/activity_object_rows.dart';
import '../data/object_activity_api.dart';
import '../data/source_read_all_transport.dart';
import '../data/workspace_controller.dart';
import 'resource_filters.dart' show activityMutation;

/// Web `swipeDoneCommitItem`: the row to write a waiting Done for, or null to
/// write nothing. The person acted on what they saw: a row that has moved on
/// since (newer activity) is not written and comes back with its news. A row
/// the list no longer holds is still written, as it was swiped.
Map<String, dynamic>? swipeDoneCommitItem(
  Map<String, dynamic> swiped,
  Map<String, dynamic>? current,
) {
  if (current == null) return swiped;
  if (current['kind'] == 'mention_action' ||
      swiped['kind'] == 'mention_action') {
    return current;
  }
  if (isActivityObjectRow(current) || isActivityObjectRow(swiped)) {
    return isActivityObjectRow(current) &&
            isActivityObjectRow(swiped) &&
            current['doneFrontierSeq'] == swiped['doneFrontierSeq']
        ? current
        : null;
  }
  final moved =
      current['latestActivitySeq'] != swiped['latestActivitySeq'] ||
      current['doneFrontierSeq'] != swiped['doneFrontierSeq'];
  return moved ? null : current;
}

/// What the controller needs from the Activity page.
class ActivityUndoDeps {
  const ActivityUndoDeps({
    required this.w,
    required this.context,
    required this.key,
    required this.listed,
    required this.mountedAction,
    required this.accepts,
  });
  final WorkspaceController w;

  /// The mounted page's context (a toast host above it); null once gone.
  final BuildContext? Function() context;

  /// The identity of a row in the list.
  final String? Function(Map<String, dynamic> row) key;

  /// The row the list holds now for [key], or null when it holds none (another
  /// filter, scope or a row that left).
  final Map<String, dynamic>? Function(String key) listed;

  /// The page still shows this server and identity (its own guard).
  final bool Function() accepts;

  /// The page's own Done / Unfollow for a row it still lists.
  final Future<void> Function(Map<String, dynamic> row, String action)
  mountedAction;
}

class _Pending {
  _Pending(this.action, this.row, this.key, this.serverId);
  final String action;
  final Map<String, dynamic> row;
  final String key;
  final String? serverId;
  RaftToastHandle? handle;
  bool settled = false;
}

class ActivityUndo extends ChangeNotifier with WidgetsBindingObserver {
  ActivityUndo(this.deps) {
    WidgetsBinding.instance.addObserver(this);
  }
  final ActivityUndoDeps deps;

  _Pending? _pending;
  final _unfollowed = <String>{};
  bool _disposed = false;

  /// A row out of the list: its Done or Unfollow waits out its Undo, or it was
  /// unfollowed while this list is shown.
  bool hides(String? key) =>
      key != null &&
      (_unfollowed.contains(key) ||
          (_pending?.key == key && !_pending!.settled));

  bool get hasPending => _pending != null;
  bool get hasHidden => _pending != null || _unfollowed.isNotEmpty;

  /// Done on every route.
  void done(Map<String, dynamic> row) =>
      _wait('done', row, 'Marked as done', {});

  /// Unfollow on every route (a followed thread).
  void unfollow(Map<String, dynamic> row, String conversation) => _wait(
    'unfollow',
    row,
    'Unfollowed thread in {conversation}',
    {'conversation': conversation},
  );

  void _wait(
    String action,
    Map<String, dynamic> row,
    String title,
    Map<String, Object?> args,
  ) {
    final key = deps.key(row);
    if (key == null) return;
    // One toast at a time: a newer action writes the older row.
    flush();
    final pending = _Pending(action, row, key, deps.w.server?.id);
    _pending = pending;
    notifyListeners();
    final context = deps.context();
    final handle = context == null
        ? null
        : showRaftToastHandle(
            context,
            args.isEmpty ? title : raftFormat(context, title, args),
            tone: RaftToastRecipeTone.success,
            actionLabel: 'Undo',
            onAction: () => _settle(pending, write: false),
            onClose: (reason) {
              if (reason != RaftToastCloseReason.action) {
                _settle(pending, write: true);
              }
            },
          );
    // No Undo can be offered (no toast host): write now.
    if (handle == null) {
      _settle(pending, write: true);
      return;
    }
    pending.handle = handle;
  }

  void _settle(_Pending pending, {required bool write, bool notify = true}) {
    if (pending.settled) return;
    pending.settled = true;
    if (identical(_pending, pending)) _pending = null;
    if (!write) {
      if (notify && !_disposed) notifyListeners();
      return;
    }
    if (pending.action == 'unfollow') {
      unawaited(_commitUnfollow(pending));
    } else {
      unawaited(_commitDone(pending));
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _commitDone(_Pending pending) async {
    final current = _disposed ? null : deps.listed(pending.key);
    final row = swipeDoneCommitItem(pending.row, current);
    // Newer activity: nothing is written, the row is back with its news.
    if (row == null) return;
    try {
      if (current != null &&
          deps.context() != null &&
          deps.accepts() &&
          pending.serverId == deps.w.server?.id) {
        await deps.mountedAction(current, 'done');
      } else {
        await _writeDone(row, pending.serverId);
      }
    } catch (_) {}
  }

  Future<void> _commitUnfollow(_Pending pending) async {
    _unfollowed.add(pending.key);
    final current = _disposed ? null : deps.listed(pending.key);
    try {
      if (current != null &&
          deps.context() != null &&
          deps.accepts() &&
          pending.serverId == deps.w.server?.id) {
        await deps.mountedAction(current, 'unfollow');
        // Still followed after the page's write: the save failed.
        if (deps.listed(pending.key)?['isFollowing'] != false) {
          _unfollowed.remove(pending.key);
        }
      } else {
        await _writeUnfollow(pending.row, pending.serverId);
      }
    } catch (_) {
      _unfollowed.remove(pending.key);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _post(String path, Object? data, String? serverId) =>
      serverId == null || serverId == deps.w.server?.id
      ? deps.w.client.post(path, data: data)
      : deps.w.client.postForServer(serverId, path, data: data);

  /// The write of a Done the page cannot make (it left, or the list shows
  /// another filter now): only the request, on the server it was asked on.
  Future<void> _writeDone(Map<String, dynamic> row, String? serverId) async {
    if (isActivityObjectRow(row)) {
      return ObjectActivityApi(deps.w.client).done(row, serverId: serverId);
    }
    final mutation = activityMutation(row, 'done');
    if (mutation == null) return;
    await _post(mutation.path, mutation.data, serverId);
    if (row['kind'] == 'thread') {
      final id = row['threadChannelId'];
      if (id is String) {
        unawaited(
          SourceReadAllTransport.of(deps.w.client)
              .threadDone(
                id,
                identity: SourceReadAllIdentity.capture(deps.w.client),
              )
              .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
        );
      }
    }
  }

  Future<void> _writeUnfollow(
    Map<String, dynamic> row,
    String? serverId,
  ) async {
    final mutation = activityMutation(row, 'unfollow');
    if (mutation != null) await _post(mutation.path, mutation.data, serverId);
  }

  /// Newer activity on the row waiting to be Done calls the Done off now, so a
  /// row is not left hidden under a toast that says it is done. A waiting
  /// Unfollow stays.
  void reconcile() {
    final pending = _pending;
    if (pending == null || pending.action != 'done') return;
    final current = deps.listed(pending.key);
    if (current != null && swipeDoneCommitItem(pending.row, current) == null) {
      _cancel(pending);
    }
  }

  // Called while the page builds: the row shows again in that build.
  void _cancel(_Pending pending) {
    _settle(pending, write: false, notify: false);
    _dismissLater(pending.handle);
  }

  /// Writes what waits now: another action, the page leaving, the app going to
  /// the background.
  void flush() {
    final pending = _pending;
    if (pending == null) return;
    _settle(pending, write: true);
    _dismissLater(pending.handle);
  }

  // The toast host rebuilds as the toast goes: never while the tree is locked
  // (a page being disposed) or building.
  void _dismissLater(RaftToastHandle? handle) {
    if (handle == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => handle.dismiss());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      flush();
    }
  }

  /// Mute applies at once; [withToast] (the swipe's) offers Undo, which
  /// un-mutes once the mute's own save is done. The menu's Mute / Unmute is
  /// immediate and silent.
  Future<void> mute(
    Map<String, dynamic> row,
    RaftChannel channel,
    String conversation, {
    required bool muted,
    bool withToast = false,
  }) async {
    flush();
    final server = deps.w.server?.id;
    final saving = _setMute(channel.id, muted);
    final context = deps.context();
    if (!withToast || !muted || context == null) {
      await saving;
      return;
    }
    RaftToastHandle? handle;
    handle = showRaftToastHandle(
      context,
      raftFormat(context, 'Muted activity in {conversation}', {
        'conversation': conversation,
      }),
      tone: RaftToastRecipeTone.success,
      actionLabel: 'Undo',
      onAction: () => unawaited(
        saving.then((saved) {
          if (!saved || deps.w.server?.id != server) return;
          final now = deps.w.channelById(channel.id);
          if (now?.flag('activityMuted') == true) {
            unawaited(_setMute(channel.id, false));
          }
        }),
      ),
    );
    // A failed save rolls back and says so with its own toast, in place of
    // this one.
    if (!await saving) _dismissLater(handle);
  }

  /// Sidebar.tsx `toggleChannelActivityMute`: optimistic, PATCH, adopt the
  /// reply; a failure restores the row (when still untouched) and toasts.
  Future<bool> _setMute(String id, bool next) async {
    final c = deps.w.channelById(id);
    if (c == null) return false;
    final previous = {
      'activityMuted': c.flag('activityMuted'),
      'muteFromSeq': c.json['muteFromSeq'],
      'prefsVersion': c.json['prefsVersion'],
    };
    deps.w.setActivityMuteState(id, {...previous, 'activityMuted': next});
    try {
      final reply = await deps.w.command(
        'PATCH',
        '/channels/$id/notification-settings',
        data: {'activityMuted': next},
      );
      if (reply is Map) {
        deps.w.setActivityMuteState(id, {
          'activityMuted': reply['activityMuted'] == true,
          'muteFromSeq': reply['muteFromSeq'],
          'prefsVersion': reply['prefsVersion'],
        });
      }
      return true;
    } catch (_) {
      final held = deps.w.channelById(id);
      if (held != null &&
          held.flag('activityMuted') == next &&
          held.json['prefsVersion'] == previous['prefsVersion']) {
        deps.w.setActivityMuteState(id, previous);
        final context = deps.context();
        if (context != null && context.mounted) {
          showRaftToast(
            context,
            next
                ? 'Failed to mute Activity for this conversation.'
                : 'Failed to unmute Activity for this conversation.',
          );
        }
      }
      return false;
    }
  }

  @override
  void dispose() {
    // Written without the page: it is going.
    _disposed = true;
    flush();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
