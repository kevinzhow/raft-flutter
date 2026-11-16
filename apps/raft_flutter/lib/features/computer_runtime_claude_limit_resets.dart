// Web v1.24 features/computer/useClaudeLimitResets.tsx,
// ClaudeLimitResetsDialog.tsx and claudeLimitResetCopy.ts: Claude limit
// resets on the runtime usage card (flag `claude_limit_reset`). What the card
// offers (View available resets, Use 5-hour reset), the list of the kinds the
// account holds (read on the Computer only when the person asks, behind a
// consent at the 5-hour limit) and the confirm that uses one kind.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';
import 'computer_runtime_limit_reset_dialog.dart';
import 'icu_message.dart';

const claudeLimitResetFlag = 'claude_limit_reset';
const claudeLimitResetKinds = ['five_hour', 'weekly', 'fable', 'full'];

/// Web `useServerFeatureFlag(CLAUDE_LIMIT_RESET_FEATURE_FLAG_KEY)`: off until
/// evaluated and on failure; evaluated once per account / server.
class ClaudeLimitResetFlag {
  ClaudeLimitResetFlag._(this.w);
  static final _flags = Expando<ClaudeLimitResetFlag>('claude limit reset');
  static ClaudeLimitResetFlag of(WorkspaceController w) {
    final source = w.presentationSource ?? w;
    return _flags[source] ??= ClaudeLimitResetFlag._(source);
  }

  final WorkspaceController w;
  String? _scope;
  Future<void>? _pending;
  bool _enabled = false;

  String get _current =>
      '${w.client.origin}|${w.client.generation}|${w.client.user?.id}|'
      '${w.client.serverId}';

  bool get enabled => _scope == _current && _enabled;

  Future<void> ensure() {
    final scope = _current;
    if (_scope == scope) return Future.value();
    return _pending ??= _evaluate(scope).whenComplete(() => _pending = null);
  }

  Future<void> _evaluate(String scope) async {
    final serverId = w.client.serverId;
    if (serverId == null) return;
    var on = false;
    try {
      final result = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: const [claudeLimitResetFlag],
          serverId: serverId,
        ),
      );
      on =
          result is Map &&
          (result['evaluations'] as List? ?? const []).whereType<Map>().any(
            (f) => f['key'] == claudeLimitResetFlag && f['enabled'] == true,
          );
    } catch (_) {
      // Unknown stays off.
    }
    if (_current != scope) return;
    _scope = scope;
    _enabled = on;
  }
}

/// claudeFiveHourLimitOf: Claude's one account reads at its 5-hour limit.
/// `at_limit` | `not_at_limit` | `unknown`.
String claudeFiveHourLimitOf(Map<String, dynamic>? snapshot) {
  final accounts = snapshot?['accounts'];
  if (snapshot?['provider'] != 'claude' ||
      accounts is! List ||
      accounts.length != 1 ||
      accounts.single is! Map) {
    return 'unknown';
  }
  final account = accounts.single as Map;
  if (account['health'] != 'ok' && account['health'] != 'rate_limited') {
    return 'unknown';
  }
  final windows = [
    for (final w in (account['windows'] as List? ?? const []))
      if (w is Map && w['label'] == 'Current session') w,
  ];
  if (windows.length != 1) return 'unknown';
  final window = windows.single;
  if (window['status'] == 'limit_reached') return 'at_limit';
  final used = window['usedRatio'];
  if (window['status'] == 'ok' && used is num && used < 1) {
    return 'not_at_limit';
  }
  return 'unknown';
}

// --- claudeLimitResetCopy.ts ---

String claudeKindName(BuildContext context, String kind) =>
    raftText(context, switch (kind) {
      'five_hour' => '5-hour reset',
      'weekly' => 'weekly reset',
      'fable' => 'Fable reset',
      _ => 'full reset',
    });

/// What the card says once a Claude redeem has an answer the dialog closes
/// on; null: the dialog stays open and says why nothing was used.
String? claudeLimitResetNote(
  BuildContext context,
  String kind,
  Map<String, dynamic> result,
) {
  final name = claudeKindName(context, kind);
  return switch (result['kind']) {
    'reset' => raftFormat(context, 'Used your {kind}.', {'kind': name}),
    'nothing_to_reset' ||
    'already_redeemed' => raftText(context, limitResetNoteSource(result)!),
    'no_reset' => raftFormat(context, 'No {kind} to use. No reset was used.', {
      'kind': name,
    }),
    'unknown' =>
      result['fiveHourSpent'] == true
          ? raftFormat(
              context,
              "Your 5-hour reset was used instead of the {kind}: this account has only Claude's older once-a-week 5-hour reset.",
              {'kind': name},
            )
          : raftText(
              context,
              "We couldn't confirm whether a reset was used. Check /usage in Claude Code before trying again.",
            ),
    _ => null,
  };
}

/// claudeLimitResetsNotSupportedHere: the Computer cannot run Claude limit
/// resets at all (macOS, a Claude Code without the command).
bool claudeLimitResetsNotSupportedHere(Map<String, dynamic> result) {
  if (result['kind'] != 'unsupported') return false;
  return switch (result['reason']) {
    'not_attempted' ||
    'not_installed' ||
    'consent_required' ||
    'capability_unavailable' => false,
    _ => true,
  };
}

/// claudeLimitResetRefusal: why nothing was used, for an answer the confirm
/// stays open on.
String claudeLimitResetRefusal(
  BuildContext context,
  String kind,
  Map<String, dynamic> result,
  bool atFiveHourLimit,
) {
  final name = claudeKindName(context, kind);
  if (result['kind'] == 'reauth_required') {
    return raftFormat(
      context,
      'Sign in to {runtime} again on this Computer. No reset was used.',
      {'runtime': 'Claude Code'},
    );
  }
  if (result['kind'] == 'unsupported') {
    switch (result['reason']) {
      case 'not_attempted':
        return atFiveHourLimit && kind != 'five_hour'
            ? raftFormat(
                context,
                'Nothing was used. At your 5-hour limit, only a 5-hour reset can be used from here. To use your {kind} now, go to Settings › Usage on claude.ai.',
                {'kind': name},
              )
            : raftText(
                context,
                'Nothing was used: the Computer was busy or ran out of time. Try again.',
              );
      case 'not_installed':
        return raftFormat(
          context,
          '{runtime} is not installed on this Computer.',
          {'runtime': 'Claude Code'},
        );
      case 'capability_unavailable':
        return raftFormat(
          context,
          "Your {kind} isn't available for this account on this Computer yet. No reset was used.",
          {'kind': name},
        );
      default:
        return _notSupportedHere(context);
    }
  }
  return raftText(
    context,
    "We couldn't confirm whether a reset was used. Check /usage in Claude Code before trying again.",
  );
}

String _notSupportedHere(BuildContext context) => raftText(
  context,
  "Claude limit resets aren't supported on this Computer. No reset was used.",
);

String claudeKindMeta(BuildContext context, Map status) {
  switch (status['state']) {
    case 'available':
      final left = status['resetsLeft'];
      final expires = status['expiresText'];
      return [
        left is num
            ? icuText(context, '{count, plural, one {# left} other {# left}}', {
                'count': left.toInt(),
              })
            : raftText(context, 'Available'),
        if (expires is String && expires.isNotEmpty)
          raftFormat(context, 'use by {date}', {'date': expires}),
      ].join(' · ');
    case 'none':
      return raftText(context, 'None');
    case 'not_checked':
      return raftText(context, 'Not checked yet');
    case 'not_offered':
      return raftText(context, 'Not on this account');
    default:
      return raftText(context, "Couldn't read");
  }
}

/// What a confirmed Claude redeem learned, for the card.
class ClaudeLimitResetOutcome extends RuntimeLimitResetOutcome {
  const ClaudeLimitResetOutcome(
    this.kind,
    super.result,
    super.snapshot,
    this.note,
  );
  final String kind;
  final String? note;
}

/// useClaudeLimitResets: the card's Claude state and its dialogs, for one
/// chip. [subject] is server, Computer and provider: keys and notes never
/// cross them.
class ClaudeLimitResets {
  ClaudeLimitResets({
    required this.context,
    required this.mounted,
    required this.client,
    required this.serverId,
    required this.machineId,
    required this.subject,
    required this.onNote,
    required this.showUsageAfterReset,
    required this.refresh,
    required this.changed,
  });

  final BuildContext Function() context;
  final bool Function() mounted;
  final RuntimeAuthClient Function() client;
  final String Function() serverId, machineId, subject;
  final void Function(String note) onNote;
  final void Function(RuntimeLimitResetOutcome outcome) showUsageAfterReset;
  final void Function() refresh, changed;

  // The Claude account a read or a redeem showed on the older once-a-week
  // 5-hour program: at the 5-hour limit its card offers only "Use 5-hour
  // reset", since opening the list there would use it.
  String? _legacyAccount;
  // The Computer answered that Claude limit resets cannot run there.
  String? _notSupportedSubject;

  Map? _account(Map<String, dynamic>? snapshot) {
    if (snapshot == null || snapshot['provider'] != 'claude') return null;
    final accounts = snapshot['accounts'];
    if (accounts is! List || accounts.isEmpty) return null;
    final first = accounts.first;
    return first is Map ? first : null;
  }

  String? _accountLabel(Map<String, dynamic>? snapshot) {
    final a = _account(snapshot);
    return (a?['maskedLabel'] ?? a?['displayName']) as String?;
  }

  String _legacySubject(Map<String, dynamic>? snapshot) =>
      '${subject()}\u0000${_account(snapshot)?['accountKey'] ?? ''}';

  /// The card's Claude actions (Web `surfaceClaudeLimitReset`), or null.
  RaftRuntimeClaudeLimitReset? surface({
    required bool claude,
    required bool flagOn,
    required bool canAct,
    required bool loggedOut,
    required RuntimeAuthView? view,
    required Map<String, dynamic>? snapshot,
  }) {
    if (!claude || !flagOn || !canAct || loggedOut) return null;
    final state = view?.claudeLimitResets;
    if (state == null || _notSupportedSubject == subject()) return null;
    // Web draws nothing for a Computer that needs an upgrade (the surface
    // state carries no action and no sentence).
    if (state == 'computer_upgrade_required') {
      return const RaftRuntimeClaudeLimitReset();
    }
    final atLimit = claudeFiveHourLimitOf(snapshot) == 'at_limit';
    final canUse = view?.claudeLimitResetCanUse ?? true;
    final legacyAtLimit = atLimit && _legacyAccount == _legacySubject(snapshot);
    return RaftRuntimeClaudeLimitReset(
      onView: legacyAtLimit
          ? null
          : () => _openList(snapshot, atLimit, canUse, view!),
      onUseFiveHour: atLimit && canUse
          ? () => _openConfirm('five_hour', snapshot, atLimit, fromList: false)
          : null,
      ownerOnly: !canUse,
    );
  }

  void _openList(
    Map<String, dynamic>? snapshot,
    bool atLimit,
    bool canUse,
    RuntimeAuthView view,
  ) {
    if (!mounted()) return;
    final legacySubject = _legacySubject(snapshot);
    final subjectNow = subject();
    unawaited(
      showComputerClaudeLimitResetsDialog(
        context(),
        client: client(),
        serverId: serverId(),
        machineId: machineId(),
        atFiveHourLimit: atLimit,
        canUse: canUse,
        canConsent: view.claudeLimitResetCanConsent,
        onLegacy: (spent) {
          _legacyAccount = legacySubject;
          if (spent) refresh();
          if (mounted()) changed();
        },
        onNotSupported: () {
          _notSupportedSubject = subjectNow;
          if (mounted()) changed();
        },
        onUse: (dialog, kind) =>
            _openConfirm(kind, snapshot, atLimit, fromList: true, from: dialog),
      ),
    );
  }

  /// Opens the confirm of [kind]; true once it closed on an answer.
  Future<bool> _openConfirm(
    String kind,
    Map<String, dynamic>? snapshot,
    bool atLimit, {
    required bool fromList,
    BuildContext? from,
  }) async {
    final target = from ?? context();
    if (!target.mounted) return false;
    final subjectNow = subject();
    final attempt = '$subjectNow\u0000$kind';
    final key = RuntimeLimitResetAttemptKeys.instance.keyFor(attempt);
    var done = false;
    await showComputerClaudeLimitResetConfirmDialog(
      target,
      client: client(),
      serverId: serverId(),
      machineId: machineId(),
      kind: kind,
      account: _accountLabel(snapshot),
      atFiveHourLimit: atLimit,
      idempotencyKey: key,
      overModal: fromList,
      onOutcome: (outcome) {
        // Any answer ends the attempt (the Computer remembers a key only until
        // it restarts); a request that got no answer keeps the key for a retry.
        if (outcome.result != null) {
          RuntimeLimitResetAttemptKeys.instance.forget(attempt);
        }
        if (outcome.result?['kind'] == 'unknown' &&
            outcome.result?['fiveHourSpent'] == true) {
          _legacyAccount = _legacySubject(snapshot);
        }
        if (outcome.result != null &&
            claudeLimitResetsNotSupportedHere(outcome.result!)) {
          _notSupportedSubject = subjectNow;
        }
        if (!mounted() || subjectNow != subject()) return;
        if (outcome.note != null) {
          done = true;
          onNote(outcome.note!);
        }
        if (outcome.result != null) showUsageAfterReset(outcome);
        changed();
      },
    );
    return done;
  }
}

/// Confirms using one kind of reset, naming the kind and the account, and
/// that it cannot be undone (ClaudeLimitResetConfirmDialog).
Future<void> showComputerClaudeLimitResetConfirmDialog(
  BuildContext context, {
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String kind,
  required String? account,
  required bool atFiveHourLimit,
  required String idempotencyKey,
  required void Function(ClaudeLimitResetOutcome outcome) onOutcome,
  bool overModal = false,
}) => RaftConfirmDialog.show(
  context,
  _confirmDialog(
    context,
    client: client,
    serverId: serverId,
    machineId: machineId,
    kind: kind,
    account: account,
    atFiveHourLimit: atFiveHourLimit,
    idempotencyKey: idempotencyKey,
    onOutcome: onOutcome,
  ),
  overModal: overModal,
);

const _marker = '\u0001';

RaftConfirmDialog _confirmDialog(
  BuildContext context, {
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String kind,
  required String? account,
  required bool atFiveHourLimit,
  required String idempotencyKey,
  required void Function(ClaudeLimitResetOutcome outcome) onOutcome,
}) {
  final t = RaftTokens.of(context);
  final name = claudeKindName(context, kind);
  final parts = icuText(
    context,
    "Claude Code on this Computer uses {account}'s {kind} now. This can't be undone.",
    {'account': _marker, 'kind': name},
  ).split(_marker);
  final accountLabel = account ?? raftText(context, 'this account');
  Future<void> confirm() async {
    Map<String, dynamic> result;
    Map<String, dynamic>? snapshot;
    try {
      final reply = await client.redeemLimitReset(
        serverId,
        machineId,
        'claude',
        idempotencyKey,
        kind: kind,
      );
      result = reply.result;
      snapshot = reply.snapshot;
    } catch (error) {
      onOutcome(ClaudeLimitResetOutcome(kind, null, null, null));
      if (!context.mounted) rethrow;
      // The Computer may have used it and the answer was lost: never "try
      // again" blindly here. A refusal (4xx) was answered before anything
      // reached the Computer.
      final status = runtimeAuthRequestError(error).status;
      final unknown = status == null || status == 408 || status >= 500;
      throw RaftComputerActionError(
        unknown
            ? raftText(
                context,
                "The Computer didn't answer in time, so it's not known whether a reset was used. Check /usage in Claude Code before trying again.",
              )
            : raftFormat(context, limitResetRequestErrorSource(error), {
                'runtime': 'Claude Code',
              }),
      );
    }
    final note = context.mounted
        ? claudeLimitResetNote(context, kind, result)
        : null;
    onOutcome(ClaudeLimitResetOutcome(kind, result, snapshot, note));
    if (note == null && context.mounted) {
      throw RaftComputerActionError(
        claudeLimitResetRefusal(context, kind, result, atFiveHourLimit),
      );
    }
  }

  return RaftConfirmDialog(
    surfaceKey: const ValueKey('claude-limit-reset-confirm-dialog'),
    title: raftFormat(context, 'Use your {kind}?', {'kind': name}),
    plainMessage: true,
    maxWidth: 448,
    content: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts.first),
          if (parts.length > 1) ...[
            TextSpan(
              text: accountLabel,
              style: RaftTypography.body(
                t,
                size: 14,
                line: 14 * 1.625,
                color: t.strong,
                weight: FontWeight.w600,
              ),
            ),
            TextSpan(text: parts.sublist(1).join(_marker)),
          ],
        ],
      ),
      key: const ValueKey('claude-limit-reset-confirm'),
      style: RaftConfirmDialog.messageStyle(t),
    ),
    confirmLabel: raftFormat(context, 'Use {kind}', {'kind': name}),
    confirmKey: const ValueKey('claude-limit-reset-confirm-action'),
    confirmVariant: RaftButtonRecipeVariant.primary,
    loadingLabel: raftText(context, 'Processing…'),
    onConfirm: confirm,
  );
}

/// "View available resets": opens the list (after a consent at the 5-hour
/// limit), hands the chosen kind to [onUse] (which opens the confirm over it
/// and says whether it closed on an answer; the list closes then too).
Future<void> showComputerClaudeLimitResetsDialog(
  BuildContext context, {
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required bool atFiveHourLimit,
  required bool canUse,
  required bool canConsent,
  required void Function(bool spent) onLegacy,
  required VoidCallback onNotSupported,
  required Future<bool> Function(BuildContext dialog, String kind) onUse,
}) => showRaftDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ClaudeLimitResetsDialog(
    client: client,
    serverId: serverId,
    machineId: machineId,
    atFiveHourLimit: atFiveHourLimit,
    canUse: canUse,
    canConsent: canConsent,
    onLegacy: onLegacy,
    onNotSupported: onNotSupported,
    onUse: onUse,
  ),
);

enum _Phase { consent, reading, read, failed }

class _ClaudeLimitResetsDialog extends StatefulWidget {
  const _ClaudeLimitResetsDialog({
    required this.client,
    required this.serverId,
    required this.machineId,
    required this.atFiveHourLimit,
    required this.canUse,
    required this.canConsent,
    required this.onLegacy,
    required this.onNotSupported,
    required this.onUse,
  });
  final RuntimeAuthClient client;
  final String serverId, machineId;
  final bool atFiveHourLimit, canUse, canConsent;
  final void Function(bool spent) onLegacy;
  final VoidCallback onNotSupported;
  final Future<bool> Function(BuildContext dialog, String kind) onUse;

  @override
  State<_ClaudeLimitResetsDialog> createState() =>
      _ClaudeLimitResetsDialogState();
}

class _ClaudeLimitResetsDialogState extends State<_ClaudeLimitResetsDialog> {
  late _Phase phase = widget.atFiveHourLimit ? _Phase.consent : _Phase.reading;
  Map<String, dynamic>? listed;
  // ignore: raft_lints/avoid_imperative_notice_state -- Set by a failed read and replaced by the next read; the dialog state is dropped when it closes.
  String? failure;
  Object? failedWith;
  String? selected;
  bool consented = false, started = false;

  @override
  void initState() {
    super.initState();
    if (phase == _Phase.reading) {
      started = true;
      unawaited(read(false));
    }
  }

  Future<void> read(bool consent) async {
    Map<String, dynamic> result;
    try {
      result = await widget.client.readLimitResets(
        widget.serverId,
        widget.machineId,
        consent: consent,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        phase = _Phase.failed;
        failedWith = error;
        failure = null;
      });
      return;
    }
    if (!mounted) return;
    switch (result['kind']) {
      case 'read':
        if (result['program'] == 'legacy') {
          widget.onLegacy(result['fiveHourSpent'] == true);
        }
        setState(() {
          selected = null;
          listed = result;
          phase = _Phase.read;
        });
      case 'unsupported':
        if (result['reason'] == 'consent_required' && !consent) {
          setState(() => phase = _Phase.consent);
        } else if (claudeLimitResetsNotSupportedHere(result)) {
          widget.onNotSupported();
          setState(() {
            phase = _Phase.failed;
            failure = _notSupportedHere(context);
          });
        } else {
          setState(() {
            phase = _Phase.failed;
            failure = switch (result['reason']) {
              'not_attempted' => raftText(
                context,
                'Nothing was used: the Computer was busy or ran out of time. Try again.',
              ),
              'not_installed' => raftFormat(
                context,
                '{runtime} is not installed on this Computer.',
                {'runtime': 'Claude Code'},
              ),
              _ => raftFormat(
                context,
                "{runtime} on this Computer can't use a limit reset from here. No reset was used.",
                {'runtime': 'Claude Code'},
              ),
            };
          });
        }
      case 'reauth_required':
        setState(() {
          phase = _Phase.failed;
          failure = raftFormat(
            context,
            'Sign in to {runtime} again on this Computer. No reset was used.',
            {'runtime': 'Claude Code'},
          );
        });
      default:
        setState(() {
          phase = _Phase.failed;
          failure = raftText(context, "Couldn't read your resets. Try again.");
        });
    }
  }

  String failureText() {
    final error = failedWith;
    if (error == null) return failure ?? '';
    final status = runtimeAuthRequestError(error).status;
    return status == null || status == 408 || status >= 500
        ? raftText(context, "The Computer didn't answer in time. Try again.")
        : raftFormat(context, limitResetRequestErrorSource(error), {
            'runtime': 'Claude Code',
          });
  }

  // One read with consent per dialog, however often Continue is pressed.
  void confirmConsent() {
    if (!widget.canConsent || consented) return;
    consented = true;
    started = true;
    setState(() => phase = _Phase.reading);
    unawaited(read(true));
  }

  bool get legacy => listed?['program'] == 'legacy';

  List<Map> get items => [
    if (listed != null && !legacy)
      for (final r in (listed!['resets'] as List? ?? const []))
        if (r is Map) r,
  ];

  bool enabledKind(Map reset) =>
      reset['state'] == 'available' &&
      !(widget.atFiveHourLimit && reset['kind'] != 'five_hour');

  bool get usable =>
      widget.canUse &&
      selected != null &&
      items.any((r) => r['kind'] == selected && enabledKind(r));

  Future<void> useSelected() async {
    final kind = selected;
    if (!usable || kind == null) return;
    final closed = await widget.onUse(context, kind);
    if (closed && mounted) Navigator.of(context).pop();
  }

  /// ChoiceList: the rows sit in a hairline frame (`rounded-container border
  /// border-line-hairline bg-layer-card`, `p-1` scroller); a disabled row's
  /// label and meta read `foreground-disabled`.
  Widget _list(RaftTokens t, TextStyle foot) {
    final frame = RaftChoiceListRecipe.resolve(
      scroll: true,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).frame;
    return RaftRecipeBox(
      key: const ValueKey('claude-limit-resets-frame'),
      style: frame,
      tokens: t.recipeTokens,
      child: Padding(
        padding: const EdgeInsets.all(RaftSpace.x1),
        child: RaftRadioGroup<String>(
          key: const ValueKey('claude-limit-resets-list'),
          value: selected,
          semanticLabel: raftText(context, 'Limit resets'),
          spacing: 0,
          onChanged: (v) => setState(() => selected = v),
          children: [
            for (final reset in items)
              _row(t, foot, reset, enabled: enabledKind(reset)),
          ],
        ),
      ),
    );
  }

  Widget _row(
    RaftTokens t,
    TextStyle foot,
    Map reset, {
    required bool enabled,
  }) => RaftRadioGroupItem<String>(
    key: ValueKey('claude-limit-reset-${reset['kind']}'),
    value: '${reset['kind']}',
    enabled: enabled,
    minHeight: 44,
    padding: const EdgeInsets.symmetric(vertical: RaftSpace.x1_5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          claudeKindName(context, '${reset['kind']}'),
          style: RaftTypography.body(
            t,
            size: 14,
            line: 20,
            color: enabled ? t.strong : t.ui.foregroundDisabled,
            weight: FontWeight.w600,
          ),
        ),
        Text(
          claudeKindMeta(context, reset),
          style: enabled ? foot : foot.copyWith(color: t.ui.foregroundDisabled),
        ),
      ],
    ),
  );

  void close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = RaftTypography.body(
      t,
      size: 14,
      line: 14 * 1.625,
      color: t.muted,
    );
    final foot = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      color: t.colors['foreground-muted'] ?? t.muted,
    );
    Widget cancel() => RaftButton(
      label: raftText(context, 'Cancel'),
      uiVariant: RaftButtonVariant.outline,
      onPressed: close,
    );
    if (phase == _Phase.consent) {
      return RaftDialog.shell(
        surfaceKey: const ValueKey('claude-limit-resets-consent-dialog'),
        title: raftText(context, 'Check your resets at the 5-hour limit?'),
        maxWidth: 448,
        onClose: close,
        body: Text(
          // An owner or admin who did not connect the Computer: the read could
          // spend someone else's 5-hour reset, so there is no Continue.
          widget.canConsent
              ? raftText(
                  context,
                  "You're at your 5-hour limit. Checking or using a reset opens Claude Code on this Computer for a moment and sends one small request, which counts against your 5-hour window. On some Claude accounts (those with only the older once-a-week 5-hour reset), just opening Claude Code's reset list now uses that 5-hour reset right away, without asking. Continue only if that's OK.",
                )
              : raftText(
                  context,
                  'Only the person who connected this Computer can use its Claude resets.',
                ),
          key: const ValueKey('claude-limit-resets-consent'),
          style: muted,
        ),
        footer: [
          cancel(),
          RaftButton(
            key: const ValueKey('claude-limit-resets-consent-continue'),
            label: raftText(context, 'Continue'),
            tone: RaftButtonRecipeVariant.warning,
            onPressed: widget.canConsent ? confirmConsent : null,
          ),
        ],
      );
    }
    final reading = phase == _Phase.reading;
    final spent = listed?['fiveHourSpent'] == true;
    return RaftDialog.shell(
      surfaceKey: const ValueKey('claude-limit-resets-dialog'),
      title: raftText(context, 'Claude limit resets'),
      maxWidth: 448,
      onClose: close,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x3,
        children: [
          if (reading)
            Row(
              key: const ValueKey('claude-limit-resets-reading'),
              spacing: RaftSpace.x2,
              children: [
                const RaftSpinner(recipeSize: RaftSpinnerRecipeSize.xs),
                Expanded(
                  child: Text(
                    raftText(
                      context,
                      'Reading your resets in Claude Code on this Computer. This can take up to a minute.',
                    ),
                    style: muted,
                  ),
                ),
              ],
            ),
          if (phase == _Phase.failed)
            RaftBanner(
              key: const ValueKey('claude-limit-resets-failed'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              description: failureText(),
            ),
          if (spent)
            RaftBanner(
              key: const ValueKey('claude-limit-resets-five-hour-spent'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              description: raftText(
                context,
                "Opening the list used this account's 5-hour reset: it has only Claude's older once-a-week 5-hour reset.",
              ),
            ),
          if (legacy)
            Text(
              raftText(
                context,
                "This account has only Claude's older once-a-week 5-hour reset, so there is nothing else to list. When you reach your 5-hour limit, use it with Use 5-hour reset on the card.",
              ),
              key: const ValueKey('claude-limit-resets-legacy'),
              style: muted,
            ),
          if (items.isNotEmpty) _list(t, foot),
          if (items.isNotEmpty && !widget.canUse)
            Text(
              raftText(
                context,
                'Only the person who connected this Computer can use its Claude resets.',
              ),
              key: const ValueKey('claude-limit-resets-owner-only'),
              style: foot,
            ),
          if (items.isNotEmpty && widget.atFiveHourLimit)
            Text(
              raftText(
                context,
                'At your 5-hour limit, only a 5-hour reset can be used from here. To use a weekly, Fable or full reset now, go to Settings › Usage on claude.ai.',
              ),
              key: const ValueKey('claude-limit-resets-at-limit-hint'),
              style: foot,
            ),
        ],
      ),
      footer: [
        cancel(),
        RaftButton(
          key: const ValueKey('claude-limit-resets-use'),
          label: raftText(context, 'Use this reset'),
          tone: RaftButtonRecipeVariant.primary,
          onPressed: usable ? useSelected : null,
        ),
      ],
    );
  }
}
