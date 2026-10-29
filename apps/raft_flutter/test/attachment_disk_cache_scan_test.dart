import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';

/// The cold-start index scan of [AttachmentDiskCache]: how long it takes on a
/// large cache, how long it can stall the isolate it is awaited on, and that
/// the cache is correct for callers that arrive while it is still running.
///
/// `RAFT_CACHE_SCAN_FILES=20000 ../../tool/flutter test test/attachment_disk_cache_scan_test.dart`
/// runs the benchmark at another size and prints the figures; the default
/// size keeps the regular run fast.
String _name(int i) =>
    sha256.convert(utf8.encode('$i')).toString().substring(0, 40);

/// Creates [count] private entries in the real layout
/// (`v2/<account>/<server>/<channel>/<entry>`, 50 entries per channel) plus a
/// few public ones, [bytes] bytes each. Synchronous so setup stays quick.
void _populate(Directory root, int count, {int bytes = 1024, int public = 50}) {
  final payload = Uint8List(bytes);
  final v2 = '${root.path}/raft-attachments/v2';
  for (var i = 0; i < count; i++) {
    final channel = i ~/ 50;
    final dir = Directory(
      '$v2/${_name(channel % 7)}/${_name(channel % 3 + 1000)}/${_name(channel + 2000)}',
    )..createSync(recursive: true);
    File('${dir.path}/${_name(i + 10000)}').writeAsBytesSync(payload);
  }
  final pub = Directory('${root.path}/raft-attachments/public')
    ..createSync(recursive: true);
  for (var i = 0; i < public; i++) {
    File('${pub.path}/${_name(i + 900000)}').writeAsBytesSync(payload);
  }
}

AttachmentImageStoreKey _key(String id) => AttachmentImageStoreKey(
  identity: AttachmentImageKey.identityOf('https://x.invalid', 'alice', 's1'),
  channelId: 'c1',
  entry: jsonEncode([id, 'rev', 'file']),
);

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-disk-cache-scan');
  });
  tearDown(() => root.delete(recursive: true));

  final files =
      int.tryParse(Platform.environment['RAFT_CACHE_SCAN_FILES'] ?? '') ?? 2000;

  test(
    'indexing $files entries does not stall the isolate',
    () async {
      _populate(root, files);
      final cache = AttachmentDiskCache(() async => root);

      // A 2 ms ticker on the same isolate: its largest gap is the longest the
      // scan kept the event loop (and so a frame) waiting.
      final clock = Stopwatch()..start();
      var last = clock.elapsedMicroseconds, worst = 0;
      final ticker = Timer.periodic(const Duration(milliseconds: 2), (_) {
        final now = clock.elapsedMicroseconds;
        if (now - last > worst) worst = now - last;
        last = now;
      });
      // What the ticker reports with nothing going on (timer jitter under load).
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final idle = worst;
      worst = 0;
      last = clock.elapsedMicroseconds;
      final start = clock.elapsedMicroseconds;
      await cache.warm();
      final scanMs = (clock.elapsedMicroseconds - start) / 1000;
      ticker.cancel();

      final count = await cache.entryCount();
      expect(count, files + 50);
      expect(await cache.sizeBytes(), (files + 50) * 1024);
      expect(
        await cache.sizeBytes(namespace: AttachmentCacheNamespace.public),
        50 * 1024,
      );
      // ignore: avoid_print
      print(
        'cache index scan: $files private + 50 public files: '
        '${scanMs.toStringAsFixed(0)} ms, longest event-loop gap '
        '${(worst / 1000).toStringAsFixed(1)} ms '
        '(${(idle / 1000).toStringAsFixed(1)} ms when idle)',
      );
      // Generous: a loaded CI machine, not a benchmark threshold.
      expect(worst / 1000, lessThan(250));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('callers that arrive while the index is being built see the right '
      'cache', () async {
    _populate(root, 600);
    final cache = AttachmentDiskCache(() async => root);
    // No warm(): everything below races the scan.
    final write = cache.write(_key('fresh'), Uint8List(1024));
    final size = cache.sizeBytes();
    final missing = cache.read(_key('never-stored'));
    final publicWrite = cache.writePublic('https://x.invalid/a', Uint8List(7));
    await Future.wait([write, size, missing, publicWrite]);
    expect(await missing, isNull);
    expect(
      await size,
      650 * 1024,
      reason: 'the scan finishes before it counts',
    );
    expect((await cache.read(_key('fresh')))?.length, 1024);
    expect(await cache.entryCount(), 600 + 50 + 2);
    expect(await cache.sizeBytes(), 651 * 1024 + 7);
    // A second cache over the same folder indexes the same entries (the
    // write above is on disk, not only in the first one's index).
    final again = AttachmentDiskCache(() async => root);
    expect(await again.entryCount(), 600 + 50 + 2);
    expect((await again.read(_key('fresh')))?.length, 1024);
  });

  test('a cap set while the index is still being built applies to what the '
      'scan finds', () async {
    _populate(root, 600, public: 5);
    final cache = AttachmentDiskCache(() async => root);
    // No warm(): the cap change races the scan and runs after it.
    await cache.setMaxBytes(300 * 1024);
    expect(
      await cache.sizeBytes(namespace: AttachmentCacheNamespace.attachments),
      lessThanOrEqualTo(270 * 1024),
    );
    expect(
      await cache.sizeBytes(namespace: AttachmentCacheNamespace.public),
      5 * 1024,
      reason: 'the public namespace is not evicted for the attachments',
    );
    final onDisk = await Directory(
      root.path,
    ).list(recursive: true).where((e) => e is File).length;
    expect(onDisk, await cache.entryCount());
  });

  test('entries keep their last-opened order across the scan', () async {
    _populate(root, 10, public: 0);
    final files = [
      for (final e in Directory(
        '${root.path}/raft-attachments/v2',
      ).listSync(recursive: true))
        if (e is File) e,
    ];
    // Oldest first: the first file opened longest ago.
    for (var i = 0; i < files.length; i++) {
      files[i].setLastModifiedSync(DateTime(2030, 1, 1 + i));
    }
    final cache = AttachmentDiskCache(
      () async => root,
      idleExpiry: const Duration(days: 100000),
      clock: () => DateTime(2030, 6, 1),
    );
    await cache.setMaxBytes(5 * 1024);
    // 90 % of 5 KiB is 4.5 KiB: the four newest of ten 1 KiB files stay.
    final left = {
      for (final e in Directory(
        '${root.path}/raft-attachments/v2',
      ).listSync(recursive: true))
        if (e is File) e.path,
    };
    expect(left, {for (final f in files.sublist(6)) f.path});
  });

  test('partial files left by a crash are deleted by the scan', () async {
    _populate(root, 20, public: 0);
    final part = File('${root.path}/raft-attachments/v2/x.7.raft-part')
      ..writeAsBytesSync([1, 2, 3]);
    final cache = AttachmentDiskCache(() async => root);
    expect(await cache.entryCount(), 20);
    expect(part.existsSync(), isFalse);
  });
}
