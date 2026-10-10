import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'attachment_image_store.dart';

export 'attachment_image_store.dart';

/// No capability URL, bearer credential or disk path is retained in this identity.
class AttachmentImageScope {
  const AttachmentImageScope({
    required this.origin,
    required this.principal,
    required this.server,
    required this.generation,
    required this.role,
  });
  final String origin, principal, server, role;
  final int generation;
  @override
  bool operator ==(Object other) =>
      other is AttachmentImageScope &&
      origin == other.origin &&
      principal == other.principal &&
      server == other.server &&
      generation == other.generation &&
      role == other.role;
  @override
  int get hashCode => Object.hash(origin, principal, server, generation, role);
}

/// Attachment IDs are immutable in the pinned upload contract. Projected
/// metadata fields also fence same-ID metadata/content-revision replacement.
/// Unknown capability URL/credential fields are deliberately excluded.
class AttachmentImageKey {
  const AttachmentImageKey({
    required this.scope,
    required this.channelId,
    required this.attachmentId,
    required this.revision,
    this.rendition = 'original',
    this.target,
  });
  factory AttachmentImageKey.fromMetadata({
    required AttachmentImageScope scope,
    required String channelId,
    required Map<String, dynamic> metadata,
    String rendition = 'original',
    AttachmentDecodeTarget? target,
  }) => AttachmentImageKey(
    scope: scope,
    channelId: channelId,
    rendition: rendition,
    target: target,
    attachmentId: metadata['id'] as String,
    revision: jsonEncode([
      metadata['id'], metadata['mimeType'], metadata['sizeBytes'],
      metadata['width'], metadata['height'],
      // These optional fields are used only if an accepted projection adds
      // them. They are not invented backend version or revalidation APIs.
      metadata['contentVersion'],
      metadata['contentHash'],
      metadata['updatedAt'],
    ]),
  );
  final AttachmentImageScope scope;
  final String channelId, attachmentId, revision, rendition;

  /// Decoded-bitmap bound; null decodes the source at its intrinsic size
  /// (within the repository's decoded budget). Only the lightbox does that.
  final AttachmentDecodeTarget? target;

  /// The fetched/persisted bytes this key decodes; independent of [target].
  AttachmentImageKey get source => target == null
      ? this
      : AttachmentImageKey(
          scope: scope,
          channelId: channelId,
          attachmentId: attachmentId,
          revision: revision,
          rendition: rendition,
        );

  /// Persistent identity: the authentication generation and role are not part
  /// of it (they change per launch); the repository re-verifies authority
  /// before every read.
  AttachmentImageStoreKey get storeKey => AttachmentImageStoreKey(
    identity: storeIdentity(scope),
    channelId: channelId,
    entry: jsonEncode([attachmentId, revision, rendition]),
  );
  static String storeIdentity(AttachmentImageScope scope) =>
      jsonEncode([scope.origin, scope.principal, scope.server]);

  @override
  bool operator ==(Object other) =>
      other is AttachmentImageKey &&
      scope == other.scope &&
      channelId == other.channelId &&
      attachmentId == other.attachmentId &&
      revision == other.revision &&
      rendition == other.rendition &&
      target == other.target;
  @override
  int get hashCode =>
      Object.hash(scope, channelId, attachmentId, revision, rendition, target);
}

/// The physical-pixel box an image is displayed in. Decoding keeps the source
/// aspect ratio: [cover] fills the box (cropped by BoxFit.cover), otherwise
/// it fits inside. Sizes are bucketed so small layout changes share a decode.
@immutable
class AttachmentDecodeTarget {
  const AttachmentDecodeTarget._(this.width, this.height, this.cover);
  factory AttachmentDecodeTarget.box(
    double logicalWidth,
    double logicalHeight, {
    required double devicePixelRatio,
    bool cover = false,
  }) {
    int bucket(double logical) {
      final physical = (logical * devicePixelRatio).ceil().clamp(1, 1 << 14);
      return ((physical + 63) ~/ 64) * 64;
    }

    return AttachmentDecodeTarget._(
      bucket(logicalWidth),
      bucket(logicalHeight),
      cover,
    );
  }
  final int width, height;
  final bool cover;

  /// Decoded size of a [sourceWidth]x[sourceHeight] image; never upscales.
  (int, int) decodedSize(int sourceWidth, int sourceHeight) {
    final sx = width / sourceWidth, sy = height / sourceHeight;
    final scale = math.min(1.0, cover ? math.max(sx, sy) : math.min(sx, sy));
    return (
      math.max(1, (sourceWidth * scale).round()),
      math.max(1, (sourceHeight * scale).round()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AttachmentDecodeTarget &&
      width == other.width &&
      height == other.height &&
      cover == other.cover;
  @override
  int get hashCode => Object.hash(width, height, cover);
}

class StaleAttachmentImage implements Exception {
  const StaleAttachmentImage();
}

class AttachmentImageBudgetExceeded implements Exception {
  const AttachmentImageBudgetExceeded();
}

/// Keeps the actual decoded image alive across ordinary row recycling.
/// A provider alone would avoid a bytes GET but could be re-decoded after the
/// global ImageCache evicts its codec. This handle is disposed on our own LRU,
/// authority invalidation or owner disposal.
class DecodedAttachmentImage {
  DecodedAttachmentImage({
    required this.provider,
    required this.encodedBytes,
    required this.decodedBytes,
    required this._release,
    this.width = 0,
    this.height = 0,
  });
  final ImageProvider provider;

  /// Bytes retained in memory: zero for a still image (only its bitmap is
  /// kept), the encoded source for an animated one.
  final int encodedBytes, decodedBytes;

  /// Decoded bitmap dimensions (0 when the decoder did not report them).
  final int width, height;
  final Future<void> Function() _release;
  bool _released = false;
  Future<void> dispose() async {
    if (_released) return;
    _released = true;
    await _release();
  }
}

typedef AttachmentImageLoader = Future<Uint8List> Function(CancelToken cancel);
typedef AttachmentImageDecoder = Future<DecodedAttachmentImage> Function(
  Uint8List bytes,
  AttachmentDecodeTarget? target,
);

/// Returns its owner-held completer even after Flutter's global LRU evicts its
/// key. Keeping bytes or a MemoryImage alone would not prevent a new codec.
/// Used for animated images, wrapped in a [ResizeImage] at the decode size.
class AttachmentMemoryImage extends MemoryImage {
  AttachmentMemoryImage(super.bytes);
  final _AttachmentImageLifetime _lifetime = _AttachmentImageLifetime();
  int get codecCreations => _lifetime.codecCreations;
  @override
  ImageStreamCompleter loadImage(MemoryImage key, ImageDecoderCallback decode) {
    if (_lifetime.retired) throw const StaleAttachmentImage();
    return _lifetime.completer ??= super.loadImage(key, (
      buffer, {
      getTargetSize,
    }) {
      _lifetime.codecCreations++;
      return decode(buffer, getTargetSize: getTargetSize);
    });
  }

  void retire() {
    _lifetime.retired = true;
    _lifetime.completer = null;
  }
}

/// Cache lifetime is owner state, rather than mutable provider identity fields.
class _AttachmentImageLifetime {
  ImageStreamCompleter? completer;
  bool retired = false;
  int codecCreations = 0;
}

/// A still image decoded once at its display size. The encoded bytes are not
/// retained; every resolution hands out a clone of the owned bitmap
/// synchronously, so a recycled or revisited row paints it in its first frame.
class AttachmentBitmapImage extends ImageProvider<AttachmentBitmapImage> {
  AttachmentBitmapImage._(this._image);
  ui.Image? _image;
  @override
  Future<AttachmentBitmapImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    AttachmentBitmapImage key,
    ImageDecoderCallback decode,
  ) {
    final image = _image;
    if (image == null) throw const StaleAttachmentImage();
    return OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image.clone())),
    );
  }

  void _retire() {
    _image?.dispose();
    _image = null;
  }
}

/// Decoded dimensions for [target] (or the intrinsic size), scaled down so the
/// bitmap stays within [maxDecodedBytes].
(int, int) attachmentDecodeSize(
  int width,
  int height,
  AttachmentDecodeTarget? target, {
  int maxDecodedBytes = 96 * 1024 * 1024,
}) {
  var (w, h) = target?.decodedSize(width, height) ?? (width, height);
  if (w * h * 4 > maxDecodedBytes) {
    final scale = math.sqrt(maxDecodedBytes / (w * h * 4));
    w = math.max(1, (w * scale).floor());
    h = math.max(1, (h * scale).floor());
  }
  return (w, h);
}

/// Decodes [bytes] once, at the [target] display size when given. A still
/// image keeps only the decoded bitmap; an animated image keeps its encoded
/// bytes and a size-bounded codec.
Future<DecodedAttachmentImage> decodeAttachmentImage(
  Uint8List bytes, {
  AttachmentDecodeTarget? target,
  int maxDecodedBytes = 96 * 1024 * 1024,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  final int width, height;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    (width, height) = attachmentDecodeSize(
      descriptor.width,
      descriptor.height,
      target,
      maxDecodedBytes: maxDecodedBytes,
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: width,
      targetHeight: height,
    );
    if (codec.frameCount == 1) {
      final frame = await codec.getNextFrame();
      final provider = AttachmentBitmapImage._(frame.image);
      return DecodedAttachmentImage(
        provider: provider,
        encodedBytes: 0,
        decodedBytes: frame.image.width * frame.image.height * 4,
        width: frame.image.width,
        height: frame.image.height,
        release: () async {
          await provider.evict();
          provider._retire();
        },
      );
    }
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
  final source = AttachmentMemoryImage(bytes);
  final provider = ResizeImage(
    source,
    width: width,
    height: height,
    policy: ResizeImagePolicy.exact,
  );
  final stream = provider.resolve(ImageConfiguration.empty);
  final ready = Completer<DecodedAttachmentImage>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, synchronous) {
      final keepAlive = stream.completer!.keepAlive();
      final decoded = DecodedAttachmentImage(
        provider: provider,
        encodedBytes: bytes.length,
        decodedBytes: info.image.width * info.image.height * 4,
        width: info.image.width,
        height: info.image.height,
        release: () async {
          source.retire();
          keepAlive.dispose();
          await provider.evict();
        },
      );
      info.dispose();
      stream.removeListener(listener);
      ready.complete(decoded);
    },
    onError: (Object error, StackTrace? trace) {
      stream.removeListener(listener);
      source.retire();
      unawaited(provider.evict());
      ready.completeError(error, trace);
    },
  );
  stream.addListener(listener);
  return ready.future;
}

class AttachmentImageLease {
  AttachmentImageLease._(this._owner, this._entry, this._authorized);
  final AttachmentImageRepository _owner;
  final _ImageEntry _entry;
  final bool Function() _authorized;
  bool _released = false;
  AttachmentImageKey get key => _entry.key;
  bool get active => !_released && _owner._live(_entry) && _authorized();

  /// Synchronous read of the decoded image; null while it is still loading,
  /// and once the lease or its authority is gone.
  ImageProvider? get value => active ? _entry.value?.provider : null;

  /// The decoded record (dimensions, retained bytes) while [value] is.
  DecodedAttachmentImage? get decoded => active ? _entry.value : null;
  Future<ImageProvider> get ready async {
    final value = await _entry.ready.future;
    if (!active) throw const StaleAttachmentImage();
    return value.provider;
  }

  /// True once the image was served from the persistent store (no network).
  bool get fromStore => _entry.fromStore;

  void release() {
    if (_released) return;
    _released = true;
    _entry.leases.remove(this);
    if (_entry.leases.isEmpty && _entry.value == null) {
      _owner._drop(_entry);
    }
  }

  /// Releases and, when no other consumer holds it, frees the decoded image
  /// instead of keeping it in the LRU (full-resolution lightbox images).
  void discard() {
    release();
    if (_entry.leases.isEmpty) _owner._drop(_entry);
  }
}

class _ImageEntry {
  _ImageEntry(this.key, this.load) {
    // A retired last consumer can legitimately abandon the shared completion.
    // Observe that internal future; every live lease still receives its error.
    unawaited(
      ready.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }
  final AttachmentImageKey key;
  AttachmentImageLoader? load;
  final CancelToken cancel = CancelToken();
  final ready = Completer<DecodedAttachmentImage>();
  final Set<AttachmentImageLease> leases = {};
  DecodedAttachmentImage? value;
  _SourceFetch? fetch;

  /// The token handed to this entry's network loader; cancelled on drop.
  CancelToken? fetchCancel;
  bool retired = false, fromStore = false;
}

/// One network fetch of a source shared by every decode of it (list preview
/// and lightbox). Cancelled once no waiting entry remains.
class _SourceFetch {
  _SourceFetch(this.key);
  final AttachmentImageKey key;
  final CancelToken cancel = CancelToken();
  final Set<_ImageEntry> waiters = {};
  late final Future<Uint8List> bytes;
  bool persisted = false;
}

/// One workspace/controller owns one bounded volatile repository. Retention
/// authority is NOT widget visibility: the owner verifies current identity,
/// membership/capabilities and canonical message/attachment projection. Each
/// lease independently gates publication with the mounted row's visibility.
/// The owner must synchronize on notifications and dispose on logout/disposal.
class AttachmentImageRepository {
  AttachmentImageRepository({
    required this._scope,
    required this._retainedAuthority,
    AttachmentImageDecoder? decoder,
    this.store,
    this.maxEntries = 64,
    this.maxEncodedBytes = 64 * 1024 * 1024,
    this.maxDecodedBytes = 96 * 1024 * 1024,
    this.maxConcurrentLoads = 4,
  }) : _decoder =
           decoder ??
           ((bytes, target) => decodeAttachmentImage(
             bytes,
             target: target,
             maxDecodedBytes: maxDecodedBytes,
           )) {
    if (maxEntries < 1 ||
        maxEncodedBytes < 1 ||
        maxDecodedBytes < 1 ||
        maxConcurrentLoads < 1) {
      throw ArgumentError('Image budgets must be positive.');
    }
  }
  AttachmentImageScope _scope;
  final bool Function(AttachmentImageKey) _retainedAuthority;
  final AttachmentImageDecoder _decoder;

  /// Persistent bytes behind the decoded entries; read only for keys that
  /// pass [canRead] and an active lease, written only after a good decode.
  final AttachmentImageByteStore? store;
  final int maxEntries, maxEncodedBytes, maxDecodedBytes, maxConcurrentLoads;
  final LinkedHashMap<AttachmentImageKey, _ImageEntry> _entries =
      LinkedHashMap();
  final Map<AttachmentImageKey, _SourceFetch> _fetches = {};
  final Queue<_ImageEntry> _queue = Queue();
  int _running = 0, _encoded = 0, _decoded = 0;
  bool _disposed = false;
  AttachmentImageScope get scope => _scope;
  int get entryCount => _entries.length;
  int get encodedByteCount => _encoded;
  int get decodedByteCount => _decoded;
  bool canRead(AttachmentImageKey key) =>
      !_disposed && key.scope == _scope && _retainedAuthority(key);
  bool _live(_ImageEntry e) =>
      !e.retired && identical(_entries[e.key], e) && canRead(e.key);

  /// Identity changes discard all providers. Ordinary channel navigation may
  /// retain authorized canonical rows; revoked/removed resources never do.
  void synchronize(AttachmentImageScope next) {
    if (_disposed) return;
    if (next != _scope) {
      _scope = next;
      clear();
    } else {
      for (final e in _entries.values.toList()) {
        if (!canRead(e.key)) _drop(e);
      }
    }
  }

  AttachmentImageLease acquire(
    AttachmentImageKey key, {
    required AttachmentImageLoader load,
    required bool Function() authorized,
  }) {
    if (!canRead(key) || !authorized()) throw const StaleAttachmentImage();
    // A same attachment/message slot with a changed projected revision retires
    // its old work. The old completion cannot enter the new cache or widget.
    for (final e in _entries.values.toList()) {
      if (e.key.scope == key.scope &&
          e.key.channelId == key.channelId &&
          e.key.attachmentId == key.attachmentId &&
          e.key.rendition == key.rendition &&
          e.key.target == key.target &&
          e.key.revision != key.revision) {
        _drop(e);
      }
    }
    var e = _entries.remove(key);
    if (e != null && !_liveDetached(e)) {
      _drop(e);
      e = null;
    }
    if (e == null) {
      _makeRoom(entries: 1);
      e = _ImageEntry(key, load);
      _entries[key] = e;
      _queue.add(e);
    } else {
      _entries[key] = e;
    }
    final lease = AttachmentImageLease._(this, e, authorized);
    e.leases.add(lease);
    scheduleMicrotask(_pump);
    return lease;
  }

  bool _liveDetached(_ImageEntry e) => !e.retired && canRead(e.key);

  /// A lease on an already decoded image, or null when [key] is not ready.
  /// Never starts a load; lets a row paint a cached image in its first frame.
  AttachmentImageLease? acquireReady(
    AttachmentImageKey key, {
    required bool Function() authorized,
  }) {
    if (!canRead(key) || !authorized()) return null;
    final e = _entries[key];
    if (e == null || e.value == null || !_liveDetached(e)) return null;
    _entries
      ..remove(key)
      ..[key] = e;
    final lease = AttachmentImageLease._(this, e, authorized);
    e.leases.add(lease);
    return lease;
  }

  void _makeRoom({int entries = 0, int encoded = 0, int decoded = 0}) {
    while (_entries.length + entries > maxEntries ||
        _encoded + encoded > maxEncodedBytes ||
        _decoded + decoded > maxDecodedBytes) {
      final idle = _entries.values.where(
        (e) => e.leases.isEmpty && e.value != null,
      );
      if (idle.isEmpty) throw const AttachmentImageBudgetExceeded();
      _drop(idle.first);
    }
  }

  void _pump() {
    while (!_disposed && _running < maxConcurrentLoads && _queue.isNotEmpty) {
      final e = _queue.removeFirst();
      if (!_live(e) || !e.leases.any((lease) => lease.active)) {
        _drop(e);
        continue;
      }
      _running++;
      unawaited(
        _load(e).whenComplete(() {
          _running--;
          _pump();
        }),
      );
    }
  }

  bool _wanted(_ImageEntry e) =>
      _live(e) && !e.cancel.isCancelled && e.leases.any((l) => l.active);

  Future<void> _load(_ImageEntry e) async {
    DecodedAttachmentImage? decoded;
    _SourceFetch? fetch;
    try {
      Uint8List? bytes;
      final store = this.store;
      if (store != null) {
        try {
          bytes = await store.read(e.key.storeKey);
        } catch (_) {
          bytes = null;
        }
        if (!_wanted(e)) throw const StaleAttachmentImage();
      }
      e.fromStore = bytes != null;
      if (bytes == null) {
        fetch = _join(e);
        try {
          bytes = await fetch.bytes;
        } finally {
          fetch.waiters.remove(e);
          e.fetch = null;
        }
      }
      e.load = null; // Idle cached bytes do not retain a retired row callback.
      if (!_wanted(e)) throw const StaleAttachmentImage();
      if (bytes.length > maxEncodedBytes) {
        throw const AttachmentImageBudgetExceeded();
      }
      try {
        decoded = await _decoder(bytes, e.key.target);
      } catch (_) {
        // Undecodable persisted bytes are not served again.
        if (e.fromStore) unawaited(_quietly(store!.remove(e.key.storeKey)));
        rethrow;
      }
      if (!_wanted(e)) throw const StaleAttachmentImage();
      if (store != null && fetch != null && !fetch.persisted) {
        fetch.persisted = true;
        unawaited(_quietly(store.write(e.key.storeKey, bytes)));
      }
      _makeRoom(encoded: decoded.encodedBytes, decoded: decoded.decodedBytes);
      _encoded += decoded.encodedBytes;
      _decoded += decoded.decodedBytes;
      e.value = decoded;
      decoded = null;
      e.ready.complete(e.value!);
    } catch (error, trace) {
      if (!e.ready.isCompleted) e.ready.completeError(error, trace);
      _drop(e);
    } finally {
      await decoded?.dispose();
    }
  }

  static Future<void> _quietly(Future<void> work) =>
      work.catchError((Object _) {});

  /// Joins (or starts) the network fetch of [e]'s source bytes.
  _SourceFetch _join(_ImageEntry e) {
    final source = e.key.source;
    var fetch = _fetches[source];
    if (fetch == null || fetch.cancel.isCancelled) {
      final loader = e.load!;
      final next = fetch = _SourceFetch(source);
      _fetches[source] = next;
      next.bytes = loader(next.cancel).whenComplete(() {
        if (identical(_fetches[source], next)) _fetches.remove(source);
      });
      // Abandoned fetches may fail after every waiter left.
      unawaited(next.bytes.then<void>((_) {}, onError: (Object _) {}));
    }
    fetch.waiters.add(e);
    e.fetch = fetch;
    e.fetchCancel = fetch.cancel;
    return fetch;
  }

  void _drop(_ImageEntry e) {
    if (e.retired) return;
    e.retired = true;
    e.load = null;
    if (identical(_entries[e.key], e)) _entries.remove(e.key);
    _queue.remove(e);
    e.cancel.cancel();
    final fetch = e.fetch;
    e.fetch = null;
    if (fetch != null && fetch.waiters.remove(e) && fetch.waiters.isEmpty) {
      if (identical(_fetches[fetch.key], fetch)) _fetches.remove(fetch.key);
    }
    // Shared work is only abandoned once no other entry waits on it; a
    // completed fetch ignores the cancellation.
    if (fetch == null || fetch.waiters.isEmpty) e.fetchCancel?.cancel();
    e.fetchCancel = null;
    if (!e.ready.isCompleted) {
      e.ready.completeError(const StaleAttachmentImage());
    }
    final value = e.value;
    e.value = null;
    if (value != null) {
      _encoded -= value.encodedBytes;
      _decoded -= value.decodedBytes;
      unawaited(value.dispose());
    }
  }

  void invalidate(AttachmentImageKey key) {
    final e = _entries[key];
    if (e != null) _drop(e);
  }

  /// Drops the channel's decoded images and its persisted bytes for the
  /// current identity (membership revoked or channel removed).
  void invalidateChannel(String channelId) {
    for (final e
        in _entries.values
            .where((e) => e.key.channelId == channelId)
            .toList()) {
      _drop(e);
    }
    final store = this.store;
    if (store != null && !_disposed) {
      unawaited(
        _quietly(
          store.purgeChannel(
            AttachmentImageKey.storeIdentity(_scope),
            channelId,
          ),
        ),
      );
    }
  }

  void clear() {
    for (final e in _entries.values.toList()) {
      _drop(e);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    clear();
  }
}
