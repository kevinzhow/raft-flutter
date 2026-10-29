import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_thumbnail_restart_test.dart'
    show CountingFiles, png, thumbnailUrl, workspace;

/// A video too large to prepare by itself: the card idles on its poster.
const video = <String, dynamic>{
  'id': 'photo',
  'filename': 'clip.mp4',
  'mimeType': 'video/mp4',
  'sizeBytes': 60 * 1024 * 1024,
};

class RefusingFiles extends AttachmentFiles {
  int attempts = 0;
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) async {
    attempts++;
    throw DioException(
      requestOptions: RequestOptions(path: url),
      response: Response(requestOptions: RequestOptions(path: url), statusCode: 403),
      type: DioExceptionType.badResponse,
    );
  }
}

void main() {
  late Directory directory;
  late Uint8List poster;

  Future<void> mountCard(
    WidgetTester tester,
    dynamic w,
    AttachmentFiles files,
    Map<String, dynamic> metadata,
  ) async {
    tester.view.physicalSize = const Size(600, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: InlineVideoAttachment(
            controller: w,
            files: files,
            metadata: metadata,
            channelId: 'channel',
            authorized: () => true,
            pending: false,
          ),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(Image).evaluate().isNotEmpty) break;
    }
  }

  Future<int> storedFiles(WidgetTester tester) async {
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
    return stored;
  }

  setUp(() {
    directory = Directory.systemTemp.createTempSync('raft-video-poster');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  testWidgets(
    'the server thumbnail poster is fetched once, kept on disk and reused after a restart',
    (tester) async {
      poster = (await tester.runAsync(() => png(320, 180)))!;
      Future<Directory> root() async => directory;
      final metadata = {...video, 'thumbnailUrl': thumbnailUrl};

      final (firstClient, first) = workspace(AttachmentDiskCache(root), metadata);
      final firstFiles = CountingFiles(poster);
      await mountCard(tester, first, firstFiles, metadata);
      expect(find.byType(Image), findsOneWidget);
      expect(firstFiles.urls, [thumbnailUrl]);
      expect(await storedFiles(tester), 1, reason: 'the poster is on disk');
      await tester.pumpWidget(const SizedBox());
      first.dispose();
      await firstClient.dispose();

      // Cold start: a new process-level store and controller.
      final (client, w) = workspace(AttachmentDiskCache(root), metadata);
      final files = CountingFiles(poster);
      await mountCard(tester, w, files, metadata);
      expect(find.byType(Image), findsOneWidget);
      expect(files.urls, isEmpty);
      expect(client.resolutions, 0);
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );

  testWidgets(
    'a message restored without thumbnailUrl still paints the stored poster, with no request',
    (tester) async {
      poster = (await tester.runAsync(() => png(320, 180)))!;
      Future<Directory> root() async => directory;
      final metadata = {...video, 'thumbnailUrl': thumbnailUrl};
      final (firstClient, first) = workspace(AttachmentDiskCache(root), metadata);
      await mountCard(tester, first, CountingFiles(poster), metadata);
      expect(await storedFiles(tester), 1);
      await tester.pumpWidget(const SizedBox());
      first.dispose();
      await firstClient.dispose();

      final (client, w) = workspace(AttachmentDiskCache(root), video);
      final files = CountingFiles(poster);
      await mountCard(tester, w, files, video);
      expect(find.byType(Image), findsOneWidget);
      expect(files.urls, isEmpty);
      expect(client.resolutions, 0);
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );

  testWidgets(
    'a refused thumbnail leaves the first frame as the poster and never fetches the video',
    (tester) async {
      Future<Directory> root() async => directory;
      final metadata = {...video, 'thumbnailUrl': thumbnailUrl};
      final (client, w) = workspace(AttachmentDiskCache(root), metadata);
      final files = RefusingFiles();
      await mountCard(tester, w, files, metadata);
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(files.attempts, 1);
      expect(find.byType(Image), findsNothing);
      expect(client.resolutions, 0, reason: 'the video is never signed or fetched');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );
}
