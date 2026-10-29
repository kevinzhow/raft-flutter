import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'conversation_window.dart';
import 'message_window_snapshot.dart';
import 'message_history_pages.dart';
import 'message_history_navigation.dart';
import 'message_history_positions.dart';
import 'raft_navigation_history.dart';
import 'workspace_message_windows.dart';
import 'user_error.dart';
import 'workspace_messages.dart';

/// Existing navigation operations on the receiver-local message domain.
class WorkspaceMessageNavigation {
  WorkspaceMessageNavigation(this.m);
  final WorkspaceMessages m;

  /// Source `syncVisibleScopes`: the open thread and the presented channel
  /// tail each read the messages after their newest row and append them to
  /// the held window. Nothing is cleared or reloaded.
  Future<void> syncVisibleScopes({BigInt? through}) async {
    if (m.state.gapSyncing || m.context.disposed) return;

    final thread = m.state.threadChannelId, main = m.presentation.channel?.id;
    final targets = [
      if (thread != null &&
          !m.state.threadLoading &&
          !m.messageWindows.contextHasNewer(thread))
        thread,
      if (main != null &&
          main != thread &&
          !m.state.hasNewer &&
          !m.state.channelLoading &&
          m.pendingMessageContextChannelId != main)
        main,
    ];
    if (targets.isEmpty) return;
    final generation = m.ledger.generation;
    var complete = true;
    m.state.gapSyncing = true;
    try {
      for (final id in targets) {
        if (!await syncGap(id)) complete = false;
      }
    } finally {
      m.state.gapSyncing = false;
    }
    if (complete && through != null && generation == m.ledger.generation) {
      m.session.assignGapSyncedThrough((generation, through));
    }
  }

  Future<bool> syncGap(String id) async {
    final thread = id == m.state.threadChannelId;
    var cursor = m.messageWindows.newestVisibleSequence(id);
    if (cursor == BigInt.zero) return true;
    final owner = thread ? m.threadParentChannelId : id;
    final request = m.windowRequest(
      id,
      thread: thread,
      allowed: () => thread
          ? m.state.threadChannelId == id &&
                !m.messageWindows.contextHasNewer(id)
          : m.presentation.channel?.id == id && !m.state.hasNewer,
    );
    try {
      while (true) {
        final page = await MessageHistoryPages.read(
          m,
          request,
          id,
          thread: thread,
          after: cursor,
          limit: WorkspaceMessages.gapPageLimit,
          localFirst: false,
          remote: () async => {
            'messages': await m.transport.client.get(
              '/messages/sync',
              query: {
                'since_seq': '$cursor',
                'channel_id': id,
                'limit': WorkspaceMessages.gapPageLimit,
              },
            ),
          },
        );
        if (!request.current) return false;
        final listed = page['messages'] is List
            ? page['messages'] as List
            : const [];
        final rows = [
          for (final row in listed.whereType<Map>())
            if (row['channelId'] == id && row['id'] is String)
              Map<String, dynamic>.from(row),
        ];
        if (rows.isEmpty) break;
        final arrived = [
          for (final row in rows)
            if (!m.ledger.contains(id, row['id'] as String)) row,
        ];
        m.messageWindows.acceptRows(request, id, rows);
        if (!await MessageHistoryPages.record(m, request, page)) return false;
        if (!request.current) return false;
        var next = cursor;
        for (final row in rows) {
          final seq = RaftMessage(row).seq;
          if (seq > next) next = seq;
        }
        if (m.channels.mayMarkRead(id) && !m.channels.scrolledAway.away(id)) {
          unawaited(m.entries.markRead(id));
        } else {
          arrived.forEach(m.channels.receiveUnread);
        }
        unawaited(m.saveWindow(id, thread: thread));
        m.context.changed();
        if (listed.length < WorkspaceMessages.gapPageLimit || next <= cursor) {
          break;
        }
        cursor = next;
      }
      return true;
    } on RaftApiException catch (e) {
      // Lost access is decided by the channel read and its revocation path.
      if (request.current &&
          owner != null &&
          (e.status == 403 || e.status == 404)) {
        unawaited(m.entries.refreshChannel(owner));
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> older({bool thread = false}) =>
      m.windowReceiver.olderLocal(thread);

  Future<void> newer({bool thread = false}) =>
      m.windowReceiver.pageHistory(thread, newer: true);

  Future<void> loadHistoryGap(BigInt before, {bool thread = false}) =>
      m.windowReceiver.pageHistory(thread, gapBefore: before);

  Future<void> olderLocal(bool thread) => m.pageHistory(thread);

  Future<void> pageHistory(
    bool thread, {
    bool newer = false,
    BigInt? gapBefore,
  }) => MessageHistoryNavigation.page(
    m,
    thread: thread,
    newer: newer,
    gapBefore: gapBefore,
    requestFor: (id) => m.windowRequest(id, thread: thread),
    summaries: m.mergeThreadSummaries,
  );

  /// Where the reader was in a conversation when its timeline is about to be
  /// rebuilt for another layout (fold / unfold). The next timeline that
  /// mounts for [conversationId] shortly after resumes there; an anchor that
  /// is not claimed promptly is a stale position and is ignored.
  void saveReadingAnchor(String conversationId, ReadingAnchor anchor) {
    m.messageWindows.saveReadingAnchor(conversationId, anchor);
    MessageHistoryPositions.save(m, conversationId, anchor);
  }

  ReadingAnchor? takeReadingAnchor(String conversationId) =>
      m.messageWindows.takeReadingAnchor(conversationId);

  /// Clears only the focus owned by the mounted timeline's highlight timer.
  void clearHighlightedMessage(
    String? expectedId, {
    int? expectedNavigationRevision,
  }) {
    if (m.source != null) {
      if (m.presentation.presentationActive) {
        m.source!.entries.clearHighlightedMessage(
          expectedId,
          expectedNavigationRevision: expectedNavigationRevision,
        );
      }
      return;
    }
    if (m.state.highlightedMessageId != expectedId ||
        expectedNavigationRevision != null &&
            expectedNavigationRevision != m.presentation.navigationRevision) {
      return;
    }
    final identity = m.threadIdentity;
    if (expectedId != null &&
        expectedNavigationRevision != null &&
        identity != null &&
        identity.focusedMessageId == expectedId &&
        m.state.threadChannelId != null) {
      m.presentation.navigation.consumeThreadFocus(
        threadChannelId: m.state.threadChannelId!,
        parentChannelId: identity.parentChannelId,
        parentMessageId: identity.parentMessageId,
        expectedMessageId: expectedId,
        expectedRevision: expectedNavigationRevision,
      );
    }
    m.state.highlightedMessageId = null;
    m.context.changed();
  }

  /// Source ChatPanel.handleBackToBottom reloads latest when newer is unloaded.
  Future<void> returnToLatest({bool navigate = true, bool thread = false}) =>
      MessageHistoryNavigation.latest(
        m.windowReceiver,
        thread: thread,
        navigate: navigate,
      );

  /// [replaceEntry] makes the destination take over the current history
  /// entry instead of pushing (Web openThreadParentMessageRoute, mobile).
  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
    bool replaceEntry = false,
  }) async {
    final source = m.source;
    if (source != null) {
      return source.entries.jumpToMessage(
        channelId,
        messageId,
        navigate: navigate,
        replaceEntry: replaceEntry,
      );
    }
    m.contextLoadError = null;
    final generation = m.ledger.generation;
    var navigationWindow = m.presentation.navigationRevision;
    var authority = m.windowAuthority();
    final replyAuthority = m.replyToken(channelId);
    m.messageWindows.channelGeneration++;
    final request = m.messageWindows.request(
      thread: false,
      allowed: () =>
          navigationWindow == m.presentation.navigationRevision &&
          authority == m.windowAuthority() &&
          replyAuthority == m.replyToken(channelId) &&
          !m.session.revocations.revokedChannels.contains(channelId),
    );
    if (m.presentation.rejectRevokedConversation(channelId) ||
        !request.current) {
      return;
    }
    var next = [
      ...m.channels.channels,
      ...m.channels.dms,
    ].where((c) => c.id == channelId).firstOrNull;
    try {
      next ??= RaftChannel(
        Map<String, dynamic>.from(
          await m.transport.client.get('/channels/$channelId'),
        ),
      );
    } catch (_) {
      // Source ChannelById/ensureChannel resolves failed metadata to its
      // unavailable body. UI callbacks may not await this request; neither a
      // global async exception nor a retained conversation owns the failure.
      if (request.current) {
        m.presentation.assignMissingConversationChannelId(channelId);
        m.context.changed();
      }
      return;
    }
    if (!request.current || !m.context.can('viewChannel', resource: next)) {
      return;
    }
    if (messageId == null) {
      await m.entries.selectChannel(next, navigate: navigate);
      return;
    }
    final sameChannel = m.presentation.channel?.id == channelId;
    authority = messageWindowAuthority(
      m.context.server?.string('role'),
      next.json,
    );
    final knownWindow = m.messageWindows.accepted[channelId];
    final compatibleWindow =
        knownWindow?.matches(authority, replyAuthority) == true;
    final cachedTarget =
        compatibleWindow &&
        m.messageWindows.containsVisible(channelId, messageId);
    m.presentation.setSelectedChannel(next);
    if (navigate) {
      if (replaceEntry && m.context.server != null) {
        m.presentation.assignUnboundSection('chat');
        m.presentation.bindNavigation();
        m.presentation.navigation.selectSection(
          'chat',
          channelId: channelId,
          dm: next.type == 'dm',
          kind: RaftNavigationKind.replace,
        );
      } else {
        m.presentation.assignSection('chat');
      }
      m.presentation.navigation.navigate(
        m.presentation.location.withQuery({'msg': messageId}),
        kind: RaftNavigationKind.replace,
      );
      navigationWindow = m.presentation.navigationRevision;
    }
    m.state.threadParent = null;
    m.state.threadChannelId = null;
    m.messageWindows.threadGeneration++;
    m.state.loadingOlder = false;
    m.presentation.assignError(null);
    m.state.highlightedMessageId = messageId;
    if (cachedTarget) {
      MessageHistoryPages.recheckContext(m, request, channelId, messageId);
      m.state.hasMore = sameChannel ? m.state.hasMore : knownWindow!.hasMore;
      m.state.hasNewer = sameChannel
          ? m.state.hasNewer
          : m.messageWindows.contextHasNewer(channelId);
      m.state.historyLimited = m.messageWindows.historyLimit(channelId);
      m.state.channelLoading = false;
      m.messageWindows.finishContextVisit(request);
      m.context.changed();
      // The held window is shown at once, but a window this channel left (or
      // that came from disk) may be behind the server: read the tail quietly
      // and merge it without moving the reading position.
      if ((!sameChannel || m.messageWindows.isDiskOnly(channelId)) &&
          !m.state.hasNewer &&
          !m.messageWindows.isContext(channelId)) {
        unawaited(m.revalidateTail(channelId));
      }
      return;
    }
    m.state.channelLoading = true;
    // Source preserves the destination's already accepted memory bucket while
    // its context GET waits. A disk/unaccepted bucket or an earlier principal,
    // server or capability epoch cannot grant this cross-channel projection.
    m.messageWindows.beginContextVisit((
      channelId: channelId,
      request: request,
      retainRows: sameChannel || compatibleWindow,
    ));
    if (!sameChannel) {
      // Held summaries belong to the held window; an incompatible window
      // takes its summaries with it.
      if (!compatibleWindow) m.summariesByChannel.remove(channelId);
      if (compatibleWindow) {
        m.state.hasMore = knownWindow!.hasMore;
        m.state.hasNewer = m.messageWindows.contextHasNewer(channelId);
        m.state.historyLimited = m.messageWindows.historyLimit(channelId);
      }
    }
    bool current() =>
        request.current &&
        m.presentation.channel?.id == channelId &&
        m.context.can('viewChannel', resource: m.presentation.channel);
    void settled() {
      m.messageWindows.finishContextVisit(request);
      m.state.channelLoading = false;
      m.context.changed();
    }

    m.context.changed();
    try {
      final context = await MessageHistoryPages.context(
        m,
        request,
        channelId,
        messageId,
      );
      if (!current()) return;
      final target = context['canonicalTarget'];
      if (target is Map && target['kind'] == 'thread') {
        final parentId = target['threadParentMessageId'] as String;
        final parentChannelId = target['channelId'] as String? ?? channelId;
        final opening = m.entries.openThreadIdentity(
          parentChannelId: parentChannelId,
          parentMessageId: parentId,
          focusedMessageId: target['messageId'] as String? ?? messageId,
          navigate: navigate,
        );
        if (navigate) navigationWindow = m.presentation.navigationRevision;
        await opening;
        if (!current()) return;
        // Source loadMessageContext opens the canonical thread, then loads the
        // outer channel tail. Keep both accepted rows and reply focus while it
        // is pending; do not pass through selectChannel's thread reset/cache.
        try {
          final tail = await MessageHistoryPages.read(m, request, channelId);
          if (!current()) return;
          final accepted = m.acceptContextPage(
            request,
            channelId,
            tail,
            context: false,
          );
          await MessageHistoryPages.record(m, request, tail);
          if (!current()) return;
          final refreshedParent = accepted
              .where((row) => row['id'] == parentId)
              .firstOrNull;
          if (parentChannelId == channelId && refreshedParent != null) {
            m.state.threadParent = RaftMessage(refreshedParent);
          }
          settled();
          await m.entries.markRead(channelId);
          if (current()) await m.saveWindow(channelId);
        } catch (e) {
          if (!current()) return;
          if (e is RaftApiException && e.status == 403) {
            m.context.transitions.revokeChannel(channelId);
          } else {
            m.presentation.assignError(
              userErrorText(e, where: 'load message context'),
            );
            settled();
          }
        }
      } else {
        m.acceptContextPage(request, channelId, context);
        await MessageHistoryPages.record(m, request, context);
        if (!current()) return;
        final targetId = context['targetMessageId'] as String? ?? messageId;
        m.state.highlightedMessageId = targetId;
        settled();
        await m.entries.markRead(channelId);
      }
    } catch (e) {
      if (!current()) return;
      if (e is RaftApiException && e.status == 403) {
        m.context.transitions.revokeChannel(channelId);
      } else {
        m.messageWindows.finishContextVisit(request);
        m.state.highlightedMessageId = null;
        // Source falls back to latest after a missing/unavailable context.
        final fallback = m.entries.selectChannel(
          next,
          navigate: navigate,
          retainContextUntilAccepted: true,
        );
        await fallback;
        if (!m.context.disposed &&
            m.presentation.channel?.id == channelId &&
            generation == m.ledger.generation &&
            authority == m.windowAuthority()) {
          m.contextLoadError = m.state.historyLimited
              ? MessageContextLoadError.beyondHistory
              : MessageContextLoadError.notFound;
          m.context.changed();
        }
      }
    } finally {
      if (current()) {
        settled();
      }
    }
  }

  /// Context and canonical-thread fallback pages publish the same accepted
  /// row versions, boundaries and reply summaries before any notification.
  List<Map<String, dynamic>> acceptContextPage(
    MessageWindowRequest request,
    String id,
    dynamic page, {
    bool context = true,
  }) {
    if (!request.current) return [];
    final rows = acceptedWindowRows(page['messages'], id);
    m.state.historyLimited = !context && page['historyLimited'] == true;
    m.state.hasMore = context
        ? page['hasOlder'] == true
        : !m.state.historyLimited && rows.length >= 50;
    m.state.hasNewer = context && page['hasNewer'] == true;
    m.messageWindows.rememberWindow(
      request,
      id,
      m.windowAuthority(),
      m.state.hasMore,
      m.replyToken(id),
      historyLimited: m.state.historyLimited,
      rows: rows,
      replace: true,
    );
    m.messageWindows.setContextMode(
      request,
      id,
      context ? m.state.hasNewer : null,
    );
    m.mergeThreadSummaries(id, page['threadSummariesByParentMessageId']);
    return rows;
  }
}
