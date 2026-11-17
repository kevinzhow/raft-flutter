import '../data/resource_row_reconcile.dart' show activityScopeId;
import '../data/workspace_controller.dart';
import 'marked_unread_sync.dart';

// The Activity row itself is `activity_inbox_row.dart` (conversations) and
// `activity_object_row.dart` (Artifacts); what stays here is what the page and
// the context menu read about a row's unread state.

/// Whether an Activity [row] of [w] is marked unread with no count (Web
/// `useScopeMarkedUnread(inboxItemChannelId(item))`).
bool activityRowMarkedUnread(WorkspaceController w, Map row) {
  MarkedUnreadSync.of(w);
  return w.conversationReads.marks.contains(activityScopeId(row));
}

/// InboxContextMenu `showsUnread`: the row's count or its marked-unread flag,
/// so Mark as Read clears a mark.
bool activityRowShowsUnread(WorkspaceController w, Map row) =>
    (row['unreadCount'] as num? ?? 0) > 0 || activityRowMarkedUnread(w, row);
