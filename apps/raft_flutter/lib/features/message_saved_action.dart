import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart' show RaftMessage;
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show workspaceAuthority;
import 'saved_sidebar_entry.dart';

/// Source MessageItem `handleToggleSave`: the saved state and the Saved badge
/// change at once; a failed request puts them back.
Future<void> toggleSavedMessage(
  BuildContext context,
  WorkspaceController w,
  RaftMessage message,
  bool Function() mounted,
) async {
  final authority = workspaceAuthority(w);
  final store = SavedCountStore.of(w);
  try {
    await store.setSaved(message.id, !store.isSaved(message.id));
  } catch (e) {
    if (mounted() && authority == workspaceAuthority(w)) {
      // ignore: use_build_context_synchronously -- `mounted` is the owning State's.
      showRaftToast(context, userErrorText(e, where: 'save message'));
    }
  }
}

/// The Saved badge of a saved message's footer; pressing it unsaves.
Widget? savedIndicatorOf(
  WorkspaceController w,
  RaftMessage message,
  Future<void> Function(RaftMessage) toggle,
) => SavedCountStore.of(w).isSaved(message.id)
    ? RaftMessageSavedIndicator(onPressed: () => toggle(message))
    : null;
