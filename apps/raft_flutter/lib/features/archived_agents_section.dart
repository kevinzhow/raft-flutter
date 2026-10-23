import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart' show RaftProfileKind;

import '../data/agent_archive.dart';
import 'agent_archive_requests.dart';
import '../data/workspace_controller.dart';
import 'agent_avatar_dialog.dart' show agentProfileAvatarUrl;
import 'agent_detail_view.dart' show agentTimeFormatter;

/// ArchivedAgentsSection.tsx: the Server settings list of archived agents,
/// laid out like the archived channels above it. Advisory: any failure (or no
/// archived agent) leaves it hidden. Re-read when an agent is archived or its
/// archive changes (socket `agent:deleted` / `agent:archive:updated`).
class ArchivedAgentsSection extends StatefulWidget {
  const ArchivedAgentsSection({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  State<ArchivedAgentsSection> createState() => _ArchivedAgentsSectionState();
}

class _ArchivedAgentsSectionState extends State<ArchivedAgentsSection> {
  WorkspaceController get w => widget.controller;
  List<ArchivedAgentEntry> entries = const [];
  StreamSubscription<RaftEvent>? _events;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _follow();
    unawaited(_load());
  }

  void _follow() {
    _events?.cancel();
    _events = w.client.events.listen((e) {
      if (e.name == agentArchiveUpdatedEvent || e.name == 'agent:deleted') {
        unawaited(_load());
      }
    });
  }

  @override
  void didUpdateWidget(covariant ArchivedAgentsSection old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      entries = const [];
      _follow();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    _request++;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request,
        serverId = w.server?.id,
        generation = w.client.generation;
    try {
      final next = await fetchArchivedAgents(w);
      if (!mounted ||
          request != _request ||
          serverId != w.server?.id ||
          generation != w.client.generation) {
        return;
      }
      setState(() => entries = next);
    } catch (_) {
      // Advisory list: a failure leaves it as it was (hidden when never read).
    }
  }

  String _workspaceText(BuildContext context, ArchivedAgentEntry e) =>
      e.pendingDelete
      ? raftText(context, 'Deleting workspace…')
      : switch (e.workspaceState) {
          AgentArchiveWorkspaceState.onComputer => raftFormat(
            context,
            'Workspace on {computer}',
            {'computer': e.machineName ?? ''},
          ),
          AgentArchiveWorkspaceState.deleted => raftText(
            context,
            'Workspace deleted',
          ),
          AgentArchiveWorkspaceState.unknown => raftText(
            context,
            'Workspace location unknown',
          ),
        };

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final formatter = agentTimeFormatter(context, w);
    return RaftArchivedAgentsSection(
      rows: [
        for (final e in entries)
          RaftArchivedAgentRow(
            id: e.agentId,
            name: e.title,
            avatarUrl: agentProfileAvatarUrl(w.client.origin, e.avatarUrl),
            canViewWorkspace: e.browsable,
            metadata: raftFormat(context, 'Archived {date} · {workspace}', {
              'date': formatter.mediumDateTime(e.archivedAt),
              'workspace': _workspaceText(context, e),
            }),
          ),
      ],
      onOpen: (id) => w.openProfile(RaftProfileKind.agent, id),
      onViewWorkspace: (id) =>
          w.openProfile(RaftProfileKind.agent, id, agentTab: 'workspace'),
    );
  }
}
