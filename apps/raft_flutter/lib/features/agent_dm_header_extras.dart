// What an agent's DM header adds to the shared head (Web v1.24
// features/channel/AgentDMStatus.tsx, ChatPanel.tsx:1778 and
// useChannelHeadToggles.tsx): the status line says "Stuck on {tool}" instead of
// the plain activity while the agent is stuck on one tool call, and the head
// has the Lounge button between Search and Settings.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_lounge.dart';
import 'agent_metadata_projection.dart';
import 'agent_status_state.dart' show agentBlockedStateOf;
import 'agent_tool_stuck_notice.dart';

/// The stuck report the DM status line shows (Web `visibleToolStuck` over the
/// agent's current activity): an online, unblocked agent whose directory row
/// carries one; null otherwise.
AgentToolStuck? dmToolStuck(Map? agent, AgentAmbientDisplay? display) =>
    agent == null || display == null
    ? null
    : visibleToolStuck(
        agentRowToolStuck(agent),
        isOnline: display.activity != 'offline',
        blocked: agentBlockedStateOf(agent['blockedReason']),
      );

/// Builds [builder] with the clock (milliseconds since the epoch), re-built
/// once a minute while [active] (the stuck line counts minutes; no timer
/// otherwise, and none while the app is in the background).
class AgentStuckMinuteClock extends StatefulWidget {
  const AgentStuckMinuteClock({
    super.key,
    required this.active,
    required this.builder,
    this.nowMs,
  });

  final bool active;
  final Widget Function(BuildContext context, int nowMs) builder;

  /// Test seam for the clock.
  final int Function()? nowMs;

  @override
  State<AgentStuckMinuteClock> createState() => _AgentStuckMinuteClockState();
}

class _AgentStuckMinuteClockState extends State<AgentStuckMinuteClock> {
  RaftForegroundPeriodic? _minute;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AgentStuckMinuteClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!widget.active) {
      _minute?.dispose();
      _minute = null;
    } else {
      // A minute tick only re-renders; the clock is read when building.
      _minute ??= RaftForegroundPeriodic(const Duration(minutes: 1), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _minute?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    widget.nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch,
  );
}

/// The Lounge button of an agent DM's head (Web `useChannelHeadToggles`
/// `onOpenLounge`, shown when the server has Lounges on, the viewer is not a
/// Guest and the DM's agent offers one); empty otherwise.
List<Widget> agentDmLoungeActions(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic>? agent,
) {
  if (agent == null || !canOpenAgentLounge(w, agent)) return const [];
  return [
    raftConversationHeaderAction(
      key: const ValueKey('agent-dm-open-lounge'),
      glyph: RaftGlyph.users,
      tooltip: raftText(context, 'Lounge'),
      onPressed: () => openAgentLounge(context, w, '${agent['id']}'),
    ),
  ];
}
