import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

// Web AgentStatusBadge and AgentRuntimeErrorNotice (v1.24.0): the agent
// profile's status chip states and the runtime error banner shapes.

@RaftPreviews('Agent status chip', size: Size(390, 420))
Widget agentStatusChipPreview() => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      const RaftAgentStatusRow(
        text: 'Online',
        tone: RaftAgentStatusTone.success,
        light: RaftAgentStatusLight.online,
      ),
      const RaftAgentStatusRow(
        text: 'Likely online',
        tone: RaftAgentStatusTone.success,
        light: RaftAgentStatusLight.online,
      ),
      RaftAgentStatusRow(
        text: 'Sign-in needed for Codex CLI',
        tone: RaftAgentStatusTone.warning,
        light: RaftAgentStatusLight.error,
        onRetry: () {},
      ),
      RaftAgentStatusRow(
        text: 'Computer offline',
        tone: RaftAgentStatusTone.muted,
        light: RaftAgentStatusLight.offline,
        onOpenChip: () {},
      ),
      const RaftAgentStatusRow(
        text: 'Computer access revoked: move the agent to another computer (re-attaching adds a new one)',
        tone: RaftAgentStatusTone.warning,
        light: RaftAgentStatusLight.error,
        wrap: true,
      ),
      RaftAgentStatusRow(
        text: 'Offline',
        tone: RaftAgentStatusTone.muted,
        light: RaftAgentStatusLight.offline,
        onChangeModel: () {},
        onRetry: () {},
      ),
      RaftAgentStatusRow(
        text: 'Working…',
        tone: RaftAgentStatusTone.busy,
        light: RaftAgentStatusLight.busy,
        retrying: true,
        onRetry: () {},
        detail: '3 deliveries written since the runtime last responded',
      ),
    ],
  ),
);

@RaftPreviews('Runtime error banner by code', size: Size(520, 420))
Widget runtimeErrorBannerCodePreview() => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    RaftRuntimeErrorBanner(
      message: "The model provider's usage limit has been reached. Wait for the limit to reset, or switch the agent to another model or account in its settings.",
      detail: '429 Too Many Requests: You have hit your usage limit for this billing period (account [redacted]). Try again after the limit resets.',
      onCopy: () {},
      onViewLogs: () {},
    ),
    const RaftRuntimeErrorBanner(
      message: "The agent's model provider usage limit has been reached. Wait for the limit to reset, or ask the agent's owner to switch it to another model or account.",
    ),
    const RaftRuntimeErrorBanner(message: 'Agent encountered an error'),
  ],
);

@RaftPreviews('Runtime error banner, billing', size: Size(520, 360))
Widget runtimeErrorBannerBillingPreview() => SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RaftRuntimeErrorBanner(
        message: 'Model service balance too low',
        billingBody: "Alpha can't reply right now. Check the balance and billing for the model service this agent uses, then start it again.",
        onOpenModelSettings: () {},
        onCopy: () {},
      ),
      const RaftRuntimeErrorBanner(
        message: 'Model service balance too low',
        billingBody: "Alpha can't reply right now. Check the balance and billing for the model service this agent uses, then start it again.",
        billingNote: 'Ask a server admin to fix this.',
      ),
    ],
  ),
);
