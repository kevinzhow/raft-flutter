// Web utils/classifyRuntimeError.ts: runtime errors are recognised only by
// enumerable, stable patterns and mapped to catalog copy; anything else stays
// unclassified so the caller falls back to the generic message (arbitrary
// server English is never "translated" by substring).

// Source: Web v1.24.0 packages/web/src/utils/classifyRuntimeError.ts and
// packages/shared/src/runtimeErrorVisibility.ts.

/// `billingExhausted` is typed-only like `toolArgsInvalid` (the daemon
/// classifies the provider's 402 into `BillingError` / `billing_exhausted`;
/// the client never reads the 402 text). `rootPrivileges` is the typed
/// `errorReason` `root_privileges`.
enum RuntimeErrorKind {
  notLoggedIn,
  notInstalled,
  authFailed,
  toolArgsInvalid,
  rootPrivileges,
  billingExhausted,
}

final _patterns = <(RuntimeErrorKind, RegExp)>[
  (
    RuntimeErrorKind.notLoggedIn,
    RegExp('is not logged in', caseSensitive: false),
  ),
  (
    RuntimeErrorKind.notInstalled,
    RegExp('not installed', caseSensitive: false),
  ),
  (
    RuntimeErrorKind.authFailed,
    RegExp(
      r'(?:auth(?:entication|orization)? (?:failed|error|invalid)|invalid api key|unauthorized)',
      caseSensitive: false,
    ),
  ),
];

/// `classifyRuntimeError(message)`. `toolArgsInvalid` is reachable only from the
/// typed carrier ([classifyTypedRuntimeError]), never from message text.
RuntimeErrorKind? classifyRuntimeError(String message) {
  for (final (kind, re) in _patterns) {
    if (re.hasMatch(message)) return kind;
  }
  return null;
}

/// The authoritative typed diagnostic (`lastRuntimeError.errorClass` /
/// `errorReason`) the daemon and server persisted.
RuntimeErrorKind? classifyTypedRuntimeError(Object? lastRuntimeError) {
  if (lastRuntimeError is! Map) return null;
  final errorClass = lastRuntimeError['errorClass'];
  final reason = lastRuntimeError['errorReason'];
  if (errorClass is! String ||
      errorClass.isEmpty ||
      reason is! String ||
      reason.isEmpty) {
    return null;
  }
  if (reason == 'root_privileges') return RuntimeErrorKind.rootPrivileges;
  if (reason == 'auth_failed' || errorClass == 'AuthError') {
    return RuntimeErrorKind.authFailed;
  }
  if (reason == 'model_tool_args_invalid' ||
      errorClass == 'ToolArgumentParseError') {
    return RuntimeErrorKind.toolArgsInvalid;
  }
  if (reason == 'billing_exhausted' || errorClass == 'BillingError') {
    return RuntimeErrorKind.billingExhausted;
  }
  return null;
}

/// `RUNTIME_ERROR_LABEL_ID`: the English catalog string per kind
/// (`agent.runtimeError.*`).
String runtimeErrorText(RuntimeErrorKind kind) => switch (kind) {
  RuntimeErrorKind.notLoggedIn =>
    'This runtime is not signed in on this computer.',
  RuntimeErrorKind.notInstalled =>
    'This runtime is not installed on this computer.',
  RuntimeErrorKind.authFailed => 'Runtime authentication failed.',
  RuntimeErrorKind.toolArgsInvalid => 'The model produced tool-call arguments in an invalid format, so Codex rejected the tool call — try a different model.',
  RuntimeErrorKind.rootPrivileges => 'Claude Code cannot start with root or sudo privileges while permission checks are disabled. Run Raft Computer as a non-root user, then start the agent again.',
  // The billing banner's title; the panel adds its body and one action.
  RuntimeErrorKind.billingExhausted => 'Model service balance too low',
};

/// What a member reads in place of an uncoded runtime error's text
/// (`GENERIC_RUNTIME_ERROR_MESSAGE`).
const genericRuntimeErrorMessage = 'Agent encountered an error';

/// Web `RUNTIME_ERROR_CODES`: the closed list of codes every viewer receives.
const runtimeErrorCodes = {
  'usage_limit',
  'billing',
  'model_unavailable',
  'auth_required',
  'network_timeout',
  'input_too_large',
  'message_too_large',
};

/// Web `isRuntimeErrorCode`: an unknown code (a newer server) is no code.
bool isRuntimeErrorCode(Object? value) =>
    value is String && runtimeErrorCodes.contains(value);

/// The catalog copy of one code (`RUNTIME_ERROR_CODE_MESSAGE_ID`): a short
/// title for status rows, the sentence a member reads, and the sentence the
/// agent's managers read above the scrubbed detail.
typedef RuntimeErrorCodeCopy = ({String title, String member, String manager});

/// `agent.runtimeError.code.*` in English; null for no code or an unknown one.
RuntimeErrorCodeCopy? runtimeErrorCodeCopy(Object? code) => switch (code) {
  'usage_limit' => (
    title: 'Usage limit reached',
    member: "The agent's model provider usage limit has been reached. Wait for the limit to reset, or ask the agent's owner to switch it to another model or account.",
    manager: "The model provider's usage limit has been reached. Wait for the limit to reset, or switch the agent to another model or account in its settings.",
  ),
  'billing' => (
    title: 'Provider balance exhausted',
    member: "The agent's model provider billing or credit balance is exhausted. Ask the agent's owner to add credits or switch it to another model or provider.",
    manager: "The model provider's billing or credit balance is exhausted. Add credits with the provider, or switch the agent to another model or provider in its settings.",
  ),
  'model_unavailable' => (
    title: 'Model not available',
    member: "The agent's configured model is not available to its provider account. Ask the agent's owner to choose another model or change the plan.",
    manager: "The agent's model is not available to its provider account. Choose another model in the agent's settings, or change the plan.",
  ),
  'auth_required' => (
    title: 'Sign-in required',
    member: "The agent's runtime is not signed in, or its provider credential was rejected. Ask the agent's owner to sign in again or update the credential.",
    manager: "The agent's runtime is not signed in, or its provider credential was rejected. Sign in again on the agent's computer, or update the credential.",
  ),
  'network_timeout' => (
    title: 'Provider unreachable',
    member: "The agent could not reach its model provider, or the request timed out. Try again later; if it keeps happening, ask the agent's owner to check the computer's network.",
    manager: "The agent could not reach its model provider, or the request timed out. Try again later; if it keeps happening, check the network on the agent's computer.",
  ),
  'input_too_large' => (
    title: 'Input too large',
    member: "The agent's input is larger than its model accepts. Ask the agent's owner to reset the session or reduce the startup context.",
    manager: "The agent's input is larger than its model accepts. Reset the session, or reduce the startup context.",
  ),
  'message_too_large' => (
    title: 'Message too long',
    member: 'A message to the agent was too long for its runtime to take at once, so it was not delivered. Shorten it, or split it into several messages.',
    manager: "A message was too long for this agent's runtime to take at once, so it was not delivered. Shorten it, or split it into several messages, and send again.",
  ),
  _ => null,
};

/// Web `RuntimeLookupDisplay`: a runtime lookup failure (`runtime_not_found`)
/// now says why the lookup missed. Only a confirmed miss keeps the install
/// guidance; a timeout, a permission denial and an unresolved failure each get
/// their own wording, and an absent reason (an old daemon) is unresolved too.
/// Uncertainty never reads as "install it".
enum RuntimeLookupDisplay {
  confirmedMissing,
  timeout,
  permissionDenied,
  unconfirmed,
}

/// Detection reasons (`not_installed`, `probe_timeout`, `permission_denied`,
/// `probe_failed`) and launch reasons (`not_on_path`, `lookup_timed_out`,
/// `lookup_permission_denied`, `lookup_failed`).
const runtimeModelLookupReasons = {
  'not_installed',
  'probe_timeout',
  'permission_denied',
  'probe_failed',
};
const spawnFailureLookupReasons = {
  'not_on_path',
  'lookup_timed_out',
  'lookup_permission_denied',
  'lookup_failed',
};

RuntimeLookupDisplay runtimeLookupDisplayForReason(String? reason) =>
    switch (reason) {
      'not_installed' || 'not_on_path' => RuntimeLookupDisplay.confirmedMissing,
      'probe_timeout' || 'lookup_timed_out' => RuntimeLookupDisplay.timeout,
      'permission_denied' ||
      'lookup_permission_denied' => RuntimeLookupDisplay.permissionDenied,
      _ => RuntimeLookupDisplay.unconfirmed,
    };

/// The English catalog string of a lookup display that is not a confirmed
/// miss (`agent.runtimeModels.runtimeLookup*`); `{runtimeName}` is filled by
/// the caller.
String runtimeLookupText(RuntimeLookupDisplay display) => switch (display) {
  RuntimeLookupDisplay.confirmedMissing =>
    '{runtimeName} was not found on this Computer. Install it, then retry.',
  RuntimeLookupDisplay.timeout => "Checking for {runtimeName} on this Computer timed out. Retry, or check this Computer's status.",
  RuntimeLookupDisplay.permissionDenied => 'Could not check for {runtimeName} on this Computer: permission denied. Check permissions on that machine, then retry.',
  RuntimeLookupDisplay.unconfirmed => "Could not confirm whether {runtimeName} is available on this Computer. Retry, or check this Computer's status.",
};

/// The agent page banner's copy for a lookup display (Web
/// `RUNTIME_LOOKUP_DISPLAY_MESSAGE_ID`): a confirmed miss names the runtime and
/// the ways out (`agent.runtimeError.notInstalledNamed`); the rest are the
/// shared lookup copy.
String runtimeLookupBannerText(RuntimeLookupDisplay display) =>
    display == RuntimeLookupDisplay.confirmedMissing
    ? "{runtimeName} is not installed on this Computer. Install it there, move the agent to a Computer that has it, or switch the agent's runtime."
    : runtimeLookupText(display);

/// Web `activityState.spawnFailure.lookupReason`: how the daemon's PATH lookup
/// ended when a start failed with `runtime_not_found`. Only meaningful on the
/// `runtime_unavailable` state; absent (or unknown) is "no verdict", which the
/// display reads as unconfirmed, never as a confirmed miss.
String? spawnLookupReason(Object? detailKind, Object? spawnFailure) =>
    detailKind == 'runtime_unavailable' &&
        spawnFailure is Map &&
        spawnFailure['reason'] == 'runtime_not_found' &&
        spawnFailureLookupReasons.contains(spawnFailure['lookupReason'])
    ? spawnFailure['lookupReason'] as String
    : null;

/// Web `activityState.spawnFailure`: the typed carrier of a failed start,
/// kept only while the state is the `runtime_unavailable` frame (agentStore).
/// Null when the state is something else or the carrier is absent or malformed.
Map<String, dynamic>? spawnFailureCarrier(
  Object? detailKind,
  Object? spawnFailure,
) =>
    detailKind == 'runtime_unavailable' &&
        spawnFailure is Map &&
        spawnFailure['reason'] is String
    ? Map<String, dynamic>.from(spawnFailure)
    : null;

/// Web `formatSpawnFailureDetail` (utils/activity.ts, v1.24.0): the text of a
/// failed start, chosen by its typed reason and never by parsing the daemon's
/// [daemonDetail]. Reasons with their own copy replace the daemon's English
/// text; others keep it, and while the server has paused automatic restarts
/// it says so and how to lift it. Null when there is nothing to replace.
/// [translate] localizes an English catalog source and fills its `{values}`.
/// [retryTime] formats `pauseRetryAtMs` (the next automatic try) in the
/// viewer's zone, or null when it has passed.
String? spawnFailureDetailText(
  Map<String, dynamic>? spawnFailure,
  String daemonDetail,
  String Function(String source, Map<String, Object?> values) translate, {
  String? Function(int atMs)? retryTime,
}) {
  if (spawnFailure == null) return null;
  final reason = spawnFailure['reason'];
  final model = spawnFailure['model'];
  final at = spawnFailure['pauseRetryAtMs'];
  final time = at is num && retryTime != null ? retryTime(at.toInt()) : null;
  // Restarting resumes the same stuck session, so the generic paused copy
  // ("...or restart the agent") would send people the wrong way.
  if (reason == 'session_needs_reset') {
    return translate(
      "The context is too large and shrinking it automatically didn't fix it. Reset the session and restart; if one message is itself very large, switch to a model with a larger context or split the content.",
      const {},
    );
  }
  // The fix is the same paused or not (paste the key again).
  if (reason == 'provider_api_key_invalid') {
    return translate(
      "Couldn't start: there's a problem with the API key. Copy the full key again from your provider's dashboard, save, and retry.",
      const {},
    );
  }
  // The runtime started and said it cannot use the agent's model; only a
  // person gets out of it, so the copy says what to do and nothing about
  // retrying.
  if (reason == 'model_unsupported') {
    return model is String && model.isNotEmpty
        ? translate(
            'This runtime\'s account or plan doesn\'t include "{model}". Change the model, or sign in with an account that includes it',
            {'model': model},
          )
        : translate(
            "This runtime's account or plan doesn't include this agent's model. Change the model, or sign in with an account that includes it",
            const {},
          );
  }
  // The runtime started and kept failing the same way; the server pauses at
  // the first report and tries again by itself after a cooldown.
  if (reason == 'runtime_repeated_failure') {
    return time != null
        ? translate(
            'Kept failing the same way after starting — automatic wakes are paused; Raft tries again by itself at {time}. Restart the agent to try now',
            {'time': time},
          )
        : translate(
            'Kept failing the same way after starting — automatic wakes are paused; Raft tries again by itself later. Restart the agent to try now',
            const {},
          );
  }
  final modelNotFound = reason == 'model_not_found';
  final detail = modelNotFound
      ? translate(
          'Model "{model}" is not available for this runtime — it may have been renamed or removed, or its provider has no API key on this computer. Pick another model or fix the key in the agent settings',
          {'model': model ?? '?'},
        )
      : daemonDetail;
  if (spawnFailure['autoRestartPaused'] != true) {
    return modelNotFound ? detail : null;
  }
  // The computer does not have the runtime: changing the model or restarting
  // will not help, getting the runtime there or switching runtime will.
  if (reason == 'runtime_not_found') {
    return translate(
      '{detail} — automatic wakes are paused until the runtime is available on this computer, or you move the agent or switch its runtime',
      {'detail': detail},
    );
  }
  // The server tries a start-timeout pause again by itself after a cooldown.
  if (reason == 'runtime_start_timeout') {
    return time != null
        ? translate(
            '{detail} — automatic wakes are paused; Raft tries again by itself at {time}. Restart the agent or switch its model to resume now',
            {'detail': detail, 'time': time},
          )
        : translate(
            '{detail} — automatic wakes are paused; Raft tries again by itself later. Restart the agent or switch its model to resume now',
            {'detail': detail},
          );
  }
  return translate(
    '{detail} — automatic restarts are paused until you change the model or API key, or restart the agent',
    {'detail': detail},
  );
}

/// Source store/events/activityTypedCarriers.ts attachSocketTypedCarriers
/// (Web v1.24.0): the typed carriers of one `agent:activity` frame, each kept
/// beside the state it describes and null otherwise (a later plain frame drops
/// them, like Web's fresh `nextActivity`). Merged into the directory row by
/// the activity patch, under the REST rows' names (`activityErrorCode`).
///
/// - `credentialHold`: the held notice's reason, only on an idle frame.
/// - `activityErrorCode`: the error's code (a known one), only on an error.
/// - `deliveryConsumption` / `wakeCrashLoop`: only on their own detail kind.
Map<String, dynamic> activityStatusCarriers({
  required Object? activity,
  required String detailKind,
  required Map payload,
}) {
  Map<String, dynamic>? carrier(String key) {
    final value = payload[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  final hold = payload['credentialHold'];
  final reason = hold is Map ? hold['reason'] : null;
  return {
    'credentialHold':
        detailKind == 'idle' &&
            reason is String &&
            const {
              'user_reauth',
              'user_model_access',
              'billing',
            }.contains(reason)
        ? {'reason': reason}
        : null,
    'activityErrorCode':
        activity == 'error' && isRuntimeErrorCode(payload['errorCode'])
        ? payload['errorCode']
        : null,
    'deliveryConsumption': detailKind == 'delivery_unconsumed'
        ? carrier('deliveryConsumption')
        : null,
    'wakeCrashLoop': detailKind == 'wake_crash_loop_blocked'
        ? carrier('wakeCrashLoop')
        : null,
  };
}
