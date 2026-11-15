// The agent profile's status chip, drawn: Web v1.24.0 AgentStatusBadge.tsx.
// agent_status_state.dart decides which words, light and links apply; this
// formats them in the viewer's language and owns the Retry request.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import 'agent_metadata_projection.dart';
import 'agent_status_state.dart';

/// `formatActivityTextDescriptor`: a catalog source is localized, a raw server
/// string is shown as it came.
String agentStatusDescriptorText(
  BuildContext context,
  AgentActivityDescriptor d,
) => d.raw ? d.source : raftFormat(context, d.source, d.values);

/// `formatPauseRetryTime`: when a paused agent's next automatic try starts
/// (`pauseRetryAtMs`): the clock if that is today, otherwise the date and the
/// clock, in the viewer's zone. Null when there is no time or it has passed
/// (the try is due; the copy says "later" until the server reports it).
String? agentPauseRetryTime(
  SourceTimeFormatter formatter,
  int atMs,
  DateTime now,
) {
  if (atMs <= now.millisecondsSinceEpoch) return null;
  final at = DateTime.fromMillisecondsSinceEpoch(atMs);
  return formatter.dayKey(at) == formatter.dayKey(now)
      ? formatter.clock(at)
      : formatter.shortDateTime(at);
}

/// The chip row of one agent's profile header.
class AgentStatusChipView extends StatefulWidget {
  const AgentStatusChipView({
    super.key,
    required this.chip,
    this.tooltip,
    this.onRetry,
    this.onChangeModel,
    this.onOpenComputer,
  });
  final AgentStatusChip chip;

  /// Descriptor of the chip's tooltip when it differs from its words.
  final AgentActivityDescriptor? tooltip;

  /// Restarts the agent (`POST /agents/:id/reset {mode: restart}`); a throw is
  /// the failure toast. Null: the viewer may not restart it.
  final Future<void> Function()? onRetry;
  final VoidCallback? onChangeModel;

  /// Opens the Computer (Computer offline / update required).
  final VoidCallback? onOpenComputer;

  @override
  State<AgentStatusChipView> createState() => _AgentStatusChipViewState();
}

class _AgentStatusChipViewState extends State<AgentStatusChipView> {
  bool _retrying = false;

  Future<void> _retry() async {
    final retry = widget.onRetry;
    if (retry == null || _retrying) return;
    setState(() => _retrying = true);
    try {
      await retry();
    } catch (_) {
      if (mounted) showRaftToast(context, 'Failed to reset agent');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = widget.chip;
    final text = agentStatusDescriptorText(context, chip.text);
    return RaftAgentStatusRow(
      text: text,
      tooltip: widget.tooltip == null
          ? null
          : agentStatusDescriptorText(context, widget.tooltip!),
      tone: switch (chip.tone) {
        AgentChipTone.success => RaftAgentStatusTone.success,
        AgentChipTone.busy => RaftAgentStatusTone.busy,
        AgentChipTone.warning => RaftAgentStatusTone.warning,
        AgentChipTone.muted => RaftAgentStatusTone.muted,
        AgentChipTone.information => RaftAgentStatusTone.information,
      },
      light: switch (chip.light) {
        AgentChipLight.online => RaftAgentStatusLight.online,
        AgentChipLight.busy => RaftAgentStatusLight.busy,
        AgentChipLight.error => RaftAgentStatusLight.error,
        AgentChipLight.offline => RaftAgentStatusLight.offline,
        AgentChipLight.external => RaftAgentStatusLight.external,
      },
      wrap: chip.wraps,
      onOpenChip: chip.opensComputer ? widget.onOpenComputer : null,
      onRetry: chip.showRetry && widget.onRetry != null
          ? () => unawaited(_retry())
          : null,
      retrying: _retrying,
      onChangeModel: chip.showChangeModel ? widget.onChangeModel : null,
      detail: chip.detail == null
          ? null
          : agentStatusDescriptorText(context, chip.detail!),
    );
  }
}
