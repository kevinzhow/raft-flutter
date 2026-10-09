import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'workspace_cache.dart';
import 'workspace_entity_directory.dart';
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
  void release() {
    if (_released) return;
    _released = true;
    lease.release();
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
}

class _SendAttempt {
  const _SendAttempt(this.fingerprint, this.randomId);
  final String fingerprint, randomId;
}

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(
    this.client, {
    this.cache,
    this.mobileNavigation = false,
    this.ownsClient = true,
    WorkspaceEntityDirectory? entityDirectory,
  }) {
    _ownsEntityDirectory = entityDirectory == null;
    this.entityDirectory =
        entityDirectory ??
        WorkspaceEntityDirectory(
          scope: _entityScope,
          query: (path) => query(path),
          events: client.events,
        );
    if (_ownsEntityDirectory) {
      addListener(_entityAuthorityChanged);
      this.entityDirectory.addListener(_entityDirectoryChanged);
    }
    subscription = client.events.listen(_event);
  }

  /// Borrowed editor controllers project messages but never own the session,
  /// membership recovery, server selection, socket resume, or client teardown.
  final bool ownsClient;
  final RaftClient client;
  final WorkspaceCache? cache;
  late final WorkspaceEntityDirectory entityDirectory;
  late final bool _ownsEntityDirectory;
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

  void _entityDirectoryChanged() {
    if (!_disposed) notifyListeners();
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
    for (final channel in [...channels, ...dms]) {
      if (_revokedChannels.contains(channel.id) ||
          !can('viewChannel', resource: channel)) {
        continue;
      }
      final roots = ledger.messages(channel.id);
      final channelIds = <String>{channel.id};
      for (final message in roots) {
        final thread = RaftMessage(message).threadId;
        if (thread != null) channelIds.add(thread);
      }
      if (!channelIds.contains(key.channelId)) continue;
      for (final message in ledger.messages(key.channelId)) {
        for (final metadata in RaftMessage(message).attachments) {
          if (metadata['id'] != key.attachmentId) continue;
          final canonical = AttachmentImageKey.fromMetadata(
            scope: key.scope,
            channelId: key.channelId,
            metadata: metadata,
            rendition: key.rendition,
          );
          if (canonical == key) return true;
        }
      }
    }
    return false;
  }

  WorkspaceAttachmentImageLease acquireAttachmentImage(
    AttachmentImageKey key, {
    required AttachmentImageLoader load,
    required bool Function() authorized,
  }) {
    final owner = Object();
    _imageAuthorities.putIfAbsent(key, () => {})[owner] = authorized;
    void releaseAuthority() {
      final owners = _imageAuthorities[key];
      owners?.remove(owner);
      if (owners?.isEmpty == true) _imageAuthorities.remove(key);
      _attachmentImages?.synchronize(attachmentImageScope);
    }

    try {
      final repository = _attachmentImages ??= AttachmentImageRepository(
        scope: attachmentImageScope,
        retainedAuthority: _retainsAttachment,
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

  /// Set by the host from its actual logical width before bootstrap. Home
  /// retains selection/drafts, but is not an open conversation/read surface.
  bool mobileNavigation;
  final messageSync = MessageSync();
  final threadRepliesSync = ThreadRepliesSync();
  final notificationPrefsSync = NotificationPrefsSync();
  bool syncCoreNotificationPrefsEnabled = false;
  String? _replyIdentity;
  int _replyAuthorityEpoch = 0;

  String _syncIdentity() => jsonEncode([
    client.origin,
    client.generation,
    client.serverId,
    client.user?.id,
    server?.string('role'),
  ]);
  String _replyToken() => jsonEncode([_syncIdentity(), _replyAuthorityEpoch]);
  void _ensureSyncIdentity() {
    final next = _syncIdentity();
    if (_replyIdentity == next) return;
    final hadIdentity = _replyIdentity != null;
    _messageFlagRequest++;
    _replyIdentity = next;
    threadRepliesSync.reset();
    notificationPrefsSync.reset();
    syncCoreNotificationPrefsEnabled = false;
    if (hadIdentity) threadSummaries = {};
  }

  Map<String, dynamic> _hydrateThreadSummaries(
    dynamic raw,
    String parentChannelId, {
    String? expectedToken,
  }) {
    _ensureSyncIdentity();
    if (expectedToken != null && expectedToken != _replyToken()) return {};
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
      token == _replyToken() &&
      !_revokedChannels.contains(request.parentChannelId) &&
      !_revokedChannels.contains(request.threadChannelId);

  Future<void> _rebaselineThread(ThreadRebaselineRequest request) async {
    final token = _replyToken();
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
      threadSummaries[request.parentMessageId] = result.summary;
      unawaited(refreshUnread());
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
      threadSummaries[parentId] = result.summary;
      unawaited(refreshUnread());
    }
    if (result.request != null) unawaited(_rebaselineThread(result.request!));
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
      drafts.clear();
      visibleIds.clear();
      _windowState.clear();
      _windowHistoryLimited.clear();
      historyLimited = threadHistoryLimited = false;
      _contextWindows.clear();
      channel = null;
      channels = [];
      dms = [];
      server = null;
      unread = {};
      sidebarOrder = {};
      threadParent = null;
      threadChannelId = null;
      threadSummaries = {};
      highlightedMessageId = null;
      channelGeneration++;
      threadGeneration++;
      ledger.switchServer(null);
      readState.reset();
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
      _replyToken(),
    );
    _windowHistoryLimited[id] = thread ? threadHistoryLimited : historyLimited;
    _contextWindows.remove(id);
    await _save('window', id, {
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
  bool _disposed = false;
  Future<String?>? _creatingThread;
  int? _creatingThreadWindow;
  @override
  void notifyListeners() {
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
  final Map<String, Set<String>> visibleIds = {};
  final Map<String, (String, bool, String)> _windowState = {};
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
          _threadIdentityToken == _replyToken() &&
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
  Map<String, dynamic> threadSummaries = {};
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
  List<RaftMessage> get replies => threadChannelId == null
      ? []
      : ledger
            .messages(threadChannelId!)
            .where(
              (m) => visibleIds[threadChannelId!]?.contains(m['id']) ?? false,
            )
            .map(RaftMessage.new)
            .toList();
  void setError(String? value) {
    error = value;
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

  Future<void> selectServer(RaftRecord next) async {
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
    ledger.switchServer(next.id);
    readState.reset();
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
    drafts.clear();
    visibleIds.clear();
    _windowState.clear();
    _windowHistoryLimited.clear();
    historyLimited = threadHistoryLimited = false;
    _contextWindows.clear();
    _revokedChannels.clear();
    highlightedMessageId = null;
    hasNewer = false;
    channels = [];
    dms = [];
    channel = null;
    threadParent = null;
    threadChannelId = null;
    threadSummaries = {};
    unread = {};
    channelGeneration++;
    threadGeneration++;
    final selectionAtStart = channelGeneration,
        threadAtStart = threadGeneration;
    notifyListeners();
    final generation = client.generation;
    final replyAuthority = _replyToken();
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
        final page = await _cached('window', initial.id);
        if (generation != client.generation) return;
        if (_acceptCachedWindow(page, initial.id)) {
          final rows = acceptedWindowRows(page['messages'], initial.id);
          ledger.ingest(rows, expectedGeneration: ledger.generation);
          visibleIds[initial.id] = rows.map((e) => e['id'] as String).toSet();
          hasMore = page['hasMore'] == true;
          historyLimited = page['historyLimited'] == true;
          hasNewer = page['hasNewer'] == true;
          threadSummaries = _hydrateThreadSummaries(
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
        await selectChannel(selected);
      }
    }
    notifyListeners();
  }

  void _persistReadState() {
    final serverId = client.serverId, principal = client.user?.id;
    if (serverId == null || principal == null) return;
    _save('read-frontiers', '', readState.exportFor(serverId, principal));
    _save('unread', '', Map.of(unread));
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
    } catch (_) {
      /* Keep accepted counts through transient failures. */
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
      for (final summary in threadSummaries.values)
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
      ledger.revokeChannel(scope);
      messageSync.revokeChannel(scope);
      threadRepliesSync.revokeChannel(scope);
      notificationPrefsSync.revokeChannel(scope);
      visibleIds.remove(scope);
      _windowState.remove(scope);
      _contextWindows.remove(scope);
      unread.remove(scope);
      if (serverId != null && principal != null) {
        readState.revoke(serverId, principal, scope);
      }
      drafts.remove(scope);
      for (final draft in _uploads.remove(scope) ?? <UploadDraft>[]) {
        draft.cancel.cancel();
      }
      _attempts.remove(scope);
    }
    for (final messageId in messageIds) {
      final scope = 'thread:$messageId';
      drafts.remove(scope);
      _attempts.remove(scope);
      for (final draft in _uploads.remove(scope) ?? <UploadDraft>[]) {
        draft.cancel.cancel();
      }
      reactionViewer.remove(messageId);
      threadSummaries.remove(messageId);
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

  Future<void> refreshChannels() async {
    final generation = ledger.generation;
    try {
      final lists = await Future.wait([
        client.channels(),
        client.channels(dm: true),
      ]);
      if (generation != ledger.generation || _disposed) return;
      final accessible = [...lists[0], ...lists[1]].map((c) => c.id).toSet();
      for (final old in [...channels, ...dms]) {
        if (!accessible.contains(old.id)) _revokeChannel(old.id);
      }
      _revokedChannels.removeAll(accessible);
      channels = lists[0];
      dms = lists[1];
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
    } catch (e) {
      if (generation == ledger.generation && !_disposed) setError('$e');
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
        reply = _replyToken(),
        generation = ledger.generation;
    bool current() =>
        !_disposed &&
        request == _conversationResolutionRequest &&
        revision == navigationRevision &&
        scope == navigationAuthority &&
        reply == _replyToken() &&
        generation == ledger.generation &&
        !_revokedChannels.contains(id);
    if (id.isEmpty || !can('viewChannel')) return;
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
    if (priorWindow != null &&
        (priorWindow.$1 != _windowAuthority() ||
            priorWindow.$3 != _replyToken())) {
      visibleIds.remove(next.id);
      _windowState.remove(next.id);
      _windowHistoryLimited.remove(next.id);
    }
    hasMore =
        priorWindow != null &&
        priorWindow.$1 == _windowAuthority() &&
        priorWindow.$3 == _replyToken() &&
        priorWindow.$2;
    historyLimited =
        priorWindow != null &&
            priorWindow.$1 == _windowAuthority() &&
            priorWindow.$3 == _replyToken()
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
    final replyAuthority = _replyToken();
    final authority = _windowAuthority();
    final navigationWindow = navigationRevision;
    bool current() =>
        !_disposed &&
        window == channelGeneration &&
        navigationWindow == navigationRevision &&
        generation == ledger.generation &&
        channel?.id == next.id &&
        authority == _windowAuthority() &&
        replyAuthority == _replyToken() &&
        !_revokedChannels.contains(next.id) &&
        can('viewChannel', resource: channel);
    notifyListeners();
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
        threadSummaries = _hydrateThreadSummaries(
          page['threadSummaries'],
          next.id,
          expectedToken: replyAuthority,
        );
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
      historyLimited = fresh['historyLimited'] == true;
      visibleIds[next.id] = fresh['historyLimited'] == true
          ? rows.map((e) => e['id'] as String).toSet()
          : reconcileTailWindow(retained, rows);
      threadSummaries = {
        for (final row in retained)
          if (threadSummaries[row['id']] != null)
            row['id'] as String: threadSummaries[row['id']],
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
    final replyAuthority = _replyToken();
    final authority = _windowAuthority();
    bool currentWindow() =>
        !_disposed &&
        window == (thread ? threadGeneration : channelGeneration) &&
        generation == ledger.generation &&
        authority == _windowAuthority() &&
        replyAuthority == _replyToken() &&
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
      threadSummaries.addAll(
        _hydrateThreadSummaries(
          page['threadSummariesByParentMessageId'],
          id,
          expectedToken: replyAuthority,
        ),
      );
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

  Future<void> markRead(String id) async {
    if (!foreground ||
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
      _persistReadState();
      await refreshUnread();
    } catch (_) {}
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
    bool currentSend() =>
        !_disposed &&
        generation == ledger.generation &&
        principal == client.user?.id &&
        serverId == client.serverId &&
        origin == client.origin &&
        clientGeneration == client.generation &&
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
    try {
      if (!thread && hasNewer && channel != null) {
        final refreshing = selectChannel(channel!);
        // selectChannel starts synchronously. Only this intentional refresh may
        // advance the window; navigation during its awaits must cancel send.
        window = channelGeneration;
        await refreshing;
        if (!currentSend()) return false;
        onWindowRefreshed?.call(window);
      }
      if (!currentSend() || intendedScope == null) return false;
      final id = thread ? await ensureThread() : intendedChannel;
      if (id == null || !currentSend()) return false;
      final scope = intendedScope;
      final uploaded = uploads(thread: thread);
      if (uploaded.any((u) => u.id == null)) {
        throw const RaftApiException(
          'Wait for uploads to finish, or remove the failed file.',
        );
      }
      final ids = selectedAttachments ?? uploaded.map((u) => u.id!).toList();
      final fingerprint = jsonEncode([
        text,
        ids,
        if (selectedMentions.isNotEmpty) selectedMentions,
        if (asTask) true,
      ]);
      var attempt = _attempts[scope];
      if (attempt == null || attempt.fingerprint != fingerprint) {
        attempt = _SendAttempt(fingerprint, randomId ?? client.newRandomId());
        _attempts[scope] = attempt;
        await _save('attempt', scope, {
          'fingerprint': fingerprint,
          'randomId': attempt.randomId,
          'channelId': channel?.id,
        });
      }
      if (!currentSend()) return false;
      final sent = await client.sendWithReceipt(
        id,
        text,
        attachments: ids,
        mentions: selectedMentions.isEmpty ? null : selectedMentions,
        randomId: attempt.randomId,
        asTask: asTask,
      );
      final message = sent.message;
      if (!currentSend()) return true;
      // Web MessageInput replaces the strip with each send's receipt.
      pendingMentionActions[scope] = normalizePendingMentionActions(
        sent.receipt['pendingMentionActions'],
      );
      _attempts.remove(scope);
      _save('attempt', scope, null);
      _uploads.remove(scope);
      ledger.ingest([message.json], expectedGeneration: generation);
      visibleIds.putIfAbsent(id, () => {}).add(message.id);
      _saveWindow(id, thread: thread);
      notifyListeners();
      return true;
    } catch (e) {
      if (!currentSend()) return false;
      error = '$e';
      notifyListeners();
      return false;
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
        token = _replyToken(),
        authority = _windowAuthority();
    final value = await client.post(
      '/channels/$parentChannelId/threads',
      data: {'parentMessageId': parentId},
    );
    if (generation != ledger.generation ||
        window != threadGeneration ||
        navigationWindow != navigationRevision ||
        token != _replyToken() ||
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
        requestAuthority = _replyToken(),
        messageAuthority = _threadResourceAuthority(parentChannelId),
        generation = ledger.generation;
    final window = ++threadGeneration;
    bool current() =>
        !_disposed &&
        navigationWindow == navigationRevision &&
        requestAuthority == _replyToken() &&
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
    threadParent = acceptedParent;
    threadChannelId = knownThreadChannelId;
    threadLoading = true;
    _threadResolutionLoading = knownThreadChannelId == null;
    _threadParentLoading = acceptedParent == null;
    _threadResolutionError = null;
    threadHasMore = false;
    threadHistoryLimited = false;
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
        threadParent =
            liveParent ?? (parent == null ? null : RaftMessage(parent));
      } catch (_) {
        if (!current()) return;
        threadParent = null;
      } finally {
        if (current()) {
          _threadParentLoading = false;
          notifyListeners();
        }
      }
    }

    Future<void> resolveReplies() async {
      try {
        if (knownThreadChannelId == null) {
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
        threadHistoryLimited = page['historyLimited'] == true;
        threadHasMore = focusedMessageId == null
            ? !threadHistoryLimited && rows.length >= 50
            : page['hasOlder'] == true;
        client.joinChannel(threadChannelId!);
        threadLoading = false;
        notifyListeners();
        await markRead(threadChannelId!);
        if (current()) _saveWindow(threadChannelId!, thread: true);
      } catch (e) {
        if (current()) {
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
    final replyAuthority = _replyToken();
    final window = ++channelGeneration;
    bool owned() =>
        !_disposed &&
        generation == ledger.generation &&
        window == channelGeneration &&
        navigationWindow == navigationRevision &&
        authority == _windowAuthority() &&
        replyAuthority == _replyToken() &&
        !_revokedChannels.contains(channelId);
    var next = [
      ...channels,
      ...dms,
    ].where((c) => c.id == channelId).firstOrNull;
    next ??= RaftChannel(
      Map<String, dynamic>.from(await client.get('/channels/$channelId')),
    );
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
      threadSummaries = {};
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
          threadSummaries = _hydrateThreadSummaries(
            tail['threadSummariesByParentMessageId'],
            channelId,
            expectedToken: replyAuthority,
          );
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
        threadSummaries = _hydrateThreadSummaries(
          context['threadSummariesByParentMessageId'],
          channelId,
          expectedToken: replyAuthority,
        );
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
    await refreshUnread();
    return value;
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

  Future<void> toggleReaction(RaftMessage message, String emoji) async {
    final key = '${message.id}:$emoji';
    if (_reactionWrites.containsKey(key)) return _reactionWrites[key];
    final generation = ledger.generation, serverId = client.serverId;
    if (serverId == null) return;
    Future<void> change() async {
      if (reactionViewer.reacted(message.id) == null) {
        final viewer = await client.get(
          '/messages/${message.id}/reactions/viewer',
        );
        if (_disposed || generation != ledger.generation) return;
        reactionViewer.accept(viewer, serverId: serverId);
      }
      final own = reactionViewer.reacted(message.id);
      if (own == null) {
        throw StateError('Your reaction state could not be loaded.');
      }
      final value = await client.request(
        own.contains(emoji) ? 'DELETE' : 'POST',
        '/messages/${message.id}/reactions',
        data: {'emoji': emoji},
      );
      if (_disposed ||
          generation != ledger.generation ||
          _revokedChannels.contains(message.channelId)) {
        return;
      }
      if (value is Map) {
        reactionViewer.accept(value['reactionViewer'], serverId: serverId);
        final row = Map<String, dynamic>.from(value)..remove('reactionViewer');
        ledger.ingest([row], expectedGeneration: generation);
        _saveWindow(
          message.channelId,
          thread: message.channelId == threadChannelId,
        );
      }
      notifyListeners();
    }

    final pending = change();
    _reactionWrites[key] = pending;
    try {
      await pending;
    } finally {
      if (identical(_reactionWrites[key], pending)) _reactionWrites.remove(key);
    }
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
    if (event.name == 'connected') {
      connected = true;
      recoverMembership();
      client.resume(ledger.watermark);
      refreshUnread();
      refreshChannels();
      refreshMessageSyncFlag();
      loadSidebar();
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
      _replyAuthorityEpoch++;
      if (event.name != 'channel:removed') threadRepliesSync.reset();
    }
    if (event.name == 'channel:updated' ||
        event.name == 'channel:members-updated' ||
        event.name == 'dm:new' ||
        event.name == 'channel:authority-updated') {
      refreshChannels();
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
      if (event.name == 'message:updated') {
        if (!ledger.ingestUpdate(row, expectedGeneration: ledger.generation)) {
          return;
        }
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
      if (row['channelId'] == channel?.id ||
          row['channelId'] == threadChannelId) {
        if (section == 'home') {
          refreshUnread();
        } else {
          markRead('${row['channelId']}');
        }
      } else {
        refreshUnread();
      }
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
            readState.consumeUpdate(
              fact,
              serverId: client.serverId!,
              principalId: client.user!.id,
            );
          }
        }
      }
      _persistReadState();
      refreshUnread();
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
      entityDirectory.removeListener(_entityDirectoryChanged);
      entityDirectory.dispose();
    }
    _imageAuthorities.clear();
    _attachmentImages?.dispose();
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
