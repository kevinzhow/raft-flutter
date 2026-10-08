import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';

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
  });
  factory AttachmentImageKey.fromMetadata({
    required AttachmentImageScope scope,
    required String channelId,
    required Map<String, dynamic> metadata,
    String rendition = 'original',
  }) => AttachmentImageKey(
    scope: scope,
    channelId: channelId,
    rendition: rendition,
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
  @override
  bool operator ==(Object other) =>
      other is AttachmentImageKey &&
      scope == other.scope &&
      channelId == other.channelId &&
      attachmentId == other.attachmentId &&
      revision == other.revision &&
      rendition == other.rendition;
  @override
  int get hashCode =>
      Object.hash(scope, channelId, attachmentId, revision, rendition);
}

class StaleAttachmentImage implements Exception {
  const StaleAttachmentImage();
}

class AttachmentImageBudgetExceeded implements Exception {
  const AttachmentImageBudgetExceeded();
}

/// Keeps the actual decoded image completer alive across ordinary row recycling.
/// A provider alone would avoid a bytes GET but could be re-decoded after the
/// global ImageCache evicts its codec. This handle is disposed on our own LRU,
/// authority invalidation or owner disposal.
class DecodedAttachmentImage {
  DecodedAttachmentImage({
    required this.provider,
    required this.encodedBytes,
    required this.decodedBytes,
    required this._release,
  });
  final MemoryImage provider;
  final int encodedBytes, decodedBytes;
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
);

/// Returns its owner-held completer even after Flutter's global LRU evicts its
/// key. Keeping bytes or a MemoryImage alone would not prevent a new codec.
class AttachmentMemoryImage extends MemoryImage {
  AttachmentMemoryImage(super.bytes);
  final _AttachmentImageLifetime _lifetime = _AttachmentImageLifetime();
  int get codecCreations => _lifetime.codecCreations;
  @override
  ImageStreamCompleter loadImage(MemoryImage key, ImageDecoderCallback decode) {
    if (_lifetime.retired) throw const StaleAttachmentImage();
    return _lifetime.completer ??= super.loadImage(key, (buffer, {getTargetSize}) {
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

Future<DecodedAttachmentImage> decodeAttachmentImage(
  Uint8List bytes, {
  int maxDecodedBytes = 96 * 1024 * 1024,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height * 4 > maxDecodedBytes) {
      throw const AttachmentImageBudgetExceeded();
    }
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
  final provider = AttachmentMemoryImage(bytes);
  final stream = provider.resolve(ImageConfiguration.empty);
  final ready = Completer<DecodedAttachmentImage>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, synchronous) {
      final size = info.image.width * info.image.height * 4;
      final keepAlive = stream.completer!.keepAlive();
      info.dispose();
      stream.removeListener(listener);
      ready.complete(
        DecodedAttachmentImage(
          provider: provider,
          encodedBytes: bytes.length,
          decodedBytes: size,
          release: () async {
            provider.retire();
            keepAlive.dispose();
            await provider.evict();
          },
        ),
      );
    },
    onError: (Object error, StackTrace? trace) {
      stream.removeListener(listener);
      provider.retire();
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
  Future<MemoryImage> get ready async {
    final value = await _entry.ready.future;
    if (!active) throw const StaleAttachmentImage();
    return value.provider;
  }

  void release() {
    if (_released) return;
    _released = true;
    _entry.leases.remove(this);
    if (_entry.leases.isEmpty && _entry.value == null) {
      _owner._drop(_entry);
    }
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
  bool retired = false;
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
    this.maxEntries = 64,
    this.maxEncodedBytes = 64 * 1024 * 1024,
    this.maxDecodedBytes = 96 * 1024 * 1024,
    this.maxConcurrentLoads = 4,
  }) : _decoder =
           decoder ??
           ((bytes) =>
               decodeAttachmentImage(bytes, maxDecodedBytes: maxDecodedBytes)) {
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
  final int maxEntries, maxEncodedBytes, maxDecodedBytes, maxConcurrentLoads;
  final LinkedHashMap<AttachmentImageKey, _ImageEntry> _entries =
      LinkedHashMap();
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

  Future<void> _load(_ImageEntry e) async {
    DecodedAttachmentImage? decoded;
    try {
      final loader = e.load!;
      e.load = null; // Idle cached bytes do not retain a retired row callback.
      final bytes = await loader(e.cancel);
      if (!_live(e) ||
          e.cancel.isCancelled ||
          !e.leases.any((lease) => lease.active)) {
        throw const StaleAttachmentImage();
      }
      if (bytes.length > maxEncodedBytes) {
        throw const AttachmentImageBudgetExceeded();
      }
      decoded = await _decoder(bytes);
      if (!_live(e) ||
          e.cancel.isCancelled ||
          !e.leases.any((lease) => lease.active)) {
        throw const StaleAttachmentImage();
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

  void _drop(_ImageEntry e) {
    if (e.retired) return;
    e.retired = true;
    e.load = null;
    if (identical(_entries[e.key], e)) _entries.remove(e.key);
    _queue.remove(e);
    e.cancel.cancel();
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

  void invalidateChannel(String channelId) {
    for (final e
        in _entries.values
            .where((e) => e.key.channelId == channelId)
            .toList()) {
      _drop(e);
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
