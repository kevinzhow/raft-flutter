// Web components/agentArchive/AgentArchiveSection.tsx: the "Archive" section of
// an archived agent's profile: when and where it was archived, where its
// workspace is now, and (for people who may manage it) deleting the workspace.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_archive.dart';
import 'agent_archive_requests.dart';
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;

/// `archive` is null while loading or when the agent has no archive record;
/// [failed] is set when the last read failed.
class AgentArchiveSection extends StatefulWidget {
  const AgentArchiveSection({
    super.key,
    required this.controller,
    required this.agentId,
    required this.canManage,
  });
  final WorkspaceController controller;
  final String agentId;

  /// `canArchiveAgent`: deleteAgents or the human creator.
  final bool canManage;

  @override
  State<AgentArchiveSection> createState() => _AgentArchiveSectionState();
}

class _AgentArchiveSectionState extends State<AgentArchiveSection> {
  WorkspaceController get w => widget.controller;
  AgentArchiveView? archive;
  bool failed = false;
  StreamSubscription<RaftEvent>? _events;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _follow();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AgentArchiveSection old) {
    super.didUpdateWidget(old);
    if (old.agentId != widget.agentId ||
        !identical(old.controller, widget.controller)) {
      archive = null;
      failed = false;
      _follow();
      unawaited(_load());
    }
  }

  /// The event carries only the agent id; details are re-read with a
  /// permission check.
  void _follow() {
    _events?.cancel();
    final id = widget.agentId;
    _events = w.client.events.listen((e) {
      final p = e.payload;
      if (e.name == agentArchiveUpdatedEvent &&
          p is Map &&
          p['agentId'] == id) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _request++;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request,
        id = widget.agentId,
        generation = w.client.generation;
    try {
      final next = await fetchAgentArchive(w, id);
      if (!mounted ||
          request != _request ||
          generation != w.client.generation) {
        return;
      }
      setState(() {
        archive = next;
        failed = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => failed = true);
    }
  }

  String get _computer =>
      archive?.machineName ?? raftText(context, 'its Computer');

  Future<void> _confirmDeleteWorkspace() async {
    final id = widget.agentId;
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('agent-archive-delete-workspace-dialog'),
        confirmKey: const ValueKey('agent-archive-delete-workspace-confirm'),
        title: 'Delete workspace from Computer',
        message: raftFormat(
          context,
          'The workspace is deleted from {computer}. This cannot be undone.',
          {'computer': _computer},
        ),
        confirmLabel: 'Delete workspace from Computer',
        confirmVariant: RaftButtonRecipeVariant.danger,
        onConfirm: () async {
          final next = await requestArchiveWorkspaceDelete(w, id);
          if (mounted && id == widget.agentId) {
            setState(() {
              archive = next;
              failed = false;
            });
          }
        },
      ),
    );
  }

  Widget _stacked(
    BuildContext context,
    RaftTokens t,
    String label,
    Widget value, {
    Key? key,
  }) => RaftGapColumn(
    key: key,
    gap: 2,
    children: [
      RaftCssText(label, style: RaftInfoRow.labelStyle(t)),
      DefaultTextStyle.merge(style: RaftInfoRow.valueStyle(t), child: value),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final a = archive;
    final computer = _computer;
    final workspaceText = a == null
        ? raftText(context, 'Unknown')
        : a.pendingDelete
        ? raftFormat(context, 'Deleting from {computer}…', {
            'computer': computer,
          })
        : switch (a.workspaceState) {
            AgentArchiveWorkspaceState.onComputer => raftFormat(
              context,
              'On {computer}',
              {'computer': computer},
            ),
            AgentArchiveWorkspaceState.deleted => raftText(
              context,
              'Deleted from the Computer',
            ),
            AgentArchiveWorkspaceState.unknown => raftText(context, 'Unknown'),
          };
    final formatter = agentTimeFormatter(context, w);
    final by = a?.archivedByUserId == null
        ? null
        : w.services.entityDirectory.member(a!.archivedByUserId!);
    final byName = by == null
        ? null
        : '${by['displayName'] ?? ''}'.isNotEmpty
        ? '${by['displayName']}'
        : '${by['name'] ?? ''}';
    final date = a == null ? '' : formatter.mediumDateTime(a.archivedAt);
    final archivedText = byName == null || byName.isEmpty
        ? date
        : raftFormat(context, '{date} by {name}', {
            'date': date,
            'name': byName,
          });
    final error = a?.lastErrorCode;
    return RaftPanelSection(
      key: const ValueKey('agent-archive-section'),
      children: [
        RaftSectionEyebrow(raftText(context, 'Archive')),
        if (failed)
          RaftBanner(
            size: RaftBannerRecipeSize.sm,
            description: raftText(context, "Couldn't load the archive details"),
          ),
        if (a != null)
          _stacked(
            context,
            t,
            raftText(context, 'Archived on'),
            RaftCssText(archivedText, style: RaftPanelText.profileMono(t)),
            key: const ValueKey('agent-archive-archived-at'),
          ),
        _stacked(
          context,
          t,
          raftText(context, 'Workspace'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaftCssText(
                workspaceText,
                key: const ValueKey('agent-archive-workspace-state'),
              ),
              if (a?.waitingForComputer == true)
                RaftCssText(
                  raftFormat(
                    context,
                    'Waiting for {computer} to come online.',
                    {'computer': computer},
                  ),
                  style: RaftPanelText.caption(t),
                ),
            ],
          ),
        ),
        if (error != null)
          RaftBanner(
            key: const ValueKey('agent-archive-error'),
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.triangleAlert,
            description: raftFormat(
              context,
              !a!.pendingDelete
                  ? archiveWorkspaceErrorText(error)
                  : error == 'ARCHIVE_DELETE_TIMED_OUT'
                  ? '{computer} is still deleting the workspace. Raft checks again shortly.'
                  : 'The last delete did not go through. It is retried automatically.',
              {'computer': computer},
            ),
          ),
        if (widget.canManage && a != null && a.canDeleteWorkspace)
          RaftButton(
            key: const ValueKey('agent-archive-delete-workspace-button'),
            label: raftText(context, 'Delete workspace from Computer'),
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            expand: true,
            onPressed: _confirmDeleteWorkspace,
          ),
      ],
    );
  }
}
