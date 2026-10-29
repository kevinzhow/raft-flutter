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

/// Counts the signed-URL resolutions (an original being fetched).
class CountingClient extends RaftClient {
  CountingClient()
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

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {'urls': []};
}

/// Serves [bytes] for every image URL and records the URLs.
class CountingFiles extends AttachmentFiles {
  CountingFiles(this.bytes);
  final Uint8List bytes;
  final urls = <String>[];
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) async {
    urls.add(url);
    return bytes;
  }
}

Future<Uint8List> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xff3366cc),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

const thumbnailUrl = 'https://cdn.invalid/thumbs/server/photo.webp';
const base = <String, dynamic>{
  'id': 'photo',
  'filename': 'photo.png',
  'mimeType': 'image/png',
  'width': 1600,
  'height': 1200,
};

/// A controller on [store] whose channel holds one message with [metadata].
(CountingClient, WorkspaceController) workspace(
  AttachmentImageByteStore store,
  Map<String, dynamic> metadata,
) {
  final client = CountingClient()..user = RaftRecord({'id': 'alice'});
  client.selectServer('server');
  final w = WorkspaceController(client, attachmentImageStore: store)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channel = RaftChannel({'id': 'channel', 'joined': true});
  w.channels = [w.channel!];
  w.messageDomain.ledger.switchServer('server');
  w.messageDomain.ledger.ingest([
    {
      'id': 'host',
      'channelId': 'channel',
      'seq': '1',
      'content': 'photo',
      'attachments': [metadata],
    },
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['channel'] = {'host'};
  return (client, w);
}

Widget view(
  WorkspaceController w,
  AttachmentFiles files,
  Map<String, dynamic> metadata,
) => MaterialApp(
  theme: raftTheme(),
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

Future<void> waitPreview(WidgetTester tester) async {
  RaftAttachmentCard card() =>
      tester.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard));
  for (var i = 0; i < 200 && card().preview == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(card().preview, isNotNull);
}

void main() {
  testWidgets(
    'a launch whose message lost thumbnailUrl still paints from the stored thumbnail, with no request',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('raft-thumb-restart'),
      ))!;
      addTearDown(() => directory.delete(recursive: true));
      Future<Directory> root() async => directory;
      final thumbnail = (await tester.runAsync(() => png(320, 240)))!;
      final withThumbnail = {...base, 'thumbnailUrl': thumbnailUrl};

      // First launch: the message carries the thumbnail URL.
      final (firstClient, first) = workspace(
        AttachmentDiskCache(root),
        withThumbnail,
      );
      final firstFiles = CountingFiles(thumbnail);
      await tester.pumpWidget(view(first, firstFiles, withThumbnail));
      await waitPreview(tester);
      expect(firstFiles.urls, [thumbnailUrl]);
      await tester.pumpWidget(const SizedBox());
      var stored = 0;
      for (var i = 0; i < 100 && stored == 0; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        stored = (await tester.runAsync(
          () => directory
              .list(recursive: true)
              .where((e) => e is File && !e.path.endsWith('.raft-part'))
              .length,
        ))!;
      }
      expect(stored, 1);
      first.dispose();
      await firstClient.dispose();

      // Second launch: the same message restored without the URL.
      final (client, w) = workspace(AttachmentDiskCache(root), base);
      final files = CountingFiles(thumbnail);
      await tester.pumpWidget(view(w, files, base));
      await waitPreview(tester);
      expect(files.urls, isEmpty, reason: 'the stored thumbnail serves it');
      expect(client.resolutions, 0, reason: 'no original is signed or fetched');
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
      final files2 = await tester.runAsync(
        () => directory
            .list(recursive: true)
            .where((e) => e is File && !e.path.endsWith('.raft-part'))
            .length,
      );
      expect(files2, 1, reason: 'no second copy of the same image is stored');
    },
  );
}
