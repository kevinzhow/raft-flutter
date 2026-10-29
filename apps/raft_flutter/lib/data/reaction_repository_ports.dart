import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'workspace_domain_ports.dart';

/// The existing public hydration entrypoint, including receiver overrides.
abstract interface class WorkspaceReactionHydrationPort {
  Future<void> hydrateReactionViewer(RaftMessage message);
}

/// Borrowed pages retain source command dispatch and the effective private
/// viewer ledger. Sharing a client alone does not make a receiver a borrower.
abstract interface class WorkspaceReactionSourcePort
    implements WorkspaceReactionHydrationPort {
  ReactionViewerLedger get reactionViewer;
  Map<String, bool>? pendingReactionTargets(String messageId);
  Future<void> toggleReaction(RaftMessage message, String emoji);
}

/// D4 owns canonical rows, accepted responses, the open parent copy and disk
/// windows. Reaction state stays in its own repository.
abstract interface class WorkspaceReactionMessagesPort
    implements WorkspaceReactionWritePort {
  int get generation;
  Map<String, dynamic>? message(String channelId, String messageId);
  String? get threadChannelId;
  RaftMessage? get threadParent;
  set threadParent(RaftMessage? value);
  void acceptReactionResponse(
    Map<String, dynamic> row, {
    required int generation,
  });
  Future<void> saveWindow(
    String channelId, {
    bool thread = false,
    bool coalesce = false,
  });
}
