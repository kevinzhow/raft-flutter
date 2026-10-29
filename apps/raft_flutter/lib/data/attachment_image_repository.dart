import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'attachment_image_store.dart';
import 'attachment_transfer.dart';

export 'attachment_disk_cache.dart';
export 'attachment_image_store.dart';
export 'attachment_transfer.dart';

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
    revision: revisionOf(metadata),
  );

  /// The attachment's content identity: its id plus every projected field
  /// that fences same-ID replacement.
  static String revisionOf(Map<String, dynamic> metadata) => jsonEncode([
    metadata['id'], metadata['mimeType'], metadata['sizeBytes'],
    metadata['width'], metadata['height'],
    // These optional fields are used only if an accepted projection adds
    // them. They are not invented backend version or revalidation APIs.
    metadata['contentVersion'],
    metadata['contentHash'],
    metadata['updatedAt'],
  ]);

  /// Persistent key of a derived entry of one attachment that is not an image
  /// source: a preview input [kind] such as `file`, `preview` or `html`. Same
  /// identity, channel and revision rules as [storeKey].
  static AttachmentImageStoreKey storeKeyOf({
    required AttachmentImageScope scope,
    required String channelId,
    required Map<String, dynamic> metadata,
    required String kind,
  }) => AttachmentImageStoreKey(
    identity: storeIdentity(scope),
    channelId: channelId,
    entry: jsonEncode([metadata['id'], revisionOf(metadata), kind]),
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

  /// Persisted entries that can serve this key, best first. With
  /// [bestAvailable] (list rows, cards, posters: pictures whose exact
  /// resolution does not matter) the original decoded at the target size
  /// comes first, else the server thumbnail. Which of the two a message asks
  /// for depends on whether it currently carries a `thumbnailUrl`, which
  /// varies between launches; without this the other version would be
  /// downloaded again. Without it (the lightbox and its preloads) only this
  /// key's own rendition counts: a stored 320px thumbnail never stands in for
  /// the full picture.
  List<AttachmentImageStoreKey> storeLookup({required bool bestAvailable}) =>
      bestAvailable && _isImageRendition(rendition)
      ? [_withRendition('original'), _withRendition('thumbnail')]
      : [storeKey];

  static bool _isImageRendition(String rendition) =>
      rendition == 'original' || rendition == 'thumbnail';

  AttachmentImageStoreKey _withRendition(String value) =>
      AttachmentImageStoreKey(
        identity: storeIdentity(scope),
        channelId: channelId,
        entry: jsonEncode([attachmentId, revision, value]),
      );

  static String storeIdentity(AttachmentImageScope scope) =>
      identityOf(scope.origin, scope.principal, scope.server);

  /// Disk identity of one account on one server (see [storeKey]).
  static String identityOf(String origin, String principal, String server) =>
      jsonEncode([origin, principal, server]);

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

/// The codec explicitly rejected the image's format or encoded data.
class AttachmentImageDecodeFailed implements Exception {
  const AttachmentImageDecodeFailed();
}

/// A decoder failure that does not establish that the source bytes are bad.
/// Native allocation failures and unknown errors can recover on a later try.
class AttachmentImageDecodeUnavailable implements Exception {
  const AttachmentImageDecodeUnavailable(this.cause);
  final Object cause;
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
  if (maxDecodedBytes < 4) throw const AttachmentImageBudgetExceeded();
  var (w, h) = target?.decodedSize(width, height) ?? (width, height);
  if (w * h * 4 > maxDecodedBytes) {
    final scale = math.sqrt(maxDecodedBytes / (w * h * 4));
    w = math.max(1, (w * scale).floor());
    h = math.max(1, (h * scale).floor());
    // An extremely narrow image can round one dimension up to 1 pixel.
    w = math.min(w, maxDecodedBytes ~/ 4);
    h = math.min(h, maxDecodedBytes ~/ (w * 4));
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
  void Function(int decodedBytes)? beforeDecode,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  final int width, height;
  try {
    // ignore: raft_lints/avoid_raw_image_decode -- Attachment images decode through decodeAttachmentImage at the target display size (bucketed), and the repository owns their lifetime.
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    (width, height) = attachmentDecodeSize(
      descriptor.width,
      descriptor.height,
      target,
      maxDecodedBytes: maxDecodedBytes,
    );
    beforeDecode?.call(width * height * 4);
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
          // Retire first, synchronously: the bitmap is gone when a drop returns,
          // not after the eviction's microtask (which a test zone, or a loaded
          // machine, may run after the owner is already torn down).
          final eviction = provider.evict();
          provider._retire();
          await eviction;
        },
      );
    }
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
  return _decodeAnimatedAttachmentImage(bytes, width, height);
}

/// Animated images keep their encoded bytes; kept out of [decodeAttachmentImage]
/// so the still-image path's closures do not share a Context with `bytes`.
Future<DecodedAttachmentImage> _decodeAnimatedAttachmentImage(
  Uint8List bytes,
  int width,
  int height,
) {
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

  /// Bytes of the network fetch behind this image, throttled. Null until the
  /// entry goes to the network (it stays null for queued work and disk-cache
  /// hits), so a cached image never shows a bar. Entries sharing one source
  /// (list preview and lightbox) see the same numbers from one download.
  ValueListenable<AttachmentTransferProgress?> get progress => _entry.transfer;

  /// True only while the loader explicitly waits for the original's address.
  /// Uses the same progress notifier; zero received bytes do not imply this.
  bool get waitingForAddress => active && _entry.transfer.waitingForAddress;

  void release() {
    if (_released) return;
    _released = true;
    _entry.leases.remove(this);
    _owner._trimRetained();
    if (_entry.leases.isEmpty && _entry.value == null) {
      _owner._drop(_entry);
    } else if (_entry.leases.isEmpty) {
      _entry.idleSince = _owner.clock();
      _owner._sweepIdle();
    }
  }

  /// Releases and, when no other consumer holds it, frees the decoded image
  /// instead of keeping it in the LRU (full-resolution lightbox images).
  void discard() {
    release();
    if (_entry.leases.isEmpty) _owner._drop(_entry);
  }
}

/// An entry's progress mirror. A lease can outlive its dropped entry (and the
/// drop disposes this), so a late listener gets a quiet no-op instead of the
/// "used after disposed" assertion; nothing publishes after the drop anyway.
class _EntryProgress extends ValueNotifier<AttachmentTransferProgress?> {
  _EntryProgress() : super(null);
  bool _gone = false;
  bool waitingForAddress = false;

  void updatePhase(AttachmentFetchPhase phase) {
    if (_gone) return;
    final next = phase == AttachmentFetchPhase.waitingForAddress;
    if (next == waitingForAddress) return;
    waitingForAddress = next;
    // Keep value (including null) and byte throttling exactly as they were.
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    if (!_gone) super.addListener(listener);
  }

  @override
  void dispose() {
    if (_gone) return;
    _gone = true;
    super.dispose();
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

  /// Mirror of the joined fetch's progress for this entry's consumers.
  final transfer = _EntryProgress();

  /// Publishes progress unless the entry was dropped (its [transfer] is
  /// disposed then).
  void report(AttachmentTransferProgress? progress) {
    if (!retired) transfer.value = progress;
  }

  void reportPhase(AttachmentFetchPhase phase) {
    if (!retired) transfer.updatePhase(phase);
  }

  DecodedAttachmentImage? value;
  _SourceFetch? fetch;

  /// The token handed to this entry's network loader; cancelled on drop.
  CancelToken? fetchCancel;
  bool retired = false, fromStore = false;

  /// Requested by an explicit open rather than background list work.
  bool foreground = false;

  /// May be served by any stored version of the attachment's image (see
  /// [AttachmentImageKey.storeLookup]); set by the first consumer.
  bool bestAvailable = false;

  /// When the last lease was returned ([AttachmentImageRepository.clock]);
  /// null while a lease is held.
  Duration? idleSince;
}

/// One network fetch of a source shared by every decode of it (list preview
/// and lightbox). Cancelled once no waiting entry remains.
class _SourceFetch {
  _SourceFetch(this.key) {
    // One throttled sink per download, fanned out to every waiting entry.
    cancel = AttachmentFetchToken(
      transfer.report,
      reportPhase: (next) {
        if (_disposed || next == phase) return;
        phase = next;
        for (final waiter in waiters.toList()) {
          waiter.reportPhase(next);
        }
      },
    );
    transfer.addListener(() {
      for (final waiter in waiters) {
        waiter.report(transfer.value);
      }
    });
  }
  final AttachmentImageKey key;
  final AttachmentTransfer transfer = AttachmentTransfer();
  AttachmentFetchPhase phase = AttachmentFetchPhase.transfer;
  late final AttachmentFetchToken cancel;
  final Set<_ImageEntry> waiters = {};
  late final Future<Uint8List> bytes;
  bool persisted = false;
  bool _disposed = false;

  /// Ends the progress sink for good; safe to call from both the end of the
  /// transfer and the abandonment of it.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    transfer.dispose();
  }
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
    int? maxActiveDecodedBytes,
    this.maxConcurrentLoads = 4,
    this.foregroundExtra = 2,
    this.idleTtl = const Duration(minutes: 5),
    Duration Function()? clock,
  }) : maxActiveDecodedBytes = maxActiveDecodedBytes ?? maxDecodedBytes,
       clock = clock ?? _monotonicClock(),
       // ignore: prefer_initializing_formals -- Preserve the public decoder injection name and private ownership.
       _decoder = decoder {
    if (maxEntries < 1 ||
        maxEncodedBytes < 1 ||
        maxDecodedBytes < 1 ||
        this.maxActiveDecodedBytes < maxDecodedBytes ||
        maxConcurrentLoads < 1) {
      throw ArgumentError('Image budgets must be positive.');
    }
  }
  AttachmentImageScope _scope;
  final bool Function(AttachmentImageKey) _retainedAuthority;
  final AttachmentImageDecoder? _decoder;

  // Network transfers remain concurrent. Decode and publish one bitmap at a
  // time so two codecs cannot both spend the same remaining decoded budget.
  Future<void>? _decoding;

  /// Persistent bytes behind the decoded entries; read only for keys that
  /// pass [canRead] and an active lease. Known invalid data is not retained;
  /// recoverable decoder failures keep the source for a later retry.
  final AttachmentImageByteStore? store;
  final int maxEntries, maxEncodedBytes, maxDecodedBytes, maxConcurrentLoads;

  /// Idle cache target versus temporary active-image capacity. The workspace
  /// selects both from device RAM; generic callers can keep a strict bound.
  final int maxActiveDecodedBytes;
  Duration? _pressureUntil;

  /// Extra concurrent loads granted to foreground (explicitly opened) images.
  final int foregroundExtra;

  /// A decoded image nobody holds a lease on is dropped once it has been idle
  /// this long. Revisiting a conversation within it paints in the first frame;
  /// later it is read back from the byte store. The sweep runs on repository
  /// activity (taking or returning a lease) and on [trimIdle]; there is no
  /// timer, so an idle app does no work and tests need no teardown.
  final Duration idleTtl;

  /// Monotonic time source of the idle sweep (a test seam).
  final Duration Function() clock;
  Duration? _lastSweep;
  static Duration Function() _monotonicClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }
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
    bool foreground = false,
    bool bestAvailable = false,
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
      e = _ImageEntry(key, load)..bestAvailable = bestAvailable;
      _entries[key] = e;
      if (foreground) {
        e.foreground = true;
        _queue.addFirst(e);
      } else {
        _queue.add(e);
      }
    } else {
      _entries[key] = e;
      // An explicit open outranks background list work still waiting.
      if (foreground && !e.foreground) {
        e.foreground = true;
        if (_queue.remove(e)) _queue.addFirst(e);
      }
    }
    final lease = AttachmentImageLease._(this, e, authorized);
    e.leases.add(lease);
    e.idleSince = null;
    _sweepIdle();
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot deferral out of a build or notification; the callback does not schedule another microtask itself.
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
    e.idleSince = null;
    _sweepIdle();
    return lease;
  }

  /// Drops every decoded image no lease holds (memory pressure, app in the
  /// background). Returns the number dropped. Held images stay: their widget
  /// owns the decision to let go. [reason] labels optional debug diagnostics.
  int trimIdle({bool pressure = false, String? reason}) {
    final before = decodedByteCount;
    if (pressure) _pressureUntil = clock() + const Duration(seconds: 30);
    var dropped = 0;
    for (final e in _entries.values.toList()) {
      if (e.leases.isEmpty && e.value != null) {
        _drop(e);
        dropped++;
      }
    }
    if (!kReleaseMode && reason != null) {
      debugPrint(
        '[raft-memory] $reason: dropped $dropped decoded images '
        '(${before - decodedByteCount} B), '
        '$entryCount held ($decodedByteCount B decoded)',
      );
    }
    return dropped;
  }

  /// Drops unleased decoded images idle for [idleTtl]. Cheap enough to run on
  /// every lease change (at most [maxEntries] entries), and rate-limited.
  void _sweepIdle() {
    final now = clock();
    final last = _lastSweep;
    if (last != null && now - last < const Duration(seconds: 5)) return;
    _lastSweep = now;
    for (final e in _entries.values.toList()) {
      final since = e.idleSince;
      if (e.leases.isEmpty &&
          e.value != null &&
          since != null &&
          now - since >= idleTtl) {
        _drop(e);
      }
    }
  }

  void _makeRoom({int entries = 0, int encoded = 0, int decoded = 0}) {
    while (_entries.length + entries > maxEntries ||
        _encoded + encoded > maxEncodedBytes ||
        _decoded + decoded > maxDecodedBytes) {
      final idle = _entries.values.where((e) => e.leases.isEmpty && e.value != null);
      if (idle.isEmpty) {
        // In-use bitmaps can temporarily exceed the idle cache target. Their
        // leases, not an LRU eviction, decide when they leave the screen.
        if (_entries.length + entries <= maxEntries &&
            _encoded + encoded <= maxEncodedBytes &&
            _decoded + decoded <= maxActiveDecodedBytes) {
          return;
        }
        throw const AttachmentImageBudgetExceeded();
      }
      _drop(idle.first);
    }
  }

  void _trimRetained() {
    while (_decoded > maxDecodedBytes) {
      final idle = _entries.values.where((e) => e.leases.isEmpty && e.value != null);
      if (idle.isEmpty) break;
      _drop(idle.first);
    }
  }

  void _pump() {
    while (!_disposed && _queue.isNotEmpty) {
      // A user-opened image does not wait behind list thumbnails: it may use
      // [foregroundExtra] slots beyond the background limit.
      final limit = _queue.first.foreground
          ? maxConcurrentLoads + foregroundExtra
          : maxConcurrentLoads;
      if (_running >= limit) break;
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
      AttachmentImageStoreKey? stored;
      final store = this.store;
      if (store != null) {
        for (final candidate in e.key.storeLookup(
          bestAvailable: e.bestAvailable,
        )) {
          try {
            bytes = await store.read(candidate);
          } catch (_) {
            bytes = null;
          }
          if (!_wanted(e)) throw const StaleAttachmentImage();
          if (bytes != null) {
            stored = candidate;
            break;
          }
        }
      }
      e.fromStore = bytes != null;
      if (bytes == null) {
        fetch = _join(e);
        try {
          // A tile that scrolled away is dropped; its load must not keep the
          // slot while the loader is still waiting on something that cannot be
          // cancelled (a signed-URL request, the rate-limit pacing). Racing the
          // entry's own cancellation frees the slot at once, so tiles that
          // are on screen now are never queued behind rows long gone.
          bytes = await _untilDropped(e, fetch.bytes);
          // Complete: hold the bar full while decoding; a loader that never
          // reported has nothing to show.
          e.report(
            fetch.transfer.value == null
                ? null
                : AttachmentTransferProgress(bytes.length, bytes.length),
          );
        } finally {
          fetch.waiters.remove(e);
          e.fetch = null;
          e.fetchCancel = null;
        }
      }
      e.load = null; // Idle cached bytes do not retain a retired row callback.
      if (!_wanted(e)) throw const StaleAttachmentImage();
      if (bytes.length > maxEncodedBytes) {
        throw const AttachmentImageBudgetExceeded();
      }
      final previous = _decoding;
      final turn = Completer<void>();
      _decoding = turn.future;
      try {
        if (previous != null) await previous;
        if (!_wanted(e)) throw const StaleAttachmentImage();
        try {
          final decoder = _decoder;
          if (decoder != null) {
            decoded = await decoder(bytes, e.key.target);
          } else {
            final pinned = _entries.values.fold<int>(
              0,
              (total, entry) => total +
                  (entry.leases.isEmpty ? 0 : entry.value?.decodedBytes ?? 0),
            );
            final pressure = _pressureUntil;
            final constrained = pressure != null && clock() < pressure;
            // A user-opened original may borrow temporary capacity above the
            // idle cache target. Rows/preloads stay display-sized. A recent
            // OS warning tightens new decodes without blanking the current
            // picture. No timer is needed to end the pressure interval.
            final budget = math.min(
              e.foreground && !constrained ? maxActiveDecodedBytes : maxDecodedBytes,
              maxActiveDecodedBytes - pinned,
            );
            decoded = await decodeAttachmentImage(
              bytes,
              target: e.key.target,
              maxDecodedBytes: budget,
              // Evict idle bitmaps before allocating this one, not after it.
              beforeDecode: (size) => _makeRoom(decoded: size),
            );
          }
        } on AttachmentImageBudgetExceeded {
          // A valid disk entry is still useful after other images close.
          if (_wanted(e)) _persistSource(e, fetch, bytes);
          rethrow;
        } on StaleAttachmentImage {
          rethrow;
        } catch (error) {
          // The pinned engine emits this exact message when no compatible
          // image generator exists. Allocation/registry/frame errors do not
          // prove corruption and must not destroy an already fetched source.
          if (error is AttachmentImageDecodeFailed ||
              error is FormatException ||
              error is Exception &&
                  // ignore: raft_lints/avoid_caught_exception_text -- Classify only the exact pinned engine format rejection; the native text is never rendered or logged.
                  error.toString() == 'Exception: Invalid image data') {
            if (stored != null) unawaited(_quietly(store!.remove(stored)));
            throw const AttachmentImageDecodeFailed();
          }
          if (_wanted(e)) _persistSource(e, fetch, bytes);
          throw AttachmentImageDecodeUnavailable(error);
        }
        if (!_wanted(e)) throw const StaleAttachmentImage();
        _persistSource(e, fetch, bytes);
        _makeRoom(encoded: decoded.encodedBytes, decoded: decoded.decodedBytes);
        _encoded += decoded.encodedBytes;
        _decoded += decoded.decodedBytes;
        e.value = decoded;
        decoded = null;
        e.ready.complete(e.value!);
      } finally {
        // Disposal must finish before the next codec spends this memory.
        try {
          await decoded?.dispose();
        } finally {
          decoded = null;
          if (identical(_decoding, turn.future)) _decoding = null;
          turn.complete();
        }
      }
    } catch (error, trace) {
      if (!e.ready.isCompleted) e.ready.completeError(error, trace);
      _drop(e);
    } finally {
      await decoded?.dispose();
    }
  }

  /// [work], or [StaleAttachmentImage] as soon as [e] is dropped.
  static Future<Uint8List> _untilDropped(_ImageEntry e, Future<Uint8List> work) {
    if (e.cancel.isCancelled) return Future.error(const StaleAttachmentImage());
    final done = Completer<Uint8List>();
    unawaited(
      e.cancel.whenCancel.then<void>((_) {
        if (!done.isCompleted) done.completeError(const StaleAttachmentImage());
      }),
    );
    work.then<void>(
      (bytes) {
        if (!done.isCompleted) done.complete(bytes);
      },
      onError: (Object error, StackTrace trace) {
        if (!done.isCompleted) done.completeError(error, trace);
      },
    );
    return done.future;
  }

  static Future<void> _quietly(Future<void> work) =>
      work.catchError((Object _) {});

  void _persistSource(_ImageEntry e, _SourceFetch? fetch, Uint8List bytes) {
    final store = this.store;
    if (store == null || fetch == null || fetch.persisted) return;
    fetch.persisted = true;
    unawaited(_quietly(store.write(e.key.storeKey, bytes)));
  }

  /// Joins (or starts) the network fetch of [e]'s source bytes.
  _SourceFetch _join(_ImageEntry e) {
    final source = e.key.source;
    var fetch = _fetches[source];
    if (fetch == null || fetch.cancel.isCancelled) {
      final loader = e.load!;
      final next = fetch = _SourceFetch(source);
      _fetches[source] = next;
      next.bytes = loader(next.cancel).whenComplete(() {
        next.transfer
          ..flush()
          ..close();
        if (identical(_fetches[source], next)) _fetches.remove(source);
        // The transfer is over (finished, failed or cancelled): nothing
        // reports to it again, and the last value stays readable.
        next.dispose();
      });
      // Abandoned fetches may fail after every waiter left.
      unawaited(next.bytes.then<void>((_) {}, onError: (Object _) {}));
    }
    fetch.waiters.add(e);
    e.reportPhase(fetch.phase);
    e.report(fetch.transfer.value ?? AttachmentTransferProgress.connecting);
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
      // Abandoned: a loader that never finishes would never reach the
      // completion handler that normally ends the transfer.
      fetch.dispose();
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
    e.transfer.dispose();
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
