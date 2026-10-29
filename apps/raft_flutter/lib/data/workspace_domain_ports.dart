import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/thread_search.dart';
import 'package:raft_flutter/data/user_activity.dart';
import 'package:raft_flutter/data/workspace_message_windows.dart';

/// Preserve raw-client calls and overridable query/command calls separately.
abstract interface class WorkspaceTransportPort {
  RaftClient get client;
  Future<dynamic> query(String path, {Map<String, dynamic>? query});
  Future<dynamic> sharedQuery(String path, {Map<String, dynamic>? query});
  Future<dynamic> command(String method, String path, {dynamic data});
}

abstract interface class WorkspaceDevicePort {
  bool get writable;
  Future<dynamic> read(String kind, String id, {String? server});
  Future<void> save(
    String kind,
    String id,
    dynamic value, {
    String? server,
    bool requiredSuccess = false,
  });
}

/// D2. Channel rows keep the existing accepted object identity.
abstract interface class WorkspaceChannelDirectoryPort {
  List<RaftChannel> get channels;
  List<RaftChannel> get dms;
  RaftChannel? channelById(String id);
  Future<void> refreshChannels();
  Future<void> refreshChannel(String id);
  void recordRowWrite(String id);
  void putRow(RaftChannel row);
}

/// D3. Live getters: callers do not retain this page's facts across awaits.
abstract interface class WorkspacePresentationReadPort {
  bool get loading;
  RaftChannel? get channel;
  RaftLocation get location;
  int get navigationRevision;
  String get navigationAuthority;
  bool get foreground;
  bool get mobileNavigation;
  bool get presentationActive;
  bool get mainPresented;
  bool get threadPresented;
  bool get chatTabPresented;
  bool get borrowed;
  String? get presentationAuthority;
  String? get sourceNavigationAuthority;
}

/// D3 writes initiated by an already admitted coordinator. Each operation has
/// only the old assignment's side effects; notification stays at its old site.
abstract interface class WorkspacePresentationWritePort {
  void setSelectedChannel(RaftChannel? channel);
  void patchSelectedChannel(RaftChannel Function(RaftChannel) patch);
  void assignError(String? value);
  void assignSection(String section);
  void assignUnboundSection(String section);
  void assignLoading(bool value);
  void assignMissingConversationChannelId(String? id);
}

/// D3 public commands retain their old source delegation and notification.
/// These are distinct from the assignment-only port above.
abstract interface class WorkspacePresentationCommandsPort {
  void setError(String? value);
  void setSection(String section);
}

/// D4. Canonical rows; ownership and mutation remain with the message domain.
abstract interface class WorkspaceMessageRowsPort {
  BigInt get watermark;
  int get generation;
  List<Map<String, dynamic>> rows(String channelId);
  Map<String, dynamic>? message(String channelId, String messageId);
  Set<String>? visibleIds(String channelId);
  bool isContext(String channelId);
  bool isDiskOnly(String? channelId);
  bool contextHasNewer(String? channelId);
  bool hasAcceptedWindow(String channelId);
}

/// D4. Thread/page facts are not included in the common session context.
abstract interface class WorkspaceWindowFactsPort {
  int windowGeneration(bool thread);
  bool get hasNewer;
  bool get channelLoading;
  String? get threadChannelId;
  String? get threadParentChannelId;
  String? get threadParentMessageId;
  WorkspaceThreadIdentity? get threadIdentity;
  RaftMessage? get threadParent;
  Object historyTicket(String channelId);
}

/// D4. Delayed page writes retain MessageWindowRequest's owner and current
/// checks. No replacement ticket type or new fence algorithm is introduced.
abstract interface class WorkspaceWindowWritePort {
  MessageWindowRequest request(
    String id, {
    bool thread = false,
    bool checkNavigation = false,
    bool Function()? allowed,
  });
  void acceptRows(
    MessageWindowRequest request,
    String id,
    Iterable<Map<String, dynamic>> rows, {
    Iterable<String>? visible,
    bool replace = false,
    bool authoritative = false,
  });
  Future<void> saveWindow(
    String id, {
    bool thread = false,
    bool coalesce = false,
  });
  void rejectHistoryRead(String id);
}

/// D4, consumed by D6. Optimistic reactions remain memory-only and include the
/// open thread-parent copy. D6 retains its existing async admission checks.
abstract interface class WorkspaceReactionWritePort {
  bool setMessageReactions(
    String channelId,
    String messageId,
    List<Map<String, dynamic>> reactions,
  );
}

/// D4, consumed by D5. The original single delivery observer calls this once;
/// borrowed editors do not register an additional source observer.
abstract interface class WorkspaceDeliveryProjectionPort {
  void deliveryChanged(String scope, RaftMessage? accepted);
}

/// D4 complete commands. Routing to a source is an explicit binding chosen
/// per entrypoint; it is never inferred from sharing a RaftClient instance.
abstract interface class WorkspaceConversationCommandsPort {
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  });
  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
    bool replaceEntry = false,
  });
  Future<void> openThread(
    RaftMessage parent, {
    String? focusedMessageId,
    bool navigate = true,
  });
  Future<void> openThreadIdentity({
    required String parentChannelId,
    required String parentMessageId,
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
  });
  void closeThread({bool navigate = true});
  void closeDeniedThread(String parentChannelId);
  void adoptAccessibleSelection(Set<String> accessible);
  Future<void> returnToLatest({bool navigate = true, bool thread = false});
}

abstract interface class WorkspaceThreadCreationPort {
  Future<String?> ensureThread();
}

/// D2. Local snapshot state and the source-effective cursor are distinct.
/// Non-D2 consumers only read these objects. Reset is ordered by SessionScope.
abstract interface class WorkspaceReadStatePort {
  ReadStateLedger get localReadState;
  ReadStateLedger get effectiveReadState;
  Map<String, int> get unread;
  Set<String> get mentions;
  Map<String, int> get readPosts;
  RaftTimelineBottoms get scrolledAway;
}

/// D2. Receipt I/O retains the current visibility and disk-only guards.
abstract interface class WorkspaceReadCommandsPort {
  Future<void> markRead(String id);
  Future<void> refreshUnread();
  bool acceptReadAllAck(
    String scopeId,
    dynamic receipt, {
    required String serverId,
    required String principalId,
  });

  /// Exactly the old selectChannel block: capture readPosts, reset the bottom
  /// flag, and optionally clear unread/mention then persist, in that order.
  int beginOpenRead(String id, {required bool optimistic});

  /// The old finally condition; no extra await or additional notification.
  void reconcileOpenRead(
    String id,
    int readPostsBefore, {
    required bool optimistic,
  });
}

/// D1 owns feature evaluation and identity-reset ordering. D2 owns the prefs
/// reducer. Patches are applied to servers then selected server, with no notify.
abstract interface class WorkspaceSessionEffectsPort {
  bool get syncCoreNotificationPrefsEnabled;
  void ensureSyncIdentity();
  void patchServerRows(RaftRecord Function(RaftRecord) patch);
}

/// Existing task warming, explicitly separate from the common context.
abstract interface class WorkspaceTaskMetadataPort {
  Future<void> warm(String channelId);
}

/// D2 chooses candidates and adds the per-session prefetched mark before this
/// call. D4 captures authority/reply, constructs the request, starts task warm,
/// reads/records the page, then remembers the tail and summaries in old order.
/// It does not select, join, mark read, or publish another notification.
abstract interface class WorkspaceMessagePrefetchPort {
  Future<void> prefetchAcceptedTail(
    RaftChannel candidate, {
    required bool Function() stillCurrent,
  });
}

/// D2 receiver-local projections used at the old SessionScope stage positions.
/// No method here delegates to a borrowed source or publishes on its own.
abstract interface class WorkspaceReadProjectionPort {
  void assignSidebarOrder(Map<String, dynamic> value);
  void resetDirectoryAndUnreadProjection();
  void resetNotificationPrefsIdentity();
}

/// D1 connection progress. Preserve the existing generation/watermark pair.
abstract interface class WorkspaceConnectionProgressPort {
  (int, BigInt)? get gapSyncedThrough;
  void assignGapSyncedThrough((int, BigInt)? value);
}
