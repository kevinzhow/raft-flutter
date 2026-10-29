// Image cards without a size in the message: the card has the picture's real
// shape once it is decoded (no letterbox box around it), learns it from the
// decode alone (no extra download), keeps it for the session and in the
// private cache so the second view has its box in the first frame; a message
// that carries a size has its box at once.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_shape.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_thumbnail_restart_test.dart'
    show CountingClient, CountingFiles, png, workspace;

Map<String, dynamic> image({int? width, int? height}) => {
  'id': 'shot',
  'channelId': 'channel',
  'filename': 'screenshot.png',
  'mimeType': 'image/png',
  'sizeBytes': 40000,
  'width': ?width,
  'height': ?height,
};

void main() {
  late Directory directory;
  setUp(() => directory = Directory.systemTemp.createTempSync('raft-image-shape'));
  tearDown(() => directory.deleteSync(recursive: true));
  Future<Directory> root() async => directory;

  Widget host(
    WorkspaceController w,
    CountingFiles files,
    Map<String, dynamic> metadata,
  ) => MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: ShapedImageGallery(
          sessions: w.attachmentMedia.playerSessions,
          images: [metadata],
          builder: (dimensions) => RaftAttachmentGallery(
            dimensions: dimensions,
            itemBuilder: (index, extent, fit) => AttachmentView(
              key: ValueKey('attachment-${metadata['id']}'),
              controller: w,
              files: files,
              metadata: metadata,
              messageId: 'host',
              imageExtent: extent,
              imageFit: fit,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done(), isTrue);
  }

  Size cardSize(WidgetTester tester) =>
      tester.getSize(find.byType(AttachmentView));
  Finder pictures() => find.descendant(
    of: find.byType(AttachmentView),
    matching: find.byType(Image),
  );

  Future<(CountingClient, WorkspaceController)> mount(
    WidgetTester tester,
    Map<String, dynamic> metadata,
    CountingFiles files,
    {
    AttachmentDiskCache? store,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (client, w) = workspace(store ?? AttachmentDiskCache(root), metadata);
    await tester.pumpWidget(host(w, files, metadata));
    return (client, w);
  }

  Future<void> finish(
    WidgetTester tester,
    CountingClient client,
    WorkspaceController w,
  ) async {
    await tester.pumpWidget(const SizedBox());
    w.dispose();
    await client.dispose();
  }

  
    testWidgets('portrait picture, no size in the message: the card takes its shape after the decode', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(() => png(360, 780)))!;
      final files = CountingFiles(bytes);
      final (client, w) = await mount(tester, image(), files);
      final first = cardSize(tester);
      expect(first.width / first.height, closeTo(4 / 3, .05), reason: 'the reserved box until it is known');
      await settle(tester, () => pictures().evaluate().isNotEmpty);
      final aspect = 360 / 780;
      await settle(tester, () {
        final box = cardSize(tester);
        return (box.width / box.height - aspect).abs() < .02;
      });
      final box = cardSize(tester);
      expect(box.height, lessThanOrEqualTo(288.5), reason: 'the single-image cap');
      final picture = tester.getSize(pictures().first);
      expect(picture.width / picture.height, closeTo(aspect, .02));
      expect(
        (picture.width - box.width).abs() < 1.5 && (picture.height - box.height).abs() < 1.5,
        isTrue,
        reason: 'the picture fills its card: no letterbox ($picture in $box)',
      );
      expect(files.urls, hasLength(1), reason: 'the decode that was needed anyway: no extra download');
      await finish(tester, client, w);
    });
  

  testWidgets('a message with a size has its box in the first frame and keeps it', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(() => png(360, 780)))!;
    final files = CountingFiles(bytes);
    final (client, w) = await mount(
      tester,
      image(width: 360, height: 780),
      files);
    final first = cardSize(tester);
    expect(first.width / first.height, closeTo(360 / 780, .02));
    await settle(tester, () => pictures().evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(cardSize(tester), first, reason: 'no layout change after the decode');
    await finish(tester, client, w);
  });

  testWidgets('a very tall picture is capped in height and keeps its shape', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(() => png(60, 900)))!;
    final (client, w) = await mount(
      tester,
      image(),
      CountingFiles(bytes));
    await settle(tester, () => pictures().evaluate().isNotEmpty);
    await settle(tester, () {
      final box = cardSize(tester);
      return (box.width / box.height - 60 / 900).abs() < .01;
    });
    final box = cardSize(tester);
    expect(box.height, lessThanOrEqualTo(844 * .6), reason: 'under 60 % of the screen');
    expect(box.height, lessThanOrEqualTo(288.5));
    await finish(tester, client, w);
  });

  testWidgets('the learnt shape is kept: the second view and a restart have the box at once', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(() => png(360, 780)))!;
    final store = AttachmentDiskCache(root);
    final (client, w) = await mount(
      tester,
      image(),
      CountingFiles(bytes),
      store: store);
    await settle(tester, () => pictures().evaluate().isNotEmpty);
    await settle(tester, () {
      final box = cardSize(tester);
      return (box.width / box.height - 360 / 780).abs() < .02;
    });
    final settled = cardSize(tester);
    // Wait for the shape entry to reach the disk.
    for (var i = 0; i < 200; i++) {
      final n = (await tester.runAsync(
        () => store.entryCount(namespace: AttachmentCacheNamespace.attachments),
      ))!;
      if (n >= 2) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    // Second view in the session: the first frame is final.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(w, CountingFiles(bytes), image()));
    expect(cardSize(tester), settled);
    await finish(tester, client, w);

    // A restart: a new controller reads the stored shape; the picture is on disk.
    final files = CountingFiles(bytes);
    final (client2, w2) = await mount(
      tester,
      image(),
      files,
      store: AttachmentDiskCache(root));
    await settle(tester, () {
      final box = cardSize(tester);
      return (box.width / box.height - 360 / 780).abs() < .02;
    });
    expect(files.urls, isEmpty, reason: 'the stored picture serves it');
    await finish(tester, client2, w2);
  });
}
