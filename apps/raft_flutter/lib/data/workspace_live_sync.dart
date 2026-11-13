// The session side of Web store/socketBridge.ts at v1.24.0-source.1 that
// server v1.24 added: incremental sync through GET /sync/changes and the new
// socket events this layer applies itself. Surfaces that show a new event
// (the typing line, a theme, Activity objects) read it with
// `LiveEvent.read` (raft_sync) from the client's event stream.
//
// Sync (Web reconnectSnapshot / recoverLiveSession / handleSyncChanged):
// - The first connect of a server takes no cursor: it reuses the lists the
//   selection read moments ago.
// - A reconnect with a cursor pulls what changed after a 0-2 s delay instead
//   of reading the sidebar order and the channel list again; without one it
//   takes a cursor first, then reads every list after it (a server with
//   `sync_changes_api` off answers 404 and the old reloads run).
// - Returning to the foreground with a cursor pulls too; `sync:changed` (the
//   person's own read / Done / follow changed elsewhere) pulls at once.
// - A dropped cursor reads every list again; the next reconnect takes a new
//   one.
import 'dart:async';
import 'dart:math';

import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'actor_directory.dart';
import 'channel_access_loss.dart';
import 'workspace_entity_directory.dart';
import 'workspace_session.dart';

class WorkspaceLiveSync {
  WorkspaceLiveSync._(this.client);
  final RaftClient client;

  static final _of = Expando<WorkspaceLiveSync>('workspace live sync');

  /// The live sync of the session that owns [client].
  static WorkspaceLiveSync of(RaftClient client) =>
      _of[client] ??= WorkspaceLiveSync._(client);

  /// Web SYNC_PULL_JITTER_MS: reconnects reach many clients at once.
  static const pullJitter = Duration(seconds: 2);
  static Random random = Random();

  /// The followed-thread list's reload (its owner registers it).
  Future<void> Function()? refreshFollowedThreads;

  SyncChangesSession? _sync;
  String? _scope;
  final _connected = <String>{};
  Timer? _pullTimer;

  /// This reconnect (or resume) is served by sync: the sidebar order and the
  /// channel list come through GET /sync/changes, not a full read.
  bool bySync = false;

  SyncChangesSession? get syncSession => _sync;

  String? _currentScope() {
    final user = client.user?.id, server = client.serverId;
    return user == null || server == null
        ? null
        : '${client.origin}|${client.generation}|$user|$server';
  }

  void _synchronize(WorkspaceSession s) {
    final scope = _currentScope();
    if (scope == _scope) return;
    _scope = scope;
    _disposeSync();
    bySync = false;
    // A server switch or sign-out: holes of the old server fill nothing.
    LiveGapFill.of(s.ledger).clear();
  }

  void _disposeSync() {
    _pullTimer?.cancel();
    _pullTimer = null;
    _sync?.dispose();
    _sync = null;
  }

  /// Every frame of the owning session, before its own handling.
  void receive(WorkspaceSession s, RaftEvent event) {
    _synchronize(s);
    final scope = _scope;
    if (scope == null) return;
    switch (event.name) {
      case 'connected':
        _onConnected(s, scope);
      case 'channel:updated':
        // Web channelRealtimeSync: re-added to a channel it had lost.
        final p = event.payload;
        final row = p is Map && p.containsKey('channel') ? p['channel'] : p;
        if (row is Map &&
            row['joined'] == true &&
            row['id'] is String &&
            row['name'] is String) {
          ChannelAccessLoss.of(client).clear(row['id'] as String);
        }
    }
    switch (LiveEvent.read(event.name, event.payload)) {
      case SyncChangedEvent():
        final sync = _sync;
        if (sync != null && sync.hasCursor) _schedulePull(sync, Duration.zero);
      case ActorUpdatedEvent update:
        ActorDirectory.of(client).applyUpdated(update);
      case UserProfileUpdatedEvent update:
        // The member row is the entity directory's; the signed-in person's
        // own record follows here, so their other devices update.
        final user = client.user;
        if (user != null &&
            user.id == update.userId &&
            update.profile.entries.any((e) => user.json[e.key] != e.value)) {
          client.user = RaftRecord({...user.json, ...update.profile});
          s.context.changed();
        }
      case AppearanceUpdatedEvent update:
        s.patchServerRows(
          (row) => row.id == update.serverId
              ? RaftRecord({...row.json, ...update.patch})
              : row,
        );
        s.context.changed();
      case ActivityChangedEvent update when update.serverId == client.serverId:
        // Object rows changed for this person: Activity reads again.
        unawaited(s.activityUnreadIfBound?.refresh());
      default:
    }
  }

  void _onConnected(WorkspaceSession s, String scope) {
    bySync = false;
    if (_connected.add(scope)) return;
    final sync = _ensureSync(s);
    bySync = true;
    if (sync.hasCursor) {
      _schedulePull(sync, pullJitter);
      return;
    }
    unawaited(
      sync.start().then((ok) {
        if (!identical(_sync, sync)) return;
        if (ok) {
          sync.resnapshotAll(SyncFetchReason.reconnect);
        } else {
          // No cursor (e.g. `sync_changes_api` off): the two reads this
          // reconnect skipped run as before; the rest already did.
          if (s.due('sidebar')) s.directory.loadSidebar();
          if (s.due('channels')) {
            unawaited(s.directory.refreshChannels(quietErrors: true));
          }
        }
      }),
    );
  }

  /// Returning to the foreground: true when a sync pull stands in for the
  /// sidebar order read.
  bool resumed(WorkspaceSession s) {
    _synchronize(s);
    final sync = _sync;
    if (sync == null || !sync.hasCursor) return false;
    _schedulePull(sync, pullJitter);
    return true;
  }

  void _schedulePull(SyncChangesSession sync, Duration max) {
    if (_pullTimer != null) return;
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot 0-2 s spread of a reconnect's sync pull (Web scheduleSyncPull); cancelled on scope change.
    _pullTimer = Timer(max * random.nextDouble(), () {
      _pullTimer = null;
      if (identical(_sync, sync)) unawaited(sync.pull());
    });
  }

  /// Web onCursorDropped: read every list again.
  void _reloadAll(WorkspaceSession s) {
    s.directory.loadSidebar();
    unawaited(s.directory.refreshChannels(quietErrors: true));
    if (s.entityDirectory.started) s.entityDirectory.revalidateLive();
  }

  SyncChangesSession _ensureSync(WorkspaceSession s) {
    final current = _sync;
    final server = client.serverId!;
    if (current != null && current.serverId == server) return current;
    current?.dispose();
    final entities = s.entityDirectory;
    Future<void> refresh(WorkspaceEntityKind kind) =>
        entities.started ? entities.refresh(kind) : Future.value();
    return _sync = SyncChangesSession(
      serverId: server,
      fetch: (since) => client
          .getForServer(server, '/sync/changes', query: {'since': ?since})
          .timeout(syncChangesTimeout),
      isTransient: isTransientSyncError,
      loaders: {
        SyncListSnapshot.channels: SyncSnapshotLoader(
          load: (_) => s.directory.refreshChannels(quietErrors: true),
        ),
        // The rows carry the member count; open rosters re-read on their
        // own `channel:members-updated`.
        SyncListSnapshot.channelMembers: SyncSnapshotLoader(
          load: (_) => s.directory.refreshChannels(quietErrors: true),
        ),
        SyncListSnapshot.serverMembers: SyncSnapshotLoader(
          load: (_) => refresh(WorkspaceEntityKind.members),
        ),
        SyncListSnapshot.agents: SyncSnapshotLoader(
          load: (_) => refresh(WorkspaceEntityKind.agents),
        ),
        SyncListSnapshot.machines: SyncSnapshotLoader(
          load: (_) => refresh(WorkspaceEntityKind.computers),
        ),
        SyncListSnapshot.inbox: SyncSnapshotLoader(
          load: (_) => s.activityUnreadIfBound?.refresh(),
        ),
        SyncListSnapshot.unread: SyncSnapshotLoader(
          load: (_) => s.directory.refreshUnread(),
        ),
        SyncListSnapshot.followedThreads: SyncSnapshotLoader(
          load: (_) => refreshFollowedThreads?.call(),
        ),
        SyncListSnapshot.sidebarOrder: SyncSnapshotLoader(
          load: (_) => s.directory.loadSidebar(),
        ),
        SyncListSnapshot.serverOrder: SyncSnapshotLoader(
          load: (_) =>
              s.entries.recoverMembership(coalesce: true, quietErrors: true),
        ),
      },
      refreshChannel: s.directory.refreshChannel,
      notifyChannelMembers: (id) => s.directory.channelRealtime(
        'channel:members-updated',
        {'channelId': id},
      ),
      // RFC 082 §4.4: a message changed in place while away; same path as
      // its live `message:updated`.
      applyMessage: (row) {
        if (s.messages.consumeMessageEvent(RaftEvent('message:updated', row))) {
          s.context.changed();
        }
      },
      channelScopeChanged: (id, op) =>
          unawaited(ChannelAccessLoss.of(client).applyScopeChange(id, op)),
      onCursorDropped: () => _reloadAll(s),
    );
  }
}

/// The contract's transient pull failures: no answer (network, the 5 s
/// timeout), 5xx, 408, 429. A malformed answer or any other status drops the
/// cursor.
bool isTransientSyncError(Object error) {
  if (error is TimeoutException) return true;
  if (error is FormatException) return false;
  if (error is! RaftApiException) return true;
  if (error.staleScope) return true;
  final status = error.status;
  return status == null || status >= 500 || status == 408 || status == 429;
}
