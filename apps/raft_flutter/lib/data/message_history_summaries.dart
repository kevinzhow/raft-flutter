import 'package:raft_sync/raft_sync.dart' show ThreadRebaselineRequest;

import 'message_history_pages.dart';
import 'workspace_message_host.dart';

/// Reply previews are stored with the history rows of their parents (same
/// store, retention and revocation). This is the controller-side adapter:
/// what a local page brings is merged without displacing newer held state,
/// and live changes are written through.
class MessageHistorySummaries {
  /// Summaries of a page served from the device, for parents the window does
  /// not already hold. A held summary is at least as new as the stored one.
  static dynamic unheld(
    WorkspaceMessageHost host,
    String channelId,
    dynamic rows,
  ) {
    final w = host.messageDomain;
    if (rows is! Map || rows.isEmpty) return rows;
    final held = w.threadSummariesFor(channelId);
    return {
      for (final entry in rows.entries)
        if (!held.containsKey(entry.key)) entry.key: entry.value,
    };
  }

  /// Presents the previews that came with a local page.
  static void restore(
    WorkspaceMessageHost host,
    String channelId,
    dynamic page,
  ) {
    final w = host.messageDomain;
    final rows = unheld(
      w,
      channelId,
      page is Map ? page['threadSummariesByParentMessageId'] : null,
    );
    if (rows is Map && rows.isNotEmpty) {
      w.mergeThreadSummaries(channelId, rows);
    }
  }

  /// Persists live summary changes (a reply arrived, a count was rebaselined)
  /// without waiting for the next window save.
  static void store(
    WorkspaceMessageHost host,
    String channelId,
    Map<String, dynamic> summaries,
  ) {
    final w = host.messageDomain;
    final device = MessageHistoryPages.storage(w.device.cache);
    if (device == null ||
        !w.device.writable ||
        w.transport.client.user == null ||
        w.transport.client.serverId == null ||
        !w.messageWindows.notRevoked(channelId)) {
      return;
    }
    final scope = MessageHistoryPages.scope(w, channelId);
    if (scope == null) return;
    device.saveSummaries(scope, summaries).ignore();
  }

  /// A rebaselined thread summary, persisted like a live reply.
  static void rebaselined(
    WorkspaceMessageHost host,
    ThreadRebaselineRequest request,
    Map<String, dynamic>? summary,
  ) {
    final w = host.messageDomain;
    if (summary == null) return;
    store(w, request.parentChannelId, {request.parentMessageId: summary});
  }

  /// The open channel's summaries after a fresh first page: held ones for
  /// retained rows, except where the page decides for its own parents (a
  /// page without the field, from an older server, decides nothing), plus
  /// the page's own.
  static void accept(
    WorkspaceMessageHost host,
    String channelId,
    List<Map<String, dynamic>> retained,
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> fresh,
  ) {
    final w = host.messageDomain;
    final carried = fresh['threadSummariesByParentMessageId'];
    final held = w.threadSummariesFor(channelId);
    final Set<dynamic> answered = carried is Map
        ? {for (final row in rows) row['id']}
        : const {};
    w.threadSummaries = {
      for (final row in retained)
        if (held[row['id']] != null && !answered.contains(row['id']))
          row['id'] as String: held[row['id']],
    };
    w.mergeThreadSummaries(channelId, carried);
  }
}
