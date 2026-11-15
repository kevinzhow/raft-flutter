// The agent profile's status chip: which words, light and links it shows.
// Pure logic, no widgets; the host formats the descriptors and draws them.
//
// Source: Web v1.24.0 packages/web/src/features/agent/AgentStatusBadge.tsx
// (the chain), store/agentStore.ts resolveAgentDisplayState (blocked and
// likely-online), utils/agentBlockedState.ts, utils/activity.ts
// (credentialInvalidReasonOf, agentNeedsManualRestart,
// formatCredentialInvalidText).
//
// The readiness branch (utils/readinessCopy.ts readinessHolds / readinessLight)
// is decided here; its words come from computer_readiness_copy.dart. Not here
// (another package owns it): the paused personal assistant chip.
import '../data/runtime_error.dart' show isRuntimeErrorCode;
import 'computer_readiness_copy.dart' show readinessLimitWaitCodes;
import 'agent_metadata_catalog.dart' show sourceAgentActivities;
import 'agent_metadata_projection.dart';

/// Web `AgentBlockedState`: why an agent is held from running, as the status
/// UI shows it.
enum AgentBlockedState {
  computerTooOld,
  computerAccessRevoked,
  computerOffline,
}

/// Web `agentBlockedState(blockedReason)`: the server's `blockedReason`. An
/// unknown computer version reads like a too-old one.
AgentBlockedState? agentBlockedStateOf(Object? blockedReason) =>
    switch (blockedReason) {
      'computer_access_revoked' => AgentBlockedState.computerAccessRevoked,
      'computer_version_unsupported' ||
      'computer_version_unknown' => AgentBlockedState.computerTooOld,
      _ => null,
    };

/// Offline states that keep their own words while the Computer is offline:
/// the server paused automatic wakes, so only a manual start lifts them.
const _ownOfflineDetailKinds = {
  'wake_crash_loop_blocked',
  'terminal_failure_paused',
};

/// Web `agentHeldByOfflineComputer`: its Computer is offline and a person did
/// not stop it (a Computer shutdown keeps the agent's own `status`; a person's
/// Stop is `stopped`). An error keeps its own words. [activity] and
/// [detailKind] are null while the agent has no activity state.
bool agentHeldByOfflineComputer({
  required String status,
  required String? activity,
  required String? detailKind,
  required bool machineOffline,
}) {
  if (!machineOffline || status == 'stopped') return false;
  if (activity == 'error') return false;
  return !(detailKind != null && _ownOfflineDetailKinds.contains(detailKind));
}

/// Web `CredentialHoldReason`.
const credentialHoldReasons = {'user_reauth', 'user_model_access', 'billing'};

/// Web `credentialInvalidReasonOf`: why an agent cannot run until someone
/// fixes its provider credential, from typed data only (never the text).
///
/// - Its own error: the stored runtime error while the live activity is that
///   error (the same message). `requiredAction` first, else its class:
///   AuthError is a rejected sign-in, BillingError an exhausted balance.
/// - Held for another agent's error on the same sign-in: the idle status
///   carries `credentialHold`.
String? credentialInvalidReasonOf({
  required String activity,
  required String activityDetail,
  required String? activityDetailKind,
  Object? credentialHold,
  Object? lastRuntimeError,
}) {
  if (activity == 'online' &&
      activityDetailKind == 'idle' &&
      credentialHold is Map) {
    final reason = credentialHold['reason'];
    if (reason is String && credentialHoldReasons.contains(reason)) {
      return reason;
    }
  }
  if (activity != 'error' || lastRuntimeError is! Map) return null;
  if (lastRuntimeError['message'] != activityDetail) return null;
  final action = lastRuntimeError['requiredAction'];
  if (action is String && action.isNotEmpty) {
    return credentialHoldReasons.contains(action) ? action : null;
  }
  return switch (lastRuntimeError['errorClass']) {
    'AuthError' => 'user_reauth',
    'BillingError' => 'billing',
    _ => null,
  };
}

/// Detail kinds of an agent that stays down until someone starts it by hand,
/// though its chip is not the error light (the server projects them offline).
const _manualStartDetailKinds = {
  'runtime_unavailable',
  'wake_crash_loop_blocked',
  'terminal_failure_paused',
};

/// Failed starts a restart cannot get out of: it resumes the same session,
/// which fails again. Only Reset Session does.
const _restartCannotFixSpawnFailures = {
  'session_needs_reset',
  'session_runtime_mismatch',
};

/// Web `agentNeedsManualRestart`: the agent cannot run until someone restarts
/// it, so the chip offers Retry to whoever may restart it. Never for an agent
/// that is simply offline or stopped, one online or at work, one only guessed
/// online, an external agent, or one whose Computer is blocked.
bool agentNeedsManualRestart({
  required String activity,
  required String? activityDetailKind,
  String? credentialReason,
  String? spawnFailureReason,
  bool spawnFailurePaused = false,
  String? runtimeErrorClass,
  bool isExternal = false,
  AgentBlockedState? blocked,
  bool likelyOnline = false,
}) {
  if (isExternal || blocked != null || likelyOnline) return false;
  if (credentialReason != null) return true;
  // Every error but a rate limit: a restart cannot lift a limit.
  if (activity == 'error') return runtimeErrorClass != 'RateLimitError';
  if (!_manualStartDetailKinds.contains(activityDetailKind)) return false;
  if (spawnFailureReason == null) return true;
  return spawnFailurePaused &&
      !_restartCannotFixSpawnFailures.contains(spawnFailureReason);
}

/// Web `formatCredentialInvalidText`: the status text naming the runtime or
/// model. [runtimeName] and [modelLabel] are the viewer's display names.
AgentActivityDescriptor credentialInvalidDescriptor(
  String reason, {
  required String runtimeName,
  required String? model,
  required String Function(String model) modelLabel,
}) {
  AgentActivityDescriptor key(String s, [Map<String, Object?> v = const {}]) =>
      (source: s, values: v, raw: false);
  switch (reason) {
    case 'user_reauth':
      return key('Sign-in needed for {runtime}', {'runtime': runtimeName});
    case 'user_model_access':
      final trimmed = model?.trim() ?? '';
      return trimmed.isNotEmpty
          ? key("Plan doesn't include {model}", {'model': modelLabel(trimmed)})
          : key("Plan doesn't include this model");
    default:
      return key('Provider balance exhausted');
  }
}

/// Web `readinessHolds`: the server's readiness says the agent cannot work
/// now (blocked) or must wait.
bool readinessHolds(Object? readiness) =>
    readiness is Map &&
    (readiness['state'] == 'blocked' || readiness['state'] == 'waiting');

/// Web `readinessLight`: a Computer offline is stone like any offline; a block
/// or a limit wait is orange (error); a wait in progress (the Computer
/// restarting or updating) is yellow (busy).
({AgentChipTone tone, AgentChipLight light}) readinessLight(Map readiness) {
  final primary = readiness['primary'];
  final code = primary is Map ? primary['code'] : null;
  if (code == 'computer_offline') {
    return (tone: AgentChipTone.muted, light: AgentChipLight.offline);
  }
  if (readiness['state'] == 'blocked' ||
      (code is String && readinessLimitWaitCodes.contains(code))) {
    return (tone: AgentChipTone.warning, light: AgentChipLight.error);
  }
  return (tone: AgentChipTone.busy, light: AgentChipLight.busy);
}

/// The chip's wash, as raft-ui `Badge` variants (Web `PRESENCE_CHIP_VARIANT`).
enum AgentChipTone { success, busy, warning, muted, information }

/// The presence light inside the chip (`StatusDot`).
enum AgentChipLight { online, busy, error, offline, external }

/// What the profile header chip shows.
class AgentStatusChip {
  const AgentStatusChip({
    required this.text,
    required this.tone,
    required this.light,
    this.blocked,
    this.credentialReason,
    this.showRetry = false,
    this.showChangeModel = false,
    this.detail,
    this.likelyOnline = false,
    this.tooltip,
    this.readiness,
    this.showReadinessDetail = false,
  });

  /// The readiness this chip reads (its words are the readiness copy, which
  /// needs the viewer's language: the host formats them). [showReadinessDetail]
  /// adds the sentence and the portal link for the viewers who see details.
  final Map? readiness;
  final bool showReadinessDetail;

  /// The chip's words (also its tooltip unless [tooltip]).
  final AgentActivityDescriptor text;
  final AgentActivityDescriptor? tooltip;
  final AgentChipTone tone;
  final AgentChipLight light;
  final AgentBlockedState? blocked;

  /// `credentialInvalidReasonOf`'s reason, when the chip names one.
  final String? credentialReason;

  /// Retry (restart) and Change model links beside the chip.
  final bool showRetry, showChangeModel;

  /// The mono hint after the chip: `delivery_unconsumed` /
  /// `wake_crash_loop_blocked` counts.
  final AgentActivityDescriptor? detail;
  final bool likelyOnline;

  /// A revoked Computer access is a sentence: the chip wraps it.
  bool get wraps => blocked == AgentBlockedState.computerAccessRevoked;

  /// Computer offline or update required: the chip opens that Computer.
  bool get opensComputer =>
      blocked == AgentBlockedState.computerOffline ||
      blocked == AgentBlockedState.computerTooOld;
}

AgentChipTone _toneOf(String activity) => switch (activity) {
  'online' => AgentChipTone.success,
  'thinking' || 'working' => AgentChipTone.busy,
  'error' => AgentChipTone.warning,
  _ => AgentChipTone.muted,
};

AgentChipLight _lightOf(String activity) => switch (activity) {
  'online' => AgentChipLight.online,
  'thinking' || 'working' => AgentChipLight.busy,
  'error' => AgentChipLight.error,
  _ => AgentChipLight.offline,
};

/// Whether the row carries an activity state of its own (Web: the agent has an
/// `agentActivities` entry). Without one a row that is `active` reads "Likely
/// online".
bool agentHasActivityState(Map row, {Map? live}) {
  bool known(Map? m) =>
      m != null &&
      (sourceAgentActivities.contains(m['activityKind']) ||
          sourceAgentActivities.contains(m['activity']));
  return known(live) || known(row);
}

/// The error's code (a closed list), only while the activity is an error and
/// only a known one: a newer server's code is none. Web `activityErrorCode`.
String? agentActivityErrorCode(Map row, {Map? live, String? activity}) {
  // The live frame's own code wins; a frame without one falls back to the row.
  final state =
      live != null &&
          (live.containsKey('activityErrorCode') ||
              live.containsKey('errorCode'))
      ? live
      : row;
  final code = state['activityErrorCode'] ?? state['errorCode'];
  if (activity != null && activity != 'error') return null;
  return isRuntimeErrorCode(code) ? code as String : null;
}

/// The typed counts line of `delivery_unconsumed` / `wake_crash_loop_blocked`.
AgentActivityDescriptor? _carrierDetail(Map row, String? detailKind) {
  AgentActivityDescriptor key(String s, Map<String, Object?> v) =>
      (source: s, values: v, raw: false);
  String text(Object? v, String fallback) =>
      v == null || '$v'.isEmpty ? fallback : '$v';
  if (detailKind == 'delivery_unconsumed') {
    final c = row['deliveryConsumption'];
    if (c is! Map) return null;
    return key(
      '{count} deliveries written since the runtime last responded (episode {episode}, last via {path})',
      {
        'count': c['unconsumedDeliveries'],
        'episode': c['episode'],
        'path': text(c['lastDeliveryPath'], 'unknown'),
      },
    );
  }
  if (detailKind == 'wake_crash_loop_blocked') {
    final c = row['wakeCrashLoop'];
    if (c is! Map) return null;
    final signal = c['lastSignal'];
    return key(
      '{count} early exits in a row (episode {episode}, last: {exitKind}{signal}); Raft stopped waking this agent until someone starts it',
      {
        'count': c['earlyExitCount'],
        'episode': c['episode'],
        'exitKind': text(c['lastExitKind'], 'unknown'),
        'signal': signal is String && signal.isNotEmpty ? ' $signal' : '',
      },
    );
  }
  return null;
}

/// Everything the chip chain reads. [activity] / [detailKind] / [detail] are
/// the row's current activity (`agentRowAmbientDisplay`), [spawnFailureText]
/// the typed failed-start text that stands in for the daemon's detail.
class AgentStatusInput {
  const AgentStatusInput({
    required this.row,
    required this.activity,
    required this.detailKind,
    required this.detail,
    required this.hasActivityState,
    required this.machineOffline,
    required this.showDetail,
    required this.canRestart,
    required this.canOpenModelSettings,
    required this.runtimeName,
    required this.modelLabel,
    this.errorCode,
    this.spawnFailure,
    this.spawnFailureText,
    this.readiness,
  });

  /// The agent row's readiness (null from a server that does not send it).
  final Map? readiness;
  final Map row;
  final String activity, detailKind, detail;
  final bool hasActivityState, machineOffline, showDetail;

  /// The viewer may restart (the reset route's `controlAgentRuntime`, the
  /// agent not archived, its Computer online).
  final bool canRestart;

  /// The viewer may open the agent's model setting.
  final bool canOpenModelSettings;
  final String runtimeName;
  final String Function(String model) modelLabel;
  final String? errorCode;
  final Map<String, dynamic>? spawnFailure;
  final String? spawnFailureText;
}

/// The chip chain of a managed agent, in Web's order: held by its Computer
/// (blocked), likely online, an invalid credential, then the activity text
/// (an error without detail reads as its code's title).
AgentStatusChip resolveAgentStatusChip(AgentStatusInput i) {
  AgentActivityDescriptor key(String s) =>
      (source: s, values: const {}, raw: false);
  final status = i.row['status'] is String ? i.row['status'] as String : '';
  final blocked =
      agentBlockedStateOf(i.row['blockedReason']) ??
      (agentHeldByOfflineComputer(
            status: status,
            activity: i.hasActivityState ? i.activity : null,
            detailKind: i.hasActivityState ? i.detailKind : null,
            machineOffline: i.machineOffline,
          )
          ? AgentBlockedState.computerOffline
          : null);
  if (blocked != null) {
    final offline = blocked == AgentBlockedState.computerOffline;
    return AgentStatusChip(
      text: key(switch (blocked) {
        AgentBlockedState.computerTooOld => 'Computer update required',
        AgentBlockedState.computerAccessRevoked => 'Computer access revoked: move the agent to another computer (re-attaching adds a new one)',
        AgentBlockedState.computerOffline => 'Computer offline',
      }),
      tone: offline ? AgentChipTone.muted : AgentChipTone.warning,
      light: offline ? AgentChipLight.offline : AgentChipLight.error,
      blocked: blocked,
    );
  }
  // The server's readiness, when the agent cannot work now and its Computer is
  // not already shown as the blocker: the first broken link in words, whose
  // problem it is and who fixes it. Retry only for a verification.
  final readiness = i.readiness;
  if (readiness != null && readinessHolds(readiness)) {
    final light = readinessLight(readiness);
    final primary = readiness['primary'];
    return AgentStatusChip(
      text: (source: '', values: const {}, raw: true),
      tone: light.tone,
      light: light.light,
      readiness: readiness,
      showReadinessDetail: i.showDetail,
      showRetry:
          i.canRestart &&
          primary is Map &&
          primary['code'] == 'verification_required',
    );
  }
  final likelyOnline = !i.hasActivityState && status == 'active';
  if (likelyOnline) {
    return AgentStatusChip(
      text: key('Likely online'),
      tone: AgentChipTone.success,
      light: AgentChipLight.online,
      likelyOnline: true,
    );
  }
  final typed = i.row['lastRuntimeError'];
  final credentialReason = credentialInvalidReasonOf(
    activity: i.activity,
    activityDetail: i.detail,
    activityDetailKind: i.detailKind,
    credentialHold: i.row['credentialHold'],
    lastRuntimeError: typed,
  );
  // Held or not, it cannot run until someone acts: the error light. The reason
  // is a detail of the error, for the viewers who see details only.
  final chipActivity = credentialReason != null ? 'error' : i.activity;
  final text = credentialReason != null
      ? (i.showDetail
            ? credentialInvalidDescriptor(
                credentialReason,
                runtimeName: i.runtimeName,
                model: i.row['model'] as String?,
                modelLabel: i.modelLabel,
              )
            : agentActivityDescriptor('error', '', null))
      : i.showDetail
      ? agentActivityDescriptor(
          i.activity,
          i.spawnFailureText ?? i.detail,
          i.detailKind,
          i.errorCode,
        )
      : agentActivityDescriptor(i.activity, '', null, i.errorCode);
  final spawn = i.spawnFailure;
  final spawnReason = spawn?['reason'] is String
      ? spawn!['reason'] as String
      : null;
  final showRetry =
      i.canRestart &&
      agentNeedsManualRestart(
        activity: i.activity,
        activityDetailKind: i.detailKind,
        credentialReason: credentialReason,
        spawnFailureReason: spawnReason,
        spawnFailurePaused: spawn?['autoRestartPaused'] == true,
        runtimeErrorClass: typed is Map ? typed['errorClass'] as String? : null,
      );
  // The runtime cannot use the model, or the context no longer fits it:
  // another model is a way out.
  final showChangeModel =
      i.showDetail &&
      i.canOpenModelSettings &&
      (spawnReason == 'model_unsupported' ||
          spawnReason == 'session_needs_reset');
  return AgentStatusChip(
    text: text,
    tone: _toneOf(chipActivity),
    light: _lightOf(chipActivity),
    credentialReason: credentialReason,
    showRetry: showRetry,
    showChangeModel: showChangeModel,
    detail: i.showDetail ? _carrierDetail(i.row, i.detailKind) : null,
  );
}

/// Web `externalSetupNeedsSignIn`: no credential it can sign in with: never
/// connected, its login token expired, or every one revoked.
bool externalSetupNeedsSignIn(String? setupState) =>
    setupState == 'waiting_for_login' ||
    setupState == 'login_token_expired' ||
    setupState == 'disconnected';

/// The chip of an external agent (AgentStatusBadge's external branch):
/// presence is its credential seen within the online window; managers also see
/// the setup state. [lastSeenRelative] is "3 minutes ago" for an agent that is
/// not online but was seen; [hasStatus] says the setup status was read.
AgentStatusChip resolveExternalStatusChip({
  required bool online,
  required bool showDetail,
  required String? setupState,
  required bool hasStatus,
  required String? lastSeenRelative,
  required String name,
}) {
  AgentActivityDescriptor key(String s, [Map<String, Object?> v = const {}]) =>
      (source: s, values: v, raw: false);
  // Not signed in yet is something a person must do: the error light.
  final needsSetup = externalSetupNeedsSignIn(setupState);
  var text = key('External');
  AgentActivityDescriptor? tooltip;
  if (showDetail && needsSetup) {
    text = key('Set up');
    tooltip = key('Finish setting up {name}', {'name': name});
  } else if (online) {
    text = key('External · Online');
  } else if (lastSeenRelative != null) {
    text = key('External · Last active {time}', {'time': lastSeenRelative});
  } else if (showDetail &&
      (setupState == 'credential_minted' || setupState == 'connected')) {
    text = key('External · No Raft activity yet');
  } else if (showDetail && hasStatus) {
    text = key('External · Not configured');
  }
  return AgentStatusChip(
    text: text,
    tooltip: tooltip,
    tone: online
        ? AgentChipTone.success
        : needsSetup
        ? AgentChipTone.warning
        : AgentChipTone.information,
    light: online
        ? AgentChipLight.online
        : needsSetup
        ? AgentChipLight.error
        : AgentChipLight.external,
  );
}
