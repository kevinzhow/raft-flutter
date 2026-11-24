// The first replies page a thread open shows (Web threadStore `openThread`):
// the restored reading position, the page around a focused reply, or the
// latest replies. A focused reply that answers 404 (deleted, or not readable
// yet) opens the latest replies instead of revoking the thread, which locked
// it until the next server selection (#294); a 403 still revokes.
import 'package:raft_client/raft_client.dart';

import 'message_history.dart';
import 'message_history_pages.dart';
import 'message_window_snapshot.dart';
import 'workspace_message_windows.dart' show MessageWindowRequest;
import 'workspace_messages.dart';

/// The thread's first replies page and whether it is a context window around
/// a focused reply or reading position. Null when [request] was superseded.
Future<({Map<String, dynamic> page, bool focused})?> threadRepliesPage(
  WorkspaceMessages m,
  MessageWindowRequest request, {
  Map<String, dynamic>? readingPage,
  String? focusedMessageId,
  bool revalidate = false,
}) async {
  if (readingPage != null) return (page: readingPage, focused: true);
  if (focusedMessageId != null) {
    final reply = await focusedThreadReplyPage(m, request, focusedMessageId);
    if (!request.current) return null;
    if (reply != null) return (page: reply, focused: true);
  }
  final page = await MessageHistoryPages.read(
    m,
    request,
    m.state.threadChannelId!,
    thread: true,
    revalidate: revalidate,
  );
  return (page: page, focused: false);
}

/// The page around a focused reply. A hidden target starts the visible
/// window immediately after the cutoff. A plain 404 falls back to latest.
Future<Map<String, dynamic>?> focusedThreadReplyPage(
  WorkspaceMessages m,
  MessageWindowRequest request,
  String focusedMessageId,
) async {
  try {
    return await MessageHistoryPages.context(
      m,
      request,
      m.state.threadChannelId!,
      focusedMessageId,
      thread: true,
    );
  } on RaftApiException catch (e) {
    if (e.status != 404) rethrow;
    if (!request.current) return null;
    m.state.highlightedMessageId = null;
    if (HiddenTarget.fromError(e)
        case HiddenTarget(target: final target, sequence: final sequence?)
        when target.id == focusedMessageId) {
      const limit = 50;
      final channelId = m.state.threadChannelId!;
      final page = await MessageHistoryPages.read(
        m,
        request,
        channelId,
        thread: true,
        after: sequence,
        limit: limit,
        localFirst: false,
      );
      if (!request.current) return null;
      final wire = page is MessageHistoryPage ? page.remotePage ?? page : page;
      final rows = acceptedWindowRows(wire['messages'], channelId);
      return page
        ..['historyLimited'] = true
        ..['hasOlder'] = false
        ..['hasNewer'] = rows.length >= limit;
    }
    return null;
  }
}
