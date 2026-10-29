// Web VideoPreviewBody comment mode: pausing (or scrubbing while paused)
// captures the time as the pending anchor, a paused video offers "Add
// timestamp", and a comment's timestamp seeks the video, paused.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_comment_ref.dart';
import 'package:raft_flutter/features/attachment_video_comments.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_ui/raft_ui.dart';

class _Player implements AttachmentPlayer {
  final seeks = <Duration>[];
  var pauses = 0;
  @override
  Stream<AttachmentPlayback> get changes => const Stream.empty();
  @override
  AttachmentPlayback get playback => const AttachmentPlayback();
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() => const SizedBox();
  @override
  Future<void> open(AttachmentSource source) async {}
  @override
  Future<void> toggle() async {}
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> seek(Duration value) async => seeks.add(value);
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {}
}

AttachmentPlayback _state({bool playing = false, num seconds = 0}) =>
    AttachmentPlayback(
      playing: playing,
      position: Duration(milliseconds: (seconds * 1000).round()),
      duration: const Duration(minutes: 5),
    );

void main() {
  late RaftAttachmentCommentState session;
  late _Player player;
  late VideoCommentAnchors video;
  setUp(() {
    session = RaftAttachmentCommentState();
    player = _Player();
    video = VideoCommentAnchors(
      session: session,
      attachmentId: 'video-1',
      player: () => player,
    );
  });
  tearDown(() {
    video.dispose();
    session.dispose();
  });

  group('capture in comment mode', () {
    test('a pause the reader made becomes the anchor, in seconds', () {
      session.commentMode = true;
      video.playbackChanged(_state(playing: true, seconds: 40));
      expect(session.pendingAnchor, isNull);
      video.playbackChanged(_state(seconds: 42));
      expect(session.pendingAnchor, {
        'type': 'video-timestamp',
        'data': {'time': 42.0},
      });
    });

    test('scrubbing while paused moves the anchor', () {
      session.commentMode = true;
      video.playbackChanged(_state(seconds: 10));
      expect(session.pendingAnchor!['data'], {'time': 10.0});
      video.playbackChanged(_state(seconds: 61.5));
      expect(session.pendingAnchor!['data'], {'time': 61.5});
    });

    test(
      'nothing is captured outside comment mode, at 0:00 or while playing',
      () {
        video.playbackChanged(_state(playing: true, seconds: 5));
        video.playbackChanged(_state(seconds: 6));
        expect(session.pendingAnchor, isNull);
        session.commentMode = true;
        video.playbackChanged(_state(playing: true, seconds: 1));
        video.playbackChanged(_state(playing: true, seconds: 2));
        expect(session.pendingAnchor, isNull);
        video.playbackChanged(_state());
        expect(session.pendingAnchor, isNull);
      },
    );

    test('a pushed anchor opens the panel', () {
      session.commentMode = true;
      var opened = 0;
      session.openPanel = () => opened++;
      video.push(const Duration(seconds: 3));
      expect(opened, 1);
    });
  });

  group('jump', () {
    test(
      'seeks to the stored time, paused, without capturing it back',
      () async {
        session.commentMode = true;
        video.playbackChanged(_state(playing: true, seconds: 10));
        expect(
          session.jump({
            'type': 'video-timestamp',
            'data': {'time': 83.25},
          }),
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);
        expect(player.pauses, 1);
        expect(player.seeks, [const Duration(milliseconds: 83250)]);
        // The pause and the seek the panel asked for are not the reader's own.
        video.playbackChanged(_state(seconds: 83.25));
        expect(session.pendingAnchor, isNull);
      },
    );

    test('other anchors, bad times and a missing player are misses', () {
      expect(
        session.jump({
          'type': 'lines',
          'data': {'start': 1},
        }),
        isFalse,
      );
      expect(
        session.jump({
          'type': 'video-timestamp',
          'data': {'time': 'soon'},
        }),
        isFalse,
      );
      expect(
        session.jump({
          'type': 'video-timestamp',
          'data': {'time': -1},
        }),
        isFalse,
      );
      final orphan = VideoCommentAnchors(
        session: session,
        attachmentId: null,
        player: () => null,
      );
      expect(
        session.jump({
          'type': 'video-timestamp',
          'data': {'time': 5},
        }),
        isFalse,
      );
      orphan.dispose();
    });

    test('a chip that opened the video seeks it once', () async {
      AttachmentPendingSeek.set('video-1', const Duration(seconds: 125));
      video.consumePendingSeek();
      await Future<void>.delayed(Duration.zero);
      expect(player.seeks, [const Duration(seconds: 125)]);
      video.consumePendingSeek();
      await Future<void>.delayed(Duration.zero);
      expect(player.seeks, hasLength(1));
    });
  });

  group('the Add timestamp button', () {
    Future<void> pump(WidgetTester t, AttachmentPlayback playback) =>
        t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: TargetPlatform.linux),
            home: Scaffold(
              body: Builder(
                builder: (context) => video.overlay(
                  context,
                  playback,
                  const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        );

    testWidgets(
      'shows for a paused video in comment mode and pushes the time',
      (t) async {
        session.commentMode = true;
        await pump(t, _state(seconds: 83));
        expect(find.text('Add timestamp 1:23'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('video-comment-add-timestamp')));
        await t.pump();
        expect(session.pendingAnchor!['data'], {'time': 83.0});
        // With a timestamp pending the button gives way.
        expect(find.text('Add timestamp 1:23'), findsNothing);
      },
    );

    testWidgets('is absent while playing, at 0:00, or outside comment mode', (
      t,
    ) async {
      session.commentMode = true;
      await pump(t, _state(playing: true, seconds: 20));
      expect(find.textContaining('Add timestamp'), findsNothing);
      await pump(t, _state());
      expect(find.textContaining('Add timestamp'), findsNothing);
      session.commentMode = false;
      await pump(t, _state(seconds: 20));
      expect(find.textContaining('Add timestamp'), findsNothing);
    });

    test('timestamps read m:ss, or h:mm:ss from an hour', () {
      expect(videoCommentTimestamp(const Duration(seconds: 5)), '0:05');
      expect(videoCommentTimestamp(const Duration(seconds: 3725)), '1:02:05');
    });

    test('a chip label is read back as a time', () {
      expect(
        AttachmentPendingSeek.parseLabel('1:23'),
        const Duration(seconds: 83),
      );
      expect(
        AttachmentPendingSeek.parseLabel('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(AttachmentPendingSeek.parseLabel('L12'), isNull);
      expect(AttachmentPendingSeek.parseLabel('Row 3–5'), isNull);
    });
  });
}
