import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'attachment_media.dart';
import 'channel_revocation.dart';
import 'followed_threads_store.dart';
import 'message_translation_store.dart';
import 'resource_snapshot_cache.dart';
import 'source_activity_unread_store.dart';
import 'workspace_composer.dart';
import 'workspace_device_store.dart';
import 'workspace_entity_directory.dart';
import 'workspace_message_windows.dart';

/// Existing domain owners and the receiver's remaining presentation hooks.
/// Getters stay lazy and keep each presentation's injection and source rules.
abstract interface class SessionScopeBinding {
  RaftClient get client;
  List<RaftRecord> get servers;
  WorkspaceComposer get composer;
  WorkspaceDeviceStore get deviceStore;
  WorkspaceMessageWindows get messageWindows;
  AttachmentMedia get attachmentMedia;
  ReadStateLedger get readState;
  ResourceSnapshotCache get resourceSnapshots;
  ReactionViewerLedger get reactionViewer;
  MessageSync get messageSync;
  ThreadRepliesSync get threadRepliesSync;
  NotificationPrefsSync get notificationPrefsSync;
  SourceActivityUnreadStore get activityUnread;
  WorkspaceEntityDirectory get entityDirectory;
  MessageTranslationStore get translations;
  FollowedThreadsStore get followedThreads;
  Future<void> Function(String, String, String, String?)?
  get discardSharedScope;

  void resetServerProjection();
  void clearSessionPrefetch();
  void closeRevokedServerProjection();
  ChannelRevocationPlan planChannelRevocation(String id);
  void clearRevokedChannelProjection(String scope);
  void removeRevokedParentSummary(dynamic messageId);
  void closeRevokedChannelProjection(ChannelRevocation event);
  void persistSessionReadState();
  void beginServerSelectionProjection(RaftRecord next);
  void resetServerSelectionState();
  Future<void> refreshMessageSyncFlag();
  Future<void> loadSidebar();
  void notifyListeners();
}

/// Fixed synchronous order; later domain slices replace their binding here.
enum ServerResetStage {
  projection,
  windows,
  readState,
  resources,
  prefetch,
  reactions,
  messages,
}

enum ServerRevocationStage {
  sharing,
  media,
  activeSelection,
  device,
  directory,
}

enum ChannelRevocationStage { scopes, parents, projection, readState, device }

enum ServerSelectionStage {
  initialProjection,
  domains,
  composer,
  windows,
  background,
  realtime,
}

/// Futures start in the original order; the caller retains both await points.
class ServerSelection {
  ServerSelection(this.server);
  final RaftRecord server;
  late final Future<void> restoredEntities, restoredTranslations;
}

class ServerReset {
  const ServerReset(this.serverId);
  final String? serverId;
}

/// The identity used by queued work stays captured even if a callback switches.
class ServerRevocation {
  const ServerRevocation({
    required this.origin,
    required this.principal,
    required this.serverId,
    required this.generation,
  });
  final String origin, principal, serverId;
  final int generation;
}

/// Receiver-local revocation facts and ordered, synchronous domain transitions.
///
/// Shared clients may have independent editors. Each controller binds its own
/// scope to the domain objects it already owns or borrows; no global broadcast
/// or new socket subscription is created. Dispatch never awaits, catches a
/// listener exception, defers work, or coalesces separate commands.
class SessionScope {
  SessionScope(this.binding, {required bool ownsMedia}) {
    onReset(
      ServerResetStage.projection,
      (_) => binding.resetServerProjection(),
    );
    onReset(ServerResetStage.windows, (event) {
      binding.messageWindows.channelGeneration++;
      binding.messageWindows.threadGeneration++;
      binding.messageWindows.switchServer(event.serverId);
    });
    onReset(ServerResetStage.readState, (_) => binding.readState.reset());
    onReset(
      ServerResetStage.resources,
      (_) => binding.resourceSnapshots.clear(),
    );
    onReset(ServerResetStage.prefetch, (_) => binding.clearSessionPrefetch());
    onReset(ServerResetStage.reactions, (_) => binding.reactionViewer.reset());
    onReset(ServerResetStage.messages, (_) {
      binding.messageSync.reset();
    });

    onServerRevoked(ServerRevocationStage.sharing, (event) {
      unawaited(
        binding.discardSharedScope?.call(
          event.origin,
          event.principal,
          event.serverId,
          null,
        ),
      );
    });
    onServerRevoked(ServerRevocationStage.media, (event) {
      if (ownsMedia) {
        binding.attachmentMedia.purgeIdentity(
          event.origin,
          event.principal,
          event.serverId,
        );
      }
    });
    onServerRevoked(ServerRevocationStage.activeSelection, (event) {
      // Check after the sharing/media callbacks, exactly as the old entrypoint.
      if (binding.client.serverId != event.serverId) return;
      binding.composer.clearOwnedBy(binding);
      resetServer(null);
      binding.closeRevokedServerProjection();
    });
    onServerRevoked(ServerRevocationStage.device, (event) {
      binding.deviceStore.revokeServer(
        event.origin,
        event.principal,
        event.serverId,
      );
    });
    onServerRevoked(ServerRevocationStage.directory, (_) {
      binding.deviceStore.write(
        'servers',
        '',
        binding.servers.map((s) => s.json).toList(),
        server: '',
      );
      binding.notifyListeners();
    });

    onChannelRevoked(ChannelRevocationStage.scopes, (event) {
      for (final scope in event.plan.scopes) {
        revokedChannels.add(scope);
        if (ownsMedia) binding.attachmentMedia.revokeChannel(scope);
        binding.messageWindows.revokeChannel(scope);
        binding.messageSync.revokeChannel(scope);
        binding.threadRepliesSync.revokeChannel(scope);
        binding.notificationPrefsSync.revokeChannel(scope);
        binding.messageWindows.discardWindow(scope);
        binding.clearRevokedChannelProjection(scope);
        binding.messageWindows.revokeThreads(scope);
        if (event.serverId != null && event.principal != null) {
          binding.readState.revoke(event.serverId!, event.principal!, scope);
        }
        binding.composer.retireScope(
          scope,
          keepFiles: event.keepShared && scope == event.plan.channelId,
        );
        if (event.keepShared && scope == event.plan.channelId) continue;
        binding.composer.attempts.remove(scope);
      }
    });
    onChannelRevoked(ChannelRevocationStage.parents, (event) {
      for (final messageId in event.plan.messageIds) {
        final scope = 'thread:$messageId';
        binding.composer.attempts.remove(scope);
        binding.composer.retireScope(scope);
        binding.reactionViewer.remove(messageId);
        binding.removeRevokedParentSummary(messageId);
      }
    });
    onChannelRevoked(
      ChannelRevocationStage.projection,
      binding.closeRevokedChannelProjection,
    );
    onChannelRevoked(
      ChannelRevocationStage.readState,
      (_) => binding.persistSessionReadState(),
    );
    onChannelRevoked(ChannelRevocationStage.device, (event) {
      if (event.principal == null || event.serverId == null) return;
      // Retirement and thread closure have finished. Keep authored text only;
      // the device owner retains the existing shared-draft exception.
      final keptDrafts = {
        for (final scope in event.plan.draftScopes)
          scope: binding.composer.draftRecord(scope, includeShareTokens: false),
      };
      binding.deviceStore.revokeChannel(
        origin: event.origin,
        principal: event.principal!,
        serverId: event.serverId!,
        channelId: event.plan.channelId,
        scopes: event.plan.scopes,
        keptDrafts: keptDrafts,
        keepShared: event.keepShared,
      );
    });

    onServerSelected(
      ServerSelectionStage.initialProjection,
      (event) => binding.beginServerSelectionProjection(event.server),
    );
    onServerSelected(ServerSelectionStage.domains, (event) {
      binding.activityUnread.start();
      binding.entityDirectory.synchronize();
      event.restoredEntities = binding.entityDirectory.restored;
      event.restoredTranslations = binding.translations.restore();
      unawaited(binding.entityDirectory.preload());
      binding.followedThreads.start();
    });
    onServerSelected(
      ServerSelectionStage.composer,
      (_) => binding.composer.clearOwnedBy(binding),
    );
    onServerSelected(
      ServerSelectionStage.windows,
      (event) => resetServer(event.server.id),
    );
    onServerSelected(ServerSelectionStage.background, (_) {
      binding.refreshMessageSyncFlag();
      binding.loadSidebar();
    });
    onServerSelected(ServerSelectionStage.realtime, (_) {
      revokedChannels.clear();
      binding.resetServerSelectionState();
    });
  }

  final SessionScopeBinding binding;
  final revokedChannels = <String>{}, revokedServers = <String>{};
  final _resetHandlers = <ServerResetStage, List<void Function(ServerReset)>>{};
  final _revokeHandlers =
      <ServerRevocationStage, List<void Function(ServerRevocation)>>{};
  final _channelHandlers =
      <ChannelRevocationStage, List<void Function(ChannelRevocation)>>{};
  final _selectionHandlers =
      <ServerSelectionStage, List<void Function(ServerSelection)>>{};
  bool _closed = false;

  /// Register in a named phase. Removal affects subsequent dispatches.
  void Function() onReset(
    ServerResetStage stage,
    void Function(ServerReset) run,
  ) {
    if (_closed) throw StateError('Session scope is disposed.');
    final handlers = _resetHandlers.putIfAbsent(stage, () => []);
    handlers.add(run);
    return () => handlers.remove(run);
  }

  void Function() onServerRevoked(
    ServerRevocationStage stage,
    void Function(ServerRevocation) run,
  ) {
    if (_closed) throw StateError('Session scope is disposed.');
    final handlers = _revokeHandlers.putIfAbsent(stage, () => []);
    handlers.add(run);
    return () => handlers.remove(run);
  }

  void Function() onChannelRevoked(
    ChannelRevocationStage stage,
    void Function(ChannelRevocation) run,
  ) {
    if (_closed) throw StateError('Session scope is disposed.');
    final handlers = _channelHandlers.putIfAbsent(stage, () => []);
    handlers.add(run);
    return () => handlers.remove(run);
  }

  void Function() onServerSelected(
    ServerSelectionStage stage,
    void Function(ServerSelection) run,
  ) {
    if (_closed) throw StateError('Session scope is disposed.');
    final handlers = _selectionHandlers.putIfAbsent(stage, () => []);
    handlers.add(run);
    return () => handlers.remove(run);
  }

  ServerSelection selectServer(RaftRecord next) {
    final event = ServerSelection(next);
    final handlers = [
      for (final stage in ServerSelectionStage.values)
        ...?_selectionHandlers[stage],
    ];
    for (final run in handlers) {
      run(event);
    }
    return event;
  }

  /// Retire accepted windows and projections in the current call stack.
  void resetServer(String? id) {
    final event = ServerReset(id);
    final handlers = [
      for (final stage in ServerResetStage.values) ...?_resetHandlers[stage],
    ];
    for (final run in handlers) {
      run(event);
    }
  }

  void revokeServer(String id) {
    final principal = binding.client.user?.id;
    if (principal == null) return;
    revokedServers.add(id);
    binding.servers.removeWhere((s) => s.id == id);
    final event = ServerRevocation(
      origin: binding.client.origin,
      principal: principal,
      serverId: id,
      generation: binding.client.generation,
    );
    final handlers = [
      for (final stage in ServerRevocationStage.values)
        ...?_revokeHandlers[stage],
    ];
    for (final run in handlers) {
      run(event);
    }
  }

  void revokeChannel(String id) {
    final origin = binding.client.origin,
        principal = binding.client.user?.id,
        serverId = binding.client.serverId,
        generation = binding.client.generation;
    final holds = binding.composer.uploads.holds,
        keepShared = holds.containsKey(id);
    if (keepShared) {
      holds[id] = 'This conversation is no longer available. Your draft and files are kept.';
    }
    if (!keepShared && principal != null && serverId != null) {
      unawaited(
        binding.discardSharedScope?.call(origin, principal, serverId, id),
      );
    }
    // Sharing callbacks still run before discovery, as in the original entry.
    final event = ChannelRevocation(
      origin: origin,
      principal: principal,
      serverId: serverId,
      generation: generation,
      keepShared: keepShared,
      plan: binding.planChannelRevocation(id),
    );
    final handlers = [
      for (final stage in ChannelRevocationStage.values)
        ...?_channelHandlers[stage],
    ];
    for (final run in handlers) {
      run(event);
    }
  }

  /// Only this receiver's bindings are detached; borrowed owners stay alive.
  void dispose() {
    _closed = true;
    _resetHandlers.clear();
    _revokeHandlers.clear();
    _channelHandlers.clear();
    _selectionHandlers.clear();
  }
}
