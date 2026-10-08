import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/features/chat_view.dart';
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
    if (!ready()) {
      final dialogs = find.byType(AttachmentPreviewDialog);
      if (dialogs.evaluate().isNotEmpty) {
        final dynamic state = tester.state(dialogs);
        final player = state.player;
        debugPrint(
          'Native preview diagnostic: loading=${state.loading} error=${state.error != null} controls=${find.byType(RaftMediaControls).evaluate().length}',
        );
        if (player is NativeAttachmentPlayer) {
          debugPrint(
            'Native decoder diagnostic: durationMs=${player.player.state.duration.inMilliseconds} positionMs=${player.player.state.position.inMilliseconds} playing=${player.player.state.playing} playlistSize=${player.player.state.playlist.medias.length}',
          );
          final native = player.player.platform;
          if (native is NativePlayer) {
            for (final property in ['idle-active', 'pause', 'duration']) {
              try {
                debugPrint(
                  'Native decoder property $property=${await native.getProperty(property).timeout(const Duration(seconds: 2))}',
                );
              } catch (_) {
                debugPrint('Native decoder property $property unavailable');
              }
            }
          }
        }
      } else {
        for (final view in find.byType(RaftChatView).evaluate()) {
          final dynamic state = (view as StatefulElement).state;
          debugPrint(
            'Media context diagnostic: loading=${w.channelLoading} rows=${w.messages.length} role=${(view.widget as RaftChatView).thread} adapter=${state.adapter.messages.length} target=${state.adapter.messages.any((dynamic m) => m.id == w.highlightedMessageId)} visible=${w.highlightedMessageId != null && state.focusReceiptVisible(w.highlightedMessageId!)} attached=${state.viewport.hasClients} offset=${state.viewport.hasClients ? state.viewport.offset : null} max=${state.viewport.hasClients ? state.viewport.position.maxScrollExtent : null}',
          );
        }
        await capture('failure-media-context');
      }
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
    final card = find.byWidgetPredicate(
      (widget) => widget is RaftAttachmentCard && widget.filename == name,
    );
    await until(() => card.evaluate().isNotEmpty);
    expect(card, findsOneWidget);
    final title = find.descendant(of: card, matching: find.text(name));
    expect(title, findsOneWidget);
    // Closing a preview and lazy timeline reflow can move the next card's
    // title under fixed chrome. Reveal the actual pointer target, then observe
    // hit-test readiness rather than treating a mounted card as clickable.
    // This is an ordinary user scroll; Search separately proves autonomous focus.
    await Scrollable.ensureVisible(tester.element(title), alignment: 0.5);
    await until(() => title.hitTestable().evaluate().length == 1);
    expect(title.hitTestable(), findsOneWidget);
    await tester.tap(title);
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
