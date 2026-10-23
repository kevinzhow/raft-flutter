import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/platform/video_frame_probe.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_thumbnail_restart_test.dart'
    show CountingFiles, png, workspace;
import 'video_card_frames_test.dart' show FakeProbe, noThumbnail;

/// Web v1.21.23 `useRefreshingMediaUrl` + the inline video card: a preview
/// that cannot be made says so and offers Retry (which signs the link again)
/// and Download to view; a file the platform cannot decode offers only the
/// download.
void main() {
  late Directory directory;
  late Uint8List picture;

  setUp(() => directory = Directory.systemTemp.createTempSync('raft-retry'));
  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> mountCard(
    WidgetTester tester,
    FakeProbe probe, {
    VoidCallback? onDownload,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (client, w) = workspace(
      AttachmentDiskCache(() async => directory),
      noThumbnail,
    );
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: InlineVideoAttachment(
              controller: w,
              files: CountingFiles(picture),
              metadata: noThumbnail,
              channelId: 'channel',
              authorized: () => true,
              pending: false,
              frameProbe: probe,
              onOpenPreview: () {},
              onDownload: onDownload,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 300 && probe.calls.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Activates the action labelled [label]. The test font is wider than the
  /// real one, so the two actions wrap onto two lines and their touch targets
  /// overlap; the activation itself is what is under test.
  void press(WidgetTester tester, String label) => tester
      .widget<RaftInteractive>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(RaftInteractive),
            )
            .first,
      )
      .onPressed!();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Retry reads the frame again and the card recovers', (
    tester,
  ) async {
    picture = (await tester.runAsync(() => png(64, 64)))!;
    final probe = FakeProbe(picture)
      ..failWith = const VideoFrameException(
        VideoFrameFailure.failed,
        'timeout',
      );
    await mountCard(tester, probe);
    await settle(tester);
    expect(find.text("Couldn't load this video preview."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Download to view'), findsOneWidget);
    expect(probe.calls, hasLength(1));

    probe.failWith = null;
    press(tester, 'Retry');
    await settle(tester);
    expect(probe.calls, hasLength(2), reason: 'one more read, not a loop');
    expect(find.byKey(const Key('inline-video-failure')), findsNothing);
    expect(find.byKey(const Key('inline-video-play')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a file the platform cannot decode offers only Download', (
    tester,
  ) async {
    picture = (await tester.runAsync(() => png(64, 64)))!;
    final probe = FakeProbe(picture)
      ..failWith = const VideoFrameException(
        VideoFrameFailure.failed,
        'unsupported',
      );
    var downloads = 0;
    await mountCard(tester, probe, onDownload: () => downloads++);
    await settle(tester);
    expect(
      find.text('This video may use a codec this browser cannot preview.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    press(tester, 'Download to view');
    expect(downloads, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
