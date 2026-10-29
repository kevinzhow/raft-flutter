// The on-disk video cache as the app uses it: one folder and one proxy per
// account, started lazily, switched off by one constant, emptied on sign-out.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/video_cache.dart';

import 'support/fake_range_upstream.dart';

void main() {
  late FakeUpstream upstream;
  late Directory root;
  final alice = VideoCacheAccount('https://raft.example/', 'alice');
  final bob = VideoCacheAccount('https://raft.example', 'bob');
  final aliceElsewhere = VideoCacheAccount('https://other.example', 'alice');

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    upstream = FakeUpstream();
    await upstream.start();
    upstream.sizes['/v.mp4'] = 5000;
    root = await Directory.systemTemp.createTemp('vc-accounts');
    VideoCache.debugRoot = root;
    VideoCache.debugEnabled = true;
    VideoCache.debugClientFactory = HttpClient.new;
  });

  tearDown(() async {
    await VideoCache.debugReset();
    VideoCache.debugRoot = null;
    VideoCache.debugEnabled = null;
    VideoCache.debugMaxBytes = null;
    VideoCache.debugClientFactory = null;
    await upstream.stop();
    await root.delete(recursive: true);
  });

  AttachmentSource sourceOf(
    VideoCacheAccount? account, {
    String id = 'att-1',
    String sig = '1',
  }) => AttachmentSource.network(
    upstream.url('/v.mp4?sig=$sig'),
    cacheKey: id,
    cacheAccount: account,
  );

  Future<Uri> routed(
    VideoCacheAccount? account, {
    String id = 'att-1',
    String sig = '1',
  }) async =>
      (await VideoCache.route(sourceOf(account, id: id, sig: sig))).url!;

  Future<void> play(Uri url) async {
    final answer = await fetch(url);
    expect(answer.status, 200);
    expect(answer.body, FakeUpstream.bytes(0, 4999));
    // Chunks are written after they were served.
    for (final account in [alice, bob, aliceElsewhere]) {
      final running = VideoCache.debugRunning(account);
      if (running != null) await (await running).flushWrites();
    }
  }

  group('account', () {
    test('a trailing slash on the origin is not part of the account', () {
      expect(alice.origin, 'https://raft.example');
      expect(
        alice.segment,
        VideoCacheAccount('https://raft.example', 'alice').segment,
      );
      expect(alice, VideoCacheAccount('https://raft.example', 'alice'));
    });

    test('the folder name tells neither the server nor the user', () {
      expect(alice.segment, hasLength(40));
      expect(alice.segment, isNot(contains('alice')));
      expect(alice.segment, isNot(contains('raft')));
    });

    test('user and origin both make the account', () {
      expect({
        alice.segment,
        bob.segment,
        aliceElsewhere.segment,
      }, hasLength(3));
    });
  });

  group('routing', () {
    test('the cache starts nothing until a video is played', () async {
      expect(VideoCache.debugStarted, 0);
      expect(await VideoCache.sizeBytes(alice), 0);
      expect(VideoCache.debugStarted, 0);
      expect(root.listSync(), isEmpty);
      await routed(alice);
      expect(VideoCache.debugStarted, 1);
      await routed(alice, id: 'att-2');
      expect(VideoCache.debugStarted, 1, reason: 'one proxy per account');
    });

    test('a slow start never holds up the open: the network plays, the next video is cached', () async {
      final gate = Completer<void>();
      VideoCache.debugStartGate = gate.future;
      final source = sourceOf(alice);
      final watch = Stopwatch()..start();
      final first = await VideoCache.route(source);
      expect(
        identical(first, source),
        isTrue,
        reason: 'this video plays from the network',
      );
      expect(
        watch.elapsed,
        lessThan(kVideoCacheStartBudget + const Duration(milliseconds: 600)),
      );
      expect(VideoCache.debugStarted, 0);
      // The start finishes in the background: the next video goes through it.
      gate.complete();
      final next = await VideoCache.route(sourceOf(alice, id: 'att-2'));
      expect(next.url!.host, '127.0.0.1');
      expect(VideoCache.debugStarted, 1);
    });

    test('a start that fails after the open gave up raises nothing', () async {
      final gate = Completer<void>();
      VideoCache.debugStartGate = gate.future;
      await VideoCache.route(sourceOf(alice));
      gate.completeError(StateError('late failure'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // The failed start is forgotten: the next video tries again.
      VideoCache.debugStartGate = null;
      final next = await VideoCache.route(sourceOf(alice, id: 'att-2'));
      expect(next.url!.host, '127.0.0.1');
    });

    test('a source without an account, or a file, is not touched', () async {
      final streamed = sourceOf(null);
      expect(identical(await VideoCache.route(streamed), streamed), isTrue);
      final file = AttachmentSource.file(File('${root.path}/x.mp4'));
      expect(identical(await VideoCache.route(file), file), isTrue);
      expect(VideoCache.debugStarted, 0);
    });

    test('the kill switch hands the player the real URL', () async {
      VideoCache.debugEnabled = false;
      final source = sourceOf(alice);
      expect(identical(await VideoCache.route(source), source), isTrue);
      expect(VideoCache.debugStarted, 0);
      expect(root.listSync(), isEmpty);
    });

    test(
      'a streamed attachment gets a loopback URL without its signature',
      () async {
        final url = await routed(alice);
        expect(url.scheme, 'http');
        expect(url.host, '127.0.0.1');
        expect(url.toString(), isNot(contains('sig=')));
        expect(url.path, endsWith('.mp4'));
      },
    );

    test('a start position carries over', () async {
      final source = AttachmentSource.network(
        upstream.url('/v.mp4'),
        cacheKey: 'att-1',
        cacheAccount: alice,
        start: const Duration(seconds: 7),
      );
      expect(
        (await VideoCache.route(source)).start,
        const Duration(seconds: 7),
      );
    });

    test('a signature renewed keeps the cache', () async {
      await play(await routed(alice));
      final sent = upstream.bytesSent;
      final again = await routed(alice, sig: '2');
      await play(again);
      expect(upstream.bytesSent, sent);
    });

    test('resigned keeps the place in the cache', () {
      final source = sourceOf(alice);
      final next = source.resigned(
        upstream.url('/v.mp4?sig=2'),
        start: const Duration(seconds: 3),
      );
      expect(next.cacheKey, 'att-1');
      expect(next.cacheAccount, alice);
      expect(next.start, const Duration(seconds: 3));
    });

    test('a cache that cannot start falls back to the real URL', () async {
      // The root is a file: no account folder can be made. The proxy copes
      // (it only stops storing), so the video still plays through it.
      root.deleteSync(recursive: true);
      File(root.path).writeAsStringSync('in the way');
      final url = await routed(alice);
      expect(url.host, '127.0.0.1');
      final answer = await fetch(url);
      expect(answer.status, 200);
      expect(answer.body, FakeUpstream.bytes(0, 4999));
      File(root.path).deleteSync();
      root.createSync();
    });
  });

  group('accounts do not mix', () {
    test('the same attachment id of two users is cached twice', () async {
      await play(await routed(alice));
      final afterAlice = upstream.bytesSent;
      expect(afterAlice, greaterThanOrEqualTo(5000));
      // Bob asks for "the same" video under the same id: his cache is empty,
      // the bytes come from upstream again.
      await play(await routed(bob));
      expect(upstream.bytesSent, greaterThanOrEqualTo(afterAlice + 5000));
      // Both are warm now.
      final warm = upstream.bytesSent;
      await play(await routed(alice));
      await play(await routed(bob));
      expect(upstream.bytesSent, warm);
    });

    test('the same user on another server has a cache of its own', () async {
      await play(await routed(alice));
      final sent = upstream.bytesSent;
      await play(await routed(aliceElsewhere));
      expect(upstream.bytesSent, greaterThan(sent));
    });

    test('every account has its own folder, proxy and token', () async {
      final a = await routed(alice);
      final b = await routed(bob);
      await play(a);
      await play(b);
      expect(a.port, isNot(b.port));
      expect(a.pathSegments.first, isNot(b.pathSegments.first));
      final folders = root.listSync().map((e) => p.basename(e.path)).toSet();
      expect(folders, {alice.segment, bob.segment});
      // One account's token means nothing to another account's proxy.
      final crossed = a.replace(port: b.port);
      expect((await fetch(crossed)).status, 404);
      final other = b.replace(port: a.port);
      expect((await fetch(other)).status, 404);
    });

    test('an account sees only its own bytes on disk', () async {
      await play(await routed(alice));
      expect(await VideoCache.sizeBytes(alice), 5000);
      expect(await VideoCache.sizeBytes(bob), 0);
    });
  });

  group('sign-out and switching', () {
    test('purging an account deletes its folder and nothing else', () async {
      await play(await routed(alice));
      await play(await routed(bob));
      final aliceFolder = Directory(p.join(root.path, alice.segment));
      expect(aliceFolder.existsSync(), isTrue);

      await VideoCache.purgeAccount('https://raft.example', 'alice');

      expect(aliceFolder.existsSync(), isFalse);
      expect(Directory(p.join(root.path, bob.segment)).existsSync(), isTrue);
      expect(await VideoCache.sizeBytes(alice), 0);
      // Bob's cache still serves without upstream.
      final sent = upstream.bytesSent;
      await play(await routed(bob));
      expect(upstream.bytesSent, sent);
    });

    test('a signed-out account\'s loopback URL stops answering', () async {
      final url = await routed(alice);
      await play(url);
      await VideoCache.purgeAccount('https://raft.example', 'alice');
      // The proxy is gone: nothing listens there any more.
      await expectLater(fetch(url), throwsA(isA<SocketException>()));
    });

    test('signing in again starts from an empty cache', () async {
      await play(await routed(alice));
      await VideoCache.purgeAccount('https://raft.example/', 'alice');
      final sent = upstream.bytesSent;
      await play(await routed(alice));
      expect(upstream.bytesSent, greaterThan(sent));
      expect(await VideoCache.sizeBytes(alice), 5000);
    });

    test('purging an account that never played anything is fine', () async {
      await VideoCache.purgeAccount('https://raft.example', 'nobody');
      expect(VideoCache.debugStarted, 0);
    });

    test('purging works when the proxy is not running (a folder from an earlier run)', () async {
      await play(await routed(alice));
      await VideoCache.debugReset();
      expect(Directory(p.join(root.path, alice.segment)).existsSync(), isTrue);
      expect(await VideoCache.sizeBytes(alice), 5000);
      await VideoCache.purgeAccount('https://raft.example', 'alice');
      expect(Directory(p.join(root.path, alice.segment)).existsSync(), isFalse);
      expect(VideoCache.debugStarted, 0);
    });

    test('clear empties one account and leaves it working', () async {
      await play(await routed(alice));
      await play(await routed(bob));
      await VideoCache.clear(alice);
      expect(await VideoCache.sizeBytes(alice), 0);
      expect(await VideoCache.sizeBytes(bob), 5000);
      final sent = upstream.bytesSent;
      await play(await routed(alice));
      expect(upstream.bytesSent, greaterThan(sent));
      expect(await VideoCache.sizeBytes(alice), 5000);
    });

    test('clear without a running proxy deletes the folder', () async {
      await play(await routed(alice));
      await VideoCache.debugReset();
      await VideoCache.clear(alice);
      expect(await VideoCache.sizeBytes(alice), 0);
      expect(VideoCache.debugStarted, 0);
    });

    test('orphans: folders of accounts with no saved session go', () async {
      await play(await routed(alice));
      await play(await routed(bob));
      await VideoCache.debugReset();
      final removed = await VideoCache.removeOrphanAccounts([
        ('https://raft.example/', 'bob'),
      ]);
      expect(removed, 1);
      expect(root.listSync().map((e) => p.basename(e.path)), [bob.segment]);
      expect(
        VideoCache.debugStarted,
        0,
        reason: 'housekeeping starts no proxy',
      );
    });

    test('orphans: nothing to do without a cache folder', () async {
      root.deleteSync(recursive: true);
      expect(await VideoCache.removeOrphanAccounts(const []), 0);
      root.createSync();
    });
  });

  group('the disk fails', () {
    test('a full disk never fails playback', () async {
      // A cap too small for anything is not a failure, but a folder that
      // cannot be written is: make the account folder a file.
      File(p.join(root.path, alice.segment)).writeAsStringSync('in the way');
      final url = await routed(alice);
      final answer = await fetch(url);
      expect(answer.status, 200);
      expect(answer.body, FakeUpstream.bytes(0, 4999));
      final again = await fetch(url);
      expect(again.body, FakeUpstream.bytes(0, 4999));
    });
  });
}
