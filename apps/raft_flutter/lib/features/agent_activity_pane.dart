// Web AgentActivityLog (default export): the Activity tab. It opens on the
// per-turn Overview with the raw log one toggle away (Web 1.24
// AgentActivityLog.tsx:647, 704; `activity_overview_web_v0` is retired) and,
// once the agent has had a subagent, a Subagents view (Web
// AgentActivityLog.tsx:656-712).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_activity_overview.dart';
import 'agent_activity_refs.dart' show ActivityOpenTask;
import 'agent_raw_log.dart';
import 'agent_subagent_stop.dart';
import 'agent_subagents_view.dart';

/// Web `ActivityView`.
enum AgentActivityView { overview, raw, subagents }

class AgentActivityPane extends StatefulWidget {
  const AgentActivityPane({
    super.key,
    required this.controller,
    required this.agentId,
    required this.activity,
    required this.activityText,
    this.initialEntries = const [],
    this.machineId,
    this.onOpenComputer,
    this.canStopSubagents = false,
    this.onOpenTask,
  });
  final WorkspaceController controller;
  final String agentId, activity, activityText;
  final String? machineId;
  final List<Map<String, dynamic>> initialEntries;
  final ValueChanged<String>? onOpenComputer;

  /// Web `canStopSubagents`: the viewer may stop a running subagent (Stop
  /// turn's authority, a runtime that can: `canStopSubagentsOf`).
  final bool canStopSubagents;

  /// Web `useRefNavigation().openTask`: opens task N of a conversation for a
  /// `#channel:#7` ref in the log. Absent: task refs read as plain text.
  final ActivityOpenTask? onOpenTask;

  @override
  State<AgentActivityPane> createState() => _AgentActivityPaneState();
}

class _AgentActivityPaneState extends State<AgentActivityPane> {
  WorkspaceController get w => widget.controller;

  /// Web `view`: the Overview first.
  AgentActivityView view = AgentActivityView.overview;

  /// Web `openSubagent`: the group key the Subagents view shows in detail.
  String? openSubagent;

  late AgentActivityLogSource source = _open();

  AgentActivityLogSource _open() => AgentActivityLogSource(
    controller: w,
    agentId: widget.agentId,
    initialEntries: widget.initialEntries,
  )..reload();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    source.setActive(TickerMode.valuesOf(context).enabled);
  }

  @override
  void didUpdateWidget(AgentActivityPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        oldWidget.agentId != widget.agentId) {
      source.dispose();
      source = _open();
      view = AgentActivityView.overview;
      openSubagent = null;
    }
  }

  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }

  /// Web `changeView`.
  void _changeView(AgentActivityView next) => setState(() {
    view = next;
    openSubagent = null;
  });

  /// Web `subagentLink.open`: the raw log's way into one subagent.
  void _openSubagentFromLog(String key) => setState(() {
    openSubagent = key;
    view = AgentActivityView.subagents;
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListenableBuilder(
        listenable: source,
        builder: (context, _) {
          // The Subagents segment appears once the agent has had one.
          final count = source.subagents.length;
          final showSubagents =
              count > 0 || view == AgentActivityView.subagents;
          return Padding(
            // ds-allow: Web `flex shrink-0 items-center px-4 pt-3`
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: RaftSegmentedControl<AgentActivityView>(
                key: const ValueKey('activity-view'),
                label: raftText(context, 'Activity view'),
                value: view,
                onChanged: _changeView,
                items: [
                  RaftSegmentedOption(
                    value: AgentActivityView.overview,
                    label: raftText(context, 'Overview'),
                    itemKey: const ValueKey('activity-view-overview'),
                  ),
                  RaftSegmentedOption(
                    value: AgentActivityView.raw,
                    label: raftText(context, 'Raw log'),
                    itemKey: const ValueKey('activity-view-raw'),
                  ),
                  if (showSubagents)
                    RaftSegmentedOption(
                      value: AgentActivityView.subagents,
                      label: raftText(context, 'Subagents'),
                      count: '$count',
                      itemKey: const ValueKey('activity-view-subagents'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      Expanded(
        child: switch (view) {
          AgentActivityView.overview => ListenableBuilder(
            listenable: source,
            builder: (context, _) => AgentActivityOverview(
              key: ValueKey('agent-overview-${widget.agentId}'),
              controller: w,
              agentId: widget.agentId,
              machineId: widget.machineId,
              activity: widget.activity,
              activityText: widget.activityText,
              hasRawActivity: source.entries.isNotEmpty,
              onShowRaw: () => _changeView(AgentActivityView.raw),
              onOpenComputer: widget.onOpenComputer,
            ),
          ),
          AgentActivityView.subagents => AgentSubagentsView(
            key: ValueKey('agent-subagents-${widget.agentId}'),
            source: source,
            openKey: openSubagent,
            onOpen: (key) => setState(() => openSubagent = key),
            onBack: () => setState(() => openSubagent = null),
            onOpenTask: widget.onOpenTask,
            onStop: widget.canStopSubagents
                ? (taskId) => unawaited(
                    stopSubagentWithFeedback(
                      context,
                      w,
                      widget.agentId,
                      taskId,
                    ),
                  )
                : null,
          ),
          AgentActivityView.raw => AgentRawLog(
            key: ValueKey('agent-activity-${widget.agentId}'),
            source: source,
            onOpenSubagent: _openSubagentFromLog,
            onOpenTask: widget.onOpenTask,
          ),
        },
      ),
    ],
  );
}
