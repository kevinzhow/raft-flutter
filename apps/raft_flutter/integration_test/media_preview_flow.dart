import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import '../test/fixtures/preview_samples.dart';

/// Uses real mounted upload/storage/preview contracts and native decoders.
/// Call in the joined fixture channel after ordinary attachment delivery.
Future<void> verifyNativeMediaPreviewFlow(
  WidgetTester tester,
  WorkspaceController w,
  Future<void> Function(String) capture,
) async {
  Future<void> until(bool Function() ready) async {
    for (var i = 0; i < 160 && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(ready(), true);
  }

  final suffix = DateTime.now().microsecondsSinceEpoch;
  final samples = <String, Uint8List>{
    'native-document-$suffix.txt': Uint8List.fromList(
      utf8.encode('Native structured preview 中文 日本語'),
    ),
    'native-pdf-$suffix.pdf': previewPdf(),
    'native-audio-$suffix.wav': previewWav(),
    'native-video-$suffix.webm': previewVideo(),
  };
  for (final sample in samples.entries) {
    await w.attachUpload(sample.key, sample.value);
  }
  expect(w.uploadsReady(), true);
  expect(await w.send('Native media previews $suffix'), true);
  final message = w.messages.singleWhere(
    (m) => m.content == 'Native media previews $suffix',
  );
  expect(message.attachments, hasLength(4));
  final channelId = w.channel?.id;
  expect(channelId, isNotNull);
  await w.jumpToMessage(channelId!, message.id);
  await tester.pump(const Duration(milliseconds: 300));
  for (final name in samples.keys) {
    await until(
      () => find.widgetWithText(TextButton, name).evaluate().isNotEmpty,
    );
    final button = find.widgetWithText(TextButton, name);
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(button);
    await until(
      () => find.byType(AttachmentPreviewDialog).evaluate().isNotEmpty,
    );
    if (name.endsWith('.txt')) {
      await until(
        () =>
            find.text('Native structured preview 中文 日本語').evaluate().isNotEmpty,
      );
      await capture('attachment-native-text-preview');
    } else if (name.endsWith('.pdf')) {
      await until(() => find.text('1 / 2').evaluate().isNotEmpty);
      expect(
        find.descendant(
          of: find.byType(AttachmentPreviewDialog),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      await capture('attachment-native-pdf-page-one');
      await tester.tap(find.byTooltip('Next page'));
      await until(() => find.text('2 / 2').evaluate().isNotEmpty);
      await capture('attachment-native-pdf-page-two');
    } else {
      await until(
        () =>
            find.byType(RaftMediaControls).evaluate().isNotEmpty &&
            tester
                    .widget<RaftMediaControls>(find.byType(RaftMediaControls))
                    .duration >
                Duration.zero,
      );
      await tester.tap(find.byTooltip('Play'));
      await until(
        () =>
            tester
                .widget<RaftMediaControls>(find.byType(RaftMediaControls))
                .position >
            const Duration(milliseconds: 300),
      );
      expect(
        tester
            .widget<RaftMediaControls>(find.byType(RaftMediaControls))
            .playing,
        true,
      );
      if (name.endsWith('.webm')) {
        await until(
          () =>
              find.byType(Video).evaluate().isNotEmpty &&
              tester.widget<Video>(find.byType(Video)).controller.rect.value !=
                  null &&
              tester
                      .widget<Video>(find.byType(Video))
                      .controller
                      .rect
                      .value!
                      .width >=
                  160 &&
              tester
                      .widget<Video>(find.byType(Video))
                      .controller
                      .rect
                      .value!
                      .height >=
                  90,
        );
      }
      await capture(
        name.endsWith('.webm')
            ? 'attachment-native-video-playing'
            : 'attachment-native-audio-playing',
      );
      await tester.tap(find.byTooltip('Pause'));
      await until(
        () => !tester
            .widget<RaftMediaControls>(find.byType(RaftMediaControls))
            .playing,
      );
      final timeline = find.byType(Slider).first;
      await tester.ensureVisible(timeline);
      await tester.tap(timeline);
      await until(
        () =>
            tester
                .widget<RaftMediaControls>(find.byType(RaftMediaControls))
                .position >=
            const Duration(milliseconds: 1400),
      );
      final volume = find.byType(Slider).last;
      await tester.ensureVisible(volume);
      await tester.tap(volume);
      await until(
        () =>
            tester
                .widget<RaftMediaControls>(find.byType(RaftMediaControls))
                .volume ==
            50,
      );
    }
    await tester.tap(find.byTooltip('Close preview'));
    await until(() => find.byType(AttachmentPreviewDialog).evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
  }
}
