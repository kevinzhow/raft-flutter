import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'channel_revocation.dart';
import 'source_activity_unread_store.dart';
import 'workspace_domain_ports.dart';
import 'workspace_entity_directory.dart';
import 'workspace_message_windows.dart';

/// D1's existing overridable entrypoints. The source is chosen at the original
/// public entry, and calls back through this interface keep facade overrides.
abstract interface class WorkspaceSessionEntries {
  WorkspaceSessionEntries? get sessionSource;
  Future<void> bootstrap();
  Future<void> selectServer(
    RaftRecord next, {
    VoidCallback? onHydrated,
    VoidCallback? onCacheMiss,
  });
  Future<void> recoverMembership({bool coalesce = false});
  Future<void> revalidateServerDirectory();
  Future<void> refreshMessageSyncFlag();
  void applyMembershipRole(dynamic payload);
  void revokeServer(String id);
  Future<void> flushCache();
}

/// Receiver-local directory/read projection assignments used only by D1's
/// ordered server hydration. They do not replace public reload commands.
abstract interface class WorkspaceSessionChannels
    implements WorkspaceChannelDirectoryPort {
  ReadStateLedger get readState;
  NotificationPrefsSync get notificationPrefsSync;
  void assignChannels(List<RaftChannel> value);
  void assignDms(List<RaftChannel> value);
  void assignUnread(Map<String, int> value);
  void assignSidebarOrder(Map<String, dynamic> value);
  void resetDirectoryAndUnreadProjection();
  void resetRowAuthority();
  void removeChannelRows(String id);
  Future<void> refreshUnread();
  Future<void> loadSidebar();
  void channelRealtime(String name, dynamic payload);
  void consumeNotificationPrefs(dynamic payload);
  void consumeMessageDisplayPrefs(dynamic payload);
  void projectReadState(String id);
  void persistReadState();
}

/// The frozen read and assignment ports, plus existing presentation commands
/// used by server selection and membership recovery. Assignments never notify.
abstract interface class WorkspaceSessionPresentation
    implements WorkspacePresentationReadPort, WorkspacePresentationWritePort {
  String get section;
  bool canVisitSection(String value);
  void setError(String? value);
}

/// D1 lifecycle uses these D4 operations at their old statement positions.
/// The original reducer/window owners remain the sole state owners.
abstract interface class WorkspaceSessionMessages {
  MessageLedger get ledger;
  MessageSync get messageSync;
  ThreadRepliesSync get threadRepliesSync;
  String? get replyIdentity;
  void assignReplyIdentity(String value);
  void clearReplySummaries();
  void resetHistoryLimits();
  void resetThreadProjection();
  void closeServerLoading();
  void resetNewer();
  void invalidateAllReplyAuthority();
  void invalidateAllChannelReplies();
  void invalidateChannelReplies(String id);
  int get channelGeneration;
  int get threadGeneration;
  String replyToken(String? id);
  String windowAuthority();
  MessageWindowRequest hydrationRequest({required bool Function() allowed});
  bool restoreCachedTail(
    String id,
    dynamic page,
    MessageWindowRequest request, {
    required String replyAuthority,
    required bool replace,
  });
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  });
  void closeThread({bool navigate = true});
  Future<void> resumeHistory();
  Future<void> syncVisibleScopes({BigInt? through});
  void consumeThreadUpdate(Map<String, dynamic> payload);
  bool consumeMessageEvent(RaftEvent event);
  Future<void> resumeResponse(
    Map payload, {
    required VoidCallback refreshUnread,
  });
  void applyReadStateHint(Map fact);
  void acceptReactionViewer(dynamic payload, {required String serverId});
  ChannelRevocationPlan discoverRevocation(String id);
}

/// D5 owns draft restoration. Server hydration invokes its existing operation.
abstract interface class WorkspaceSessionDrafts {
  Future<void> restoreDraft(String id);
}

/// Existing entity/activity owners; reads do not create the optional Activity
/// store. Its receiver identity remains the original facade authority.
abstract interface class WorkspaceSessionEntities
    implements ActivityUnreadAuthority {
  WorkspaceEntityDirectory get entityDirectory;
  bool get ownsEntityDirectory;
}

/// D1-only aliases to the existing receiver-local revocation facts.
/// Ordered commands use the frozen transition port, never the scope binding.
abstract interface class WorkspaceSessionRevocations {
  Set<String> get revokedChannels;
  Set<String> get revokedServers;
}

/// Temporary history boundary; receiver-sensitive helpers retain their original
/// receiver in the composition adapter until the remaining D4 migration.
abstract interface class WorkspacePrefetchPagesPort {
  String replyToken(String? id);
  Future<Map<String, dynamic>> readPrefetchPage(
    MessageWindowRequest request,
    String id,
  );
  Future<bool> recordPrefetchPage(
    MessageWindowRequest request,
    Map<String, dynamic> page,
  );
  void mergeThreadSummaries(String id, dynamic rows);
}
