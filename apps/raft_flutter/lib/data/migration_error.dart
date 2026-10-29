// Web components/agentMigration/errors.ts + presentation.ts: a migration
// failure is never shown as the server's text. The server's `code` selects
// catalog copy (`migration.error.*`); anything unknown falls back to the
// context's generic line. Every value here is the English source string of the
// Web catalog entry; the display layer localizes it with raftText.
//
// The four codes whose Web copy is assembled from wire data (bundle / manifest
// size, entry count, free disk) have their catalog text here in the Web
// message's "no details" branch (the ICU `select` arm for an absent `items` /
// `paths` / sizes); features/agent_migration_presentation.dart parses the wire
// detail and picks the richer arm when it is there.

import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' show RaftUserError;

import 'user_error.dart';

/// Web components/agentMigration/state.ts migrationPhase: null for a state
/// this client does not know.
String? migrationPhase(String? state) => switch (state) {
  'provisioning' ||
  'prep' ||
  'ready' ||
  'in_transit' ||
  'arriving' ||
  'starting' ||
  'cancel_requested_pre_flip' ||
  'cancel_requested_post_flip' => 'active',
  'canceled_pre_flip' || 'canceled_post_flip' => 'canceled',
  'completed' => 'completed',
  'aborted' || 'failed' => 'failed',
  _ => null,
};

/// Web billing.ts `MIGRATION_PRO_PLAN_REQUIRED_CODE`.
const migrationProPlanRequiredCode = 'MIGRATION_PRO_PLAN_REQUIRED';

/// Web billing.ts `isMigrationProPlanRequiredError`: the start route refused
/// because the Server is not on a Pro-capable plan.
bool isMigrationProPlanRequiredError(Object? error) =>
    error is RaftApiException &&
    error.details['code'] == migrationProPlanRequiredCode;

/// Web billing.ts `agentMigrationRequiresUpgrade`. The billing projection is
/// advisory; an unavailable or unrecognized plan must not invent a denial the
/// server cannot confirm. [trialActive] is `isTrialActive(now)`.
bool agentMigrationRequiresUpgrade(Object? plan, {required bool trialActive}) =>
    switch (plan) {
      'pro' || 'founder' || 'partner' => false,
      'free' => !trialActive,
      _ => false,
    };

enum MigrationErrorContext { start, status, failed, aborted, cancel }

const _entryCountLimit =
    'The workspace has too many files and folders to move. Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.';

const _copy = <String, String>{
  'agent_migration_ui_disabled':
      'Agent migration is not enabled on this server.',
  'not_supported':
      "You need permission to migrate agents, or you must be the agent's human creator.",
  'AGENT_NOT_FOUND':
      'This agent is no longer available. Refresh and try again.',
  'TARGET_COMPUTER_REQUIRED':
      'Choose a target computer before starting the migration.',
  'AGENT_HAS_NO_SOURCE_MACHINE':
      "The agent's source computer is unavailable. Reconnect it and try again.",
  'TARGET_COMPUTER_NOT_IN_SERVER':
      'The selected computer is no longer attached to this server. Refresh and choose another computer.',
  'TARGET_COMPUTER_MATCHES_SOURCE':
      "Choose a computer other than the agent's current computer.",
  'COMPUTER_CAPABILITY_INSUFFICIENT':
      'Both computers must run a compatible Raft Computer version and support this agent\'s runtime. Update or reconnect them, or choose another computer, then try again.',
  'MIGRATION_RESUMABLE_CAPABILITY_REQUIRED':
      'One of these computers needs a Raft Computer update before it can move agents. Update Raft Computer on both to the latest version, restart them, wait for them to reconnect, then try again.',
  'TARGET_RUNTIME_DETECTION_PENDING':
      'The target computer is still detecting its runtimes. Try again in a moment.',
  'HOSTED_TARGET_UNAVAILABLE':
      'Moving agents to the cloud is not available on this server right now. Try again later, or move the agent to a computer.',
  'HOSTED_TARGET_ALREADY_USED':
      'This agent has already run in the cloud, so it cannot move there again.',
  'HOSTED_TARGET_MODEL_INVALID':
      'That model is not available for cloud agents on this server. Pick another model, or leave it on the default.',
  'HOSTED_REVIEW_NOT_READY':
      'This migration is not waiting for your confirmation any more. Refresh to see where it stands.',
  'HOSTED_IMPORT_MEMORY_UNIMPORTABLE':
      "The agent's MEMORY.md can't be brought to the cloud: it is too large, is not plain text, or the cloud refused it. Ask the agent to trim MEMORY.md to plain text, then try again.",
  'MIGRATION_NOT_CANCELABLE':
      'The agent already moved to the cloud, so this migration can no longer be canceled.',
  'TARGET_COMPUTER_OFFLINE':
      'The target computer is offline. Start Raft Computer on it and try again.',
  'MIGRATION_ALREADY_IN_PROGRESS':
      'This agent already has a migration in progress. Wait for it to finish before trying again.',
  'MIGRATION_PRO_PLAN_REQUIRED':
      'Agent migration requires the Pro plan. Upgrade this server to Pro before trying again.',
  'MIGRATION_TRANSPORT_NOT_PROVISIONED':
      'Raft could not prepare a secure transfer between these computers. Make sure both computers are online and up to date, then try again.',
  'MIGRATION_TRANSPORT_PROVISION_FAILED':
      'Raft could not prepare the transfer. Make sure both computers are online, then try again.',
  'MIGRATION_TRANSPORT_LOST':
      'The connection between the two computers dropped during the transfer. Make sure both computers are online, then try again.',
  'MIGRATION_WORKSPACE_ALREADY_EXISTS':
      'The target computer could not install the agent because that workspace already exists. Check which copy is current; move or back up the conflicting workspace, then try again. Raft will not delete it automatically.',
  'MIGRATION_WORKSPACE_COMPLETE_OLD_COPY':
      'The target computer found a previously completed copy of this workspace and stopped before replacing it. Confirm which copy is current; move or back up the old copy, then try again. Raft will not delete it automatically.',
  'MIGRATION_CHUNK_DIGEST_MISMATCH': _failedGeneric,
  'MIGRATION_WHOLE_BUNDLE_DIGEST_MISMATCH': _failedGeneric,
  'MIGRATION_LEASE_EXPIRED': _failedGeneric,
  'MIGRATION_GENERATION_STALE': _failedGeneric,
  'MIGRATION_CONTROL_MANIFEST_INVALID':
      'The source computer produced transfer metadata that the target computer could not verify. Update Raft Computer on both computers, then try again.',
  'MIGRATION_CONTROL_MANIFEST_TOO_LARGE': _entryCountLimit,
  'MIGRATION_OBJECT_STORE_ENTRY_COUNT_LIMIT_EXCEEDED': _entryCountLimit,
  'MIGRATION_OBJECT_STORE_BUNDLE_TOO_LARGE':
      'The workspace is too large to move. Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.',
  'MIGRATION_OBJECT_STORE_MANIFEST_TOO_LARGE':
      'The workspace has too many files and folders to move. Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.',
  'MIGRATION_OBJECT_STORE_INSUFFICIENT_DISK':
      'The target computer does not have enough free disk space to stage and install this migration. Free disk space and try again.',
  'MIGRATION_REF_INVALID':
      'The migration reference is missing or invalid. Refresh the migration status before trying again.',
  'MIGRATION_REVISION_INVALID':
      'The migration status is incomplete. Refresh before trying to cancel again.',
  'MIGRATION_NOT_FOUND':
      'This migration is no longer available. Refresh the migration status.',
  'MIGRATION_REVISION_STALE':
      'The migration changed before this action completed. Refresh and try again.',
  'MIGRATION_CONCURRENT_UPDATE':
      'The migration changed concurrently. Refresh and try again.',
  'MIGRATION_CANCEL_FAILED':
      'Raft could not request cancellation. Refresh the migration status and try again.',
  'MIGRATION_START_FAILED':
      'The migration could not be started. Check both computers and try again.',
  'MIGRATION_STATUS_FAILED':
      'Migration status could not be loaded. Refresh and try again.',
};

const _failedGeneric = 'The transfer did not finish. Try again.';

const _abortReasons = <String, String>{
  'prep-deadline':
      'Preparing the workspace on the source computer stopped making progress before the deadline. Make sure the source is online, then try again.',
  'transfer-deadline':
      'The workspace transfer did not finish before the deadline. Make sure both computers stay online and the target has enough free disk space, then try again.',
  'arrival-deadline':
      'The target computer did not finish installing the workspace before the deadline. Make sure the target is running and has enough free disk space, then try again.',
};

const _abortedFallback =
    'The migration stopped before it completed. Review the technical reason, then try again.';

String _fallback(MigrationErrorContext context, String? reason) =>
    switch (context) {
      MigrationErrorContext.status => _copy['MIGRATION_STATUS_FAILED']!,
      MigrationErrorContext.aborted =>
        _abortReasons[reason] ?? _abortedFallback,
      MigrationErrorContext.failed => _failedGeneric,
      MigrationErrorContext.start ||
      MigrationErrorContext.cancel => _copy['MIGRATION_START_FAILED']!,
    };

final _safeTechnicalCode = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{1,127}$');

/// Catalog copy for a migration [code] (`migrationErrorPresentation`); unknown
/// or absent codes give the [context]'s generic line.
String migrationCodeText(
  String? code,
  MigrationErrorContext context, {
  String? reason,
}) => _copy[code] ?? _fallback(context, reason);

/// Whether [code] has dedicated catalog copy (Web errors.ts `Object.hasOwn`
/// over the copy tables).
bool migrationHasCopy(String? code) => _copy.containsKey(code);

/// English source text for a failed migration request ([error] is what the
/// API call threw). The server's own sentence is never shown.
String migrationErrorText(Object error, MigrationErrorContext context) {
  final code = error is RaftApiException ? error.details['code'] : null;
  logUserError(error, where: 'agent migration');
  return migrationCodeText(code is String ? code : null, context);
}

/// Web AgentMigrationCancelDialog: the stale / generic cancel copy; the safe
/// technical code, when there is one, is appended as `message (CODE)`.
({String message, String suffix}) migrationCancelErrorParts(Object error) {
  final code = error is RaftApiException ? error.details['code'] : null;
  logUserError(error, where: 'agent migration cancel');
  final stale =
      code == 'MIGRATION_REVISION_STALE' ||
      code == 'MIGRATION_CONCURRENT_UPDATE';
  return (
    message: stale
        ? 'The migration moved on before your request went through. Check the latest status and try again.'
        : "Couldn't cancel the migration. The status has been refreshed. Keep both computers online and try again.",
    suffix: code is String && _safeTechnicalCode.hasMatch(code)
        ? ' ($code)'
        : '',
  );
}

/// [migrationCancelErrorParts] as one English string.
String migrationCancelErrorText(Object error) {
  final parts = migrationCancelErrorParts(error);
  return '${parts.message}${parts.suffix}';
}

/// [migrationCancelErrorParts] as a user error whose code suffix is added
/// after the message is localized.
RaftUserError migrationCancelUserError(Object error) {
  final parts = migrationCancelErrorParts(error);
  return RaftUserError(parts.message, suffix: parts.suffix);
}
