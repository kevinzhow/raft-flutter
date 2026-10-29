import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

class _MemoryStore implements RaftImageByteStore {
  final files = <String, Uint8List>{};
  var reads = 0;
  var throwOnRead = false;
  final etags = <String, String?>{};
  final touched = <String>[];
  @override
  Future<RaftStoredImage?> readEntry(String key) async {
    reads++;
    if (throwOnRead) throw StateError('disk gone');
    final bytes = files[key];
    return bytes == null
        ? null
        : RaftStoredImage(
            bytes,
            expires: DateTime(2100),
            etag: etags[key],
          );
  }

  @override
  Future<void> write(
    String key,
    Uint8List bytes, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) async {
    files[key] = bytes;
    etags[key] = etag;
  }

  @override
  Future<void> touch(
    String key, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) async => touched.add(key);
}

class _RecordingStore implements RaftImageByteStore {
  _RecordingStore(this.written);
  final Map<String, Duration?> written;
  @override
  Future<RaftStoredImage?> readEntry(String key) async => null;
  @override
  Future<void> write(
    String key,
    Uint8List bytes, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) async => written[key] = maxAge;
  @override
  Future<void> touch(
    String key, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) async {}
}

Uint8List _bytes(int n, [int fill = 7]) =>
    Uint8List.fromList(List.filled(n, fill));

void main() {
  group('raftStableImageKey', () {
    test('drops signing and expiry parameters, keeps content parameters', () {
      const a =
          'https://CDN.example.test/a/b.webp?v=3&X-Amz-Signature=aaa&X-Amz-Expires=60&s=80';
      const b =
          'https://cdn.example.test/a/b.webp?s=80&X-Amz-Expires=900&v=3&X-Amz-Signature=bbb#frag';
      expect(raftStableImageKey(a), raftStableImageKey(b));
      expect(
        raftStableImageKey(a),
        'https://cdn.example.test/a/b.webp?s=80&v=3',
      );
      expect(
        raftStableImageKey('https://x.test/a.webp?v=3'),
        isNot(raftStableImageKey('https://x.test/a.webp?v=4')),
      );
    });
    test('a plain URL and a relative reference are left alone', () {
      expect(
        raftStableImageKey('https://x.test/api/avatars/users/ab.webp'),
        'https://x.test/api/avatars/users/ab.webp',
      );
      expect(
        raftStableImageKey('/api/avatars/a.webp?sig=1'),
        '/api/avatars/a.webp?sig=1',
      );
    });
  });

  group('raftCacheControlMaxAge', () {
    test('reads the freshness the server grants', () {
      expect(
        raftCacheControlMaxAge('public, max-age=31536000, immutable'),
        const Duration(days: 365),
      );
      expect(raftCacheControlMaxAge('max-age=300'), const Duration(minutes: 5));
      expect(
        raftCacheControlMaxAge('public, immutable'),
        greaterThan(const Duration(days: 365)),
      );
      expect(
        raftCacheControlMaxAge('public, no-cache, must-revalidate'),
        Duration.zero,
      );
      expect(raftCacheControlMaxAge('no-store, max-age=60'), Duration.zero);
      expect(raftCacheControlMaxAge('max-age=0'), Duration.zero);
      expect(raftCacheControlMaxAge('public'), isNull);
      expect(raftCacheControlMaxAge(null), isNull);
    });
  });

  group('display-size buckets', () {
    test('exact common sizes stay exact, near sizes share a bucket', () {
      expect(raftBucketExtent(36), 36);
      expect(raftBucketExtent(72), 72);
      expect(raftBucketExtent(108), 108);
      expect(raftBucketExtent(60), 60);
      expect(raftBucketExtent(95), 96);
      expect(raftBucketExtent(90), 96);
      expect(raftBucketExtent(144), 144);
      expect(raftBucketExtent(145), 192);
    });
    test('36 dp at 2.5x and 2.625x are one provider, 3x is its own', () {
      final base = RaftAvatarImageProvider('https://x.test/a.webp');
      ImageProvider<Object> at(double dp, double dpr) => raftSizedImage(
        base,
        logicalWidth: dp,
        logicalHeight: dp,
        devicePixelRatio: dpr,
        avatar: true,
      );
      expect(at(36, 2.5), at(36, 2.625));
      expect(at(36, 2.625), isNot(at(36, 3)));
      // The same URL re-signed is the same provider too.
      expect(
        RaftAvatarImageProvider('https://x.test/a.webp?sig=1'),
        RaftAvatarImageProvider('https://x.test/a.webp?sig=2'),
      );
    });
  });

  group('RaftImageBytes', () {
    late int fetches;
    late Map<String, Object> answers;
    final maxAges = <String, Duration?>{};
    var clock = DateTime(2026, 10, 14);
    late RaftImageBytes service;
    late _MemoryStore store;

    setUp(() {
      fetches = 0;
      answers = {};
      clock = DateTime(2026, 10, 14);
      store = _MemoryStore();
      service = RaftImageBytes(
        store: store,
        now: () => clock,
        memoryBudgetBytes: 100,
        fetcher: (url) async {
          fetches++;
          final answer = answers[Uri.parse(url).path] ?? _bytes(10);
          if (answer is Uint8List) {
            return RaftFetchedImage(answer, maxAge: maxAges[url]);
          }
          throw answer;
        },
      );
    });

    test('concurrent loads of one stable key share a single request', () async {
      final loads = await Future.wait([
        service.load('https://x.test/a.webp?sig=1'),
        service.load('https://x.test/a.webp?sig=2'),
        service.load('https://x.test/a.webp?sig=3'),
      ]);
      expect(fetches, 1);
      expect(loads.map((b) => b.length), everyElement(10));
    });

    test('a second load is a synchronous memory hit', () async {
      await service.load('https://x.test/a.webp');
      expect(service.load('https://x.test/a.webp'), isA<SynchronousFuture>());
      expect(fetches, 1);
    });

    test('the store answers after memory is gone, with no request', () async {
      await service.load('https://x.test/a.webp');
      expect(store.files, hasLength(1));
      service.clearMemory();
      final again = await service.load('https://x.test/a.webp?sig=9');
      expect(again.length, 10);
      expect(fetches, 1);
    });

    test(
      'the server freshness reaches the store; no-cache is not stored',
      () async {
        maxAges['https://x.test/imm.webp'] = const Duration(days: 365);
        maxAges['https://x.test/nocache.webp'] = Duration.zero;
        final recorded = <String, Duration?>{};
        final recording = RaftImageBytes(
          store: _RecordingStore(recorded),
          fetcher: (url) async =>
              RaftFetchedImage(_bytes(4), maxAge: maxAges[url]),
        );
        await recording.load('https://x.test/imm.webp');
        await recording.load('https://x.test/nocache.webp');
        await recording.load('https://x.test/silent.webp');
        await Future<void>.delayed(Duration.zero);
        expect(
          recorded.keys,
          unorderedEquals([
            'https://x.test/imm.webp',
            'https://x.test/silent.webp',
          ]),
        );
        expect(recorded['https://x.test/imm.webp'], const Duration(days: 365));
        expect(recorded['https://x.test/silent.webp'], isNull);
      },
    );

    test('a failing store is a miss, not an error', () async {
      store.throwOnRead = true;
      expect((await service.load('https://x.test/a.webp')).length, 10);
      expect(fetches, 1);
    });

    test('a 404 is remembered for ten minutes, a 503 for one', () async {
      answers['/gone.webp'] = const RaftImageHttpError(404);
      answers['/busy.webp'] = const RaftImageHttpError(503);
      for (var i = 0; i < 3; i++) {
        await expectLater(
          service.load('https://x.test/gone.webp'),
          throwsA(isA<RaftImageHttpError>()),
        );
        await expectLater(
          service.load('https://x.test/busy.webp'),
          throwsA(isA<RaftImageHttpError>()),
        );
      }
      expect(fetches, 2);
      clock = clock.add(const Duration(minutes: 2));
      await expectLater(
        service.load('https://x.test/busy.webp'),
        throwsA(isA<RaftImageHttpError>()),
      );
      await expectLater(
        service.load('https://x.test/gone.webp'),
        throwsA(isA<RaftImageHttpError>()),
      );
      expect(fetches, 3, reason: 'only the 503 was asked again');
      clock = clock.add(const Duration(minutes: 10));
      answers.remove('/gone.webp');
      expect((await service.load('https://x.test/gone.webp')).length, 10);
      expect(fetches, 4);
    });

    test('memory is bounded; the oldest entries leave first', () async {
      for (var i = 0; i < 15; i++) {
        answers['/$i.webp'] = _bytes(10, i);
        await service.load('https://x.test/$i.webp');
      }
      expect(service.memoryBytes, lessThanOrEqualTo(100));
      expect(service.memoryEntries, 10);
      // The first ones were evicted from memory but are in the store.
      await service.load('https://x.test/0.webp');
      expect(fetches, 15);
    });
  });

  group('RaftHotImages', () {
    test('is bounded by entries and by estimated bytes', () {
      final hot = RaftHotImages(maxEntries: 3, maxBytes: 1000);
      final completers = [
        for (var i = 0; i < 6; i++)
          OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
      ];
      for (var i = 0; i < 4; i++) {
        hot.hold('k$i', completers[i], 100);
      }
      expect(hot.length, 3);
      expect(hot.holds('k0'), isFalse);
      hot.touch('k1');
      hot.hold('k4', completers[4], 100);
      expect(hot.holds('k1'), isTrue);
      expect(hot.holds('k2'), isFalse);
      hot.hold('k5', completers[5], 950);
      expect(hot.length, 1, reason: 'one big entry pushes the rest out');
      expect(hot.estimatedBytes, 950);
      hot.hold(
        'k6',
        OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
        10,
      );
      hot.trimTo(maxEntries: 1, maxBytes: 1 << 20);
      expect(hot.holds('k6'), isTrue, reason: 'most recent survives a trim');
      expect(hot.length, 1);
      hot.releaseAll();
      expect(hot.length, 0);
      expect(hot.estimatedBytes, 0);
    });
  });
}
