import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'message_window_snapshot.dart';
import 'workspace_domain_ports.dart';
import 'workspace_message_windows.dart';
import 'workspace_session_context.dart';
import 'workspace_session_bindings.dart';

/// One candidate's original message-window operation. D2 chooses candidates;
/// this body owns admission, page read/write and the existing failure boundary.
Future<void> prefetchWorkspaceMessageTail(
  RaftChannel candidate, {
  required bool Function() stillCurrent,
  required WorkspaceSessionContext context,
  required WorkspacePresentationReadPort presentation,
  required WorkspaceMessageWindows windows,
  required WorkspacePrefetchPagesPort pages,
  required WorkspaceTaskMetadataPort tasks,
}) async {
  String authorityOf(RaftChannel row) =>
      messageWindowAuthority(context.server?.string('role'), row.json);
  final authority = authorityOf(candidate),
      reply = pages.replyToken(candidate.id);
  // Construction failures stay outside the best-effort page catch. D2 still
  // releases its in-flight flag in the original outer finally.
  final request = windows.request(
    allowed: () =>
        stillCurrent() &&
        reply == pages.replyToken(candidate.id) &&
        presentation.channel?.id != candidate.id &&
        windows.accepted[candidate.id] == null &&
        !context.isChannelRevoked(candidate.id) &&
        authority == authorityOf(candidate) &&
        context.can('viewChannel', resource: candidate),
  );
  try {
    unawaited(tasks.warm(candidate.id));
    final page = await pages.readPrefetchPage(request, candidate.id);
    if (!request.current) return;
    final rows = acceptedWindowRows(page['messages'], candidate.id);
    if (rows.isEmpty) return;
    final limited = page['historyLimited'] == true;
    windows.acceptRows(request, candidate.id, rows, replace: true);
    await pages.recordPrefetchPage(request, page);
    if (!request.current) return;
    windows.rememberWindow(
      request,
      candidate.id,
      authority,
      !limited && rows.length >= 50,
      reply,
      historyLimited: limited,
    );
    pages.mergeThreadSummaries(
      candidate.id,
      page['threadSummariesByParentMessageId'],
    );
  } catch (_) {
    // Best effort: the channel opens normally on demand.
  }
}
