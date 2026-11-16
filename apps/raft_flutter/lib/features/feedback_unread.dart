import '../data/workspace_controller.dart';
import 'management_support.dart';

/// FeedbackUnreadDot: the account's `unread_total` from
/// GET /product-feedback/tickets?limit=1. Settings and the phone's server tab
/// read the same accepted value for the current identity.
const feedbackUnreadSnapshotKey = 'settings:feedback-unread';

int cachedFeedbackUnread(WorkspaceController w) =>
    readPageSnapshot(w, feedbackUnreadSnapshotKey)?['count'] as int? ?? 0;

/// Reads the count and records it for [pageIdentity]; null when the read
/// failed or the identity changed meanwhile (the dot is an accelerator: a
/// failed read shows none).
Future<int?> fetchFeedbackUnread(WorkspaceController w) async {
  if (w.server == null || w.client.user == null) return null;
  final identity = pageIdentity(w);
  try {
    final page = await w.client.get(
      '/product-feedback/tickets',
      query: {'limit': 1},
    );
    final unread = page is Map ? page['unread_total'] : null;
    if (identity != pageIdentity(w) || unread is! int) return null;
    final count = unread < 0 ? 0 : unread;
    writePageSnapshot(w, feedbackUnreadSnapshotKey, identity, {'count': count});
    return count;
  } catch (_) {
    return null;
  }
}
