import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'conversation_window.dart';
import 'message_window_snapshot.dart';
import 'message_history_snapshots.dart';
import 'resource_snapshot_cache.dart';
import 'workspace_message_windows.dart';
import 'workspace_channels.dart';
import 'workspace_device_store.dart';
import 'workspace_domain_ports.dart';
import 'workspace_message_host.dart';
import 'workspace_message_state.dart';
import 'workspace_message_ports.dart';
import 'workspace_message_replies.dart';
import 'workspace_message_selection.dart';
import 'workspace_message_commands.dart';
import 'workspace_message_navigation.dart';
import 'workspace_session.dart';
import 'workspace_session_context.dart';

/// Message projections, accepted windows and existing operation coordinators
/// for one receiver. Borrowing selects the same stores at the original entry.
class WorkspaceMessages implements WorkspaceMessageHost {
  WorkspaceMessages({
    required this.context,
    required this.transport,
    required this.device,
    required this.presentation,
    required this.entries,
    required this.channels,
    required this.session,
    required this.drafts,
    required this.notifications,
    required this.resolveSource,
    required this.staleScope,
  });

  final WorkspaceSessionContext context;
  final WorkspaceTransportPort transport;
  final WorkspaceDeviceStore device;
  final WorkspaceMessagePresentationPort presentation;
  final WorkspaceMessageEntryPort entries;
  final WorkspaceChannels channels;
  final WorkspaceSession session;
  final WorkspaceMessageDraftPort drafts;
  final WorkspaceMessageNotificationPort notifications;
  final WorkspaceMessages? Function() resolveSource;
  final bool Function(Object) staleScope;
  final state = WorkspaceMessageState();
  WorkspaceMessages? get source => resolveSource();
  @override
  WorkspaceMessages get messageDomain => this;
  late final replyOperations = WorkspaceMessageReplies(this);
  late final selection = WorkspaceMessageSelection(this);
  late final threads = WorkspaceThreadCommands(this);
  late final navigation = WorkspaceMessageNavigation(this);
  late final WorkspaceMessageWindows messageWindows =
      source?.messageWindows ??
      WorkspaceMessageWindows(
        authority: windowAuthorityFor,
        presentation: windowPresentation,
        layout: windowLayout,
        sends: drafts.composer.sends,
        notRevoked: (id) => !context.isChannelRevoked(id),
      );
  static const gapPageLimit = 200;

  WorkspaceMessages get windowReceiver => source?.windowReceiver ?? this;

  ConversationWindow? get messageWindow =>
      messageWindows.channel(presentation.channel?.id);

  ConversationWindow? get threadWindow =>
      messageWindows.thread(threadParentChannelId, threadParentMessageId);

  MessageWindowAuthority? windowAuthorityFor(ConversationWindowScope scope) {
    final resource = threadChannelResource(scope.channelId);
    if (context.disposed ||
        transport.client.user == null ||
        context.server == null ||
        context.server!.id != transport.client.serverId ||
        session.revocations.revokedServers.contains(context.server!.id) ||
        session.revocations.revokedChannels.contains(scope.channelId) ||
        resource == null ||
        !context.can('viewChannel', resource: resource)) {
      return null;
    }
    final accepted = messageWindows.accepted[scope.channelId];
    final authority = messageWindowAuthority(
      context.server!.string('role'),
      resource.json,
    );
    if (accepted != null &&
        !accepted.matches(authority, replyToken(scope.channelId))) {
      return null;
    }
    return (
      presentation.navigationAuthority,
      ledger.generation,
      replyToken(scope.channelId),
      authority,
      jsonEncode(context.server!.json['permissions']),
    );
  }

  (bool, bool) windowLayout(ConversationWindowScope scope) {
    final selected = scope.parentMessageId == null
        ? presentation.channel?.id == scope.channelId
        : threadParentChannelId == scope.channelId &&
              threadParentMessageId == scope.parentMessageId;
    return (
      selected,
      selected &&
          presentation.foreground &&
          presentation.chatTabPresented &&
          (scope.parentMessageId == null
              ? presentation.mainPresented
              : presentation.threadPresented),
    );
  }

  ConversationWindowSnapshot windowPresentation(bool thread) {
    final rows = thread ? replies : messages;
    return ConversationWindowSnapshot(
      channelId: thread ? state.threadChannelId : presentation.channel?.id,
      rows: rows,
      timeline: timeline(thread: thread, rows: rows),
      parent: thread ? presentedThreadParent : null,
      loading: thread ? state.threadLoading : state.channelLoading,
      loadingOlder: state.loadingOlder,
      parentLoading: thread && threadParentLoading,
      resolving: thread && threadResolutionLoading,
      error: thread ? threadResolutionError : presentation.error,
      hasMore: thread ? state.threadHasMore : state.hasMore,
      hasNewer: thread
          ? messageWindows.contextHasNewer(state.threadChannelId)
          : state.hasNewer,
      historyLimited: thread
          ? state.threadHistoryLimited
          : state.historyLimited,
      highlightedMessageId: state.highlightedMessageId,
      contextLoadError: thread ? null : contextLoadError,
    );
  }

  /// Authority token for data owned by [channelId] (its message window, its
  /// thread windows and reply summaries).
  String replyToken(String? channelId) => replyOperations.replyToken(channelId);

  /// Retires one channel's reply authority (Source refreshes only the
  /// affected channel row on a membership event). Its reply scopes and
  /// thread windows go now; its message window is dropped on next use by the
  /// token mismatch. The open channel keeps its displayed summaries until its
  /// own refresh replaces them; a real revocation clears them in
  /// [_revokeChannel].
  void invalidateChannelReplies(String id) =>
      replyOperations.invalidateChannelReplies(id);

  void invalidateAllChannelReplies() =>
      replyOperations.invalidateAllChannelReplies();

  void mergeThreadSummaries(String id, dynamic rows) =>
      replyOperations.mergeThreadSummaries(id, rows);

  Map<String, dynamic> hydrateThreadSummaries(
    dynamic raw,
    String parentChannelId, {
    String? expectedToken,
  }) => replyOperations.hydrateThreadSummaries(
    raw,
    parentChannelId,
    expectedToken: expectedToken,
  );

  bool replyCurrent(String token, ThreadRebaselineRequest request) =>
      replyOperations.replyCurrent(token, request);

  Future<void> rebaselineThread(ThreadRebaselineRequest request) =>
      replyOperations.rebaselineThread(request);

  void consumeThreadUpdate(Map<String, dynamic> payload) =>
      replyOperations.consumeThreadUpdate(payload);

  /// The parent channel whose reply rows a `thread:updated` summary belongs
  /// to: the wire anchor first, else the channel already holding the parent.
  String? summaryOwner(Map<String, dynamic> payload, String parentId) =>
      replyOperations.summaryOwner(payload, parentId);

  /// Capture the common session facts once; the window owner captures its
  /// own epochs. A caller supplies only the operation-specific selection rule.
  MessageWindowRequest windowRequest(
    String id, {
    bool thread = false,
    bool checkNavigation = false,
    bool Function()? allowed,
  }) {
    final parent = thread ? threadParentChannelId : id;
    final reply = replyToken(parent), authority = windowAuthority();
    final revision = presentation.navigationRevision;
    return messageWindows.request(
      thread: thread,
      allowed: () =>
          reply == replyToken(parent) &&
          authority == windowAuthority() &&
          !session.revocations.revokedChannels.contains(id) &&
          (!checkNavigation || revision == presentation.navigationRevision) &&
          (allowed?.call() ?? true),
    );
  }

  String windowAuthority() => messageWindowAuthority(
    context.server?.string('role'),
    presentation.channel?.json ?? const {},
  );

  Object messageHistoryTicket(String id) => replyToken(id);

  void rejectHistoryRead(String id) =>
      windowReceiver.context.transitions.revokeChannel(id);

  Future<void> saveHistoryWindow(String id, {bool thread = false}) =>
      windowReceiver.saveWindow(id, thread: thread);

  Future<void> saveWindow(
    String id, {
    bool thread = false,
    bool coalesce = false,
  }) => MessageHistorySnapshots.save(
    this,
    id,
    thread: thread,
    coalesce: coalesce,
    identity: state.threadIdentity,
    replyToken: replyToken,
    write: device.write,
  );

  /// Disk windows retain canonical versions already held in memory. Only the
  /// bootstrap replaces visible membership and starts from disk summaries.
  bool restoreCachedTail(
    String id,
    dynamic page,
    MessageWindowRequest request, {
    String? replyAuthority,
    bool replace = false,
  }) {
    if (!MessageHistorySnapshots.restore(
      this,
      id,
      page,
      request,
      replace: replace,
      allowed: () =>
          !session.revocations.revokedServers.contains(context.server?.id),
    )) {
      return false;
    }
    summariesByChannel[id] = {
      ...hydrateThreadSummaries(
        page['threadSummaries'],
        id,
        expectedToken: replyAuthority ?? replyToken(id),
      ),
      if (!replace) ...?summariesByChannel[id],
    };
    return true;
  }

  MessageLedger get ledger => messageWindows.ledger;

  /// A destination that does not exist on the server yet (a new DM): the
  /// composer opens on this local row; [adoptResolvedDm] swaps in the real one.
  static RaftChannel pendingDm({
    required String key,
    required String serverId,
    required String name,
  }) => RaftChannel({
    'id': 'pending-dm:$key',
    'name': name,
    'type': 'dm',
    'joined': true,
    'serverId': serverId,
    'peerDisplayName': name,
    'pendingDm': true,
  });

  static bool isPendingDm(RaftChannel? c) => c?.json['pendingDm'] == true;

  ResourceSnapshotCache get resourceSnapshots =>
      source?.resourceSnapshots ?? state.resourceSnapshots;

  Map<String, Set<String>> get visibleIds => messageWindows.visibleIds;

  /// Pending unknown context; cross-channel cached tails are not that context.
  String? get pendingMessageContextChannelId =>
      messageWindows.pendingContextChannelId;

  WorkspaceThreadIdentity? get threadIdentity =>
      state.threadVisit?.current == true ? state.threadIdentity : null;

  bool get threadResolutionLoading =>
      threadIdentity != null && state.threadResolutionLoading;

  bool get threadParentLoading =>
      threadIdentity != null && state.threadParentLoading;

  String? get threadResolutionError =>
      threadIdentity == null ? null : state.threadResolutionError;

  RaftMessage? get presentedThreadParent => state.threadIdentity == null
      ? state.threadParent
      : threadIdentity != null &&
            state.threadParent?.id == threadIdentity!.parentMessageId &&
            state.threadParent?.channelId == threadIdentity!.parentChannelId
      ? state.threadParent
      : null;

  String? get threadParentMessageId =>
      threadIdentity?.parentMessageId ??
      (state.threadIdentity == null ? state.threadParent?.id : null);

  String? get threadParentChannelId =>
      threadIdentity?.parentChannelId ??
      (state.threadIdentity == null ? state.threadParent?.channelId : null);

  RaftChannel? threadChannelResource(String? id) => [
    ?presentation.channel,
    ...channels.channels,
    ...channels.dms,
  ].where((value) => value.id == id).firstOrNull;

  String? threadResourceAuthority(String? id) {
    final resource = threadChannelResource(id);
    return resource == null
        ? null
        : messageWindowAuthority(context.server?.string('role'), resource.json);
  }

  RaftChannel? get threadSourceChannel =>
      threadChannelResource(threadParentChannelId);

  /// Source messageStore `contextLoadError` for the open channel: the jump
  /// target's context failed to load and the latest window replaced it.
  /// `notFound` -> ChatPanel's "Message not found" banner; `beyondHistory` ->
  /// the plan history-limit banner. Cleared by the next channel open or jump.
  /// Bound to the channel and server it was raised for: it reads as null in
  /// any other one (a channel replaced without a re-open, a server switch).
  MessageContextLoadError? get contextLoadError {
    if (state.contextFailure?.$2 !=
        (presentation.channel?.id, context.server?.id)) {
      state.contextFailure = null;
    }
    return state.contextFailure?.$1;
  }

  set contextLoadError(MessageContextLoadError? value) =>
      state.contextFailure = value == null
      ? null
      : (value, (presentation.channel?.id, context.server?.id));

  int get channelGeneration => messageWindows.channelGeneration;

  int get threadGeneration => messageWindows.threadGeneration;

  Map<String, Map<String, dynamic>> get summariesByChannel =>
      replyOperations.summariesByChannel;

  /// Summaries of the selected channel's messages.
  Map<String, dynamic> get threadSummaries => replyOperations.threadSummaries;

  set threadSummaries(Map<String, dynamic> value) =>
      replyOperations.threadSummaries = value;

  /// Summaries held for [channelId] (selected or not).
  Map<String, dynamic> threadSummariesFor(String channelId) =>
      replyOperations.threadSummariesFor(channelId);

  List<RaftMessage> get messages =>
      messageWindows.rows(presentation.channel?.id);

  /// Same membership as [messages], in constant time (no list projection).
  bool presentsMessage(String? id) =>
      messageWindows.retainsContextRows(presentation.channel?.id) &&
      messageWindows.containsVisible(presentation.channel?.id, id);

  /// Same membership as [replies], in constant time.
  bool presentsReply(String? id) =>
      messageWindows.containsVisible(state.threadChannelId, id);

  List<RaftMessage> get replies => messageWindows.rows(state.threadChannelId);

  /// Web display order uses server sequence, with a display-only coordinate
  /// for pending rows. Context windows keep their existing admission policy.
  List<RaftMessage> timeline({bool thread = false, List<RaftMessage>? rows}) =>
      messageWindows.project(
        rows ?? (thread ? replies : messages),
        drafts.draftScope(thread: thread),
        context:
            !thread &&
            (state.hasNewer ||
                pendingMessageContextChannelId == presentation.channel?.id),
      );

  /// Stable presentation identity: a row sent from this session keeps its
  /// optimistic key after the server copy replaces it, so the timeline
  /// updates that row in place instead of removing and inserting one.
  String messageKey(RaftMessage message) {
    if (source != null) {
      return source!.messageKey(message);
    }
    final randomId = message.json['randomId'];
    return randomId is String && drafts.composer.sends.localId(randomId)
        ? 'optimistic-$randomId'
        : message.id;
  }

  /// Whether [message] is an optimistic row still waiting for the server.
  static bool isPendingSend(RaftMessage message) =>
      message.json['pendingSend'] == true;

  void clearRevokedChannelProjection(String scope) {
    channels.unread.remove(scope);
    channels.clearMention(scope);
    channels.latestActivity.remove(scope);
    summariesByChannel.remove(scope);
  }

  void removeRevokedParentSummary(dynamic messageId) {
    for (final bucket in summariesByChannel.values) {
      bucket.remove(messageId);
    }
  }

  void adoptAcceptedChannelSelection(Set<String> accessible) =>
      selection.adoptAcceptedChannelSelection(accessible);

  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  }) => selection.selectChannel(
    next,
    autoRead: autoRead,
    navigate: navigate,
    retainContextUntilAccepted: retainContextUntilAccepted,
    preserveThread: preserveThread,
    onDraftRestored: onDraftRestored,
  );

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
  }) => selection.acceptFreshTail(
    id,
    fresh,
    retained: retained,
    retainedHasMore: retainedHasMore,
    request: request,
  );

  /// Source ChatPanel shows a retained bucket at once and re-reads the tail
  /// behind it. Used where a held window is shown without [selectChannel]
  /// (a jump to a message the window holds, a live seq gap): the first page is
  /// merged into the open window by [_acceptFreshTail], so rows already shown
  /// keep their place and only the missing newer rows are added.
  Future<void> revalidateTail(String id) => selection.revalidateTail(id);

  Future<void> older({bool thread = false}) => navigation.older(thread: thread);

  Future<void> newer({bool thread = false}) => navigation.newer(thread: thread);

  Future<void> loadHistoryGap(BigInt before, {bool thread = false}) =>
      navigation.loadHistoryGap(before, thread: thread);

  Future<void> olderLocal(bool thread) => navigation.olderLocal(thread);

  Future<void> pageHistory(
    bool thread, {
    bool newer = false,
    BigInt? gapBefore,
  }) => navigation.pageHistory(thread, newer: newer, gapBefore: gapBefore);

  /// Where the reader was in a conversation when its timeline is about to be
  /// rebuilt for another layout (fold / unfold). The next timeline that
  /// mounts for [conversationId] shortly after resumes there; an anchor that
  /// is not claimed promptly is a stale position and is ignored.
  void saveReadingAnchor(String conversationId, ReadingAnchor anchor) =>
      navigation.saveReadingAnchor(conversationId, anchor);

  ReadingAnchor? takeReadingAnchor(String conversationId) =>
      navigation.takeReadingAnchor(conversationId);

  /// Project session delivery into each existing accepted window. This does
  /// not create another ledger or move a page's current selection.
  void sendChanged(String scope, RaftMessage? accepted) {
    if (context.disposed) return;
    final selected =
        scope == drafts.draftScope() ||
        scope == drafts.draftScope(thread: true);
    if (accepted != null &&
        !session.revocations.revokedChannels.contains(accepted.channelId)) {
      final id = accepted.channelId;
      if (id == presentation.channel?.id && !state.hasNewer ||
          id == state.threadChannelId ||
          messageWindows.retainsLiveTail(id)) {
        messageWindows.acceptRows(liveWindowWrite, id, [accepted.json]);
        unawaited(saveWindow(id, thread: id == state.threadChannelId));
      }
    }
    if (selected) context.changed();
  }

  /// Clears only the focus owned by the mounted timeline's highlight timer.
  void clearHighlightedMessage(
    String? expectedId, {
    int? expectedNavigationRevision,
  }) => navigation.clearHighlightedMessage(
    expectedId,
    expectedNavigationRevision: expectedNavigationRevision,
  );

  /// Source ChatPanel.handleBackToBottom reloads latest when newer is unloaded.
  Future<void> returnToLatest({bool navigate = true, bool thread = false}) =>
      navigation.returnToLatest(navigate: navigate, thread: thread);

  /// [replaceEntry] makes the destination take over the current history
  /// entry instead of pushing (Web openThreadParentMessageRoute, mobile).
  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
    bool replaceEntry = false,
  }) => navigation.jumpToMessage(
    channelId,
    messageId,
    navigate: navigate,
    replaceEntry: replaceEntry,
  );

  /// Context and canonical-thread fallback pages publish the same accepted
  /// row versions, boundaries and reply summaries before any notification.
  List<Map<String, dynamic>> acceptContextPage(
    MessageWindowRequest request,
    String id,
    dynamic page, {
    bool context = true,
  }) => navigation.acceptContextPage(request, id, page, context: context);

  /// Web ChatPanel `joinChannel(channel.id)`: join the open channel, then
  /// re-read the channel list so the sidebar and composer see the membership.
  Future<void> joinOpenChannel() => selection.joinOpenChannel();

  /// Web ThreadPanel `handleJoinParentChannel`: join the thread's parent
  /// channel (the CTA that replaces the composer for a non-member).
  Future<void> joinThreadParentChannel() => selection.joinThreadParentChannel();

  /// Replace a held message's reactions (and the open thread's parent copy).
  /// Not persisted: optimistic state never reaches the disk cache.
  bool setMessageReactions(
    String channelId,
    String messageId,
    List<Map<String, dynamic>> reactions,
  ) {
    var changed = false;
    if (ledger.contains(channelId, messageId)) {
      changed = ledger.ingestUpdate({
        'id': messageId,
        'channelId': channelId,
        'reactions': reactions,
      }, expectedGeneration: ledger.generation);
    }
    final parent = state.threadParent;
    if (parent != null && parent.id == messageId) {
      state.threadParent = RaftMessage({
        ...parent.json,
        'reactions': reactions,
      });
      changed = true;
    }
    return changed;
  }
}
