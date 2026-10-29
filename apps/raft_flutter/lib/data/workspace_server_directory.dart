import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'burst_reads.dart';
import 'user_error.dart';
import 'workspace_domain_ports.dart';
import 'workspace_session_bindings.dart';
import 'workspace_session_context.dart';

/// Receiver-local server directory, membership and ordered server hydration.
/// Connection liveness and feature evaluation remain separate session owners.
class WorkspaceServerDirectory {
  WorkspaceServerDirectory({
    required this.context,
    required this.transport,
    required this.device,
    required this.entries,
    required this.directory,
    required this.presentation,
    required this.messages,
    required this.drafts,
    required this.revocations,
    required BurstReads burstReads,
    required this.clientOwnership,
    required this.ensureIdentity,
    required this.quietFailure,
    required this.staleScope,
  }) : _burstAt = burstReads;
  final WorkspaceSessionContext context;
  final WorkspaceTransportPort transport;
  final WorkspaceDevicePort device;
  final WorkspaceSessionEntries entries;
  final WorkspaceSessionChannels directory;
  final WorkspaceSessionPresentation presentation;
  final WorkspaceSessionMessages messages;
  final WorkspaceSessionDrafts drafts;
  final WorkspaceSessionRevocations revocations;
  final BurstReads _burstAt;
  final bool Function() clientOwnership;
  bool get ownsClient => clientOwnership();
  final VoidCallback ensureIdentity;
  final bool Function(Object) quietFailure, staleScope;
  List<RaftRecord> servers = [];
  RaftRecord? server;
  int _membershipRevision = 0, _membershipRequest = 0;
  int planRevision = 0;

  RaftClient get client => transport.client;
  ReadStateLedger get readState => directory.readState;
  List<RaftChannel> get channels => directory.channels;
  set channels(List<RaftChannel> value) => directory.assignChannels(value);
  List<RaftChannel> get dms => directory.dms;
  set dms(List<RaftChannel> value) => directory.assignDms(value);
  set unread(Map<String, int> value) => directory.assignUnread(value);
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
  String syncIdentity() => context.syncIdentity();
  Set<String> get revokedServers => revocations.revokedServers;
  void revokeChannel(String id) => context.transitions.revokeChannel(id);
  void patchServerRows(RaftRecord Function(RaftRecord) patch) {
    servers = servers.map(patch).toList();
    if (server != null) server = patch(server!);
  }

  bool can(String capability, {RaftChannel? resource}) => raftCan(
    server?.string('role'),
    capability,
    channelCapabilities: resource?.json['channelCapabilities'] is Map
        ? Map<String, dynamic>.from(resource!.json['channelCapabilities'])
        : null,
  );

  Future<bool> loadServerDirectory({
    bool cachedFirst = false,
    void Function()? onCacheMiss,
  }) => _burstAt.directoryRead(() async {
    if (!ownsClient) {
      throw StateError('A borrowed editor cannot load the server directory.');
    }
    final generation = client.generation,
        principal = client.user?.id,
        request = ++_membershipRequest,
        revision = _membershipRevision;
    bool current() =>
        !context.disposed &&
        generation == client.generation &&
        principal == client.user?.id &&
        request == _membershipRequest &&
        revision == _membershipRevision;
    if (principal == null) return false;
    if (client.restoredOffline || cachedFirst) {
      final cached = await device.read('servers', '', server: '');
      if (!current()) return false;
      if (cached is List && cached.isNotEmpty) {
        servers = cached
            .map((row) => RaftRecord(Map<String, dynamic>.from(row)))
            .where((server) => !revokedServers.contains(server.id))
            .toList();
        context.changed();
        if (cachedFirst) unawaited(entries.revalidateServerDirectory());
        return true;
      }
    }
    onCacheMiss?.call();
    final accepted = await client.servers();
    if (!current()) return false;
    revokedServers.removeAll(accepted.map((server) => server.id));
    servers = accepted;
    await device.save(
      'servers',
      '',
      accepted.map((server) => server.json).toList(),
      server: '',
    );
    if (!current()) return false;
    context.changed();
    return true;
  });

  Future<List<RaftChannel>?> cachedChannelDirectory(String serverId) async {
    if (context.disposed || revokedServers.contains(serverId)) return null;
    final cached = await device.read('channels', '', server: serverId);
    if (cached is! Map ||
        context.disposed ||
        revokedServers.contains(serverId)) {
      return null;
    }
    try {
      return [
        for (final key in const ['channels', 'dms'])
          for (final row in cached[key] as List)
            RaftChannel(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<void> revalidateServerDirectory() => _burstAt.directoryRead(() async {
    final principal = client.user?.id,
        request = ++_membershipRequest,
        revision = _membershipRevision;
    bool current() =>
        !context.disposed &&
        principal != null &&
        principal == client.user?.id &&
        request == _membershipRequest &&
        revision == _membershipRevision;
    await client.sessionValidated;
    if (!current() || client.restoredOffline) return;
    final List<RaftRecord> accepted;
    try {
      accepted = await client.accountServers();
    } catch (_) {
      return;
    }
    if (!current()) return;
    final ids = {for (final s in accepted) s.id};
    for (final held in [...servers]) {
      if (!ids.contains(held.id)) entries.revokeServer(held.id);
    }
    final selected = server;
    if (selected != null && !ids.contains(selected.id)) {
      entries.revokeServer(selected.id);
    }
    revokedServers.removeAll(ids);
    servers = accepted;
    device.save(
      'servers',
      '',
      accepted.map((s) => s.json).toList(),
      server: '',
    );
    final held = server;
    final fresh = held == null
        ? null
        : accepted.where((s) => s.id == held.id).firstOrNull;
    if (held != null && fresh != null) {
      final role = fresh.string('role');
      if (role != held.string('role')) {
        entries.applyMembershipRole({
          'userId': principal,
          'serverId': held.id,
          'role': role,
        });
        server = fresh;
        context.changed();
        await directory.refreshChannels();
        final open = channel;
        if (!context.disposed && open != null && server?.id == held.id) {
          unawaited(
            messages.selectChannel(
              open,
              navigate: false,
              preserveThread: true,
              autoRead: false,
            ),
          );
        }
        return;
      }
      if (jsonEncode(fresh.json) != jsonEncode(held.json)) server = fresh;
    }
    context.changed();
  });

  Future<void> bootstrap() async {
    final source = entries.sessionSource;
    if (source != null) {
      return source.bootstrap();
    }
    if (!ownsClient) {
      throw StateError('A borrowed editor cannot bootstrap a session.');
    }
    loading = true;
    error = null;
    context.changed();
    try {
      final cached = await device.read('servers', '', server: '');
      if (cached is List) {
        servers = cached
            .map((e) => RaftRecord(Map<String, dynamic>.from(e)))
            .where((s) => !revokedServers.contains(s.id))
            .toList();
      }
      context.changed();
      if (servers.isNotEmpty && client.restoredOffline) {
        await entries.selectServer(servers.first);
        return;
      }
      servers = await client.servers();
      revokedServers.removeAll(servers.map((s) => s.id));
      await device.save(
        'servers',
        '',
        servers.map((s) => s.json).toList(),
        server: '',
      );
      if (servers.isNotEmpty) await entries.selectServer(servers.first);
    } catch (e) {
      if (!staleScope(e)) error = userErrorText(e, where: 'load servers');
    } finally {
      loading = false;
      context.changed();
    }
  }

  Future<void> selectServer(
    RaftRecord next, {
    void Function()? onHydrated,
    void Function()? onCacheMiss,
  }) async {
    // A live mobile page presents the source's session; the source selects.
    final source = entries.sessionSource;
    if (source != null) {
      return source.selectServer(
        next,
        onHydrated: onHydrated,
        onCacheMiss: onCacheMiss,
      );
    }
    if (!ownsClient) {
      throw StateError('A borrowed editor cannot select a server.');
    }
    if (revokedServers.contains(next.id)) return;
    final selection = context.transitions.selectServer(next);
    final selectionAtStart = channelGeneration,
        threadAtStart = threadGeneration,
        navigationAtStart = navigationRevision;
    context.changed();
    final generation = client.generation;
    final replyIdentity = syncIdentity();
    final cached = await device.read('channels', '');
    await selection.restoredEntities;
    await selection.restoredTranslations;
    if (generation != client.generation) return;
    if (cached is Map) {
      channels = (cached['channels'] as List)
          .map((e) => RaftChannel(Map<String, dynamic>.from(e)))
          .toList();
      dms = (cached['dms'] as List)
          .map((e) => RaftChannel(Map<String, dynamic>.from(e)))
          .toList();
      final last = await device.read('selection', '');
      final initial =
          [...channels, ...dms].where((c) => c.id == last).firstOrNull ??
          channels.where((c) => c.joined && !c.archived).firstOrNull;
      if (initial != null) {
        channel = initial;
        // A principal/role change before this point retires its summaries.
        final replyAuthority = replyIdentity == syncIdentity()
            ? messages.replyToken(initial.id)
            : '';
        final request = messages.hydrationRequest(
          allowed: () => generation == client.generation,
        );
        final page = await device.read('window', initial.id);
        if (generation != client.generation) return;
        if (messages.restoreCachedTail(
          initial.id,
          page,
          request,
          replyAuthority: replyAuthority,
          replace: true,
        )) {
          await drafts.restoreDraft(initial.id);
        }
      }
      context.changed();
    }
    final cachedFrontiers = await device.read('read-frontiers', '');
    if (generation != client.generation) return;
    readState.restore(
      cachedFrontiers,
      serverId: next.id,
      principalId: client.user!.id,
    );
    final cachedUnread = await device.read('unread', '');
    if (generation != client.generation) return;
    if (cachedUnread is Map) {
      unread = {
        for (final entry in cachedUnread.entries)
          if (entry.value is int && entry.value >= 0)
            '${entry.key}': entry.value,
      };
    }
    context.changed();
    if (cached is Map) {
      onHydrated?.call();
    } else {
      onCacheMiss?.call();
    }
    final readGeneration = readState.generation;
    List<List<RaftChannel>> values;
    try {
      values = await Future.wait([
        client.channels(),
        client.channels(dm: true),
      ]);
    } catch (e) {
      if (isNotServerMember(e) && generation == client.generation) {
        entries.revokeServer(next.id);
        await entries.recoverMembership();
        loading = false;
        context.changed();
        return;
      }
      if (generation == client.generation) {
        error = userErrorText(e, where: 'load channels');
        loading = false;
        context.changed();
      }
      return;
    }
    if (generation != client.generation) return;
    final accessible = [...values[0], ...values[1]].map((c) => c.id).toSet();
    for (final old in [...channels, ...dms]) {
      if (!accessible.contains(old.id)) revokeChannel(old.id);
    }
    channels = values[0];
    dms = values[1];
    // A cached selection adopts its fresh row. When the fresh row changes
    // the window authority, the cached rows are not shown under it: the
    // selection is revalidated below (or by the newer selection in flight).
    final held = channel;
    final freshHeld = held == null
        ? null
        : [...channels, ...dms].where((c) => c.id == held.id).firstOrNull;
    var heldAuthorityChanged = false;
    if (held != null && freshHeld != null && !identical(held, freshHeld)) {
      final before = messages.windowAuthority();
      channel = freshHeld;
      heldAuthorityChanged = before != messages.windowAuthority();
    }
    // The cache-painted workspace is already on screen: show the fresh lists
    // (and any revocation) now, not after the unread read below.
    context.changed();
    await device.save('channels', '', {
      'channels': channels.map((c) => c.json).toList(),
      'dms': dms.map((c) => c.json).toList(),
    });
    // The cache write yields: a sign-out meanwhile clears `client.user`.
    if (generation != client.generation) return;
    final principalId = client.user?.id;
    if (principalId == null) return;
    for (final c in [...channels, ...dms]) {
      readState.consumeSnapshot(
        c.json['readState'],
        serverId: next.id,
        principalId: principalId,
        scopeId: c.id,
        generationAtRequest: readGeneration,
      );
    }
    client.connect();
    await directory.refreshUnread();
    final joined = channels.where((c) => c.joined && !c.archived).toList();
    if (joined.isNotEmpty &&
        selectionAtStart == channelGeneration &&
        threadAtStart == threadGeneration) {
      final selected =
          joined.where((c) => c.id == channel?.id).firstOrNull ?? joined.first;
      if (mobileNavigation && section == 'home') {
        channel = selected;
        await drafts.restoreDraft(selected.id);
      } else {
        // A location the app root applied over the cache-painted workspace
        // (e.g. a remembered non-chat page) keeps its section.
        await messages.selectChannel(
          selected,
          navigate: navigationAtStart == navigationRevision,
        );
      }
    } else if (heldAuthorityChanged &&
        channel != null &&
        identical(channel, freshHeld)) {
      await messages.selectChannel(
        channel!,
        navigate: false,
        preserveThread: true,
        autoRead: false,
      );
    }
    context.changed();
  }

  void applyMembershipRole(dynamic payload) {
    if (payload is! Map ||
        payload['userId'] != client.user?.id ||
        payload['serverId'] is! String ||
        payload['role'] is! String) {
      return;
    }
    final id = payload['serverId'] as String, role = payload['role'] as String;
    if (!servers.any((s) => s.id == id) && server?.id != id) return;
    _membershipRevision++;
    _membershipRequest++;
    servers = [
      for (final s in servers)
        s.id == id ? RaftRecord({...s.json, 'role': role}) : s,
    ];
    if (server?.id == id) {
      if (server?.string('role') != role) {
        messages.invalidateAllReplyAuthority();
      }
      server = RaftRecord({...server!.json, 'role': role});
      ensureIdentity();
      entries.refreshMessageSyncFlag();
      if (!canVisitSection(section)) section = 'chat';
    }
    device.save('servers', '', servers.map((s) => s.json).toList(), server: '');
    context.changed();
  }

  void consumeServerPlanUpdated(dynamic payload) {
    final id = payload is Map ? payload['serverId'] : null;
    final plan = payload is Map ? payload['plan'] : null;
    if (id is String && id.isNotEmpty && plan is String) {
      RaftRecord patch(RaftRecord value) =>
          value.id == id ? RaftRecord({...value.json, 'plan': plan}) : value;
      servers = servers.map(patch).toList();
      if (server != null) server = patch(server!);
      device.save(
        'servers',
        '',
        servers.map((s) => s.json).toList(),
        server: '',
      );
    } else {
      unawaited(entries.recoverMembership());
    }
    planRevision++;
    context.changed();
  }

  void applyServerAvatar(String serverId, String? avatarUrl) {
    if (entries.sessionSource != null) {
      unawaited(entries.recoverMembership());
      return;
    }
    if (context.disposed) return;
    RaftRecord patch(RaftRecord value) => value.id == serverId
        ? RaftRecord({...value.json, 'avatarUrl': avatarUrl})
        : value;
    servers = servers.map(patch).toList();
    if (server != null) server = patch(server!);
    device.save('servers', '', servers.map((s) => s.json).toList(), server: '');
    context.changed();
  }

  Future<void> recoverMembership({bool coalesce = false}) async {
    if (entries.sessionSource != null) {
      return entries.sessionSource!.recoverMembership();
    }
    if (!ownsClient || coalesce && _burstAt.directoryReading) return;
    final generation = client.generation,
        request = ++_membershipRequest,
        revision = _membershipRevision;
    try {
      final current = await client.servers();
      if (generation != client.generation ||
          context.disposed ||
          request != _membershipRequest ||
          revision != _membershipRevision) {
        return;
      }
      revokedServers.removeAll(current.map((s) => s.id));
      servers = current;
      await device.save(
        'servers',
        '',
        current.map((s) => s.json).toList(),
        server: '',
      );
      if (server != null && !current.any((s) => s.id == server!.id)) {
        entries.revokeServer(server!.id);
        await entries.flushCache();
      }
      if (server == null && current.isNotEmpty) {
        await entries.selectServer(current.first);
      }
      if (server != null) {
        server = current.where((s) => s.id == server!.id).firstOrNull;
        if (!canVisitSection(section)) section = 'chat';
      }
      context.changed();
    } catch (e) {
      // A refresh superseded by a newer one, or outrun by a server switch
      // (deleting the open server selects the next), is not a failure.
      if (!context.disposed &&
          !quietFailure(e) &&
          generation == client.generation &&
          request == _membershipRequest) {
        // ignore: raft_lints/avoid_imperative_notice_state -- Raised only for the latest membership request on the current client generation and not for rate-limited or stale-scope failures.
        presentation.setError(userErrorText(e, where: 'refresh servers'));
      }
    }
  }

  static bool isNotServerMember(Object failure) =>
      failure is RaftApiException &&
      failure.status == 403 &&
      failure.message == 'Not a member of this server';
}
