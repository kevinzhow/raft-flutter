import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/memory_release.dart';
import 'package:raft_ui/raft_ui.dart';

/// Hidden pages, idle caches, a backgrounded app and memory pressure all let
/// go of decoded images (owner report 2026-10-13: finished media stayed
/// resident for as long as a hidden page kept its card alive).

AttachmentImageScope scope() => const AttachmentImageScope(
  origin: 'https://example.invalid',
  principal: 'alice',
  server: 'server',
  generation: 1,
  role: 'member',
);
AttachmentImageKey key(String id) => AttachmentImageKey(
  scope: scope(),
  channelId: 'channel',
  attachmentId: id,
  revision: 'A',
);

class _Clock {
  Duration now = Duration.zero;
  Duration call() => now;
}

AttachmentImageRepository repository({
  Duration idleTtl = const Duration(minutes: 3),
  Duration Function()? clock,
}) =>
    AttachmentImageRepository(
      scope: scope(),
      retainedAuthority: (_) => true,
      idleTtl: idleTtl,
      clock: clock,
      decoder: (bytes, _) async => DecodedAttachmentImage(
        provider: MemoryImage(bytes),
        encodedBytes: bytes.length,
        decodedBytes: 4,
        release: () async {},
      ),
    );

Future<AttachmentImageLease> acquired(AttachmentImageRepository r, String id) async {
  final lease = r.acquire(
    key(id),
    authorized: () => true,
    load: (_) async => Uint8List(4),
  );
  await lease.ready;
  return lease;
}

class _CountingImageCache extends ImageCache {
  int clears = 0;
  @override
  void clear() {
    clears++;
    super.clear();
  }
}

class _RasterClient extends RaftClient {
  _RasterClient()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'url': 'https://storage.example.invalid/owned-public-fixture',
  };
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {'urls': []};
}

class _RasterFiles extends AttachmentFiles {
  int downloads = 0;
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) async {
    downloads++;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
    );
  }
}

void main() {
  group('AttachmentImageRepository', () {
    test('trimIdle drops decoded images no lease holds and keeps held ones', () async {
      final r = repository();
      addTearDown(r.dispose);
      final held = await acquired(r, 'held');
      final idle = await acquired(r, 'idle');
      idle.release();
      expect(r.entryCount, 2);
      expect(r.trimIdle(), 1);
      expect(r.entryCount, 1);
      expect(held.active, isTrue);
      expect(r.decodedByteCount, 4);
      held.release();
      expect(r.trimIdle(), 1);
      expect(r.entryCount, 0);
      expect(r.decodedByteCount, 0);
      expect(r.encodedByteCount, 0);
    });

    test('an image idle for the TTL goes on the next repository activity; a leased one never', () async {
      final clock = _Clock();
      final r = repository(idleTtl: const Duration(minutes: 3), clock: clock.call);
      addTearDown(r.dispose);
      final held = await acquired(r, 'held');
      final idle = await acquired(r, 'idle');
      idle.release();
      expect(r.entryCount, 2);
      clock.now = const Duration(minutes: 2, seconds: 59);
      (await acquired(r, 'busy')).release();
      expect(r.entryCount, 3, reason: 'inside the TTL');
      clock.now = const Duration(minutes: 3, seconds: 10);
      (await acquired(r, 'busy2')).release();
      expect(r.entryCount, 3, reason: 'idle and busy2 are idle; busy too new');
      expect(r.acquireReady(key('idle'), authorized: () => true), isNull);
      expect(held.active, isTrue);
      clock.now = const Duration(hours: 1);
      held.release();
      (await acquired(r, 'later')).release();
      // Everything else idle for over the TTL is gone; `held` was released
      // just now, `later` just now.
      expect(r.entryCount, 2);
    });

    test('taking the image again before a sweep keeps it, and restarts its idle clock', () async {
      final clock = _Clock();
      final r = repository(idleTtl: const Duration(minutes: 3), clock: clock.call);
      addTearDown(r.dispose);
      (await acquired(r, 'a')).release();
      clock.now = const Duration(minutes: 4);
      final again = r.acquireReady(key('a'), authorized: () => true)!;
      clock.now = const Duration(minutes: 30);
      (await acquired(r, 'x')).release();
      final probe = r.acquireReady(key('a'), authorized: () => true);
      expect(probe, isNotNull, reason: 'held the whole time');
      probe!.release();
      again.release();
      clock.now = const Duration(minutes: 32, seconds: 59);
      (await acquired(r, 'y')).release();
      expect(r.entryCount, 3, reason: 'a idle for 3 min is still inside');
      clock.now = const Duration(minutes: 34);
      (await acquired(r, 'z')).release();
      expect(r.acquireReady(key('a'), authorized: () => true), isNull);
    });

    test('the sweep is rate limited and never starts a timer', () async {
      final clock = _Clock();
      final r = repository(idleTtl: const Duration(seconds: 1), clock: clock.call);
      addTearDown(r.dispose);
      (await acquired(r, 'a')).release();
      clock.now = const Duration(seconds: 6);
      (await acquired(r, 'b')).release(); // sweeps: a is gone
      expect(r.entryCount, 1);
      clock.now = const Duration(seconds: 8);
      (await acquired(r, 'c')).release(); // under 5 s since the last sweep
      expect(r.entryCount, 2);
      clock.now = const Duration(seconds: 11);
      (await acquired(r, 'd')).release();
      expect(r.entryCount, 1, reason: 'b and c went, d is fresh');
    });
  });

  group('RaftMemoryRelease', () {
    testWidgets('hidden for the delay: flag set, image cache cleared, trimmers run; resume clears the flag', (tester) async {
      final cache = _CountingImageCache();
      final release = RaftMemoryRelease(
        backgroundDelay: const Duration(seconds: 30),
        imageCache: () => cache,
      )..install();
      addTearDown(release.uninstall);
      final reasons = <RaftMemoryTrim>[];
      release.addTrimmer(reasons.add);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 29));
      expect(release.backgrounded, isFalse);
      expect(reasons, isEmpty);
      // A quick app switch back costs nothing.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(minutes: 2));
      expect(release.backgrounded, isFalse);
      expect(reasons, isEmpty);
      expect(cache.clears, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 31));
      expect(release.backgrounded, isTrue);
      expect(reasons, [RaftMemoryTrim.backgrounded]);
      expect(cache.clears, 1);
      // Staying in the background does not trim again.
      await tester.pump(const Duration(minutes: 5));
      expect(reasons, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(release.backgrounded, isFalse);
    });

    testWidgets('memory pressure runs the trimmers; a failing one does not stop the rest', (tester) async {
      final release = RaftMemoryRelease()..install();
      addTearDown(release.uninstall);
      final reasons = <RaftMemoryTrim>[];
      release.addTrimmer((_) => throw StateError('boom'));
      final remove = release.addTrimmer(reasons.add);
      tester.binding.handleMemoryPressure();
      expect(reasons, [RaftMemoryTrim.pressure]);
      expect(tester.takeException(), isStateError);
      remove();
      tester.binding.handleMemoryPressure();
      expect(reasons, hasLength(1));
      expect(tester.takeException(), isStateError);
    });
  });

  group('AttachmentView', () {
    const metadata = {
      'id': 'file',
      'filename': 'fixture.png',
      'mimeType': 'image/png',
      'width': 16,
      'height': 16,
    };
    late _RasterClient client;
    late WorkspaceController w;
    late _RasterFiles files;
    final tickers = ValueNotifier<bool>(true);

    setUp(() {
      client = _RasterClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      w.channels = [w.channel!];
      w.messageDomain.ledger.switchServer('server');
      w.messageDomain.ledger.ingest([
        {
          'id': 'host',
          'channelId': 'channel',
          'seq': '1',
          'content': 'public diagnostic',
          'attachments': [metadata],
        },
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['channel'] = {'host'};
      files = _RasterFiles();
      tickers.value = true;
      RaftMemoryRelease.instance.install();
    });
    tearDown(RaftMemoryRelease.instance.uninstall);
    // The repository's idle-sweep timer must not outlive the test body.
    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
      await tester.pump();
    }

    Widget app() => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: tickers,
          builder: (_, enabled, _) => TickerMode(
            enabled: enabled,
            child: AttachmentView(
              controller: w,
              files: files,
              messageId: 'host',
              metadata: metadata,
            ),
          ),
        ),
      ),
    );

    Future<void> waitImage(WidgetTester tester) async {
      for (var i = 0; i < 30 && find.byType(Image).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.byType(Image), findsOneWidget);
    }

    RaftAttachmentCard card(WidgetTester tester) =>
        tester.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard));

    testWidgets('a row on a hidden route lets go of its image after the delay, so a trim can free it', (tester) async {
      await tester.pumpWidget(app());
      await waitImage(tester);
      expect(w.attachmentMedia.retainedImageCount, 1);
      final provider = tester.widget<Image>(find.byType(Image)).image;

      tickers.value = false;
      await tester.pump();
      // Not at once: flipping back and forth must not thrash.
      await tester.pump(const Duration(seconds: 4));
      expect(card(tester).preview, isNotNull);
      await tester.pump(const Duration(seconds: 2));
      expect(card(tester).preview, isNull, reason: 'stream listener released');
      // The decoded image is still retained for a quick return ...
      expect(w.attachmentMedia.retainedImageCount, 1);
      // ... until a trim: the row no longer pins it.
      RaftMemoryRelease.instance.trim(RaftMemoryTrim.pressure);
      expect(w.attachmentMedia.retainedImageCount, 0);
      expect(w.attachmentMedia.retainedImageDecodedBytes, 0);

      // Coming back decodes again (from the network here; the byte store in
      // the product) and shows the image.
      final before = files.downloads;
      tickers.value = true;
      await tester.pump();
      await waitImage(tester);
      expect(files.downloads, before + 1);
      expect(tester.widget<Image>(find.byType(Image)).image, isNot(same(provider)));
      await finish(tester);
    });

    testWidgets('a quick return paints the retained image in the first frame', (tester) async {
      await tester.pumpWidget(app());
      await waitImage(tester);
      final provider = tester.widget<Image>(find.byType(Image)).image;
      final downloads = files.downloads;
      tickers.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(card(tester).preview, isNull);
      tickers.value = true;
      await tester.pump();
      expect(find.byType(Image), findsOneWidget, reason: 'first frame');
      expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
      expect(files.downloads, downloads);
      await finish(tester);
    });

    testWidgets('a hidden spell shorter than the delay keeps the image untouched', (tester) async {
      await tester.pumpWidget(app());
      await waitImage(tester);
      tickers.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      tickers.value = true;
      await tester.pump(const Duration(seconds: 10));
      expect(card(tester).preview, isNotNull);
      await finish(tester);
    });

    testWidgets('a visible row keeps its image while the app is in the background; the idle ones go', (tester) async {
      await tester.pumpWidget(app());
      await waitImage(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(minutes: 2));
      expect(RaftMemoryRelease.instance.backgrounded, isTrue);
      // The row still shows its image and the repository still retains it.
      expect(find.byType(Image), findsOneWidget);
      expect(w.attachmentMedia.retainedImageCount, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      await finish(tester);
    });

    testWidgets('after the row is gone, the background trim frees its image', (tester) async {
      await tester.pumpWidget(app());
      await waitImage(tester);
      await tester.pumpWidget(const SizedBox());
      expect(w.attachmentMedia.retainedImageCount, 1, reason: 'kept for a quick revisit');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 31));
      expect(w.attachmentMedia.retainedImageCount, 0);
      expect(w.attachmentMedia.retainedImageDecodedBytes, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await finish(tester);
    });
  });
}
