import 'message_history_summaries.dart';
import 'workspace_messages.dart';

/// Web v1.24 messageUpdatedApply `applyThreadReplyUpdate`: a thread reply's
/// new copy (`thread:reply_updated`, `message:updated`, a sync `message`
/// change) edits its inline preview under the parent in place. It never
/// inserts a reply or changes a count. True when a held preview changed.
bool applyThreadReplyUpdate(WorkspaceMessages m, Map<String, dynamic> row) {
  final server = m.transport.client.serverId;
  final me = m.transport.client.user?.id;
  final context = row['conversationContext'];
  final owner = context is Map ? context['parentChannelId'] : null;
  if (server == null ||
      me == null ||
      owner is! String ||
      m.session.revocations.revokedChannels.contains(owner) ||
      m.session.revocations.revokedChannels.contains(row['channelId'])) {
    return false;
  }
  final result = m.state.threadRepliesSync.applyReplyUpdate(
    row,
    serverId: server,
    principalId: me,
  );
  if (result == null) return false;
  final held = m.summariesByChannel[owner]?[result.parentMessageId];
  if (held is! Map) return false;
  final summary = {
    ...Map<String, dynamic>.from(held),
    'latestReplies': result.scope.replies,
  };
  m.summariesByChannel[owner]![result.parentMessageId] = summary;
  MessageHistorySummaries.store(m, owner, {result.parentMessageId: summary});
  return true;
}
