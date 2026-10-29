// "Clear cache" (Settings > Storage) goes through one coordinator; this proves
// the coordinator's contract and that, wired the way the app wires it, it
// empties every layer of rebuildable data and nothing else: both disk
// namespaces, the decoded attachment pictures, signed URLs, video stills,
// avatar and framework image caches, idle staging folders. Files a preview has
// open, received shares (`raft-incoming`), the session and drafts survive.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/avatar_image_store.dart';
import 'package:raft_flutter/data/cache_clear.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/memory_release.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_image_cache_test.dart' show view, waitPreview, workspace;

class _Files extends AttachmentFiles {
  _Files(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) async => bytes;
}

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 64, 48),
    Paint()..color = const Color(0xff3366cc),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 48);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

AttachmentImageStoreKey _key(String entry) => AttachmentImageStoreKey(
  identity: AttachmentImageKey.identityOf('https://x.invalid', 'u', 's'),
  channelId: 'c',
  entry: entry,
);

void main() {
  group('CacheClear', () {
    test('runs hooks in registration order and reports each', () async {
      final clear = CacheClear();
      final order = <String>[];
      clear.register('disk', () => order.add('disk'));
      clear.register('memory', () async => order.add('memory'));
      expect(clear.names, ['disk', 'memory']);
      final result = await clear.run();
      expect(order, ['disk', 'memory']);
      expect(result.cleared, ['disk', 'memory']);
      expect(result.ok, isTrue);
    });

    test('a failing hook is reported and the others still run', () async {
      final clear = CacheClear();
      var after = false;
      clear.register('a', () => throw const FileSystemException('busy'));
      clear.register('b', () => after = true);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      final result = await clear.run();
      expect(after, isTrue);
      expect(result.ok, isFalse);
      expect(result.failed.keys, ['a']);
      expect(result.cleared, ['b']);
      expect(reported, hasLength(1));
    });

    test('a hook can be removed, and a run in progress is joined', () async {
      final clear = CacheClear();
      var runs = 0;
      final gate = Completer<void>();
      final remove = clear.register('slow', () async {
        runs++;
        await gate.future;
      });
      final first = clear.run(), second = clear.run();
      expect(identical(first, second), isTrue);
      gate.complete();
      await first;
      expect(runs, 1);
      remove();
      expect(clear.names, isEmpty);
      await clear.run();
      expect(runs, 1);
    });
  });

  group('wired as the app wires it', () {
    late Directory cacheRoot, temp;
    late AttachmentDiskCache cache;
    late Uint8List png;

    setUpAll(() async {
      png = (await TestWidgetsFlutterBinding.ensureInitialized().runAsync(
        _png,
      ))!;
    });
    setUp(() async {
      cacheRoot = await Directory.systemTemp.createTemp('raft-clear-cache');
      temp = await Directory.systemTemp.createTemp('raft-clear-temp');
      cache = AttachmentDiskCache(() async => cacheRoot);
    });
    tearDown(() async {
      await cacheRoot.delete(recursive: true);
      await temp.delete(recursive: true);
    });

    // Synchronous: the widget test zone does not run real file futures.
    File staged(String relative, {Duration age = const Duration(hours: 1)}) {
      final file = File('${temp.path}/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync('x')
        ..setLastModifiedSync(DateTime.now().subtract(age));
      // The sweep also looks at the folder's own time, which only touch sets.
      final t = DateTime.now().subtract(age);
      String two(int v) => v.toString().padLeft(2, '0');
      Process.runSync('touch', [
        '-t',
        '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}.${two(t.second)}',
        file.parent.path,
      ]);
      return file;
    }

    testWidgets('empties every layer and keeps what is in use or the user\'s', (
      tester,
    ) async {
      // Disk: both namespaces, plus a file an open preview holds.
      final session = File('${cacheRoot.path}/session.json')
        ..writeAsStringSync('keep');
      final draft = File('${temp.path}/drafts.json')..writeAsStringSync('keep');
      AttachmentCachedFile? open;
      await tester.runAsync(() async {
        await cache.write(_key('a'), Uint8List(1000));
        await cache.writePublic('https://x.invalid/a.webp', Uint8List(300));
        open = await cache.fetchFile(
          _key('open'),
          filename: 'open.pdf',
          download: (destination, cancel, progress) async =>
              destination.writeAsBytes(Uint8List(500)),
        );
      });
      addTearDown(() => open?.release());
      expect(await tester.runAsync(cache.sizeBytes), 1800);

      // Avatars: encoded bytes and decoded bitmaps in memory.
      RaftImageBytes.instance = RaftImageBytes();
      installAvatarImageCache(cache, memoryRelease: RaftMemoryRelease());
      RaftHotImages.instance.hold(
        'k',
        OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
        10,
      );
      expect(RaftHotImages.instance.length, 1);

      // Flutter's ImageCache.
      final images = PaintingBinding.instance.imageCache;
      final decoded = (await tester.runAsync(() => decodeImageFromList(png)))!;
      images.putIfAbsent(
        'photo',
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: decoded.clone())),
        ),
      );
      await tester.pump();
      expect(images.currentSize, 1);

      // Staging folders: idle ones go, a leased one, a fresh one (a transfer
      // running now) and received shares stay.
      final idlePreview = staged('staging/raft-previews/preview-1/a.pdf');
      final idleShare = staged('staging/raft-share/share-1/a.png');
      final idleExport = staged('raft-export-1/a.csv');
      final fresh = staged(
        'staging/raft-gallery-1/a.png',
        age: const Duration(seconds: 3),
      );
      final leased = staged('staging/raft-previews/preview-leased/b.pdf');
      final lease = SharedFileLease(leased, lifetime: const Duration(hours: 1));
      final incoming = staged('raft-incoming/received.bin');

      // The workspace's memory: decoded attachment picture (no widget shows
      // it any more), a signed URL, a video still.
      final (client, w) = workspace(null);
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      await tester.pumpWidget(view(w, _Files(png)));
      await waitPreview(tester);
      await tester.pumpWidget(const SizedBox());
      await w.attachmentMedia.debugUrls.resolve(
        'a',
        scope: 's',
        fetch: () async => {'url': 'https://storage.invalid/a?sig=1'},
      );
      w.attachmentMedia.playerSessions.keepStill('v', decoded);
      expect(w.attachmentMedia.retainedImageCount, 1);
      expect(w.attachmentMedia.debugUrls.length, 1);
      expect(w.attachmentMedia.playerSessions.stillCount, 1);

      final remove = CacheClear.instance.installAppLayers(
        cache: cache,
        stagingDirectory: () async => Directory('${temp.path}/staging'),
        legacyTemporary: () async => temp,
      );
      addTearDown(remove);
      final result = (await tester.runAsync(CacheClear.instance.run))!;
      expect(result.ok, isTrue);
      expect(
        result.cleared,
        containsAll(['disk', 'staging', 'image-cache', 'workspace-memory']),
      );

      // Disk: nothing but the open preview's file is left.
      expect(await tester.runAsync(cache.sizeBytes), 500);
      expect(
        await tester.runAsync(
          () => cache.sizeBytes(namespace: AttachmentCacheNamespace.public),
        ),
        0,
      );
      expect(open!.file.existsSync(), isTrue);
      // Memory layers.
      expect(RaftHotImages.instance.length, 0);
      expect(RaftImageBytes.instance.memoryEntries, 0);
      expect(images.currentSize, 0);
      expect(w.attachmentMedia.retainedImageCount, 0);
      expect(w.attachmentMedia.debugUrls.length, 0);
      expect(w.attachmentMedia.playerSessions.stillCount, 0);
      // Staging.
      expect(idlePreview.parent.existsSync(), isFalse);
      expect(idleShare.parent.existsSync(), isFalse);
      expect(idleExport.parent.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: 'a transfer may be running');
      expect(leased.existsSync(), isTrue, reason: 'a live lease');
      expect(incoming.existsSync(), isTrue, reason: 'received shares are data');
      // Everything that is not cache.
      expect(session.existsSync(), isTrue);
      expect(draft.existsSync(), isTrue);

      // The lease's owner finishing ends the hold; the folder goes with it.
      await tester.runAsync(lease.dispose);
      expect(leased.existsSync(), isFalse);
      decoded.dispose();
    });

    testWidgets('a picture a widget still shows stays decoded', (tester) async {
      final (client, w) = workspace(null);
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      await tester.pumpWidget(view(w, _Files(png)));
      await waitPreview(tester);
      expect(w.attachmentMedia.retainedImageCount, 1);
      final remove = CacheClear.instance.installAppLayers();
      addTearDown(remove);
      await tester.runAsync(CacheClear.instance.run);
      expect(w.attachmentMedia.retainedImageCount, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(CacheClear.instance.run);
      expect(w.attachmentMedia.retainedImageCount, 0);
    });
  });
}
