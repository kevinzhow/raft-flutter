import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/cache_directory_listing.dart';

AttachmentImageStoreKey key(
  String id, {
  String account = 'alice',
  String server = 's1',
  String channel = 'c1',
}) => AttachmentImageStoreKey(
  identity: AttachmentImageKey.identityOf('https://x.invalid', account, server),
  channelId: channel,
  entry: jsonEncode([id, 'rev', 'file']),
);

Uint8List bytes(int length, [int fill = 7]) =>
    Uint8List.fromList(List.filled(length, fill));

/// A download that writes [length] bytes and counts its runs.
class _Downloads {
  int runs = 0;
  Completer<void>? gate;
  Future<void> call(
    File destination,
    CancelToken cancel,
    void Function(int, int) progress, {
    int length = 10,
    int fill = 7,
  }) async {
    runs++;
    await gate?.future;
    if (cancel.isCancelled) throw const FileSystemException('cancelled');
    await destination.writeAsBytes(bytes(length, fill));
    progress(length, length);
  }
}

Future<List<File>> allFiles(Directory root) async => [
  await for (final e in listCacheDirectory(root, recursive: true))
    if (e is File) e,
];

void main() {
  late Directory root;
  late AttachmentDiskCache cache;
  AttachmentDiskCache open({int maxBytes = 1 << 20}) =>
      AttachmentDiskCache(() async => root, maxBytes: maxBytes);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-disk-cache');
    cache = open();
  });
  tearDown(() => root.delete(recursive: true));

  test('the default cap is one gibibyte, defined once', () {
    expect(attachmentCacheMaxBytes, 1024 * 1024 * 1024);
    expect(
      AttachmentDiskCache(() async => root).maxBytes,
      attachmentCacheMaxBytes,
    );
  });

  group('changing the cap', () {
    Future<void> tick() =>
        Future<void>.delayed(const Duration(milliseconds: 5));

    test('the tiers are 256 MB to 5 GB and include the default', () {
      expect(attachmentCacheBudgetTiers, [
        256 * 1024 * 1024,
        512 * 1024 * 1024,
        1024 * 1024 * 1024,
        2 * 1024 * 1024 * 1024,
        5 * 1024 * 1024 * 1024,
      ]);
      expect(attachmentCacheBudgetTiers, contains(attachmentCacheMaxBytes));
    });

    test('a lower cap evicts least recently used entries at once, down to '
        '90 % of it', () async {
      final c = open(maxBytes: 1000);
      for (final id in ['a', 'b', 'c', 'd', 'e']) {
        await c.write(key(id), bytes(150));
        await tick();
      }
      // Opening a makes b the oldest.
      expect(await c.read(key('a')), isNotNull);
      await tick();
      expect(await c.sizeBytes(), 750);

      await c.setMaxBytes(400);
      expect(c.maxBytes, 400);
      // 90 % of 400 is 360: two entries (300) are left, the newest two.
      expect(await c.sizeBytes(), 300);
      expect(await c.contains(key('b')), isFalse);
      expect(await c.contains(key('c')), isFalse);
      expect(await c.contains(key('d')), isFalse);
      expect(await c.contains(key('a')), isTrue);
      expect(await c.contains(key('e')), isTrue);
      final onDisk = (await allFiles(root))
          .fold<int>(0, (sum, f) => sum + f.lengthSync());
      expect(onDisk, 300, reason: 'evicted from the disk, not only the index');
    });

    test('a cap the cache is already under evicts nothing; a higher one '
        'lets it grow', () async {
      final c = open(maxBytes: 300);
      await c.write(key('a'), bytes(100));
      await tick();
      await c.setMaxBytes(1000);
      await c.write(key('b'), bytes(400));
      await c.write(key('c'), bytes(400));
      expect(await c.entryCount(), 3, reason: '900 B is under the new cap');
      await c.setMaxBytes(2000);
      expect(await c.entryCount(), 3);
    });

    test('files an open preview holds survive a lower cap', () async {
      final c = open(maxBytes: 1000);
      final held = await c.fetchFile(
        key('held'),
        filename: 'a.bin',
        download: _Downloads().call,
        expectedBytes: 10,
      );
      await tick();
      await c.write(key('x'), bytes(300));
      await tick();
      await c.write(key('y'), bytes(300));
      await c.setMaxBytes(100);
      expect(await c.containsFile(key('held'), filename: 'a.bin'), isTrue);
      expect(held!.file.existsSync(), isTrue);
      expect(await c.contains(key('x')), isFalse);
      expect(await c.contains(key('y')), isFalse);
      held.release();
    });

    test('the public namespace keeps its own cap whatever the total is set '
        'to', () async {
      final c = AttachmentDiskCache(
        () async => root,
        maxBytes: 100000,
        publicMaxBytes: 500,
      );
      await c.writePublic('https://x.invalid/a.webp', bytes(400));
      await c.write(key('a'), bytes(5000));
      await c.setMaxBytes(1000);
      expect(c.publicMaxBytes, 500);
      expect(await c.readPublic('https://x.invalid/a.webp'), isNotNull);
      expect(
        await c.sizeBytes(namespace: AttachmentCacheNamespace.public),
        400,
        reason: 'lowering the total does not touch the avatars',
      );
      expect(await c.contains(key('a')), isFalse);
      // And a raise does not grow the avatar cap.
      await c.setMaxBytes(2 * 1024 * 1024 * 1024);
      expect(c.publicMaxBytes, 500);
    });

    test('later writes obey the new cap', () async {
      final c = open(maxBytes: 100000);
      await c.setMaxBytes(100);
      for (var i = 0; i < 10; i++) {
        await c.write(key('e$i'), bytes(30));
        expect(await c.sizeBytes(), lessThanOrEqualTo(100));
      }
    });

    test('a cap that is not positive is refused', () async {
      expect(() => cache.setMaxBytes(0), throwsArgumentError);
    });

    test('without a cache directory it does nothing', () async {
      final broken = AttachmentDiskCache(
        () async => throw const FileSystemException('none'),
      );
      await broken.setMaxBytes(10);
      expect(await broken.sizeBytes(), 0);
    });
  });

  group('bytes entries', () {
    test('miss, then hit, and the same bytes after a restart', () async {
      expect(await cache.read(key('a')), isNull);
      expect(await cache.contains(key('a')), isFalse);
      await cache.write(key('a'), bytes(5));
      expect(await cache.contains(key('a')), isTrue);
      expect(await cache.read(key('a')), bytes(5));
      // A new instance (app restart) indexes what is on disk.
      final restarted = open();
      expect(await restarted.read(key('a')), bytes(5));
      expect(await restarted.sizeBytes(), 5);
    });

    test('entries are scoped by account, server and channel', () async {
      await cache.write(key('a'), bytes(3));
      expect(await cache.read(key('a', account: 'bob')), isNull);
      expect(await cache.read(key('a', server: 's2')), isNull);
      expect(await cache.read(key('a', channel: 'c2')), isNull);
    });

    test('empty and over-entry-size writes are ignored', () async {
      final small = AttachmentDiskCache(() async => root, maxEntryBytes: 4);
      await small.write(key('a'), Uint8List(0));
      await small.write(key('b'), bytes(5));
      expect(await small.sizeBytes(), 0);
    });

    test('least recently used entries are evicted past the cap', () async {
      final small = open(maxBytes: 100);
      await small.write(key('a'), bytes(40));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await small.write(key('b'), bytes(40));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // Touching a makes b the oldest.
      expect(await small.read(key('a')), isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await small.write(key('c'), bytes(40));
      expect(await small.contains(key('b')), isFalse);
      expect(await small.contains(key('a')), isTrue);
      expect(await small.contains(key('c')), isTrue);
      expect(await small.sizeBytes(), lessThanOrEqualTo(100));
    });

    test('the total never stays above the cap', () async {
      final small = open(maxBytes: 100);
      for (var i = 0; i < 20; i++) {
        await small.write(key('e$i'), bytes(30));
        expect(await small.sizeBytes(), lessThanOrEqualTo(100));
      }
      final onDisk = (await allFiles(root))
          .fold<int>(0, (sum, f) => sum + f.lengthSync());
      expect(onDisk, await small.sizeBytes());
    });

    test('a damaged index entry (file removed) is a miss', () async {
      await cache.write(key('a'), bytes(5));
      for (final file in await allFiles(root)) {
        file.deleteSync();
      }
      expect(await cache.read(key('a')), isNull);
      expect(await cache.contains(key('a')), isFalse);
    });

    test('writes leave no partial file behind', () async {
      await Future.wait([
        for (var i = 0; i < 5; i++) cache.write(key('a$i'), bytes(8, i)),
      ]);
      final names = [for (final f in await allFiles(root)) f.path];
      expect(names.where((n) => n.endsWith('.raft-part')), isEmpty);
      expect(names, hasLength(5));
    });
  });

  group('public namespace', () {
    AttachmentDiskCache openPublic({int maxBytes = 1 << 20, int? publicMax}) =>
        AttachmentDiskCache(
          () async => root,
          maxBytes: maxBytes,
          publicMaxBytes: publicMax,
        );

    test(
      'its cap defaults to the smaller of 64 MiB and an eighth of the budget',
      () {
        expect(
          AttachmentDiskCache(() async => root).publicMaxBytes,
          64 * 1024 * 1024,
        );
        expect(openPublic(maxBytes: 8000).publicMaxBytes, 1000);
      },
    );

    test('miss, hit and a restart; the key is hashed on disk', () async {
      expect(await cache.readPublic('https://x.test/a.webp'), isNull);
      await cache.writePublic('https://x.test/a.webp', bytes(6));
      expect(await cache.readPublic('https://x.test/a.webp'), bytes(6));
      expect(await open().readPublic('https://x.test/a.webp'), bytes(6));
      final names = (await allFiles(root)).map((f) => f.path).join('\n');
      expect(names, isNot(contains('x.test')));
      expect(
        names,
        contains('${Platform.pathSeparator}public${Platform.pathSeparator}'),
      );
    });

    test(
      'one budget, one size figure, separate counts per namespace',
      () async {
        await cache.write(key('a'), bytes(30));
        await cache.writePublic('p1', bytes(5));
        await cache.writePublic('p2', bytes(7));
        expect(await cache.sizeBytes(), 42);
        expect(
          await cache.sizeBytes(namespace: AttachmentCacheNamespace.public),
          12,
        );
        expect(
          await cache.sizeBytes(
            namespace: AttachmentCacheNamespace.attachments,
          ),
          30,
        );
        expect(await cache.entryCount(), 3);
        expect(
          await cache.entryCount(namespace: AttachmentCacheNamespace.public),
          2,
        );
        // The figures survive a restart (the index reads both directories).
        final restarted = open();
        expect(await restarted.sizeBytes(), 42);
        expect(
          await restarted.sizeBytes(namespace: AttachmentCacheNamespace.public),
          12,
        );
      },
    );

    test('sign-out and channel purges leave public entries alone', () async {
      final identity = AttachmentImageKey.identityOf(
        'https://x.invalid',
        'alice',
        's1',
      );
      await cache.write(key('a'), bytes(3));
      await cache.writePublic('p', bytes(3));
      await cache.purgeAccount('https://x.invalid', 'alice');
      await cache.purgeIdentity(identity);
      await cache.purgeChannel(identity, 'c1');
      expect(await cache.contains(key('a')), isFalse);
      expect(await cache.readPublic('p'), bytes(3));
      expect(await cache.sizeBytes(), 3);
    });

    test(
      'the public namespace keeps to its own cap, least recently used first',
      () async {
        final c = openPublic(publicMax: 100);
        await c.writePublic('a', bytes(40));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await c.writePublic('b', bytes(40));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(await c.readPublic('a'), isNotNull); // b is now the oldest
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await c.writePublic('c', bytes(40));
        expect(await c.readPublic('b'), isNull);
        expect(await c.readPublic('a'), isNotNull);
        expect(await c.readPublic('c'), isNotNull);
        expect(
          await c.sizeBytes(namespace: AttachmentCacheNamespace.public),
          lessThanOrEqualTo(100),
        );
      },
    );

    test('attachment pressure does not evict public entries', () async {
      final c = openPublic(maxBytes: 1000, publicMax: 200);
      await c.writePublic('avatar', bytes(50));
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 3));
        await c.write(key('e$i'), bytes(200));
      }
      expect(await c.sizeBytes(), lessThanOrEqualTo(1000));
      expect(await c.readPublic('avatar'), bytes(50));
      expect(
        await c.entryCount(namespace: AttachmentCacheNamespace.attachments),
        lessThan(12),
      );
    });

    test(
      'public entries do not count against the attachments LRU order',
      () async {
        final c = openPublic(maxBytes: 100, publicMax: 50);
        await c.writePublic('p', bytes(20));
        await c.write(key('a'), bytes(40));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await c.write(key('b'), bytes(40)); // 100 total: not over
        expect(await c.contains(key('a')), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await c.write(key('c'), bytes(40)); // 140: attachments trim, not p
        expect(await c.contains(key('a')), isFalse);
        expect(await c.readPublic('p'), isNotNull);
      },
    );

    test('oversized and empty public writes are ignored', () async {
      final c = AttachmentDiskCache(() async => root, publicMaxEntryBytes: 4);
      await c.writePublic('a', Uint8List(0));
      await c.writePublic('b', bytes(5));
      expect(await c.sizeBytes(), 0);
    });

    test('clear() empties both namespaces and tells the listeners', () async {
      var cleared = 0;
      cache.addPublicClearListener(() => cleared++);
      await cache.write(key('a'), bytes(3));
      await cache.writePublic('p', bytes(3));
      await cache.clear();
      expect(await cache.sizeBytes(), 0);
      expect(await cache.readPublic('p'), isNull);
      expect(cleared, 1);
      expect((await allFiles(root)), isEmpty);
    });

    test('clear(namespace) empties only that namespace', () async {
      var cleared = 0;
      cache.addPublicClearListener(() => cleared++);
      await cache.write(key('a'), bytes(3));
      await cache.writePublic('p', bytes(4));
      await cache.clear(namespace: AttachmentCacheNamespace.attachments);
      expect(await cache.contains(key('a')), isFalse);
      expect(await cache.readPublic('p'), bytes(4));
      expect(cleared, 0);
      await cache.write(key('a'), bytes(3));
      await cache.clear(namespace: AttachmentCacheNamespace.public);
      expect(await cache.contains(key('a')), isTrue);
      expect(await cache.readPublic('p'), isNull);
      expect(cleared, 1);
    });

    test('an unusable cache directory is a miss, never an error', () async {
      final broken = AttachmentDiskCache(
        () async => throw const FileSystemException(),
      );
      expect(await broken.readPublic('k'), isNull);
      await broken.writePublic('k', bytes(3));
      expect(await broken.sizeBytes(), 0);
    });
  });

  group('long cache roots', () {
    late Directory longRoot;
    AttachmentDiskCache openLong() => AttachmentDiskCache(() async => longRoot);

    setUp(() async {
      longRoot = await Directory(
        p.join(root.path, 'long cache-测试-${'r' * 100}'),
      ).create();
    });

    test(
      'restart indexes bytes and files without changing their paths',
      () async {
        final first = openLong();
        await first.write(key('bytes'), bytes(3));
        await first.writePublic('avatar', bytes(5));
        final file = (await first.fetchFile(
          key('file'),
          filename: 'paper.pdf',
          download: _Downloads().call,
        ))!;
        final path = file.file.path;
        file.release();

        final restarted = openLong();
        expect(await restarted.sizeBytes(), 18);
        expect(await restarted.read(key('bytes')), bytes(3));
        expect(await restarted.readPublic('avatar'), bytes(5));
        final hit = await restarted.openFile(
          key('file'),
          filename: 'paper.pdf',
        );
        expect(hit, isNotNull);
        expect(hit!.file.path, path);
        expect(await hit.file.readAsBytes(), bytes(10));
        hit.release();

        await restarted.clear(namespace: AttachmentCacheNamespace.attachments);
        expect(File(path).existsSync(), isFalse);
        expect(await restarted.sizeBytes(), 5);
        expect(await restarted.readPublic('avatar'), bytes(5));
      },
    );

    test(
      'startup removes partials and revocation removes the stored file',
      () async {
        final file = (await openLong().fetchFile(
          key('file'),
          filename: 'paper.pdf',
          download: _Downloads().call,
        ))!;
        final path = file.file.path;
        file.release();
        final partial = File(
          p.join(file.file.parent.path, 'paper.pdf.9.raft-part'),
        )..writeAsBytesSync(bytes(7));

        final restarted = openLong();
        await restarted.warm();
        expect(partial.existsSync(), isFalse);
        expect(await restarted.sizeBytes(), 10);
        final hit = await restarted.openFile(
          key('file'),
          filename: 'paper.pdf',
        );
        expect(hit, isNotNull);
        hit!.release();
        await restarted.purgeAccount('https://x.invalid', 'alice');
        expect(File(path).existsSync(), isFalse);
        expect(await openLong().sizeBytes(), 0);
      },
    );
  });

  group('file entries', () {
    test('miss downloads once, hit makes no download', () async {
      final downloads = _Downloads();
      final first = await cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        expectedBytes: 10,
        download: downloads.call,
      );
      expect(downloads.runs, 1);
      expect(first!.file.path.endsWith('doc.pdf'), isTrue);
      expect(await first.file.readAsBytes(), bytes(10));
      first.release();

      final second = await cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        expectedBytes: 10,
        download: downloads.call,
      );
      expect(downloads.runs, 1, reason: 'the second open is a cache hit');
      expect(second!.file.path, first.file.path);
      second.release();
    });

    test('a hit survives a restart with no download', () async {
      final downloads = _Downloads();
      (await cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        download: downloads.call,
      ))!.release();
      final restarted = open();
      final hit = await restarted.openFile(key('a'), filename: 'doc.pdf');
      expect(hit, isNotNull);
      expect(await hit!.file.readAsBytes(), bytes(10));
      hit.release();
      expect(downloads.runs, 1);
    });

    test('concurrent opens of one entry share one download', () async {
      final downloads = _Downloads()..gate = Completer<void>();
      final seen = <int>[];
      final results = Future.wait([
        for (var i = 0; i < 3; i++)
          cache.fetchFile(
            key('a'),
            filename: 'doc.pdf',
            expectedBytes: 10,
            download: downloads.call,
            onProgress: (received, total) => seen.add(received),
          ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      downloads.gate!.complete();
      final files = await results;
      expect(downloads.runs, 1);
      expect(files.map((f) => f!.file.path).toSet(), hasLength(1));
      expect(seen, [10, 10, 10], reason: 'every caller sees the progress');
      for (final f in files) {
        f!.release();
      }
    });

    test('a cancelled caller leaves the others downloading', () async {
      final downloads = _Downloads()..gate = Completer<void>();
      final quitter = CancelToken();
      final stays = cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        download: downloads.call,
      );
      final leaves = cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        download: downloads.call,
        cancel: quitter,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      quitter.cancel();
      expect(await leaves, isNull);
      downloads.gate!.complete();
      final file = await stays;
      expect(file, isNotNull);
      expect(downloads.runs, 1);
      file!.release();
    });

    test('when every caller cancels the download is cancelled', () async {
      final downloads = _Downloads()..gate = Completer<void>();
      final started = Completer<CancelToken>();
      final only = CancelToken();
      final result = cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        cancel: only,
        download: (destination, cancel, progress) {
          started.complete(cancel);
          return downloads.call(destination, cancel, progress);
        },
      );
      final shared = await started.future;
      only.cancel();
      expect(await result, isNull);
      expect(shared.isCancelled, isTrue);
      downloads.gate!.complete();
      // The cancelled download cleans up after itself.
      for (var i = 0; i < 100 && (await allFiles(root)).isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await cache.sizeBytes(), 0);
      expect(
        (await allFiles(root)),
        isEmpty,
        reason: 'a cancelled download leaves nothing',
      );
    });

    test('a failed or truncated download is never cached', () async {
      await expectLater(
        cache.fetchFile(
          key('a'),
          filename: 'doc.pdf',
          download: (file, cancel, progress) async {
            await file.writeAsBytes(bytes(4));
            throw const SocketException('connection reset');
          },
        ),
        throwsA(isA<SocketException>()),
      );
      expect(await allFiles(root), isEmpty);
      // Fewer bytes than the metadata promises: incomplete, rejected.
      final downloads = _Downloads();
      await expectLater(
        cache.fetchFile(
          key('a'),
          filename: 'doc.pdf',
          expectedBytes: 99,
          download: downloads.call,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await cache.sizeBytes(), 0);
      expect(await allFiles(root), isEmpty);
      // The entry is still fetchable afterwards.
      final ok = await cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        expectedBytes: 10,
        download: downloads.call,
      );
      expect(ok, isNotNull);
      ok!.release();
    });

    test(
      'a metadata size of 0 means unknown, not "every download is short"',
      () async {
        final downloads = _Downloads();
        final first = await cache.fetchFile(
          key('z'),
          filename: 'doc.pdf',
          expectedBytes: 0,
          download: downloads.call,
        );
        expect(first, isNotNull);
        first!.release();
        final again = await cache.openFile(
          key('z'),
          filename: 'doc.pdf',
          expectedBytes: 0,
        );
        expect(
          again,
          isNotNull,
          reason: 'the stored copy is not called corrupt',
        );
        again!.release();
      },
    );

    test('a corrupt stored file is ignored and fetched again', () async {
      final downloads = _Downloads();
      final first = await cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        expectedBytes: 10,
        download: downloads.call,
      );
      final path = first!.file.path;
      first.release();
      // Truncate it behind the cache's back.
      File(path).writeAsBytesSync(bytes(3));
      expect(
        await cache.openFile(key('a'), filename: 'doc.pdf', expectedBytes: 10),
        isNull,
      );
      expect(File(path).existsSync(), isFalse);
      final again = await cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        expectedBytes: 10,
        download: downloads.call,
      );
      expect(downloads.runs, 2);
      expect(again, isNotNull);
      again!.release();
    });

    test('metadata that disagrees with the stored size is a miss', () async {
      final downloads = _Downloads();
      (await cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        download: downloads.call,
      ))!.release();
      expect(
        await cache.openFile(key('a'), filename: 'doc.pdf', expectedBytes: 11),
        isNull,
      );
    });

    test('partial files from a crashed run are deleted at start', () async {
      (await cache.fetchFile(
        key('a'),
        filename: 'doc.pdf',
        download: _Downloads().call,
      ))!.release();
      final entry = (await allFiles(root)).single;
      final partial = File('${entry.parent.path}/doc.pdf.9.raft-part')
        ..writeAsBytesSync(bytes(500));
      final restarted = open();
      expect(await restarted.sizeBytes(), 10);
      expect(partial.existsSync(), isFalse);
    });

    test('a file in use is never evicted', () async {
      final small = open(maxBytes: 25);
      final held = await small.fetchFile(
        key('a'),
        filename: 'a.bin',
        download: _Downloads().call,
      );
      await small.write(key('b'), bytes(10));
      await small.write(key('c'), bytes(10));
      expect(held!.file.existsSync(), isTrue);
      expect(await small.containsFile(key('a'), filename: 'a.bin'), isTrue);
      held.release();
      await small.write(key('d'), bytes(10));
      expect(
        await small.containsFile(key('a'), filename: 'a.bin'),
        isFalse,
        reason: 'once released it is the oldest and goes first',
      );
    });

    test('file names cannot escape the entry directory', () async {
      final file = await cache.fetchFile(
        key('a'),
        filename: '../../etc/passwd',
        download: _Downloads().call,
      );
      expect(file!.file.path.startsWith(root.path), isTrue);
      expect(file.file.path.endsWith('passwd'), isTrue);
      file.release();
    });

    test('no cache directory: callers fall back', () async {
      final broken = AttachmentDiskCache(
        () async => throw const FileSystemException('none'),
      );
      await expectLater(
        broken.fetchFile(
          key('a'),
          filename: 'a.bin',
          download: _Downloads().call,
        ),
        throwsA(isA<AttachmentCacheUnavailable>()),
      );
      expect(await broken.sizeBytes(), 0);
      expect(await broken.read(key('a')), isNull);
    });
  });

  group('clearing and revocation', () {
    Future<void> fill() async {
      await cache.write(key('a'), bytes(10));
      await cache.write(key('b', account: 'bob'), bytes(10));
      (await cache.fetchFile(
        key('c', server: 's2'),
        filename: 'c.pdf',
        download: _Downloads().call,
      ))!.release();
    }

    test('clear empties the cache and only the cache', () async {
      await fill();
      // Things that live next to the cache directory are not the cache's.
      final session = File(p.join(root.path, 'session.json'))
        ..writeAsStringSync('x');
      final saved = File(p.join(root.path, 'Downloads', 'report.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('mine');
      expect(await cache.sizeBytes(), 30);
      await cache.clear();
      expect(await cache.sizeBytes(), 0);
      expect(await cache.entryCount(), 0);
      expect(await cache.read(key('a')), isNull);
      expect(session.existsSync(), isTrue);
      expect(saved.readAsStringSync(), 'mine');
      expect(
        (await allFiles(root)).map((f) => f.path),
        unorderedEquals([session.path, saved.path]),
      );
      // It keeps working afterwards.
      await cache.write(key('a'), bytes(4));
      expect(await cache.sizeBytes(), 4);
    });

    test('clear keeps a file an open preview still holds', () async {
      final held = await cache.fetchFile(
        key('a'),
        filename: 'a.pdf',
        download: _Downloads().call,
      );
      await cache.write(key('b'), bytes(5));
      await cache.clear();
      expect(held!.file.existsSync(), isTrue);
      expect(await cache.sizeBytes(), 10);
      held.release();
      await cache.clear();
      expect(await cache.sizeBytes(), 0);
    });

    test('logout removes the account on every server, others stay', () async {
      await fill();
      await cache.write(key('d', server: 's9'), bytes(2));
      await cache.purgeAccount('https://x.invalid', 'alice');
      expect(await cache.read(key('a')), isNull);
      expect(await cache.read(key('d', server: 's9')), isNull);
      expect(
        await cache.containsFile(key('c', server: 's2'), filename: 'c.pdf'),
        isFalse,
      );
      expect(await cache.read(key('b', account: 'bob')), bytes(10));
    });

    test('revoking a server removes only that server', () async {
      await fill();
      await cache.purgeIdentity(
        AttachmentImageKey.identityOf('https://x.invalid', 'alice', 's2'),
      );
      expect(
        await cache.containsFile(key('c', server: 's2'), filename: 'c.pdf'),
        isFalse,
      );
      expect(await cache.read(key('a')), bytes(10));
    });

    test(
      'revoking a channel removes bytes and files of that channel',
      () async {
        await cache.write(key('a'), bytes(10));
        await cache.write(key('b', channel: 'c2'), bytes(10));
        (await cache.fetchFile(
          key('f'),
          filename: 'f.pdf',
          download: _Downloads().call,
        ))!.release();
        await cache.purgeChannel(
          AttachmentImageKey.identityOf('https://x.invalid', 'alice', 's1'),
          'c1',
        );
        expect(await cache.read(key('a')), isNull);
        expect(await cache.containsFile(key('f'), filename: 'f.pdf'), isFalse);
        expect(await cache.read(key('b', channel: 'c2')), bytes(10));
        expect(await cache.sizeBytes(), 10);
      },
    );

    test('the pre-v2 image-only directory is removed', () async {
      final old = File('${root.path}/raft-attachment-images/v1/x/y/z')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes(9));
      await open().sizeBytes();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(old.existsSync(), isFalse);
    });
  });
}
