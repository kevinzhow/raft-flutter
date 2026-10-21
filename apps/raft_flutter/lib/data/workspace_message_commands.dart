import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'message_window_snapshot.dart';
import 'message_history_pages.dart';
import 'message_history_positions.dart';
import 'thread_search.dart';
import 'thread_window_snapshot.dart';
import 'user_error.dart';
import 'workspace_messages.dart';

/// Web `isThreadAbsentLookupError` (threadStore.ts): only the route's explicit
/// "no thread for this message" 404 means an empty thread. A 404 carrying a
/// `code` is absent only for `THREAD_NOT_FOUND`; without a `code` the legacy
/// error text decides. Every other failure (a lost parent channel is also a
/// 404) is a load error with Retry.
bool isThreadAbsentLookupError(Object? error) {
  if (error is! RaftApiException || error.status != 404) return false;
  if (error.details.containsKey('code')) {
    return error.details['code'] == 'THREAD_NOT_FOUND';
  }
  return error.message == 'No thread found for this message';
}

/// Existing commands operations on the receiver-local message domain.
class WorkspaceThreadCommands {
  WorkspaceThreadCommands(this.m);
  final WorkspaceMessages m;

  Future<String?> ensureThread() async {
    if (m.source != null) return m.source!.entries.ensureThread();
    if (m.state.threadChannelId != null) return m.state.threadChannelId;
    return m.messageWindows.createThread(createThread);
  }

  Future<String?> createThread() async {
    final parentId = m.threadParentMessageId,
        parentChannelId = m.threadParentChannelId;
    if (parentId == null || parentChannelId == null) return null;
    final request = m.windowRequest(
      parentChannelId,
      thread: true,
      checkNavigation: true,
      allowed: () =>
          parentId == m.threadParentMessageId &&
          parentChannelId == m.threadParentChannelId,
    );
    final value = await m.transport.client.post(
      '/channels/$parentChannelId/threads',
      data: {'parentMessageId': parentId},
    );
    if (!request.current) {
      throw const RaftApiException('The thread changed. Please retry.');
    }
    m.state.threadChannelId = value['threadChannelId'];
    m.transport.client.joinChannel(m.state.threadChannelId!);
    m.context.changed();
    return m.state.threadChannelId;
  }

  Future<void> openThread(
    RaftMessage parent, {
    String? focusedMessageId,
    bool navigate = true,
  }) => m.windowReceiver.threads.openThreadLocal(
    parent.channelId,
    parent.id,
    focusedMessageId: focusedMessageId,
    navigate: navigate,
    acceptedParent: parent,
  );

  /// Opens a real thread identity independently of its parent metadata.
  /// [initialThreadChannelId] is the accepted inbox row's existing channel;
  /// Source opens that channel immediately without a resolution lookup.
  Future<void> openThreadIdentity({
    required String parentChannelId,
    required String parentMessageId,
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
  }) => m.windowReceiver.threads.openThreadLocal(
    parentChannelId,
    parentMessageId,
    focusedMessageId: focusedMessageId,
    initialThreadChannelId: initialThreadChannelId,
    navigate: navigate,
  );

  Future<void> openThreadLocal(
    String parentChannelId,
    String parentMessageId, {
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
    RaftMessage? acceptedParent,
  }) async {
    if (parentChannelId.trim().isEmpty || parentMessageId.trim().isEmpty) {
      return;
    }
    final knownThreadChannelId = initialThreadChannelId?.trim().isEmpty == false
        ? initialThreadChannelId
        : null;
    if (m.session.revocations.revokedChannels.contains(parentChannelId) ||
        m.session.revocations.revokedChannels.contains(knownThreadChannelId) ||
        !m.context.can(
          'viewChannel',
          resource: m.threadChannelResource(parentChannelId),
        )) {
      return;
    }
    if (navigate) {
      final next = m.presentation.location.withQuery({
        'thread': '$parentChannelId:$parentMessageId',
        'msg': ?focusedMessageId,
      });
      m.presentation.navigation.navigate(
        next,
        kind: m.presentation.location.panelNavigationKindTo(next),
      );
    }
    final navigationWindow = m.presentation.navigationRevision,
        requestAuthority = m.replyToken(parentChannelId),
        messageAuthority = m.threadResourceAuthority(parentChannelId),
        generation = m.ledger.generation;
    m.messageWindows.threadGeneration++;
    final request = m.messageWindows.request(
      thread: true,
      allowed: () =>
          navigationWindow == m.presentation.navigationRevision &&
          requestAuthority == m.replyToken(parentChannelId) &&
          (messageAuthority == null ||
              messageAuthority == m.threadResourceAuthority(parentChannelId)) &&
          !m.session.revocations.revokedChannels.contains(parentChannelId) &&
          !m.session.revocations.revokedChannels.contains(
            m.state.threadChannelId,
          ) &&
          m.context.can(
            'viewChannel',
            resource: m.threadChannelResource(parentChannelId),
          ),
    );
    m.state.threadIdentity = WorkspaceThreadIdentity(
      parentChannelId: parentChannelId,
      parentMessageId: parentMessageId,
      focusedMessageId: focusedMessageId,
    );
    m.state.threadVisit = request;
    final held = m.messageWindows.matchingThread(
      parentChannelId,
      parentMessageId,
      requestAuthority,
      messageAuthority,
    );
    final cached =
        held != null &&
            (knownThreadChannelId == null ||
                knownThreadChannelId == held.threadChannelId) &&
            (m.visibleIds[held.threadChannelId]?.isNotEmpty ?? false) &&
            (focusedMessageId == null ||
                m.visibleIds[held.threadChannelId]!.contains(focusedMessageId))
        ? held
        : null;
    if (cached == null) m.messageWindows.forgetThread(parentMessageId);
    m.state.threadParent = acceptedParent ?? cached?.parent;
    m.state.threadChannelId = knownThreadChannelId ?? cached?.threadChannelId;
    m.state.threadLoading = cached == null;
    m.state.threadResolutionLoading = m.state.threadChannelId == null;
    m.state.threadParentLoading = m.state.threadParent == null;
    m.state.threadResolutionError = null;
    m.state.threadHasMore = cached?.hasMore ?? false;
    m.state.threadHistoryLimited = cached?.historyLimited ?? false;
    m.state.highlightedMessageId = focusedMessageId;
    m.context.changed();
    Future<void> restoreCurrentDraft() async {
      final scope = 'thread:$parentMessageId';
      if (await m.drafts.composer.restoreText(scope, () => request.current)) {
        m.context.changed();
      }
    }

    unawaited(restoreCurrentDraft());

    Future<void> resolveParent() async {
      if (acceptedParent != null) return;
      try {
        final page = await m.transport.client.get(
          '/messages/context/$parentMessageId',
          query: threadParentQuery(parentChannelId),
        );
        if (!request.current) return;
        final rows = acceptedWindowRows(page['messages'], parentChannelId);
        final parent = rows
            .where((row) => row['id'] == parentMessageId)
            .firstOrNull;
        // Independently fetched parent metadata is not an accepted outer window.
        final liveParent = m.presentation.channel?.id == parentChannelId
            ? m.messages.where((row) => row.id == parentMessageId).firstOrNull
            : null;
        final resolved =
            liveParent ?? (parent == null ? null : RaftMessage(parent));
        // A background revalidation never takes away a shown parent.
        if (resolved != null || m.state.threadParent == null) {
          m.state.threadParent = resolved;
        }
        m.messageWindows.cacheThreadParent(
          request,
          parentMessageId,
          m.state.threadParent,
        );
      } catch (_) {
        if (!request.current) return;
        if (cached?.parent == null) m.state.threadParent = null;
      } finally {
        if (request.current) {
          m.state.threadParentLoading = false;
          m.context.changed();
        }
      }
    }

    Map<String, dynamic>? readingPage;
    Future<void> resolveReplies() async {
      try {
        if (m.state.threadChannelId == null) {
          dynamic info;
          try {
            info = await m.transport.client.get(
              '/channels/$parentChannelId/threads/$parentMessageId',
            );
          } on RaftApiException catch (e) {
            // Only the route's explicit "no thread for this message" 404 is an
            // empty thread; any other failure raises the in-panel Retry.
            if (!isThreadAbsentLookupError(e)) rethrow;
          }
          if (!request.current) return;
          m.state.threadResolutionLoading = false;
          if (info == null) return;
          m.state.threadChannelId = info['threadChannelId'];
          if (!request.current) return;
          m.context.changed();
        }
        readingPage ??= focusedMessageId == null
            ? await MessageHistoryPositions.restore(
                m,
                request,
                m.state.threadChannelId!,
                thread: true,
              )
            : null;
        final focused = focusedMessageId != null || readingPage != null;
        final page =
            readingPage ??
            (focusedMessageId == null
                ? await MessageHistoryPages.read(
                    m,
                    request,
                    m.state.threadChannelId!,
                    thread: true,
                  )
                : await MessageHistoryPages.context(
                    m,
                    request,
                    m.state.threadChannelId!,
                    focusedMessageId,
                    thread: true,
                  ));
        if (!request.current) return;
        final boundary = m.messageWindows.acceptThreadPage(
          request,
          m.state.threadChannelId!,
          page,
          focused: focused,
          retainOlder:
              cached?.contextWindow == false ||
              cached == null &&
                  m.messageWindows.isDiskOnly(m.state.threadChannelId),
          retainedHasMore: m.state.threadHasMore,
        );
        await MessageHistoryPages.record(m, request, page);
        if (!request.current) return;
        m.state.threadHistoryLimited = boundary.limited;
        m.state.threadHasMore = boundary.more;
        m.transport.client.joinChannel(m.state.threadChannelId!);
        m.state.threadLoading = false;
        m.messageWindows.cacheThread(
          request,
          parentMessageId,
          CachedMessageThread(
            parentChannelId,
            m.state.threadChannelId!,
            requestAuthority,
            messageAuthority,
            generation,
            m.state.threadHasMore,
            m.state.threadHistoryLimited,
            m.state.threadParent ?? cached?.parent,
            contextWindow: focused,
          ),
        );
        m.messageWindows.setContextMode(
          request,
          m.state.threadChannelId!,
          focused ? page['hasNewer'] == true : null,
        );
        m.context.changed();
        await m.entries.markRead(m.state.threadChannelId!);
        if (request.current) {
          m.saveWindow(m.state.threadChannelId!, thread: true);
        }
      } catch (e) {
        final denied = m.state.threadChannelId;
        if (request.current &&
            denied != null &&
            e is RaftApiException &&
            (e.status == 403 || e.status == 404)) {
          m.context.transitions.revokeChannel(denied);
          m.state.threadLoading = false;
          m.state.threadResolutionLoading = false;
          m.context.changed();
        }
        // A cached window stays readable when its revalidation fails.
        if (request.current && cached == null) {
          // ThreadPanel's in-panel "Couldn't load this thread" + Retry; Web raises
          // no workspace-level error for it.
          m.state.threadResolutionError = userErrorText(
            e,
            fallback: "Couldn't load this thread",
            where: 'open thread',
          );
        }
      } finally {
        if (request.current) {
          m.state.threadResolutionLoading = false;
          m.state.threadLoading = false;
          m.context.changed();
        }
      }
    }

    /// A tail thread with no window in memory paints its on-device window
    /// (previous visit or previous process) while the lookup revalidates.
    Future<void> restoreDiskWindow() async {
      if (cached != null && !cached.contextWindow || focusedMessageId != null) {
        return;
      }
      final page = await m.device.read('thread-window', parentMessageId);
      if (!request.current ||
          !m.state.threadLoading && cached?.contextWindow != true ||
          page is! Map) {
        return;
      }
      final threadId = page['threadChannelId'];
      if (page['version'] != 1 ||
          page['windowKind'] != 'tail' ||
          messageAuthority == null ||
          page['authority'] != messageAuthority ||
          page['parentChannelId'] != parentChannelId ||
          threadId is! String ||
          (m.state.threadChannelId != null &&
              m.state.threadChannelId != threadId) ||
          m.session.revocations.revokedChannels.contains(threadId)) {
        return;
      }
      readingPage = await MessageHistoryPositions.restoreThread(
        m,
        request,
        threadId,
        page,
      );
      if (readingPage != null) {
        m.state.threadResolutionLoading = false;
        m.state.threadParentLoading = m.state.threadParent == null;
        return;
      }
      final rows = acceptedWindowRows(page['messages'], threadId);
      if (rows.isEmpty) return;
      m.messageWindows.acceptRows(request, threadId, rows, replace: true);
      m.messageWindows.setDiskOnly(request, threadId, true);
      m.messageWindows.setContextMode(request, threadId, null);
      m.state.threadChannelId = threadId;
      final parent = page['parent'];
      if (m.state.threadParent == null &&
          parent is Map &&
          parent['id'] == parentMessageId &&
          parent['channelId'] == parentChannelId) {
        m.state.threadParent = RaftMessage(Map<String, dynamic>.from(parent));
        m.state.threadParentLoading = false;
      }
      m.state.threadHasMore = page['hasMore'] == true;
      m.state.threadHistoryLimited = page['historyLimited'] == true;
      m.state.threadLoading = false;
      m.state.threadResolutionLoading = false;
      m.context.changed();
    }

    await restoreDiskWindow();
    if (!request.current) return;
    // Source threadStore opens an accepted inbox row's known channel directly,
    // without a lookup. Parent metadata and focused replies load independently.
    final replies = resolveReplies();
    unawaited(resolveParent());
    await replies;
  }

  void closeThread({bool navigate = true}) =>
      m.windowReceiver.threads.closeThreadLocal(navigate);

  void closeThreadLocal(bool navigate) {
    if (navigate && m.presentation.location.thread != null) {
      final next = m.presentation.location.withQuery({'thread': null});
      m.presentation.navigation.navigate(
        next,
        kind: m.presentation.location.panelNavigationKindTo(next),
      );
    }
    m.messageWindows.threadGeneration++;
    m.state.threadIdentity = null;
    m.state.threadVisit = null;
    m.state.threadResolutionLoading = m.state.threadParentLoading = false;
    m.state.threadResolutionError = null;
    m.state.threadParent = null;
    m.state.threadChannelId = null;
    m.state.threadLoading = false;
    m.state.threadHistoryLimited = false;
    m.context.changed();
  }
}
