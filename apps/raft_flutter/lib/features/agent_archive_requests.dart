// The archive requests (Web components/agentArchive/archiveApi.ts and
// settings/ArchivedAgentsSection.tsx): they run through the workspace
// controller's fenced query / command.
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' show RaftUserError;

import '../data/agent_archive.dart';
import '../data/workspace_controller.dart';

/// `DELETE /agents/:id` with the workspace choice. A failure carries the
/// catalog copy ([RaftUserError]) so a dialog shows it as Web does.
Future<void> archiveAgent(
  WorkspaceController w,
  String agentId,
  AgentArchiveWorkspaceChoice choice,
) async {
  try {
    await w.command(
      'DELETE',
      '/agents/$agentId',
      data: {'workspace': choice.name},
    );
  } catch (e) {
    if (e is RaftApiException && e.staleScope) rethrow;
    throw RaftUserError(archiveRequestErrorText(e));
  }
}

Future<AgentArchiveView?> fetchAgentArchive(
  WorkspaceController w,
  String agentId,
) async {
  final value = await w.query('/agents/$agentId/archive');
  final archive = value is Map ? value['archive'] : null;
  return archive is Map ? AgentArchiveView.fromJson(archive) : null;
}

/// `POST /agents/:id/archive/workspace { action: delete }`.
Future<AgentArchiveView> requestArchiveWorkspaceDelete(
  WorkspaceController w,
  String agentId,
) async {
  try {
    final value = await w.command(
      'POST',
      '/agents/$agentId/archive/workspace',
      data: {'action': 'delete'},
    );
    final archive = value is Map ? value['archive'] : null;
    if (archive is! Map) throw const FormatException('archive missing');
    return AgentArchiveView.fromJson(archive);
  } catch (e) {
    if (e is RaftApiException && e.staleScope) rethrow;
    throw RaftUserError(archiveRequestErrorText(e));
  }
}

/// `GET /agents/archived`. Advisory: the caller hides the list on a failure.
Future<List<ArchivedAgentEntry>> fetchArchivedAgents(
  WorkspaceController w,
) async {
  final value = await w.query('/agents/archived');
  final list = value is Map ? value['agents'] : null;
  if (list is! List) return const [];
  return [for (final row in list) ?ArchivedAgentEntry.tryParse(row)];
}
