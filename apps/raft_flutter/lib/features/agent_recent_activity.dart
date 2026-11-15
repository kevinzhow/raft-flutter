// Web features/agent/AgentRecentActivity.tsx: the profile's "Recent activity"
// (xxchan, 2026-11-05): the Now card with the profile's status chip as its
// first line and the agent's last few turns one line each; its heading opens
// the Activity tab. It shows from the start (the status needs no turns) and
// follows the agent's activity as the Activity overview does: each status push
// and each reconnect reload it. The turns are the agent's, held per server
// scope, so a revisit shows them at once while a read refreshes them.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_activity_reload.dart';
import 'agent_activity_summaries.dart';
import 'agent_now_card.dart';

/// Finished turns the profile lists under what the agent is doing now.
const recentActivityTurns = 3;

/// What the last read of the agent's newest turns found.
class AgentRecentActivitySnapshot {
  List<TurnSummary> turns = const [];
  TurnSummary? running;
  bool loaded = false;
}

class AgentRecentActivity extends StatefulWidget {
  const AgentRecentActivity({
    super.key,
    required this.controller,
    required this.agentId,
    required this.activity,
    required this.activityText,
    required this.status,
    required this.onOpenActivity,
    this.clock,
  });
  final WorkspaceController controller;
  final String agentId, activity, activityText;

  /// The profile's status chip (with Retry, Change model and the tool-stuck
  /// notice): the card's first line.
  final Widget status;
  final VoidCallback onOpenActivity;
  final DateTime Function()? clock;

  @override
  State<AgentRecentActivity> createState() => _AgentRecentActivityState();
}

class _AgentRecentActivityState extends State<AgentRecentActivity> {
  late AgentRecentActivitySnapshot snapshot;
  AgentActivityReload? _reload;
  int _request = 0;

  WorkspaceController get w => widget.controller;

  AgentRecentActivitySnapshot _snapshot() => w.agentTabCache.putIfAbsent(
    'recent-activity/${widget.agentId}',
    AgentRecentActivitySnapshot.new,
  ) as AgentRecentActivitySnapshot;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    snapshot = _snapshot();
    _reload?.dispose();
    _reload = AgentActivityReload(
      events: w.client.events,
      agentId: widget.agentId,
      load: _load,
    );
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AgentRecentActivity old) {
    super.didUpdateWidget(old);
    // The panel is reused for another agent: its turns are never shown while
    // this one's load.
    if (old.agentId != widget.agentId) {
      _request++;
      _open();
    }
  }

  @override
  void dispose() {
    _request++;
    _reload?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request, id = widget.agentId;
    try {
      // One more than listed: without a running turn the newest is the
      // card's own line.
      final result = await w.query(
        '/agents/$id/activity-summaries',
        query: {'limit': '${recentActivityTurns + 1}'},
      );
      if (!mounted || request != _request || id != widget.agentId) return;
      final page = TurnSummaryPage.parse(result);
      // A running turn's own row (an empty wake it continued) is not a
      // finished one.
      final runningId = page.current?.id;
      setState(() {
        snapshot
          ..turns = runningId == null
              ? page.summaries
              : page.summaries.where((t) => t.id != runningId).toList()
          ..running = page.current
          ..loaded = true;
      });
    } catch (_) {
      // The status still shows; the turns come with the next reload.
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('agent-recent-activity'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        // ds-allow: Web `px-5 py-4`
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: AgentNowCard(
          controller: w,
          activity: widget.activity,
          activityText: widget.activityText,
          turns: snapshot.turns,
          running: snapshot.running,
          status: widget.status,
          onOpenActivity: widget.onOpenActivity,
          recentRows: recentActivityTurns,
          clock: widget.clock,
        ),
      ),
      const RaftSeparator(),
    ],
  );
}
