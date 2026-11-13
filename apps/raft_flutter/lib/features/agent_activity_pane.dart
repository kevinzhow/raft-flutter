// Web AgentActivityLog (default export): the Activity tab. It opens on the
// per-turn Overview with the raw log one toggle away (Web 1.24
// AgentActivityLog.tsx:647, 704; `activity_overview_web_v0` is retired).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_activity_overview.dart';
import 'agent_detail_view.dart'
    show AgentActivityTab, agentCachedActivityEntries;
import 'agent_trajectory_log.dart' show admittedAgentTrajectoryRows;

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
  });
  final WorkspaceController controller;
  final String agentId, activity, activityText;
  final String? machineId;
  final List<Map<String, dynamic>> initialEntries;
  final ValueChanged<String>? onOpenComputer;

  @override
  State<AgentActivityPane> createState() => _AgentActivityPaneState();
}

class _AgentActivityPaneState extends State<AgentActivityPane> {
  WorkspaceController get w => widget.controller;

  /// Web `view`: the Overview first.
  bool overview = true;

  /// Whether the agent has any raw activity (tells "no turns yet" from "this
  /// computer records no turns"): the log the raw view shares, read once.
  bool? rawKnown;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRawKnown());
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  Future<void> _loadRawKnown() async {
    final request = ++_request, id = widget.agentId;
    try {
      final result = await w.query(
        '/agents/$id/activity-log',
        query: {'limit': '50'},
      );
      if (!mounted || request != _request) return;
      setState(() => rawKnown = admittedAgentTrajectoryRows(result).isNotEmpty);
    } catch (_) {
      // Unknown: the overview treats it as "has activity" only when the
      // shared log snapshot says so.
    }
  }

  AgentActivityTab _raw() => AgentActivityTab(
    key: ValueKey('agent-activity-${widget.agentId}'),
    controller: w,
    agentId: widget.agentId,
    initialEntries: widget.initialEntries,
  );

  @override
  Widget build(BuildContext context) {
    final hasRaw =
        rawKnown ??
        (widget.initialEntries.isNotEmpty ||
            agentCachedActivityEntries(w, widget.agentId).isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // ds-allow: Web `flex shrink-0 items-center px-4 pt-3`
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: RaftSegmentedControl<bool>(
              key: const ValueKey('activity-view'),
              label: raftText(context, 'Activity view'),
              value: overview,
              onChanged: (value) => setState(() => overview = value),
              items: [
                RaftSegmentedOption(
                  value: true,
                  label: raftText(context, 'Overview'),
                  itemKey: const ValueKey('activity-view-overview'),
                ),
                RaftSegmentedOption(
                  value: false,
                  label: raftText(context, 'Raw log'),
                  itemKey: const ValueKey('activity-view-raw'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: overview
              ? AgentActivityOverview(
                  key: ValueKey('agent-overview-${widget.agentId}'),
                  controller: w,
                  agentId: widget.agentId,
                  machineId: widget.machineId,
                  activity: widget.activity,
                  activityText: widget.activityText,
                  hasRawActivity: hasRaw,
                  onShowRaw: () => setState(() => overview = false),
                  onOpenComputer: widget.onOpenComputer,
                )
              : _raw(),
        ),
      ],
    );
  }
}
