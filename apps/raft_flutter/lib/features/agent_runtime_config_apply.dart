// Source: Web v1.24 features/agent/runtimeConfigApplyNotice.ts and
// features/agent/AgentProfileInfo.tsx `saveRuntimeFormV2Edit`.
//
// Reconciler step 11c: a running agent is not interrupted when its runtime
// config is saved. `PATCH /agents/:id` without `restartMode` answers
// `configApply`: the server applies the change at the agent's next idle point
// (`when_idle`), or, from a daemon too old for that, at its next start
// (`saved`). Either way nothing was interrupted, so the result is a toast whose
// one action, "Restart now", is the agent's ordinary reset, offered only to
// who may restart it. `newSession`: a runtime switch or a Codex model change,
// which runs on a new session (and Restart now resets the session).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'agent_profile_rules.dart' show canViewAgentPrivateSurfaces;

/// Web `AgentConfigApply`.
enum AgentConfigApply { whenIdle, restarted, saved }

/// The `configApply` of a `PATCH /agents/:id` response, null when absent or
/// not one of the three values.
AgentConfigApply? agentConfigApplyOf(Object? response) {
  final value = response is Map ? response['configApply'] : null;
  return switch (value) {
    'when_idle' => AgentConfigApply.whenIdle,
    'restarted' => AgentConfigApply.restarted,
    'saved' => AgentConfigApply.saved,
    _ => null,
  };
}

/// Web `newSession`: a runtime switch, or a Codex model change since
/// `thread/resume` pins the model (the server clears the session).
bool runtimeConfigStartsNewSession({
  required bool runtimeSwitched,
  required String runtime,
  required String? model,
  required String? initialModel,
}) => runtimeSwitched || (runtime == 'codex' && model != initialModel);

/// Web `canRestartAgent && !agent.deletedAt`: `canControlAgentRuntime`
/// (a managed agent, not a bounded projection; its creator or anyone with
/// `controlAgentRuntime`).
bool canRestartAgentAfterSave({
  required Map agent,
  required String? currentUserId,
  required bool controlAgentRuntime,
  required bool external,
}) =>
    agent['deletedAt'] == null &&
    !external &&
    canViewAgentPrivateSurfaces(agent, currentUserId, controlAgentRuntime);

/// Web `announceRuntimeConfigApply`. [context] must outlive the editor that
/// closed (the root navigator's); [restartNow] is null when this person may
/// not restart the agent.
void announceRuntimeConfigApply(
  BuildContext context, {
  required AgentConfigApply? configApply,
  required bool agentActive,
  required String agentName,
  required bool newSession,
  Future<void> Function(String mode)? restartNow,
}) {
  final whenIdle = configApply == AgentConfigApply.whenIdle;
  // `restarted` already happened; a stopped agent's change applies when it
  // starts, as before.
  if (!whenIdle && !(configApply == AgentConfigApply.saved && agentActive)) {
    return;
  }
  final title = raftFormat(context, "{name}'s settings saved", {
    'name': agentName,
  });
  final description = !whenIdle
      ? 'They apply the next time it starts.'
      : newSession
      ? "It starts a new session when it's next idle."
      : "They apply when it's next idle.";
  showRaftToast(
    context,
    title,
    description: description,
    tone: RaftToastRecipeTone.success,
    actionLabel: restartNow == null ? null : 'Restart now',
    onAction: restartNow == null
        ? null
        : () => unawaited(
            restartNow(newSession ? 'session' : 'restart').catchError((_) {
              if (context.mounted) {
                showRaftToast(
                  context,
                  'Restart failed.',
                  tone: RaftToastRecipeTone.warning,
                );
              }
            }),
          ),
  );
}
