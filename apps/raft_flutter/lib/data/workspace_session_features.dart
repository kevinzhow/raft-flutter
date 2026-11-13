import 'package:raft_sync/raft_sync.dart';

import 'workspace_domain_ports.dart';
import 'workspace_session_bindings.dart';
import 'workspace_session_context.dart';

/// The session's sync identity (thread replies, notification prefs) and the
/// slot that used to evaluate its feature flags.
class WorkspaceSessionFeatures {
  WorkspaceSessionFeatures({
    required this.context,
    required this.transport,
    required this.directory,
    required this.messages,
  });
  final WorkspaceSessionContext context;
  final WorkspaceTransportPort transport;
  final WorkspaceSessionChannels directory;
  final WorkspaceSessionMessages messages;
  String syncIdentity() => context.syncIdentity();
  ThreadRepliesSync get threadRepliesSync => messages.threadRepliesSync;
  NotificationPrefsSync get notificationPrefsSync =>
      directory.notificationPrefsSync;
  void ensureSyncIdentity() {
    final next = syncIdentity();
    if (messages.replyIdentity == next) return;
    final hadIdentity = messages.replyIdentity != null;
    messages.assignReplyIdentity(next);
    threadRepliesSync.reset();
    notificationPrefsSync.reset();
    if (hadIdentity) messages.clearReplySummaries();
  }

  /// The session's feature flags once lived here (`sync_core_notification_prefs_v0`,
  /// `remote_computer_upgrade_v2`, `agent_migration_v0`, `runtime_form_v2_web`).
  /// Web 1.24 reads none of them (each is on for everyone, or follows the
  /// server's own answer), so nothing is evaluated: only the sync identity is
  /// checked, as before every evaluation.
  Future<void> refreshMessageSyncFlag() async => ensureSyncIdentity();
}
