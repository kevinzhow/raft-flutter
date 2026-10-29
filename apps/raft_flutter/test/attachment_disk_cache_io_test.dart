import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/data/attachment_disk_cache.dart';
import 'package:raft_flutter/data/attachment_image_store.dart';

// Real files and handles; only the completion order is controlled. No cache
// internals, filesystem errors, or delays are mocked away.
final class _ObservedIO extends IOOverrides {
  Future<void> Function(File)? afterRead, afterWrite, beforeTouch, afterTouch;
  Future<void> Function(File)? beforeFileDelete;
  Future<void> Function(Directory)? beforeDelete;

  @override
  File createFile(String path) => _ObservedFile(super.createFile(path), this);

  @override
  Directory createDirectory(String path) =>
      _ObservedDirectory(super.createDirectory(path), this);
}

class _ObservedFile implements File {
  _ObservedFile(this.inner, this.io);
  final File inner;
  final _ObservedIO io;

  @override
  String get path => inner.path;
  @override
  Directory get parent => inner.parent;
  @override
  Future<Uint8List> readAsBytes() async {
    final bytes = await inner.readAsBytes();
    await io.afterRead?.call(inner);
    return bytes;
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await inner.writeAsBytes(bytes, mode: mode, flush: flush);
    await io.afterWrite?.call(inner);
    return this;
  }

  @override
  Future<File> setLastModified(DateTime time) async {
    try {
      await io.beforeTouch?.call(inner);
      await inner.setLastModified(time);
    } finally {
      await io.afterTouch?.call(inner);
    }
    return this;
  }

  @override
  Future<File> rename(String path) => inner.rename(path);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    await io.beforeFileDelete?.call(inner);
    return inner.delete(recursive: recursive);
  }

  @override
  Future<bool> exists() => inner.exists();
  @override
  Future<int> length() => inner.length();
  @override
  Future<FileStat> stat() => inner.stat();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedDirectory implements Directory {
  _ObservedDirectory(this.inner, this.io);
  final Directory inner;
  final _ObservedIO io;

  @override
  String get path => inner.path;
  @override
  Future<Directory> create({bool recursive = false}) =>
      inner.create(recursive: recursive);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    await io.beforeDelete?.call(inner);
    return inner.delete(recursive: recursive);
  }

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => inner.list(recursive: recursive, followLinks: followLinks);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _key = AttachmentImageStoreKey(
  identity: '["https://example.invalid","alice","server"]',
  channelId: 'channel',
  entry: 'image',
);

void main() {
  late Directory root;
  late AttachmentDiskCache cache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-disk-io');
    cache = AttachmentDiskCache(() async => root);
    await cache.write(_key, Uint8List.fromList([1, 2, 3]));
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'an unrelated write never delays stored reads or cache misses',
    () async {
      final writing = Completer<void>(), resume = Completer<void>();
      final other = AttachmentImageStoreKey(
        identity: _key.identity,
        channelId: 'other-channel',
        entry: 'other-image',
      );
      final io = _ObservedIO()
        ..afterWrite = (_) async {
          writing.complete();
          await resume.future;
        };
      await IOOverrides.runWithIOOverrides(() async {
        final write = cache.write(other, Uint8List.fromList([4, 5]));
        await writing.future;
        try {
          // This is a bounded liveness assertion, not a delay before checking.
          // The unrelated write stays blocked until every lookup completes.
          final results = await Future.wait<Object?>([
            cache.read(_key),
            cache.contains(_key),
            cache.readPublic('missing-avatar'),
            cache.containsFile(_key, filename: 'missing.pdf'),
            cache.openFile(_key, filename: 'missing.pdf'),
          ]).timeout(const Duration(seconds: 5));
          expect(results, [
            Uint8List.fromList([1, 2, 3]),
            true,
            null,
            false,
            null,
          ]);
        } finally {
          resume.complete();
          await write;
        }
      }, io);
    },
  );

  test('a late byte read cannot restore a purged index entry', () async {
    final paused = Completer<void>(), resume = Completer<void>();
    final io = _ObservedIO()
      ..afterRead = (_) async {
        paused.complete();
        await resume.future;
      };
    await IOOverrides.runWithIOOverrides(() async {
      final read = cache.read(_key);
      await paused.future;
      final purge = cache.purgeChannel(_key.identity, _key.channelId);
      // One event turn lets the already-requested purge enter its queue.
      // The byte read remains explicitly blocked on resume, not a timer.
      await Future<void>(() {});
      resume.complete();
      await read;
      await purge;
    }, io);
    expect(await cache.entryCount(), 0);
    expect(await cache.sizeBytes(), 0);
    expect(await AttachmentDiskCache(() async => root).read(_key), isNull);
  });

  test(
    'a failed read cannot discard a replacement with the same clock',
    () async {
      final now = DateTime.now();
      cache = AttachmentDiskCache(() async => root, clock: () => now);
      await cache.write(_key, Uint8List.fromList([1, 2, 3]));
      final reading = Completer<void>(), resume = Completer<void>();
      final io = _ObservedIO()
        ..afterRead = (_) async {
          reading.complete();
          await resume.future;
          throw const FileSystemException('read failed after opening');
        };
      await IOOverrides.runWithIOOverrides(() async {
        final read = cache.read(_key);
        await reading.future;
        final write = cache.write(_key, Uint8List.fromList([4, 5, 6]));
        await Future<void>(() {});
        resume.complete();
        expect(await read, isNull);
        await write;
      }, io);
      expect(await cache.read(_key), [4, 5, 6]);
      expect(await cache.sizeBytes(), 3);
    },
  );

  test('revocation waits for the timestamp handle before deleting', () async {
    final touching = Completer<void>(), resume = Completer<void>();
    final touchedDone = Completer<void>();
    final deleting = Completer<void>(), deleted = Completer<void>();
    var deletedWhileTouching = false;
    var touchActive = false;
    File? touched;
    final io = _ObservedIO()
      ..beforeTouch = (file) async {
        // Windows will refuse to delete this file while this handle is open.
        final handle = await file.open(mode: FileMode.append);
        touched = file;
        touchActive = true;
        touching.complete();
        try {
          await resume.future;
        } finally {
          await handle.close();
          touchActive = false;
        }
      }
      ..afterTouch = (_) async {
        touchedDone.complete();
      }
      ..beforeDelete = (directory) async {
        if (touched != null && p.isWithin(directory.path, touched!.path)) {
          deletedWhileTouching |= touchActive;
          deleting.complete();
        }
      };
    await IOOverrides.runWithIOOverrides(() async {
      final read = cache.read(_key);
      await touching.future;
      final purge = cache.purgeChannel(_key.identity, _key.channelId)
        ..whenComplete(() => deleted.complete());
      // Old code reaches deletion immediately and encounters the real locked
      // file. Correct code keeps deletion behind the unfinished read/touch.
      await Future.any([deleting.future, Future<void>(() {})]);
      if (deleting.isCompleted) await deleted.future;
      resume.complete();
      await read;
      await purge;
      await touchedDone.future;
    }, io);
    expect(
      (
        deletedWhileTouching,
        await touched!.exists(),
        await AttachmentDiskCache(() async => root).read(_key),
      ),
      (false, false, null),
    );
  });

  for (final fileEntry in [false, true]) {
    test(
      '${fileEntry ? 'file open' : 'public read'} finishes its timestamp before removal',
      () async {
        if (fileEntry) {
          (await cache.fetchFile(
            _key,
            filename: 'preview.pdf',
            download: (file, cancel, progress) async {
              await file.writeAsBytes([1, 2, 3]);
            },
          ))!.release();
        } else {
          await cache.writePublic('avatar', Uint8List.fromList([4, 5]));
        }
        final touching = Completer<void>(), resume = Completer<void>();
        final touchedDone = Completer<void>();
        var touchActive = false, deletedWhileTouching = false;
        String? touched;
        final io = _ObservedIO()
          ..beforeTouch = (file) async {
            touched = file.path;
            touchActive = true;
            touching.complete();
            await resume.future;
            touchActive = false;
          }
          ..afterTouch = (_) async {
            touchedDone.complete();
          }
          ..beforeFileDelete = (file) async {
            if (file.path == touched) deletedWhileTouching |= touchActive;
          }
          ..beforeDelete = (directory) async {
            if (touched != null && p.isWithin(directory.path, touched!)) {
              deletedWhileTouching |= touchActive;
            }
          };
        await IOOverrides.runWithIOOverrides(() async {
          final read = fileEntry
              ? cache.openFile(_key, filename: 'preview.pdf')
              : cache.readPublic('avatar');
          await touching.future;
          final remove = fileEntry
              ? cache.purgeAccount('https://example.invalid', 'alice')
              : cache.clear(namespace: AttachmentCacheNamespace.public);
          await Future<void>(() {});
          resume.complete();
          final result = await read;
          if (result is AttachmentCachedFile) result.release();
          await remove;
          await touchedDone.future;
        }, io);
        expect(deletedWhileTouching, isFalse);
        expect(await File(touched!).exists(), isFalse);
        // Removing public pictures leaves private bytes; account revocation
        // removes both private entry kinds.
        expect(await cache.entryCount(), fileEntry ? 0 : 1);
      },
    );
  }

  test(
    'purge follows an already-started byte write through its rename',
    () async {
      final writing = Completer<void>(), resume = Completer<void>();
      final io = _ObservedIO()
        ..afterWrite = (_) async {
          writing.complete();
          await resume.future;
        };
      await IOOverrides.runWithIOOverrides(() async {
        final write = cache.write(_key, Uint8List.fromList([4, 5]));
        await writing.future;
        final purge = cache.purgeIdentity(_key.identity);
        await Future<void>(() {});
        resume.complete();
        await write;
        await purge;
      }, io);
      expect(await cache.read(_key), isNull);
      expect(await cache.entryCount(), 0);
      expect(await cache.sizeBytes(), 0);
      expect(await AttachmentDiskCache(() async => root).read(_key), isNull);
    },
  );
}
