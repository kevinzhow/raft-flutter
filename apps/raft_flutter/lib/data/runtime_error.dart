// Web utils/classifyRuntimeError.ts: runtime errors are recognised only by
// enumerable, stable patterns and mapped to catalog copy; anything else stays
// unclassified so the caller falls back to the generic message (arbitrary
// server English is never "translated" by substring).

enum RuntimeErrorKind { notLoggedIn, notInstalled, authFailed, toolArgsInvalid }

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
  if (reason == 'auth_failed' || errorClass == 'AuthError') {
    return RuntimeErrorKind.authFailed;
  }
  if (reason == 'model_tool_args_invalid' ||
      errorClass == 'ToolArgumentParseError') {
    return RuntimeErrorKind.toolArgsInvalid;
  }
  return null;
}

/// `RUNTIME_ERROR_LABEL_ID`: the English catalog string per kind
/// (`agent.runtimeError.*`).
String runtimeErrorText(RuntimeErrorKind kind) => switch (kind) {
  RuntimeErrorKind.notLoggedIn =>
    'This runtime is not logged in on this computer.',
  RuntimeErrorKind.notInstalled =>
    'This runtime is not installed on this computer.',
  RuntimeErrorKind.authFailed => 'Runtime authentication failed.',
  RuntimeErrorKind.toolArgsInvalid => 'The model produced tool-call arguments in an invalid format, so Codex rejected the tool call — try a different model.',
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

/// Web `formatSpawnFailureDetail` (utils/activity.ts): the text of a failed
/// start, chosen by its typed reason and never by parsing the daemon's
/// [daemonDetail]. `model_not_found` has catalog copy; other reasons keep the
/// daemon's message. While the server has paused automatic restarts it says so
/// and how to lift it. Null when there is nothing to replace. [translate]
/// localizes an English catalog source and fills its `{values}`.
String? spawnFailureDetailText(
  Map<String, dynamic>? spawnFailure,
  String daemonDetail,
  String Function(String source, Map<String, Object?> values) translate,
) {
  if (spawnFailure == null) return null;
  final reason = spawnFailure['reason'];
  // Restarting resumes the same stuck session, so the generic paused copy
  // ("...or restart the agent") would send people the wrong way.
  if (reason == 'session_needs_reset') {
    return translate(
      "This agent's conversation no longer fits its model, and context compaction failed several times in a row, so restarting would fail again. To start a new session, open Restart / Reset and choose Reset Session & Restart (Reset Model for members). Raft messages and workspace files, including MEMORY.md, are kept",
      const {},
    );
  }
  final modelNotFound = reason == 'model_not_found';
  final detail = modelNotFound
      ? translate(
          'Model "{model}" is not available for this runtime — it may have been renamed or removed, or its provider has no API key on this computer. Pick another model or fix the key in the agent settings',
          {'model': spawnFailure['model'] ?? '?'},
        )
      : daemonDetail;
  if (spawnFailure['autoRestartPaused'] != true) {
    return modelNotFound ? detail : null;
  }
  return translate(
    '{detail} — automatic restarts are paused until you change the model or API key, or restart the agent',
    {'detail': detail},
  );
}
