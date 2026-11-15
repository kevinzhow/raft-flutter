// The agent panel's runtime error banner, drawn: Web v1.24.0
// AgentRuntimeErrorNotice.tsx. agent_runtime_error_state.dart decides what it
// says; this formats it and wires the actions.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'agent_runtime_error_state.dart';
import 'agent_status_chip_view.dart' show agentStatusDescriptorText;

RaftRuntimeErrorBanner agentRuntimeErrorBanner(
  BuildContext context,
  RuntimeErrorBannerSpec spec, {
  required bool copied,
  required VoidCallback onCopy,
  VoidCallback? onViewLogs,
  VoidCallback? onOpenModelSettings,
}) => RaftRuntimeErrorBanner(
  message: agentStatusDescriptorText(context, spec.headline),
  detail: spec.detail,
  billingBody: spec.billingBody == null
      ? null
      : agentStatusDescriptorText(context, spec.billingBody!),
  billingNote: spec.showAskAdmin
      ? raftText(context, 'Ask a server admin to fix this.')
      : null,
  onOpenModelSettings: spec.showModelSettings ? onOpenModelSettings : null,
  copied: copied,
  onCopy: spec.showCopy ? onCopy : null,
  onViewLogs: spec.showViewLogs ? onViewLogs : null,
);
