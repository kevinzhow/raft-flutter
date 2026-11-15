// Source: Web v1.24 components/agent/stopSubagent.ts. Stop one running
// subagent (`POST /agents/:id/subagents/:taskId/interrupt`, API+100): the agent
// and its other subagents keep running. One short toast says what happened, as
// Stop current turn does: no confirmation, Retry on a plain failure (the stop
// is idempotent), and a refusal the server explains with a code gets its own
// message and no Retry.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart' show RaftApiException;
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show workspaceAuthority;

/// Web `SubagentStopOutcome`: how a stop-this-subagent request ended.
enum SubagentStopOutcome { interrupted, notRunning, unsupported }

/// Web `stopSubagent`: any other `outcome` reads as `not_running`.
Future<SubagentStopOutcome> stopSubagent(
  WorkspaceController w,
  String agentId,
  String subagentTaskId,
) async {
  final data = await w.command(
    'POST',
    '/agents/$agentId/subagents/${Uri.encodeComponent(subagentTaskId)}/interrupt',
  );
  final outcome = data is Map ? data['outcome'] : null;
  return switch (outcome) {
    'interrupted' => SubagentStopOutcome.interrupted,
    'unsupported' => SubagentStopOutcome.unsupported,
    _ => SubagentStopOutcome.notRunning,
  };
}

/// Web `REFUSAL_MESSAGE_IDS`: retrying will not help these. Offline reuses the
/// stop-turn copy.
String? _refusalMessage(Object error) => switch (error) {
  RaftApiException(code: 'computer_upgrade_required') =>
    "Upgrade this agent's Computer to stop a single subagent.",
  RaftApiException(code: 'computer_offline') =>
    "This agent's Computer is offline.",
  _ => null,
};

/// Web `stopSubagentWithFeedback`.
Future<void> stopSubagentWithFeedback(
  BuildContext context,
  WorkspaceController w,
  String agentId,
  String subagentTaskId,
) async {
  final authority = workspaceAuthority(w);
  try {
    final outcome = await stopSubagent(w, agentId, subagentTaskId);
    if (!context.mounted || authority != workspaceAuthority(w)) return;
    switch (outcome) {
      case SubagentStopOutcome.interrupted:
        showRaftToast(
          context,
          'Asked the subagent to stop.',
          tone: RaftToastRecipeTone.success,
        );
      case SubagentStopOutcome.notRunning:
        showRaftToast(
          context,
          "This subagent isn't running.",
          tone: RaftToastRecipeTone.info,
        );
      case SubagentStopOutcome.unsupported:
        showRaftToast(
          context,
          "This subagent can't be stopped on its own.",
          tone: RaftToastRecipeTone.info,
        );
    }
  } catch (error) {
    if (!context.mounted || authority != workspaceAuthority(w)) return;
    final refusal = _refusalMessage(error);
    if (refusal != null) {
      showRaftToast(context, refusal);
      return;
    }
    showRaftToast(
      context,
      "Couldn't stop the subagent.",
      actionLabel: 'Retry',
      onAction: () {
        if (context.mounted) {
          unawaited(
            stopSubagentWithFeedback(context, w, agentId, subagentTaskId),
          );
        }
      },
    );
  }
}
