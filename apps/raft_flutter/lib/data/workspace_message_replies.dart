import 'dart:async';

import 'package:raft_sync/raft_sync.dart';

import 'message_history_summaries.dart';
import 'workspace_messages.dart';

/// Existing replies operations on the receiver-local message domain.
class WorkspaceMessageReplies {
  WorkspaceMessageReplies(this.m);
  final WorkspaceMessages m;

  /// Authority token for data owned by [channelId] (its message window, its
  /// thread windows and reply summaries).
  String replyToken(String? channelId) =>
      m.state.replyAuthority.token(m.context.syncIdentity(), channelId);

  /// Retires one channel's reply authority (Source refreshes only the
  /// affected channel row on a membership event). Its reply scopes and
  /// thread windows go now; its message window is dropped on next use by the
  /// token mismatch. The open channel keeps its displayed summaries until its
  /// own refresh replaces them; a real revocation clears them in
  /// [_revokeChannel].
  void invalidateChannelReplies(String id) {
    m.state.replyAuthority.invalidateChannel(id);
    m.state.threadRepliesSync.revokeChannel(id);
    m.messageWindows.invalidateParentThreads(id);
    if (m.presentation.channel?.id != id) m.summariesByChannel.remove(id);
  }

  void invalidateAllChannelReplies() {
    m.state.replyAuthority.invalidateAll();
    m.state.threadRepliesSync.reset();
    m.messageWindows.clearThreads();
    m.summariesByChannel.removeWhere(
      (id, _) => id != m.presentation.channel?.id,
    );
  }

  void mergeThreadSummaries(String id, dynamic rows) => m.summariesByChannel
      .putIfAbsent(id, () => {})
      .addAll(
        m.hydrateThreadSummaries(rows, id, expectedToken: m.replyToken(id)),
      );

  Map<String, dynamic> hydrateThreadSummaries(
    dynamic raw,
    String parentChannelId, {
    String? expectedToken,
  }) {
    m.session.ensureSyncIdentity();
    if (expectedToken != null &&
        expectedToken != m.replyToken(parentChannelId)) {
      return {};
    }
    if (raw is! Map) return {};
    final id = m.transport.client.serverId,
        principal = m.transport.client.user?.id;
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: id == null || principal == null
              ? Map<String, dynamic>.from(entry.value)
              : m.state.threadRepliesSync.hydrateSummary(
                  id,
                  principal,
                  parentChannelId,
                  entry.key as String,
                  Map<String, dynamic>.from(entry.value),
                ),
    };
  }

  bool replyCurrent(String token, ThreadRebaselineRequest request) =>
      !m.context.disposed &&
      token == m.replyToken(request.parentChannelId) &&
      !m.session.revocations.revokedChannels.contains(
        request.parentChannelId,
      ) &&
      !m.session.revocations.revokedChannels.contains(request.threadChannelId);

  Future<void> rebaselineThread(ThreadRebaselineRequest request) async {
    final token = m.replyToken(request.parentChannelId);
    try {
      // Exact mounted compatibility snapshot used by threadRepliesSyncDomain.
      final values = await Future.wait([
        m.transport.client.get(
          '/messages/channel/${request.threadChannelId}',
          query: {'limit': inlineReplyCap},
        ),
        m.transport.client.get(
          '/channels/${request.parentChannelId}/threads/${request.parentMessageId}',
        ),
      ]);
      if (!m.replyCurrent(token, request)) return;
      final page = values[0], summary = values[1];
      if (page is! Map ||
          page['messages'] is! List ||
          summary is! Map ||
          summary['threadChannelId'] != request.threadChannelId ||
          summary['replyCount'] is! int ||
          summary['replyCount'] < 0) {
        return;
      }
      final previews = (page['messages'] as List)
          .map((m) => projectThreadReply(m, snapshot: true))
          .whereType<Map<String, dynamic>>();
      final result = m.state.threadRepliesSync.completeRebaseline(
        request,
        replies: previews,
        replyCount: summary['replyCount'],
        historyLimited: page['historyLimited'] == true,
      );
      if (result.kind != 'applied' || result.summary == null) return;
      m.summariesByChannel.putIfAbsent(
        request.parentChannelId,
        () => {},
      )[request.parentMessageId] = result.summary;
      MessageHistorySummaries.rebaselined(m, request, result.summary);
      m.channels.applyThreadUnread(request.threadChannelId, result.summary);
      if (m.presentation.channel?.id == request.parentChannelId) {
        m.saveWindow(m.presentation.channel!.id);
      }
      m.context.changed();
    } catch (_) {
      // No guessed transport or fabricated completion. The next eligible
      // producer frame can retry its authorized compatibility snapshot.
    } finally {
      m.state.threadRepliesSync.release(request);
    }
  }

  void consumeThreadUpdate(Map<String, dynamic> payload) {
    m.session.ensureSyncIdentity();
    final id = m.transport.client.serverId,
        principal = m.transport.client.user?.id;
    if (id == null || principal == null) return;
    if (payload['serverId'] != null && payload['serverId'] != id) return;
    final parentId = payload['parentMessageId'];
    final latest = payload['latestReply'];
    final anchor = latest is Map ? latest['conversationContext'] : null;
    final parentChannel = anchor is Map ? anchor['parentChannelId'] : null;
    if (m.session.revocations.revokedChannels.contains(
          payload['threadChannelId'],
        ) ||
        m.session.revocations.revokedChannels.contains(parentChannel)) {
      return;
    }
    if (parentId is String &&
        m.presentation.channel != null &&
        m.session.revocations.revokedChannels.contains(
          m.presentation.channel!.id,
        )) {
      return;
    }
    final result = m.state.threadRepliesSync.consume(
      payload,
      serverId: id,
      principalId: principal,
    );
    if (result.summary != null && parentId is String) {
      final owner = m.summaryOwner(payload, parentId);
      if (owner != null &&
          !m.session.revocations.revokedChannels.contains(owner)) {
        m.summariesByChannel.putIfAbsent(owner, () => {})[parentId] =
            result.summary;
        MessageHistorySummaries.store(m, owner, {parentId: result.summary});
      }
      m.channels.applyThreadUnread(payload['threadChannelId'], payload);
    }
    if (result.request != null) unawaited(m.rebaselineThread(result.request!));
  }

  /// The parent channel whose reply rows a `thread:updated` summary belongs
  /// to: the wire anchor first, else the channel already holding the parent.
  String? summaryOwner(Map<String, dynamic> payload, String parentId) {
    final latest = payload['latestReply'];
    final anchor = latest is Map ? latest['conversationContext'] : null;
    if (anchor is Map && anchor['parentChannelId'] is String) {
      return anchor['parentChannelId'] as String;
    }
    final window = payload['syncCoreReplyWindow'];
    final discussion = window is Map ? window['discussion'] : null;
    final scope = discussion is Map ? discussion['parentScopeKey'] : null;
    if (scope is Map && scope['scopeId'] is String) {
      return scope['scopeId'] as String;
    }
    final current = m.presentation.channel?.id;
    if (current != null &&
        (m.summariesByChannel[current]?.containsKey(parentId) == true ||
            m.ledger.contains(current, parentId))) {
      return current;
    }
    for (final entry in m.summariesByChannel.entries) {
      if (entry.value.containsKey(parentId)) return entry.key;
    }
    for (final entry in m.visibleIds.entries) {
      if (entry.value.contains(parentId)) return entry.key;
    }
    return null;
  }

  Map<String, Map<String, dynamic>> get summariesByChannel =>
      m.source?.summariesByChannel ?? m.state.pageSummariesByChannel;

  /// Summaries of the selected channel's messages.
  Map<String, dynamic> get threadSummaries {
    final id = m.presentation.channel?.id;
    return id == null
        ? <String, dynamic>{}
        : m.summariesByChannel.putIfAbsent(id, () => {});
  }

  set threadSummaries(Map<String, dynamic> value) {
    final id = m.presentation.channel?.id;
    if (id != null) m.summariesByChannel[id] = value;
  }

  /// Summaries held for [channelId] (selected or not).
  Map<String, dynamic> threadSummariesFor(String channelId) =>
      Map.unmodifiable(m.summariesByChannel[channelId] ?? const {});
}
