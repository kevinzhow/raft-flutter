import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'attachment_image_store.dart';
import 'cache_directory_listing.dart';
import 'cache_file_access.dart';

/// The default size cap of the attachment cache (all accounts and servers on
/// this device); Settings > Storage offers other tiers
/// ([attachmentCacheBudgetTiers]). The one place the number is defined;
/// eviction trims to 90 % of the cap in force.
const int attachmentCacheMaxBytes = 1024 * 1024 * 1024;

/// The caps Settings > Storage offers for the whole cache, smallest first;
/// [attachmentCacheMaxBytes] is among them.
const List<int> attachmentCacheBudgetTiers = [
  256 * 1024 * 1024,
  512 * 1024 * 1024,
  1024 * 1024 * 1024,
  2 * 1024 * 1024 * 1024,
  5 * 1024 * 1024 * 1024,
];

/// The public namespace's cap (avatars, icons) in the app. It does not follow
/// the chosen total budget: a profile picture is small however large the
/// attachment cache is allowed to grow.
const int attachmentPublicCacheMaxBytes = 64 * 1024 * 1024;

/// A private entry nobody opened for this long is deleted (lazily when
/// touched, and by the scan at start). Opening an entry restarts the clock.
const Duration attachmentCacheIdleExpiry = Duration(days: 30);

/// The format of the cached preview JSON / static HTML entries (the
/// [AttachmentDiskCache.readPreview] family). Raise it when the client reads
/// those documents differently: older entries then count as misses.
const int attachmentPreviewFormatVersion = 1;

/// A preview entry is refetched this long after it was stored, however
/// recently it was opened (the server may have changed what it renders).
const Duration attachmentPreviewFreshness = Duration(days: 14);

/// The two kinds of entry in the cache, which share one root, one index and one
/// size figure but not their lifetime.
enum AttachmentCacheNamespace {
  /// Private content: keyed by account / server / channel, purged on sign-out
  /// and channel revocation, evicted least recently used when the cache is over
  /// its budget.
  attachments,

  /// Public pictures (avatars, icons): keyed by a caller-chosen string, shared
  /// by every account, not purged on sign-out, kept inside their own cap with
  /// their own least-recently-used order, and never evicted to make room for
  /// attachments.
  public,
}

/// A cached file handed to a caller. While it is open the cache never evicts
/// or clears the file; [release] ends that. Never delete [file] yourself.
class AttachmentCachedFile {
  AttachmentCachedFile._(this._owner, this.file);
  final AttachmentDiskCache _owner;
  final File file;
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    _owner._unpin(file.path);
  }
}

/// Downloads into [destination] (a private temporary path inside the cache).
/// [cancel] is shared by every caller joined to the download; [progress] is
/// dio's `onReceiveProgress` shape. Throws on any failure.
typedef AttachmentFileDownload = Future<void> Function(
  File destination,
  CancelToken cancel,
  void Function(int received, int total) progress,
);

/// The cache directory is unusable (no platform cache dir, read-only disk).
/// Callers fall back to their uncached path.
class AttachmentCacheUnavailable implements Exception {
  const AttachmentCacheUnavailable();
}

/// Persistent, bounded, concurrency-safe on-disk cache of attachment content,
/// keyed by account/server/channel and the attachment id plus its content
/// identity (never by a signed URL, so URL expiry cannot invalidate or
/// duplicate an entry).
///
/// Two kinds of entry share the budget and the LRU order:
/// * bytes (inline image sources, preview JSON/HTML): [read] / [write];
/// * files (PDF, audio and other preview inputs that native decoders open by
///   path): [openFile] / [fetchFile].
///
/// Layout `<root>/raft-attachments/v2/<account>/<server>/<channel>/<entry>[.f/<name>]`
/// for [AttachmentCacheNamespace.attachments] and
/// `<root>/raft-attachments/public/<hash of the key>` for
/// [AttachmentCacheNamespace.public], every segment a hash except the file name. Writes go to a `.raft-part` sibling
/// and are renamed into place, so a crash leaves only an ignorable partial
/// that the next start deletes. Access order persists in file modification
/// times. Reads are only issued by callers that already hold authority; the
/// cache never grants access.
class AttachmentDiskCache implements AttachmentImageByteStore {
  AttachmentDiskCache(
    this._root, {
    this.maxBytes = attachmentCacheMaxBytes,
    this.maxEntryBytes = 64 * 1024 * 1024,
    int? publicMaxBytes,
    this.publicMaxEntryBytes = 4 * 1024 * 1024,
    this.idleExpiry = attachmentCacheIdleExpiry,
    this.previewFreshness = attachmentPreviewFreshness,
    this.previewFormatVersion = attachmentPreviewFormatVersion,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       publicMaxBytes =
           publicMaxBytes ?? math.min(64 * 1024 * 1024, maxBytes ~/ 8);

  /// The process-wide cache installed by the app entry point. Controllers use
  /// it unless they are given another store; tests leave it unset.
  static AttachmentDiskCache? installed;

  static const _partSuffix = '.raft-part';
  static const _layout = 'v2';
  static const _publicLayout = 'public';

  final Future<Directory> Function() _root;
  final int maxEntryBytes;

  /// The cap of the whole cache (both namespaces). Change it with
  /// [setMaxBytes], which also evicts down to a lower one.
  int maxBytes;

  /// How long a private entry may go unopened, and how old a preview entry
  /// may be, and the preview format this client reads. [_clock] is injectable
  /// for tests; there is no timer: expiry is checked on access and once at
  /// start.
  final Duration idleExpiry, previewFreshness;
  final int previewFormatVersion;
  final DateTime Function() _clock;

  /// The public namespace's own cap (default the smaller of 64 MiB and an
  /// eighth of [maxBytes]; it counts toward [maxBytes]) and entry size limit.
  final int publicMaxBytes, publicMaxEntryBytes;
  final _clearListeners = <void Function()>[];

  /// Calls [listener] after [clear] emptied the public namespace (the
  /// in-memory layers in front of it use this to forget what is no longer on
  /// disk). Returns the callback that removes it.
  void Function() addPublicClearListener(void Function() listener) {
    _clearListeners.add(listener);
    return () => _clearListeners.remove(listener);
  }

  Future<_DiskIndex?>? _index;
  Future<void> _tail = Future.value();
  final _access = CacheFileAccess();
  final Map<String, int> _pins = {};
  final Map<String, _Download> _downloads = {};
  int _sequence = 0;

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 40);

  /// Account and server segments of an identity. The identity string is
  /// `[origin, principal, server]` as JSON (see `AttachmentImageKey`); the
  /// split lets sign-out remove an account without knowing its servers.
  static (String, String) _segments(String identity) {
    try {
      final parts = jsonDecode(identity);
      if (parts is List && parts.length == 3) {
        return (
          _hash(jsonEncode([parts[0], parts[1]])),
          _hash(jsonEncode(parts[2])),
        );
      }
    } catch (_) {
      // Not structured: a single flat bucket.
    }
    return (_hash(identity), '-');
  }

  static String _accountSegment(String origin, String principal) =>
      _hash(jsonEncode([origin, principal]));

  /// Opens the index (once): creates the directory, deletes partial files and
  /// the pre-v2 layout, and sizes what is there. Null when no directory.
  Future<_DiskIndex?> _open() => _index ??= () async {
    try {
      final base = await _root();
      final directory = Directory(
        p.join(base.path, 'raft-attachments', _layout),
      );
      await directory.create(recursive: true);
      // Created by the first public write; read here only if it exists.
      final publicDirectory = Directory(
        p.join(base.path, 'raft-attachments', _publicLayout),
      );
      // The first image-only layout: its entries were never reachable again.
      unawaited(
        _quietly(
          () =>
              Directory(p.join(base.path, 'raft-attachment-images'))
                  .delete(recursive: true),
        ),
      );
      // The walk (tens of thousands of stat calls on a large cache) runs on a
      // helper isolate, which also builds the index: this isolate only adopts
      // the finished map, so a frame never waits for the disk and a cold start
      // costs it milliseconds. Every caller waits on this future, so none can
      // see a half-built index.
      final scan = await _scanOffIsolate(
        directory.path,
        publicDirectory.path,
        _partSuffix,
      );
      final index = _DiskIndex(directory, publicDirectory, scan);
      await _expireIdle(index);
      return index;
    } catch (_) {
      return null; // No platform cache directory: run memory-only.
    }
  }();

  /// Sets the cap of the whole cache and, when the cache is over it, evicts the
  /// least recently used attachment entries down to 90 % of it right away
  /// (never an entry an open preview holds, and never the public namespace,
  /// which keeps its own cap [publicMaxBytes]). Later writes use the new cap
  /// at once. Completes after the eviction; it waits for the index to be
  /// built and runs behind the writes already queued.
  Future<void> setMaxBytes(int bytes) async {
    if (bytes <= 0) throw ArgumentError.value(bytes, 'bytes');
    maxBytes = bytes;
    final index = await _open();
    if (index == null) return;
    await _serial(() => _trim(index, keep: ''));
  }

  /// Starts indexing now (app start), so the first lookups do not wait for it.
  Future<void> warm() => _open().then<void>((_) {}, onError: (Object _) {});

  /// True when the private entry at [path] was last opened [idleExpiry] ago
  /// or more and nothing holds it open. The public namespace follows its own
  /// rules and never expires here.
  bool _expired(
    _DiskIndex index,
    String path,
    DateTime lastUsed, [
    DateTime? now,
  ]) =>
      !index.isPublic(path) &&
      !_pins.containsKey(path) &&
      (now ?? _clock()).difference(lastUsed) >= idleExpiry;

  /// The start-up pass: deletes every private entry unopened for
  /// [idleExpiry]. One walk over the in-memory index; the only disk work is
  /// deleting what expired.
  Future<void> _expireIdle(_DiskIndex index) async {
    final now = _clock();
    final expired = [
      for (final entry in index.files.entries)
        if (_expired(index, entry.key, entry.value.$2, now)) entry.key,
    ];
    if (expired.isEmpty) return;
    for (final path in expired) {
      await _delete(index, path);
    }
    await _pruneEmpty(index.directory);
  }

  /// Serializes mutations. Lookups run independently; removal invalidates
  /// them and waits for their handles before deleting on Windows.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _dir(_DiskIndex index, AttachmentImageStoreKey key) {
    final (account, server) = _segments(key.identity);
    return p.join(index.directory.path, account, server, _hash(key.channelId));
  }

  String _path(_DiskIndex index, AttachmentImageStoreKey key) =>
      p.join(_dir(index, key), _hash(key.entry));

  static String _safeName(String name) {
    var cleaned = p.posix
        .basename(p.windows.basename(name))
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '_');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      cleaned = 'attachment';
    }
    if (cleaned.length > 96) {
      final extension = p.extension(cleaned);
      final keep = extension.length <= 16 ? extension : '';
      cleaned = cleaned.substring(0, 96 - keep.length) + keep;
    }
    return cleaned;
  }

  String _filePath(
    _DiskIndex index,
    AttachmentImageStoreKey key,
    String filename,
  ) => p.join('${_path(index, key)}.f', _safeName(filename));

  // ---- Bytes entries -------------------------------------------------------

  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async {
    final index = await _open();
    if (index == null) return null;
    return _readBytes(index, _path(index, key));
  }

  Future<Uint8List?> _readBytes(_DiskIndex index, String path) async {
    final entry = index.files[path];
    if (entry == null) return null;
    if (_expired(index, path, entry.$2)) {
      await _discard(index, path, entry);
      return null;
    }
    final lookup = _access.begin(path);
    if (lookup == null) return null;
    try {
      final bytes = await File(path).readAsBytes();
      if (!lookup.valid) return null;
      final now = _clock();
      index.files[path] = (bytes.length, now, entry.$3);
      await _quietly(() => File(path).setLastModified(now));
      return lookup.valid ? bytes : null;
    } on FileSystemException {
      // Release our handle before queued removal can wait for it.
    } finally {
      lookup.release();
    }
    await _discard(index, path, entry);
    return null;
  }

  Future<void> _discard(_DiskIndex index, String path, _DiskEntry entry) =>
      _serial(() async {
        // A replacement queued during the lookup owns its own bytes.
        if (identical(index.files[path]?.$3, entry.$3)) {
          await _delete(index, path);
        }
      });

  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxEntryBytes) return;
    final index = await _open();
    if (index == null) return;
    final path = _path(index, key);
    await _serial(
      () => _access.write(path, () async {
        final part = '$path.${_sequence++}$_partSuffix';
        try {
          await Directory(p.dirname(path)).create(recursive: true);
          await File(part).writeAsBytes(bytes, flush: true);
          await File(part).rename(path);
        } on FileSystemException {
          await _quietly(() => File(part).delete());
          return;
        }
        _register(index, path, bytes.length);
        await _trim(index, keep: path);
      }),
    );
  }

  /// True when the bytes entry is stored; no read and no LRU touch.
  Future<bool> contains(AttachmentImageStoreKey key) async {
    final index = await _open();
    return index != null && await _stored(index, _path(index, key));
  }

  /// True when the index has [path], it has not expired and the file is still
  /// on disk. A file the OS removed underneath is dropped from the index (and
  /// the totals) here instead of being promised to the caller.
  Future<bool> _stored(_DiskIndex index, String path) async {
    final entry = index.files[path];
    if (entry == null || _expired(index, path, entry.$2)) return false;
    final lookup = _access.begin(path);
    if (lookup == null) return false;
    try {
      if (await File(path).exists()) return lookup.valid;
    } finally {
      lookup.release();
    }
    await _discard(index, path, entry);
    return false;
  }

  // ---- Preview documents ---------------------------------------------------

  /// Reads a preview JSON / static HTML entry written by [writePreview].
  /// An entry stored by another preview format version, older than
  /// [previewFreshness], or without the header is deleted and reported as a
  /// miss.
  Future<Uint8List?> readPreview(AttachmentImageStoreKey key) async {
    final bytes = await read(key);
    if (bytes == null) return null;
    final body = _previewBody(bytes);
    if (body == null) {
      await remove(key);
      return null;
    }
    return body;
  }

  /// Stores a preview JSON / static HTML entry with the client's format
  /// version and the time it was written (the freshness clock; opening the
  /// entry later does not restart it).
  Future<void> writePreview(AttachmentImageStoreKey key, Uint8List bytes) {
    final header = utf8.encode(
      'RPV$previewFormatVersion:'
      '${_clock().millisecondsSinceEpoch}\n',
    );
    return write(key, Uint8List.fromList([...header, ...bytes]));
  }

  Uint8List? _previewBody(Uint8List bytes) {
    final end = bytes.indexOf(0x0a);
    if (end < 0 || end > 40) return null;
    final header = ascii.decode(bytes.sublist(0, end), allowInvalid: true);
    final match = RegExp(r'^RPV(\d{1,9}):(\d{1,15})$').firstMatch(header);
    if (match == null || int.parse(match[1]!) != previewFormatVersion) {
      return null;
    }
    final written = DateTime.fromMillisecondsSinceEpoch(int.parse(match[2]!));
    if (_clock().difference(written) >= previewFreshness) return null;
    return Uint8List.sublistView(bytes, end + 1);
  }

  @override
  Future<void> remove(AttachmentImageStoreKey key) async {
    final index = await _open();
    if (index == null) return;
    await _serial(() => _delete(index, _path(index, key)));
  }

  // ---- Public namespace ----------------------------------------------------

  String _publicPath(_DiskIndex index, String key) =>
      p.join(index.publicDirectory.path, _hash(key));

  /// The public entry stored under [key], or null. Refreshes its recency.
  Future<Uint8List?> readPublic(String key) async {
    final index = await _open();
    if (index == null) return null;
    return _readBytes(index, _publicPath(index, key));
  }

  /// Stores [bytes] under [key] in the public namespace, then trims that
  /// namespace to its cap and, if the whole cache is over budget, the
  /// attachments.
  Future<void> writePublic(String key, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > publicMaxEntryBytes) return;
    final index = await _open();
    if (index == null) return;
    final path = _publicPath(index, key);
    await _serial(
      () => _access.write(path, () async {
        final part = '$path.${_sequence++}$_partSuffix';
        try {
          await index.publicDirectory.create(recursive: true);
          await File(part).writeAsBytes(bytes, flush: true);
          await File(part).rename(path);
        } on FileSystemException {
          await _quietly(() => File(part).delete());
          return;
        }
        _register(index, path, bytes.length);
        await _trimPublic(index, keep: path);
        await _trim(index, keep: path);
      }),
    );
  }

  Future<void> removePublic(String key) async {
    final index = await _open();
    if (index == null) return;
    await _serial(() => _delete(index, _publicPath(index, key)));
  }

  // ---- File entries --------------------------------------------------------

  /// True when the file entry is stored; no LRU touch.
  Future<bool> containsFile(
    AttachmentImageStoreKey key, {
    required String filename,
  }) async {
    final index = await _open();
    return index != null &&
        await _stored(index, _filePath(index, key, filename));
  }

  /// The stored file for [key], pinned, or null on a miss. A file whose size
  /// differs from [expectedBytes] (or from what was stored) is corrupt: it is
  /// deleted and reported as a miss.
  Future<AttachmentCachedFile?> openFile(
    AttachmentImageStoreKey key, {
    required String filename,
    int? expectedBytes,
  }) async {
    expectedBytes = _knownSize(expectedBytes);
    final index = await _open();
    if (index == null) return null;
    return _openPath(index, _filePath(index, key, filename), expectedBytes);
  }

  /// Attachment metadata without a size (0, negative) promises nothing: it must
  /// not make every download look incomplete.
  static int? _knownSize(int? bytes) =>
      bytes != null && bytes > 0 ? bytes : null;

  Future<AttachmentCachedFile?> _openPath(
    _DiskIndex index,
    String path,
    int? expectedBytes,
  ) async {
    final entry = index.files[path];
    if (entry == null) return null;
    if (_expired(index, path, entry.$2)) {
      await _discard(index, path, entry);
      return null;
    }
    final lookup = _access.begin(path);
    if (lookup == null) return null;
    var keepPin = false;
    _pin(path); // Before touching the disk: eviction must not win the race.
    try {
      if (expectedBytes != null && entry.$1 != expectedBytes) {
        throw const FileSystemException('size differs from the metadata');
      }
      final stat = await File(path).stat();
      if (stat.type != FileSystemEntityType.file || stat.size != entry.$1) {
        throw const FileSystemException('stored file changed');
      }
      if (!lookup.valid) return null;
      final now = _clock();
      index.files[path] = (stat.size, now, entry.$3);
      await _quietly(() => File(path).setLastModified(now));
      if (!lookup.valid) return null;
      keepPin = true;
      return AttachmentCachedFile._(this, File(path));
    } on FileSystemException {
      // Removal must run after this lookup releases its handle.
    } finally {
      lookup.release();
      if (!keepPin) _unpin(path);
    }
    await _discard(index, path, entry);
    return null;
  }

  /// The file for [key]: the stored copy, or one download shared by every
  /// caller asking for the same entry at the same time. [download] runs once;
  /// its result is checked (non-empty, [expectedBytes]) and renamed into
  /// place atomically before any caller sees it. Returns a pinned handle, or
  /// null if this caller's [cancel] fired first (the download is cancelled
  /// when no caller is left). Throws the download's error otherwise, and
  /// [AttachmentCacheUnavailable] when there is no cache directory.
  Future<AttachmentCachedFile?> fetchFile(
    AttachmentImageStoreKey key, {
    required String filename,
    required AttachmentFileDownload download,
    int? expectedBytes,
    CancelToken? cancel,
    void Function(int received, int total)? onProgress,
  }) async {
    expectedBytes = _knownSize(expectedBytes);
    final index = await _open();
    if (index == null) throw const AttachmentCacheUnavailable();
    final path = _filePath(index, key, filename);
    final stored = await _openPath(index, path, expectedBytes);
    if (stored != null) return stored;
    if (cancel?.isCancelled == true) return null;
    final job = _downloads[path] ??= _startDownload(
      index,
      path,
      download,
      expectedBytes,
    );
    final waiter = _Waiter(onProgress);
    job.waiters.add(waiter);
    final detached = Completer<void>();
    unawaited(
      cancel?.whenCancel.then<void>((_) {
        // After the download finished the waiter already owns its pin.
        if (job.finished || !job.waiters.remove(waiter)) return;
        if (job.waiters.isEmpty) job.shared.cancel();
        detached.complete();
      }),
    );
    await Future.any([job.done.future, detached.future]);
    if (!job.waiters.contains(waiter)) return null;
    return AttachmentCachedFile._(this, File(path));
  }

  _Download _startDownload(
    _DiskIndex index,
    String path,
    AttachmentFileDownload download,
    int? expectedBytes,
  ) {
    final job = _Download();
    // An abandoned download may fail after every waiter left.
    unawaited(job.done.future.then<void>((_) {}, onError: (Object _) {}));
    unawaited(() async {
      final part = File('$path.${_sequence++}$_partSuffix');
      try {
        await part.parent.create(recursive: true);
        await download(part, job.shared, (received, total) {
          for (final waiter in job.waiters.toList()) {
            waiter.progress?.call(received, total);
          }
        });
        if (job.shared.isCancelled) {
          throw const FileSystemException('download cancelled');
        }
        final length = await part.length();
        if (length == 0 ||
            length > maxBytes ||
            (expectedBytes != null && length != expectedBytes)) {
          throw const FileSystemException('incomplete download');
        }
        await _serial(
          () => _access.write(path, () async {
            await part.rename(path);
            _register(index, path, length);
            // From this instant the entry is findable, every caller still
            // attached owns one pin, and later callers open the stored file:
            // nothing below (eviction included) can lose it.
            _pins[path] = (_pins[path] ?? 0) + job.waiters.length;
            job.finished = true;
            if (identical(_downloads[path], job)) _downloads.remove(path);
            await _trim(index, keep: path);
          }),
        );
        job.done.complete();
      } catch (error, trace) {
        await _quietly(part.delete);
        job.finished = true;
        if (identical(_downloads[path], job)) _downloads.remove(path);
        job.done.completeError(error, trace);
      }
    }());
    return job;
  }

  void _pin(String path) => _pins[path] = (_pins[path] ?? 0) + 1;

  void _unpin(String path) {
    final count = (_pins[path] ?? 0) - 1;
    if (count > 0) {
      _pins[path] = count;
    } else {
      _pins.remove(path);
    }
  }

  // ---- Index, eviction, removal -------------------------------------------

  void _register(_DiskIndex index, String path, int length) {
    final before = index.files[path]?.$1 ?? 0;
    index.total += length - before;
    if (index.isPublic(path)) index.publicTotal += length - before;
    index.files[path] = (length, _clock(), Object());
  }

  /// Trims the least recently used unpinned attachment entries (never [keep])
  /// down to 90 % of [maxBytes] when the cache is over it. The public
  /// namespace has its own cap ([_trimPublic]) and is not evicted here.
  /// Inside [_serial].
  Future<void> _trim(_DiskIndex index, {required String keep}) async {
    if (index.total <= maxBytes) return;
    final oldest =
        index.files.entries.where((e) => !index.isPublic(e.key)).toList()
          ..sort((a, b) => a.value.$2.compareTo(b.value.$2));
    for (final entry in oldest) {
      if (index.total <= maxBytes * 9 ~/ 10) break;
      if (entry.key == keep || _pins.containsKey(entry.key)) continue;
      await _delete(index, entry.key);
    }
  }

  /// Trims the least recently used public entries (never [keep]) down to 90 %
  /// of [publicMaxBytes] when that namespace is over it. Inside [_serial].
  Future<void> _trimPublic(_DiskIndex index, {required String keep}) async {
    if (index.publicTotal <= publicMaxBytes) return;
    final oldest =
        index.files.entries.where((e) => index.isPublic(e.key)).toList()
          ..sort((a, b) => a.value.$2.compareTo(b.value.$2));
    for (final entry in oldest) {
      if (index.publicTotal <= publicMaxBytes * 9 ~/ 10) break;
      if (entry.key == keep) continue;
      await _delete(index, entry.key);
    }
  }

  /// Bytes stored (what Settings shows): both namespaces, or just [namespace].
  Future<int> sizeBytes({AttachmentCacheNamespace? namespace}) async {
    final index = await _open();
    if (index == null) return 0;
    return switch (namespace) {
      null => index.total,
      AttachmentCacheNamespace.public => index.publicTotal,
      AttachmentCacheNamespace.attachments => index.total - index.publicTotal,
    };
  }

  /// Number of stored entries: both namespaces, or just [namespace].
  Future<int> entryCount({AttachmentCacheNamespace? namespace}) async {
    final index = await _open();
    if (index == null) return 0;
    if (namespace == null) return index.files.length;
    return index.files.keys
        .where(
          (path) =>
              index.isPublic(path) ==
              (namespace == AttachmentCacheNamespace.public),
        )
        .length;
  }

  /// Removes every entry of every account and server on this device (both
  /// namespaces, or just [namespace]) except files an open preview still
  /// holds. Never touches anything outside the cache directory (sessions,
  /// drafts, settings, files the user saved).
  Future<void> clear({AttachmentCacheNamespace? namespace}) async {
    final index = await _open();
    if (index == null) return;
    await _serial(() async {
      for (final path in index.files.keys.toList()) {
        if (_pins.containsKey(path)) continue;
        if (namespace != null &&
            index.isPublic(path) !=
                (namespace == AttachmentCacheNamespace.public)) {
          continue;
        }
        await _delete(index, path);
      }
      await _pruneEmpty(index.directory);
    });
    if (namespace != AttachmentCacheNamespace.attachments) {
      for (final listener in List.of(_clearListeners)) {
        listener();
      }
    }
  }

  Future<void> _pruneEmpty(Directory root) async {
    final directories = <Directory>[];
    try {
      await for (final entity in listCacheDirectory(root, recursive: true)) {
        if (entity is Directory) directories.add(entity);
      }
    } on FileSystemException {
      return;
    }
    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final directory in directories) {
      await _quietly(directory.delete); // Non-recursive: only when empty.
    }
  }

  /// Removes the account folders of the attachments namespace that belong to
  /// none of [keep] (`(origin, principal)` of every saved session): what
  /// sign-outs and removed sessions that happened while the app was not
  /// running left behind. Returns the number of folders removed. The caller
  /// passes only a complete, verified list; an empty one removes every
  /// account.
  Future<int> removeOrphanAccounts(
    Iterable<(String origin, String principal)> keep,
  ) async {
    final index = await _open();
    if (index == null) return 0;
    final keepNames = {for (final (o, pr) in keep) _accountSegment(o, pr)};
    final orphans = <String>[];
    try {
      await for (final entity in listCacheDirectory(index.directory)) {
        final name = p.basename(entity.path);
        if (!keepNames.contains(name)) orphans.add(name);
      }
    } on FileSystemException {
      return 0;
    }
    for (final name in orphans) {
      await _purge(name);
    }
    return orphans.length;
  }

  @override
  Future<void> purgeChannel(String identity, String channelId) {
    final (account, server) = _segments(identity);
    return _purge(p.join(account, server, _hash(channelId)));
  }

  @override
  Future<void> purgeIdentity(String identity) {
    final (account, server) = _segments(identity);
    return _purge(p.join(account, server));
  }

  /// Removes everything cached for one account on this device (sign-out,
  /// rejected session, account switch), whatever servers it used.
  Future<void> purgeAccount(String origin, String principal) =>
      _purge(_accountSegment(origin, principal));

  /// [purgeAccount] on the installed cache.
  static Future<void> purgeInstalledAccount(
    String origin,
    String principal,
  ) async => installed?.purgeAccount(origin, principal);

  Future<void> _purge(String relative) async {
    final index = await _open();
    if (index == null) return;
    await _serial(() async {
      final directory = p.join(index.directory.path, relative);
      // Revoked data goes even if a preview still holds it; that preview's
      // own authority check closes it.
      for (final path in index.files.keys.toList()) {
        if (p.isWithin(directory, path)) {
          final removed = index.files.remove(path)!.$1;
          index.total -= removed;
          if (index.isPublic(path)) index.publicTotal -= removed;
        }
      }
      await _access.invalidateWhere((path) => p.isWithin(directory, path));
      await _quietly(() => Directory(directory).delete(recursive: true));
    });
  }

  Future<void> _delete(_DiskIndex index, String path) async {
    final removed = index.files.remove(path);
    if (removed != null) {
      index.total -= removed.$1;
      if (index.isPublic(path)) index.publicTotal -= removed.$1;
    }
    await _access.invalidateWhere((candidate) => candidate == path);
    await _quietly(() => File(path).delete());
    if (path.contains('.f${p.separator}')) {
      // A file entry lives in its own directory.
      await _quietly(() => Directory(p.dirname(path)).delete());
    }
  }

  static Future<void> _quietly(Future<Object?> Function() task) async {
    try {
      await task();
    } on FileSystemException {
      // Best effort: a missing file is already the desired state.
    }
  }
}

/// What the start-up walk found: every file with its size and modification
/// time, and the byte totals (all entries, and the public ones among them).
class _Scan {
  final files = <String, (int, DateTime)>{};
  int total = 0, publicTotal = 0;
}

/// [_scanEntries] on a helper isolate. A top-level function so the closure
/// sent to the isolate captures three strings and nothing of the cache.
Future<_Scan> _scanOffIsolate(String a, String b, String partSuffix) =>
    Isolate.run(() => _scanEntries(a, b, partSuffix));

/// Walks both namespaces, deleting `.raft-part` leftovers of an interrupted
/// write, and lists every other file. Runs on a helper isolate with
/// synchronous I/O (one thread, no per-file event-loop round trip); a file
/// that vanishes mid-walk (another eviction) is simply not listed.
_Scan _scanEntries(String privatePath, String publicPath, String partSuffix) {
  final scan = _Scan();
  final publicPrefix = '$publicPath${Platform.pathSeparator}';
  for (final root in [privatePath, publicPath]) {
    final directory = Directory(root);
    // The public folder is created by the first public write.
    if (!directory.existsSync()) continue;
    try {
      for (final entity in listCacheDirectorySync(
        directory,
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        try {
          if (entity.path.endsWith(partSuffix)) {
            entity.deleteSync();
            continue;
          }
          final stat = entity.statSync();
          if (stat.type != FileSystemEntityType.file) continue;
          scan.files[entity.path] = (stat.size, stat.modified);
          scan.total += stat.size;
          if (entity.path.startsWith(publicPrefix)) {
            scan.publicTotal += stat.size;
          }
        } on FileSystemException {
          // Raced with another eviction; nothing to index.
        }
      }
    } on FileSystemException {
      // The folder went away mid-walk: index what was listed.
    }
  }
  return scan;
}

// A write gets a new token even when its size and clock match the old file.
// Recency-only updates preserve it, so failed lookups cannot delete a rewrite.
typedef _DiskEntry = (int, DateTime, Object);

class _DiskIndex {
  _DiskIndex(this.directory, this.publicDirectory, _Scan scan)
    : _publicPrefix = '${publicDirectory.path}${p.separator}',
      files = {
        for (final entry in scan.files.entries)
          entry.key: (entry.value.$1, entry.value.$2, Object()),
      },
      total = scan.total,
      publicTotal = scan.publicTotal;

  /// The attachments namespace (`v2`) and the public one, side by side.
  final Directory directory, publicDirectory;
  final Map<String, _DiskEntry> files;

  /// Bytes of every entry, and of the public ones among them.
  int total, publicTotal;

  final String _publicPrefix;

  /// Every indexed path is built from [directory] or [publicDirectory], so a
  /// prefix test is exact (and, unlike `p.isWithin`, cheap enough to run for
  /// every entry of a large cache).
  bool isPublic(String path) => path.startsWith(_publicPrefix);
}

class _Waiter {
  _Waiter(this.progress);
  final void Function(int received, int total)? progress;
}

class _Download {
  final CancelToken shared = CancelToken();
  final Set<_Waiter> waiters = {};
  final Completer<void> done = Completer<void>();
  bool finished = false;
}
