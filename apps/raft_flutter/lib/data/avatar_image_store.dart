import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/memory_release.dart';
import 'attachment_disk_cache.dart';

/// Persistent encoded avatar / icon pictures (the layer under the decoded
/// bitmaps of `RaftHotImages`, see raft_ui `avatar_image_cache.dart`), kept in
/// the `public` namespace of the shared [AttachmentDiskCache] that Settings >
/// Storage shows and clears: one root, one size figure, one "Clear cache".
/// The namespace is shared by every account and is not purged on sign-out
/// (avatars are public pictures), has its own cap and recency order, and is
/// never evicted to make room for attachments; keys are the stable URL keys.
///
/// Each entry is `RIV1`, the expiry time (8 bytes big-endian ms), the lengths
/// of the `ETag` and `Last-Modified` (2 bytes each), those two strings and the
/// picture. (Entries from before validators existed are the 8-byte expiry and
/// the picture; they still read.) The expiry is the server's `Cache-Control`
/// freshness (`/api/avatars/**` is `public, max-age=31536000, immutable`;
/// Gravatar is minutes; `external-avatars` is `public, no-cache,
/// must-revalidate` with a strong `ETag`), capped at [ttl], and [unknownTtl]
/// when the server said nothing. `no-cache` and expired entries that carry a
/// validator stay as stale entries (for [staleRetention]) so the next use can
/// show them at once and send `If-None-Match` / `If-Modified-Since`; a stale
/// entry without a validator is a miss and is removed, and `no-store` is never
/// written.
class AvatarImageStore implements RaftImageByteStore {
  AvatarImageStore(
    this._cache, {
    this.ttl = const Duration(days: 14),
    this.unknownTtl = const Duration(hours: 1),
    this.staleRetention = const Duration(days: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AttachmentDiskCache _cache;
  final Duration ttl, unknownTtl, staleRetention;
  final DateTime Function() _now;

  static const _magic = [0x52, 0x49, 0x56, 0x31]; // "RIV1"
  static const _maxValidator = 1024;

  /// The picture under [key] while it is fresh (null once it ran out).
  Future<Uint8List?> read(String key) async {
    final entry = await readEntry(key);
    if (entry == null || !_now().isBefore(entry.expires)) return null;
    return entry.bytes;
  }

  @override
  Future<RaftStoredImage?> readEntry(String key) async {
    final data = await _cache.readPublic(key);
    if (data == null) return null;
    final entry = _decode(data);
    if (entry == null) {
      unawaited(_cache.removePublic(key));
      return null;
    }
    final now = _now();
    final usable =
        now.isBefore(entry.expires) ||
        (entry.canRevalidate &&
            now.isBefore(entry.expires.add(staleRetention)));
    if (!usable) {
      unawaited(_cache.removePublic(key));
      return null;
    }
    return entry;
  }

  @override
  Future<void> write(
    String key,
    Uint8List bytes, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) async {
    final granted = maxAge ?? unknownTtl;
    final canRevalidate =
        _validator(etag) != null || _validator(lastModified) != null;
    if (granted <= Duration.zero && !canRevalidate) return;
    await _cache.writePublic(
      key,
      _encode(bytes, _expiry(granted), etag, lastModified),
    );
  }

  @override
  Future<void> touch(
    String key, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) async {
    final data = await _cache.readPublic(key);
    final entry = data == null ? null : _decode(data);
    if (entry == null) return;
    await _cache.writePublic(
      key,
      _encode(
        entry.bytes,
        _expiry(maxAge ?? unknownTtl),
        etag ?? entry.etag,
        lastModified ?? entry.lastModified,
      ),
    );
  }

  DateTime _expiry(Duration granted) {
    final lifetime = granted < ttl ? granted : ttl;
    return _now().add(lifetime < Duration.zero ? Duration.zero : lifetime);
  }

  static String? _validator(String? value) =>
      value == null || value.isEmpty || value.length > _maxValidator
      ? null
      : value;

  static Uint8List _encode(
    Uint8List bytes,
    DateTime expires,
    String? etag,
    String? lastModified,
  ) {
    final tag = utf8.encode(_validator(etag) ?? '');
    final modified = utf8.encode(_validator(lastModified) ?? '');
    final head = 4 + 8 + 2 + 2;
    final entry = Uint8List(head + tag.length + modified.length + bytes.length);
    entry.setRange(0, 4, _magic);
    final view = ByteData.sublistView(entry);
    view.setInt64(4, expires.millisecondsSinceEpoch);
    view.setUint16(12, tag.length);
    view.setUint16(14, modified.length);
    entry.setRange(head, head + tag.length, tag);
    entry.setRange(
      head + tag.length,
      head + tag.length + modified.length,
      modified,
    );
    entry.setRange(head + tag.length + modified.length, entry.length, bytes);
    return entry;
  }

  static RaftStoredImage? _decode(Uint8List data) {
    if (data.length > 8 + 4 && _hasMagic(data)) {
      if (data.length < 16) return null;
      final view = ByteData.sublistView(data);
      final tag = view.getUint16(12), modified = view.getUint16(14);
      final bodyAt = 16 + tag + modified;
      if (bodyAt >= data.length) return null;
      return RaftStoredImage(
        Uint8List.sublistView(data, bodyAt),
        expires: DateTime.fromMillisecondsSinceEpoch(view.getInt64(4)),
        etag: tag == 0
            ? null
            : utf8.decode(data.sublist(16, 16 + tag), allowMalformed: true),
        lastModified: modified == 0
            ? null
            : utf8.decode(data.sublist(16 + tag, bodyAt), allowMalformed: true),
      );
    }
    if (data.length <= 8) return null;
    return RaftStoredImage(
      Uint8List.sublistView(data, 8),
      expires: DateTime.fromMillisecondsSinceEpoch(
        ByteData.sublistView(data, 0, 8).getInt64(0),
      ),
    );
  }

  static bool _hasMagic(Uint8List data) {
    for (var i = 0; i < 4; i++) {
      if (data[i] != _magic[i]) return false;
    }
    return true;
  }
}

// One pooled client per proxy service (the app has one).
final _avatarClients = Expando<HttpClient>('avatar http client');

/// Fetches an avatar through the shared proxy decision (docs/system-proxy.md).
/// One pooled client; no credentials of any kind are attached. With [etag] /
/// [lastModified] it is a conditional GET (`If-None-Match` /
/// `If-Modified-Since`) and a 304 answers [RaftFetchedImage.notModified]
/// without a body.
Future<RaftFetchedImage> fetchAvatarImage(
  String url, {
  SystemProxy? proxy,
  Duration timeout = const Duration(seconds: 20),
  int maxBytes = 4 * 1024 * 1024,
  String? etag,
  String? lastModified,
}) async {
  final service = proxy ?? SystemProxy.instance;
  final uri = Uri.parse(url);
  await service.ready(uri);
  final client = _avatarClients[service] ??= service.createHttpClient()
    ..idleTimeout = const Duration(seconds: 60)
    ..maxConnectionsPerHost = 8
    ..autoUncompress = true;
  final request = await client.getUrl(uri).timeout(timeout);
  if (etag != null) request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
  if (lastModified != null) {
    request.headers.set(HttpHeaders.ifModifiedSinceHeader, lastModified);
  }
  final response = await request.close().timeout(timeout);
  final cacheControl = response.headers.value(HttpHeaders.cacheControlHeader);
  final tag = response.headers.value(HttpHeaders.etagHeader);
  final modified = response.headers.value(HttpHeaders.lastModifiedHeader);
  if (response.statusCode == HttpStatus.notModified &&
      (etag != null || lastModified != null)) {
    await response.drain<void>();
    return RaftFetchedImage.notModified(
      maxAge: raftCacheControlMaxAge(cacheControl),
      etag: tag,
      lastModified: modified,
    );
  }
  if (response.statusCode != HttpStatus.ok) {
    await response.drain<void>();
    throw RaftImageHttpError(response.statusCode);
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response.timeout(timeout)) {
    bytes.add(chunk);
    if (bytes.length > maxBytes) {
      throw const RaftImageHttpError(HttpStatus.requestEntityTooLarge);
    }
  }
  return RaftFetchedImage(
    bytes.takeBytes(),
    maxAge: raftCacheControlMaxAge(cacheControl),
    etag: tag,
    lastModified: modified,
    noStore: raftCacheControlNoStore(cacheControl),
  );
}

/// Points the avatar layer at the proxy-aware fetcher and the shared disk
/// cache, registers the memory-pressure shrink, and makes "Clear cache" in
/// Settings > Storage forget the in-memory avatars too (the next mount then
/// fetches once). Called once at start-up.
void installAvatarImageCache(
  AttachmentDiskCache cache, {
  RaftMemoryRelease? memoryRelease,
}) {
  RaftImageBytes.instance
    ..fetcher = fetchAvatarImage
    ..revalidator = fetchAvatarImage
    ..store = AvatarImageStore(cache);
  (memoryRelease ?? RaftMemoryRelease.instance).addTrimmer(trimAvatarImages);
  cache.addPublicClearListener(clearAvatarImages);
}

/// Forgets every avatar held in memory (decoded, encoded and remembered
/// failures); widgets that show one keep theirs until they unmount.
void clearAvatarImages() {
  RaftHotImages.instance.evictAll();
  RaftImageBytes.instance
    ..clearMemory()
    ..forgetFailures();
}

/// Memory pressure shrinks the avatar caches to a small floor (64 decoded
/// avatars / 4 MB, 1 MB of encoded bytes) instead of emptying them: Android
/// reports the app being hidden as pressure, and avatars are what makes the
/// app look populated when it comes back. A time-based background trim keeps
/// them whole (they are bounded: `RaftHotImages` 24 MB).
@visibleForTesting
void trimAvatarImages(RaftMemoryTrim reason) {
  if (reason != RaftMemoryTrim.pressure) return;
  RaftHotImages.instance.trimTo();
  RaftImageBytes.instance.trimMemory(1024 * 1024);
}
