import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';

import 'support/scroll_session.dart' show MemoryImageStore;

const scope = AttachmentImageScope(
  origin: 'https://example.invalid',
  principal: 'alice',
  server: 'server',
  generation: 1,
  role: 'member',
);

AttachmentImageKey keyOf(String rendition, {AttachmentDecodeTarget? target}) =>
    AttachmentImageKey(
      scope: scope,
      channelId: 'channel',
      attachmentId: 'photo',
      revision: 'A',
      rendition: rendition,
      target: target,
    );

final listTarget = AttachmentDecodeTarget.box(
  300,
  200,
  devicePixelRatio: 2,
  cover: true,
);

/// Decodes by recording: the "image" is whichever bytes it was handed.
class _Run {
  _Run(this.store) {
    repository = AttachmentImageRepository(
      scope: scope,
      retainedAuthority: (_) => true,
      store: store,
      decoder: (bytes, target) async {
        decodedBytes.add(bytes);
        decodedTargets.add(target);
        return DecodedAttachmentImage(
          provider: MemoryImage(bytes),
          encodedBytes: 0,
          decodedBytes: 4,
          release: () async {},
        );
      },
    );
  }
  final MemoryImageStore store;
  late final AttachmentImageRepository repository;
  final decodedBytes = <Uint8List>[];
  final decodedTargets = <AttachmentDecodeTarget?>[];
  final downloads = <String>[];

  Future<bool> load(
    AttachmentImageKey key, {
    bool bestAvailable = true,
    Uint8List? network,
  }) async {
    final lease = repository.acquire(
      key,
      authorized: () => true,
      bestAvailable: bestAvailable,
      load: (_) async {
        downloads.add(key.rendition);
        return network ?? Uint8List.fromList([9, 9, 9]);
      },
    );
    await lease.ready;
    final fromStore = lease.fromStore;
    lease.release();
    return fromStore;
  }
}

void main() {
  final original = Uint8List.fromList([1, 1, 1, 1]);
  final thumbnail = Uint8List.fromList([2, 2]);

  Future<_Run> run({bool withOriginal = false, bool withThumbnail = false}) async {
    final store = MemoryImageStore();
    if (withOriginal) {
      await store.write(keyOf('original').storeKey, original);
    }
    if (withThumbnail) {
      await store.write(keyOf('thumbnail').storeKey, thumbnail);
    }
    final run = _Run(store);
    addTearDown(run.repository.dispose);
    return run;
  }

  test('a thumbnail key is served by the stored original, decoded at the list size', () async {
    final r = await run(withOriginal: true);
    expect(await r.load(keyOf('thumbnail', target: listTarget)), isTrue);
    expect(r.downloads, isEmpty);
    expect(r.decodedBytes.single, original);
    expect(r.decodedTargets.single, listTarget);
  });

  test('an original key is served by the stored thumbnail (the flipped cold-start key)', () async {
    final r = await run(withThumbnail: true);
    expect(await r.load(keyOf('original', target: listTarget)), isTrue);
    expect(r.downloads, isEmpty);
    expect(r.decodedBytes.single, thumbnail);
  });

  test('the original is preferred when both versions are stored', () async {
    final r = await run(withOriginal: true, withThumbnail: true);
    await r.load(keyOf('thumbnail', target: listTarget));
    expect(r.decodedBytes.single, original);
    expect(r.downloads, isEmpty);
  });

  test('the lightbox never settles for the stored thumbnail', () async {
    // Full size, and a stage-sized preload: both want the real picture.
    for (final key in [keyOf('original'), keyOf('original', target: listTarget)]) {
      final r = await run(withThumbnail: true);
      expect(await r.load(key, bestAvailable: false), isFalse);
      expect(r.downloads, ['original']);
    }
  });

  test('nothing stored: one download, saved under the requested rendition only', () async {
    final r = await run();
    expect(await r.load(keyOf('original', target: listTarget)), isFalse);
    expect(r.downloads, ['original']);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(r.store.entries.length, 1);
    // The next launch carries the thumbnail URL: still no second download.
    final next = _Run(r.store);
    addTearDown(next.repository.dispose);
    expect(await next.load(keyOf('thumbnail', target: listTarget)), isTrue);
    expect(next.downloads, isEmpty);
  });

  test('an undecodable stored hit is removed, not served again', () async {
    final store = MemoryImageStore();
    await store.write(keyOf('original').storeKey, original);
    final repository = AttachmentImageRepository(
      scope: scope,
      retainedAuthority: (_) => true,
      store: store,
      decoder: (bytes, target) async => throw const FormatException('bad'),
    );
    addTearDown(repository.dispose);
    final lease = repository.acquire(
      keyOf('thumbnail', target: listTarget),
      authorized: () => true,
      bestAvailable: true,
      load: (_) async => thumbnail,
    );
    await expectLater(lease.ready, throwsA(anything));
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(store.entries, isEmpty);
  });
}
