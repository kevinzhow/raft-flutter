// Web v1.24 features/computer/RuntimeLimitResetDialog.tsx (+ limitResetOutcome.ts,
// limitResetAttemptKey.ts): confirm spending one of an account's limit
// resets (Codex), naming the account whose reset it is. The idempotency key
// comes from the card: one per attempt, the same one again when the person
// retries an attempt whose outcome was never learned.
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/runtime_auth.dart';
import 'computers_rack/computers_rack_model.dart' show rackRuntimeDisplayName;
import 'icu_message.dart';

/// What a confirmed limit-reset click learned. [result] null: the request
/// itself failed (timeout, offline, refused), so nothing is known about the
/// account. The card re-reads usage after any of them instead of assuming
/// the limits recovered.
class RuntimeLimitResetOutcome {
  const RuntimeLimitResetOutcome(this.result, this.snapshot);
  final Map<String, dynamic>? result;
  final Map<String, dynamic>? snapshot;
}

/// limitResetOutcomeIsSettled: the outcomes that end the attempt for good;
/// the next click is a new attempt with a new key.
bool limitResetOutcomeIsSettled(Map<String, dynamic>? result) =>
    result != null && result['kind'] != 'unknown';

/// limitResetNoteMessageId: what the card says after an outcome the dialog
/// closes on (the catalog's English text), or null.
String? limitResetNoteSource(Map<String, dynamic> result) =>
    switch (result['kind']) {
      'reset' => 'Limits reset.',
      'nothing_to_reset' => 'Nothing to reset right now. No reset was used.',
      'no_reset' => 'No resets left.',
      'already_redeemed' => 'This reset already went through.',
      _ => null,
    };

/// limitResetFailureMessageId: what the dialog says, staying open, after an
/// outcome the person has to act on (the catalog's English text), or null.
String? limitResetFailureSource(Map<String, dynamic> result) =>
    switch (result['kind']) {
      'reauth_required' =>
        'Sign in to {runtime} again on this Computer. No reset was used.',
      'unsupported' =>
        result['reason'] == 'not_installed'
            ? '{runtime} is not installed on this Computer.'
            : "{runtime} on this Computer can't use a limit reset from here. No reset was used.",
      'unknown' => "We couldn't confirm whether a reset was used. Try again — it won't use a second one.",
      _ => null,
    };

/// limitResetRequestErrorMessageId: why a limit-reset request itself failed
/// (the catalog's English text).
String limitResetRequestErrorSource(Object error) {
  final (:status, :code) = runtimeAuthRequestError(error);
  if (code == 'claude_limit_reset_owner_only') {
    return 'Only the person who connected this Computer can use its Claude resets.';
  }
  if (status == 403) {
    return 'Only the person who connected this Computer, or an owner or admin, can use its resets.';
  }
  if (code == 'computer_offline') {
    return 'This Computer is offline. Connect it, then try again.';
  }
  if (code == 'computer_upgrade_required') {
    return 'Upgrade this Computer to use a reset from here.';
  }
  if (code == 'computer_not_attached') {
    return "This Computer has no owner, so its runtimes can't be signed in from here";
  }
  // The server refused before sending anything to the Computer.
  if (status == 429) {
    return 'Too many attempts on this Computer. No reset was used. Try again in a few minutes.';
  }
  if (code == 'claude_limit_reset_disabled') {
    return "Claude limit resets can't be used here. No reset was used.";
  }
  if (status != null && status >= 400 && status < 500 && status != 408) {
    return 'This request was refused before it reached the Computer. No reset was used.';
  }
  // A timeout, a server error or a dropped connection: the reset may or may
  // not have been spent.
  return "We couldn't confirm whether a reset was used. Try again — it won't use a second one.";
}

/// limitResetAttemptKey.ts: one attempt's idempotency key, kept for the life
/// of the app: after an outcome nobody learned, the person may reopen the
/// dialog before retrying, and a freshly minted key could spend a second
/// reset. Dropped once the Computer answers for good.
class RuntimeLimitResetAttemptKeys {
  RuntimeLimitResetAttemptKeys({String Function()? mint})
    : _mint = mint ?? _uuid;
  static final instance = RuntimeLimitResetAttemptKeys();

  final String Function() _mint;
  final _kept = <String, String>{};

  /// The subject a key belongs to: another server, Computer or provider
  /// never inherits it.
  static String subject(String server, String machine, String provider) =>
      '$server\u0000$machine\u0000$provider';

  String keyFor(String subject) => _kept.putIfAbsent(subject, _mint);
  void forget(String subject) => _kept.remove(subject);

  /// 128 random bits as a UUID v4 (matches `^[A-Za-z0-9_-]{16,128}$`).
  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int from, int to) => bytes
        .sublist(from, to)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}

/// Opens the confirmation to spend one limit reset of [provider]'s account.
/// [account]: the account's (masked) email or name as the card shows it; null
/// when it has none. [onOutcome] hears every answer, including a request that
/// failed (`result` null), so the card can read the usage again.
Future<void> showComputerRuntimeLimitResetDialog(
  BuildContext context, {
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String runtimeId,
  required String provider,
  required String? account,
  required int resetsAvailable,
  required String idempotencyKey,
  required void Function(RuntimeLimitResetOutcome outcome) onOutcome,
}) => showRaftDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialog) => _LimitResetDialog(
    client: client,
    serverId: serverId,
    machineId: machineId,
    runtimeId: runtimeId,
    provider: provider,
    account: account,
    resetsAvailable: resetsAvailable,
    idempotencyKey: idempotencyKey,
    onOutcome: onOutcome,
  ),
);

class _LimitResetDialog extends StatelessWidget {
  const _LimitResetDialog({
    required this.client,
    required this.serverId,
    required this.machineId,
    required this.runtimeId,
    required this.provider,
    required this.account,
    required this.resetsAvailable,
    required this.idempotencyKey,
    required this.onOutcome,
  });
  final RuntimeAuthClient client;
  final String serverId, machineId, runtimeId, provider, idempotencyKey;
  final String? account;
  final int resetsAvailable;
  final void Function(RuntimeLimitResetOutcome outcome) onOutcome;

  static const _marker = '\u0001';

  Future<void> confirm(BuildContext context) async {
    final runtime = rackRuntimeDisplayName(runtimeId);
    ({Map<String, dynamic> result, Map<String, dynamic>? snapshot}) reply;
    try {
      reply = await client.redeemLimitReset(
        serverId,
        machineId,
        provider,
        idempotencyKey,
      );
    } catch (error) {
      onOutcome(const RuntimeLimitResetOutcome(null, null));
      if (!context.mounted) rethrow;
      throw RaftComputerActionError(
        raftFormat(context, limitResetRequestErrorSource(error), {
          'runtime': runtime,
        }),
      );
    }
    onOutcome(RuntimeLimitResetOutcome(reply.result, reply.snapshot));
    final failure = limitResetFailureSource(reply.result);
    if (failure != null) {
      if (!context.mounted) return;
      throw RaftComputerActionError(
        raftFormat(context, failure, {'runtime': runtime}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftConfirmDialog.messageStyle(t);
    final accountLabel = account ?? raftText(context, 'this account');
    // The account is bold: split the message around where it goes.
    final text = icuText(
      context,
      "This uses one of {account}'s resets to restore its {runtime} usage limits now. {count, plural, one {# reset} other {# resets}} left.",
      {
        'account': _marker,
        'runtime': rackRuntimeDisplayName(runtimeId),
        'count': resetsAvailable,
      },
    );
    final parts = text.split(_marker);
    return RaftConfirmDialog(
      surfaceKey: const ValueKey('runtime-limit-reset-dialog'),
      title: raftText(context, 'Use a limit reset?'),
      plainMessage: true,
      maxWidth: 448,
      content: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: parts.first),
            if (parts.length > 1) ...[
              TextSpan(
                text: accountLabel,
                style: TextStyle(color: t.strong, fontWeight: FontWeight.w600),
              ),
              TextSpan(text: parts.sublist(1).join(_marker)),
            ],
          ],
        ),
        key: const ValueKey('runtime-limit-reset-message'),
        style: style,
      ),
      confirmLabel: raftText(context, 'Use a reset'),
      confirmKey: const ValueKey('runtime-limit-reset-confirm'),
      confirmVariant: RaftButtonRecipeVariant.primary,
      loadingLabel: raftText(context, 'Processing…'),
      onConfirm: () => confirm(context),
    );
  }
}
