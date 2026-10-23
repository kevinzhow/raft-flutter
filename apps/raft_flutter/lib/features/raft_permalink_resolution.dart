import 'package:raft_client/raft_client.dart';

import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';

/// What [resolveForeignPermalink] decided for a message link.
enum ForeignPermalinkOutcome {
  /// The link now points into this workspace: open [ForeignPermalink.local].
  local,

  /// No readable local projection exists (or the link is not one this
  /// resolution applies to): the link keeps its own destination.
  keep,

  /// The context read failed for another reason: say so, do not guess.
  unavailable,
}

class ForeignPermalink {
  const ForeignPermalink(this.outcome, [this.local]);
  final ForeignPermalinkOutcome outcome;
  final RaftPermalink? local;
}

/// Web `MessageItem.handleOpenPermalink`, the branch for a channel link whose
/// server slug is not the open workspace's: a joint channel keeps one
/// projection per workspace, so a link copied in the other workspace names a
/// channel id this one does not hold. `GET /messages/context/:id` authorizes
/// the local projection and returns its canonical navigation target (a reply
/// maps to the local thread); the link is rewritten to that local channel.
///
/// A 404 means no readable projection: the link keeps its destination (it
/// opens outside the app, where its own access checks apply). Any other
/// failure is [ForeignPermalinkOutcome.unavailable]. [current] reports that
/// the workspace the read started under is still the open one.
Future<ForeignPermalink> resolveForeignPermalink(
  WorkspaceController w,
  RaftPermalink link, {
  bool Function()? current,
}) async {
  final slug = w.server?.string('slug');
  if (slug == null ||
      slug.isEmpty ||
      link.serverSlug == slug ||
      link.routeKind != 'channel') {
    return const ForeignPermalink(ForeignPermalinkOutcome.keep);
  }
  final Object? data;
  try {
    data = await w.query(
      '/messages/context/${Uri.encodeComponent(link.messageId)}',
      query: {'channelId': link.channelId},
    );
  } catch (e) {
    if (current != null && !current()) {
      return const ForeignPermalink(ForeignPermalinkOutcome.keep);
    }
    if (e is RaftApiException && e.status == 404) {
      return const ForeignPermalink(ForeignPermalinkOutcome.keep);
    }
    return const ForeignPermalink(ForeignPermalinkOutcome.unavailable);
  }
  if (current != null && !current()) {
    return const ForeignPermalink(ForeignPermalinkOutcome.keep);
  }
  if (data is! Map || data['channelId'] is! String) {
    return const ForeignPermalink(ForeignPermalinkOutcome.unavailable);
  }
  final target = data['canonicalTarget'];
  final thread = target is Map && target['kind'] == 'thread';
  final threadChannel = thread ? target['channelId'] : null;
  final parent = thread ? target['threadParentMessageId'] : null;
  return ForeignPermalink(
    ForeignPermalinkOutcome.local,
    RaftPermalink(
      routeKind: link.routeKind,
      serverSlug: slug,
      channelId: threadChannel is String
          ? threadChannel
          : data['channelId'] as String,
      messageId: data['targetMessageId'] is String
          ? data['targetMessageId'] as String
          : link.messageId,
      threadParentMessageId: parent is String
          ? parent
          : link.threadParentMessageId,
    ),
  );
}
