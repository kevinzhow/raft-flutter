import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'conversation_window.dart';
import 'reply_authority_epochs.dart';
import 'resource_snapshot_cache.dart';
import 'thread_search.dart';
import 'workspace_message_windows.dart';

/// Receiver-local message and thread projections. Canonical message rows and
/// accepted window membership remain in the existing WorkspaceMessageWindows.
/// Notifications, source routing and ordered session transitions stay with
/// their existing commands; assigning one of these projections never notifies.
class WorkspaceMessageState {
  final messageSync = MessageSync();
  final threadRepliesSync = ThreadRepliesSync();
  String? replyIdentity;
  final replyAuthority = ReplyAuthorityEpochs();
  final resourceSnapshots = ResourceSnapshotCache();

  bool hasNewer = false;
  bool threadHasMore = false;
  bool threadHistoryLimited = false, historyLimited = false;
  String? highlightedMessageId;
  WorkspaceThreadIdentity? threadIdentity;
  MessageWindowRequest? threadVisit;
  bool threadResolutionLoading = false, threadParentLoading = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when a thread opens or closes and hidden whenever threadIdentity is stale.
  String? threadResolutionError;
  RaftMessage? threadParent;
  String? threadChannelId;
  bool channelLoading = false,
      threadLoading = false,
      loadingOlder = false,
      hasMore = false;
  (MessageContextLoadError, (String?, String?))? contextFailure;
  final Map<String, Map<String, dynamic>> pageSummariesByChannel = {};
  bool gapSyncing = false;
}
