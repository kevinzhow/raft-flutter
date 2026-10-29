// Web components/agent/stopHostedTurn.ts: one command on a cloud agent's
// profile, "Stop current turn" (`POST /agents/:id/stop`). The agent stays; the
// provider interrupts what it is doing. No confirmation: stopping a runaway
// turn must be quick. The outcome is one short toast; a failed stop offers
// Retry (the provider's stop is idempotent).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show workspaceAuthority;

/// `stopHostedAgentTurn`: `interrupted`, else `not_running`.
Future<String> stopHostedAgentTurn(
  WorkspaceController w,
  String agentId,
) async {
  final data = await w.command(
    'POST',
    '/agents/${Uri.encodeComponent(agentId)}/stop',
  );
  return data is Map && data['result'] == 'interrupted'
      ? 'interrupted'
      : 'not_running';
}

/// `stopHostedTurnWithFeedback`.
Future<void> stopHostedTurnWithFeedback(
  BuildContext context,
  WorkspaceController w,
  String agentId,
) async {
  final authority = workspaceAuthority(w);
  try {
    final result = await stopHostedAgentTurn(w, agentId);
    if (!context.mounted || authority != workspaceAuthority(w)) return;
    showRaftToast(
      context,
      result == 'interrupted'
          ? 'Stopped the current turn.'
          : 'Nothing was running.',
      tone: RaftToastRecipeTone.success,
    );
  } catch (_) {
    if (!context.mounted || authority != workspaceAuthority(w)) return;
    showRaftToast(
      context,
      "Couldn't stop the current turn.",
      actionLabel: 'Retry',
      onAction: () {
        if (context.mounted) {
          unawaited(stopHostedTurnWithFeedback(context, w, agentId));
        }
      },
    );
  }
}
