// Web components/agentArchive/archiveApi.ts + settings/ArchivedAgentsSection.tsx
// + packages/shared/src/agentArchive.ts: archiving an agent (the old "delete")
// keeps its record; its workspace stays on the Computer or is removed from it.
//
//   DELETE /agents/:id             { workspace: keep | delete }
//   GET    /agents/:id/archive     the archive record (workspace state, op)
//   POST   /agents/:id/archive/workspace { action: delete }
//   GET    /agents/archived        the server's archived agents (Settings)
//   socket agent:archive:updated   { agentId }; details are re-read

import 'user_error.dart';

/// Web `AGENT_ARCHIVE_UPDATED_EVENT`.
const agentArchiveUpdatedEvent = 'agent:archive:updated';

/// What happens to the workspace when an agent is archived.
enum AgentArchiveWorkspaceChoice { keep, delete }

/// Where the workspace still exists on the Computer it last ran on.
enum AgentArchiveWorkspaceState { onComputer, deleted, unknown }

AgentArchiveWorkspaceState _workspaceState(Object? value) => switch (value) {
  'on_computer' => AgentArchiveWorkspaceState.onComputer,
  'deleted' => AgentArchiveWorkspaceState.deleted,
  _ => AgentArchiveWorkspaceState.unknown,
};

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// `AgentArchiveView` of `GET /agents/:id/archive`.
class AgentArchiveView {
  const AgentArchiveView({
    required this.agentId,
    required this.archivedAt,
    this.archivedByUserId,
    this.machineId,
    this.machineName,
    this.workspaceState = AgentArchiveWorkspaceState.unknown,
    this.pendingDelete = false,
    this.waitingForComputer = false,
    this.lastErrorCode,
  });

  factory AgentArchiveView.fromJson(Map<dynamic, dynamic> json) =>
      AgentArchiveView(
        agentId: '${json['agentId'] ?? ''}',
        archivedAt: '${json['archivedAt'] ?? ''}',
        archivedByUserId: _string(json['archivedByUserId']),
        machineId: _string(json['machineId']),
        machineName: _string(json['machineName']),
        workspaceState: _workspaceState(json['workspaceState']),
        pendingDelete: json['pendingOp'] == 'delete',
        waitingForComputer: json['waitingForComputer'] == true,
        lastErrorCode: _string(json['lastErrorCode']),
      );

  final String agentId, archivedAt;
  final String? archivedByUserId, machineId, machineName, lastErrorCode;
  final AgentArchiveWorkspaceState workspaceState;

  /// `pendingOp == "delete"`: the Computer is (or will be) deleting it.
  final bool pendingDelete;

  /// Set while the op waits for its Computer to come online.
  final bool waitingForComputer;

  /// Web `canDeleteWorkspace` (the manage check is the caller's).
  bool get canDeleteWorkspace =>
      !pendingDelete && workspaceState == AgentArchiveWorkspaceState.onComputer;
}

/// One row of `GET /agents/archived`.
class ArchivedAgentEntry {
  const ArchivedAgentEntry({
    required this.agentId,
    required this.name,
    this.displayName,
    this.avatarUrl,
    required this.archivedAt,
    this.workspaceState = AgentArchiveWorkspaceState.unknown,
    this.pendingDelete = false,
    this.machineName,
  });

  /// Null for a row without an id (the list is advisory; such a row is skipped).
  static ArchivedAgentEntry? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _string(json['agentId']);
    if (id == null) return null;
    return ArchivedAgentEntry(
      agentId: id,
      name: '${json['name'] ?? ''}',
      displayName: _string(json['displayName']),
      avatarUrl: _string(json['avatarUrl']),
      archivedAt: '${json['archivedAt'] ?? ''}',
      workspaceState: _workspaceState(json['workspaceState']),
      pendingDelete: json['pendingOp'] == 'delete',
      machineName: _string(json['machineName']),
    );
  }

  final String agentId, name, archivedAt;
  final String? displayName, avatarUrl, machineName;
  final AgentArchiveWorkspaceState workspaceState;
  final bool pendingDelete;

  String get title => displayName ?? name;

  /// Web `browsable`: only a workspace still on its Computer opens.
  bool get browsable => workspaceState == AgentArchiveWorkspaceState.onComputer;
}

/// Web `REQUEST_ERROR_MESSAGE_IDS` / `archiveRequestErrorMessage`: a refused
/// archive request in catalog copy when the code is known, else the server's
/// own text, else [fallback] (English source strings).
String archiveRequestErrorText(
  Object? error, {
  String fallback = 'Failed to archive the agent',
}) => userErrorText(
  error,
  fallback: fallback,
  codeText: const {
    'archive_migration_active': 'This agent is being migrated. Wait for the migration to finish or cancel it, then archive it.',
  },
  where: 'agent archive',
);

/// Web `archiveErrorMessageId`: plain-language reason for the last failed
/// workspace operation (English source).
String archiveWorkspaceErrorText(String code) => switch (code) {
  'ARCHIVE_WORKSPACE_MISSING' => 'The workspace was not found on the Computer.',
  'ARCHIVE_DELETE_UNCONFIRMED' => 'The Computer took too long to confirm the delete. It may still be deleting, or may be done: delete the workspace again to check.',
  _ => 'The last workspace operation failed. Try again.',
};
