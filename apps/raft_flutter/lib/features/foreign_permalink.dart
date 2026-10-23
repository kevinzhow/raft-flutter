import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart';
import 'raft_permalink_resolution.dart';
import 'quoted_message_preview.dart';

/// Opens a message link in the app. A link of the open workspace opens as it
/// is; a channel link of another workspace is first resolved to this
/// workspace's own channel (Web `handleOpenPermalink`, joint-channel
/// projections). Returns false when the link keeps its own destination and
/// should open outside the app; true once it opened or the failure was shown.
Future<bool> openPermalinkInApp(
  BuildContext context,
  WorkspaceController w,
  RaftPermalink link,
) async {
  if (link.serverSlug == w.server?.string('slug')) {
    await openRaftPermalink(w, link);
    return true;
  }
  final authority = workspaceAuthority(w);
  bool current() => context.mounted && authority == workspaceAuthority(w);
  final resolved = await resolveForeignPermalink(w, link, current: current);
  if (!context.mounted || authority != workspaceAuthority(w)) return true;
  switch (resolved.outcome) {
    case ForeignPermalinkOutcome.keep:
      return false;
    case ForeignPermalinkOutcome.unavailable:
      showRaftToast(
        context,
        raftText(
          context,
          'Could not resolve this message link. Please try again.',
        ),
      );
      return true;
    case ForeignPermalinkOutcome.local:
      await openRaftPermalink(w, resolved.local!);
      return true;
  }
}
