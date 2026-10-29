import 'package:raft_client/raft_client.dart';

import 'thread_search.dart' show WorkspaceThreadIdentity;

/// Related private scopes captured before any ledger or summary is cleared.
class ChannelRevocationPlan {
  ChannelRevocationPlan.discover({
    required this.channelId,
    required Iterable<Map<String, dynamic>> messages,
    required Iterable<String> parentMessageIds,
    required Map<String, Map<String, dynamic>> summaries,
    required WorkspaceThreadIdentity? identity,
    required RaftMessage? parent,
    required String? threadChannelId,
  }) {
    messageIds = Set.unmodifiable({
      ...messages.map((m) => m['id']),
      ...parentMessageIds,
      if (identity != null &&
          (identity.parentChannelId == channelId ||
              threadChannelId == channelId))
        identity.parentMessageId,
      if (threadChannelId == channelId && parent != null) parent.id,
    });
    threadIds = Set.unmodifiable({
      for (final message in messages)
        if (message['threadChannelId'] is String)
          message['threadChannelId'] as String,
      for (final summary in [
        ...?summaries[channelId]?.values,
        for (final bucket in summaries.values)
          for (final messageId in messageIds) ?bucket[messageId],
      ])
        if (summary is Map &&
            messageIds.contains(summary['parentMessageId']) &&
            summary['threadChannelId'] is String)
          summary['threadChannelId'] as String,
      if ((parent?.channelId == channelId ||
              identity?.parentChannelId == channelId) &&
          threadChannelId != null)
        threadChannelId,
    });
  }

  final String channelId;
  late final Set<dynamic> messageIds;
  late final Set<String> threadIds;
  Set<String> get scopes => {channelId, ...threadIds};
  Set<String> get draftScopes => {
    ...scopes,
    for (final messageId in messageIds) 'thread:$messageId',
  };
}

class ChannelRevocation {
  const ChannelRevocation({
    required this.origin,
    required this.principal,
    required this.serverId,
    required this.generation,
    required this.plan,
    required this.keepShared,
  });
  final String origin;
  final String? principal, serverId;
  final int generation;
  final ChannelRevocationPlan plan;
  final bool keepShared;
}
