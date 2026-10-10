import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'message_task_cache.dart';
import 'panel_caches.dart';
import 'source_channel_files_store.dart';
import 'reaction_toggle.dart';
import 'workspace_cache.dart';
import 'resource_snapshot_cache.dart';
import 'user_activity.dart';
import 'workspace_entity_directory.dart';
import 'followed_threads_store.dart';
import 'raft_location.dart';
import 'raft_navigation_history.dart';
import 'workspace_navigation.dart';
import 'message_window_snapshot.dart';
import 'attachment_image_repository.dart';

class WorkspaceAttachmentImageLease {
  WorkspaceAttachmentImageLease(this.lease, this._releaseAuthority);
  final AttachmentImageLease lease;
  final VoidCallback _releaseAuthority;
  bool _released = false;
  void release({bool discard = false}) {
    if (_released) return;
    _released = true;
    discard ? lease.discard() : lease.release();
    _releaseAuthority();
  }
}

/// Real URI identity, independent of the asynchronously accepted parent record.
@immutable
class WorkspaceThreadIdentity {
  const WorkspaceThreadIdentity({
    required this.parentChannelId,
    required this.parentMessageId,
    this.focusedMessageId,
  });
  final String parentChannelId, parentMessageId;
  final String? focusedMessageId;
}

class UploadDraft {
  UploadDraft(this.filename, this.bytes);
  final String filename;
  final Uint8List bytes;
  var cancel = UploadCancellation();
  double progress = 0;
  String? id, error;

  /// The accepted upload record (`POST /attachments/upload`), so an
  /// optimistic row can present the attachment before the message exists.
  Map<String, dynamic>? metadata;
}

class _SendAttempt {
  const _SendAttempt(this.fingerprint, this.randomId);
  final String fingerprint, randomId;
}

/// Web MessageInput `addOptimisticMessage`: the row presented from the moment
/// the user sends until the server copy (HTTP receipt or socket echo, matched
/// by `randomId`) replaces it. A failed send removes it and gives its text and
/// files back to the draft, as Web `removeOptimisticMessage` +
/// `restoreFailedSendDraft` do.
class _PendingSend {
  _PendingSend(this.randomId, this.row, this.draft, this.uploads);
  final String randomId, draft;
  final Map<String, dynamic> row;
  final List<UploadDraft> uploads;
}

/// Web `mergeFailedSendIntoDraft`.
String _mergeFailedSendIntoDraft(String failed, String current) {
  if (current.isEmpty) return failed;
  if (failed.isEmpty) return current;
  final separator = failed.endsWith('\n') || current.startsWith('\n')
      ? ''
      : '\n';
  return '$failed$separator$current';
}

class WorkspaceController extends ChangeNotifier {
  /// High-frequency socket events that never change workspace state.
  static const presenceEvents = {
    'agent:activity',
    'agent:seen',
    'agent:session',
    'machine:status',
    'machine:capabilities',
  };

  WorkspaceController(
    this.client, {
    this.cache,
    this.mobileNavigation = false,
    this.ownsClient = true,
    WorkspaceEntityDirectory? entityDirectory,
    FollowedThreadsStore? followedThreads,
    AttachmentImageByteStore? attachmentImageStore,
  }) : attachmentImageStore =
           attachmentImageStore ?? AttachmentImageDiskCache.installed {
    _ownsFollowedThreads = followedThreads == null;
    this.followedThreads =
        followedThreads ??
        FollowedThreadsStore(
          scope: _entityScope,
          query: (path) => query(path),
          command: (path, data) => command('POST', path, data: data),
          authority: this,
          events: client.events,
          isOpen: (id) => threadChannelId == id,
        );
    _ownsEntityDirectory = entityDirectory == null;
    this.entityDirectory =
        entityDirectory ??
        WorkspaceEntityDirectory(
          scope: _entityScope,
          query: (path) => query(path),
          events: client.events,
        );
    // Directory changes are not forwarded to this notifier: agent heartbeats,
    // last-seen and machine status patches would rebuild every workspace
    // listener. Surfaces that render entities listen to [entityDirectory]
    // (or a [WorkspaceEntitySelection] of it) directly.
    if (_ownsEntityDirectory) addListener(_entityAuthorityChanged);
    subscription = client.events.listen(_event);
  }

  /// Borrowed editor controllers project messages but never own the session,
  /// membership recovery, server selection, socket resume, or client teardown.
  final bool ownsClient;
  final RaftClient client;
  final WorkspaceCache? cache;
  late final WorkspaceEntityDirectory entityDirectory;
  late final bool _ownsEntityDirectory;

  /// Server-scoped followed threads, shared with borrowed controllers.
  late final FollowedThreadsStore followedThreads;
  late final bool _ownsFollowedThreads;
  WorkspaceEntityScope? _entityScope() {
    final principal = client.user?.id;
    final serverId = client.serverId;
    if (_disposed ||
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
        if (can('viewAgents')) WorkspaceEntityKind.agents,
        if (can('viewMachines')) WorkspaceEntityKind.computers,
        if (can('viewMembers')) WorkspaceEntityKind.members,
      },
    );
  }

  void _entityAuthorityChanged() {
    if (_disposed || !_ownsEntityDirectory) return;
    if (entityDirectory.synchronize() && entityDirectory.started) {
      scheduleMicrotask(() {
        if (!_disposed) unawaited(entityDirectory.preload());
      });
    }
  }

  AttachmentImageRepository? _attachmentImages;

  /// Persistent bytes for inline/list image previews (null: memory only).
  final AttachmentImageByteStore? attachmentImageStore;
  int get retainedImageDecodedBytes => _attachmentImages?.decodedByteCount ?? 0;
  int get retainedImageCount => _attachmentImages?.entryCount ?? 0;
  int get retainedImageEncodedBytes => _attachmentImages?.encodedByteCount ?? 0;
  final _imageAuthorities =
      <AttachmentImageKey, Map<Object, bool Function()>>{};
  AttachmentImageScope get attachmentImageScope => AttachmentImageScope(
    origin: client.origin,
    principal: client.user?.id ?? '',
    server: client.serverId ?? '',
    generation: client.generation,
    role: server?.string('role') ?? '',
  );

  /// Server-identity key for panel caches (account, origin, server, role and
  /// authentication generation). Channel switches, threads and tab changes do
  /// not change it; null while no signed-in server is selected.
  String? _panelCacheIdentity() {
    final principal = client.user?.id;
    final serverId = client.serverId;
    if (_disposed ||
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

  late final agentTabCache = ServerBoundCache<String, Object>(
    _panelCacheIdentity,
  );
  late final taskHistoryCache = ServerBoundCache<String, TaskHistorySnapshot>(
    _panelCacheIdentity,
    limit: 128,
  );
  late final _channelFilesStores =
      ServerBoundCache<String, SourceChannelFilesStore>(
        _panelCacheIdentity,
        limit: 24,
        onEvict: (store) => store.retire(),
      );

  /// Channel access behind a cached Files list: the server identity plus the
  /// member's current capabilities for that channel. null (nothing shown, list
  /// dropped on the next synchronization) once the channel is gone, revoked or
  /// no longer viewable. Channel switches and thread windows are not part of it.
  String? _channelFilesAuthority(String channelId) {
    final identity = _panelCacheIdentity();
    if (identity == null || _revokedChannels.contains(channelId)) return null;
    final current = channel?.id == channelId ? channel : null;
    final row =
        current ??
        [...channels, ...dms].where((c) => c.id == channelId).firstOrNull;
    if (row == null || !can('viewChannel', resource: row)) return null;
    return jsonEncode([identity, row.id, row.json['channelCapabilities']]);
  }

  /// The controller-owned Files projection of [channelId]. The same store is
  /// returned on every visit, so a revisit paints the last list immediately
  /// and a refresh replaces it in place.
  SourceChannelFilesStore channelFilesStore(String channelId) {
    final store = _channelFilesStores.putIfAbsent(
      channelId,
      () => SourceChannelFilesStore(
        channelId: channelId,
        authority: () => _channelFilesAuthority(channelId),
        get: (path, {query}) async {
          try {
            return await client.get(path, query: query);
          } on RaftApiException catch (error) {
            throw ChannelFilesRequestFailure(
              [401, 403].contains(error.status)
                  ? ChannelFilesFailure.unauthorized
                  : ChannelFilesFailure.unavailable,
            );
          }
        },
      ),
    );
    store.syncAuthority();
    return store;
  }

  bool _retainsAttachment(AttachmentImageKey key) {
    if (_disposed ||
        key.scope != attachmentImageScope ||
        client.user == null ||
        server?.id != client.serverId) {
      return false;
    }
    // A freshly accepted Files row is an independent permission projection.
    // Its active owner never grants authority through a cached URL or count.
    if (_imageAuthorities[key]?.values.any((admitted) => admitted()) == true) {
      return true;
    }
    final candidates =
        _retainedAttachmentIndex()[key.channelId]?[key.attachmentId] ??
        const <Map<String, dynamic>>[];
    for (final metadata in candidates) {
      final canonical = AttachmentImageKey.fromMetadata(
        scope: key.scope,
        channelId: key.channelId,
        metadata: metadata,
        rendition: key.rendition,
        target: key.target,
      );
      if (canonical == key) return true;
    }
    return false;
  }

  // Attachments in channels the member can currently view, keyed by channel
  // then attachment id. Rebuilt whenever messages, channel lists, revocations,
  // permissions or the image scope change; never reused across them.
  Object? _retainedIndexStamp;
  Map<String, Map<String, List<Map<String, dynamic>>>> _retainedIndex = {};

  Map<String, Map<String, List<Map<String, dynamic>>>>
  _retainedAttachmentIndex() {
    final stamp = (
      ledger.revision,
      _stateStamp,
      attachmentImageScope,
      identityHashCode(channels),
      channels.length,
      identityHashCode(dms),
      dms.length,
      _revokedChannels.length,
    );
    if (stamp == _retainedIndexStamp) return _retainedIndex;
    final index = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final channel in [...channels, ...dms]) {
      if (_revokedChannels.contains(channel.id) ||
          !can('viewChannel', resource: channel)) {
        continue;
      }
      final channelIds = <String>{channel.id};
      for (final message in ledger.messages(channel.id)) {
        final thread = RaftMessage(message).threadId;
        if (thread != null) channelIds.add(thread);
      }
      for (final channelId in channelIds) {
        if (index.containsKey(channelId)) continue;
        final byAttachment = index[channelId] = {};
        for (final message in ledger.messages(channelId)) {
          for (final metadata in RaftMessage(message).attachments) {
            final id = metadata['id'];
            if (id is String) (byAttachment[id] ??= []).add(metadata);
          }
        }
      }
    }
    _retainedIndexStamp = stamp;
    return _retainedIndex = index;
  }

  VoidCallback _registerImageAuthority(
    AttachmentImageKey key,
    bool Function() authorized,
  ) {
    final owner = Object();
    _imageAuthorities.putIfAbsent(key, () => {})[owner] = authorized;
    return () {
      final owners = _imageAuthorities[key];
      owners?.remove(owner);
      if (owners?.isEmpty == true) _imageAuthorities.remove(key);
      _attachmentImages?.synchronize(attachmentImageScope);
    };
  }

  WorkspaceAttachmentImageLease acquireAttachmentImage(
    AttachmentImageKey key, {
    required AttachmentImageLoader load,
    required bool Function() authorized,
  }) {
    final releaseAuthority = _registerImageAuthority(key, authorized);
    try {
      final repository = _attachmentImages ??= AttachmentImageRepository(
        scope: attachmentImageScope,
        retainedAuthority: _retainsAttachment,
        store: attachmentImageStore,
      );
      repository.synchronize(attachmentImageScope);
      return WorkspaceAttachmentImageLease(
        repository.acquire(key, load: load, authorized: authorized),
        releaseAuthority,
      );
    } catch (_) {
      releaseAuthority();
      rethrow;
    }
  }

  /// Synchronous lookup: a lease on the already decoded image for [key], or
  /// null when it is not retained (or no longer authorized). Never loads.
  WorkspaceAttachmentImageLease? peekAttachmentImage(
    AttachmentImageKey key, {
    required bool Function() authorized,
  }) {
    final repository = _attachmentImages;
    if (repository == null || _disposed) return null;
    repository.synchronize(attachmentImageScope);
    final releaseAuthority = _registerImageAuthority(key, authorized);
    final lease = repository.acquireReady(key, authorized: authorized);
    if (lease == null) {
      releaseAuthority();
      return null;
    }
    return WorkspaceAttachmentImageLease(lease, releaseAuthority);
  }

  /// Set by the host from its actual logical width before bootstrap. Home
  /// retains selection/drafts, but is not an open conversation/read surface.
  bool mobileNavigation;
  final messageSync = MessageSync();
  final threadRepliesSync = ThreadRepliesSync();
  final notificationPrefsSync = NotificationPrefsSync();
  bool syncCoreNotificationPrefsEnabled = false;
  String? _replyIdentity;

  /// Fail-closed fallback for an authority event without a channel id.
  int _replyAuthorityEpoch = 0;

  /// Per-channel authority epochs. A membership/authority change for one
  /// channel retires only that channel's windows, thread windows, reply
  /// scopes and in-flight loads; every other channel keeps its cache.
  final Map<String, int> _channelReplyEpochs = {};

  String _syncIdentity() => jsonEncode([
    client.origin,
    client.generation,
    client.serverId,
    client.user?.id,
    server?.string('role'),
  ]);

  /// Authority token for data owned by [channelId] (its message window, its
  /// thread windows and reply summaries).
  String _replyToken(String? channelId) => jsonEncode([
    _syncIdentity(),
    _replyAuthorityEpoch,
    channelId,
    _channelReplyEpochs[channelId] ?? 0,
  ]);
  void _ensureSyncIdentity() {
    final next = _syncIdentity();
    if (_replyIdentity == next) return;
    final hadIdentity = _replyIdentity != null;
    _messageFlagRequest++;
    _replyIdentity = next;
    threadRepliesSync.reset();
    notificationPrefsSync.reset();
    syncCoreNotificationPrefsEnabled = false;
    if (hadIdentity) _summariesByChannel.clear();
  }

  /// Retires one channel's reply authority (Source refreshes only the
  /// affected channel row on a membership event). Its reply scopes and
  /// thread windows go now; its message window is dropped on next use by the
  /// token mismatch. The open channel keeps its displayed summaries until its
  /// own refresh replaces them; a real revocation clears them in
  /// [_revokeChannel].
  void _invalidateChannelReplies(String id) {
    _channelReplyEpochs[id] = (_channelReplyEpochs[id] ?? 0) + 1;
    threadRepliesSync.revokeChannel(id);
    _threadWindows.removeWhere((_, window) => window.parentChannelId == id);
    if (channel?.id != id) _summariesByChannel.remove(id);
  }

  void _invalidateAllChannelReplies() {
    _replyAuthorityEpoch++;
    threadRepliesSync.reset();
    _threadWindows.clear();
    _summariesByChannel.removeWhere((id, _) => id != channel?.id);
  }

  /// Whether a member list change can change this principal's visibility of
  /// the channel (Source resource views fail closed on the same rule).
  bool _membershipScoped(String id) {
    final known = [...channels, ...dms].where((c) => c.id == id).firstOrNull;
    if (known == null) return true;
    final json = known.json;
    return json['isPrivate'] == true ||
        json['visibility'] == 'private' ||
        const {'private', 'dm', 'joint', 'thread'}.contains(known.type);
  }

  Map<String, dynamic> _hydrateThreadSummaries(
    dynamic raw,
    String parentChannelId, {
    String? expectedToken,
  }) {
    _ensureSyncIdentity();
    if (expectedToken != null &&
        expectedToken != _replyToken(parentChannelId)) {
      return {};
    }
    if (raw is! Map) return {};
    final id = client.serverId, principal = client.user?.id;
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: id == null || principal == null
              ? Map<String, dynamic>.from(entry.value)
              : threadRepliesSync.hydrateSummary(
                  id,
                  principal,
                  parentChannelId,
                  entry.key as String,
                  Map<String, dynamic>.from(entry.value),
                ),
    };
  }

  bool _replyCurrent(String token, ThreadRebaselineRequest request) =>
      !_disposed &&
      token == _replyToken(request.parentChannelId) &&
      !_revokedChannels.contains(request.parentChannelId) &&
      !_revokedChannels.contains(request.threadChannelId);

  Future<void> _rebaselineThread(ThreadRebaselineRequest request) async {
    final token = _replyToken(request.parentChannelId);
    try {
      // Exact mounted compatibility snapshot used by threadRepliesSyncDomain.
      final values = await Future.wait([
        client.get(
          '/messages/channel/${request.threadChannelId}',
          query: {'limit': inlineReplyCap},
        ),
        client.get(
          '/channels/${request.parentChannelId}/threads/${request.parentMessageId}',
        ),
      ]);
      if (!_replyCurrent(token, request)) return;
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
      final result = threadRepliesSync.completeRebaseline(
        request,
        replies: previews,
        replyCount: summary['replyCount'],
        historyLimited: page['historyLimited'] == true,
      );
      if (result.kind != 'applied' || result.summary == null) return;
      _summariesByChannel.putIfAbsent(
        request.parentChannelId,
        () => {},
      )[request.parentMessageId] = result.summary;
      _applyThreadUnread(request.threadChannelId, result.summary);
      if (channel?.id == request.parentChannelId) _saveWindow(channel!.id);
      notifyListeners();
    } catch (_) {
      // No guessed transport or fabricated completion. The next eligible
      // producer frame can retry its authorized compatibility snapshot.
    } finally {
      threadRepliesSync.release(request);
    }
  }

  void _consumeThreadUpdate(Map<String, dynamic> payload) {
    _ensureSyncIdentity();
    final id = client.serverId, principal = client.user?.id;
    if (id == null || principal == null) return;
    if (payload['serverId'] != null && payload['serverId'] != id) return;
    final parentId = payload['parentMessageId'];
    final latest = payload['latestReply'];
    final anchor = latest is Map ? latest['conversationContext'] : null;
    final parentChannel = anchor is Map ? anchor['parentChannelId'] : null;
    if (_revokedChannels.contains(payload['threadChannelId']) ||
        _revokedChannels.contains(parentChannel)) {
      return;
    }
    if (parentId is String &&
        channel != null &&
        _revokedChannels.contains(channel!.id)) {
      return;
    }
    final result = threadRepliesSync.consume(
      payload,
      serverId: id,
      principalId: principal,
    );
    if (result.summary != null && parentId is String) {
      final owner = _summaryOwner(payload, parentId);
      if (owner != null && !_revokedChannels.contains(owner)) {
        _summariesByChannel.putIfAbsent(owner, () => {})[parentId] =
            result.summary;
      }
      _applyThreadUnread(payload['threadChannelId'], payload);
    }
    if (result.request != null) unawaited(_rebaselineThread(result.request!));
  }

  /// The parent channel whose reply rows a `thread:updated` summary belongs
  /// to: the wire anchor first, else the channel already holding the parent.
  String? _summaryOwner(Map<String, dynamic> payload, String parentId) {
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
    final current = channel?.id;
    if (current != null &&
        (_summariesByChannel[current]?.containsKey(parentId) == true ||
            ledger.contains(current, parentId))) {
      return current;
    }
    for (final entry in _summariesByChannel.entries) {
      if (entry.value.containsKey(parentId)) return entry.key;
    }
    for (final entry in visibleIds.entries) {
      if (entry.value.contains(parentId)) return entry.key;
    }
    return null;
  }

  /// A thread summary carries the server's own per-thread unread count; it
  /// replaces only a count the unread snapshot already tracks.
  void _applyThreadUnread(dynamic threadChannelId, dynamic summary) {
    if (threadChannelId is! String ||
        summary is! Map ||
        !unread.containsKey(threadChannelId) ||
        threadChannelId == this.threadChannelId) {
      return;
    }
    final count = summary['unreadCount'];
    if (count is! int || count < 0 || unread[threadChannelId] == count) return;
    unread = {...unread, threadChannelId: count};
    _persistUnread();
  }

  void _consumeNotificationPrefs(dynamic payload) {
    _ensureSyncIdentity();
    var update = readNotificationPrefsUpdate(payload);
    if (update == null ||
        update['serverId'] != client.serverId ||
        client.user == null) {
      return;
    }
    if (syncCoreNotificationPrefsEnabled) {
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

      servers = servers.map(patch).toList();
      if (server != null) server = patch(server!);
    } else {
      final state = accepted['state'] as Map;
      final id = accepted['channelId'];
      if (_revokedChannels.contains(id)) return;
      RaftChannel patch(RaftChannel value) {
        if (value.id != id) return value;
        final old = value.json['prefsVersion'],
            incoming = state['prefsVersion'];
        if (old is int && incoming is int && incoming < old) return value;
        return RaftChannel({...value.json, ...state});
      }

      channels = channels.map(patch).toList();
      dms = dms.map(patch).toList();
      if (channel != null) channel = patch(channel!);
    }
    refreshUnread();
  }

  bool syncCoreMessagesEnabled = false;
  int _messageFlagRequest = 0;

  Future<void> refreshMessageSyncFlag() async {
    _ensureSyncIdentity();
    final request = ++_messageFlagRequest;
    final generation = client.generation, principal = client.user?.id;
    final identity = _syncIdentity();
    final id = client.serverId;
    if (id == null || principal == null) return;
    try {
      final result = await client.post(
        '/feature-flags/evaluate',
        data: {
          'keys': ['sync_core_messages_v0', notificationPrefsFlag],
          'serverId': id,
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'mobile'
              : 'web',
        },
      );
      if (_disposed ||
          request != _messageFlagRequest ||
          generation != client.generation ||
          principal != client.user?.id ||
          id != client.serverId ||
          identity != _syncIdentity()) {
        return;
      }
      final enabled =
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == 'sync_core_messages_v0' && f['enabled'] == true,
          );
      if (enabled != syncCoreMessagesEnabled) messageSync.reset();
      syncCoreMessagesEnabled = enabled;
      final prefsEnabled =
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == notificationPrefsFlag && f['enabled'] == true,
          );
      if (prefsEnabled != syncCoreNotificationPrefsEnabled) {
        notificationPrefsSync.reset();
      }
      syncCoreNotificationPrefsEnabled = prefsEnabled;
    } catch (_) {
      if (!_disposed &&
          request == _messageFlagRequest &&
          identity == _syncIdentity()) {
        syncCoreNotificationPrefsEnabled = false;
        notificationPrefsSync.reset();
      }
      // Unknown capability never authorizes the gated preference path.
    }
  }

  Future<void> _cacheWrites = Future<void>.value();
  Future<void> flushCache() => _cacheWrites;
  final Map<String, String> drafts = {};
  final Set<String> _revokedChannels = {};
  final Set<String> _revokedServers = {};
  Object? _presentationOwner;
  bool _mainPresented = true, _threadPresented = true;
  Object? _tabPresentationOwner;
  bool _chatTabPresented = true;

  /// Channel tabs and folded panels are independent presentation owners.
  /// Neither loaded data nor an offstage retained editor admits a read receipt.
  void setChatTabPresentation(Object owner, bool visible) {
    _tabPresentationOwner = owner;
    _chatTabPresented = visible;
  }

  void releaseChatTabPresentation(Object owner) {
    if (!identical(owner, _tabPresentationOwner)) return;
    _tabPresentationOwner = null;
    _chatTabPresented = true;
  }

  /// Mounted layout admission, separate from accepted message windows. This
  /// changes synchronously without notifying/rebuilding the controller tree.
  void setConversationPresentation(
    Object owner, {
    required bool main,
    required bool thread,
  }) {
    _presentationOwner = owner;
    _mainPresented = main;
    _threadPresented = thread;
  }

  void releaseConversationPresentation(Object owner) {
    if (!identical(owner, _presentationOwner)) return;
    _presentationOwner = null;
    _mainPresented = _threadPresented = true;
  }

  final foregroundChanges = ValueNotifier<bool>(true);
  bool foreground = true;
  void setForeground(bool value) {
    foreground = value;
    if (!value) RaftUserActivity.forget();
    foregroundChanges.value = value;
    if (value) {
      if (channel != null && !hasNewer) markRead(channel!.id);
      if (threadChannelId != null) markRead(threadChannelId!);
    }
  }

  void revokeServer(String id) {
    final principal = client.user?.id;
    if (principal == null) return;
    _revokedServers.add(id);
    servers.removeWhere((s) => s.id == id);
    final origin = client.origin;
    if (client.serverId == id) {
      for (final list in _uploads.values) {
        for (final draft in list) {
          draft.cancel.cancel();
        }
      }
      _uploads.clear();
      _attempts.clear();
      _pendingSends.clear();
      drafts.clear();
      visibleIds.clear();
      _windowState.clear();
      _diskOnlyWindows.clear();
      _windowHistoryLimited.clear();
      _threadWindows.clear();
      historyLimited = threadHistoryLimited = false;
      _contextWindows.clear();
      channel = null;
      channels = [];
      dms = [];
      server = null;
      unread = {};
      _latestActivity.clear();
      sidebarOrder = {};
      threadParent = null;
      threadChannelId = null;
      _summariesByChannel.clear();
      highlightedMessageId = null;
      channelGeneration++;
      threadGeneration++;
      ledger.switchServer(null);
      readState.reset();
      resourceSnapshots.clear();
      _prefetched.clear();
      reactionViewer.reset();
      messageSync.reset();
      syncCoreMessagesEnabled = false;
      _messageFlagRequest++;
      if (ownsClient) client.selectServer(null);
      loading = false;
      channelLoading = false;
      threadLoading = false;
    }
    _cacheWrites = _cacheWrites.then((_) async {
      try {
        await cache?.revokeServer(origin, principal, id);
      } catch (_) {
        if (!_disposed) {
          setError(
            'Revoked workspace data could not be removed from this device.',
          );
        }
      }
    });
    _save('servers', '', servers.map((s) => s.json).toList(), server: '');
    notifyListeners();
  }

  Future<dynamic> _cached(String kind, String id, {String? server}) async {
    if (cache == null || client.user == null) return null;
    final origin = client.origin,
        principal = client.user!.id,
        serverId = server ?? client.serverId ?? '';
    await flushCache();
    try {
      return await cache!.read(origin, principal, serverId, kind, id);
    } catch (_) {
      if (!_disposed) error ??= 'Local workspace history is unavailable.';
      return null;
    }
  }

  Future<void> _save(
    String kind,
    String id,
    dynamic value, {
    String? server,
  }) async {
    final user = client.user?.id;
    if (cache == null || user == null) return;
    if (_revokedChannels.contains(id) ||
        value is Map && _revokedChannels.contains(value['channelId'])) {
      return;
    }
    final origin = client.origin, serverId = server ?? client.serverId ?? '';
    _cacheWrites = _cacheWrites.then((_) async {
      try {
        await cache!.write(origin, user, serverId, kind, id, value);
      } catch (_) {
        if (!_disposed) {
          error ??= 'Local changes could not be saved on this device.';
          notifyListeners();
        }
      }
    });
    await _cacheWrites;
  }

  void saveDraft(String text, {bool thread = false}) {
    final scope = draftScope(thread: thread);
    if (scope == null) return;
    drafts[scope] = text;
    _save(
      'draft',
      scope,
      text.isEmpty ? null : {'text': text, 'channelId': channel?.id},
    );
  }

  void updateDraftFromShare(String text) {
    saveDraft(text);
    notifyListeners();
  }

  Future<void> _restoreDraft(String scope) async {
    final generation = ledger.generation;
    final value = await _cached('draft', scope);
    if (generation != ledger.generation ||
        _disposed ||
        drafts.containsKey(scope)) {
      return;
    }
    if (value is Map && value['text'] is String) {
      drafts[scope] = value['text'];
      notifyListeners();
    }
    final attempt = await _cached('attempt', scope);
    if (generation == ledger.generation &&
        attempt is Map &&
        !_attempts.containsKey(scope)) {
      _attempts[scope] = _SendAttempt(
        attempt['fingerprint'],
        attempt['randomId'],
      );
    }
  }

  String _windowAuthority() =>
      messageWindowAuthority(server?.string('role'), channel?.json ?? const {});

  Future<void> _saveWindow(String id, {bool thread = false}) async {
    if (_disposed ||
        channel == null ||
        (thread ? id != threadChannelId : id != channel!.id) ||
        _revokedChannels.contains(id) ||
        hasNewer ||
        highlightedMessageId != null) {
      return;
    }
    final rows = (thread ? replies : messages);
    _windowState[id] = (
      _windowAuthority(),
      thread ? threadHasMore : hasMore,
      _replyToken(thread ? threadParentChannelId : id),
    );
    _windowHistoryLimited[id] = thread ? threadHistoryLimited : historyLimited;
    _contextWindows.remove(id);
    final saved = _save('window', id, {
      'version': 1,
      'authority': _windowAuthority(),
      'windowKind': 'tail',
      'messages': rows
          .skip(
            rows.length > messageWindowLimit
                ? rows.length - messageWindowLimit
                : 0,
          )
          .map((m) => m.json)
          .toList(),
      'parentChannelId': thread ? threadParentChannelId : id,
      'hasMore': thread ? threadHasMore : hasMore,
      'historyLimited': thread ? threadHistoryLimited : historyLimited,
      'hasNewer': false,
      'threadSummaries': thread
          ? {}
          : Map<String, dynamic>.from(threadSummaries),
    });
    final identity = _threadIdentity;
    // Queued in the same turn as the window write, so one flush covers both.
    if (thread && identity != null && identity.focusedMessageId == null) {
      await _saveThreadWindow(identity, id);
    }
    await saved;
  }

  /// A thread's accepted tail, keyed by its parent message so a later open
  /// (including after restart) paints it before any lookup. It belongs to
  /// the parent channel: that channel's revocation purges it.
  Future<void> _saveThreadWindow(
    WorkspaceThreadIdentity identity,
    String threadId,
  ) async {
    final authority = _threadResourceAuthority(identity.parentChannelId);
    if (authority == null ||
        _revokedChannels.contains(identity.parentChannelId) ||
        _revokedChannels.contains(threadId)) {
      return;
    }
    final rows = replies;
    final parent = threadParent;
    await _save('thread-window', identity.parentMessageId, {
      'version': 1,
      'windowKind': 'tail',
      'authority': authority,
      'parentChannelId': identity.parentChannelId,
      'threadChannelId': threadId,
      if (parent != null &&
          parent.id == identity.parentMessageId &&
          parent.channelId == identity.parentChannelId)
        'parent': parent.json,
      'messages': rows
          .skip(
            rows.length > messageWindowLimit
                ? rows.length - messageWindowLimit
                : 0,
          )
          .map((m) => m.json)
          .toList(),
      'hasMore': threadHasMore,
      'historyLimited': threadHistoryLimited,
    });
  }

  bool _acceptCachedWindow(dynamic page, String id) =>
      page is Map &&
      page['version'] == 1 &&
      page['windowKind'] == 'tail' &&
      page['hasNewer'] != true &&
      page['authority'] == _windowAuthority() &&
      can('viewChannel', resource: channel) &&
      !_revokedChannels.contains(id) &&
      !_revokedServers.contains(server?.id) &&
      page['parentChannelId'] == channel?.id;

  late final StreamSubscription<RaftEvent> subscription;
  final ledger = MessageLedger();
  final reactionViewer = ReactionViewerLedger();
  final Map<String, Future<void>> _reactionWrites = {};
  final Map<String, Future<void>> _viewerLoads = {};
  final Map<String, List<UploadDraft>> _uploads = {};
  final Map<String, _SendAttempt> _attempts = {};

  /// Optimistic rows by draft scope, in send order.
  final Map<String, List<_PendingSend>> _pendingSends = {};

  /// `randomId`s this session sent; their rows keep one presentation key
  /// from the optimistic row through the server copy.
  final Set<String> _localRandomIds = {};
  bool _disposed = false;
  Future<String?>? _creatingThread;
  int? _creatingThreadWindow;
  int _stateStamp = 0;
  @override
  void notifyListeners() {
    _stateStamp++;
    _attachmentImages?.synchronize(attachmentImageScope);
    if (!_disposed) {
      _ensureSyncIdentity();
      super.notifyListeners();
    }
  }

  /// Outside-channel mention actions from the latest send per draft scope
  /// (Web MessageInput `pendingMentionActions`).
  final Map<String, List<Map<String, dynamic>>> pendingMentionActions = {};

  List<Map<String, dynamic>> pendingMentionsFor({bool thread = false}) =>
      pendingMentionActions[draftScope(thread: thread)] ?? const [];

  void dismissPendingMention(String resolutionId, {bool thread = false}) {
    final scope = draftScope(thread: thread);
    final list = pendingMentionActions[scope];
    if (list == null) return;
    pendingMentionActions[scope!] = [
      for (final a in list)
        if (a['resolutionId'] != resolutionId) a,
    ];
    notifyListeners();
  }

  /// `POST /messages/mention-actions/execute`; returns ids whose result
  /// status matches the action (`queued` for notify, `delivered` for add).
  Future<Set<String>> executeMentionActions(
    String action,
    List<String> resolutionIds,
  ) async {
    final value = await command(
      'POST',
      '/messages/mention-actions/execute',
      data: {'action': action, 'resolutionIds': resolutionIds},
    );
    final ok = action == 'notify' ? 'queued' : 'delivered';
    return {
      if (value is Map && value['results'] is List)
        for (final r in (value['results'] as List).whereType<Map>())
          if (r['status'] == ok && r['resolutionId'] is String)
            r['resolutionId'] as String,
    };
  }

  String? draftScope({bool thread = false}) => thread
      ? (threadParentMessageId == null ? null : 'thread:$threadParentMessageId')
      : channel?.id;
  bool get conversationPaused =>
      channel != null && channelConversionBlocksSending(channel!.json);
  List<UploadDraft> uploads({bool thread = false}) =>
      _uploads[draftScope(thread: thread)] ?? [];
  bool uploadsReady({bool thread = false}) =>
      uploads(thread: thread).every((u) => u.id != null);

  /// Web MessageInput composer error banner per draft scope.
  final Map<String, String> composerErrors = {};
  String? composerErrorFor({bool thread = false}) =>
      composerErrors[draftScope(thread: thread)];

  /// Web `resolveAttachmentUploadLimitBytes`: the server ceiling from
  /// `GET /attachments/upload-capabilities`, or null when it is unusable.
  Future<int?> uploadLimitBytes() async {
    try {
      final value = await query('/attachments/upload-capabilities');
      final max = value is Map ? value['maxBytes'] : null;
      return max is num && max.isFinite && max > 0 ? max.toInt() : null;
    } catch (_) {
      return null;
    }
  }

  /// Web `decideMessageAttachmentSelection` + upload: an unknown ceiling
  /// refuses the whole batch; empty, oversize and over-count files are
  /// skipped with the Web messages. [text] localizes a message key.
  Future<void> attachSelection(
    List<({String name, Uint8List bytes})> files, {
    bool thread = false,
    required String Function(String key, Map<String, Object> args) text,
  }) async {
    final scope = draftScope(thread: thread);
    if (scope == null || files.isEmpty) return;
    final generation = ledger.generation;
    final authority = jsonEncode([
      client.generation,
      client.user?.id,
      client.serverId,
      server?.id,
      server?.string('role'),
      channel?.joined,
      channel?.archived,
      channel?.json['channelCapabilities'],
    ]);
    bool current() =>
        generation == ledger.generation &&
        scope == draftScope(thread: thread) &&
        authority ==
            jsonEncode([
              client.generation,
              client.user?.id,
              client.serverId,
              server?.id,
              server?.string('role'),
              channel?.joined,
              channel?.archived,
              channel?.json['channelCapabilities'],
            ]);
    final limit = await uploadLimitBytes();
    if (!current()) return;
    final accepted = <({String name, Uint8List bytes})>[];
    var count = 0, empty = 0;
    final oversize = <int>[];
    var slots = (10 - uploads(thread: thread).length).clamp(0, 10);
    if (limit != null) {
      for (final file in files) {
        if (file.bytes.isEmpty) {
          empty++;
        } else if (file.bytes.length > limit) {
          oversize.add(file.bytes.length);
        } else if (slots <= 0) {
          count++;
        } else {
          accepted.add(file);
          slots--;
        }
      }
    }
    final parts = <String>[
      if (limit == null)
        text(
          'The upload size limit could not be checked. Try again in a moment.',
          const {},
        ),
      if (count > 0)
        text(
          'Only {max} attachments per message. {extra} extra files skipped.',
          {'max': 10, 'extra': count},
        ),
      if (empty > 0) text('{count} empty files skipped.', {'count': empty}),
      if (oversize.isNotEmpty)
        text('Max {maxSize} per file. Current largest file is {largest}.', {
          'maxSize': _limitLabel(limit!),
          'largest': _bytesLabel(oversize.reduce((a, b) => a > b ? a : b)),
        }),
    ];
    if (parts.isEmpty) {
      composerErrors.remove(scope);
    } else {
      composerErrors[scope] = parts.join(' ');
    }
    notifyListeners();
    for (final file in accepted) {
      if (!current()) return;
      await attachUpload(file.name, file.bytes, thread: thread);
    }
  }

  static String _limitLabel(int bytes) => bytes % (1024 * 1024) == 0
      ? '${bytes ~/ (1024 * 1024)}MB'
      : _bytesLabel(bytes);

  static String _bytesLabel(int bytes) {
    if (bytes <= 0) return '0B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)}${units[unit]}';
  }

  Future<void> attachUpload(
    String name,
    Uint8List bytes, {
    bool thread = false,
  }) async {
    final scope = draftScope(thread: thread);
    if (scope == null) return;
    if (bytes.isEmpty) {
      throw const RaftApiException('Empty files cannot be uploaded.');
    }
    if (uploads(thread: thread).length >= 10) {
      throw const RaftApiException('Attach up to 10 files per message.');
    }
    final draft = UploadDraft(name, bytes);
    (_uploads[scope] ??= []).add(draft);
    await _transferUpload(draft, thread: thread);
  }

  Future<void> retryUpload(UploadDraft draft, {bool thread = false}) async {
    if (!uploads(thread: thread).contains(draft) || draft.error == null) return;
    draft.cancel = UploadCancellation();
    draft.error = null;
    draft.progress = 0;
    await _transferUpload(draft, thread: thread);
  }

  Future<void> _transferUpload(
    UploadDraft draft, {
    required bool thread,
  }) async {
    final generation = ledger.generation;
    final idBefore = channel?.id;
    final scope = draftScope(thread: thread);
    notifyListeners();
    try {
      final id = thread ? await ensureThread() : idBefore;
      if (id == null ||
          generation != ledger.generation ||
          _disposed ||
          draft.cancel.cancelled ||
          !(_uploads[scope]?.contains(draft) ?? false)) {
        return;
      }
      final files = await client.upload(
        id,
        draft.bytes,
        draft.filename,
        cancellation: draft.cancel,
        onProgress: (sent, total) {
          if (generation != ledger.generation ||
              draft.cancel.cancelled ||
              _disposed) {
            return;
          }
          draft.progress = total > 0 ? sent / total : 0;
          notifyListeners();
        },
      );
      if (generation != ledger.generation ||
          draft.cancel.cancelled ||
          _disposed ||
          !(_uploads[scope]?.contains(draft) ?? false)) {
        return;
      }
      draft.id = files.single['id'];
      draft.metadata = files.single;
      draft.progress = 1;
    } catch (e) {
      if (!draft.cancel.cancelled &&
          generation == ledger.generation &&
          !_disposed) {
        draft.error = e is RaftApiException
            ? e.message
            : 'Upload failed. Retry the file.';
      }
    } finally {
      notifyListeners();
    }
  }

  void removeUpload(UploadDraft draft, {bool thread = false}) {
    draft.cancel.cancel();
    // The caller may be disposing a view after selection changed.
    for (final drafts in _uploads.values) {
      drafts.remove(draft);
    }
    notifyListeners();
  }

  final readState = ReadStateLedger();

  /// Workspace-owned page snapshots (Activity, Saved) that survive
  /// navigation; dropped on every server or account switch.
  final resourceSnapshots = ResourceSnapshotCache();
  final Map<String, Set<String>> visibleIds = {};
  final Map<String, (String, bool, String)> _windowState = {};

  /// Accepted reply windows by parent message (Source threadStore keeps a
  /// thread's messages after it closes): reopening shows them at once and
  /// revalidates in the background. Bound to the authority that accepted them.
  final Map<String, _ThreadWindow> _threadWindows = {};
  final Set<String> _contextWindows = {};
  bool hasNewer = false, threadHasMore = false;
  bool threadHistoryLimited = false, historyLimited = false;
  final Map<String, bool> _windowHistoryLimited = {};
  String? highlightedMessageId;
  String? _pendingMessageContextChannelId;
  int? _pendingMessageContextWindow;
  bool _pendingMessageContextRetainsRows = false;
  final Map<String, bool> _contextWindowHasNewer = {};

  /// Pending unknown context; cross-channel cached tails are not that context.
  String? get pendingMessageContextChannelId =>
      _pendingMessageContextWindow == channelGeneration
      ? _pendingMessageContextChannelId
      : null;
  List<RaftRecord> servers = [];
  List<RaftChannel> channels = [], dms = [];
  Map<String, int> unread = {};
  Map<String, dynamic> sidebarOrder = {};
  RaftRecord? server;
  bool can(String capability, {RaftChannel? resource}) => raftCan(
    server?.string('role'),
    capability,
    channelCapabilities: resource?.json['channelCapabilities'] is Map
        ? Map<String, dynamic>.from(resource!.json['channelCapabilities'])
        : null,
  );
  RaftChannel? channel;
  WorkspaceThreadIdentity? _threadIdentity;
  int _threadIdentityWindow = -1, _threadIdentityNavigation = -1;
  String? _threadIdentityToken, _threadIdentityAuthority;
  bool _threadResolutionLoading = false, _threadParentLoading = false;
  String? _threadResolutionError;

  WorkspaceThreadIdentity? get threadIdentity =>
      !_disposed &&
          _threadIdentityWindow == threadGeneration &&
          _threadIdentityNavigation == navigationRevision &&
          _threadIdentityToken ==
              _replyToken(_threadIdentity?.parentChannelId) &&
          (_threadIdentityAuthority == null ||
              _threadIdentityAuthority ==
                  _threadResourceAuthority(_threadIdentity?.parentChannelId)) &&
          !_revokedChannels.contains(_threadIdentity?.parentChannelId) &&
          !_revokedChannels.contains(threadChannelId) &&
          can(
            'viewChannel',
            resource: _threadChannelResource(_threadIdentity?.parentChannelId),
          )
      ? _threadIdentity
      : null;
  bool get threadResolutionLoading =>
      threadIdentity != null && _threadResolutionLoading;
  bool get threadParentLoading =>
      threadIdentity != null && _threadParentLoading;
  String? get threadResolutionError =>
      threadIdentity == null ? null : _threadResolutionError;
  RaftMessage? get presentedThreadParent => _threadIdentity == null
      ? threadParent
      : threadIdentity != null &&
            threadParent?.id == threadIdentity!.parentMessageId &&
            threadParent?.channelId == threadIdentity!.parentChannelId
      ? threadParent
      : null;
  String? get threadParentMessageId =>
      threadIdentity?.parentMessageId ??
      (_threadIdentity == null ? threadParent?.id : null);
  String? get threadParentChannelId =>
      threadIdentity?.parentChannelId ??
      (_threadIdentity == null ? threadParent?.channelId : null);

  RaftChannel? _threadChannelResource(String? id) => [
    ?channel,
    ...channels,
    ...dms,
  ].where((value) => value.id == id).firstOrNull;
  String? _threadResourceAuthority(String? id) {
    final resource = _threadChannelResource(id);
    return resource == null
        ? null
        : messageWindowAuthority(server?.string('role'), resource.json);
  }

  RaftChannel? get threadSourceChannel =>
      _threadChannelResource(threadParentChannelId);

  RaftMessage? threadParent;
  String? threadChannelId;
  bool loading = false,
      channelLoading = false,
      threadLoading = false,
      loadingOlder = false,
      hasMore = false;
  bool connected = false;
  String? error;
  final navigation = WorkspaceNavigation();
  String _unboundSection = 'chat';
  String? _navigationAuthority;
  String get navigationAuthority => jsonEncode([
    client.origin,
    client.generation,
    client.user?.id,
    server?.id,
    client.serverId,
    server?.string('role'),
  ]);
  void bindNavigation() {
    if (server == null) return;
    final authority = navigationAuthority;
    if (_navigationAuthority == authority) return;
    final slug =
        [
          server!.string('slug'),
          server!.id,
          client.serverId,
        ].whereType<String>().where((value) => value.isNotEmpty).firstOrNull ??
        '_';
    final initial = _navigationAuthority == null
        ? WorkspaceNavigation.locationForSection(
            slug,
            _unboundSection,
            channelId: channel?.id,
            dm: channel?.type == 'dm',
          )
        : navigation.location.serverSlug == slug
        ? navigation.location
        : WorkspaceNavigation.locationForSection(
            slug,
            mobileNavigation ? 'home' : _unboundSection,
            channelId: null,
          );
    _navigationAuthority = authority;
    navigation.bind(authority, initial);
  }

  RaftLocation get location {
    bindNavigation();
    return navigation.location;
  }

  int get navigationRevision {
    bindNavigation();
    return navigation.revision;
  }

  String get section {
    bindNavigation();
    if (server == null) return _unboundSection;
    final projected = navigation.section;
    // SettingsPanel.tsx:7882–7894 retains the requested URL while a denied
    // tab resolves to Account. It does not redirect the entire workspace.
    return navigation.location.route == RaftRoute.settings &&
            !canVisitSection(projected)
        ? 'settings'
        : projected;
  }

  set section(String value) {
    _unboundSection = value;
    final firstBind = _navigationAuthority == null && server != null;
    bindNavigation();
    if (server != null && !firstBind) {
      navigation.selectSection(
        value,
        channelId: channel?.id,
        dm: channel?.type == 'dm',
      );
    }
  }

  int channelGeneration = 0, threadGeneration = 0;

  /// Accepted thread summaries ("N replies" rows) per parent channel, keyed
  /// by parent message. Like the channel's message window they outlive a
  /// channel switch, so a revisit or a prefetched first open renders its
  /// reply rows in the same frame as the messages.
  final Map<String, Map<String, dynamic>> _summariesByChannel = {};

  /// Summaries of the selected channel's messages.
  Map<String, dynamic> get threadSummaries {
    final id = channel?.id;
    return id == null
        ? <String, dynamic>{}
        : _summariesByChannel.putIfAbsent(id, () => {});
  }

  set threadSummaries(Map<String, dynamic> value) {
    final id = channel?.id;
    if (id != null) _summariesByChannel[id] = value;
  }

  /// Summaries held for [channelId] (selected or not).
  Map<String, dynamic> threadSummariesFor(String channelId) =>
      Map.unmodifiable(_summariesByChannel[channelId] ?? const {});
  List<RaftMessage> get messages =>
      channel == null ||
          (pendingMessageContextChannelId == channel!.id &&
              !_pendingMessageContextRetainsRows)
      ? []
      : ledger
            .messages(channel!.id)
            .where((m) => visibleIds[channel!.id]?.contains(m['id']) ?? false)
            .map(RaftMessage.new)
            .toList();

  /// Same membership as [messages], in constant time (no list projection).
  bool presentsMessage(String? id) {
    final current = channel;
    if (id == null || current == null) return false;
    if (pendingMessageContextChannelId == current.id &&
        !_pendingMessageContextRetainsRows) {
      return false;
    }
    return (visibleIds[current.id]?.contains(id) ?? false) &&
        ledger.contains(current.id, id);
  }

  /// Same membership as [replies], in constant time.
  bool presentsReply(String? id) {
    final thread = threadChannelId;
    if (id == null || thread == null) return false;
    return (visibleIds[thread]?.contains(id) ?? false) &&
        ledger.contains(thread, id);
  }

  List<RaftMessage> get replies => threadChannelId == null
      ? []
      : ledger
            .messages(threadChannelId!)
            .where(
              (m) => visibleIds[threadChannelId!]?.contains(m['id']) ?? false,
            )
            .map(RaftMessage.new)
            .toList();

  /// The presented timeline: [messages] or [replies] followed by this
  /// scope's optimistic rows (Web `addOptimisticMessage` places them after
  /// every persisted row). A row whose server copy is already presented is
  /// dropped, whichever of HTTP or socket delivered it. Like Web ThreadPanel,
  /// optimistic rows stay hidden while an older window is presented.
  List<RaftMessage> timeline({bool thread = false}) {
    final rows = thread ? replies : messages;
    final scope = draftScope(thread: thread);
    final pending = scope == null ? null : _pendingSends[scope];
    if (pending == null ||
        pending.isEmpty ||
        !thread &&
            (hasNewer || pendingMessageContextChannelId == channel?.id)) {
      return rows;
    }
    final confirmed = {
      for (final row in rows)
        if (row.json['randomId'] is String) row.json['randomId'],
    };
    return [
      ...rows,
      for (final send in pending)
        if (!confirmed.contains(send.randomId)) RaftMessage(send.row),
    ];
  }

  /// Stable presentation identity: a row sent from this session keeps its
  /// optimistic key after the server copy replaces it, so the timeline
  /// updates that row in place instead of removing and inserting one.
  String messageKey(RaftMessage message) {
    final randomId = message.json['randomId'];
    return randomId is String && _localRandomIds.contains(randomId)
        ? 'optimistic-$randomId'
        : message.id;
  }

  /// Whether [message] is an optimistic row still waiting for the server.
  static bool isPendingSend(RaftMessage message) =>
      message.json['pendingSend'] == true;

  void setError(String? value) {
    error = value;
    notifyListeners();
  }

  /// Hydrates the account's real server directory without selecting a server.
  /// The app root uses this before exposing the global chooser. Offline rows
  /// retain the existing account-scoped cache contract; fresh authority and
  /// cache writes share the membership reducer's request/revocation fences.
  ///
  /// With [cachedFirst] (cold start) an accepted on-device directory is
  /// adopted at once, so the remembered server and its cached channels paint
  /// without waiting for the network; [revalidateServerDirectory] then
  /// replaces it in the background.
  Future<bool> loadServerDirectory({bool cachedFirst = false}) async {
    if (!ownsClient) {
      throw StateError('A borrowed editor cannot load the server directory.');
    }
    final generation = client.generation,
        principal = client.user?.id,
        request = ++_membershipRequest,
        revision = _membershipRevision;
    bool current() =>
        !_disposed &&
        generation == client.generation &&
        principal == client.user?.id &&
        request == _membershipRequest &&
        revision == _membershipRevision;
    if (principal == null) return false;
    if (client.restoredOffline || cachedFirst) {
      final cached = await _cached('servers', '', server: '');
      if (!current()) return false;
      if (cached is List && cached.isNotEmpty) {
        servers = cached
            .map((row) => RaftRecord(Map<String, dynamic>.from(row)))
            .where((server) => !_revokedServers.contains(server.id))
            .toList();
        notifyListeners();
        if (cachedFirst) unawaited(revalidateServerDirectory());
        return true;
      }
    }
    final accepted = await client.servers();
    if (!current()) return false;
    _revokedServers.removeAll(accepted.map((server) => server.id));
    servers = accepted;
    await _save(
      'servers',
      '',
      accepted.map((server) => server.json).toList(),
      server: '',
    );
    if (!current()) return false;
    notifyListeners();
    return true;
  }

  /// Background replacement of a cache-first directory once the restored
  /// session is validated. A server missing from the fresh directory is
  /// revoked (its on-device data is purged and, when selected, its workspace
  /// closes); a changed role replaces the selected server's authority, which
  /// retires role-bound windows and revalidates the open channel. A failure
  /// keeps the accepted directory (offline).
  Future<void> revalidateServerDirectory() async {
    final principal = client.user?.id,
        request = ++_membershipRequest,
        revision = _membershipRevision;
    bool current() =>
        !_disposed &&
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
      if (!ids.contains(held.id)) revokeServer(held.id);
    }
    final selected = server;
    if (selected != null && !ids.contains(selected.id)) {
      revokeServer(selected.id);
    }
    _revokedServers.removeAll(ids);
    servers = accepted;
    _save('servers', '', accepted.map((s) => s.json).toList(), server: '');
    final held = server;
    final fresh = held == null
        ? null
        : accepted.where((s) => s.id == held.id).firstOrNull;
    if (held != null && fresh != null) {
      final role = fresh.string('role');
      if (role != held.string('role')) {
        applyMembershipRole({
          'userId': principal,
          'serverId': held.id,
          'role': role,
        });
        server = fresh;
        notifyListeners();
        await refreshChannels();
        final open = channel;
        if (!_disposed && open != null && server?.id == held.id) {
          unawaited(
            selectChannel(
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
    notifyListeners();
  }

  Future<void> bootstrap() async {
    if (!ownsClient) {
      throw StateError('A borrowed editor cannot bootstrap a session.');
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final cached = await _cached('servers', '', server: '');
      if (cached is List) {
        servers = cached
            .map((e) => RaftRecord(Map<String, dynamic>.from(e)))
            .where((s) => !_revokedServers.contains(s.id))
            .toList();
      }
      notifyListeners();
      if (servers.isNotEmpty && client.restoredOffline) {
        await selectServer(servers.first);
        return;
      }
      servers = await client.servers();
      _revokedServers.removeAll(servers.map((s) => s.id));
      await _save(
        'servers',
        '',
        servers.map((s) => s.json).toList(),
        server: '',
      );
      if (servers.isNotEmpty) await selectServer(servers.first);
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// [onHydrated] runs once the on-device channels, selection window and
  /// unread counts of [next] are painted, before any network response; it
  /// does not run when nothing is cached. The returned future still settles
  /// only after the fresh channel lists (and the selected page) are applied.
  Future<void> selectServer(
    RaftRecord next, {
    void Function()? onHydrated,
  }) async {
    if (!ownsClient) {
      throw StateError('A borrowed editor cannot select a server.');
    }
    if (_revokedServers.contains(next.id)) return;
    server = next;
    if (mobileNavigation) section = 'home';
    if (!canVisitSection(section)) section = 'chat';
    sidebarOrder = {};
    client.selectServer(next.id);
    entityDirectory.synchronize();
    unawaited(entityDirectory.preload());
    followedThreads.start();
    ledger.switchServer(next.id);
    readState.reset();
    resourceSnapshots.clear();
    _prefetched.clear();
    reactionViewer.reset();
    messageSync.reset();
    syncCoreMessagesEnabled = false;
    refreshMessageSyncFlag();
    loadSidebar();
    for (final drafts in _uploads.values) {
      for (final d in drafts) {
        d.cancel.cancel();
      }
    }
    _uploads.clear();
    _attempts.clear();
    _pendingSends.clear();
    _localRandomIds.clear();
    drafts.clear();
    visibleIds.clear();
    _windowState.clear();
    _windowHistoryLimited.clear();
    _diskOnlyWindows.clear();
    _threadWindows.clear();
    historyLimited = threadHistoryLimited = false;
    _contextWindows.clear();
    _revokedChannels.clear();
    _channelRowSeq.clear();
    // The new server's socket connects for the first time.
    _connectedBefore = _roomsJoinedPending = false;
    _gapSyncedThrough = null;
    highlightedMessageId = null;
    hasNewer = false;
    channels = [];
    dms = [];
    channel = null;
    threadParent = null;
    threadChannelId = null;
    _summariesByChannel.clear();
    unread = {};
    _latestActivity.clear();
    channelGeneration++;
    threadGeneration++;
    final selectionAtStart = channelGeneration,
        threadAtStart = threadGeneration,
        navigationAtStart = navigationRevision;
    notifyListeners();
    final generation = client.generation;
    final replyIdentity = _syncIdentity();
    final cached = await _cached('channels', '');
    if (generation != client.generation) return;
    if (cached is Map) {
      channels = (cached['channels'] as List)
          .map((e) => RaftChannel(Map<String, dynamic>.from(e)))
          .toList();
      dms = (cached['dms'] as List)
          .map((e) => RaftChannel(Map<String, dynamic>.from(e)))
          .toList();
      final last = await _cached('selection', '');
      final initial =
          [...channels, ...dms].where((c) => c.id == last).firstOrNull ??
          channels.where((c) => c.joined && !c.archived).firstOrNull;
      if (initial != null) {
        channel = initial;
        // A principal/role change before this point retires its summaries.
        final replyAuthority = replyIdentity == _syncIdentity()
            ? _replyToken(initial.id)
            : '';
        final page = await _cached('window', initial.id);
        if (generation != client.generation) return;
        if (_acceptCachedWindow(page, initial.id)) {
          final rows = acceptedWindowRows(page['messages'], initial.id);
          ledger.ingest(rows, expectedGeneration: ledger.generation);
          visibleIds[initial.id] = rows.map((e) => e['id'] as String).toSet();
          hasMore = page['hasMore'] == true;
          historyLimited = page['historyLimited'] == true;
          hasNewer = page['hasNewer'] == true;
          // Record the authority the disk rows were accepted under, so a
          // later selection under different facts drops them first.
          _windowState[initial.id] = (
            _windowAuthority(),
            hasMore,
            _replyToken(initial.id),
          );
          _windowHistoryLimited[initial.id] = historyLimited;
          _diskOnlyWindows.add(initial.id);
          _summariesByChannel[initial.id] = _hydrateThreadSummaries(
            page['threadSummaries'],
            initial.id,
            expectedToken: replyAuthority,
          );
          await _restoreDraft(initial.id);
        }
      }
      notifyListeners();
    }
    final cachedFrontiers = await _cached('read-frontiers', '');
    if (generation != client.generation) return;
    readState.restore(
      cachedFrontiers,
      serverId: next.id,
      principalId: client.user!.id,
    );
    final cachedUnread = await _cached('unread', '');
    if (generation != client.generation) return;
    if (cachedUnread is Map) {
      unread = {
        for (final entry in cachedUnread.entries)
          if (entry.value is int && entry.value >= 0)
            '${entry.key}': entry.value,
      };
    }
    notifyListeners();
    if (cached is Map) onHydrated?.call();
    final readGeneration = readState.generation;
    List<List<RaftChannel>> values;
    try {
      values = await Future.wait([
        client.channels(),
        client.channels(dm: true),
      ]);
    } catch (e) {
      if (e is RaftApiException &&
          e.status == 403 &&
          e.message == 'Not a member of this server' &&
          generation == client.generation) {
        revokeServer(next.id);
        await recoverMembership();
        loading = false;
        notifyListeners();
        return;
      }
      if (generation == client.generation) {
        error = '$e';
        loading = false;
        notifyListeners();
      }
      return;
    }
    if (generation != client.generation) return;
    final accessible = [...values[0], ...values[1]].map((c) => c.id).toSet();
    for (final old in [...channels, ...dms]) {
      if (!accessible.contains(old.id)) _revokeChannel(old.id);
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
      final before = _windowAuthority();
      channel = freshHeld;
      heldAuthorityChanged = before != _windowAuthority();
    }
    // The cache-painted workspace is already on screen: show the fresh lists
    // (and any revocation) now, not after the unread read below.
    notifyListeners();
    await _save('channels', '', {
      'channels': channels.map((c) => c.json).toList(),
      'dms': dms.map((c) => c.json).toList(),
    });
    for (final c in [...channels, ...dms]) {
      readState.consumeSnapshot(
        c.json['readState'],
        serverId: next.id,
        principalId: client.user!.id,
        scopeId: c.id,
        generationAtRequest: readGeneration,
      );
    }
    client.connect();
    await refreshUnread();
    final joined = channels.where((c) => c.joined && !c.archived).toList();
    if (joined.isNotEmpty &&
        selectionAtStart == channelGeneration &&
        threadAtStart == threadGeneration) {
      final selected =
          joined.where((c) => c.id == channel?.id).firstOrNull ?? joined.first;
      if (mobileNavigation && section == 'home') {
        channel = selected;
        await _restoreDraft(selected.id);
      } else {
        // A location the app root applied over the cache-painted workspace
        // (e.g. a remembered non-chat page) keeps its section.
        await selectChannel(
          selected,
          navigate: navigationAtStart == navigationRevision,
        );
      }
    } else if (heldAuthorityChanged &&
        channel != null &&
        identical(channel, freshHeld)) {
      await selectChannel(
        channel!,
        navigate: false,
        preserveThread: true,
        autoRead: false,
      );
    }
    notifyListeners();
  }

  void _persistReadState() {
    final serverId = client.serverId, principal = client.user?.id;
    if (serverId == null || principal == null) return;
    _save('read-frontiers', '', readState.exportFor(serverId, principal));
    _save('unread', '', Map.of(unread));
  }

  void _persistUnread() {
    if (client.serverId == null || client.user == null) return;
    _save('unread', '', Map.of(unread));
  }

  /// Latest activity seq per scope from the last unread snapshot; live
  /// messages raise it. Lets a read receipt clear a count without a GET.
  final Map<String, BigInt> _latestActivity = {};

  /// Source messageStore `message:new`: +1 for a conversation the member is
  /// not reading, never for the member's own message. Counts only what the
  /// unread snapshot counts (joined channels, DMs, tracked threads).
  void _receiveUnread(Map<String, dynamic> row) {
    final id = row['channelId'];
    if (id is! String || _revokedChannels.contains(id)) return;
    final seq = canonicalUint64(row['seq']);
    if (seq != null && seq > (_latestActivity[id] ?? BigInt.zero)) {
      _latestActivity[id] = seq;
    }
    // Source canAutoMarkLiveAppendRead: a live arrival in the open
    // conversation is read only if the user was just interacting; while the
    // user is idle it stays unread (Activity keeps its indicator).
    if ((id == channel?.id || id == threadChannelId) &&
        _mayMarkRead(id) &&
        RaftUserActivity.recent) {
      unawaited(markRead(id));
      return;
    }
    if (row['senderType'] == 'user' && row['senderId'] == client.user?.id) {
      return;
    }
    final known = [...channels, ...dms].where((c) => c.id == id).firstOrNull;
    final counted = known == null
        ? unread.containsKey(id)
        : known.type != 'channel' || known.joined;
    if (!counted) return;
    final serverId = client.serverId, principal = client.user?.id;
    final frontier = serverId == null || principal == null
        ? null
        : readState.state(serverId, principal, id);
    if (seq != null &&
        frontier != null &&
        BigInt.from(frontier['maxReadSeq']) >= seq) {
      return;
    }
    unread = {...unread, id: (unread[id] ?? 0) + 1};
    _persistUnread();
    unawaited(prefetchLikelyChannels());
  }

  /// Source `applyAcceptedReadStateProjection`: an accepted read frontier
  /// recounts the scope from held messages when they cover it, and clears
  /// it when it reaches the latest known activity. Otherwise the count
  /// waits for the next reconcile.
  void _projectReadState(String id) {
    final serverId = client.serverId, principal = client.user?.id;
    if (serverId == null || principal == null || !unread.containsKey(id)) {
      return;
    }
    final state = readState.state(serverId, principal, id);
    if (state == null) return;
    final maxRead = BigInt.from(state['maxReadSeq']);
    final rows = ledger.messages(id);
    var latest = _latestActivity[id];
    if (rows.isNotEmpty) {
      final last = RaftMessage(rows.last).seq;
      if (latest == null || last > latest) latest = last;
    }
    int? count;
    if (latest != null && maxRead >= latest) {
      count = 0;
    } else if (rows.isNotEmpty &&
        !_contextWindows.contains(id) &&
        !(id == channel?.id && hasNewer) &&
        RaftMessage(rows.first).seq <= maxRead) {
      count = rows
          .where(
            (row) =>
                RaftMessage(row).seq > maxRead &&
                !(row['senderType'] == 'user' && row['senderId'] == principal),
          )
          .length;
    }
    if (count == null || unread[id] == count) return;
    unread = {...unread, id: count};
  }

  Future<void> refreshUnread() async {
    final requestGeneration = readState.generation;
    final serverId = client.serverId, principal = client.user?.id;
    if (serverId == null || principal == null) return;
    try {
      final value = await client.get('/channels/unread', query: {'summary': 1});
      if (client.serverId != serverId || client.user?.id != principal) return;
      final counts = value is Map ? value['channels'] ?? value : {};
      if (counts is Map) {
        final next = <String, int>{};
        for (final e in counts.entries) {
          final id = e.key.toString(), entry = e.value;
          if (entry is num) {
            next[id] = entry.toInt();
            continue;
          }
          if (entry is! Map) continue;
          final frontier = entry['readState'];
          final outcome = readState.consumeSnapshot(
            frontier,
            serverId: serverId,
            principalId: principal,
            scopeId: id,
            generationAtRequest: requestGeneration,
            // RisingWave projects this endpoint asynchronously. An absent row
            // cannot erase a newer positive HTTP/socket acknowledgement.
            authoritativeAbsence: false,
          );
          final state = readState.state(serverId, principal, id);
          final latest = frontier is Map && frontier['latestActivity'] is Map
              ? canonicalUint64(frontier['latestActivity']['seq'])
              : null;
          if (latest != null) _latestActivity[id] = latest;
          final fullyRead =
              state != null &&
              latest != null &&
              BigInt.from(state['maxReadSeq']) >= latest;
          next[id] = fullyRead
              ? 0
              : outcome == 'corrupt'
              ? (unread[id] ?? 0)
              : ((entry['unreadCount'] ?? 0) as num).toInt();
        }
        unread = next;
        _persistReadState();
      }
      notifyListeners();
      unawaited(prefetchLikelyChannels());
    } catch (_) {
      /* Keep accepted counts through transient failures. */
    }
  }

  final _prefetched = <String>{};
  bool _prefetching = false;

  /// Loads the latest page of channels the member is likely to open next
  /// (those with unread messages) in the background, so a first open shows
  /// content at once instead of waiting for the network. Never selects,
  /// joins or marks anything read; each channel is prefetched once per
  /// session, sequentially, and only while the same account/server/role and
  /// view permission hold.
  Future<void> prefetchLikelyChannels({int limit = 6}) async {
    // Not during startup: the restored selection (possibly hidden behind
    // mobile Home) is decided first and is never prefetched.
    if (_prefetching || _disposed || loading || channel == null) return;
    _prefetching = true;
    try {
      // A window's authority is per channel (role + that channel's record).
      String authorityOf(RaftChannel c) =>
          messageWindowAuthority(server?.string('role'), c.json);
      final role = server?.string('role'),
          identity = _syncIdentity(),
          generation = ledger.generation;
      bool stillCurrent() =>
          !_disposed &&
          role == server?.string('role') &&
          identity == _syncIdentity() &&
          generation == ledger.generation;
      final candidates = [
        for (final c in [...channels, ...dms])
          if (c.id != channel?.id &&
              !_prefetched.contains(c.id) &&
              !_revokedChannels.contains(c.id) &&
              _windowState[c.id] == null &&
              (unread[c.id] ?? 0) > 0 &&
              can('viewChannel', resource: c))
            c,
      ].take(limit).toList();
      for (final c in candidates) {
        if (!stillCurrent()) return;
        _prefetched.add(c.id);
        final authority = authorityOf(c), reply = _replyToken(c.id);
        try {
          // The channel's task chips load with its first page.
          unawaited(MessageTaskCache.of(client).warm(this, c.id));
          final page = await client.messagePage(c.id);
          if (!stillCurrent() ||
              reply != _replyToken(c.id) ||
              channel?.id == c.id ||
              _windowState[c.id] != null ||
              _revokedChannels.contains(c.id) ||
              authority != authorityOf(c) ||
              !can('viewChannel', resource: c)) {
            continue;
          }
          final rows = (page['messages'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((e) => e['channelId'] == c.id && e['id'] is String)
              .toList();
          if (rows.isEmpty) continue;
          ledger.ingest(rows, expectedGeneration: generation);
          final limited = page['historyLimited'] == true;
          visibleIds[c.id] = rows.map((e) => e['id'] as String).toSet();
          _windowState[c.id] = (
            authority,
            !limited && rows.length >= 50,
            reply,
          );
          _windowHistoryLimited[c.id] = limited;
          // Reply rows are part of the window: a first open renders them in
          // the same frame as the prefetched messages.
          _summariesByChannel[c.id] = {
            ...?_summariesByChannel[c.id],
            ..._hydrateThreadSummaries(
              page['threadSummariesByParentMessageId'],
              c.id,
              expectedToken: reply,
            ),
          };
        } catch (_) {
          // Best effort: the channel opens normally on demand.
        }
      }
    } finally {
      _prefetching = false;
    }
  }

  void _revokeChannel(String id) {
    final origin = client.origin,
        principal = client.user?.id,
        serverId = client.serverId;
    final messageIds = <dynamic>{
      ...ledger.messages(id).map((m) => m['id']),
      ...threadRepliesSync.parentMessageIdsForChannel(id),
      if (_threadIdentity?.parentChannelId == id)
        _threadIdentity!.parentMessageId,
    };
    final threadIds = <String>{
      for (final message in ledger.messages(id))
        if (message['threadChannelId'] is String) message['threadChannelId'],
      for (final summary in [
        ...?_summariesByChannel[id]?.values,
        for (final bucket in _summariesByChannel.values)
          for (final messageId in messageIds) ?bucket[messageId],
      ])
        if (summary is Map &&
            messageIds.contains(summary['parentMessageId']) &&
            summary['threadChannelId'] is String)
          summary['threadChannelId'],
      if ((threadParent?.channelId == id ||
              _threadIdentity?.parentChannelId == id) &&
          threadChannelId != null)
        threadChannelId!,
    };
    for (final scope in {id, ...threadIds}) {
      _revokedChannels.add(scope);
      _attachmentImages
        ?..synchronize(attachmentImageScope)
        ..invalidateChannel(scope);
      ledger.revokeChannel(scope);
      messageSync.revokeChannel(scope);
      threadRepliesSync.revokeChannel(scope);
      notificationPrefsSync.revokeChannel(scope);
      visibleIds.remove(scope);
      _windowState.remove(scope);
      _diskOnlyWindows.remove(scope);
      _contextWindows.remove(scope);
      unread.remove(scope);
      _latestActivity.remove(scope);
      _summariesByChannel.remove(scope);
      _threadWindows.removeWhere(
        (_, window) =>
            window.parentChannelId == scope || window.threadChannelId == scope,
      );
      if (serverId != null && principal != null) {
        readState.revoke(serverId, principal, scope);
      }
      drafts.remove(scope);
      for (final draft in _uploads.remove(scope) ?? <UploadDraft>[]) {
        draft.cancel.cancel();
      }
      _attempts.remove(scope);
      _pendingSends.remove(scope);
    }
    for (final messageId in messageIds) {
      final scope = 'thread:$messageId';
      drafts.remove(scope);
      _attempts.remove(scope);
      _pendingSends.remove(scope);
      for (final draft in _uploads.remove(scope) ?? <UploadDraft>[]) {
        draft.cancel.cancel();
      }
      reactionViewer.remove(messageId);
      for (final bucket in _summariesByChannel.values) {
        bucket.remove(messageId);
      }
    }
    if (channel?.id == id) {
      channel = null;
      channelGeneration++;
    }
    if (threadParent?.channelId == id ||
        _threadIdentity?.parentChannelId == id ||
        threadIds.contains(threadChannelId)) {
      closeThread();
    }
    _persistReadState();
    if (principal != null && serverId != null) {
      _cacheWrites = _cacheWrites.then((_) async {
        try {
          for (final scope in {id, ...threadIds}) {
            await cache?.revokeChannel(origin, principal, serverId, scope);
          }
          for (final messageId in messageIds) {
            await cache?.write(
              origin,
              principal,
              serverId,
              'draft',
              'thread:$messageId',
              null,
            );
          }
        } catch (_) {
          if (!_disposed) {
            setError(
              'Revoked workspace data could not be removed from this device.',
            );
          }
        }
      });
    }
  }

  int _sidebarRequest = 0;
  Future<void> loadSidebar() async {
    final request = ++_sidebarRequest;
    final generation = client.generation, id = client.serverId;
    final authority = jsonEncode([
      client.user?.id,
      server?.id,
      server?.string('role'),
    ]);
    bool accepts() =>
        !_disposed &&
        request == _sidebarRequest &&
        generation == client.generation &&
        id == client.serverId &&
        authority ==
            jsonEncode([client.user?.id, server?.id, server?.string('role')]);
    if (id == null) return;
    final cached = await _cached('sidebar-order', '');
    if (!accepts()) return;
    if (cached is Map) {
      sidebarOrder = Map<String, dynamic>.from(cached);
      notifyListeners();
    }
    try {
      final value = await client.get('/servers/$id/sidebar-order');
      if (!accepts()) return;
      sidebarOrder = Map<String, dynamic>.from(value);
      _save('sidebar-order', '', sidebarOrder);
      notifyListeners();
    } catch (_) {
      /* Cached order remains usable while offline. */
    }
  }

  /// Read order of channel-row authority. Every list read, single-row read
  /// and realtime row patch takes the next value when it starts; a row keeps
  /// the value of whatever last wrote it. An older response therefore never
  /// overwrites a newer row, and never revokes a row added after it started.
  int _channelReadSeq = 0, _channelListSeq = 0;
  final Map<String, int> _channelRowSeq = {};

  /// Full channel and DM list reload (Source `loadChannels` +
  /// `loadDMChannels`): server selection, `rooms:joined`, a role change, or a
  /// channel event without an id. Unchanged rows keep their objects.
  Future<void> refreshChannels() async {
    final generation = ledger.generation;
    final read = ++_channelReadSeq;
    try {
      final lists = await Future.wait([
        client.channels(),
        client.channels(dm: true),
      ]);
      if (generation != ledger.generation || _disposed) return;
      // A list read that started later has already been applied.
      if (read < _channelListSeq) return;
      _channelListSeq = read;
      // Rows written after this read started keep their current state.
      final newer = {
        for (final entry in _channelRowSeq.entries)
          if (entry.value > read) entry.key,
      };
      _channelRowSeq.removeWhere((_, seq) => seq <= read);
      List<RaftChannel> merge(
        List<RaftChannel> fetched,
        List<RaftChannel> current,
      ) {
        final held = {for (final c in current) c.id: c};
        final fetchedIds = {for (final c in fetched) c.id};
        final next = [
          for (final c in fetched)
            if (!newer.contains(c.id))
              _reuseChannelRow(held[c.id], c)
            else if (held[c.id] != null)
              held[c.id]!,
        ];
        // A row added after this read started keeps its held position.
        for (var i = 0; i < current.length; i++) {
          final c = current[i];
          if (newer.contains(c.id) && !fetchedIds.contains(c.id)) {
            next.insert(i < next.length ? i : next.length, c);
          }
        }
        return next;
      }

      _acceptChannelLists(
        merge(lists[0], channels),
        merge(lists[1], dms),
        readmit: {
          for (final c in [...lists[0], ...lists[1]])
            if (!newer.contains(c.id)) c.id,
        },
      );
    } catch (e) {
      if (generation == ledger.generation && !_disposed) setError('$e');
    }
  }

  /// The one place channel lists change after selection. A row missing from
  /// the next lists lost access and is revoked; [readmit] are rows the
  /// server just confirmed readable.
  void _acceptChannelLists(
    List<RaftChannel> nextChannels,
    List<RaftChannel> nextDms, {
    required Set<String> readmit,
  }) {
    final accessible = {
      for (final c in [...nextChannels, ...nextDms]) c.id,
    };
    for (final old in [...channels, ...dms]) {
      if (!accessible.contains(old.id)) _revokeChannel(old.id);
    }
    _revokedChannels.removeAll(readmit);
    channels = nextChannels;
    dms = nextDms;
    _save('channels', '', {
      'channels': channels.map((c) => c.json).toList(),
      'dms': dms.map((c) => c.json).toList(),
    });
    if (channel != null) {
      channel = [
        ...channels,
        ...dms,
      ].where((c) => c.id == channel!.id).firstOrNull;
      if (channel == null) {
        if (threadChannelId != null) ledger.revokeChannel(threadChannelId!);
        closeThread();
        channelGeneration++;
      }
    }
    notifyListeners();
  }

  /// A refreshed row equal to the held one keeps the held object, so sidebar
  /// rows and the open channel do not rebuild for an unchanged read.
  static RaftChannel _reuseChannelRow(RaftChannel? held, RaftChannel fresh) {
    if (held == null) return fresh;
    try {
      return jsonEncode(held.json) == jsonEncode(fresh.json) ? held : fresh;
    } catch (_) {
      return fresh;
    }
  }

  /// Whether the server's channel lists carry [row] for this viewer: private
  /// and joint channels only for members (`requiresExplicitMembership`).
  static bool _listsChannel(RaftChannel row) =>
      !const {'private', 'joint'}.contains(row.type) || row.joined;

  /// Replaces [next]'s row in place, or adds it (a new DM goes first, as the
  /// server's recency-ordered DM list would place it).
  void _putChannelRow(RaftChannel next) {
    final held = [...channels, ...dms].where((c) => c.id == next.id);
    if (held.length == 1 && identical(held.single, next)) return;
    final dm = next.type == 'dm';
    List<RaftChannel> put(List<RaftChannel> list, bool owns) {
      final index = list.indexWhere((c) => c.id == next.id);
      if (!owns) return index < 0 ? list : ([...list]..removeAt(index));
      if (index >= 0) return [...list]..[index] = next;
      return dm ? [next, ...list] : [...list, next];
    }

    _acceptChannelLists(put(channels, !dm), put(dms, dm), readmit: {next.id});
  }

  static String? _payloadChannelId(dynamic payload) {
    if (payload is! Map) return null;
    final id = payload['channelId'] ?? payload['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Source `readApiChannel`: `{channel: row}` or a bare row with a name.
  static Map<String, dynamic>? _payloadChannelRow(dynamic payload) {
    if (payload is! Map) return null;
    final candidate = payload.containsKey('channel')
        ? payload['channel']
        : payload;
    if (candidate is! Map ||
        candidate['id'] is! String ||
        candidate['name'] is! String) {
      return null;
    }
    return Map<String, dynamic>.from(candidate);
  }

  /// Source channelRealtimeSync: a channel event changes one row. A carried
  /// row is patched in place; an id re-reads that one channel; only an event
  /// without an id reloads both lists.
  void _channelRealtime(String name, dynamic payload) {
    if (name == 'channel:updated') {
      final row = _payloadChannelRow(payload);
      if (row != null) {
        // A user-room event can carry another server's joint-channel row.
        final serverId = row['serverId'];
        if (serverId is String &&
            client.serverId != null &&
            serverId != client.serverId) {
          return;
        }
        _patchChannelRow(row);
        return;
      }
    }
    final id = _payloadChannelId(payload);
    if (id == null) {
      if (name != 'dm:new') unawaited(refreshChannels());
      return;
    }
    if (name == 'dm:new') {
      client.joinChannel(id);
      // Source addOrRefreshDM: a held DM moves first without a read.
      final index = dms.indexWhere((c) => c.id == id);
      if (index >= 0 && !_revokedChannels.contains(id)) {
        if (index > 0) {
          _acceptChannelLists(channels, [
            dms[index],
            for (var i = 0; i < dms.length; i++)
              if (i != index) dms[i],
          ], readmit: const {});
        }
        return;
      }
    }
    unawaited(refreshChannel(id));
  }

  void _patchChannelRow(Map<String, dynamic> patch) {
    final id = patch['id'] as String;
    final held = [...channels, ...dms].where((c) => c.id == id).firstOrNull;
    // A projection lacks viewer fields (membership, capabilities): an unknown
    // or revoked row is read once instead of trusted.
    if (held == null || _revokedChannels.contains(id)) {
      unawaited(refreshChannel(id));
      return;
    }
    final next = _reuseChannelRow(held, RaftChannel({...held.json, ...patch}));
    if (!_listsChannel(next) || next.type == 'thread') {
      unawaited(refreshChannel(id));
      return;
    }
    _channelRowSeq[id] = ++_channelReadSeq;
    _putChannelRow(next);
  }

  final Map<String, Future<void>> _channelReads = {};
  final Set<String> _channelRereads = {};

  /// Source `ensureChannel(id, {refresh: true})`: reads one channel and
  /// upserts its row. Lost access (403/404, or a private row the lists would
  /// not carry) revokes that channel through the list revocation path.
  Future<void> refreshChannel(String id) {
    final pending = _channelReads[id];
    if (pending != null) {
      // The read in flight may predate this change: read once more after it.
      _channelRereads.add(id);
      return pending;
    }
    final read = _readChannel(id).whenComplete(() {
      _channelReads.remove(id);
      if (_channelRereads.remove(id) && !_disposed) {
        unawaited(refreshChannel(id));
      }
    });
    return _channelReads[id] = read;
  }

  Future<void> _readChannel(String id) async {
    final generation = ledger.generation, identity = _syncIdentity();
    final read = ++_channelReadSeq;
    bool current() =>
        !_disposed &&
        generation == ledger.generation &&
        identity == _syncIdentity() &&
        read > _channelListSeq &&
        read > (_channelRowSeq[id] ?? 0);
    RaftChannel? fresh;
    try {
      final data = await client.get('/channels/$id');
      if (!current() || data is! Map || data['id'] != id) return;
      fresh = RaftChannel(Map<String, dynamic>.from(data));
      if (fresh.type == 'thread') return;
      final serverId = fresh.json['serverId'];
      if (serverId is String && serverId != client.serverId) fresh = null;
    } on RaftApiException catch (e) {
      if (!current() || (e.status != 403 && e.status != 404)) return;
    } catch (_) {
      // Transient failure: the held row stays until a later read.
      return;
    }
    _channelRowSeq[id] = read;
    final held = [...channels, ...dms].where((c) => c.id == id).firstOrNull;
    if (fresh != null && _listsChannel(fresh)) {
      _putChannelRow(_reuseChannelRow(held, fresh));
    } else if (held != null) {
      _acceptChannelLists(
        channels.where((c) => c.id != id).toList(),
        dms.where((c) => c.id != id).toList(),
        readmit: const {},
      );
    }
  }

  bool _roomsJoinedPending = false, _connectedBefore = false;
  DateTime? _lastHeartbeat, _lastServerEvent;
  (int, BigInt)? _gapSyncedThrough;

  /// Source socketBridge `roomsJoined`: the server joined this socket's
  /// rooms, so missed messages can be resumed and the lists re-read.
  void _roomsJoined() {
    _roomsJoinedPending = false;
    if (ledger.watermark > BigInt.zero) client.resume(ledger.watermark);
    unawaited(syncVisibleScopes());
    unawaited(refreshChannels());
    unawaited(refreshUnread());
  }

  /// Source `recordHeartbeat`: a server seq past the ledger watermark means
  /// a push was missed; the visible scopes read their gap.
  void _heartbeat(dynamic payload) {
    _lastHeartbeat = DateTime.now();
    // A lost `rooms:joined`: the connection's first heartbeat stands in.
    if (_roomsJoinedPending) {
      _roomsJoined();
      return;
    }
    final seq = payload is Map ? BigInt.tryParse('${payload['seq']}') : null;
    final synced = _gapSyncedThrough;
    if (seq == null ||
        seq <= ledger.watermark ||
        synced != null && synced.$1 == ledger.generation && seq <= synced.$2) {
      return;
    }
    unawaited(syncVisibleScopes(through: seq));
  }

  /// Source `recoverLiveSession` on return to the foreground: reconnect a
  /// dropped or silent socket (its `rooms:joined` resumes and gap-syncs), or
  /// resume and gap-sync on the live one; then refresh live counts.
  void resumeLiveSession() {
    if (_disposed || !ownsClient || client.serverId == null) return;
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
      if (ledger.watermark > BigInt.zero) client.resume(ledger.watermark);
      unawaited(syncVisibleScopes());
    }
    unawaited(refreshUnread());
    loadSidebar();
    if (entityDirectory.started) entityDirectory.revalidateAuthors();
  }

  static const _gapPageLimit = 200;
  bool _gapSyncing = false;

  /// Source `syncVisibleScopes`: the open thread and the presented channel
  /// tail each read the messages after their newest row and append them to
  /// the held window. Nothing is cleared or reloaded.
  Future<void> syncVisibleScopes({BigInt? through}) async {
    if (_gapSyncing || _disposed) return;
    final thread = threadChannelId, main = channel?.id;
    final targets = [
      if (thread != null && !threadLoading) thread,
      if (main != null &&
          main != thread &&
          !hasNewer &&
          !channelLoading &&
          pendingMessageContextChannelId != main)
        main,
    ];
    if (targets.isEmpty) return;
    final generation = ledger.generation;
    var complete = true;
    _gapSyncing = true;
    try {
      for (final id in targets) {
        if (!await _syncGap(id)) complete = false;
      }
    } finally {
      _gapSyncing = false;
    }
    if (complete && through != null && generation == ledger.generation) {
      _gapSyncedThrough = (generation, through);
    }
  }

  Future<bool> _syncGap(String id) async {
    final thread = id == threadChannelId;
    var cursor = BigInt.zero;
    for (final row in ledger.messages(id)) {
      if (visibleIds[id]?.contains(row['id']) != true) continue;
      final seq = RaftMessage(row).seq;
      if (seq > cursor) cursor = seq;
    }
    if (cursor == BigInt.zero) return true;
    final generation = ledger.generation,
        window = thread ? threadGeneration : channelGeneration,
        owner = thread ? threadParentChannelId : id,
        reply = _replyToken(owner),
        authority = _windowAuthority();
    bool current() =>
        !_disposed &&
        generation == ledger.generation &&
        window == (thread ? threadGeneration : channelGeneration) &&
        reply == _replyToken(owner) &&
        authority == _windowAuthority() &&
        !_revokedChannels.contains(id) &&
        (thread ? threadChannelId == id : channel?.id == id && !hasNewer);
    try {
      while (true) {
        final page = await client.get(
          '/messages/sync',
          query: {
            'since_seq': '$cursor',
            'channel_id': id,
            'limit': _gapPageLimit,
          },
        );
        if (!current()) return false;
        final listed = page is List ? page : const [];
        final rows = [
          for (final row in listed.whereType<Map>())
            if (row['channelId'] == id && row['id'] is String)
              Map<String, dynamic>.from(row),
        ];
        if (rows.isEmpty) break;
        final arrived = [
          for (final row in rows)
            if (!ledger.contains(id, row['id'] as String)) row,
        ];
        ledger.ingest(rows, expectedGeneration: generation);
        visibleIds
            .putIfAbsent(id, () => {})
            .addAll(rows.map((row) => row['id'] as String));
        var next = cursor;
        for (final row in rows) {
          final seq = RaftMessage(row).seq;
          if (seq > next) next = seq;
        }
        if (_mayMarkRead(id)) {
          unawaited(markRead(id));
        } else {
          arrived.forEach(_receiveUnread);
        }
        unawaited(_saveWindow(id, thread: thread));
        notifyListeners();
        if (listed.length < _gapPageLimit || next <= cursor) break;
        cursor = next;
      }
      return true;
    } on RaftApiException catch (e) {
      // Lost access is decided by the channel read and its revocation path.
      if (current() && owner != null && (e.status == 403 || e.status == 404)) {
        unawaited(refreshChannel(owner));
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  int _membershipRevision = 0, _membershipRequest = 0;

  bool canVisitSection(String name) {
    final capability = const {
      'agents': 'viewAgents',
      'computers': 'viewMachines',
      'members': 'viewMembers',
      'providers': 'manageExternalAuth',
      'integrations': 'manageIntegrations',
      'im-bridges': 'manageIntegrations',
      'joint-channels': 'federateChannels',
      'administration': 'viewServerSettings',
      'billing': 'viewBilling',
      'workspace-settings': 'viewServerSettings',
    }[name];
    if (capability != null) return can(capability);
    return const {
      'home',
      'chat',
      'activity',
      'search',
      'saved',
      'tasks',
      'settings',
      'sidebar-settings',
    }.contains(name);
  }

  /// Apply the mounted receiver's own authoritative role event synchronously.
  /// Any earlier HTTP membership snapshot loses its request revision fence.
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
      server = RaftRecord({...server!.json, 'role': role});
      _ensureSyncIdentity();
      refreshMessageSyncFlag();
      if (!canVisitSection(section)) section = 'chat';
    }
    _save('servers', '', servers.map((s) => s.json).toList(), server: '');
    notifyListeners();
  }

  Future<void> recoverMembership() async {
    if (!ownsClient) return;
    final generation = client.generation,
        request = ++_membershipRequest,
        revision = _membershipRevision;
    try {
      final current = await client.servers();
      if (generation != client.generation ||
          _disposed ||
          request != _membershipRequest ||
          revision != _membershipRevision) {
        return;
      }
      _revokedServers.removeAll(current.map((s) => s.id));
      servers = current;
      await _save(
        'servers',
        '',
        current.map((s) => s.json).toList(),
        server: '',
      );
      if (server != null && !current.any((s) => s.id == server!.id)) {
        revokeServer(server!.id);
        await flushCache();
      }
      if (server == null && current.isNotEmpty) {
        await selectServer(current.first);
      }
      if (server != null) {
        server = current.where((s) => s.id == server!.id).firstOrNull;
        if (!canVisitSection(section)) section = 'chat';
      }
      notifyListeners();
    } catch (e) {
      if (!_disposed) setError('$e');
    }
  }

  bool _rejectRevokedConversation(String id) {
    if (_disposed || !_revokedChannels.contains(id)) return false;
    if (location.entityId == id) {
      _missingConversationChannelId = id;
      _resolvingConversationChannelId = null;
      notifyListeners();
    }
    return true;
  }

  String? _resolvingConversationChannelId, _missingConversationChannelId;
  int _conversationResolutionRequest = 0;
  String? get missingConversationChannelId => _missingConversationChannelId;

  /// MainLayout ChannelById/ensureChannel: hydrate a real channel without
  /// treating the thread's focused reply as a message in its parent channel.
  /// URI, principal/server epoch and request ownership fence late arrival.
  Future<void> resolveConversationChannel(
    String id, {
    bool preserveThread = false,
  }) async {
    final request = ++_conversationResolutionRequest,
        revision = navigationRevision,
        scope = navigationAuthority,
        reply = _replyToken(id),
        generation = ledger.generation;
    bool current() =>
        !_disposed &&
        request == _conversationResolutionRequest &&
        revision == navigationRevision &&
        scope == navigationAuthority &&
        reply == _replyToken(id) &&
        generation == ledger.generation &&
        !_revokedChannels.contains(id);
    if (_disposed ||
        _rejectRevokedConversation(id) ||
        id.isEmpty ||
        !can('viewChannel')) {
      return;
    }
    _resolvingConversationChannelId = id;
    _missingConversationChannelId = null;
    notifyListeners();
    try {
      var real = [...channels, ...dms].where((c) => c.id == id).firstOrNull;
      if (real == null) {
        final data = await client.get('/channels/$id');
        if (!current()) return;
        if (data is! Map ||
            data['id'] != id ||
            data['serverId'] != null && data['serverId'] != server?.id) {
          throw const RaftApiException('This channel is not available.');
        }
        real = RaftChannel(Map<String, dynamic>.from(data));
        if (!can('viewChannel', resource: real)) return;
        if (real.type == 'dm') {
          dms = [...dms.where((c) => c.id != id), real];
        } else {
          channels = [...channels.where((c) => c.id != id), real];
        }
      }
      if (!current() || !can('viewChannel', resource: real)) return;
      await selectChannel(
        real,
        navigate: false,
        preserveThread: preserveThread,
      );
    } catch (_) {
      if (current()) _missingConversationChannelId = id;
    } finally {
      if (current() && _resolvingConversationChannelId == id) {
        _resolvingConversationChannelId = null;
        notifyListeners();
      }
    }
  }

  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
  }) async {
    final retainThread =
        preserveThread &&
        threadIdentity?.parentChannelId == next.id &&
        location.thread?.channelId == next.id;
    channel = next;
    hasNewer = false;
    if (!retainThread) highlightedMessageId = null;
    final priorWindow = _windowState[next.id];
    final replyAuthority = _replyToken(next.id);
    if (priorWindow != null &&
        (priorWindow.$1 != _windowAuthority() ||
            priorWindow.$3 != replyAuthority)) {
      visibleIds.remove(next.id);
      _windowState.remove(next.id);
      _diskOnlyWindows.remove(next.id);
      _windowHistoryLimited.remove(next.id);
      _summariesByChannel.remove(next.id);
    }
    hasMore =
        priorWindow != null &&
        priorWindow.$1 == _windowAuthority() &&
        priorWindow.$3 == replyAuthority &&
        priorWindow.$2;
    historyLimited =
        priorWindow != null &&
            priorWindow.$1 == _windowAuthority() &&
            priorWindow.$3 == replyAuthority
        ? _windowHistoryLimited[next.id] == true
        : false;
    if (_contextWindows.remove(next.id) && !retainContextUntilAccepted) {
      visibleIds.remove(next.id);
    }
    if (navigate) section = 'chat';
    if (!retainThread) {
      threadParent = null;
      threadChannelId = null;
      threadGeneration++;
    }
    loadingOlder = false;
    channelLoading = true;
    error = null;
    final window = ++channelGeneration;
    final generation = ledger.generation;
    final authority = _windowAuthority();
    final navigationWindow = navigationRevision;
    bool current() =>
        !_disposed &&
        window == channelGeneration &&
        navigationWindow == navigationRevision &&
        generation == ledger.generation &&
        channel?.id == next.id &&
        authority == _windowAuthority() &&
        replyAuthority == _replyToken(next.id) &&
        !_revokedChannels.contains(next.id) &&
        can('viewChannel', resource: channel);
    notifyListeners();
    // Source ChatPanel loads the channel's tasks with its messages: start the
    // bucket read now so the chips are cached when the rows first render.
    unawaited(MessageTaskCache.of(client).warm(this, next.id));
    await _restoreDraft(next.id);
    if (!current()) return;
    try {
      final page = retainContextUntilAccepted
          ? null
          : await _cached('window', next.id);
      if (!current()) return;
      if (_acceptCachedWindow(page, next.id)) {
        final rows = acceptedWindowRows(page['messages'], next.id);
        // The ledger may be newer than disk after a live event. Ingest applies
        // its canonical versions/tombstones; visibility is never raw cache data.
        ledger.ingest(rows, expectedGeneration: generation);
        visibleIds
            .putIfAbsent(next.id, () => {})
            .addAll(rows.map((e) => e['id'] as String));
        hasMore = page['hasMore'] == true;
        historyLimited = page['historyLimited'] == true;
        _windowState[next.id] = (authority, hasMore, replyAuthority);
        _windowHistoryLimited[next.id] = historyLimited;
        _diskOnlyWindows.add(next.id);
        // Memory is never older than disk: held summaries win.
        _summariesByChannel[next.id] = {
          ..._hydrateThreadSummaries(
            page['threadSummaries'],
            next.id,
            expectedToken: replyAuthority,
          ),
          ...?_summariesByChannel[next.id],
        };
        notifyListeners();
      }
      final retained = retainContextUntilAccepted
          ? <Map<String, dynamic>>[]
          : messages.map((m) => m.json).toList();
      final retainedHasMore = hasMore;
      client.joinChannel(next.id);
      final fresh = await client.messagePage(next.id);
      if (!current()) return;
      final rows = (fresh['messages'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      ledger.ingest(rows, expectedGeneration: generation);
      _diskOnlyWindows.remove(next.id);
      historyLimited = fresh['historyLimited'] == true;
      visibleIds[next.id] = fresh['historyLimited'] == true
          ? rows.map((e) => e['id'] as String).toSet()
          : reconcileTailWindow(retained, rows);
      final held = _summariesByChannel[next.id] ?? const {};
      _summariesByChannel[next.id] = {
        for (final row in retained)
          if (held[row['id']] != null) row['id'] as String: held[row['id']],
        ..._hydrateThreadSummaries(
          fresh['threadSummariesByParentMessageId'],
          next.id,
          expectedToken: replyAuthority,
        ),
      };
      hasMore =
          fresh['historyLimited'] != true &&
          (visibleIds[next.id]!.length > rows.length
              ? retainedHasMore
              : rows.length >= 50);
      channelLoading = false;
      notifyListeners();
      await _saveWindow(next.id);
      if (!current()) return;
      await _save('selection', '', next.id);
      if (current() && autoRead) await markRead(next.id);
    } catch (e) {
      if (current()) {
        if (e is RaftApiException && (e.status == 403 || e.status == 404)) {
          _revokeChannel(next.id);
        } else {
          error = '$e';
        }
      }
    } finally {
      if (current()) {
        channelLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> older({bool thread = false}) async {
    final current = thread ? replies : messages;
    if (loadingOlder ||
        (thread ? !threadHasMore : !hasMore) ||
        current.isEmpty) {
      return;
    }
    loadingOlder = true;
    final id = thread ? threadChannelId! : channel!.id;
    final window = thread ? threadGeneration : channelGeneration;
    final generation = ledger.generation;
    final owner = thread ? threadParentChannelId : id;
    final replyAuthority = _replyToken(owner);
    final authority = _windowAuthority();
    bool currentWindow() =>
        !_disposed &&
        window == (thread ? threadGeneration : channelGeneration) &&
        generation == ledger.generation &&
        authority == _windowAuthority() &&
        replyAuthority == _replyToken(owner) &&
        !_revokedChannels.contains(id);
    notifyListeners();
    try {
      final page = await client.messagePage(id, before: current.first.seq);
      if (!currentWindow()) {
        return;
      }
      final rows = (page['messages'] as List);
      ledger.ingest(
        rows.map((e) => Map<String, dynamic>.from(e)),
        expectedGeneration: generation,
      );
      visibleIds
          .putIfAbsent(id, () => {})
          .addAll(rows.map((e) => e['id'] as String));
      if (thread) {
        threadHistoryLimited = page['historyLimited'] == true;
        threadHasMore = !threadHistoryLimited && rows.length >= 50;
      } else {
        historyLimited = page['historyLimited'] == true;
        hasMore = !historyLimited && rows.length >= 50;
      }
      if (!thread) {
        _summariesByChannel
            .putIfAbsent(id, () => {})
            .addAll(
              _hydrateThreadSummaries(
                page['threadSummariesByParentMessageId'],
                id,
                expectedToken: replyAuthority,
              ),
            );
      }
      await _saveWindow(id, thread: thread);
    } catch (e) {
      if (currentWindow()) error = '$e';
    } finally {
      if (currentWindow()) {
        loadingOlder = false;
        notifyListeners();
      }
    }
  }

  bool _mayMarkRead(String id) {
    if (!foreground ||
        id == channel?.id &&
            (!_mainPresented ||
                !_chatTabPresented ||
                hasNewer ||
                channelLoading) ||
        id == threadChannelId && !_threadPresented ||
        id != channel?.id && id != threadChannelId) {
      return false;
    }
    final current = location;
    // Source mobile thread folds the parent channel immediately from the URI.
    // A prior Activity layout callback cannot admit its concurrently loaded tail.
    if (id == channel?.id && mobileNavigation && current.thread != null) {
      return false;
    }
    final content = current.content;
    final mainRoute =
        (current.route == RaftRoute.channel || current.route == RaftRoute.dm) &&
        current.entityId == channel?.id;
    final previewMounted =
        current.route == RaftRoute.search ||
        current.route == RaftRoute.activity;
    final mainPreview =
        previewMounted &&
        (content?.kind == RaftContentKind.channel ||
            content?.kind == RaftContentKind.dm) &&
        content?.id == channel?.id;
    final threadRoute =
        current.thread?.channelId == threadParentChannelId &&
        current.thread?.itemId == threadParentMessageId &&
        current.thread != null;
    final threadPreview =
        previewMounted &&
        content?.kind == RaftContentKind.thread &&
        content?.id == threadChannelId;
    return id == channel?.id
        ? mainRoute || mainPreview
        : id == threadChannelId && (threadRoute || threadPreview);
  }

  /// Windows painted from disk whose first fresh page has not arrived yet.
  /// Their tail may be stale, so they never send a read receipt (nor clear
  /// the unread count) until revalidated.
  final Set<String> _diskOnlyWindows = {};

  Future<void> markRead(String id) async {
    if (!foreground ||
        _diskOnlyWindows.contains(id) ||
        id == channel?.id && (!_mainPresented || !_chatTabPresented) ||
        id == threadChannelId && !_threadPresented ||
        !_mayMarkRead(id) ||
        id != channel?.id && id != threadChannelId ||
        id == channel?.id && hasNewer) {
      return;
    }
    final rows = ledger
        .messages(id)
        .where((m) => visibleIds[id]?.contains(m['id']) ?? false)
        .toList();
    if (rows.isEmpty) return;
    final origin = client.origin,
        principal = client.user?.id,
        serverId = client.serverId,
        generation = ledger.generation;
    final window = id == threadChannelId ? threadGeneration : channelGeneration;
    try {
      final receipt = await client.post(
        '/channels/$id/read',
        data: {'seq': rows.last['seq']},
      );
      if (client.origin != origin ||
          client.user?.id != principal ||
          client.serverId != serverId ||
          ledger.generation != generation ||
          window !=
              (id == threadChannelId ? threadGeneration : channelGeneration) ||
          !_mayMarkRead(id)) {
        return;
      }
      if (receipt is Map && client.serverId != null && client.user != null) {
        readState.consumeUpdate(
          {
            'serverId': client.serverId,
            'scopeId': id,
            'maxReadSeq': receipt['maxReadSeq'],
            'readStateVersion': receipt['readStateVersion'],
          },
          serverId: client.serverId!,
          principalId: client.user!.id,
        );
      }
      // Source clearUnread: the read tail is the latest; no snapshot GET.
      if ((unread[id] ?? 0) != 0) unread = {...unread, id: 0};
      _persistReadState();
      notifyListeners();
    } catch (_) {}
  }

  /// Source acceptActivityReadAllAck: an Activity row's persisted read-all
  /// receipt is a read-state fact for [scopeId]. Folding it into the ledger is
  /// what keeps a stale inbox response from re-presenting the row as unread.
  /// Returns false for an invalid receipt or a changed identity.
  bool acceptReadAllAck(
    String scopeId,
    dynamic receipt, {
    required String serverId,
    required String principalId,
  }) {
    if (client.serverId != serverId || client.user?.id != principalId) {
      return false;
    }
    if (receipt is! Map) return false;
    final outcome = readState.consumeUpdate(
      {
        'serverId': serverId,
        'scopeId': scopeId,
        'maxReadSeq': receipt['maxReadSeq'] ?? receipt['seq'],
        'readStateVersion': receipt['readStateVersion'],
      },
      serverId: serverId,
      principalId: principalId,
    );
    if (outcome == 'corrupt') return false;
    if ((unread[scopeId] ?? 0) != 0) unread = {...unread, scopeId: 0};
    _persistReadState();
    notifyListeners();
    return true;
  }

  Future<bool> send(
    String text, {
    bool thread = false,
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    void Function(int window)? onWindowRefreshed,
  }) async {
    if (conversationPaused) {
      error = 'Channel conversion in progress';
      notifyListeners();
      return false;
    }
    error = null;
    final generation = ledger.generation;
    final principal = client.user?.id, serverId = client.serverId;
    final origin = client.origin, clientGeneration = client.generation;
    final intendedScope = draftScope(thread: thread);
    final intendedChannel = channel?.id, intendedParent = threadParentMessageId;
    final role = server?.string('role');
    var window = thread ? threadGeneration : channelGeneration;
    final selectedAttachments = attachments == null
        ? null
        : List<String>.unmodifiable(attachments);
    bool sameAccount() =>
        !_disposed &&
        generation == ledger.generation &&
        principal == client.user?.id &&
        serverId == client.serverId &&
        origin == client.origin &&
        clientGeneration == client.generation &&
        !_revokedChannels.contains(intendedChannel);
    bool currentSend() =>
        sameAccount() &&
        intendedScope == draftScope(thread: thread) &&
        intendedChannel == channel?.id &&
        (!thread || intendedParent == threadParentMessageId) &&
        window == (thread ? threadGeneration : channelGeneration) &&
        role == server?.string('role') &&
        !conversationPaused;
    final selectedMentions = [
      for (final mention in mentions ?? <Map<String, dynamic>>[])
        Map<String, dynamic>.unmodifiable({
          'type': mention['type'],
          'id': mention['id'],
          'name': mention['name'],
        }),
    ];
    if (intendedScope == null) return false;
    final scope = intendedScope;
    final uploaded = List<UploadDraft>.of(uploads(thread: thread));
    if (uploaded.any((u) => u.id == null)) {
      error =
          '${const RaftApiException('Wait for uploads to finish, or remove the failed file.')}';
      notifyListeners();
      return false;
    }
    final ids = selectedAttachments ?? uploaded.map((u) => u.id!).toList();
    final fingerprint = jsonEncode([
      text,
      ids,
      if (selectedMentions.isNotEmpty) selectedMentions,
      if (asTask) true,
    ]);
    // A failed send keeps its randomId so retrying the same draft cannot
    // duplicate a message the server did accept. A second send of the same
    // text while the first is still in flight is a new message.
    final retained = _attempts[scope];
    final freshAttempt =
        retained == null ||
        retained.fingerprint != fingerprint ||
        (_pendingSends[scope]?.any((p) => p.randomId == retained.randomId) ??
            false);
    final attempt = freshAttempt
        ? _SendAttempt(fingerprint, randomId ?? client.newRandomId())
        : retained;
    _attempts[scope] = attempt;
    final sentId = attempt.randomId;
    // Web MessageInput: the optimistic row appears and the composer's files
    // leave with it before any request; a failure gives both back.
    final user = client.user;
    final selectedUploads = [
      for (final upload in uploaded)
        if (ids.contains(upload.id)) upload,
    ];
    final pending = _PendingSend(
      sentId,
      {
        'id': 'optimistic-$sentId',
        'randomId': sentId,
        'channelId': thread ? threadChannelId : intendedChannel,
        'senderId': user?.id ?? '',
        'senderType': 'user',
        'senderName': user?.name ?? '',
        'messageType': 'chat',
        'content': text,
        if (selectedMentions.isNotEmpty) 'mentions': selectedMentions,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        if (selectedUploads.isNotEmpty)
          'attachments': [
            for (final upload in selectedUploads)
              upload.metadata ??
                  {
                    'id': upload.id,
                    'filename': upload.filename,
                    'sizeBytes': upload.bytes.length,
                  },
          ],
        'pendingSend': true,
      },
      text,
      selectedUploads,
    );
    (_pendingSends[scope] ??= []).add(pending);
    _localRandomIds.add(sentId);
    if (selectedUploads.isNotEmpty) {
      _uploads[scope]?.removeWhere(selectedUploads.contains);
      if (_uploads[scope]?.isEmpty ?? false) _uploads.remove(scope);
    }
    notifyListeners();

    void settle() {
      final list = _pendingSends[scope];
      list?.remove(pending);
      if (list != null && list.isEmpty) _pendingSends.remove(scope);
    }

    bool delivered(String? id) =>
        id != null &&
        ledger.messages(id).any((row) => row['randomId'] == sentId);

    // Web `restoreFailedSendDraft`: restore into the scope that owned the
    // send, never into whichever conversation is current now.
    bool fail([Object? cause]) {
      settle();
      if (sameAccount()) {
        final restored = _mergeFailedSendIntoDraft(
          pending.draft,
          drafts[scope] ?? '',
        );
        drafts[scope] = restored;
        _save('draft', scope, {'text': restored, 'channelId': intendedChannel});
        if (pending.uploads.isNotEmpty) {
          _uploads[scope] = [...pending.uploads, ...?_uploads[scope]];
        }
        if (cause != null && currentSend()) error = '$cause';
      }
      notifyListeners();
      return false;
    }

    try {
      if (!thread && hasNewer && channel != null) {
        final refreshing = selectChannel(channel!);
        // selectChannel starts synchronously. Only this intentional refresh may
        // advance the window; navigation during its awaits must cancel send.
        window = channelGeneration;
        await refreshing;
        if (!currentSend()) return fail();
        onWindowRefreshed?.call(window);
      }
      if (!currentSend()) return fail();
      final id = thread ? await ensureThread() : intendedChannel;
      if (id == null || !currentSend()) return fail();
      if (freshAttempt) {
        await _save('attempt', scope, {
          'fingerprint': fingerprint,
          'randomId': sentId,
          'channelId': channel?.id,
        });
      }
      if (!currentSend()) return fail();
      final sent = await client.sendWithReceipt(
        id,
        text,
        attachments: ids,
        mentions: selectedMentions.isEmpty ? null : selectedMentions,
        randomId: sentId,
        asTask: asTask,
      );
      final message = sent.message;
      settle();
      if (_attempts[scope]?.randomId == sentId) {
        _attempts.remove(scope);
        _save('attempt', scope, null);
      }
      if (!currentSend()) {
        notifyListeners();
        return true;
      }
      // Web MessageInput replaces the strip with each send's receipt.
      pendingMentionActions[scope] = normalizePendingMentionActions(
        sent.receipt['pendingMentionActions'],
      );
      ledger.ingest([
        {...message.json, 'randomId': message.json['randomId'] ?? sentId},
      ], expectedGeneration: generation);
      visibleIds.putIfAbsent(id, () => {}).add(message.id);
      _saveWindow(id, thread: thread);
      notifyListeners();
      return true;
    } catch (e) {
      // The socket echo already presented the accepted copy.
      if (sameAccount() &&
          delivered(thread ? threadChannelId : intendedChannel)) {
        settle();
        notifyListeners();
        return true;
      }
      return fail(e);
    }
  }

  Future<String?> ensureThread() async {
    if (threadChannelId != null) return threadChannelId;
    if (_creatingThreadWindow == threadGeneration && _creatingThread != null) {
      return _creatingThread;
    }
    final window = threadGeneration;
    _creatingThreadWindow = window;
    final pending = _createThread();
    _creatingThread = pending;
    try {
      return await pending;
    } finally {
      if (_creatingThreadWindow == window) {
        _creatingThread = null;
        _creatingThreadWindow = null;
      }
    }
  }

  Future<String?> _createThread() async {
    final parentId = threadParentMessageId,
        parentChannelId = threadParentChannelId;
    if (parentId == null || parentChannelId == null) return null;
    final generation = ledger.generation, window = threadGeneration;
    final navigationWindow = navigationRevision,
        token = _replyToken(parentChannelId),
        authority = _windowAuthority();
    final value = await client.post(
      '/channels/$parentChannelId/threads',
      data: {'parentMessageId': parentId},
    );
    if (generation != ledger.generation ||
        window != threadGeneration ||
        navigationWindow != navigationRevision ||
        token != _replyToken(parentChannelId) ||
        authority != _windowAuthority() ||
        parentId != threadParentMessageId ||
        parentChannelId != threadParentChannelId) {
      throw const RaftApiException('The thread changed. Please retry.');
    }
    threadChannelId = value['threadChannelId'];
    visibleIds.putIfAbsent(threadChannelId!, () => {});
    client.joinChannel(threadChannelId!);
    notifyListeners();
    return threadChannelId;
  }

  Future<void> openThread(
    RaftMessage parent, {
    String? focusedMessageId,
    bool navigate = true,
  }) => _openThreadIdentity(
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
  }) => _openThreadIdentity(
    parentChannelId,
    parentMessageId,
    focusedMessageId: focusedMessageId,
    initialThreadChannelId: initialThreadChannelId,
    navigate: navigate,
  );

  Future<void> _openThreadIdentity(
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
    if (_revokedChannels.contains(parentChannelId) ||
        _revokedChannels.contains(knownThreadChannelId) ||
        !can(
          'viewChannel',
          resource: _threadChannelResource(parentChannelId),
        )) {
      return;
    }
    if (navigate) {
      final next = location.withQuery({
        'thread': '$parentChannelId:$parentMessageId',
        'msg': ?focusedMessageId,
      });
      navigation.navigate(next, kind: location.panelNavigationKindTo(next));
    }
    final navigationWindow = navigationRevision,
        requestAuthority = _replyToken(parentChannelId),
        messageAuthority = _threadResourceAuthority(parentChannelId),
        generation = ledger.generation;
    final window = ++threadGeneration;
    bool current() =>
        !_disposed &&
        navigationWindow == navigationRevision &&
        requestAuthority == _replyToken(parentChannelId) &&
        (messageAuthority == null ||
            messageAuthority == _threadResourceAuthority(parentChannelId)) &&
        window == threadGeneration &&
        generation == ledger.generation &&
        !_revokedChannels.contains(parentChannelId) &&
        !_revokedChannels.contains(threadChannelId) &&
        can('viewChannel', resource: _threadChannelResource(parentChannelId));
    _threadIdentity = WorkspaceThreadIdentity(
      parentChannelId: parentChannelId,
      parentMessageId: parentMessageId,
      focusedMessageId: focusedMessageId,
    );
    _threadIdentityWindow = window;
    _threadIdentityNavigation = navigationWindow;
    _threadIdentityToken = requestAuthority;
    _threadIdentityAuthority = messageAuthority;
    final cachedWindow = _threadWindows[parentMessageId];
    final cached =
        cachedWindow != null &&
            cachedWindow.parentChannelId == parentChannelId &&
            cachedWindow.token == requestAuthority &&
            cachedWindow.authority == messageAuthority &&
            cachedWindow.generation == generation &&
            (knownThreadChannelId == null ||
                knownThreadChannelId == cachedWindow.threadChannelId) &&
            !_revokedChannels.contains(cachedWindow.threadChannelId) &&
            (visibleIds[cachedWindow.threadChannelId]?.isNotEmpty ?? false) &&
            (focusedMessageId == null ||
                visibleIds[cachedWindow.threadChannelId]!.contains(
                  focusedMessageId,
                ))
        ? cachedWindow
        : null;
    if (cachedWindow != null && cached == null) {
      _threadWindows.remove(parentMessageId);
    }
    threadParent = acceptedParent ?? cached?.parent;
    threadChannelId = knownThreadChannelId ?? cached?.threadChannelId;
    threadLoading = cached == null;
    _threadResolutionLoading = threadChannelId == null;
    _threadParentLoading = threadParent == null;
    _threadResolutionError = null;
    threadHasMore = cached?.hasMore ?? false;
    threadHistoryLimited = cached?.historyLimited ?? false;
    highlightedMessageId = focusedMessageId;
    notifyListeners();
    Future<void> restoreCurrentDraft() async {
      final scope = 'thread:$parentMessageId';
      final value = await _cached('draft', scope);
      if (!current() || drafts.containsKey(scope)) return;
      if (value is Map && value['text'] is String) {
        drafts[scope] = value['text'];
        notifyListeners();
      }
    }

    unawaited(restoreCurrentDraft());

    Future<void> resolveParent() async {
      if (acceptedParent != null) return;
      try {
        final page = await client.get(
          '/messages/context/$parentMessageId',
          query: {'channelId': parentChannelId},
        );
        if (!current()) return;
        final rows = acceptedWindowRows(page['messages'], parentChannelId);
        final parent = rows
            .where((row) => row['id'] == parentMessageId)
            .firstOrNull;
        // Independently fetched parent metadata is not an accepted outer window.
        final liveParent = channel?.id == parentChannelId
            ? messages.where((row) => row.id == parentMessageId).firstOrNull
            : null;
        final resolved =
            liveParent ?? (parent == null ? null : RaftMessage(parent));
        // A background revalidation never takes away a shown parent.
        if (resolved != null || threadParent == null) threadParent = resolved;
        _threadWindows[parentMessageId]?.parent = threadParent;
      } catch (_) {
        if (!current()) return;
        if (cached?.parent == null) threadParent = null;
      } finally {
        if (current()) {
          _threadParentLoading = false;
          notifyListeners();
        }
      }
    }

    Future<void> resolveReplies() async {
      try {
        if (threadChannelId == null) {
          dynamic info;
          try {
            info = await client.get(
              '/channels/$parentChannelId/threads/$parentMessageId',
            );
          } on RaftApiException catch (e) {
            if (e.status != 404) rethrow;
          }
          if (!current()) return;
          _threadResolutionLoading = false;
          if (info == null) return;
          threadChannelId = info['threadChannelId'];
          if (!current()) return;
          notifyListeners();
        }
        final page = focusedMessageId == null
            ? await client.messagePage(threadChannelId!)
            : await client.get(
                '/messages/context/$focusedMessageId',
                query: {'channelId': threadChannelId},
              );
        if (!current()) return;
        final rows = acceptedWindowRows(page['messages'], threadChannelId!);
        ledger.ingest(rows, expectedGeneration: generation);
        visibleIds[threadChannelId!] = rows
            .map((row) => row['id'] as String)
            .toSet();
        _diskOnlyWindows.remove(threadChannelId);
        threadHistoryLimited = page['historyLimited'] == true;
        threadHasMore = focusedMessageId == null
            ? !threadHistoryLimited && rows.length >= 50
            : page['hasOlder'] == true;
        client.joinChannel(threadChannelId!);
        threadLoading = false;
        _threadWindows[parentMessageId] = _ThreadWindow(
          parentChannelId: parentChannelId,
          threadChannelId: threadChannelId!,
          token: requestAuthority,
          authority: messageAuthority,
          generation: generation,
          hasMore: threadHasMore,
          historyLimited: threadHistoryLimited,
          parent: threadParent ?? cached?.parent,
        );
        notifyListeners();
        await markRead(threadChannelId!);
        if (current()) _saveWindow(threadChannelId!, thread: true);
      } catch (e) {
        final diskOnly = threadChannelId;
        if (current() &&
            diskOnly != null &&
            _diskOnlyWindows.contains(diskOnly) &&
            e is RaftApiException &&
            (e.status == 403 || e.status == 404)) {
          // A denied lookup never leaves an on-device window on screen.
          _diskOnlyWindows.remove(diskOnly);
          visibleIds.remove(diskOnly);
          _save('thread-window', parentMessageId, null);
        }
        // A cached window stays readable when its revalidation fails.
        if (current() && cached == null) {
          _threadResolutionError = '$e';
          error = '$e';
        }
      } finally {
        if (current()) {
          _threadResolutionLoading = false;
          threadLoading = false;
          notifyListeners();
        }
      }
    }

    /// A tail thread with no window in memory paints its on-device window
    /// (previous visit or previous process) while the lookup revalidates.
    Future<void> restoreDiskWindow() async {
      if (cached != null || focusedMessageId != null) return;
      final page = await _cached('thread-window', parentMessageId);
      if (!current() || !threadLoading || page is! Map) return;
      final threadId = page['threadChannelId'];
      if (page['version'] != 1 ||
          page['windowKind'] != 'tail' ||
          messageAuthority == null ||
          page['authority'] != messageAuthority ||
          page['parentChannelId'] != parentChannelId ||
          threadId is! String ||
          (threadChannelId != null && threadChannelId != threadId) ||
          _revokedChannels.contains(threadId)) {
        return;
      }
      final rows = acceptedWindowRows(page['messages'], threadId);
      if (rows.isEmpty) return;
      ledger.ingest(rows, expectedGeneration: generation);
      visibleIds[threadId] = rows.map((row) => row['id'] as String).toSet();
      _diskOnlyWindows.add(threadId);
      threadChannelId = threadId;
      final parent = page['parent'];
      if (threadParent == null &&
          parent is Map &&
          parent['id'] == parentMessageId &&
          parent['channelId'] == parentChannelId) {
        threadParent = RaftMessage(Map<String, dynamic>.from(parent));
        _threadParentLoading = false;
      }
      threadHasMore = page['hasMore'] == true;
      threadHistoryLimited = page['historyLimited'] == true;
      threadLoading = false;
      _threadResolutionLoading = false;
      notifyListeners();
    }

    unawaited(restoreDiskWindow());
    // Source threadStore opens an accepted inbox row's known channel directly,
    // without a lookup. Parent metadata and focused replies load independently.
    final replies = resolveReplies();
    unawaited(resolveParent());
    await replies;
  }

  /// Clears only the focus owned by the mounted timeline's highlight timer.
  void clearHighlightedMessage(
    String? expectedId, {
    int? expectedNavigationRevision,
  }) {
    if (highlightedMessageId != expectedId ||
        expectedNavigationRevision != null &&
            expectedNavigationRevision != navigationRevision) {
      return;
    }
    final identity = threadIdentity;
    if (expectedId != null &&
        expectedNavigationRevision != null &&
        identity != null &&
        identity.focusedMessageId == expectedId &&
        threadChannelId != null) {
      navigation.consumeThreadFocus(
        threadChannelId: threadChannelId!,
        parentChannelId: identity.parentChannelId,
        parentMessageId: identity.parentMessageId,
        expectedMessageId: expectedId,
        expectedRevision: expectedNavigationRevision,
      );
    }
    highlightedMessageId = null;
    notifyListeners();
  }

  /// Source ChatPanel.handleBackToBottom reloads latest when newer is unloaded.
  Future<void> returnToLatest({bool navigate = true}) async {
    final selected = channel;
    if (selected == null) return;
    clearHighlightedMessage(highlightedMessageId);
    if (hasNewer) {
      await selectChannel(
        selected,
        navigate: navigate,
        retainContextUntilAccepted: true,
      );
    }
  }

  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
  }) async {
    final generation = ledger.generation;
    var navigationWindow = navigationRevision;
    var authority = _windowAuthority();
    final replyAuthority = _replyToken(channelId);
    final window = ++channelGeneration;
    bool owned() =>
        !_disposed &&
        generation == ledger.generation &&
        window == channelGeneration &&
        navigationWindow == navigationRevision &&
        authority == _windowAuthority() &&
        replyAuthority == _replyToken(channelId) &&
        !_revokedChannels.contains(channelId);
    if (_rejectRevokedConversation(channelId) || !owned()) return;
    var next = [
      ...channels,
      ...dms,
    ].where((c) => c.id == channelId).firstOrNull;
    try {
      next ??= RaftChannel(
        Map<String, dynamic>.from(await client.get('/channels/$channelId')),
      );
    } catch (_) {
      // Source ChannelById/ensureChannel resolves failed metadata to its
      // unavailable body. UI callbacks may not await this request; neither a
      // global async exception nor a retained conversation owns the failure.
      if (owned()) {
        _missingConversationChannelId = channelId;
        notifyListeners();
      }
      return;
    }
    if (!owned() || !can('viewChannel', resource: next)) return;
    if (messageId == null) {
      await selectChannel(next, navigate: navigate);
      return;
    }
    final sameChannel = channel?.id == channelId;
    authority = messageWindowAuthority(server?.string('role'), next.json);
    final knownWindow = _windowState[channelId];
    final compatibleWindow =
        knownWindow?.$1 == authority && knownWindow?.$3 == replyAuthority;
    final cachedTarget =
        compatibleWindow &&
        ledger
            .messages(channelId)
            .any(
              (row) =>
                  row['id'] == messageId &&
                  visibleIds[channelId]?.contains(messageId) == true,
            );
    channel = next;
    if (navigate) {
      section = 'chat';
      navigation.navigate(
        location.withQuery({'msg': messageId}),
        kind: RaftNavigationKind.replace,
      );
      navigationWindow = navigationRevision;
    }
    threadParent = null;
    threadChannelId = null;
    threadGeneration++;
    loadingOlder = false;
    error = null;
    highlightedMessageId = messageId;
    if (cachedTarget) {
      hasMore = sameChannel ? hasMore : knownWindow!.$2;
      hasNewer = sameChannel
          ? hasNewer
          : _contextWindows.contains(channelId) &&
                _contextWindowHasNewer[channelId] == true;
      historyLimited = _windowHistoryLimited[channelId] == true;
      channelLoading = false;
      _pendingMessageContextChannelId = null;
      _pendingMessageContextWindow = null;
      notifyListeners();
      return;
    }
    channelLoading = true;
    _pendingMessageContextChannelId = channelId;
    _pendingMessageContextWindow = window;
    // Source preserves the destination's already accepted memory bucket while
    // its context GET waits. A disk/unaccepted bucket or an earlier principal,
    // server or capability epoch cannot grant this cross-channel projection.
    _pendingMessageContextRetainsRows = sameChannel || compatibleWindow;
    if (!sameChannel) {
      // Held summaries belong to the held window; an incompatible window
      // takes its summaries with it.
      if (!compatibleWindow) _summariesByChannel.remove(channelId);
      if (compatibleWindow) {
        hasMore = knownWindow!.$2;
        hasNewer =
            _contextWindows.contains(channelId) &&
            _contextWindowHasNewer[channelId] == true;
        historyLimited = _windowHistoryLimited[channelId] == true;
      }
    }
    bool current() =>
        owned() &&
        channel?.id == channelId &&
        can('viewChannel', resource: channel);
    notifyListeners();
    try {
      final context = await client.get(
        '/messages/context/$messageId',
        query: {'channelId': channelId},
      );
      if (!current()) return;
      final target = context['canonicalTarget'];
      if (target is Map && target['kind'] == 'thread') {
        final parentId = target['threadParentMessageId'] as String;
        final parentChannelId = target['channelId'] as String? ?? channelId;
        final opening = openThreadIdentity(
          parentChannelId: parentChannelId,
          parentMessageId: parentId,
          focusedMessageId: target['messageId'] as String? ?? messageId,
          navigate: navigate,
        );
        if (navigate) navigationWindow = navigationRevision;
        await opening;
        if (!current()) return;
        // Source loadMessageContext opens the canonical thread, then loads the
        // outer channel tail. Keep both accepted rows and reply focus while it
        // is pending; do not pass through selectChannel's thread reset/cache.
        try {
          final tail = await client.messagePage(channelId);
          if (!current()) return;
          final accepted = acceptedWindowRows(tail['messages'], channelId);
          ledger.ingest(accepted, expectedGeneration: generation);
          visibleIds[channelId] = accepted
              .map((row) => row['id'] as String)
              .toSet();
          _contextWindows.remove(channelId);
          _contextWindowHasNewer.remove(channelId);
          historyLimited = tail['historyLimited'] == true;
          hasMore = !historyLimited && accepted.length >= 50;
          hasNewer = false;
          _windowState[channelId] = (authority, hasMore, replyAuthority);
          _windowHistoryLimited[channelId] = historyLimited;
          _summariesByChannel[channelId] = {
            ...?_summariesByChannel[channelId],
            ..._hydrateThreadSummaries(
              tail['threadSummariesByParentMessageId'],
              channelId,
              expectedToken: replyAuthority,
            ),
          };
          final refreshedParent = accepted
              .where((row) => row['id'] == parentId)
              .firstOrNull;
          if (parentChannelId == channelId && refreshedParent != null) {
            threadParent = RaftMessage(refreshedParent);
          }
          _pendingMessageContextChannelId = null;
          _pendingMessageContextWindow = null;
          channelLoading = false;
          notifyListeners();
          await markRead(channelId);
          if (current()) await _saveWindow(channelId);
        } catch (e) {
          if (!current()) return;
          if (e is RaftApiException && e.status == 403) {
            _revokeChannel(channelId);
          } else {
            error = '$e';
            _pendingMessageContextChannelId = null;
            _pendingMessageContextWindow = null;
            channelLoading = false;
            notifyListeners();
          }
        }
      } else {
        final accepted = acceptedWindowRows(context['messages'], channelId);
        final targetId = context['targetMessageId'] as String? ?? messageId;
        ledger.ingest(accepted, expectedGeneration: generation);
        _contextWindows.add(channelId);
        visibleIds[channelId] = accepted.map((e) => e['id'] as String).toSet();
        hasMore = context['hasOlder'] == true;
        hasNewer = context['hasNewer'] == true;
        historyLimited = false;
        _windowState[channelId] = (authority, hasMore, replyAuthority);
        _windowHistoryLimited[channelId] = false;
        _contextWindowHasNewer[channelId] = hasNewer;
        _summariesByChannel[channelId] = {
          ...?_summariesByChannel[channelId],
          ..._hydrateThreadSummaries(
            context['threadSummariesByParentMessageId'],
            channelId,
            expectedToken: replyAuthority,
          ),
        };
        highlightedMessageId = targetId;
        _pendingMessageContextChannelId = null;
        _pendingMessageContextWindow = null;
        channelLoading = false;
        // Publish the accepted window, summaries and pagination as one event.
        notifyListeners();
        await markRead(channelId);
      }
    } catch (e) {
      if (!current()) return;
      if (e is RaftApiException && e.status == 403) {
        _revokeChannel(channelId);
      } else {
        _pendingMessageContextChannelId = null;
        _pendingMessageContextWindow = null;
        highlightedMessageId = null;
        // Source falls back to latest after a missing/unavailable context.
        final fallbackWindow = channelGeneration + 1;
        final fallback = selectChannel(
          next,
          navigate: navigate,
          retainContextUntilAccepted: true,
        );
        final fallbackNavigation = navigationRevision;
        await fallback;
        if (fallbackNavigation == navigationRevision &&
            !_disposed &&
            channelGeneration == fallbackWindow &&
            channel?.id == channelId &&
            generation == ledger.generation &&
            authority == _windowAuthority()) {
          error = '$e';
          notifyListeners();
        }
      }
    } finally {
      if (current()) {
        _pendingMessageContextChannelId = null;
        _pendingMessageContextWindow = null;
        channelLoading = false;
        notifyListeners();
      }
    }
  }

  void closeThread({bool navigate = true}) {
    if (navigate && location.thread != null) {
      final next = location.withQuery({'thread': null});
      navigation.navigate(next, kind: location.panelNavigationKindTo(next));
    }
    threadGeneration++;
    _threadIdentity = null;
    _threadResolutionLoading = _threadParentLoading = false;
    _threadResolutionError = null;
    threadParent = null;
    threadChannelId = null;
    threadLoading = false;
    threadHistoryLimited = false;
    notifyListeners();
  }

  void setSection(String next) {
    if (!canVisitSection(next)) return;
    section = next;
    notifyListeners();
  }

  Future<dynamic> query(String path, {Map<String, dynamic>? query}) =>
      client.get(path, query: query);

  final _sharedReads = <String, Future<dynamic>>{};

  /// Coalesce identical concurrent reads of the same window. The Activity
  /// page and the Activity attention badge both reconcile the inbox 150 ms
  /// after the same socket event; they now share one request. Every caller
  /// receives its own copy of the decoded response.
  Future<dynamic> sharedQuery(String path, {Map<String, dynamic>? query}) {
    final params = query == null
        ? null
        : (query.keys.toList()..sort()).map((k) => [k, query[k]]).toList();
    final key = jsonEncode([
      client.origin,
      client.generation,
      client.user?.id,
      client.serverId,
      path,
      params,
    ]);
    var pending = _sharedReads[key];
    if (pending == null) {
      final started = pending = this.query(path, query: query);
      _sharedReads[key] = started;
      unawaited(
        started
            .then<void>((_) {}, onError: (Object _, StackTrace _) {})
            .whenComplete(() {
              if (identical(_sharedReads[key], started)) {
                _sharedReads.remove(key);
              }
            }),
      );
    }
    return pending.then(_copyDecoded);
  }

  static dynamic _copyDecoded(dynamic value) => switch (value) {
    Map() => <String, dynamic>{
      for (final MapEntry(:key, :value) in value.entries)
        '$key': _copyDecoded(value),
    },
    List() => [for (final item in value) _copyDecoded(item)],
    _ => value,
  };
  int savedRevision = 0;
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    final generation = client.generation,
        principal = client.user?.id,
        serverId = client.serverId;
    final value = await client.request(method, path, data: data);
    if (generation == client.generation &&
        principal == client.user?.id &&
        serverId == client.serverId &&
        ((method == 'POST' && path == '/channels/saved') ||
            (method == 'DELETE' && path.startsWith('/channels/saved/')))) {
      ++savedRevision;
      notifyListeners();
    }
    if (_reconcilesUnread(path)) await refreshUnread();
    return value;
  }

  /// Commands whose effect on unread counts is only known to the server
  /// (read-all, mark unread, join/leave, notification preferences).
  static bool _reconcilesUnread(String path) {
    final segments = Uri.parse(path).pathSegments;
    return segments.isNotEmpty &&
        const {
          'read',
          'read-all',
          'unread',
          'join',
          'leave',
          'notification-settings',
        }.contains(segments.last);
  }

  Future<void> hydrateReactionViewer(RaftMessage message) async {
    if (reactionViewer.reacted(message.id) != null ||
        _viewerLoads.containsKey(message.id) ||
        channel?.archived == true) {
      return;
    }
    final generation = ledger.generation, serverId = client.serverId;
    if (serverId == null) return;
    Future<void> load() async {
      try {
        final snapshot = await client.get(
          '/messages/${message.id}/reactions/viewer',
        );
        if (_disposed ||
            generation != ledger.generation ||
            _revokedChannels.contains(message.channelId)) {
          return;
        }
        if (reactionViewer.accept(snapshot, serverId: serverId) == 'accepted') {
          notifyListeners();
        }
      } catch (_) {
        /* A click retries explicitly and reports an actionable error. */
      }
    }

    final pending = load();
    _viewerLoads[message.id] = pending;
    try {
      await pending;
    } finally {
      if (identical(_viewerLoads[message.id], pending)) {
        _viewerLoads.remove(message.id);
      }
    }
  }

  /// Reaction toggles in flight per message, so a presented row shows the
  /// viewer's own state at once (Web `pendingReactionTargetsRef`).
  final Map<String, Map<String, PendingReaction>> _pendingReactions = {};

  /// The state each pending toggle is heading for (null when none).
  Map<String, bool>? pendingReactionTargets(String messageId) {
    final pending = _pendingReactions[messageId];
    return pending == null || pending.isEmpty
        ? null
        : {for (final e in pending.entries) e.key: e.value.target};
  }

  String get _reactionViewerName => client.user?.name ?? '';

  /// Replace a held message's reactions (and the open thread's parent copy).
  /// Not persisted: optimistic state never reaches the disk cache.
  bool _setMessageReactions(
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
    final parent = threadParent;
    if (parent != null && parent.id == messageId) {
      threadParent = RaftMessage({...parent.json, 'reactions': reactions});
      changed = true;
    }
    return changed;
  }

  List<Map<String, dynamic>> _heldReactions(RaftMessage message) =>
      reactionList(
        (ledger.message(message.channelId, message.id) ??
            message.json)['reactions'],
      );

  /// Socket rows carry server state that may predate a pending write: lay the
  /// pending toggles back over the row's reactions.
  void _overlayPendingReactions(Map<String, dynamic> row) {
    final id = row['id'], channelId = row['channelId'];
    final pending = _pendingReactions[id];
    final viewerId = client.user?.id;
    if (pending == null ||
        pending.isEmpty ||
        viewerId == null ||
        id is! String ||
        channelId is! String ||
        !row.containsKey('reactions')) {
      return;
    }
    final held = reactionList(ledger.message(channelId, id)?['reactions']);
    final next = overlayPendingReactions(
      held,
      pending,
      viewerId: viewerId,
      viewerName: _reactionViewerName,
    );
    if (!identical(next, held)) _setMessageReactions(channelId, id, next);
  }

  /// Web MessageItem `handleToggleReaction`: the chip and the viewer's own
  /// state change at once, the write follows, the server row reconciles and a
  /// failure puts the previous reaction back. A second toggle of the same
  /// emoji while one is in flight is ignored (Web `pendingReactionEmojisRef`).
  Future<void> toggleReaction(RaftMessage message, String emoji) {
    final key = '${message.id}:$emoji';
    final inFlight = _reactionWrites[key];
    if (inFlight != null) return inFlight;
    final generation = ledger.generation,
        serverId = client.serverId,
        viewerId = client.user?.id;
    if (serverId == null || viewerId == null) return Future.value();
    Future<void> change() async {
      var reacted =
          reactionViewer.reacted(message.id)?.contains(emoji) ??
          ownReactionFromRow(_heldReactions(message), emoji, viewerId);
      if (reacted == null) {
        // Canonical chip without a private snapshot: read it first.
        final viewer = await client.get(
          '/messages/${message.id}/reactions/viewer',
        );
        if (_disposed || generation != ledger.generation) return;
        reactionViewer.accept(viewer, serverId: serverId);
        reacted = reactionViewer.reacted(message.id)?.contains(emoji);
        if (reacted == null) {
          throw StateError('Your reaction state could not be loaded.');
        }
      }
      final target = !reacted;
      final before = _heldReactions(message);
      final pending = beginReaction(before, emoji, target: target);
      (_pendingReactions[message.id] ??= {})[emoji] = pending;
      _setMessageReactions(
        message.channelId,
        message.id,
        setOwnReaction(
          before,
          emoji,
          reacted: target,
          viewerId: viewerId,
          viewerName: _reactionViewerName,
        ),
      );
      notifyListeners();
      bool stale() =>
          _disposed ||
          generation != ledger.generation ||
          _revokedChannels.contains(message.channelId);
      try {
        final value = await client.request(
          target ? 'POST' : 'DELETE',
          '/messages/${message.id}/reactions',
          data: {'emoji': emoji},
        );
        _clearPendingReaction(message.id, emoji);
        if (stale()) return;
        if (value is Map) {
          final accepted = reactionViewer.accept(
            value['reactionViewer'],
            serverId: serverId,
          );
          final row = Map<String, dynamic>.from(value)
            ..remove('reactionViewer');
          ledger.ingest([row], expectedGeneration: generation);
          // Other emojis still in flight keep their optimistic state.
          _overlayPendingReactions(row);
          final snapshot = reactionViewer.reacted(message.id);
          if (accepted != 'accepted' &&
              snapshot != null &&
              snapshot.contains(emoji) != target) {
            // A snapshot older than the write would show the old state.
            reactionViewer.remove(message.id);
            unawaited(hydrateReactionViewer(message));
          }
          final held = ledger.message(message.channelId, message.id);
          if (held != null && threadParent?.id == message.id) {
            threadParent = RaftMessage(held);
          }
          _saveWindow(
            message.channelId,
            thread: message.channelId == threadChannelId,
          );
        }
        notifyListeners();
      } catch (_) {
        _clearPendingReaction(message.id, emoji);
        if (!stale()) {
          _setMessageReactions(
            message.channelId,
            message.id,
            restoreReaction(_heldReactions(message), emoji, pending),
          );
          notifyListeners();
        }
        rethrow;
      }
    }

    final pending = change();
    _reactionWrites[key] = pending;
    return pending.whenComplete(() {
      if (identical(_reactionWrites[key], pending)) _reactionWrites.remove(key);
    });
  }

  void _clearPendingReaction(String messageId, String emoji) {
    final pending = _pendingReactions[messageId];
    pending?.remove(emoji);
    if (pending != null && pending.isEmpty) _pendingReactions.remove(messageId);
  }

  void _event(RaftEvent event) {
    if (_disposed) return;
    _ensureSyncIdentity();
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
    // Presence patches are owned by the entity directory and the agent
    // presentations; no workspace state changes, so nothing is notified.
    if (presenceEvents.contains(event.name)) return;
    if (event.name == 'connected') {
      connected = true;
      // Source socketBridge reconnectSnapshot: server-level reads only. The
      // channel list, unread counts and the resume/gap sync wait for
      // `rooms:joined`, once the server has joined this socket's rooms.
      _roomsJoinedPending = true;
      _lastHeartbeat = _lastServerEvent;
      recoverMembership();
      refreshMessageSyncFlag();
      loadSidebar();
      // A reconnect refreshes agents and members in place; the first connect
      // reuses the reads the selection already started.
      if (_connectedBefore && entityDirectory.started) {
        entityDirectory.revalidateAuthors();
      }
      _connectedBefore = true;
    }
    if (event.name == 'rooms:joined') _roomsJoined();
    if (event.name == 'heartbeat') {
      final joining = _roomsJoinedPending;
      _heartbeat(event.payload);
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
      revokeServer(event.payload['serverId']);
      recoverMembership();
    }
    if (event.name == 'connection:error' &&
        event.payload is Map &&
        event.payload['notServerMember'] == true) {
      final id = client.serverId;
      if (id != null) revokeServer(id);
      recoverMembership();
    }
    if (event.name == 'server:member-updated') {
      applyMembershipRole(event.payload);
      recoverMembership();
      refreshChannels();
    }
    if (event.name == 'channel:members-updated' ||
        event.name == 'channel:authority-updated' ||
        event.name == 'channel:removed') {
      final payload = event.payload;
      final id = payload is Map ? payload['channelId'] ?? payload['id'] : null;
      if (id is! String || id.isEmpty) {
        // Unknown scope: fail closed for every channel.
        _invalidateAllChannelReplies();
      } else if (event.name != 'channel:members-updated' ||
          _membershipScoped(id)) {
        // Only the named channel's authority may have changed. A public
        // channel's member list never changes who can read it.
        _invalidateChannelReplies(id);
      }
    }
    if (event.name == 'channel:updated' ||
        event.name == 'channel:members-updated' ||
        event.name == 'dm:new' ||
        event.name == 'channel:authority-updated') {
      _channelRealtime(event.name, event.payload);
    }
    if (event.name == 'pinned:updated') loadSidebar();
    if (event.name == 'thread:updated' && event.payload is Map) {
      _consumeThreadUpdate(Map<String, dynamic>.from(event.payload));
    }
    if (event.name == 'notification_prefs:updated') {
      _consumeNotificationPrefs(event.payload);
    }
    if ((event.name == 'message:new' || event.name == 'message:updated') &&
        event.payload is Map) {
      final row = Map<String, dynamic>.from(event.payload);
      if (_revokedChannels.contains(row['channelId'])) return;
      final duplicate =
          row['channelId'] is String &&
          row['id'] is String &&
          ledger.contains(row['channelId'], row['id']);
      if (event.name == 'message:updated') {
        if (!ledger.ingestUpdate(row, expectedGeneration: ledger.generation)) {
          return;
        }
        _overlayPendingReactions(row);
      } else {
        final projection = syncCoreMessagesEnabled
            ? messageSync.consumeNew(row)
            : row;
        if (projection == null) return;
        ledger.ingest([projection], expectedGeneration: ledger.generation);
      }
      final id = row['channelId'];
      if (id == channel?.id && !hasNewer || id == threadChannelId) {
        visibleIds.putIfAbsent(id, () => {}).add(row['id']);
        _saveWindow(id, thread: id == threadChannelId);
      }
      // Source messageStore: counts move per event; only a first delivery
      // counts, and an edit never does.
      if (event.name == 'message:new' && !duplicate) _receiveUnread(row);
    }
    if (event.name == 'sync:resume:response' && event.payload is Map) {
      final p = event.payload as Map;
      final rows = (p['messages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .where((row) => !_revokedChannels.contains(row['channelId']))
          .toList();
      ledger.ingest(rows, expectedGeneration: ledger.generation);
      for (final row in rows) {
        final id = row['channelId'];
        if (id == channel?.id && !hasNewer || id == threadChannelId) {
          visibleIds.putIfAbsent(id, () => {}).add(row['id']);
        }
      }
      if (channel != null && !hasNewer) markRead(channel!.id);
      if (threadChannelId != null) markRead(threadChannelId!);
      if (p['hasMore'] == true) {
        final cursor = BigInt.tryParse('${p['currentSeq']}');
        if (cursor != null && cursor > BigInt.zero) client.resume(cursor);
      }
      refreshUnread();
    }
    if (event.name == 'channel:removed') {
      final p = event.payload;
      if (p is Map && p['channelId'] is String) {
        final id = p['channelId'] as String;
        _revokeChannel(id);
        channels.removeWhere((c) => c.id == id);
        dms.removeWhere((c) => c.id == id);
        if (channel?.id == id) {
          channel = null;
          closeThread();
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
              _projectReadState(fact['scopeId'] as String);
            }
          }
        }
      }
      _persistReadState();
    }
    if (event.name == 'reaction_viewer:updated' && client.serverId != null) {
      reactionViewer.accept(event.payload, serverId: client.serverId!);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsEntityDirectory) {
      removeListener(_entityAuthorityChanged);
      entityDirectory.dispose();
    }
    if (_ownsFollowedThreads) followedThreads.dispose();
    _imageAuthorities.clear();
    _attachmentImages?.dispose();
    _channelFilesStores.clear();
    for (final drafts in _uploads.values) {
      for (final draft in drafts) {
        draft.cancel.cancel();
      }
    }
    _uploads.clear();
    subscription.cancel();
    foregroundChanges.dispose();
    if (ownsClient) client.dispose();
    super.dispose();
  }
}

/// Web `normalizePendingMentionActions`: keep well-formed rows only.
List<Map<String, dynamic>> normalizePendingMentionActions(dynamic value) => [
  if (value is List)
    for (final row in value.whereType<Map>())
      if (row['resolutionId'] is String &&
          row['targetType'] is String &&
          row['availableActions'] is List)
        Map<String, dynamic>.from(row),
];

class _ThreadWindow {
  _ThreadWindow({
    required this.parentChannelId,
    required this.threadChannelId,
    required this.token,
    required this.authority,
    required this.generation,
    required this.hasMore,
    required this.historyLimited,
    this.parent,
  });
  final String parentChannelId, threadChannelId, token;
  final String? authority;
  final int generation;
  final bool hasMore, historyLimited;
  RaftMessage? parent;
}
