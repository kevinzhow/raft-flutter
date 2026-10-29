import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/features/attachment_image_zoom.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  int urlReads = 0;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    urlReads++;
    return {'url': 'https://storage.example.invalid/image'};
  }

  // The batch route is not served here: tiles fall back to the single route.
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {'urls': []};
}

class _Files extends AttachmentFiles {
  final bytes = Completer<Uint8List>();
  int reads = 0;
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) {
    reads++;
    return bytes.future;
  }
}

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

/// Stands in for the persistent store the app installs at startup.
class _MemoryStore implements AttachmentImageByteStore {
  final entries = <String, Uint8List>{};
  String _id(AttachmentImageStoreKey key) =>
      '${key.identity}|${key.channelId}|${key.entry}';
  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async =>
      entries[_id(key)];
  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async =>
      entries[_id(key)] = bytes;
  @override
  Future<void> remove(AttachmentImageStoreKey key) async =>
      entries.remove(_id(key));
  @override
  Future<void> purgeChannel(String identity, String channelId) async =>
      entries.removeWhere((k, _) => k.startsWith('$identity|$channelId|'));
  @override
  Future<void> purgeIdentity(String identity) async =>
      entries.removeWhere((k, _) => k.startsWith('$identity|'));
}

Future<(_Client, WorkspaceController, _Files)> mountImage(
  WidgetTester tester,
  bool dark, {
  AttachmentImageByteStore? store,
}) async {
  final client = _Client()..user = RaftRecord({'id': 'alice'});
  client.selectServer('server');
  final w = WorkspaceController(client, attachmentImageStore: store)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channel = RaftChannel({'id': 'channel', 'joined': true});
  w.channels = [w.channel!];
  final files = _Files();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    if (!files.bytes.isCompleted) files.bytes.complete(png);
    w.dispose();
    await client.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: AttachmentView(
          controller: w,
          files: files,
          metadata: const {
            'id': 'image',
            'filename': 'image.png',
            'mimeType': 'image/png',
          },
        ),
      ),
    ),
  );
  return (client, w, files);
}

Future<void> decodeWithoutPainting(WidgetTester tester) async {
  final dynamic state = tester.state(find.byType(AttachmentView));
  for (var i = 0; i < 100 && state.imageProvider == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(state.imageProvider, isA<ImageProvider>());
}

/// Pumps frames and yields to the real event loop until [finder] matches,
/// failing after [timeout] of wall-clock time. The lightbox shows the zoom
/// surface once the original has been read back and decoded, which is real
/// file and codec work: a fixed delay or frame count fails on a loaded machine.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final clock = Stopwatch()..start();
  while (finder.evaluate().isEmpty) {
    if (clock.elapsed > timeout) {
      fail('Timed out after ${timeout.inSeconds}s waiting for $finder');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '[K11a] ${dark ? 'dark' : 'light'} painted loading image accepts its first click',
      (tester) async {
        final (_, _, files) = await mountImage(tester, dark);
        await tester.pump();
        expect(files.reads, 1);
        expect(
          tester
              .widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard))
              .preview,
          isNull,
        );
        final action = find.byTooltip('Preview image.png');
        expect(action.hitTestable(), findsOneWidget);
        await tester.tap(action);
        await tester.pump();
        // The route's first frame is built off stage while the Hero measures.
        await tester.pump();
        expect(
          find.byTooltip('Close Preview'),
          findsOneWidget,
          reason: 'Source opens the lightbox at intent while image bytes are pending.',
        );
        expect(tester.takeException(), isNull);
      },
    );
    for (final retirement in ['close', 'revoke']) {
      testWidgets(
        '[K11b] ${dark ? 'dark' : 'light'} pending image $retirement rejects late preview',
        (tester) async {
          final (_, w, files) = await mountImage(tester, dark);
          await tester.pump();
          await tester.tap(find.byTooltip('Preview image.png'));
          await tester.pump();
          await tester.pump();
          expect(find.byTooltip('Close Preview'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 300));
          if (retirement == 'close') {
            await tester.tap(find.byTooltip('Close Preview'));
          } else {
            w.revokeServer('server');
          }
          await tester.pump();
          files.bytes.complete(png);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.byTooltip('Close Preview'), findsNothing);
          expect(
            find.byKey(const ValueKey('attachment-image-image')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          expect(files.reads, 1);
        },
      );
    }
    testWidgets(
      '[K11c] ${dark ? 'dark' : 'light'} real pointer survives decoded-before-paint handoff',
      (tester) async {
        final (client, _, files) = await mountImage(
          tester,
          dark,
          store: _MemoryStore(),
        );
        await tester.pump();
        final action = find.byTooltip('Preview image.png');
        expect(action.hitTestable(), findsOneWidget);
        final paintedCenter = tester.getCenter(action);
        files.bytes.complete(png);
        // Complete the real codec without painting another thumbnail frame.
        await decodeWithoutPainting(tester);
        await tester.tapAt(paintedCenter);
        await tester.pump();
        await tester.pump();
        expect(find.byTooltip('Close Preview'), findsOneWidget);
        // The card's picture flies to the stage; the stage's own picture
        // takes over when the flight lands.
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byKey(const ValueKey('attachment-image-image')),
          findsOneWidget,
        );
        // The lightbox decodes the full original from the persisted bytes.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('attachment-image-image')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(files.reads, 1);
        expect(client.urlReads, 1);
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} accepted loading click displays decode failure without reopening',
      (tester) async {
        final (_, _, files) = await mountImage(tester, dark);
        await tester.pump();
        await tester.tap(find.byTooltip('Preview image.png'));
        await tester.pump();
        await tester.pump();
        expect(find.byTooltip('Close Preview'), findsOneWidget);
        files.bytes.completeError(StateError('owned image failure'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Failed to load image'), findsOneWidget);
        expect(find.byTooltip('Close Preview'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(files.reads, 1);
      },
    );
  }

  testWidgets('image lightbox: the 0 key resets zoom and pan', (tester) async {
    final (_, _, files) = await mountImage(
      tester,
      false,
      store: _MemoryStore(),
    );
    await tester.pump();
    final action = find.byTooltip('Preview image.png');
    final center = tester.getCenter(action);
    files.bytes.complete(png);
    await decodeWithoutPainting(tester);
    await tester.tapAt(center);
    await tester.pump();
    await tester.pump();
    // The card's picture lands on the stage before the stage's own takes over.
    await tester.pump(const Duration(milliseconds: 400));
    await pumpUntilFound(tester, find.byType(ImageZoomSurface));
    final zoom = tester
        .widget<ImageZoomSurface>(find.byType(ImageZoomSurface))
        .controller;
    zoom.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);
    expect(zoom.value.getMaxScaleOnAxis(), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pump();
    expect(zoom.value, Matrix4.identity());
    expect(find.byTooltip('Close Preview'), findsOneWidget);
  });
}
