import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'workspace_navigation.dart';
import 'workspace_composer.dart';
import 'workspace_domain_ports.dart';

/// D4's navigation coordination uses the existing presentation and history.
/// Assignment ports retain their original notification and navigation effects.
abstract interface class WorkspaceMessagePresentationPort
    implements
        WorkspacePresentationReadPort,
        WorkspacePresentationWritePort,
        WorkspacePresentationCommandsPort {
  String? get error;
  WorkspaceNavigation get navigation;
  void bindNavigation();
  bool rejectRevokedConversation(String id);
}

/// Calls that originally dispatched through an overridable public facade
/// still do so. These are commands, not a second owner of their state.
abstract interface class WorkspaceMessageEntryPort {
  Future<void> syncVisibleScopes({BigInt? through});
  Future<String?> ensureThread();
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
  Future<void> openThreadIdentity({
    required String parentChannelId,
    required String parentMessageId,
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
  });
  void closeThread({bool navigate = true});
  void clearHighlightedMessage(
    String? expectedId, {
    int? expectedNavigationRevision,
  });
  Future<void> markRead(String id);
  Future<void> refreshChannel(String id);
  Future<void> refreshChannels();
  Future<void> flushCache();
}

/// Draft restoration remains in its current owner. The scope is evaluated at
/// the old call site, including borrowed editors and pending thread drafts.
abstract interface class WorkspaceMessageDraftPort {
  WorkspaceComposer get composer;
  Map<String, String> get drafts;
  String? draftScope({bool thread = false});
  Future<void> restoreDraft(String id);
}

/// History observes the original notification source. Constructing the message
/// domain creates no notifier, forwarding listener, subscription or event bus.
abstract interface class WorkspaceMessageNotificationPort {
  Listenable get changes;
}
