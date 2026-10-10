import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Where one fetched image source (thumbnail or original bytes) is persisted.
/// [identity] binds the entry to origin/principal/server; [channelId] lets a
/// revoked channel be purged as a unit. No URL or credential is part of it.
class AttachmentImageStoreKey {
  const AttachmentImageStoreKey({
    required this.identity,
    required this.channelId,
    required this.entry,
  });
  final String identity, channelId, entry;
}

/// Persistent encoded-bytes cache behind the attachment image repository.
/// Reads are only issued after the repository has verified the current
/// identity and channel authority; the store itself never grants access.
abstract interface class AttachmentImageByteStore {
  Future<Uint8List?> read(AttachmentImageStoreKey key);
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes);
  Future<void> remove(AttachmentImageStoreKey key);
  Future<void> purgeChannel(String identity, String channelId);
  Future<void> purgeIdentity(String identity);
}

/// Bounded on-disk LRU of attachment image bytes. File and directory names
/// are hashes; access order persists through file modification times.
class AttachmentImageDiskCache implements AttachmentImageByteStore {
  AttachmentImageDiskCache(
    this._root, {
    this.maxBytes = 256 * 1024 * 1024,
    this.maxEntryBytes = 32 * 1024 * 1024,
  });

  /// The process-wide cache installed by the app entry point. Controllers use
  /// it unless they are given another store; tests leave it unset.
  static AttachmentImageByteStore? installed;

  final Future<Directory> Function() _root;
  final int maxBytes, maxEntryBytes;
  Future<_DiskIndex?>? _index;
  Future<void> _tail = Future.value();

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 40);

  Future<_DiskIndex?> _open() => _index ??= () async {
    try {
      final directory = Directory(
        p.join((await _root()).path, 'raft-attachment-images', 'v1'),
      );
      await directory.create(recursive: true);
      final index = _DiskIndex(directory);
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.part')) {
          await _quietly(entity.delete);
          continue;
        }
        try {
          final stat = await entity.stat();
          index.files[entity.path] = (stat.size, stat.modified);
          index.total += stat.size;
        } on FileSystemException {
          // Raced with another eviction; nothing to index.
        }
      }
      return index;
    } catch (_) {
      return null; // No platform cache directory: run memory-only.
    }
  }();

  /// Serializes mutations so concurrent writes/evictions see one index.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _path(_DiskIndex index, AttachmentImageStoreKey key) => p.join(
    index.directory.path,
    _hash(key.identity),
    _hash(key.channelId),
    _hash(key.entry),
  );

  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async {
    final index = await _open();
    if (index == null) return null;
    final path = _path(index, key);
    if (!index.files.containsKey(path)) return null;
    try {
      final bytes = await File(path).readAsBytes();
      final now = DateTime.now();
      index.files[path] = (bytes.length, now);
      unawaited(_quietly(() => File(path).setLastModified(now)));
      return bytes;
    } on FileSystemException {
      await _serial(() => _delete(index, path));
      return null;
    }
  }

  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxEntryBytes) return;
    final index = await _open();
    if (index == null) return;
    await _serial(() async {
      final path = _path(index, key);
      final part = '$path.part';
      try {
        await Directory(p.dirname(path)).create(recursive: true);
        await File(part).writeAsBytes(bytes, flush: true);
        await File(part).rename(path);
      } on FileSystemException {
        await _quietly(() => File(part).delete());
        return;
      }
      index.total -= index.files[path]?.$1 ?? 0;
      index.files[path] = (bytes.length, DateTime.now());
      index.total += bytes.length;
      if (index.total <= maxBytes) return;
      final oldest = index.files.entries.toList()
        ..sort((a, b) => a.value.$2.compareTo(b.value.$2));
      for (final entry in oldest) {
        if (index.total <= maxBytes * 9 ~/ 10) break;
        if (entry.key == path) continue;
        await _delete(index, entry.key);
      }
    });
  }

  @override
  Future<void> remove(AttachmentImageStoreKey key) async {
    final index = await _open();
    if (index == null) return;
    await _serial(() => _delete(index, _path(index, key)));
  }

  @override
  Future<void> purgeChannel(String identity, String channelId) =>
      _purge(p.join(_hash(identity), _hash(channelId)));

  @override
  Future<void> purgeIdentity(String identity) => _purge(_hash(identity));

  Future<void> _purge(String relative) async {
    final index = await _open();
    if (index == null) return;
    await _serial(() async {
      final directory = p.join(index.directory.path, relative);
      for (final path in index.files.keys.toList()) {
        if (p.isWithin(directory, path)) {
          index.total -= index.files.remove(path)!.$1;
        }
      }
      await _quietly(() => Directory(directory).delete(recursive: true));
    });
  }

  Future<void> _delete(_DiskIndex index, String path) async {
    final removed = index.files.remove(path);
    if (removed != null) index.total -= removed.$1;
    await _quietly(() => File(path).delete());
  }

  static Future<void> _quietly(Future<Object?> Function() task) async {
    try {
      await task();
    } on FileSystemException {
      // Best effort: a missing file is already the desired state.
    }
  }
}

class _DiskIndex {
  _DiskIndex(this.directory);
  final Directory directory;
  final Map<String, (int, DateTime)> files = {};
  int total = 0;
}
