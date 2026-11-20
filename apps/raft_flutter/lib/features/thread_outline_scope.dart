import 'package:flutter/widgets.dart';

import '../data/message_history_positions.dart';
import '../data/thread_outline.dart';
import '../data/workspace_controller.dart';
import 'history_reading_anchor.dart';

ThreadOutline? threadOutlineFor(WorkspaceController workspace) {
  final id = workspace.threadChannelId;
  final identity = workspace.threadIdentity;
  if (id == null || identity == null || identity.taskId != null) return null;
  final store = workspace.services.threadOutlines;
  final cached = store[id];
  if (cached != null && cached.current) return cached;
  cached?.dispose();

  final messages = workspace.messageDomain;
  Object authority() {
    final parent = workspace.threadIdentity?.parentChannelId;
    return (
      workspace.client.generation,
      workspace.client.user?.id,
      workspace.client.serverId,
      workspace.server?.string('role'),
      messages.replyToken(parent),
      parent == null ? null : messages.threadResourceAuthority(parent),
    );
  }

  final scope = authority();
  final user = workspace.client.user;
  return store[id] = ThreadOutline(
    channelId: id,
    userId: user?.id,
    preferredTimezone:
        user?.string('preferredTimezone') ?? user?.string('timezone'),
    preferredTimeFormat:
        user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
    isCurrent: () => workspace.threadChannelId == id && authority() == scope,
    query: workspace.query,
    position: () {
      final anchor = workspace.messageWindows.readingAnchor(id)?.messageKey;
      final reading = anchor == null
          ? null
          : workspace.replies
                .where((row) => messages.messageKey(row) == anchor)
                .firstOrNull
                ?.seq;
      return (jump: messages.state.highlightedMessageId, reading: reading);
    },
  );
}

/// Samples the mounted outline even at the live end, where no resume anchor
/// is written. A visible parent can drive the outline but is outside the
/// persisted replies window.
void saveTimelineReadingAnchor(
  WorkspaceController workspace,
  BuildContext context, {
  required String? scope,
  required bool thread,
  required bool atBottom,
  required BigInt? Function(String key) replySequence,
}) {
  final id = thread ? workspace.threadChannelId : workspace.channel?.id;
  if (id == null || id != scope) return;
  final messages = workspace.messageDomain;
  // A restored context can fit in the viewport while newer rows remain.
  final latest =
      atBottom &&
      !(thread
          ? messages.threadWindow?.hasNewer == true
          : messages.state.hasNewer);
  final anchor = thread
      ? _sampleThreadOutline(
          workspace,
          context,
          latest: latest,
          replySequence: replySequence,
        )
      : latest
      ? null
      : captureTimelineReadingAnchor(context);
  if (latest) {
    workspace.messageWindows.clearReadingAnchor(id);
    MessageHistoryPositions.save(workspace, id, null);
  } else if (anchor != null) {
    messages.saveReadingAnchor(id, anchor);
  }
}

ReadingAnchor? _sampleThreadOutline(
  WorkspaceController workspace,
  BuildContext context, {
  required bool latest,
  required BigInt? Function(String key) replySequence,
}) {
  final outline = threadOutlineFor(workspace);
  if (outline == null) {
    return latest ? null : captureTimelineReadingAnchor(context);
  }
  final parent = workspace.presentedThreadParent;
  final parentKey = parent == null
      ? null
      : workspace.messageDomain.messageKey(parent);
  final visible = captureTimelineReadingAnchor(
    context,
    threadParentKey: parentKey,
  );
  if (visible == null) return null;
  if (parent != null && visible.messageKey == parentKey) {
    outline.updateVisibleTop(leadingId: parent.id);
    return latest ? null : captureTimelineReadingAnchor(context);
  }
  if (replySequence(visible.messageKey) case final seq?) {
    outline.updateVisibleTop(seq: seq);
  }
  return latest ? null : visible;
}
