import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'workspace_cache.dart';
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
  }) {
    subscription = client.events.listen(_event);
  }
  final RaftClient client;
  final WorkspaceCache? cache;
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

  bool foreground = true;
  void setForeground(bool value) {
    foreground = value;
    if (value && section == 'chat') {
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
      client.selectServer(null);
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
    _windowState[id] = (_windowAuthority(), thread ? threadHasMore : hasMore);
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
      'parentChannelId': thread ? threadParent?.channelId : id,
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

  String? draftScope({bool thread = false}) => thread
      ? (threadParent == null ? null : 'thread:${threadParent!.id}')
      : channel?.id;
  bool get conversationPaused =>
      channel != null && channelConversionBlocksSending(channel!.json);
  List<UploadDraft> uploads({bool thread = false}) =>
      _uploads[draftScope(thread: thread)] ?? [];
  bool uploadsReady({bool thread = false}) =>
      uploads(thread: thread).every((u) => u.id != null);
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
  final Map<String, (String, bool)> _windowState = {};
  final Set<String> _contextWindows = {};
  bool hasNewer = false, threadHasMore = false;
  bool threadHistoryLimited = false, historyLimited = false;
  final Map<String, bool> _windowHistoryLimited = {};
  String? highlightedMessageId;
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
  RaftMessage? threadParent;
  String? threadChannelId;
  bool loading = false,
      channelLoading = false,
      threadLoading = false,
      loadingOlder = false,
      hasMore = false;
  bool connected = false;
  String? error;
  String section = 'chat';
  int channelGeneration = 0, threadGeneration = 0;
  Map<String, dynamic> threadSummaries = {};
  List<RaftMessage> get messages => channel == null
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
    if (_revokedServers.contains(next.id)) return;
    server = next;
    if (mobileNavigation) section = 'home';
    if (!canVisitSection(section)) section = 'chat';
    sidebarOrder = {};
    client.selectServer(next.id);
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
    };
    final threadIds = <String>{
      for (final message in ledger.messages(id))
        if (message['threadChannelId'] is String) message['threadChannelId'],
      for (final summary in threadSummaries.values)
        if (summary is Map &&
            messageIds.contains(summary['parentMessageId']) &&
            summary['threadChannelId'] is String)
          summary['threadChannelId'],
      if (threadParent?.channelId == id && threadChannelId != null)
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
    if (threadParent?.channelId == id || threadIds.contains(threadChannelId)) {
      closeThread();
    }
    _persistReadState();
    if (principal != null && serverId != null) {
      _cacheWrites = _cacheWrites.then((_) async {
        try {
          await cache?.revokeChannel(origin, principal, serverId, id);
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

  Future<void> selectChannel(RaftChannel next, {bool autoRead = true}) async {
    channel = next;
    hasNewer = false;
    highlightedMessageId = null;
    final priorWindow = _windowState[next.id];
    if (priorWindow != null && priorWindow.$1 != _windowAuthority()) {
      visibleIds.remove(next.id);
      _windowState.remove(next.id);
      _windowHistoryLimited.remove(next.id);
    }
    hasMore =
        priorWindow != null &&
        priorWindow.$1 == _windowAuthority() &&
        priorWindow.$2;
    historyLimited = priorWindow != null && priorWindow.$1 == _windowAuthority()
        ? _windowHistoryLimited[next.id] == true
        : false;
    if (_contextWindows.remove(next.id)) visibleIds.remove(next.id);
    section = 'chat';
    threadParent = null;
    threadChannelId = null;
    threadGeneration++;
    loadingOlder = false;
    channelLoading = true;
    error = null;
    final window = ++channelGeneration;
    final generation = ledger.generation;
    final replyAuthority = _replyToken();
    final authority = _windowAuthority();
    bool current() =>
        !_disposed &&
        window == channelGeneration &&
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
      final page = await _cached('window', next.id);
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
      final retained = messages.map((m) => m.json).toList();
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

  Future<void> markRead(String id) async {
    if (!foreground ||
        id == channel?.id && (!_mainPresented || !_chatTabPresented) ||
        id == threadChannelId && !_threadPresented ||
        section != 'chat' ||
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
          id != channel?.id && id != threadChannelId) {
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
    final intendedChannel = channel?.id, intendedParent = threadParent?.id;
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
        (!thread || intendedParent == threadParent?.id) &&
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
      final message = await client.send(
        id,
        text,
        attachments: ids,
        mentions: selectedMentions.isEmpty ? null : selectedMentions,
        randomId: attempt.randomId,
        asTask: asTask,
      );
      if (!currentSend()) return true;
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
    final parent = threadParent;
    if (parent == null) return null;
    final generation = ledger.generation, window = threadGeneration;
    final value = await client.post(
      '/channels/${parent.channelId}/threads',
      data: {'parentMessageId': parent.id},
    );
    if (generation != ledger.generation || window != threadGeneration) {
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
  }) async {
    threadParent = parent;
    threadChannelId = null;
    threadLoading = true;
    threadHasMore = false;
    threadHistoryLimited = false;
    highlightedMessageId = focusedMessageId;
    final window = ++threadGeneration, generation = ledger.generation;
    notifyListeners();
    try {
      await _restoreDraft('thread:${parent.id}');
      dynamic info;
      try {
        info = await client.get(
          '/channels/${parent.channelId}/threads/${parent.id}',
        );
      } on RaftApiException catch (e) {
        if (e.status != 404) rethrow;
      }
      if (window != threadGeneration || generation != ledger.generation) return;
      if (info == null) return;
      threadChannelId = info['threadChannelId'];
      final page = focusedMessageId == null
          ? await client.messagePage(threadChannelId!)
          : await client.get(
              '/messages/context/$focusedMessageId',
              query: {'channelId': threadChannelId},
            );
      if (window != threadGeneration || generation != ledger.generation) return;
      final rows = page['messages'] as List;
      ledger.ingest(
        rows.map((e) => Map<String, dynamic>.from(e)),
        expectedGeneration: generation,
      );
      visibleIds[threadChannelId!] = rows.map((e) => e['id'] as String).toSet();
      threadHistoryLimited = page['historyLimited'] == true;
      threadHasMore = focusedMessageId == null
          ? !threadHistoryLimited && rows.length >= 50
          : page['hasOlder'] == true;
      client.joinChannel(threadChannelId!);
      await markRead(threadChannelId!);
      _saveWindow(threadChannelId!, thread: true);
    } catch (e) {
      if (window == threadGeneration) error = '$e';
    } finally {
      if (window == threadGeneration) {
        threadLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> jumpToMessage(String channelId, String? messageId) async {
    var next = [
      ...channels,
      ...dms,
    ].where((c) => c.id == channelId).firstOrNull;
    next ??= RaftChannel(
      Map<String, dynamic>.from(await client.get('/channels/$channelId')),
    );
    if (messageId == null) {
      await selectChannel(next);
      return;
    }
    channel = next;
    section = 'chat';
    threadParent = null;
    threadChannelId = null;
    threadGeneration++;
    channelLoading = true;
    highlightedMessageId = messageId;
    final replyAuthority = _replyToken();
    final generation = ledger.generation, window = ++channelGeneration;
    notifyListeners();
    try {
      final context = await client.get(
        '/messages/context/$messageId',
        query: {'channelId': channelId},
      );
      if (generation != ledger.generation || window != channelGeneration) {
        return;
      }
      final target = context['canonicalTarget'];
      if (target is Map && target['kind'] == 'thread') {
        final parentId = target['threadParentMessageId'] as String;
        final parentContext = await client.get(
          '/messages/context/$parentId',
          query: {'channelId': channelId},
        );
        if (generation != ledger.generation || window != channelGeneration) {
          return;
        }
        final parentRows = parentContext['messages'] as List;
        ledger.ingest(
          parentRows.map((e) => Map<String, dynamic>.from(e)),
          expectedGeneration: generation,
        );
        visibleIds[channelId] = parentRows
            .map((e) => e['id'] as String)
            .toSet();
        hasMore = parentContext['hasOlder'] == true;
        hasNewer = parentContext['hasNewer'] == true;
        threadSummaries = _hydrateThreadSummaries(
          parentContext['threadSummariesByParentMessageId'],
          channelId,
          expectedToken: replyAuthority,
        );
        final parent = RaftMessage(
          Map<String, dynamic>.from(
            parentRows.firstWhere((e) => e['id'] == parentId),
          ),
        );
        await openThread(parent, focusedMessageId: messageId);
      } else {
        final rows = context['messages'] as List;
        ledger.ingest(
          rows.map((e) => Map<String, dynamic>.from(e)),
          expectedGeneration: generation,
        );
        _contextWindows.add(channelId);
        visibleIds[channelId] = rows.map((e) => e['id'] as String).toSet();
        hasMore = context['hasOlder'] == true;
        hasNewer = context['hasNewer'] == true;
        threadSummaries = _hydrateThreadSummaries(
          context['threadSummariesByParentMessageId'],
          channelId,
          expectedToken: replyAuthority,
        );
        await markRead(channelId);
      }
    } catch (e) {
      error = '$e';
    } finally {
      if (window == channelGeneration) {
        channelLoading = false;
        notifyListeners();
      }
    }
  }

  void closeThread() {
    threadGeneration++;
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
    _imageAuthorities.clear();
    _attachmentImages?.dispose();
    for (final drafts in _uploads.values) {
      for (final draft in drafts) {
        draft.cancel.cancel();
      }
    }
    _uploads.clear();
    subscription.cancel();
    client.dispose();
    super.dispose();
  }
}
