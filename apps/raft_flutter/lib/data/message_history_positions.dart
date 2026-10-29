import 'workspace_messages.dart';

import 'package:raft_client/raft_client.dart';

import 'message_history.dart';
import 'cached_history_window.dart';
import 'history_read_policy.dart';
import 'message_history_pages.dart';
import 'message_history_verification.dart';
import 'message_history_summaries.dart';
import 'message_window_snapshot.dart';
import 'reading_positions.dart';
import 'workspace_message_host.dart';
import 'workspace_message_windows.dart';

/// Device positions are presentation metadata under the live receiver's scope.
class MessageHistoryPositions {
  static void save(
    WorkspaceMessageHost receiver,
    String id,
    ReadingAnchor? anchor,
  ) {
    var w = receiver.messageDomain;
    while (w.source != null) {
      w = w.source!;
    }
    if (!w.device.writable) return;
    if (id == w.presentation.channel?.id && w.state.channelLoading ||
        id == w.state.threadChannelId && w.state.threadLoading) {
      return;
    }
    final storage = MessageHistoryPages.storage(w.device.cache),
        scope = MessageHistoryPages.scope(
          w,
          id,
          parent: id == w.state.threadChannelId ? w.threadParentChannelId : id,
          parentMessage: id == w.state.threadChannelId
              ? w.threadParentMessageId
              : null,
        );
    if (storage == null || scope == null) return;
    // A null viewport anchor reports the latest end, including a manual drag.
    // A previous older-page hint must not retain the opposite end afterward.
    if (anchor == null) {
      storage.memory.direction(w.context.receiverKey, id, older: false);
    }
    SavedReadingPosition? position;
    if (anchor != null) {
      final row = w.messageWindows
          .rows(id)
          .where((row) => w.messageKey(row) == anchor.messageKey)
          .firstOrNull;
      if (row == null || WorkspaceMessages.isPendingSend(row)) return;
      position = SavedReadingPosition(row.id, row.seq, anchor.top);
    }
    storage.savePosition(scope, position).ignore();
  }

  static Future<void> clear(
    WorkspaceMessageHost host,
    String id, {
    required bool thread,
    MessageHistoryScope? boundScope,
    bool Function()? current,
  }) async {
    final w = host.messageDomain;
    final storage = MessageHistoryPages.storage(w.device.cache),
        scope =
            boundScope ??
            MessageHistoryPages.scope(
              w,
              id,
              parent: thread ? w.threadParentChannelId : id,
              parentMessage: thread ? w.threadParentMessageId : null,
            );
    if (storage != null && scope != null) {
      await storage.savePosition(scope, null);
    }
    if (current?.call() ?? true) w.messageWindows.clearReadingAnchor(id);
  }

  static Future<MessageHistoryPage?> restore(
    WorkspaceMessageHost host,
    MessageWindowRequest request,
    String id, {
    bool thread = false,
    dynamic cached,
  }) async {
    final w = host.messageDomain;
    MessageHistoryPages.opened(w, id).ignore();
    if (!request.current) return null;
    final storage = MessageHistoryPages.storage(w.device.cache),
        scope = MessageHistoryPages.scope(
          w,
          id,
          parent: thread ? w.threadParentChannelId : id,
          parentMessage: thread ? w.threadParentMessageId : null,
        );
    if (storage == null ||
        scope == null ||
        !request.current ||
        !w.device.writable) {
      return null;
    }
    if (cached is CachedHistoryWindow && cached.provesNoPosition(scope)) {
      return null;
    }
    try {
      final position = await storage.readPosition(scope);
      if (position == null || !request.current) return null;
      final initial = {
        for (final row in w.ledger.messages(id)) row['id'] as String: row,
      };
      final local = await storage.readContext(scope, position.messageId);
      if (local == null || !request.current || !w.device.writable) return null;
      final target = (local['messages'] as List)
          .whereType<Map>()
          .where((row) => row['id'] == position.messageId)
          .firstOrNull;
      if (target == null) return null;
      final key = w.messageKey(RaftMessage(Map<String, dynamic>.from(target)));
      w.messageWindows.saveReadingAnchor(id, ReadingAnchor(key, position.top));
      storage.reads.count(HistoryReadReason.local);
      MessageHistoryVerification.tail(w, request, scope);
      return MessageHistoryPages.savedContext(w, scope, local, initial);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> restoreMain(
    WorkspaceMessageHost host,
    MessageWindowRequest request,
    String id, {
    dynamic cached,
  }) async {
    final w = host.messageDomain;
    final page = await restore(w, request, id, cached: cached);
    if (page == null || !request.current) return false;
    final rows = acceptedWindowRows(page['messages'], id);
    w.state.hasMore = page['hasOlder'] == true;
    w.state.hasNewer = page['hasNewer'] == true;
    w.state.historyLimited = page['historyLimited'] == true;
    w.messageWindows.rememberWindow(
      request,
      id,
      page.scope.authority,
      w.state.hasMore,
      w.messageHistoryTicket(id) as String,
      historyLimited: w.state.historyLimited,
      rows: rows,
      replace: true,
    );
    w.messageWindows.setContextMode(request, id, w.state.hasNewer);
    w.messageWindows.setDiskOnly(request, id, true);
    MessageHistorySummaries.restore(w, id, page);
    w.transport.client.joinChannel(id);
    w.state.channelLoading = false;
    w.context.changed();
    await MessageHistoryPages.record(w, request, page);
    return true;
  }

  static Future<MessageHistoryPage?> restoreThread(
    WorkspaceMessageHost host,
    MessageWindowRequest request,
    String id,
    Map legacy,
  ) async {
    final w = host.messageDomain;
    final page = await restore(w, request, id, thread: true, cached: legacy);
    if (page == null || !request.current) return null;
    w.state.threadChannelId = id;
    final parent = legacy['parent'];
    if (w.state.threadParent == null &&
        parent is Map &&
        parent['id'] == w.threadParentMessageId &&
        parent['channelId'] == w.threadParentChannelId) {
      w.state.threadParent = RaftMessage(Map<String, dynamic>.from(parent));
    }
    final boundary = w.messageWindows.acceptThreadPage(
      request,
      id,
      page,
      focused: true,
      retainOlder: false,
      retainedHasMore: false,
    );
    w.state.threadHasMore = boundary.more;
    w.state.threadHistoryLimited = boundary.limited;
    w.state.threadLoading = false;
    w.messageWindows.rememberWindow(
      request,
      id,
      page.scope.authority,
      boundary.more,
      w.messageHistoryTicket(page.scope.parentChannel) as String,
      historyLimited: boundary.limited,
    );
    w.messageWindows.setContextMode(request, id, page['hasNewer'] == true);
    w.messageWindows.setDiskOnly(request, id, true);
    w.context.changed();
    return page;
  }
}
