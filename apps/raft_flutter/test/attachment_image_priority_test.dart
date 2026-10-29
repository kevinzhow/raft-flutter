import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';

AttachmentImageScope get _scope => const AttachmentImageScope(
  origin: 'https://example.invalid',
  principal: 'alice',
  server: 'server',
  generation: 1,
  role: 'member',
);

AttachmentImageKey _key(String id) => AttachmentImageKey(
  scope: _scope,
  channelId: 'channel',
  attachmentId: id,
  revision: 'A',
);

void main() {
  AttachmentImageRepository make({int limit = 2}) => AttachmentImageRepository(
    scope: _scope,
    retainedAuthority: (_) => true,
    maxConcurrentLoads: limit,
    decoder: (bytes, _) async => DecodedAttachmentImage(
      provider: MemoryImage(bytes),
      encodedBytes: bytes.length,
      decodedBytes: 4,
      release: () async {},
    ),
  );

  test('an explicitly opened image does not wait behind list thumbnails', () async {
    final repository = make();
    final started = <String>[];
    final gates = <String, Completer<Uint8List>>{};
    AttachmentImageLoader loader(String id) => (CancelToken _) {
      started.add(id);
      return (gates[id] = Completer<Uint8List>()).future;
    };
    // Six list thumbnails: two run, four queue.
    for (var i = 0; i < 6; i++) {
      repository.acquire(
        _key('t$i'),
        load: loader('t$i'),
        authorized: () => true,
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(started, ['t0', 't1']);
    // The user opens one: it starts now, ahead of the four waiting ones.
    repository.acquire(
      _key('open'),
      load: loader('open'),
      authorized: () => true,
      foreground: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(started, ['t0', 't1', 'open']);
    // Foreground work is bounded too: the extra slots are limited.
    for (final id in ['f2', 'f3']) {
      repository.acquire(
        _key(id),
        load: loader(id),
        authorized: () => true,
        foreground: true,
      );
    }
    await Future<void>.delayed(Duration.zero);
    // Newest intent first; the other waits for a slot.
    expect(started, ['t0', 't1', 'open', 'f3']);
    repository.dispose();
  });

  test('background work keeps its limit and order', () async {
    final repository = make();
    final started = <String>[];
    for (var i = 0; i < 4; i++) {
      repository.acquire(
        _key('t$i'),
        load: (_) {
          started.add('t$i');
          return Completer<Uint8List>().future;
        },
        authorized: () => true,
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(started, ['t0', 't1']);
    repository.dispose();
  });
}
