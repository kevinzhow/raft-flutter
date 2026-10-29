import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/attachment_player.dart';
import 'attachment_comment_ref.dart' show AttachmentPendingSeek;

// Web `VideoPreviewBody` comment mode: pausing (or scrubbing while paused)
// captures the time as the anchor of the next comment, a paused video offers
// "Add timestamp 0:42", and a comment's timestamp seeks the video (pausing it).

/// Web `formatVideoCommentTimestamp`.
String videoCommentTimestamp(Duration time) {
  final seconds = time.inSeconds < 0 ? 0 : time.inSeconds;
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

class VideoCommentAnchors {
  VideoCommentAnchors({
    required this.session,
    required this.attachmentId,
    required this.player,
  }) {
    session.jumpHandler = jump;
  }

  final RaftAttachmentCommentState session;
  final String? attachmentId;

  /// The player on screen (it changes when an HDR video swaps to its own).
  final AttachmentPlayer? Function() player;

  bool _wasPlaying = false;
  Duration _lastPosition = Duration.zero;
  // A seek the comments panel asked for is not the reader's own scrub.
  bool _seeking = false;

  void dispose() {
    if (session.jumpHandler == jump) session.jumpHandler = null;
  }

  /// Seeks to [time], paused. False when there is no player to seek.
  Future<bool> seekTo(Duration time) async {
    final p = player();
    if (p == null) return false;
    _seeking = true;
    try {
      await p.pause();
      await p.seek(time);
    } finally {
      // The position event of this seek arrives a moment later.
      Timer(const Duration(milliseconds: 400), () => _seeking = false);
    }
    return true;
  }

  /// Web `jumpToAnchor("video-timestamp")`.
  bool jump(RaftCommentAnchor anchor) {
    if (anchor['type'] != 'video-timestamp') return false;
    final data = anchor['data'];
    final time = data is Map ? data['time'] : null;
    if (time is! num || !time.isFinite || time < 0) return false;
    if (player() == null) return false;
    unawaited(seekTo(Duration(milliseconds: (time * 1000).round())));
    return true;
  }

  /// A comment's chip opened this video: go to the commented time.
  void consumePendingSeek() {
    final id = attachmentId;
    final pending = id == null ? null : AttachmentPendingSeek.consume(id);
    if (pending != null) unawaited(seekTo(pending));
  }

  /// The player reported [value]: in comment mode, a pause (or a scrub while
  /// paused) of the reader's own becomes the pending anchor.
  void playbackChanged(AttachmentPlayback value) {
    final paused = !value.playing;
    if (session.commentMode && !_seeking && value.position > Duration.zero) {
      final userPaused = _wasPlaying && paused;
      final scrubbed =
          paused && !_wasPlaying && value.position != _lastPosition;
      if (userPaused || scrubbed) push(value.position);
    }
    _wasPlaying = value.playing;
    _lastPosition = value.position;
  }

  void push(Duration position) {
    final time = (position.inMilliseconds / 1000 * 1000).round() / 1000;
    if (time <= 0) return;
    session.pushAnchor({
      'type': 'video-timestamp',
      'data': {'time': time},
    });
  }

  /// The viewer with the "Add timestamp" button over it while the video is
  /// paused in comment mode and no timestamp is pending.
  Widget overlay(
    BuildContext context,
    AttachmentPlayback playback,
    Widget viewer,
  ) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final canAdd =
          session.commentMode &&
          !playback.playing &&
          playback.position > Duration.zero &&
          session.pendingAnchor?['type'] != 'video-timestamp';
      if (!canAdd) return viewer;
      final stamp = videoCommentTimestamp(playback.position);
      return Stack(
        children: [
          Positioned.fill(child: viewer),
          Positioned(
            left: 0,
            right: 0,
            bottom: 84,
            child: Center(
              child: RaftTooltip(
                message: raftFormat(context, 'Attach timestamp {timestamp}', {
                  'timestamp': stamp,
                }),
                child: RaftRecipeButton(
                  key: const ValueKey('video-comment-add-timestamp'),
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  glyph: RaftGlyph.plus,
                  label: raftFormat(context, 'Add timestamp {timestamp}', {
                    'timestamp': stamp,
                  }),
                  onPressed: () => push(playback.position),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
