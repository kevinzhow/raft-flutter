import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'attachment_image_repository.dart';
import 'burst_reads.dart';
import 'channel_revocation.dart';
import 'source_activity_unread_store.dart';
import 'workspace_domain_ports.dart';
import 'workspace_member_events.dart';
import 'workspace_entity_directory.dart';
import 'workspace_session_bindings.dart';
import 'workspace_session_context.dart';
import 'workspace_server_directory.dart';
import 'workspace_session_features.dart';

/// Receiver-local session, directory, connection and feature-flag policy.
/// The composition root supplies separate typed ports; it is never retained as
/// an untyped controller or used to discover unrelated domain state.
class WorkspaceSession
    implements WorkspaceSessionEffectsPort, WorkspaceConnectionProgressPort {
  WorkspaceSession({
    required this.context,
    required this.transport,
    required WorkspaceDevicePort device,
    required this.entries,
    required this.directory,
    required this.presentation,
    required this.messages,
    required WorkspaceSessionDrafts drafts,
    required this.entities,
    required this.revocations,
    required bool Function(Object) quietFailure,
    required bool Function(Object) staleScope,
    required this.ownsClient,
  }) {
    _serverDirectory = WorkspaceServerDirectory(
      context: context,
      transport: transport,
      device: device,
      entries: entries,
      directory: directory,
      presentation: presentation,
      messages: messages,
      drafts: drafts,
      revocations: revocations,
      burstReads: _burstAt,
      clientOwnership: () => ownsClient,
      ensureIdentity: () => _features.ensureSyncIdentity(),
      quietFailure: quietFailure,
      staleScope: staleScope,
    );
    _features = WorkspaceSessionFeatures(
      context: context,
      transport: transport,
      directory: directory,
      messages: messages,
    );
  }
  final WorkspaceSessionContext context;
  final WorkspaceTransportPort transport;
  final WorkspaceSessionEntries entries;
  final WorkspaceSessionChannels directory;
  final WorkspaceSessionPresentation presentation;
  final WorkspaceSessionMessages messages;
  final WorkspaceSessionEntities entities;
  final WorkspaceSessionRevocations revocations;
  final bool ownsClient;

  late final WorkspaceServerDirectory _serverDirectory;
  late final WorkspaceSessionFeatures _features;
  List<RaftRecord> get servers => _serverDirectory.servers;
  set servers(List<RaftRecord> value) => _serverDirectory.servers = value;
  RaftRecord? get server => _serverDirectory.server;
  set server(RaftRecord? value) => _serverDirectory.server = value;
  bool connected = false;
  @override
  bool get syncCoreNotificationPrefsEnabled =>
      _features.syncCoreNotificationPrefsEnabled;
  set syncCoreNotificationPrefsEnabled(bool value) =>
      _features.syncCoreNotificationPrefsEnabled = value;
  bool get remoteComputerUpgradeEnabled =>
      _features.remoteComputerUpgradeEnabled;
  set remoteComputerUpgradeEnabled(bool value) =>
      _features.remoteComputerUpgradeEnabled = value;
  bool get agentMigrationEnabled => _features.agentMigrationEnabled;
  set agentMigrationEnabled(bool value) =>
      _features.agentMigrationEnabled = value;
  bool get runtimeFormV2WebEnabled => _features.runtimeFormV2WebEnabled;
  set runtimeFormV2WebEnabled(bool value) =>
      _features.runtimeFormV2WebEnabled = value;
  // ignore: raft_lints/avoid_unreleased_resource -- The composition root disposes this notifier at the original ordered disposal stage.
  final resumes = ValueNotifier<int>(0);
  late final StreamSubscription<RaftEvent> subscription;
  bool _roomsJoinedPending = false;
  DateTime? _lastHeartbeat, _lastServerEvent;
  (int, BigInt)? _gapSyncedThrough;
  final _burstAt = BurstReads();
  int get planRevision => _serverDirectory.planRevision;
  set planRevision(int value) => _serverDirectory.planRevision = value;
  static const remoteComputerUpgradeFlag =
      WorkspaceSessionFeatures.remoteComputerUpgradeFlag;
  static const agentMigrationFlag = WorkspaceSessionFeatures.agentMigrationFlag;
  static const runtimeFormV2WebFlag =
      WorkspaceSessionFeatures.runtimeFormV2WebFlag;
  static const _burstFreshness = Duration(seconds: 15);
  static const _membershipResumeFreshness = Duration(seconds: 60);
  static const presenceEvents = {
    'agent:activity',
    'agent:seen',
    'agent:session',
    'machine:status',
    'machine:capabilities',
  };

  RaftClient get client => transport.client;
  WorkspaceEntityDirectory get entityDirectory => entities.entityDirectory;
  SourceActivityUnreadStore? get activityUnreadIfBound =>
      entities.activityUnreadIfBound;
  MessageLedger get ledger => messages.ledger;
  MessageSync get messageSync => messages.messageSync;
  ThreadRepliesSync get threadRepliesSync => messages.threadRepliesSync;
  NotificationPrefsSync get notificationPrefsSync =>
      directory.notificationPrefsSync;
  ReadStateLedger get readState => directory.readState;
  List<RaftChannel> get channels => directory.channels;
  List<RaftChannel> get dms => directory.dms;
  set sidebarOrder(Map<String, dynamic> value) =>
      directory.assignSidebarOrder(value);
  RaftChannel? get channel => presentation.channel;
  set channel(RaftChannel? value) => presentation.setSelectedChannel(value);
  String get section => presentation.section;
  set section(String value) => presentation.assignSection(value);
  set error(String? value) => presentation.assignError(value);
  set loading(bool value) => presentation.assignLoading(value);
  bool get mobileNavigation => presentation.mobileNavigation;
  int get navigationRevision => presentation.navigationRevision;
  int get channelGeneration => messages.channelGeneration;
  int get threadGeneration => messages.threadGeneration;
  bool canVisitSection(String value) => presentation.canVisitSection(value);
  @override
  (int, BigInt)? get gapSyncedThrough => _gapSyncedThrough;
  @override
  void assignGapSyncedThrough((int, BigInt)? value) =>
      _gapSyncedThrough = value;
  @override
  void patchServerRows(RaftRecord Function(RaftRecord) patch) =>
      _serverDirectory.patchServerRows(patch);

  void attachSubscription(void Function(RaftEvent) receive) {
    subscription = entries.sessionSource == null
        ? client.events.listen(receive)
        : const Stream<RaftEvent>.empty().listen((_) {});
  }

  WorkspaceEntityScope? entityScope() {
    final principal = client.user?.id;
    final serverId = client.serverId;
    if (context.disposed ||
        principal == null ||
        serverId == null ||
        server?.id != serverId) {
      return null;
    }
    return WorkspaceEntityScope(
      origin: client.origin,
      principal: principal,
      serverId: serverId,
      generation: client.generation,
      role: server?.string('role') ?? '',
      capabilities: {
        if (context.can('viewAgents')) WorkspaceEntityKind.agents,
        if (context.can('viewMachines')) WorkspaceEntityKind.computers,
        if (context.can('viewMembers')) WorkspaceEntityKind.members,
      },
    );
  }

  void entityAuthorityChanged() {
    if (context.disposed || !entities.ownsEntityDirectory) return;
    if (entityDirectory.synchronize() && entityDirectory.started) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot deferral out of a build or notification; the callback does not schedule another microtask itself.
      scheduleMicrotask(() {
        if (!context.disposed) unawaited(entityDirectory.preload());
      });
    }
  }

  AttachmentImageScope get attachmentImageScope => AttachmentImageScope(
    origin: client.origin,
    principal: client.user?.id ?? '',
    server: client.serverId ?? '',
    generation: client.generation,
    role: server?.string('role') ?? '',
  );

  String? panelCacheIdentity() {
    final principal = client.user?.id;
    final serverId = client.serverId;
    if (context.disposed ||
        principal == null ||
        serverId == null ||
        server?.id != serverId) {
      return null;
    }
    return jsonEncode([
      client.origin,
      principal,
      serverId,
      client.generation,
      server?.string('role'),
    ]);
  }

  String syncIdentity() => jsonEncode([
    client.origin,
    client.generation,
    client.serverId,
    client.user?.id,
    server?.string('role'),
  ]);

  @override
  void ensureSyncIdentity() => _features.ensureSyncIdentity();

  /// Whether a member list change can change this principal's visibility of
  /// the channel (Source resource views fail closed on the same rule).
  bool membershipScoped(String id) {
    final known = [...channels, ...dms].where((c) => c.id == id).firstOrNull;
    if (known == null) return true;
    return const {'private', 'dm', 'joint', 'thread'}.contains(known.type);
  }

  Future<void> refreshMessageSyncFlag() => _features.refreshMessageSyncFlag();

  Set<String> get revokedChannels => revocations.revokedChannels;

  Set<String> get revokedServers => revocations.revokedServers;

  void resetServerProjection() {
    messages.resetHistoryLimits();
    presentation.setSelectedChannel(null);
    directory.resetDirectoryAndUnreadProjection();
    messages.resetThreadProjection();
  }

  void revokeServer(String id) => context.transitions.revokeServer(id);

  void closeRevokedServerProjection() {
    server = null;
    sidebarOrder = {};
    error = null;
    _features.invalidateRequests();
    if (ownsClient) client.selectServer(null);
    loading = false;
    messages.closeServerLoading();
  }

  bool can(String capability, {RaftChannel? resource}) =>
      _serverDirectory.can(capability, resource: resource);

  Future<bool> loadServerDirectory({
    bool cachedFirst = false,
    void Function()? onCacheMiss,
  }) => _serverDirectory.loadServerDirectory(
    cachedFirst: cachedFirst,
    onCacheMiss: onCacheMiss,
  );

  Future<List<RaftChannel>?> cachedChannelDirectory(String serverId) =>
      _serverDirectory.cachedChannelDirectory(serverId);

  Future<void> revalidateServerDirectory() =>
      _serverDirectory.revalidateServerDirectory();

  Future<void> bootstrap() => _serverDirectory.bootstrap();

  void beginServerSelectionProjection(RaftRecord next) {
    server = next;
    // A workspace error belongs to the server where it was raised.
    error = null;
    _burstAt.clear();
    if (mobileNavigation) section = 'home';
    if (!canVisitSection(section)) section = 'chat';
    sidebarOrder = {};
    client.selectServer(next.id);
  }

  void resetServerSelectionState() {
    directory.resetRowAuthority();
    // The new server's socket connects for the first time.
    _roomsJoinedPending = false;
    _gapSyncedThrough = null;
    messages.resetNewer();
  }

  Future<void> selectServer(
    RaftRecord next, {
    void Function()? onHydrated,
    void Function()? onCacheMiss,
  }) => _serverDirectory.selectServer(
    next,
    onHydrated: onHydrated,
    onCacheMiss: onCacheMiss,
  );

  void revokeChannel(String id) => context.transitions.revokeChannel(id);

  ChannelRevocationPlan planChannelRevocation(String id) =>
      messages.discoverRevocation(id);

  void roomsJoined() {
    SourceActivityUnreadStore.activateForRooms(entities);
    _roomsJoinedPending = false;
    unawaited(messages.resumeHistory());
    // A reconnect and a resume can both ask within a second; the tail read a
    // moment ago already covers them.
    if (due('gap', freshness: const Duration(seconds: 3))) {
      unawaited(messages.syncVisibleScopes());
    }
    if (due('channels')) unawaited(directory.refreshChannels());
    if (due('unread')) unawaited(directory.refreshUnread());
  }

  bool due(String name, {Duration freshness = _burstFreshness}) =>
      _burstAt.due(name, freshness);

  void heartbeat(dynamic payload) {
    _lastHeartbeat = DateTime.now();
    // A lost `rooms:joined`: the connection's first heartbeat stands in.
    if (_roomsJoinedPending) {
      roomsJoined();
      return;
    }
    final seq = payload is Map ? BigInt.tryParse('${payload['seq']}') : null;
    final synced = _gapSyncedThrough;
    if (seq == null ||
        seq <= ledger.watermark ||
        synced != null && synced.$1 == ledger.generation && seq <= synced.$2) {
      return;
    }
    unawaited(messages.syncVisibleScopes(through: seq));
  }

  void resumeLiveSession() {
    if (context.disposed || !ownsClient || client.serverId == null) return;
    // The Activity window and the cross-server summary are read at once, in
    // parallel with the resume handshake below (not after its reply).
    unawaited(activityUnreadIfBound?.refreshOnResume());
    resumes.value++;
    final now = DateTime.now();
    final heartbeat = _lastHeartbeat, inbound = _lastServerEvent;
    final silent =
        heartbeat != null &&
        inbound != null &&
        now.difference(heartbeat) > const Duration(seconds: 90) &&
        now.difference(inbound) > const Duration(seconds: 120);
    if (!client.connected || silent) {
      client.connect();
    } else {
      unawaited(messages.resumeHistory());
      if (due('gap', freshness: const Duration(seconds: 3))) {
        unawaited(messages.syncVisibleScopes());
      }
    }
    // Returning to the foreground (alt-tab on a desktop does it often): the
    // counts, sidebar and directory read less than 15 s ago are still fresh.
    if (due('unread')) unawaited(directory.refreshUnread());
    if (due('sidebar')) directory.loadSidebar();
    if (entityDirectory.started && due('authors')) {
      entityDirectory.revalidateLive();
    }
    // Another session of this account may have joined or created a server;
    // the server tells only that server's room, so this is the one moment the
    // directory is re-read. On a desktop the engine reports window focus as
    // inactive/resumed, so this also runs when the window regains focus.
    if (due('membership', freshness: _membershipResumeFreshness)) {
      unawaited(entries.recoverMembership(coalesce: true));
    }
  }

  void applyMembershipRole(dynamic payload) =>
      _serverDirectory.applyMembershipRole(payload);

  void consumeServerPlanUpdated(dynamic payload) =>
      _serverDirectory.consumeServerPlanUpdated(payload);

  void applyServerAvatar(String serverId, String? avatarUrl) =>
      _serverDirectory.applyServerAvatar(serverId, avatarUrl);

  Future<void> recoverMembership({bool coalesce = false}) =>
      _serverDirectory.recoverMembership(coalesce: coalesce);

  void event(RaftEvent event) {
    if (context.disposed) return;
    ensureSyncIdentity();
    if (!ownsClient &&
        !const {
          'message:new',
          'message:updated',
          'thread:updated',
          'reaction_viewer:updated',
          'channel:removed',
        }.contains(event.name)) {
      return;
    }
    _lastServerEvent = DateTime.now();
    // Presence patches are owned by the entity directory; presentation
    // adapters observe that accepted state; no workspace state changes, so nothing is notified.
    if (presenceEvents.contains(event.name)) return;
    if (event.name == 'connected') {
      connected = true;
      // Source socketBridge reconnectSnapshot: server-level reads only. The
      // channel list, unread counts and the resume/gap sync wait for
      // `rooms:joined`, once the server has joined this socket's rooms.
      _roomsJoinedPending = true;
      _lastHeartbeat = _lastServerEvent;
      // A socket that flaps (a bad network reconnects every few seconds) must
      // not repeat the whole refresh burst each time: what was read less than
      // [_burstFreshness] ago is still fresh, and the resume sync below
      // brings messages up to date.
      if (due('membership')) entries.recoverMembership(coalesce: true);
      if (due('syncFlag')) entries.refreshMessageSyncFlag();
      if (due('sidebar')) directory.loadSidebar();
      // The shared entity directory owns reconnect revalidation for every surface.
    }
    if (event.name == 'rooms:joined') roomsJoined();
    if (event.name == 'heartbeat') {
      final joining = _roomsJoinedPending;
      heartbeat(event.payload);
      // A heartbeat only records liveness; a missed-push gap sync notifies
      // when its rows arrive.
      if (!joining) return;
    }
    if (event.name == 'disconnected' || event.name == 'connection:error') {
      connected = false;
    }
    if (event.name == 'server:membership-removed' &&
        event.payload is Map &&
        event.payload['serverId'] is String) {
      entries.revokeServer(event.payload['serverId']);
      entries.recoverMembership();
    }
    if (event.name == 'connection:error' &&
        event.payload is Map &&
        event.payload['notServerMember'] == true) {
      final id = client.serverId;
      if (id != null) entries.revokeServer(id);
      entries.recoverMembership();
    }
    consumeWorkspaceMemberEvent(
      event,
      client: client,
      entries: entries,
      directory: directory,
    );
    if (event.name == 'channel:members-updated' ||
        event.name == 'channel:authority-updated' ||
        event.name == 'channel:removed') {
      final payload = event.payload;
      final id = payload is Map ? payload['channelId'] ?? payload['id'] : null;
      if (id is! String || id.isEmpty) {
        // Unknown scope: fail closed for every channel.
        messages.invalidateAllChannelReplies();
      } else if (event.name != 'channel:members-updated' ||
          membershipScoped(id)) {
        // Only the named channel's authority may have changed. A public
        // channel's member list never changes who can read it.
        messages.invalidateChannelReplies(id);
      }
    }
    if (event.name == 'channel:updated' ||
        event.name == 'channel:members-updated' ||
        event.name == 'dm:new' ||
        event.name == 'channel:authority-updated') {
      directory.channelRealtime(event.name, event.payload);
    }
    if (event.name == 'pinned:updated') directory.loadSidebar();
    if (event.name == 'thread:updated' && event.payload is Map) {
      messages.consumeThreadUpdate(Map<String, dynamic>.from(event.payload));
    }
    if (event.name == 'notification_prefs:updated') {
      directory.consumeNotificationPrefs(event.payload);
    }
    if (event.name == 'message_display_prefs:updated') {
      directory.consumeMessageDisplayPrefs(event.payload);
    }
    if (event.name == 'server:plan-updated') {
      consumeServerPlanUpdated(event.payload);
    }
    if (!messages.consumeMessageEvent(event)) return;
    if (event.name == 'sync:resume:response' && event.payload is Map) {
      unawaited(
        messages.resumeResponse(
          event.payload as Map,
          refreshUnread: () {
            if (due('unread', freshness: const Duration(seconds: 5))) {
              directory.refreshUnread();
            }
          },
        ),
      );
    }
    if (event.name == 'channel:removed') {
      final p = event.payload;
      if (p is Map && p['channelId'] is String) {
        final id = p['channelId'] as String;
        revokeChannel(id);
        directory.removeChannelRows(id);
        if (channel?.id == id) {
          channel = null;
          messages.closeThread();
        }
      }
    }
    if (event.name == 'read_state:updated' ||
        event.name == 'read_state:updated_bulk') {
      final payload = event.payload;
      if (payload is Map && client.serverId != null && client.user != null) {
        final updates = event.name.endsWith('_bulk')
            ? (payload['scopes'] as List? ?? [])
            : [payload];
        for (final update in updates) {
          if (update is Map) {
            final fact = {...update, 'serverId': payload['serverId']};
            final outcome = readState.consumeUpdate(
              fact,
              serverId: client.serverId!,
              principalId: client.user!.id,
            );
            if (outcome == 'accepted' && fact['scopeId'] is String) {
              directory.projectReadState(fact['scopeId'] as String);
              messages.applyReadStateHint(fact);
            }
          }
        }
      }
      directory.persistReadState();
    }
    if (event.name == 'reaction_viewer:updated' && client.serverId != null) {
      messages.acceptReactionViewer(event.payload, serverId: client.serverId!);
    }
    context.changed();
  }
}
