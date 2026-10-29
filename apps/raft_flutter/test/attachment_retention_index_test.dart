import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_sync/raft_sync.dart';

const _metadata = {
  'id': 'image',
  'filename': 'fixture.png',
  'mimeType': 'image/png',
  'width': 16,
  'height': 16,
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => [];
  @override
  Future<void> dispose() async {
    await bus.close();
    await super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    client.user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
    w.channels = [w.channel!];
    w.messageDomain.ledger.switchServer('server');
    ingest(_metadata, '1');
    imageKey = AttachmentImageKey.fromMetadata(
      scope: w.attachmentImageScope,
      channelId: 'channel',
      metadata: _metadata,
    );
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
  }
  final client = _Client();
  late final WorkspaceController w;
  late final AttachmentImageKey imageKey;
  int loads = 0;
  void ingest(Map<String, dynamic> metadata, String seq) =>
      w.messageDomain.ledger.ingest([
        {
          'id': 'host',
          'channelId': 'channel',
          'seq': seq,
          'content': 'fixture',
          'attachments': [metadata],
        },
      ], expectedGeneration: w.messageDomain.ledger.generation);

  Future<Object> retain() async {
    final lease = w.attachmentMedia.acquireImage(
      imageKey,
      authorized: () => true,
      load: (_) async {
        ++loads;
        return base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
        );
      },
    );
    final provider = await lease.lease.ready;
    lease.release();
    expect(w.attachmentMedia.retainedImageCount, 1);
    return provider;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'page notifications retain the image without rescanning message history',
    () async {
      final f = _Fixture();
      final image = await f.retain();
      final firstBuilds = f.w.attachmentRetentionIndex.debugBuilds;
      for (var i = 0; i < 20; i++) {
        f.w.section = i.isEven ? 'settings' : 'chat';
        f.w.notifyListeners();
        final ready = f.w.attachmentMedia.peekImage(
          f.imageKey,
          authorized: () => true,
        );
        expect(ready, isNotNull);
        expect(ready!.lease.value, same(image));
        ready.release();
      }
      expect(f.loads, 1);
      expect(f.w.attachmentRetentionIndex.debugBuilds, firstBuilds);
    },
  );

  test(
    'replacing channel records with the same admission retains the index',
    () async {
      final f = _Fixture();
      await f.retain();
      final firstBuilds = f.w.attachmentRetentionIndex.debugBuilds;
      f.w.channels = [
        RaftChannel({'id': 'channel', 'name': 'renamed', 'joined': true}),
      ];
      f.w.notifyListeners();
      expect(f.w.attachmentMedia.retainedImageCount, 1);
      expect(f.w.attachmentRetentionIndex.debugBuilds, firstBuilds);
    },
  );

  test(
    'same-length in-place channel replacement drops the retired image',
    () async {
      final f = _Fixture();
      await f.retain();
      f.w.channels[0] = RaftChannel({'id': 'other', 'joined': true});
      f.w.notifyListeners();
      expect(f.w.attachmentMedia.retainedImageCount, 0);
      expect(
        f.w.attachmentMedia.peekImage(f.imageKey, authorized: () => true),
        isNull,
      );
    },
  );

  test(
    'accepted same-ID metadata replacement drops the previous rendition',
    () async {
      final f = _Fixture();
      await f.retain();
      final builds = f.w.attachmentRetentionIndex.debugBuilds;
      f.ingest({..._metadata, 'contentVersion': 'next'}, '2');
      f.w.notifyListeners();
      expect(f.w.attachmentRetentionIndex.debugBuilds, builds);
      expect(f.w.attachmentMedia.retainedImageCount, 0);
      expect(
        f.w.attachmentMedia.peekImage(f.imageKey, authorized: () => true),
        isNull,
      );
    },
  );

  test(
    'ledger updates recheck admission before another notification',
    () async {
      final f = _Fixture();
      await f.retain();
      f.w.channels[0] = RaftChannel({'id': 'other', 'joined': true});
      f.ingest({..._metadata, 'width': 32}, '2');
      // A ledger read can precede its owner's next notification. Its revision
      // must refresh admission as well as the cached attachment metadata.
      expect(
        f.w.attachmentMedia.peekImage(f.imageKey, authorized: () => true),
        isNull,
      );
      expect(f.w.attachmentMedia.retainedImageCount, 0);
    },
  );

  test(
    'a real channel removal event clears the retained image immediately',
    () async {
      final f = _Fixture();
      await f.retain();
      f.client.bus.add(
        const RaftEvent('channel:removed', {'channelId': 'channel'}),
      );
      expect(f.w.attachmentMedia.retainedImageCount, 0);
      expect(
        f.w.attachmentMedia.peekImage(f.imageKey, authorized: () => true),
        isNull,
      );
    },
  );

  test(
    'role and principal changes cannot retain a previous scope image',
    () async {
      for (final changeRole in [true, false]) {
        final f = _Fixture();
        await f.retain();
        if (changeRole) {
          f.w.server = RaftRecord({'id': 'server', 'role': 'guest'});
        } else {
          f.client.user = RaftRecord({'id': 'bob'});
        }
        f.w.notifyListeners();
        expect(f.w.attachmentMedia.retainedImageCount, 0);
        expect(
          f.w.attachmentMedia.peekImage(f.imageKey, authorized: () => true),
          isNull,
        );
      }
    },
  );

  test(
    'plain arrivals keep the retained image without a complete history scan',
    () async {
      final f = _Fixture();
      final image = await f.retain();
      final builds = f.w.attachmentRetentionIndex.debugBuilds;
      for (var i = 0; i < 20; i++) {
        f.w.messageDomain.ledger.ingest([
          {
            'id': 'plain-$i',
            'channelId': 'channel',
            'seq': '${i + 2}',
            'content': 'An ordinary message without attachments.',
          },
        ], expectedGeneration: f.w.messageDomain.ledger.generation);
        f.w.notifyListeners();
        final lease = f.w.attachmentMedia.peekImage(
          f.imageKey,
          authorized: () => true,
        );
        expect(lease, isNotNull);
        expect(lease!.lease.value, same(image));
        lease.release();
      }
      expect(f.loads, 1);
      expect(
        f.w.attachmentRetentionIndex.debugBuilds,
        builds,
        reason: 'no attachment or admission changed in these arrivals',
      );
    },
  );

  test(
    'a new message retains its own attachment without a history scan',
    () async {
      final f = _Fixture();
      await f.retain();
      final builds = f.w.attachmentRetentionIndex.debugBuilds;
      final extra = {..._metadata, 'id': 'extra'};
      f.w.messageDomain.ledger.ingest([
        {
          'id': 'other',
          'channelId': 'channel',
          'seq': '2',
          'attachments': [extra],
        },
      ], expectedGeneration: f.w.messageDomain.ledger.generation);
      final key = AttachmentImageKey.fromMetadata(
        scope: f.w.attachmentImageScope,
        channelId: 'channel',
        metadata: extra,
      );
      final lease = f.w.attachmentMedia.acquireImage(
        key,
        authorized: () => true,
        load: (_) async {
          ++f.loads;
          return base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
          );
        },
      );
      await lease.lease.ready;
      lease.release();
      final ready = f.w.attachmentMedia.peekImage(key, authorized: () => true);
      expect(ready, isNotNull);
      ready!.release();
      expect(f.loads, 2);
      expect(f.w.attachmentRetentionIndex.debugBuilds, builds);
      final kept = f.w.attachmentMedia.peekImage(
        f.imageKey,
        authorized: () => true,
      );
      expect(kept, isNotNull);
      kept!.release();
    },
  );

  test(
    'one plain message stays within a millisecond after long history',
    () async {
      for (final history in [100, 2000]) {
        final f = _Fixture();
        final image = await f.retain();
        final builds = f.w.attachmentRetentionIndex.debugBuilds;
        for (var i = 0; i < history; i++) {
          f.w.messageDomain.ledger.ingest([
            {
              'id': 'bulk-$i',
              'channelId': 'channel',
              'seq': '${i + 2}',
              'content': 'bulk',
            },
          ], expectedGeneration: f.w.messageDomain.ledger.generation);
          if ((i + 1) % MessageLedger.incrementalChangeLimit == 0) {
            final drained = f.w.attachmentMedia.peekImage(
              f.imageKey,
              authorized: () => true,
            );
            expect(drained, isNotNull);
            drained!.release();
          }
        }
        final caughtUp = f.w.attachmentMedia.peekImage(
          f.imageKey,
          authorized: () => true,
        );
        expect(caughtUp, isNotNull);
        expect(caughtUp!.lease.value, same(image));
        caughtUp.release();
        expect(f.w.attachmentRetentionIndex.debugBuilds, builds);
        final micros = <int>[];
        for (var i = 0; i < 21; i++) {
          final watch = Stopwatch()..start();
          f.w.messageDomain.ledger.ingest([
            {
              'id': 'timed-$history-$i',
              'channelId': 'channel',
              'seq': '${history + i + 3}',
              'content': 'timed',
            },
          ], expectedGeneration: f.w.messageDomain.ledger.generation);
          final lease = f.w.attachmentMedia.peekImage(
            f.imageKey,
            authorized: () => true,
          );
          watch.stop();
          expect(lease, isNotNull);
          expect(lease!.lease.value, same(image));
          lease.release();
          micros.add(watch.elapsedMicroseconds);
        }
        micros.sort();
        final median = micros[micros.length ~/ 2];
        expect(f.loads, 1);
        expect(f.w.attachmentRetentionIndex.debugBuilds, builds);
        expect(
          median,
          lessThan(1000),
          reason:
              'plain message after $history took ${median}us '
              '(min ${micros.first}us, max ${micros.last}us)',
        );
      }
    },
  );

  test('an unread change window still retains images by rebuilding', () async {
    final f = _Fixture();
    final image = await f.retain();
    final builds = f.w.attachmentRetentionIndex.debugBuilds;
    final limit = MessageLedger.incrementalChangeLimit;
    for (var i = 0; i < limit; i++) {
      f.w.messageDomain.ledger.ingest([
        {
          'id': 'unread-$i',
          'channelId': 'channel',
          'seq': '${i + 2}',
          'content': 'unread',
        },
      ], expectedGeneration: f.w.messageDomain.ledger.generation);
    }
    final extra = {..._metadata, 'id': 'extra'};
    f.w.messageDomain.ledger.ingest([
      {
        'id': 'extra-host',
        'channelId': 'channel',
        'seq': '${limit + 2}',
        'attachments': [extra],
      },
    ], expectedGeneration: f.w.messageDomain.ledger.generation);
    expect(f.w.messageDomain.ledger.debugChangeCount, lessThanOrEqualTo(limit));
    final kept = f.w.attachmentMedia.peekImage(
      f.imageKey,
      authorized: () => true,
    );
    expect(kept, isNotNull);
    expect(kept!.lease.value, same(image));
    kept.release();
    expect(f.w.attachmentRetentionIndex.debugBuilds, builds + 1);
    final key = AttachmentImageKey.fromMetadata(
      scope: f.w.attachmentImageScope,
      channelId: 'channel',
      metadata: extra,
    );
    final lease = f.w.attachmentMedia.acquireImage(
      key,
      authorized: () => true,
      load: (_) async {
        ++f.loads;
        return base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
        );
      },
    );
    await lease.lease.ready;
    lease.release();
    final ready = f.w.attachmentMedia.peekImage(key, authorized: () => true);
    expect(ready, isNotNull);
    ready!.release();
    expect(f.loads, 2);
    expect(f.w.attachmentRetentionIndex.debugBuilds, builds + 1);
  });

  test(
    'removing the host message drops its image without a history scan',
    () async {
      final f = _Fixture();
      await f.retain();
      final builds = f.w.attachmentRetentionIndex.debugBuilds;
      f.w.messageDomain.ledger.remove('channel', 'host');
      f.w.notifyListeners();
      expect(
        f.w.attachmentMedia.peekImage(f.imageKey, authorized: () => true),
        isNull,
      );
      expect(f.w.attachmentMedia.retainedImageCount, 0);
      expect(f.w.attachmentRetentionIndex.debugBuilds, builds);
    },
  );
}
