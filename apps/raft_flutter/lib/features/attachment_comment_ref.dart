import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart' show RaftMessage;
import 'package:raft_ui/raft_ui.dart';

import '../data/plain_listenable.dart';
import '../data/workspace_controller.dart';
import 'attachment_comments_flag.dart';
import '../data/personal_presentation.dart' show PersonalPresentationScope;

// Web MessageItem `AttachmentCommentRefChip` and `handleJumpToCommentHost`: a
// comment on an attachment is a message whose server enrichment `commentRef`
// names the attachment, the anchor and where its message lives.

/// Where [commentRef] of a message sends the reader, or null when the server
/// could not resolve the host (the chip then does not jump: never a wrong one).
({String channelId, String messageId, String? parentMessageId})? commentHostOf(
  Map commentRef,
) {
  final messageId = commentRef['hostMessageId'];
  final source = commentRef['hostSource'];
  if (messageId is! String || source is! Map) return null;
  final channelId = source['channelId'];
  if (channelId is! String) return null;
  final rootThread = source['rootThreadChannelId'];
  // The host is itself a thread root: that thread opens on it. A host inside a
  // thread opens its parent's thread; any other host is a channel / DM message.
  final parent = rootThread is String
      ? messageId
      : source['type'] == 'thread' && source['parentMessageId'] is String
      ? source['parentMessageId'] as String
      : null;
  return (channelId: channelId, messageId: messageId, parentMessageId: parent);
}

/// Web `setPendingVideoSeek` / `consumePendingVideoSeek`: the chip of a video
/// comment opens the video at the commented time.
abstract final class AttachmentPendingSeek {
  static final _times = <String, Duration>{};

  static void set(String attachmentId, Duration time) =>
      _times[attachmentId] = time;

  static Duration? consume(String attachmentId) => _times.remove(attachmentId);

  /// Web `parseTimestampLabel`: `1:23` or `1:02:03` as a time, else null.
  static Duration? parseLabel(String label) {
    final parts = label.split(':').map(int.tryParse).toList();
    if (parts.any((n) => n == null) || parts.length < 2 || parts.length > 3) {
      return null;
    }
    final seconds = parts.length == 2
        ? parts[0]! * 60 + parts[1]!
        : parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    return Duration(seconds: seconds);
  }
}

/// Asks the attachment card of an id to open its preview (Web clicks the
/// host message's `video-preview` button once the jump has put it on screen).
/// A request no card takes within [lifetime] is forgotten, so a card that
/// appears much later never opens by surprise.
class AttachmentPendingOpen extends PlainListenable {
  AttachmentPendingOpen._();
  static final instance = AttachmentPendingOpen._();
  static const lifetime = Duration(seconds: 10);

  final _requested = <String, DateTime>{};

  void request(String attachmentId) {
    _requested[attachmentId] = DateTime.now();
    notify();
  }

  bool wants(String attachmentId) {
    final at = _requested[attachmentId];
    if (at == null) return false;
    if (DateTime.now().difference(at) > lifetime) {
      _requested.remove(attachmentId);
      return false;
    }
    return true;
  }

  /// True once, for the card that should open.
  bool take(String attachmentId) =>
      wants(attachmentId) && _requested.remove(attachmentId) != null;
}

Future<void> _openHost(
  WorkspaceController w,
  Map ref,
  ({String channelId, String messageId, String? parentMessageId}) host,
) async {
  final label = ref['anchorLabel'];
  final attachmentId = ref['attachmentId'];
  if (label is String && attachmentId is String) {
    final time = AttachmentPendingSeek.parseLabel(label);
    if (time != null) {
      AttachmentPendingSeek.set(attachmentId, time);
      AttachmentPendingOpen.instance.request(attachmentId);
    }
  }
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == host.channelId).firstOrNull;
  if (host.parentMessageId != null) {
    if (channel != null && w.channel?.id != channel.id) {
      await w.selectChannel(channel);
    }
    await w.openThreadIdentity(
      parentChannelId: host.channelId,
      parentMessageId: host.parentMessageId!,
      focusedMessageId: host.messageId,
    );
    return;
  }
  await w.jumpToMessage(host.channelId, host.messageId);
}

/// The message [body] with the `re:` chip (and the anchor's quote) above it
/// when the message comments on an attachment and the server has attachment
/// comments on. [body] is returned as it is otherwise.
Widget withAttachmentCommentRef(
  BuildContext context,
  WorkspaceController w,
  RaftMessage message,
  Widget body,
) {
  final ref = message.json['commentRef'];
  if (ref is! Map || ref['filename'] is! String) return body;
  final fontSize = PersonalPresentationScope.bodyFontSize(
    context,
    w.client.user?.string('preferredMessageBodyFontSize'),
  );
  final gate = AttachmentCommentsGate.of(w);
  return ListenableBuilder(
    listenable: gate,
    builder: (context, _) {
      if (!gate.enabled) {
        // Learn the flag (cached for the next first frame); until it is on,
        // the message reads as a plain one.
        unawaited(gate.ensure());
        return body;
      }
      final host = commentHostOf(ref);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftAttachmentCommentRef(
            filename: ref['filename'] as String,
            anchorLabel: ref['anchorLabel'] as String?,
            anchorQuote: ref['anchorQuote'] as String?,
            fontSize: fontSize,
            onJump: host == null
                ? null
                : () => unawaited(_openHost(w, ref, host)),
          ),
          body,
        ],
      );
    },
  );
}
