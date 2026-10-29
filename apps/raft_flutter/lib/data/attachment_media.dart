import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/attachment_player_sessions.dart';
import '../platform/memory_budgets.dart';
import '../platform/memory_release.dart';
import 'attachment_image_repository.dart';
import 'attachment_url_cache.dart';

typedef AttachmentMediaGet = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});
typedef AttachmentMediaPost = Future<dynamic> Function(
  String path, {
  dynamic data,
});

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

/// Owns attachment resources shared by all presentations of one workspace.
///
/// Session identity and message-history admission stay with the workspace.
/// This owner receives their current facts through callbacks, and never
/// selects a server, loads a conversation or owns the API client.
class AttachmentMedia {
  AttachmentMedia({
    required this._scope,
    required this._get,
    required this._post,
    required this._isDisposed,
    required this._admitsImages,
    required this._isRevoked,
    required this._retainedByHistory,
    this.imageStore,
    AttachmentUrlCache? urls,
  }) : _urls = urls ?? AttachmentUrlCache() {
    _removePlayerTrim = playerSessions.installMemoryTrim();
  }

  final AttachmentImageScope Function() _scope;
  final AttachmentMediaGet _get;
  final AttachmentMediaPost _post;
  final bool Function() _isDisposed, _admitsImages;
  final bool Function(String? channelId) _isRevoked;
  final bool Function(AttachmentImageKey key) _retainedByHistory;

  /// Persistent bytes for inline/list image previews (null: memory only).
  final AttachmentImageByteStore? imageStore;
  AttachmentImageRepository? _images;
  final _imageAuthorities =
      <AttachmentImageKey, Map<Object, bool Function()>>{};
  VoidCallback? _removeImageTrimmer, _removeImageReporter, _removePlayerTrim;
  final AttachmentUrlCache _urls;
  final playerSessions = PlayerSessions();
  int _urlRequests = 0;
  DateTime? _previewGateAt;
  bool? _previewGate;
  Object? _previewGateScope;
  bool _disposed = false;

  int get retainedImageDecodedBytes => _images?.decodedByteCount ?? 0;
  int get retainedImageCount => _images?.entryCount ?? 0;
  int get retainedImageEncodedBytes => _images?.encodedByteCount ?? 0;

  /// Diagnostics forwarded by the controller's existing test facade.
  int get debugUrlRequests => _urlRequests;
  AttachmentUrlCache get debugUrls => _urls;

  bool _retainsImage(AttachmentImageKey key) {
    if (_disposed ||
        _isDisposed() ||
        key.scope != _scope() ||
        !_admitsImages()) {
      return false;
    }
    // A freshly accepted Files row is an independent permission projection.
    // Its active owner never grants authority through a cached URL or count.
    return _imageAuthorities[key]?.values.any((admitted) => admitted()) ==
            true ||
        _retainedByHistory(key);
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
      _images?.synchronize(_scope());
    };
  }

  AttachmentImageRepository _newImageRepository() {
    final budgets = RaftMemoryBudgets.current;
    final repository = AttachmentImageRepository(
      scope: _scope(),
      retainedAuthority: _retainsImage,
      store: imageStore,
      maxEntries: budgets.attachmentImageEntries,
      maxDecodedBytes: budgets.attachmentImageDecodedBytes,
      maxActiveDecodedBytes: budgets.attachmentImageActiveDecodedBytes,
      maxEncodedBytes: budgets.attachmentImageEncodedBytes,
    );
    // Decoded bitmaps are rebuildable from the byte store: let go of the
    // unleased ones under memory pressure and while the app is hidden.
    _removeImageReporter = RaftMemoryRelease.instance.addReporter(
      'attachmentImages',
      () =>
          '${repository.entryCount}/${repository.maxEntries} entries '
          '${repository.decodedByteCount}/${repository.maxDecodedBytes} B decoded '
          '${repository.encodedByteCount} B encoded',
    );
    _removeImageTrimmer = RaftMemoryRelease.instance.addTrimmer(
      (reason) => repository.trimIdle(
        pressure: reason == RaftMemoryTrim.pressure,
        reason: reason.name,
      ),
    );
    return repository;
  }

  WorkspaceAttachmentImageLease acquireImage(
    AttachmentImageKey key, {
    required AttachmentImageLoader load,
    required bool Function() authorized,
    bool foreground = false,
    bool bestAvailable = false,
  }) {
    final releaseAuthority = _registerImageAuthority(key, authorized);
    try {
      final repository = _images ??= _newImageRepository();
      repository.synchronize(_scope());
      return WorkspaceAttachmentImageLease(
        repository.acquire(
          key,
          load: load,
          authorized: authorized,
          foreground: foreground,
          bestAvailable: bestAvailable,
        ),
        releaseAuthority,
      );
    } catch (_) {
      releaseAuthority();
      rethrow;
    }
  }

  /// Synchronous lookup: a lease on the already decoded image for [key], or
  /// null when it is not retained (or no longer authorized). Never loads.
  WorkspaceAttachmentImageLease? peekImage(
    AttachmentImageKey key, {
    required bool Function() authorized,
  }) {
    final repository = _images;
    if (repository == null || _disposed || _isDisposed()) return null;
    repository.synchronize(_scope());
    final releaseAuthority = _registerImageAuthority(key, authorized);
    final lease = repository.acquireReady(key, authorized: authorized);
    if (lease == null) {
      releaseAuthority();
      return null;
    }
    return WorkspaceAttachmentImageLease(lease, releaseAuthority);
  }

  /// The persistent attachment cache, when this owner has one (the
  /// installed app cache by default; tests with a fake byte store have none).
  AttachmentDiskCache? get diskCache {
    final store = imageStore;
    return store is AttachmentDiskCache ? store : null;
  }

  /// Persistent key of a derived entry (`file`, `preview`, `html`) of
  /// [metadata]'s attachment for the current account and server.
  AttachmentImageStoreKey cacheKey(
    Map<String, dynamic> metadata,
    String kind, {
    required String channelId,
  }) => AttachmentImageKey.storeKeyOf(
    scope: _scope(),
    channelId: channelId,
    metadata: metadata,
    kind: kind,
  );

  /// True when [key]'s source bytes are already stored on this device, so
  /// nothing needs to be signed or fetched for them.
  Future<bool> stored(AttachmentImageKey key) async {
    final disk = diskCache;
    if (disk == null) return false;
    try {
      return await disk.contains(key.source.storeKey);
    } catch (_) {
      return false;
    }
  }

  /// The signed URL of attachment [id]. Reuses a fresh cached URL and joins a
  /// request already in flight; otherwise asks the API once. [disposition]
  /// null sends no disposition (server default). `attachment` URLs are
  /// one-shot downloads and are never retained. [channelId] ties the entry to
  /// its channel so revocation drops it.
  Future<String> url(
    String id, {
    String? disposition = 'inline',
    String? channelId,
    bool refresh = false,
    bool coalesce = false,
  }) {
    final scope = _scope();
    Future<dynamic> fetch() {
      _urlRequests++;
      return _get(
        '/attachments/${Uri.encodeComponent(id)}/url',
        query: disposition == null ? null : {'disposition': disposition},
      );
    }

    if (disposition == 'attachment' || _isRevoked(channelId)) {
      return fetch().then(_urlOf);
    }
    if (refresh) _urls.invalidate(id, disposition: disposition ?? '');
    if (coalesce && disposition == 'inline') {
      // Many tiles asking at once (a screenful of images) share one batch
      // request instead of sending one request each.
      return _urls.resolveCoalesced(
        id,
        scope: scope,
        channelId: channelId,
        fetchMany: _fetchAttachmentUrls,
        fetch: fetch,
      );
    }
    return _urls.resolve(
      id,
      disposition: disposition ?? '',
      scope: scope,
      channelId: channelId,
      fetch: fetch,
    );
  }

  static String _urlOf(dynamic body) {
    final url = body is Map ? body['url'] : null;
    if (url is! String || url.isEmpty) {
      throw const FormatException('Invalid attachment response.');
    }
    return url;
  }

  /// A transfer rejected [id]'s cached URL (expired): forget it.
  void invalidateUrl(String id) {
    _urls.invalidate(id);
  }

  /// `POST /attachments/urls` (1..50 ids) for the visible tiles that need a
  /// signed URL in this frame (images without a server thumbnail). Foreground
  /// work: a user-visible load, never speculative.
  Future<dynamic> _fetchAttachmentUrls(List<String> ids) {
    _urlRequests++;
    return _post('/attachments/urls', data: {'attachmentIds': ids});
  }

  /// Whether document/media previews are enabled on the server. The flag is
  /// per server, so a short per-scope memory removes a serial round trip from
  /// every preview open; a failed read is never remembered.
  Future<bool> previewEnabled() async {
    final scope = _scope();
    final at = _previewGateAt;
    if (_previewGate != null &&
        _previewGateScope == scope &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 2)) {
      return _previewGate!;
    }
    final gate = await _get('/messages/attachment-preview/enabled');
    final enabled = gate is Map && gate['enabled'] == true;
    if (_disposed || _isDisposed() || scope != _scope()) return enabled;
    _previewGate = enabled;
    _previewGateScope = scope;
    _previewGateAt = DateTime.now();
    return enabled;
  }

  /// Rechecks accepted identity and image authority before observers rebuild.
  void synchronize() {
    final scope = _scope();
    _images?.synchronize(scope);
    _urls.synchronize(scope);
    playerSessions.synchronize(scope);
  }

  /// Drops rebuildable idle data without disturbing a held image or player.
  void trimRebuildable() {
    _images?.trimIdle();
    _urls.dropResolved();
    playerSessions.trimStills();
    playerSessions.forgetFrames();
  }

  /// Removes a revoked channel's media, including warm bytes not decoded yet.
  void revokeChannel(String channelId) {
    _images
      ?..synchronize(_scope())
      ..invalidateChannel(channelId);
    _urls.invalidateChannel(channelId);
    playerSessions.invalidateChannel(channelId);
    final store = imageStore;
    if (store != null) {
      unawaited(
        store
            .purgeChannel(AttachmentImageKey.storeIdentity(_scope()), channelId)
            .catchError((Object _) {}),
      );
    }
  }

  /// Captures the revoked identity before the session resets its selection.
  void purgeIdentity(String origin, String principal, String serverId) {
    final store = imageStore;
    if (store != null) {
      unawaited(
        store
            .purgeIdentity(
              AttachmentImageKey.identityOf(origin, principal, serverId),
            )
            .catchError((Object _) {}),
      );
    }
  }

  /// Stops callbacks before releasing resources. Borrowed pages never call it.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _imageAuthorities.clear();
    _removeImageTrimmer?.call();
    _removeImageTrimmer = null;
    _removeImageReporter?.call();
    _removeImageReporter = null;
    _removePlayerTrim?.call();
    _removePlayerTrim = null;
    _images?.dispose();
    _urls.dispose();
    playerSessions.dispose();
  }
}
