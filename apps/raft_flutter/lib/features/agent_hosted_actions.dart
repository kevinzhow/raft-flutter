// Source: Web v1.24 components/agent/stopAgentTurn.ts and store/agentStore.ts
// `stopAgentTurn`: one command, "Stop current turn" (`POST
// /agents/:id/interrupt-turn`), for a hosted agent and a Computer agent alike.
// The agent stays; a Computer that cannot stop just the turn in place restarts
// the agent and answers `restarted`. No confirmation: stopping a runaway turn
// must be quick. The outcome is one short toast; a refusal the server explains
// with a code gets its own message and no Retry; any other failure offers
// Retry (the stop is idempotent).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart' show RaftApiException;
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show workspaceAuthority;

/// Web `AgentTurnStopOutcome`.
enum AgentTurnStopOutcome { interrupted, restarted, notRunning }

/// Web `stopAgentTurn`: any other `outcome` reads as `not_running`.
Future<AgentTurnStopOutcome> stopAgentTurn(
  WorkspaceController w,
  String agentId,
) async {
  final data = await w.command(
    'POST',
    '/agents/${Uri.encodeComponent(agentId)}/interrupt-turn',
  );
  final outcome = data is Map ? data['outcome'] : null;
  return switch (outcome) {
    'interrupted' => AgentTurnStopOutcome.interrupted,
    'restarted' => AgentTurnStopOutcome.restarted,
    _ => AgentTurnStopOutcome.notRunning,
  };
}

/// Web `REFUSAL_MESSAGE_IDS`: retrying will not help these.
String? _refusalMessage(Object error) => switch (error) {
  RaftApiException(code: 'computer_upgrade_required') => "Upgrade this agent's Computer to stop a single turn. You can stop the whole agent instead.",
  RaftApiException(code: 'computer_offline') =>
    "This agent's Computer is offline.",
  _ => null,
};

/// Web `stopAgentTurnWithFeedback`.
Future<void> stopAgentTurnWithFeedback(
  BuildContext context,
  WorkspaceController w,
  String agentId,
) async {
  final authority = workspaceAuthority(w);
  try {
    final outcome = await stopAgentTurn(w, agentId);
    if (!context.mounted || authority != workspaceAuthority(w)) return;
    showRaftToast(context, switch (outcome) {
      AgentTurnStopOutcome.interrupted => 'Stopped the current turn.',
      AgentTurnStopOutcome.restarted => 'To stop the turn, the agent was restarted. Its conversation context is kept.',
      AgentTurnStopOutcome.notRunning => 'Nothing was running.',
    }, tone: RaftToastRecipeTone.success);
  } catch (error) {
    if (!context.mounted || authority != workspaceAuthority(w)) return;
    final refusal = _refusalMessage(error);
    if (refusal != null) {
      showRaftToast(context, refusal);
      return;
    }
    showRaftToast(
      context,
      "Couldn't stop the current turn.",
      actionLabel: 'Retry',
      onAction: () {
        if (context.mounted) {
          unawaited(stopAgentTurnWithFeedback(context, w, agentId));
        }
      },
    );
  }
}

/// The fleet row's entry (`onStopHostedTurn`) keeps its name; it is the same
/// command.
Future<void> stopHostedTurnWithFeedback(
  BuildContext context,
  WorkspaceController w,
  String agentId,
) => stopAgentTurnWithFeedback(context, w, agentId);
