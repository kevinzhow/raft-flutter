import 'message_history_pages.dart';
import 'history_snapshot_writes.dart';
import 'message_window_snapshot.dart';
import 'workspace_message_host.dart';
import 'workspace_message_windows.dart';

/// Compatibility snapshot adapter. Durable rows/ranges are owned separately;
/// this keeps the previous version's rollback format and window boundaries.
class MessageHistorySnapshots {
  static Future<void> flush(WorkspaceMessageHost host) {
    var w = host.messageDomain;
    while (w.source != null) {
      w = w.source!;
    }
    return HistorySnapshotWrites.flush(w.context.receiverKey);
  }

  static bool restore(
    WorkspaceMessageHost host,
    String id,
    dynamic page,
    MessageWindowRequest request, {
    required bool replace,
    required bool Function() allowed,
  }) {
    final w = host.messageDomain;
    final authority = messageWindowAuthority(
      w.context.server?.string('role'),
      w.presentation.channel?.json ?? const {},
    );
    if (!request.current ||
        page is! Map ||
        page['version'] != 1 ||
        page['windowKind'] != 'tail' ||
        page['hasNewer'] == true ||
        page['authority'] != authority ||
        !w.context.can('viewChannel', resource: w.presentation.channel) ||
        !w.messageWindows.notRevoked(id) ||
        !allowed() ||
        page['parentChannelId'] != w.presentation.channel?.id) {
      return false;
    }
    w.state.hasMore = page['hasMore'] == true;
    w.state.historyLimited = page['historyLimited'] == true;
    if (replace) w.state.hasNewer = page['hasNewer'] == true;
    w.messageWindows.rememberWindow(
      request,
      id,
      authority,
      w.state.hasMore,
      w.messageHistoryTicket(id) as String,
      historyLimited: w.state.historyLimited,
      rows: acceptedWindowRows(page['messages'], id),
      replace: replace,
    );
    w.messageWindows.setDiskOnly(request, id, true);
    w.messageWindows.setContextMode(request, id, null);
    // This accepted local window is ready to present. Background validation
    // must not leave the chat adapter waiting for a writer or the network.
    w.state.channelLoading = false;
    return true;
  }

  static Future<void> save(
    WorkspaceMessageHost host,
    String id, {
    required bool thread,
    bool coalesce = false,
    required WorkspaceThreadIdentity? identity,
    required String Function(String?) replyToken,
    required Future<void> Function(String, String, dynamic) write,
  }) {
    final w = host.messageDomain;
    if (!w.device.writable ||
        w.state.channelLoading && w.messageWindows.isContext(id) ||
        !thread && w.presentation.channel == null ||
        (thread
            ? id != w.state.threadChannelId
            : id != w.presentation.channel!.id) ||
        !w.messageWindows.notRevoked(id) ||
        (thread ? w.messageWindows.contextHasNewer(id) : w.state.hasNewer) ||
        w.state.highlightedMessageId != null) {
      return Future<void>.value();
    }
    final resource = thread ? w.threadSourceChannel : w.presentation.channel;
    if (resource == null || !w.context.can('viewChannel', resource: resource)) {
      return Future<void>.value();
    }
    final authority = messageWindowAuthority(
      w.context.server?.string('role'),
      resource.json,
    );
    w.messageWindows.rememberWindow(
      liveWindowWrite,
      id,
      authority,
      thread ? w.state.threadHasMore : w.state.hasMore,
      replyToken(thread ? w.threadParentChannelId : id),
      historyLimited: thread
          ? w.state.threadHistoryLimited
          : w.state.historyLimited,
    );
    w.messageWindows.setContextMode(liveWindowWrite, id, null);
    final rows = thread ? w.replies : w.messages;
    final payload = {
      'version': 1,
      'windowKind': 'tail',
      'authority': authority,
      'parentChannelId': thread ? w.threadParentChannelId : id,
      'messages': MessageHistoryPages.snapshotRows(w.device.cache, rows),
      'hasMore': thread ? w.state.threadHasMore : w.state.hasMore,
      'historyLimited': thread
          ? w.state.threadHistoryLimited
          : w.state.historyLimited,
    };
    final window = {
      ...payload,
      'hasNewer': false,
      'threadSummaries': thread
          ? {}
          : Map<String, dynamic>.from(w.threadSummaries),
    };
    final parent = w.state.threadParent;
    final threadPayload =
        thread &&
            identity != null &&
            identity.focusedMessageId == null &&
            w.messageWindows.notRevoked(identity.parentChannelId) &&
            w.messageWindows.notRevoked(id)
        ? {
            ...payload,
            'parentChannelId': identity.parentChannelId,
            'threadChannelId': id,
            if (parent != null &&
                parent.id == identity.parentMessageId &&
                parent.channelId == identity.parentChannelId)
              'parent': parent.json,
          }
        : null;
    final parentId = thread ? w.threadParentChannelId ?? id : id;
    final scope = (
      w.transport.client.origin,
      w.transport.client.user?.id,
      w.transport.client.serverId,
      w.ledger.generation,
      replyToken(parentId),
    );
    bool current() =>
        w.device.writable &&
        scope ==
            (
              w.transport.client.origin,
              w.transport.client.user?.id,
              w.transport.client.serverId,
              w.ledger.generation,
              replyToken(parentId),
            ) &&
        w.messageWindows.notRevoked(id) &&
        w.messageWindows.notRevoked(parentId);
    Future<void> writeCopies() async {
      if (!current()) return;
      final saved = write('window', id, window);
      if (threadPayload != null) {
        await write('thread-window', identity!.parentMessageId, threadPayload);
      }
      await saved;
    }

    return coalesce && MessageHistoryPages.storage(w.device.cache) != null
        ? HistorySnapshotWrites.schedule(w.context.receiverKey, (
            scope,
            id,
          ), writeCopies)
        : HistorySnapshotWrites.writeNow(w.context.receiverKey, (
            scope,
            id,
          ), writeCopies);
  }
}
