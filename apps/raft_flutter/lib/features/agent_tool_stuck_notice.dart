// Source: Web v1.24 components/agent/AgentToolStuckNotice.tsx (rendered under
// the status chip by features/agent/AgentStatusBadge.tsx) and
// features/agent/AgentDetailPanel.tsx `canStopThisTurn`.
//
// The agent is stuck on one tool call (no output for the daemon's threshold),
// so new messages queue behind it. The line says so instead of a plain "busy",
// with how long and how much is waiting, and, for whoever can control the
// agent, the way out: stop just this turn (`stopAgentTurnWithFeedback`).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'icu_message.dart';

const _minuteMs = 60000;

/// Web `ToolStuckActivityDiagnostic` (the parts the notice reads).
class AgentToolStuck {
  const AgentToolStuck({
    required this.toolName,
    required this.quietSinceMs,
    required this.thresholdMs,
    required this.queuedMessages,
  });

  /// Normalized tool name, e.g. `bash`.
  final String toolName;

  /// When this quiet stretch began, on the agent's Computer clock (ms).
  final num quietSinceMs;
  final num thresholdMs;

  /// Deliveries queued behind the call on the daemon.
  final int queuedMessages;

  /// The carrier of `agent:activity` / the REST agent row's `toolStuck`, or
  /// null when it is absent or not the documented shape.
  static AgentToolStuck? parse(Object? raw) {
    if (raw is! Map) return null;
    final tool = raw['toolName'], quiet = raw['quietSinceMs'];
    final threshold = raw['thresholdMs'], queued = raw['queuedMessages'];
    if (tool is! String || tool.isEmpty) return null;
    if (quiet is! num || !quiet.isFinite) return null;
    if (threshold is! num || !threshold.isFinite) return null;
    return AgentToolStuck(
      toolName: tool,
      quietSinceMs: quiet,
      thresholdMs: threshold,
      queuedMessages: queued is num && queued.isFinite && queued > 0
          ? queued.toInt()
          : 0,
    );
  }

  /// The carrier as the directory row keeps it (JSON-safe).
  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'quietSinceMs': quietSinceMs,
    'thresholdMs': thresholdMs,
    'queuedMessages': queuedMessages,
  };

  @override
  bool operator ==(Object other) =>
      other is AgentToolStuck &&
      other.toolName == toolName &&
      other.quietSinceMs == quietSinceMs &&
      other.thresholdMs == thresholdMs &&
      other.queuedMessages == queuedMessages;

  @override
  int get hashCode =>
      Object.hash(toolName, quietSinceMs, thresholdMs, queuedMessages);
}

/// The normalized carrier a directory row stores for `agent:activity`
/// (Web `updateActivity` keeps `toolStuck` only when the frame carries one).
Map<String, dynamic>? toolStuckCarrier(Object? raw) =>
    AgentToolStuck.parse(raw)?.toJson();

/// A directory row's `toolStuck` (REST row or socket patch).
AgentToolStuck? agentRowToolStuck(Map row) =>
    AgentToolStuck.parse(row['toolStuck']);

/// Web `toolStuckMinutes`: whole minutes quiet, never below the reported
/// threshold (the clock is the agent's Computer, so a small skew is expected)
/// and at least 1.
int toolStuckMinutes(AgentToolStuck stuck, int nowMs) {
  final quietMs = nowMs - stuck.quietSinceMs > stuck.thresholdMs
      ? nowMs - stuck.quietSinceMs
      : stuck.thresholdMs;
  final minutes = (quietMs / _minuteMs).floor();
  return minutes < 1 ? 1 : minutes;
}

/// Web `visibleToolStuck`: a blocked or offline agent's status says that
/// instead, even if a stuck snapshot is still stored. [blocked] is the display
/// state's blocked reason (null when not blocked).
AgentToolStuck? visibleToolStuck(
  AgentToolStuck? stuck, {
  required bool isOnline,
  required Object? blocked,
}) => stuck != null && isOnline && blocked == null ? stuck : null;

/// The "Stuck on {tool} · no output for {minutes} min · N message(s) waiting"
/// line, re-rendered once a minute while it shows (no timer otherwise; it
/// pauses while the app is in the background).
class AgentToolStuckNotice extends StatefulWidget {
  const AgentToolStuckNotice({
    super.key,
    required this.toolStuck,
    this.onStop,
    this.nowMs,
  });

  /// Already filtered by [visibleToolStuck].
  final AgentToolStuck toolStuck;

  /// Stops the current turn. Null when the viewer can't control this agent.
  final VoidCallback? onStop;

  /// Test seam for the clock (milliseconds since the epoch).
  final int Function()? nowMs;

  @override
  State<AgentToolStuckNotice> createState() => _AgentToolStuckNoticeState();
}

class _AgentToolStuckNoticeState extends State<AgentToolStuckNotice> {
  RaftForegroundPeriodic? _minute;

  @override
  void initState() {
    super.initState();
    // A minute tick only re-renders; the clock is read when building.
    _minute = RaftForegroundPeriodic(const Duration(minutes: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minute?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final stuck = widget.toolStuck;
    final now = widget.nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;
    final text = icuText(
      context,
      'Stuck on {tool} · no output for {minutes} min{queued, plural, =0 {} one { · # message waiting} other { · # messages waiting}}',
      {
        'tool': stuck.toolName,
        'minutes': toolStuckMinutes(stuck, now),
        'queued': stuck.queuedMessages,
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        key: const ValueKey('agent-tool-stuck'),
        crossAxisAlignment: WrapCrossAlignment.center,
        // Web `flex-wrap gap-x-2 gap-y-0.5`.
        spacing: RaftSpace.x2,
        runSpacing: RaftSpace.half,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : double.infinity,
            ),
            child: RaftTooltip(
              message: raftText(
                context,
                'A command started by this agent has produced no output for a while. New messages wait until it ends or this turn is stopped.',
              ),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.scale(
                  RaftTypeScale.footnote,
                  color: t.colors['warning-strong'],
                ),
              ),
            ),
          ),
          if (widget.onStop != null)
            RaftTextLink(
              key: const ValueKey('agent-tool-stuck-stop'),
              label: raftText(context, 'Stop current turn'),
              onPressed: widget.onStop,
            ),
        ],
      ),
    );
  }
}
