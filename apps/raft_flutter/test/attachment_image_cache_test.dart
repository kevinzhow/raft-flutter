import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  int resolutions = 0;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    resolutions++;
    return {'url': 'https://storage.example.invalid/owned-public-fixture'};
  }
}

class _Files extends AttachmentFiles {
  _Files(this.bytes);
  final Uint8List bytes;
  int downloads = 0;
  @override
  Future<Uint8List> image(String url, {required CancelToken cancel}) async {
    downloads++;
    return bytes;
  }
}

class _CountingStore implements AttachmentImageByteStore {
  _CountingStore(this.inner);
  final AttachmentImageByteStore inner;
  int reads = 0;
  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) {
    reads++;
    return inner.read(key);
  }

  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) =>
      inner.write(key, bytes);
  @override
  Future<void> remove(AttachmentImageStoreKey key) => inner.remove(key);
  @override
  Future<void> purgeChannel(String identity, String channelId) =>
      inner.purgeChannel(identity, channelId);
  @override
  Future<void> purgeIdentity(String identity) => inner.purgeIdentity(identity);
}

/// A real 4000x3000 PNG (a camera-sized original).
Future<Uint8List> largePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 4000, 3000),
    Paint()..color = const Color(0xff3366cc),
  );
  canvas.drawCircle(const Offset(2000, 1500), 900, Paint());
  final image = await recorder.endRecording().toImage(4000, 3000);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<(int, int)> resolvedSize(ImageProvider provider) {
  final done = Completer<(int, int)>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener((info, _) {
    done.complete((info.image.width, info.image.height));
    info.dispose();
    stream.removeListener(listener);
  });
  stream.addListener(listener);
  return done.future;
}

const metadata = <String, dynamic>{
  'id': 'photo',
  'filename': 'photo.png',
  'mimeType': 'image/png',
  'width': 4000,
  'height': 3000,
};

(_Client, WorkspaceController) workspace(AttachmentImageByteStore? store) {
  final client = _Client()..user = RaftRecord({'id': 'alice'});
  client.selectServer('server');
  final w = WorkspaceController(client, attachmentImageStore: store)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channel = RaftChannel({'id': 'channel', 'joined': true});
  w.channels = [w.channel!];
  w.ledger.switchServer('server');
  w.ledger.ingest([
    {
      'id': 'host',
      'channelId': 'channel',
      'seq': '1',
      'content': 'photo',
      'attachments': [metadata],
    },
  ], expectedGeneration: w.ledger.generation);
  w.visibleIds['channel'] = {'host'};
  return (client, w);
}

Widget view(WorkspaceController w, AttachmentFiles files) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: AttachmentView(
        controller: w,
        files: files,
        messageId: 'host',
        metadata: metadata,
      ),
    ),
  ),
);

RaftAttachmentCard card(WidgetTester tester) =>
    tester.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard));

Future<int> waitPreview(WidgetTester tester) async {
  var frames = 0;
  for (; frames < 200 && card(tester).preview == null; frames++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(card(tester).preview, isNotNull);
  return frames;
}

void main() {
  late Uint8List original;
  setUpAll(() async {
    original = (await TestWidgetsFlutterBinding.ensureInitialized().runAsync(
      largePng,
    ))!;
  });

  testWidgets('a large original decodes at its display size, not 4000x3000', (
    tester,
  ) async {
    final result = await tester.runAsync(() async {
      // Before: the list decoded the original at its intrinsic size.
      final full = await decodeAttachmentImage(original);
      // After: a ~300px box at 3x decodes a bitmap bounded by that box.
      final box = AttachmentDecodeTarget.box(300, 225, devicePixelRatio: 3);
      final bounded = await decodeAttachmentImage(original, target: box);
      final sizes = (
        await resolvedSize(full.provider),
        await resolvedSize(bounded.provider),
      );
      final bytes = (full.decodedBytes, bounded.decodedBytes);
      final retained = (full.encodedBytes, bounded.encodedBytes);
      await full.dispose();
      await bounded.dispose();
      return (sizes, bytes, retained);
    });
    final ((fullSize, boundedSize), (fullBytes, boundedBytes), retained) =
        result!;
    expect(fullSize, (4000, 3000));
    expect(fullBytes, 48000000);
    expect(boundedSize.$1, lessThanOrEqualTo(300 * 3 + 64));
    expect(boundedSize.$2, lessThanOrEqualTo(225 * 3 + 64));
    expect(boundedSize.$1 / boundedSize.$2, closeTo(4 / 3, .01));
    expect(boundedBytes, boundedSize.$1 * boundedSize.$2 * 4);
    expect(boundedBytes, lessThan(fullBytes ~/ 15));
    // Still images keep only the bitmap, never the encoded original.
    expect(retained, (0, 0));
  });

  testWidgets(
    'list row decodes at the reserved box; lightbox loads the full original',
    (tester) async {
      final (client, w) = workspace(null);
      final files = _Files(original);
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      await tester.pumpWidget(view(w, files));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(card(tester).previewPending, isTrue);
      final reserved = tester.getRect(find.byType(RaftAttachmentCard));
      expect(reserved.size, const Size(384, 288));
      await waitPreview(tester);
      expect(tester.getRect(find.byType(RaftAttachmentCard)), reserved);
      final listProvider = tester.widget<Image>(find.byType(Image)).image;
      final listSize = (await tester.runAsync(
        () => resolvedSize(listProvider),
      ))!;
      // 384x288 logical at the test view's 3x.
      expect(listSize, (1152, 864));
      expect(w.retainedImageDecodedBytes, 1152 * 864 * 4);
      expect(w.retainedImageEncodedBytes, 0);

      await tester.tap(find.byTooltip('Preview photo.png'));
      await tester.pump();
      final lightbox = find.byKey(const ValueKey('attachment-image-photo'));
      expect(lightbox, findsOneWidget);
      for (
        var i = 0;
        i < 200 &&
            identical(tester.widget<Image>(lightbox).image, listProvider);
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      final fullProvider = tester.widget<Image>(lightbox).image;
      expect(fullProvider, isNot(same(listProvider)));
      expect(await tester.runAsync(() => resolvedSize(fullProvider)), (
        4000,
        3000,
      ));
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      // Closing the lightbox frees the full bitmap; the preview stays.
      expect(w.retainedImageDecodedBytes, 1152 * 864 * 4);
      expect(w.retainedImageCount, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'restart serves the persisted image with zero network; revoked authority does not read it',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('raft-image-cache'),
      ))!;
      addTearDown(() => directory.delete(recursive: true));
      Future<Directory> root() async => directory;

      // First launch: cold network load, persisted after a good decode.
      final (firstClient, first) = workspace(AttachmentImageDiskCache(root));
      final firstFiles = _Files(original);
      await tester.pumpWidget(view(first, firstFiles));
      await waitPreview(tester);
      expect(firstFiles.downloads, 1);
      expect(firstClient.resolutions, 1);
      await tester.pumpWidget(const SizedBox());
      // The store's file work runs in the widget zone: pump while waiting.
      var stored = 0;
      for (var i = 0; i < 100 && stored == 0; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        stored = (await tester.runAsync(
          () => directory
              .list(recursive: true)
              .where((e) => e is File && !e.path.endsWith('.part'))
              .length,
        ))!;
      }
      expect(stored, 1);
      first.dispose();
      await firstClient.dispose();

      // Second launch: new process-level store, controller and client.
      final store = _CountingStore(AttachmentImageDiskCache(root));
      final (client, w) = workspace(store);
      final files = _Files(original);
      await tester.pumpWidget(view(w, files));
      final reserved = tester.getRect(find.byType(RaftAttachmentCard));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final frames = await waitPreview(tester);
      expect(tester.getRect(find.byType(RaftAttachmentCard)), reserved);
      expect(files.downloads, 0);
      expect(client.resolutions, 0);
      expect(store.reads, 1);
      expect(frames, lessThan(50));
      // Served from disk: shown directly, without the cold-load fade.
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(
        (await tester.runAsync(
          () => resolvedSize(tester.widget<Image>(find.byType(Image)).image),
        ))!,
        (1152, 864),
      );
      await tester.pumpWidget(const SizedBox());

      // The member can no longer view the channel: nothing is read or shown.
      w.channels = [];
      w.channel = null;
      w.notifyListeners();
      await tester.pumpWidget(view(w, files));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(card(tester).preview, isNull);
      expect(store.reads, 1);
      expect(files.downloads, 0);
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );

  test('repository never reads persisted bytes without authority; revocation purges them', () async {
    final directory = await Directory.systemTemp.createTemp('raft-image-cache');
    addTearDown(() => directory.delete(recursive: true));
    final disk = AttachmentImageDiskCache(() async => directory);
    final store = _CountingStore(disk);
    const scope = AttachmentImageScope(
      origin: 'https://example.invalid',
      principal: 'alice',
      server: 'server',
      generation: 1,
      role: 'member',
    );
    const key = AttachmentImageKey(
      scope: scope,
      channelId: 'channel',
      attachmentId: 'photo',
      revision: 'A',
    );
    await disk.write(key.storeKey, Uint8List.fromList([1, 2, 3]));
    var allowed = false;
    final repository = AttachmentImageRepository(
      scope: scope,
      retainedAuthority: (_) => allowed,
      store: store,
      decoder: (bytes, _) async => DecodedAttachmentImage(
        provider: MemoryImage(bytes),
        encodedBytes: 0,
        decodedBytes: 4,
        release: () async {},
      ),
    );
    addTearDown(repository.dispose);
    var loads = 0;
    expect(
      () => repository.acquire(
        key,
        authorized: () => true,
        load: (_) async {
          loads++;
          return Uint8List(0);
        },
      ),
      throwsA(isA<StaleAttachmentImage>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.reads, 0);
    expect(loads, 0);

    allowed = true;
    final lease = repository.acquire(
      key,
      authorized: () => true,
      load: (_) async {
        loads++;
        return Uint8List(0);
      },
    );
    await lease.ready;
    expect(lease.fromStore, isTrue);
    expect((store.reads, loads), (1, 0));
    lease.release();

    repository.invalidateChannel('channel');
    for (var i = 0; i < 50 && await disk.read(key.storeKey) != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await disk.read(key.storeKey), isNull);
  });

  test(
    'disk cache stays within its byte bound, evicting oldest first',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'raft-image-cache',
      );
      addTearDown(() => directory.delete(recursive: true));
      final disk = AttachmentImageDiskCache(
        () async => directory,
        maxBytes: 3000,
      );
      AttachmentImageStoreKey entry(int i) => AttachmentImageStoreKey(
        identity: 'identity',
        channelId: 'channel',
        entry: 'entry-$i',
      );
      for (var i = 0; i < 5; i++) {
        await disk.write(entry(i), Uint8List(1000));
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(await disk.read(entry(0)), isNull);
      expect(await disk.read(entry(4)), isNotNull);
      var total = 0;
      await for (final file in directory.list(recursive: true)) {
        if (file is File) total += await file.length();
      }
      expect(total, lessThanOrEqualTo(3000));
    },
  );
}
