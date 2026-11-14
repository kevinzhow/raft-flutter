// Source: packages/web/src/components/thread/inboxRowActions.ts
// (`onNothingUnread`, `thread.row.markUnreadNothing`) at v1.24.0-source.1
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

/// The toast after Mark as Unread on an Activity row whose conversation has
/// nothing from others to count (an older server's `nothing` answer): without
/// it the row would slip back to read unexplained. Skipped when the row's
/// page is gone.
void showNothingUnreadToast(State owner) {
  if (!owner.mounted) return;
  showRaftToast(
    owner.context,
    'Nothing new from others here to mark unread.',
    tone: RaftToastRecipeTone.info,
  );
}
