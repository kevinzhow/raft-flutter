import 'dart:async';

import '../data/server_error_code.dart';
import '../data/source_read_all_transport.dart';
import '../data/workspace_controller.dart';
import 'activity_rollout_flags.dart';
import 'sidebar_thread_unread.dart';

/// Web `messageStore.markConversationRead`: the sidebar's "Mark All as Read"
/// reads a channel together with its followed threads in one request
/// (`POST /channels/:id/conversation-read-all`). The answer lists every scope it
/// advanced (`scopes[]` of `scopeId`, `maxReadSeq`, `readStateVersion`); each is
/// folded into the read ledger as an acknowledged frontier, then the unread
/// counts and the followed-thread list are read again.
///
/// A server that no longer has `sidebar_mark_all_read_v0` answers 404
/// `sidebar_mark_all_read_disabled`: the flags are evaluated again and only the
/// channel itself is read, as the plain "Mark as Read" would have.
Future<void> markConversationRead(
  WorkspaceController w,
  String channelId,
) async {
  final identity = SourceReadAllIdentity.capture(w.client);
  try {
    final receipt = await w.command(
      'POST',
      '/channels/$channelId/conversation-read-all',
    );
    if (w.services.isDisposed() || !identity.current(w.client)) return;
    final scopes = receipt is Map ? receipt['scopes'] : null;
    if (scopes is List) {
      for (final scope in scopes) {
        if (scope is! Map || scope['scopeId'] is! String) continue;
        w.conversationReads.acceptReadAllAck(
          scope['scopeId'] as String,
          {
            'maxReadSeq': scope['maxReadSeq'],
            'readStateVersion': scope['readStateVersion'],
          },
          serverId: identity.serverId!,
          principalId: identity.principalId!,
        );
      }
    }
    // The read replicas can answer a moment behind the write: what the answer
    // proved read stays read in the followed list (a count only ever lowers).
    void settleThreads() {
      if (scopes is! List) return;
      for (final scope in scopes) {
        if (scope is Map && scope['scopeId'] is String) {
          w.followedThreads.applyReadStateHint({
            'scopeId': scope['scopeId'],
            'unreadCount': 0,
            'maxReadSeq': scope['maxReadSeq'],
          });
        }
      }
    }

    settleThreads();
    await Future.wait([w.refreshUnread(), w.followedThreads.refresh()]);
    settleThreads();
  } catch (error) {
    if (w.services.isDisposed() || !identity.current(w.client)) return;
    if (serverErrorCode(error) == 'sidebar_mark_all_read_disabled') {
      ActivityRolloutFlags.of(w).reevaluate();
      await w.conversationReads.markAllRead(channelId, identity: identity);
      return;
    }
    rethrow;
  }
}

/// SidebarReadToggleMenuItem: Mark as Read posts read-all and clears the count;
/// Mark as Unread waits for the server's count (no invented badge). A failure
/// only reloads the unread counts (no message). A joined channel's menu
/// ([channel]) reads it together with its followed threads
/// (`conversation-read-all`, "Mark All as Read") while `thread_unread_badge_v0`
/// and `sidebar_mark_all_read_v0` are on, and then counts the thread unread too.
class SidebarReadToggle {
  SidebarReadToggle(this.w, this.id, {required bool channel})
    : all = channel && SidebarThreadUnread.of(w).readsConversation;
  final WorkspaceController w;
  final String id;
  final bool all;

  bool get unread =>
      (w.conversationReads.unread[id] ?? 0) > 0 ||
      all && SidebarThreadUnread.of(w).forChannel(id, joined: true).count > 0;

  String get label =>
      unread ? (all ? 'Mark All as Read' : 'Mark as Read') : 'Mark as Unread';

  Future<void> run() async {
    final reading = unread;
    try {
      if (!reading) return await w.conversationReads.markUnread(id);
      if (all) return await markConversationRead(w, id);
      final identity = SourceReadAllIdentity.capture(w.client);
      final receipt = await w.command('POST', '/channels/$id/read-all');
      if (w.services.isDisposed() || !identity.current(w.client)) return;
      w.conversationReads.acceptReadAllAck(
        id,
        receipt,
        serverId: identity.serverId!,
        principalId: identity.principalId!,
      );
    } catch (_) {
      if (reading && !w.services.isDisposed()) unawaited(w.refreshUnread());
    }
  }
}
