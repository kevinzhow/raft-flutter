import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'message_task_cache.dart';
import 'message_window_snapshot.dart';
import 'message_history_pages.dart';
import 'message_history_positions.dart';
import 'message_history_summaries.dart';
import 'workspace_message_windows.dart';
import 'user_error.dart';
import 'workspace_messages.dart';

/// Existing selection operations on the receiver-local message domain.
class WorkspaceMessageSelection {
  WorkspaceMessageSelection(this.m);
  final WorkspaceMessages m;

  void adoptAcceptedChannelSelection(Set<String> accessible) {
    // A held share's destination (and a DM that is not on the server yet)
    // stays open when the lists do not carry it: the composer says why.
    if (m.presentation.channel != null &&
        !WorkspaceMessages.isPendingDm(m.presentation.channel) &&
        !(m.drafts.composer.uploads.holds.containsKey(
              m.presentation.channel!.id,
            ) &&
            !accessible.contains(m.presentation.channel!.id))) {
      m.presentation.setSelectedChannel(
        [
          ...m.channels.channels,
          ...m.channels.dms,
        ].where((c) => c.id == m.presentation.channel!.id).firstOrNull,
      );
      if (m.presentation.channel == null) {
        if (m.state.threadChannelId != null) {
          m.messageWindows.revokeChannel(m.state.threadChannelId!);
        }
        m.entries.closeThread();
        m.messageWindows.channelGeneration++;
      }
    }
  }

  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  }) async {
    final source = m.source;
    if (source != null) {
      return source.entries.selectChannel(
        next,
        autoRead: autoRead,
        navigate: navigate,
        retainContextUntilAccepted: retainContextUntilAccepted,
        preserveThread: preserveThread,
        onDraftRestored: onDraftRestored,
      );
    }
    final retainThread =
        preserveThread &&
        m.threadIdentity?.parentChannelId == next.id &&
        m.presentation.location.thread?.channelId == next.id;
    if (!retainContextUntilAccepted && m.presentation.channel?.id != next.id) {
      m.contextLoadError = null;
    }
    autoRead &= m.channels.readsOnOpen(next.id);
    m.presentation.setSelectedChannel(next);
    m.state.hasNewer = false;
    if (!retainThread) m.state.highlightedMessageId = null;
    final priorWindow = m.messageWindows.accepted[next.id];
    final replyAuthority = m.replyToken(next.id);
    final compatible =
        priorWindow != null &&
        priorWindow.matches(m.windowAuthority(), replyAuthority);
    if (priorWindow != null && !compatible) {
      m.messageWindows.discardWindow(next.id);
      m.summariesByChannel.remove(next.id);
    }
    m.state.hasMore = compatible && priorWindow.hasMore;
    m.state.historyLimited = compatible && priorWindow.historyLimited;
    // Keep the accepted context kind until its replacement tail is accepted.
    if (!retainContextUntilAccepted &&
        m.messageWindows.setContextMode(liveWindowWrite, next.id, null)) {
      m.messageWindows.hideWindow(next.id);
    }
    if (navigate) m.presentation.assignSection('chat');
    if (!retainThread) {
      m.state.threadParent = null;
      m.state.threadChannelId = null;
      m.messageWindows.threadGeneration++;
    }
    m.state.loadingOlder = false;
    m.state.channelLoading = true;
    m.presentation.assignError(null);
    // Opening clears the unread at once; the receipt follows the first page.
    final optimisticRead =
        autoRead &&
        navigate &&
        !retainContextUntilAccepted &&
        ((m.channels.unread[next.id] ?? 0) != 0 ||
            m.channels.mentions.contains(next.id));
    final readPostsBefore = m.channels.beginOpenRead(
      next.id,
      optimistic: optimisticRead,
    );
    m.messageWindows.channelGeneration++;
    final request = m.windowRequest(
      next.id,
      checkNavigation: true,
      allowed: () =>
          m.presentation.channel?.id == next.id &&
          m.context.can('viewChannel', resource: m.presentation.channel),
    );
    m.context.changed();
    if (WorkspaceMessages.isPendingDm(next)) {
      // A DM that is not on the server yet has nothing to read: only its
      // saved draft, then the composer.
      await m.drafts.restoreDraft(next.id);
      onDraftRestored?.call();
      if (request.current) {
        m.state.channelLoading = false;
        m.context.changed();
      }
      return;
    }
    // Source ChatPanel loads the channel's tasks with its messages: start the
    // bucket read now so the chips are cached when the rows first render.
    unawaited(MessageTaskCache.of(m.transport.client).warm(m, next.id));
    await m.drafts.restoreDraft(next.id);
    // The composer can take staged content from here on; the message page
    // below is still loading.
    onDraftRestored?.call();
    if (!request.current) return;
    try {
      final page =
          retainContextUntilAccepted &&
              MessageHistoryPages.storage(m.device.cache) == null
          ? null
          : await m.device.read('window', next.id);
      if (!request.current) return;
      if (!retainContextUntilAccepted &&
          await MessageHistoryPositions.restoreMain(
            m,
            request,
            next.id,
            cached: page,
          )) {
        if (request.current) await m.device.write('selection', '', next.id);
        return;
      }
      if (m.restoreCachedTail(
        next.id,
        page,
        request,
        replace: retainContextUntilAccepted,
      )) {
        m.context.changed();
      }
      final retained = retainContextUntilAccepted
          ? <Map<String, dynamic>>[]
          : m.messages.map((m) => m.json).toList();
      final retainedHasMore = m.state.hasMore;
      m.transport.client.joinChannel(next.id);
      final fresh = await MessageHistoryPages.read(m, request, next.id);
      if (!request.current) return;
      m.acceptFreshTail(
        next.id,
        fresh,
        retained: retained,
        retainedHasMore: retainedHasMore,
        request: request,
      );
      await MessageHistoryPages.record(m, request, fresh);
      if (!request.current) return;
      m.state.channelLoading = false;
      m.context.changed();
      await m.saveWindow(next.id);
      if (!request.current) return;
      await m.device.write('selection', '', next.id);
      if (request.current && autoRead) await m.entries.markRead(next.id);
    } catch (e) {
      if (request.current) {
        if (e is RaftApiException && (e.status == 403 || e.status == 404)) {
          m.context.transitions.revokeChannel(next.id);
        } else {
          m.presentation.assignError(userErrorText(e, where: 'select channel'));
        }
      }
    } finally {
      if (request.current) {
        m.state.channelLoading = false;
        m.context.changed();
      }
      m.channels.reconcileOpenRead(
        next.id,
        readPostsBefore,
        optimistic: optimisticRead,
      );
    }
  }

  /// Reconciles a freshly read first page into the open channel's window: the
  /// page is authoritative over its own range, older retained rows stay, and
  /// nothing outside the page range is dropped. Shared by the open and by the
  /// silent revalidation of a retained window.
  void acceptFreshTail(
    String id,
    Map<String, dynamic> fresh, {
    required List<Map<String, dynamic>> retained,
    required bool retainedHasMore,
    required MessageWindowRequest request,
  }) {
    if (!request.current) return;
    final rows = acceptedWindowRows(fresh['messages'], id);
    m.messageWindows.setDiskOnly(request, id, false);
    m.state.historyLimited = fresh['historyLimited'] == true;
    m.messageWindows.acceptRows(
      request,
      id,
      rows,
      visible: m.state.historyLimited
          ? rows.map((e) => e['id'] as String)
          : reconcileTailWindow(retained, rows),
      replace: true,
    );
    MessageHistorySummaries.accept(m, id, retained, rows, fresh);
    m.state.hasMore =
        fresh['historyLimited'] != true &&
        (m.visibleIds[id]!.length > rows.length
            ? retainedHasMore
            : rows.length >= 50);
  }

  /// Source ChatPanel shows a retained bucket at once and re-reads the tail
  /// behind it. Used where a held window is shown without [selectChannel]
  /// (a jump to a message the window holds, a live seq gap): the first page is
  /// merged into the open window by [_acceptFreshTail], so rows already shown
  /// keep their place and only the missing newer rows are added.
  Future<void> revalidateTail(String id) async {
    if (m.presentation.channel?.id != id ||
        !m.messageWindows.beginTailRevalidation(id)) {
      return;
    }
    final request = m.windowRequest(
      id,
      allowed: () =>
          m.presentation.channel?.id == id &&
          !m.state.hasNewer &&
          m.context.can('viewChannel', resource: m.presentation.channel),
    );
    try {
      final retained = m.messages.map((m) => m.json).toList();
      final retainedHasMore = m.state.hasMore;
      final fresh = await MessageHistoryPages.read(m, request, id);
      if (!request.current) return;
      m.acceptFreshTail(
        id,
        fresh,
        retained: retained,
        retainedHasMore: retainedHasMore,
        request: request,
      );
      await MessageHistoryPages.record(m, request, fresh);
      if (!request.current) return;
      m.context.changed();
      await m.saveWindow(id);
    } catch (e) {
      if (request.current &&
          e is RaftApiException &&
          (e.status == 403 || e.status == 404)) {
        m.context.transitions.revokeChannel(id);
      }
      // Any other failure leaves the shown window as it was.
    } finally {
      m.messageWindows.endTailRevalidation(id);
    }
  }

  /// Web ChatPanel `joinChannel(channel.id)`: join the open channel, then
  /// re-read the channel list so the sidebar and composer see the membership.
  Future<void> joinOpenChannel() async {
    try {
      final c = m.presentation.channel!;
      await m.transport.command('POST', '/channels/${c.id}/join');
      await m.entries.refreshChannels();
      await m.entries.selectChannel(
        m.channels.channels.firstWhere((next) => next.id == c.id),
      );
    } catch (e) {
      _joinFailed(e, 'join channel');
    }
  }

  void _joinFailed(Object e, String where) {
    if (m.context.disposed || m.staleScope(e)) return;
    // ignore: raft_lints/avoid_imperative_notice_state -- User-initiated join; stale-scope failures are not reported; cleared on server switch or revoke.
    m.presentation.setError(userErrorText(e, where: where));
  }

  /// Web ThreadPanel `handleJoinParentChannel`: join the thread's parent
  /// channel (the CTA that replaces the composer for a non-member).
  Future<void> joinThreadParentChannel() async {
    final id = m.threadParentChannelId;
    if (id == null) return;
    try {
      await m.transport.command('POST', '/channels/$id/join');
      await m.entries.refreshChannels();
    } catch (e) {
      _joinFailed(e, 'join thread parent channel');
    }
  }
}
