import 'dart:async';
import 'dart:convert';

import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'channel_repository.dart';
import 'conversation_read_repository.dart';
import 'raft_location.dart';
import 'sidebar_repository.dart';
import 'task_discussion_read.dart';
import 'user_activity.dart';
import 'workspace_domain_ports.dart';
import 'workspace_session_context.dart';

/// Channel, read-state and sidebar behavior for one workspace receiver.
///
/// The composition root retains the existing public override/source bindings.
/// Repositories may be borrowed, while the five remaining projections below
/// belong to this receiver. No event subscription or session is created here.
class WorkspaceChannels
    implements
        WorkspaceChannelDirectoryPort,
        WorkspaceReadStatePort,
        WorkspaceReadCommandsPort,
        WorkspaceReadProjectionPort {
  WorkspaceChannels({
    required this.context,
    required this.transport,
    required this.presentation,
    required this.messages,
    required this.windows,
    required this.messagePrefetch,
    required this.sessionEffects,
    required this.directory,
    required this.reads,
    required this.sidebar,
    required this._effectiveReadState,
    required this._refreshUnread,
  });

  final WorkspaceSessionContext context;
  final WorkspaceTransportPort transport;
  final WorkspacePresentationReadPort presentation;
  final WorkspaceMessageRowsPort messages;
  final WorkspaceWindowFactsPort windows;
  final WorkspaceMessagePrefetchPort messagePrefetch;
  final WorkspaceSessionEffectsPort sessionEffects;
  final ChannelRepository directory;
  final ConversationReadRepository reads;
  final SidebarRepository sidebar;

  // Preserve the source-effective getter and the overridable public refresh
  // entrypoint, rather than flattening nested borrowed receivers to a client.
  final ReadStateLedger Function() _effectiveReadState;
  final Future<void> Function() _refreshUnread;

  final _prefetched = <String>{};
  bool _prefetching = false;
  final notificationPrefsSync = NotificationPrefsSync();
  Map<String, dynamic> sidebarOrder = {};
  int savedRevision = 0;

  RaftClient get client => transport.client;

  @override
  List<RaftChannel> get channels => directory.channels;
  set channels(List<RaftChannel> value) => directory.channels = value;
  @override
  List<RaftChannel> get dms => directory.dms;
  set dms(List<RaftChannel> value) => directory.dms = value;
  @override
  Map<String, int> get unread => reads.unread;
  set unread(Map<String, int> value) => reads.unread = value;
  @override
  Set<String> get mentions => reads.mentions;
  set mentions(Set<String> value) => reads.mentions = value;
  Set<String> get newFlags => reads.newFlags;
  set newFlags(Set<String> value) => reads.newFlags = value;
  @override
  ReadStateLedger get localReadState => reads.localReadState;
  @override
  ReadStateLedger get effectiveReadState => _effectiveReadState();
  @override
  Map<String, int> get readPosts => reads.readPosts;
  @override
  RaftTimelineBottoms get scrolledAway => reads.scrolledAway;
  Map<String, BigInt> get latestActivity => reads.latestActivity;

  @override
  RaftChannel? channelById(String id) =>
      [...channels, ...dms].where((c) => c.id == id).firstOrNull;

  @override
  Future<void> refreshChannels() => directory.refreshChannels();
  @override
  Future<void> refreshChannel(String id) => directory.refreshChannel(id);
  @override
  void recordRowWrite(String id) => directory.recordRowWrite(id);
  @override
  void putRow(RaftChannel row) => directory.putRow(row);

  void acceptChannelLists(
    List<RaftChannel> nextChannels,
    List<RaftChannel> nextDms, {
    required Set<String> readmit,
  }) => directory.acceptLists(nextChannels, nextDms, readmit: readmit);

  void consumeRealtime(String name, dynamic payload) =>
      directory.consumeRealtime(name, payload);

  void consumeMessageDisplayPrefs(dynamic payload) =>
      directory.consumeMessageDisplayPrefs(payload);

  void setActivityMuteState(String id, Map<String, dynamic> state) =>
      directory.setActivityMuteState(id, state);

  Future<void> loadSidebar() => sidebar.load();
  Future<void> updateSidebarOrder(Map<String, dynamic> updates) =>
      sidebar.update(updates);

  void savedChanged() {
    ++savedRevision;
    context.changed();
  }

  @override
  void assignSidebarOrder(Map<String, dynamic> value) => sidebarOrder = value;

  @override
  void resetDirectoryAndUnreadProjection() {
    channels = [];
    dms = [];
    unread = {};
    mentions = {};
    newFlags = {};
    latestActivity.clear();
  }

  @override
  void resetNotificationPrefsIdentity() => notificationPrefsSync.reset();

  void clearSessionPrefetch() => _prefetched.clear();

  /// Preserve the original Files cache authority independently of selection.
  String? channelFilesAuthority(String channelId) {
    final identity = context.panelIdentity();
    if (identity == null || context.isChannelRevoked(channelId)) return null;
    final current = presentation.channel?.id == channelId
        ? presentation.channel
        : null;
    final row =
        current ??
        [...channels, ...dms].where((c) => c.id == channelId).firstOrNull;
    if (row == null || !context.can('viewChannel', resource: row)) return null;
    return jsonEncode([identity, row.id, row.json['channelCapabilities']]);
  }

  void consumeNotificationPrefs(dynamic payload) {
    sessionEffects.ensureSyncIdentity();
    var update = readNotificationPrefsUpdate(payload);
    if (update == null ||
        update['serverId'] != client.serverId ||
        client.user == null) {
      return;
    }
    if (sessionEffects.syncCoreNotificationPrefsEnabled) {
      update = notificationPrefsSync.consume(update);
      if (update == null) return;
    }
    final accepted = update;
    if (accepted['type'] == 'server') {
      final version = accepted['prefsVersion'];
      RaftRecord patch(RaftRecord value) {
        if (value.id != accepted['serverId']) return value;
        final prior = value.json['notificationPrefsVersion'];
        if (prior is int && version is int && version < prior) return value;
        return RaftRecord({
          ...value.json,
          'serverPushMuted': accepted['serverPushMuted'],
          'notificationPrefsVersion': ?version,
        });
      }

      sessionEffects.patchServerRows(patch);
    } else if (!directory.applyNotificationPrefs(accepted)) {
      return;
    }
    _refreshUnread();
  }

  /// One policy body for ordinary, mobile, preview and task-discussion reads.
  bool mayMarkRead(String id) {
    if (!presentation.foreground ||
        id == presentation.channel?.id &&
            (!presentation.mainPresented ||
                !presentation.chatTabPresented ||
                windows.hasNewer ||
                windows.channelLoading) ||
        id == windows.threadChannelId && !presentation.threadPresented ||
        id != presentation.channel?.id && id != windows.threadChannelId) {
      return false;
    }
    final current = presentation.location, content = current.content;
    final previewMounted =
        current.route == RaftRoute.search ||
        current.route == RaftRoute.activity;
    if (id == presentation.channel?.id) {
      if (presentation.mobileNavigation && current.thread != null) return false;
      return (current.route == RaftRoute.channel ||
                  current.route == RaftRoute.dm) &&
              current.entityId == presentation.channel?.id ||
          previewMounted &&
              (content?.kind == RaftContentKind.channel ||
                  content?.kind == RaftContentKind.dm) &&
              content?.id == presentation.channel?.id;
    }
    return isTaskDiscussion(context.receiverKey) ||
        current.thread != null &&
            current.thread?.channelId == windows.threadParentChannelId &&
            current.thread?.itemId == windows.threadParentMessageId ||
        previewMounted &&
            current.knownThreadChannelId == windows.threadChannelId;
  }

  @override
  Future<void> markRead(String id) => reads.markRead(id);
  @override
  Future<void> refreshUnread() => reads.refreshUnread();
  @override
  void markUnreadLocally(String id) => reads.markUnreadLocally(id);
  @override
  bool acceptReadAllAck(
    String scopeId,
    dynamic receipt, {
    required String serverId,
    required String principalId,
  }) => reads.acceptReadAllAck(
    scopeId,
    receipt,
    serverId: serverId,
    principalId: principalId,
  );

  void persistReadState() => reads.persistReadState();
  void persistUnread() => reads.persistUnread();
  void receiveUnread(Map<String, dynamic> row) => reads.receiveUnread(row);
  void clearMention(String id) => reads.clearMention(id);
  void projectReadState(String id) => reads.projectReadState(id);
  void applyThreadUnread(dynamic id, dynamic summary) =>
      reads.applyThreadUnread(id, summary);
  void setTimelineAtBottom(String id, bool atBottom) =>
      reads.setTimelineAtBottom(id, atBottom);

  @override
  int beginOpenRead(String id, {required bool optimistic}) {
    final readPostsBefore = readPosts[id] ?? 0;
    scrolledAway.reset(id);
    if (optimistic) {
      if ((unread[id] ?? 0) != 0) unread = {...unread, id: 0};
      clearMention(id);
      persistUnread();
    }
    return readPostsBefore;
  }

  @override
  void reconcileOpenRead(
    String id,
    int readPostsBefore, {
    required bool optimistic,
  }) {
    if (optimistic &&
        !context.disposed &&
        (readPosts[id] ?? 0) == readPostsBefore) {
      unawaited(_refreshUnread());
    }
  }

  /// D2 selects candidates; D4 owns the complete, guarded page operation.
  Future<void> prefetchLikelyChannels({int limit = 6}) async {
    if (_prefetching ||
        context.disposed ||
        presentation.loading ||
        presentation.channel == null) {
      return;
    }
    _prefetching = true;
    try {
      final role = context.server?.string('role'),
          identity = context.syncIdentity(),
          generation = messages.generation;
      bool stillCurrent() =>
          !context.disposed &&
          role == context.server?.string('role') &&
          identity == context.syncIdentity() &&
          generation == messages.generation;
      final candidates = [
        for (final c in [...channels, ...dms])
          if (c.id != presentation.channel?.id &&
              !_prefetched.contains(c.id) &&
              !context.isChannelRevoked(c.id) &&
              !messages.hasAcceptedWindow(c.id) &&
              (unread[c.id] ?? 0) > 0 &&
              context.can('viewChannel', resource: c))
            c,
      ].take(limit).toList();
      for (final c in candidates) {
        if (!stillCurrent()) return;
        _prefetched.add(c.id);
        await messagePrefetch.prefetchAcceptedTail(
          c,
          stillCurrent: stillCurrent,
        );
      }
    } finally {
      _prefetching = false;
    }
  }
}
