import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart'
    show ImageConfiguration, ImageInfo, OneFrameImageStreamCompleter;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/data/attachment_disk_cache.dart';
import 'package:raft_flutter/data/avatar_image_store.dart';
import 'package:raft_flutter/platform/memory_release.dart';
import 'package:raft_ui/raft_ui.dart';

Uint8List _bytes(int n, [int fill = 1]) =>
    Uint8List.fromList(List.filled(n, fill));

void main() {
  late Directory root;
  var clock = DateTime(2026, 10, 14);

  setUp(() async {
    HttpOverrides.global = null;
    root = await Directory.systemTemp.createTemp('raft-avatars-test');
    clock = DateTime(2026, 10, 14);
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  AttachmentDiskCache cacheOf({int maxBytes = 1 << 30}) =>
      AttachmentDiskCache(() async => root, maxBytes: maxBytes);
  AvatarImageStore store(AttachmentDiskCache cache) =>
      AvatarImageStore(cache, now: () => clock);

  group('AvatarImageStore in the public namespace of the shared cache', () {
    test('round-trips bytes by stable key, also in a new instance', () async {
      await store(cacheOf()).write(
        'https://x.test/a.webp',
        _bytes(20, 9),
        maxAge: const Duration(days: 365),
      );
      expect(
        await store(cacheOf()).read('https://x.test/a.webp'),
        _bytes(20, 9),
      );
      expect(await store(cacheOf()).read('https://x.test/other.webp'), isNull);
    });

    test(
      'is counted in the size Settings shows and removed by Clear',
      () async {
        final cache = cacheOf();
        final s = store(cache);
        expect(await cache.sizeBytes(), 0);
        await s.write('k1', _bytes(100), maxAge: const Duration(days: 1));
        await s.write('k2', _bytes(50), maxAge: const Duration(days: 1));
        expect(await cache.sizeBytes(), 100 + 16 + 50 + 16);
        expect(await cache.entryCount(), 2);
        await cache.clear();
        expect(await cache.sizeBytes(), 0);
        expect(await s.read('k1'), isNull);
        expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
      },
    );

    test('an entry is fresh for the granted time, capped at the TTL', () async {
      final s = store(cacheOf());
      await s.write('k', _bytes(5), maxAge: const Duration(days: 365));
      await s.write('short', _bytes(5), maxAge: const Duration(minutes: 5));
      await s.write('silent', _bytes(5));
      clock = clock.add(const Duration(minutes: 6));
      expect(await s.read('short'), isNull, reason: 'max-age=300 ran out');
      expect(await s.read('silent'), isNotNull, reason: 'unknown: one hour');
      clock = clock.add(const Duration(hours: 1));
      expect(await s.read('silent'), isNull);
      clock = clock.add(const Duration(days: 12));
      expect(await s.read('k'), isNotNull);
      clock = clock.add(const Duration(days: 2));
      expect(await s.read('k'), isNull, reason: 'capped at 14 days');
    });

    test('an expired entry is removed from the cache', () async {
      final cache = cacheOf();
      final s = store(cache);
      await s.write('k', _bytes(5), maxAge: const Duration(minutes: 1));
      clock = clock.add(const Duration(minutes: 2));
      expect(await s.read('k'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await cache.entryCount(), 0);
    });

    test('no-cache / no-store answers are not kept at all', () async {
      final cache = cacheOf();
      await store(cache).write('k', _bytes(5), maxAge: Duration.zero);
      expect(await cache.entryCount(), 0);
    });

    test('sign-out purges the account but leaves the avatars', () async {
      final cache = cacheOf();
      await store(cache).write('k', _bytes(5), maxAge: const Duration(days: 1));
      await cache.purgeAccount('https://x.invalid', 'alice');
      expect(await store(cache).read('k'), isNotNull);
    });

    test('an unusable cache directory is a miss, never an error', () async {
      final cache = AttachmentDiskCache(
        () async => throw const FileSystemException(),
      );
      final s = store(cache);
      expect(await s.read('k'), isNull);
      await s.write('k', _bytes(3), maxAge: const Duration(days: 1));
    });
  });

  group('Clear cache in Settings > Storage', () {
    test(
      'forgets the in-memory avatars: the next load fetches exactly once',
      () async {
        final cache = cacheOf();
        var fetches = 0;
        RaftImageBytes.instance = RaftImageBytes();
        installAvatarImageCache(cache, memoryRelease: RaftMemoryRelease());
        RaftImageBytes.instance.fetcher = (_) async {
          fetches++;
          return RaftFetchedImage(
            _bytes(30),
            maxAge: const Duration(days: 365),
          );
        };
        final url =
            'http://127.0.0.1:1/api/avatars/users/ab.webp?X-Amz-Signature=1';
        await RaftImageBytes.instance.load(url);
        // The disk write is fire and forget: wait for it, not for a time.
        await RaftImageBytes.instance.settled();
        // Still cached in every layer: no new request.
        await RaftImageBytes.instance.load(url);
        expect(fetches, 1);
        final hot = RaftHotImages.instance;
        hot.hold(
          'k',
          OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
          10,
        );

        await cache.clear();

        expect(hot.length, 0);
        expect(RaftImageBytes.instance.memoryEntries, 0);
        await RaftImageBytes.instance.load(url);
        await RaftImageBytes.instance.load(url);
        expect(fetches, 2, reason: 'one refetch, then served again');
        await RaftImageBytes.instance.settled();
        expect(await cache.entryCount(), 1);
      },
    );
  });

  group('fetchAvatarImage', () {
    test(
      'follows the shared proxy decision and sends no credentials',
      () async {
        final seen = <String>[];
        final headers = <String>[];
        final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        proxy.listen((request) {
          seen.add(request.uri.toString());
          headers.addAll(
            request.headers.value('authorization') == null ? [] : ['auth'],
          );
          headers.addAll(
            request.headers.value('cookie') == null ? [] : ['cookie'],
          );
          request.response
            ..persistentConnection = false
            ..headers.set(
              'cache-control',
              'public, max-age=31536000, immutable',
            )
            ..add(_bytes(8))
            ..close();
        });
        final service = SystemProxy()
          ..configure(
            ProxySettings(
              mode: ProxyMode.manual,
              host: '127.0.0.1',
              port: proxy.port,
            ),
          );
        final bytes = await fetchAvatarImage(
          'http://avatars.invalid/api/avatars/users/ab.webp?X-Amz-Signature=s',
          proxy: service,
        );
        expect(bytes.bytes, _bytes(8));
        expect(bytes.maxAge, const Duration(days: 365));
        expect(seen.single, startsWith('http://avatars.invalid/api/avatars/'));
        expect(
          seen.single,
          contains('X-Amz-Signature=s'),
          reason: 'fetched as given',
        );
        expect(headers, isEmpty);
        await proxy.close(force: true);
      },
    );

    test('a non-200 answer is a typed error', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((r) {
        r.response
          ..statusCode = 404
          ..persistentConnection = false
          ..close();
      });
      final service = SystemProxy()
        ..configure(const ProxySettings(mode: ProxyMode.direct));
      await expectLater(
        fetchAvatarImage(
          'http://127.0.0.1:${server.port}/x.webp',
          proxy: service,
        ),
        throwsA(
          isA<RaftImageHttpError>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      await server.close(force: true);
    });
  });

  group('conditional revalidation against a loopback server', () {
    late _AvatarServer server;
    late SystemProxy direct;
    late AttachmentDiskCache cache;

    setUp(() async {
      server = await _AvatarServer.start();
      direct = SystemProxy()
        ..configure(const ProxySettings(mode: ProxyMode.direct));
      cache = cacheOf();
      RaftHotImages.instance.releaseAll();
    });
    tearDown(() async {
      await server.close();
      RaftHotImages.instance.releaseAll();
    });

    // One "process": its own memory, over the shared disk cache.
    RaftImageBytes process() => RaftImageBytes(
      fetcher: (url) => fetchAvatarImage(url, proxy: direct),
      revalidator: (url, {etag, lastModified}) => fetchAvatarImage(
        url,
        proxy: direct,
        etag: etag,
        lastModified: lastModified,
      ),
      store: store(cache),
      now: () => clock,
    );

    // The key the display holds a decoded 36 dp avatar under.
    Future<Object> hotKey(String url) => RaftSizedImageProvider(
      RaftAvatarImageProvider(url),
      width: 36,
      height: 36,
    ).obtainKey(ImageConfiguration.empty);

    // A first run of the app: the picture is downloaded and its disk entry is
    // written (waited for, not slept for) before the "restart" under test.
    Future<void> seed(String url) async {
      final first = process();
      await first.load(url);
      await first.settled();
    }

    test('a no-cache answer is stored with its ETag, not refetched', () async {
      final first = process();
      final url = server.url('/api/external-avatars/a.webp');
      expect(await first.load(url), _bytes(40, 1));
      await first.settled();
      expect(server.requests, hasLength(1));
      expect(server.requests.single.ifNoneMatch, isNull);

      final entry = await store(cache).readEntry(raftStableImageKey(url));
      expect(entry, isNotNull);
      expect(entry!.etag, '"v1"');
      expect(entry.bytes, _bytes(40, 1));
      expect(entry.expires.isAfter(clock), isFalse, reason: 'no-cache: stale');

      // Same process, many more uses: memory answers, nothing is sent.
      for (var i = 0; i < 20; i++) {
        await first.load(url);
      }
      await first.settled();
      expect(server.requests, hasLength(1));
    });

    test(
      'a fresh immutable entry is served from disk with 0 requests',
      () async {
        final url = server.url('/api/avatars/users/ab.webp');
        await seed(url);
        expect(server.requests, hasLength(1));
        clock = clock.add(const Duration(days: 2));
        final restarted = process();
        expect(await restarted.load(url), _bytes(40, 1));
        await restarted.settled();
        expect(server.requests, hasLength(1), reason: 'max-age=1 year');
        expect(restarted.revalidationCount, 0);
      },
    );

    test('stale after a restart: stored bytes at once, one 304, no body '
        'transfer, decoded copy untouched', () async {
      final url = server.url('/api/external-avatars/a.webp');
      final key = raftStableImageKey(url);
      await seed(url);
      server.requests.clear();
      server.bodyBytesSent = 0;

      final restarted = process();
      final hot = RaftHotImages.instance;
      final held = await hotKey(url);
      hot.hold(
        held,
        OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
        10,
      );
      final shown = await restarted.load(url);
      expect(shown, _bytes(40, 1), reason: 'shown before any answer');
      await restarted.settled();

      expect(server.requests, hasLength(1));
      expect(server.requests.single.ifNoneMatch, '"v1"');
      expect(server.requests.single.status, 304);
      expect(server.bodyBytesSent, 0, reason: 'a 304 carries no body');
      expect(restarted.revalidationCount, 1);
      expect(restarted.revisionOf(key), 0);
      expect(hot.holds(held), isTrue);
      expect(await restarted.load(url), shown);
      expect(identical(await restarted.load(url), shown), isTrue);
      // Still one entry on disk, same bytes.
      await restarted.settled();
      expect(await cache.entryCount(), 1);
      expect((await store(cache).readEntry(key))!.bytes, _bytes(40, 1));
    });

    test('Clear cache forgets the validators too: the next use is a plain '
        'first fetch, not a conditional request with the old ETag', () async {
      final url = server.url('/api/external-avatars/a.webp');
      await seed(url);
      final live = RaftImageBytes.instance;
      addTearDown(() => RaftImageBytes.instance = live);
      final p = RaftImageBytes.instance = process();
      final remove = cache.addPublicClearListener(clearAvatarImages);
      addTearDown(remove);
      expect(await p.load(url), _bytes(40, 1));
      await p.settled();
      expect(p.memoryEntries, 1);
      expect(await cache.entryCount(), 1);
      server.requests.clear();
      final revalidated = p.revalidationCount;

      await cache.clear();

      expect(p.memoryEntries, 0);
      expect(await cache.entryCount(), 0);
      expect(await p.load(url), _bytes(40, 1));
      await p.settled();
      expect(server.requests, hasLength(1));
      expect(server.requests.single.ifNoneMatch, isNull);
      expect(server.requests.single.status, 200);
      expect(p.revalidationCount, revalidated);
      expect(
        await cache.entryCount(),
        1,
        reason: 'stored again, with its ETag',
      );
      expect(
        (await store(cache).readEntry(raftStableImageKey(url)))!.etag,
        '"v1"',
      );
    });

    test('a changed ETag replaces the picture and tells the screen', () async {
      final url = server.url('/api/external-avatars/a.webp');
      final key = raftStableImageKey(url);
      await seed(url);
      server
        ..etag = '"v2"'
        ..body = _bytes(55, 2);
      server.requests.clear();
      server.bodyBytesSent = 0;

      final restarted = process();
      final changed = <String>[];
      restarted.addChangeListener(changed.add);
      final hot = RaftHotImages.instance;
      hot.hold(
        await hotKey(url),
        OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
        10,
      );
      expect(await restarted.load(url), _bytes(40, 1), reason: 'stale first');
      await restarted.settled();
      expect(server.requests.single.ifNoneMatch, '"v1"');
      expect(server.requests.single.status, 200);
      expect(server.bodyBytesSent, 55);
      expect(changed, [key]);
      expect(restarted.revisionOf(key), 1);
      expect(await restarted.load(url), _bytes(55, 2));
      expect(hot.length, 0, reason: 'old decoded copy released');
      await restarted.settled();
      final stored = await store(cache).readEntry(key);
      expect(stored!.etag, '"v2"');
      expect(stored.bytes, _bytes(55, 2));
      // The next process gets the new picture from disk and revalidates with v2.
      server.requests.clear();
      final third = process();
      expect(await third.load(url), _bytes(55, 2));
      await third.settled();
      expect(server.requests.single.ifNoneMatch, '"v2"');
      expect(server.requests.single.status, 304);
    });

    test('a new ETag over identical bytes is not a change', () async {
      final url = server.url('/api/external-avatars/a.webp');
      final key = raftStableImageKey(url);
      await seed(url);
      server.etag = '"v2"';
      final restarted = process();
      final changed = <String>[];
      restarted.addChangeListener(changed.add);
      await restarted.load(url);
      await restarted.settled();
      expect(server.requests.last.status, 200);
      expect(changed, isEmpty);
      expect(restarted.revisionOf(key), 0);
      await restarted.settled();
      expect((await store(cache).readEntry(key))!.etag, '"v2"');
    });

    test('a network error or an error answer keeps the stored bytes', () async {
      final url = server.url('/api/external-avatars/a.webp');
      final key = raftStableImageKey(url);
      await seed(url);

      server.failWith = 503;
      final failing = process();
      expect(await failing.load(url), _bytes(40, 1));
      await failing.settled();
      expect(await failing.load(url), _bytes(40, 1));
      expect((await store(cache).readEntry(key))!.bytes, _bytes(40, 1));

      // Connection refused: the server is gone.
      await server.close();
      clock = clock.add(const Duration(minutes: 11));
      final offline = process();
      expect(await offline.load(url), _bytes(40, 1));
      await offline.settled();
      expect(offline.revalidationCount, 1);
      expect(
        await offline.load(url),
        _bytes(40, 1),
        reason: 'no failure memory for an entry that is shown',
      );
      expect((await store(cache).readEntry(key))!.bytes, _bytes(40, 1));
    });

    test('revalidation is rate limited per key and process', () async {
      final a = server.url('/api/external-avatars/a.webp');
      final b = server.url('/api/external-avatars/b.webp');
      await seed(a);
      await seed(b);
      server.requests.clear();

      final restarted = process();
      for (var i = 0; i < 30; i++) {
        await restarted.load('$a?sig=$i');
        await restarted.load(b);
      }
      await restarted.settled();
      expect(
        server.requests.map((r) => r.path),
        unorderedEquals([
          '/api/external-avatars/a.webp?sig=0',
          '/api/external-avatars/b.webp',
        ]),
        reason: 'one conditional request per key, not per row',
      );

      clock = clock.add(const Duration(minutes: 9));
      await restarted.load(a);
      await restarted.settled();
      expect(server.requests, hasLength(2), reason: 'still inside 10 minutes');

      clock = clock.add(const Duration(minutes: 2));
      await restarted.load(a);
      await restarted.load(a);
      await restarted.settled();
      expect(
        server.requests,
        hasLength(3),
        reason: 'one more after 10 minutes',
      );
    });

    test('a 304 renews the freshness of a max-age entry', () async {
      server
        ..cacheControl = 'public, max-age=300'
        ..lastModified = 'Tue, 13 Oct 2026 10:00:00 GMT';
      final url = server.url('/x/g.webp');
      final key = raftStableImageKey(url);
      await seed(url);
      clock = clock.add(const Duration(minutes: 6));
      expect(await store(cache).read(key), isNull, reason: 'expired');

      final restarted = process();
      expect(await restarted.load(url), _bytes(40, 1));
      await restarted.settled();
      expect(server.requests.last.status, 304);
      expect(server.requests.last.ifModifiedSince, server.lastModified);
      expect(server.requests.last.ifNoneMatch, '"v1"');
      expect(await store(cache).read(key), _bytes(40, 1), reason: 'renewed');
      server.requests.clear();
      clock = clock.add(const Duration(minutes: 4));
      final again = process();
      await again.load(url);
      await again.settled();
      expect(server.requests, isEmpty, reason: 'fresh for 5 minutes again');
    });

    test('requests carry no credentials and go through the proxy-aware '
        'client', () async {
      await seed(server.url('/api/external-avatars/a.webp'));
      expect(server.requests.single.credentials, isFalse);

      final proxied = <String>[];
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      proxy.listen((request) {
        proxied.add('${request.method} ${request.uri}');
        request.response
          ..statusCode = 304
          ..headers.set('etag', '"p"')
          ..headers.set('cache-control', 'public, no-cache')
          ..close();
      });
      final service = SystemProxy()
        ..configure(
          ProxySettings(
            mode: ProxyMode.manual,
            host: '127.0.0.1',
            port: proxy.port,
          ),
        );
      final answer = await fetchAvatarImage(
        'http://avatars.invalid/api/external-avatars/z.webp',
        proxy: service,
        etag: '"p"',
      );
      expect(answer.notModified, isTrue);
      expect(answer.etag, '"p"');
      expect(proxied.single, contains('avatars.invalid'));
      await proxy.close(force: true);
    });

    test('a failing revalidation never escapes as an uncaught error', () async {
      final url = server.url('/api/external-avatars/a.webp');
      await seed(url);
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        // Error answers, a store that throws, a client that throws at once,
        // then a refused connection; each stale process shows the stored
        // bytes and every failure is swallowed where it happens.
        for (final status in [503, 404, 500, 429]) {
          server.failWith = status;
          clock = clock.add(const Duration(minutes: 11));
          final p = process();
          expect(await p.load(url), _bytes(40, 1));
          await p.settled();
          expect(p.revalidationCount, 1);
        }
        final throwing = RaftImageBytes(
          store: store(cache),
          now: () => clock,
          fetcher: (_) => throw StateError('no network'),
          revalidator: (_, {etag, lastModified}) =>
              throw StateError('no network'),
        );
        clock = clock.add(const Duration(minutes: 11));
        expect(await throwing.load(url), _bytes(40, 1));
        await throwing.settled();
        expect(throwing.revalidationCount, 1);

        // A disk that fails on write and on touch: the 200 and the 304 are
        // still handled, nothing escapes.
        RaftImageBytes onBrokenDisk() => RaftImageBytes(
          store: _ThrowingStore(store(cache)),
          fetcher: (u) => fetchAvatarImage(u, proxy: direct),
          revalidator: (u, {etag, lastModified}) => fetchAvatarImage(
            u,
            proxy: direct,
            etag: etag,
            lastModified: lastModified,
          ),
          now: () => clock,
        );
        server
          ..failWith = null
          ..etag = '"v9"'
          ..body = _bytes(12, 9);
        clock = clock.add(const Duration(minutes: 11));
        final changed = onBrokenDisk();
        expect(await changed.load(url), _bytes(40, 1));
        await changed.settled();
        expect(await changed.load(url), _bytes(12, 9));
        server
          ..etag = '"v1"'
          ..body = _bytes(40, 1);
        clock = clock.add(const Duration(minutes: 11));
        final unchanged = onBrokenDisk();
        expect(await unchanged.load(url), _bytes(40, 1));
        await unchanged.settled();
        expect(server.requests.last.status, 304);

        await server.close();
        clock = clock.add(const Duration(minutes: 11));
        final offline = process();
        expect(await offline.load(url), _bytes(40, 1));
        await offline.settled();
        // Let any stray error reach the zone.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }, (error, stack) => uncaught.add(error));
      expect(uncaught, isEmpty);
    });

    test('entries from before validators existed still read', () async {
      final legacy = Uint8List(8 + 5);
      ByteData.sublistView(
        legacy,
        0,
        8,
      ).setInt64(0, clock.add(const Duration(days: 1)).millisecondsSinceEpoch);
      legacy.setRange(8, 13, _bytes(5, 3));
      await cache.writePublic('legacy', legacy);
      expect(await store(cache).read('legacy'), _bytes(5, 3));
      final entry = await store(cache).readEntry('legacy');
      expect(entry!.etag, isNull);
      clock = clock.add(const Duration(days: 2));
      expect(await store(cache).readEntry('legacy'), isNull);
    });

    test('stale entries without a validator are a miss; with one they '
        'are kept for the retention', () async {
      final s = store(cache);
      await s.write('plain', _bytes(5), maxAge: const Duration(minutes: 1));
      await s.write('tagged', _bytes(5), maxAge: Duration.zero, etag: '"t"');
      await s.write('nostore', _bytes(5), maxAge: Duration.zero);
      expect(await cache.entryCount(), 2, reason: 'zero + no validator: none');
      clock = clock.add(const Duration(days: 3));
      expect(await s.readEntry('plain'), isNull);
      expect((await s.readEntry('tagged'))!.etag, '"t"');
      clock = clock.add(const Duration(days: 31));
      expect(await s.readEntry('tagged'), isNull);
    });
  });

  group('memory trim', () {
    test(
      'pressure keeps a small floor of avatars, a background trim keeps all',
      () async {
        final hot = RaftHotImages.instance;
        for (var i = 0; i < 70; i++) {
          hot.hold(
            'k$i',
            OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
            100,
          );
        }
        RaftImageBytes.instance = RaftImageBytes(
          fetcher: (_) async =>
              RaftFetchedImage(Uint8List(600 * 1024), maxAge: Duration.zero),
        );
        await RaftImageBytes.instance.load('https://x.test/a.webp');
        await RaftImageBytes.instance.load('https://x.test/b.webp');
        final release = RaftMemoryRelease();
        installAvatarImageCache(cacheOf(), memoryRelease: release);
        release.trim(RaftMemoryTrim.backgrounded);
        expect(hot.length, 70);
        expect(RaftImageBytes.instance.memoryEntries, 2);
        release.trim(RaftMemoryTrim.pressure);
        expect(hot.length, 64, reason: 'the 64 most recent stay');
        expect(hot.holds('k69'), isTrue);
        expect(hot.holds('k0'), isFalse);
        expect(RaftImageBytes.instance.memoryEntries, 1);
        expect(RaftImageBytes.instance.memoryBytes, lessThanOrEqualTo(1 << 20));
      },
    );
  });
}

class _Seen {
  _Seen(this.path, this.ifNoneMatch, this.ifModifiedSince, this.credentials);
  final String path;
  final String? ifNoneMatch, ifModifiedSince;
  final bool credentials;
  int status = 0;
}

/// A loopback server that behaves like the Raft avatar routes: an `ETag`, a
/// `Cache-Control` per route, `304` for a matching `If-None-Match` /
/// `If-Modified-Since`, and a count of every request and body byte.
class _AvatarServer {
  _AvatarServer(this._server) {
    _server.listen(_handle);
  }
  final HttpServer _server;
  final requests = <_Seen>[];
  var bodyBytesSent = 0;
  var etag = '"v1"';
  Uint8List body = _bytes(40, 1);
  String? cacheControl, lastModified;
  int? failWith;

  static Future<_AvatarServer> start() async =>
      _AvatarServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  String url(String path) => 'http://127.0.0.1:${_server.port}$path';

  Future<void> close() => _server.close(force: true);

  void _handle(HttpRequest request) {
    final seen = _Seen(
      request.uri.toString(),
      request.headers.value('if-none-match'),
      request.headers.value('if-modified-since'),
      request.headers.value('authorization') != null ||
          request.headers.value('cookie') != null,
    );
    requests.add(seen);
    final response = request.response..persistentConnection = false;
    final immutable = request.uri.path.startsWith('/api/avatars/');
    if (failWith != null) {
      seen.status = failWith!;
      response
        ..statusCode = failWith!
        ..close();
      return;
    }
    response.headers
      ..set(
        'cache-control',
        cacheControl ??
            (immutable
                ? 'public, max-age=31536000, immutable'
                : 'public, no-cache, must-revalidate'),
      )
      ..set('etag', etag);
    if (lastModified != null) {
      response.headers.set('last-modified', lastModified!);
    }
    final matches =
        seen.ifNoneMatch == etag ||
        (seen.ifNoneMatch == null &&
            lastModified != null &&
            seen.ifModifiedSince == lastModified);
    if (matches) {
      seen.status = 304;
      response
        ..statusCode = 304
        ..close();
      return;
    }
    seen.status = 200;
    bodyBytesSent += body.length;
    response
      ..headers.contentType = ContentType('image', 'webp')
      ..add(body)
      ..close();
  }
}

/// A disk that reads but fails every write and touch.
class _ThrowingStore implements RaftImageByteStore {
  _ThrowingStore(this._inner);
  final RaftImageByteStore _inner;
  @override
  Future<RaftStoredImage?> readEntry(String key) => _inner.readEntry(key);
  @override
  Future<void> write(
    String key,
    Uint8List bytes, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) => throw const FileSystemException('disk full');
  @override
  Future<void> touch(
    String key, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) => Future<void>.error(const FileSystemException('disk full'));
}
