import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'feature_flag_client_facts.dart';
import 'workspace_domain_ports.dart';
import 'workspace_session_bindings.dart';
import 'workspace_session_context.dart';

/// Receiver-local feature evaluations fenced by the original request and identity.
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
  bool syncCoreNotificationPrefsEnabled = false;
  bool remoteComputerUpgradeEnabled = false;
  bool agentMigrationEnabled = false, runtimeFormV2WebEnabled = false;
  int _messageFlagRequest = 0;
  static const remoteComputerUpgradeFlag = 'remote_computer_upgrade_v2';
  static const agentMigrationFlag = 'agent_migration_v0';
  static const runtimeFormV2WebFlag = 'runtime_form_v2_web';
  RaftClient get client => transport.client;
  String syncIdentity() => context.syncIdentity();
  ThreadRepliesSync get threadRepliesSync => messages.threadRepliesSync;
  NotificationPrefsSync get notificationPrefsSync =>
      directory.notificationPrefsSync;
  void invalidateRequests() => _messageFlagRequest++;
  void ensureSyncIdentity() {
    final next = syncIdentity();
    if (messages.replyIdentity == next) return;
    final hadIdentity = messages.replyIdentity != null;
    _messageFlagRequest++;
    messages.assignReplyIdentity(next);
    threadRepliesSync.reset();
    notificationPrefsSync.reset();
    syncCoreNotificationPrefsEnabled = false;
    if (hadIdentity) messages.clearReplySummaries();
  }

  Future<void> refreshMessageSyncFlag() async {
    ensureSyncIdentity();
    final request = ++_messageFlagRequest;
    final generation = client.generation, principal = client.user?.id;
    final identity = syncIdentity();
    final id = client.serverId;
    if (id == null || principal == null) return;
    try {
      final result = await client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: [
            notificationPrefsFlag,
            remoteComputerUpgradeFlag,
            agentMigrationFlag,
            runtimeFormV2WebFlag,
          ],
          serverId: id,
        ),
      );
      if (context.disposed ||
          request != _messageFlagRequest ||
          generation != client.generation ||
          principal != client.user?.id ||
          id != client.serverId ||
          identity != syncIdentity()) {
        return;
      }
      final prefsEnabled =
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == notificationPrefsFlag && f['enabled'] == true,
          );
      if (prefsEnabled != syncCoreNotificationPrefsEnabled) {
        notificationPrefsSync.reset();
      }
      syncCoreNotificationPrefsEnabled = prefsEnabled;
      remoteComputerUpgradeEnabled =
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) =>
                f['key'] == remoteComputerUpgradeFlag && f['enabled'] == true,
          );
      bool evaluated(String key) =>
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == key && f['enabled'] == true,
          );
      final migration = evaluated(agentMigrationFlag);
      final runtimeV2 = evaluated(runtimeFormV2WebFlag);
      final flagsChanged =
          migration != agentMigrationEnabled ||
          runtimeV2 != runtimeFormV2WebEnabled;
      agentMigrationEnabled = migration;
      runtimeFormV2WebEnabled = runtimeV2;
      if (flagsChanged) context.changed();
    } catch (_) {
      if (!context.disposed &&
          request == _messageFlagRequest &&
          identity == syncIdentity()) {
        syncCoreNotificationPrefsEnabled = false;
        notificationPrefsSync.reset();
        if (agentMigrationEnabled || runtimeFormV2WebEnabled) {
          agentMigrationEnabled = runtimeFormV2WebEnabled = false;
          context.changed();
        }
      }
      // Unknown capability never authorizes the gated preference path.
    }
  }
}
