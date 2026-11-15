import 'interaction.dart';
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'copyable_code.dart';
import 'raft/badge.dart' show RaftBadge;
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'raft/status.dart' show RaftStatus, RaftStatusSize, RaftStatusVariant;
import 'design_primitives.dart';
import 'dialog_card.dart' show RaftCloseButton;
import 'hover_card.dart';
import 'icons.dart';
import 'indicators.dart' show RaftProgressBar;
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/badge.g.dart';
import 'recipes/card.g.dart';
import 'recipes/progress.g.dart';
import 'recipes/status.g.dart';
import 'theme.dart';

/// One usage window (`5h`, `weekly`…) of a runtime account.
@immutable
class RaftRuntimeUsageWindow {
  const RaftRuntimeUsageWindow({
    required this.label,
    required this.status,
    this.percent = 0,
    this.reset,
    this.usedUp = false,
  });
  final String label;

  /// `ok` | `limit_reached` | `parse_unavailable`.
  final String status;
  final int percent;

  /// Relative reset time ("in 3 hours"); null when unavailable.
  final String? reset;

  /// Used up by the provider's word or the ratio itself, not by rounding: a
  /// window with 0.4% left reads "100% used", not "Used up" (UsageWindowMeter).
  final bool usedUp;
}

@immutable
class RaftRuntimeUsageAccount {
  const RaftRuntimeUsageAccount({
    required this.health,
    this.plan,
    this.identity,
    this.windows = const [],
    this.resetsText,
  });

  /// `ok` | `rate_limited` | `reauth_required` | `unsupported` | `error`.
  final String health;
  final String? plan, identity;
  final List<RaftRuntimeUsageWindow> windows;

  /// The account's limit resets (Codex) in words ("2 resets left", "No resets
  /// left"), beside the account they belong to; null when the provider reports
  /// none.
  final String? resetsText;
}

/// What a card's sign-in action is (runtimeAuthAction).
enum RaftRuntimeAuthActionKind {
  /// Nothing for this person here.
  none,

  /// A caption saying why there is no button.
  hint,

  /// The runtime's CLI is missing or too old: [RaftRuntimeAuthData.unavailableText]
  /// and its install command.
  unavailable,

  /// "Add provider" (Pi, OpenCode).
  addProvider,

  /// "Connect provider" (Qwen Code).
  connectProvider,

  /// "Sign out".
  signOut,

  /// "Sign in".
  signIn,
}

/// A per-provider runtime's (Pi's) stored sign-in, one row.
@immutable
class RaftRuntimeAuthProvider {
  const RaftRuntimeAuthProvider({
    required this.id,
    required this.label,
    required this.detail,
    required this.isKey,
    this.onSignOut,
  });
  final String id, label;

  /// "API key" / "Subscription account" / "Account" / "Signed in".
  final String detail;
  final bool isKey;

  /// Its own Sign out (an account) or Remove (a key); null for a person who
  /// may not act here.
  final VoidCallback? onSignOut;
}

/// The runtime's sign-in state on the card (task #17).
@immutable
class RaftRuntimeAuthData {
  const RaftRuntimeAuthData({
    required this.runtime,
    this.status,
    this.accountText,
    this.perProvider = false,
    this.providerKey = false,
    this.providers = const [],
    this.action = RaftRuntimeAuthActionKind.none,
    this.outlineAction = false,
    this.hint,
    this.unavailableText,
    this.installCommand,
    this.onSignIn,
    this.onSignOut,
    this.onConnectProvider,
  });

  /// The runtime whose sign-in this is (the runtime-auth id: `kimi`).
  final String runtime;

  /// `logged_in` | `logged_out` | `unknown` | `unavailable`; null before the
  /// Computer reported.
  final String? status;

  /// "plan · masked email" of the signed-in account.
  final String? accountText;
  final bool perProvider, providerKey;
  final List<RaftRuntimeAuthProvider> providers;
  final RaftRuntimeAuthActionKind action;

  /// Add / connect provider is the quieter action once one is signed in.
  final bool outlineAction;
  final String? hint, unavailableText, installCommand;
  final VoidCallback? onSignIn, onSignOut, onConnectProvider;
}

/// The card's limit-reset action: shown only to a person who may act, while
/// the account holds a reset.
@immutable
class RaftRuntimeLimitReset {
  const RaftRuntimeLimitReset({required this.primary, required this.onUse});

  /// The account is rate-limited right now: the reset is the main action.
  final bool primary;
  final VoidCallback onUse;
}

/// Claude limit resets on the card (claude_limit_reset), `state: ok`.
/// [onView] is null for an account known to be on Claude's older program at
/// its 5-hour limit, where opening the list would use it. [ownerOnly]: the
/// viewer did not connect this Computer, so they may view but not use.
@immutable
class RaftRuntimeClaudeLimitReset {
  const RaftRuntimeClaudeLimitReset({
    this.onView,
    this.onUseFiveHour,
    this.ownerOnly = false,
  });
  final VoidCallback? onView, onUseFiveHour;
  final bool ownerOnly;
}

/// What stops this runtime here (RuntimeReadinessNotice).
@immutable
class RaftRuntimeReadinessNotice {
  const RaftRuntimeReadinessNotice({
    required this.heading,
    required this.body,
    this.linkText,
    this.onOpenLink,
  });
  final String heading, body;
  final String? linkText;
  final VoidCallback? onOpenLink;
}

/// Everything the Web RuntimeAccountUsageChip surface shows; the adapter
/// owns reads, refreshes and permission.
@immutable
class RaftRuntimeUsageData {
  const RaftRuntimeUsageData({
    required this.provider,
    this.runtimeName,
    this.runtimeId,
    this.version,
    this.loading = false,
    this.loadError = false,
    this.state,
    this.accounts = const [],
    this.updated,
    this.statusText,
    this.refreshing = false,
    this.refreshDisabled = false,
    this.auth,
    this.limitReset,
    this.claudeLimitReset,
    this.readiness,
    this.dialogLabel,
  });

  /// The card's accessible name ("Claude Code runtime account usage",
  /// "Qoder sign-in", "Qwen Code provider"); defaults to the usage one.
  final String? dialogLabel;

  /// The usage provider's display name ("Claude"); null for a runtime with no
  /// usage to read (Qoder): the card is its sign-in alone.
  final String? provider;

  /// The runtime's display name ("Claude Code"): the title once there is no
  /// usage to name. Defaults to [provider].
  final String? runtimeName;
  final String? runtimeId;
  final String? version;
  final bool loading, loadError;

  /// null before the first read; `missing` | `unsupported` | `fresh` |
  /// `stale`.
  final String? state;
  final List<RaftRuntimeUsageAccount> accounts;

  /// Relative collection time of the snapshot.
  final String? updated;

  /// The one caption under the action row: what the last limit reset did, a
  /// refresh in flight or refused, the countdown, the Computer offline. Null
  /// by default.
  final String? statusText;
  final bool refreshing, refreshDisabled;
  final RaftRuntimeAuthData? auth;
  final RaftRuntimeLimitReset? limitReset;
  final RaftRuntimeClaudeLimitReset? claudeLimitReset;
  final RaftRuntimeReadinessNotice? readiness;

  String get name => runtimeName ?? provider ?? '';

  /// isAttention: stale, or any account / window not `ok`.
  bool get attention =>
      state == 'stale' ||
      (state == 'fresh' &&
          accounts.any(
            (a) => a.health != 'ok' || a.windows.any((w) => w.status != 'ok'),
          ));
  bool get known =>
      state != null && state != 'missing' && state != 'unsupported';

  /// Signed out on the Computer: there is no usage to show, only the way to
  /// sign in.
  bool get signedOut => auth?.status == 'logged_out';

  /// `unsupported`: this Computer reads no usage for it, as a runtime with
  /// none.
  bool get showsUsage =>
      provider != null && !signedOut && state != 'unsupported';
}

/// Web RuntimeUsageSurface: header (title, sign-in line, version, privacy
/// note, close), the readiness notice, the usage block and the one action
/// row. A button that opens a dialog closes the card first (`onAuthDialog`).
class RaftRuntimeUsageSurface extends StatelessWidget {
  const RaftRuntimeUsageSurface({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onClose,
  });
  final RaftRuntimeUsageData data;
  final VoidCallback onRefresh, onClose;

  /// A dialog takes over from the card: close the card so it does not float
  /// above it.
  VoidCallback? _dialog(VoidCallback? action) => action == null
      ? null
      : () {
          onClose();
          action();
        };

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = _UsageInk(t);
    final hairline = BorderSide(color: t.colors['line-hairline']!, width: 1);
    final auth = data.auth;
    final showsUsage = data.showsUsage;
    final authOnly = data.provider == null || data.state == 'unsupported';
    final usageShowsAccount = showsUsage && data.accounts.isNotEmpty;
    final readiness = data.readiness;
    return Column(
      key: ValueKey(
        data.provider != null
            ? 'runtime-usage-surface-${data.provider!.toLowerCase()}'
            : 'runtime-auth-surface-${data.runtimeId ?? data.name}',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: hairline)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showsUsage
                          ? raftFormat(context, '{runtime} usage', {
                              'runtime': data.name,
                            })
                          : data.name,
                      key: const ValueKey('runtime-usage-title'),
                      style: ink.sans(14, 20, ink.strong, FontWeight.w900),
                    ),
                    if (auth != null)
                      _AuthHeaderLine(
                        auth: auth,
                        usageShowsAccount: usageShowsAccount,
                        authOnly: authOnly,
                      ),
                    if (data.version?.trim().isNotEmpty == true)
                      Text(
                        data.version!.trim(),
                        key: const ValueKey('runtime-usage-version'),
                        style: ink
                            .sans(10, 15, ink.hint, FontWeight.w400)
                            .copyWith(fontFamily: t.monoFont),
                      ),
                    Text(
                      raftText(
                        context,
                        'Visible to server admins and the person who connected this Computer',
                      ),
                      style: ink.sans(11, 16.5, ink.hint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RaftCloseButton(
                onPressed: onClose,
                tooltip: 'Close runtime usage',
              ),
            ],
          ),
        ),
        if (readiness != null) _ReadinessNotice(notice: readiness, ink: ink),
        if (showsUsage) _contents(context, ink),
        if (showsUsage)
          _actions(context, ink, hairline)
        else ...[
          if (auth != null) _providerRows(context, ink, auth),
          if (_authAction(context, ink, auth) case final action?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Align(alignment: Alignment.centerLeft, child: action),
            ),
        ],
      ],
    );
  }

  /// One action row: the quiet sign-in action on the left, Refresh and Use a
  /// reset on the right (the reset is the primary action only while the
  /// account is rate-limited). What just happened, if anything, is one
  /// caption line under it.
  Widget _actions(BuildContext context, _UsageInk ink, BorderSide hairline) {
    final limit = data.limitReset;
    final claude = data.claudeLimitReset;
    final authAction = _authAction(context, ink, data.auth);
    return Container(
      key: const ValueKey('runtime-usage-actions'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(top: hairline)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ?authAction,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RaftButton(
                    key: const ValueKey('runtime-usage-refresh'),
                    label: raftText(context, 'Refresh'),
                    glyph: data.refreshing ? null : RaftGlyph.refreshCw,
                    busy: data.refreshing,
                    loadingLabel: raftText(context, 'Refresh'),
                    uiVariant: RaftButtonVariant.outline,
                    uiSize: RaftButtonSize.md,
                    onPressed: data.refreshDisabled || data.refreshing
                        ? null
                        : onRefresh,
                  ),
                  if (limit != null)
                    RaftButton(
                      key: const ValueKey('runtime-limit-reset-action'),
                      label: raftText(context, 'Use a reset'),
                      glyph: RaftGlyph.timerReset,
                      uiVariant: limit.primary
                          ? RaftButtonVariant.primary
                          : RaftButtonVariant.outline,
                      uiSize: RaftButtonSize.md,
                      onPressed: _dialog(limit.onUse),
                    ),
                  if (claude?.onView != null)
                    RaftButton(
                      key: const ValueKey('claude-limit-resets-view-action'),
                      label: raftText(context, 'View available resets'),
                      glyph: RaftGlyph.listChecks,
                      uiVariant: RaftButtonVariant.outline,
                      uiSize: RaftButtonSize.md,
                      onPressed: _dialog(claude!.onView),
                    ),
                  if (claude?.onUseFiveHour != null)
                    RaftButton(
                      key: const ValueKey(
                        'claude-limit-reset-five-hour-action',
                      ),
                      label: raftText(context, 'Use 5-hour reset'),
                      glyph: RaftGlyph.timerReset,
                      uiVariant: RaftButtonVariant.primary,
                      uiSize: RaftButtonSize.md,
                      onPressed: _dialog(claude!.onUseFiveHour),
                    ),
                ],
              ),
            ],
          ),
          if (claude?.ownerOnly == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                raftText(
                  context,
                  'Only the person who connected this Computer can use its Claude resets.',
                ),
                key: const ValueKey('claude-limit-resets-owner-only'),
                style: ink.sans(11, 16.5, ink.hint),
              ),
            ),
          if (data.statusText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  data.statusText!,
                  key: const ValueKey('runtime-usage-status'),
                  style: ink.sans(11, 16.5, ink.hint),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// runtimeAuthAction: a button (sign in, sign out, connect a provider), or
  /// the hint that says why there is none here.
  Widget? _authAction(
    BuildContext context,
    _UsageInk ink,
    RaftRuntimeAuthData? auth,
  ) {
    if (auth == null) return null;
    switch (auth.action) {
      case RaftRuntimeAuthActionKind.none:
        return null;
      case RaftRuntimeAuthActionKind.hint:
        return Text(
          auth.hint ?? '',
          key: const ValueKey('runtime-auth-unavailable'),
          style: ink.sans(11, 16.5, ink.hint),
        );
      case RaftRuntimeAuthActionKind.unavailable:
        return Column(
          key: const ValueKey('runtime-auth-cli-unavailable'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              auth.unavailableText ?? '',
              style: ink.sans(11, 16.5, ink.hint),
            ),
            if (auth.installCommand != null) ...[
              const SizedBox(height: 4),
              Text(
                raftText(context, 'On macOS or Linux:'),
                style: ink.sans(11, 16.5, ink.hint),
              ),
              const SizedBox(height: 4),
              RaftCopyableCode(
                auth.installCommand!,
                codeKey: const ValueKey('runtime-auth-install-line'),
              ),
            ],
          ],
        );
      case RaftRuntimeAuthActionKind.addProvider:
        return RaftButton(
          key: const ValueKey('runtime-auth-add-provider'),
          label: raftText(context, 'Add provider'),
          glyph: RaftGlyph.plus,
          uiVariant: auth.outlineAction
              ? RaftButtonVariant.outline
              : RaftButtonVariant.primary,
          uiSize: RaftButtonSize.md,
          onPressed: _dialog(auth.onSignIn),
        );
      case RaftRuntimeAuthActionKind.connectProvider:
        return RaftButton(
          key: const ValueKey('runtime-auth-connect-provider'),
          label: raftText(context, 'Connect provider'),
          glyph: RaftGlyph.keyRound,
          uiVariant: auth.outlineAction
              ? RaftButtonVariant.outline
              : RaftButtonVariant.primary,
          uiSize: RaftButtonSize.md,
          onPressed: _dialog(auth.onConnectProvider),
        );
      case RaftRuntimeAuthActionKind.signOut:
        // Red is for the confirm button of what cannot be undone, and a
        // log-out can be (sign in again): a quiet ghost action here.
        return RaftButton(
          key: const ValueKey('runtime-auth-sign-out'),
          label: raftText(context, 'Sign out'),
          glyph: RaftGlyph.logOut,
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.md,
          onPressed: _dialog(auth.onSignOut),
        );
      case RaftRuntimeAuthActionKind.signIn:
        return RaftButton(
          key: const ValueKey('runtime-auth-sign-in'),
          label: raftText(context, 'Sign in'),
          glyph: RaftGlyph.logIn,
          uiVariant: RaftButtonVariant.primary,
          uiSize: RaftButtonSize.md,
          onPressed: _dialog(auth.onSignIn),
        );
    }
  }

  /// PerProviderRows: a per-provider runtime's (Pi's) stored sign-ins, one
  /// row each.
  Widget _providerRows(
    BuildContext context,
    _UsageInk ink,
    RaftRuntimeAuthData auth,
  ) {
    if (!auth.perProvider ||
        auth.status != 'logged_in' ||
        auth.providers.isEmpty) {
      return const SizedBox.shrink();
    }
    final t = ink.t;
    return Padding(
      key: const ValueKey('runtime-auth-providers'),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          for (final p in auth.providers)
            Padding(
              key: ValueKey('runtime-auth-provider-${p.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.colors['fill-muted'],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RaftIcon(
                      p.isKey ? RaftGlyph.keyRound : RaftGlyph.userRound,
                      size: 16,
                      color: ink.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ink.sans(14, 20, ink.strong, FontWeight.w600),
                        ),
                        Text(p.detail, style: ink.sans(12, 16, ink.muted)),
                      ],
                    ),
                  ),
                  if (p.onSignOut != null)
                    RaftButton(
                      key: ValueKey('runtime-auth-provider-sign-out-${p.id}'),
                      label: raftText(context, p.isKey ? 'Remove' : 'Sign out'),
                      glyph: p.isKey ? null : RaftGlyph.logOut,
                      uiVariant: RaftButtonVariant.ghost,
                      uiSize: RaftButtonSize.md,
                      onPressed: _dialog(p.onSignOut),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _contents(BuildContext context, _UsageInk ink) {
    final t = ink.t;
    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 20);
    if (data.loading && data.state == null) {
      return Padding(
        padding: pad,
        child: Text(
          raftText(context, 'Reading cached snapshot…'),
          style: ink.sans(14, 20, ink.muted),
        ),
      );
    }
    if (data.loadError && data.state == null) {
      return Padding(
        padding: pad,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RaftIcon(
                RaftGlyph.alertTriangle,
                size: 16,
                color: t.colors['warning-strong'],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                raftText(context, 'Cached usage could not be read.'),
                style: ink.sans(14, 20, t.colors['warning-strong']!),
              ),
            ),
          ],
        ),
      );
    }
    if (!data.known) {
      return Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              raftText(context, 'No snapshot yet'),
              style: ink.sans(14, 20, ink.strong, FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              raftText(
                context,
                'Usage shows here once this Computer reports it. Provider credentials never leave it.',
              ),
              style: ink.sans(12, 16, ink.muted),
            ),
          ],
        ),
      );
    }
    final stale = data.state == 'stale';
    final divider = BorderSide(color: t.colors['line-hairline']!, width: 1);
    return ColoredBox(
      color: stale ? t.colors['fill-muted']! : const Color(0x00000000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: t.colors['warning-soft'],
                border: Border(bottom: divider),
              ),
              child: Text(
                raftText(
                  context,
                  'Stale snapshot · every value below is last known',
                ),
                style: ink.sans(11, 16.5, ink.strong, FontWeight.w700),
              ),
            ),
          for (final (i, account) in data.accounts.indexed)
            Container(
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _account(context, ink, account),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(border: Border(top: divider)),
            child: Text(
              raftFormat(context, 'Updated {updated}', {
                'updated': data.updated ?? raftText(context, 'recently'),
              }),
              style: ink.sans(11, 16.5, ink.hint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _account(
    BuildContext context,
    _UsageInk ink,
    RaftRuntimeUsageAccount account,
  ) {
    final t = ink.t;
    final ok = account.health == 'ok';
    final healthWord = switch (account.health) {
      'ok' => 'ok',
      'rate_limited' => 'used up',
      'reauth_required' => 'reauth required',
      'unsupported' => 'unsupported',
      _ => 'error',
    };
    final note = switch (account.health) {
      'unsupported' => null,
      'error' => 'Cached usage could not be read.',
      'reauth_required' => 'Sign in again on this Computer. Last-known percentages are hidden until the provider authenticates.',
      _ => '',
    };
    final resets = account.resetsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.plan ?? raftText(context, 'Runtime account'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink.sans(14, 20, ink.strong, FontWeight.w700),
                  ),
                  if (account.identity != null || resets != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (account.identity != null)
                            Flexible(
                              child: Text(
                                account.identity!,
                                key: const ValueKey(
                                  'runtime-account-masked-label',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ink
                                    .sans(10, 15, ink.hint)
                                    .copyWith(fontFamily: t.monoFont),
                              ),
                            ),
                          if (account.identity != null && resets != null)
                            Container(
                              width: 1,
                              height: 12,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: t.colors['line-hairline'],
                            ),
                          if (resets != null)
                            Text(
                              resets,
                              key: const ValueKey(
                                'runtime-account-limit-resets',
                              ),
                              style: ink.sans(11, 16.5, ink.muted),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Raft DS StatusChip: soft wash, a square pixel, one word.
            RaftBadge(
              label: raftText(context, healthWord),
              appearance: RaftBadgeRecipeAppearance.soft,
              variant: ok
                  ? RaftBadgeRecipeVariant.success
                  : RaftBadgeRecipeVariant.warning,
              leading: RaftStatus(
                size: RaftStatusSize.md,
                variant: ok
                    ? RaftStatusVariant.success
                    : RaftStatusVariant.warning,
              ),
            ),
          ],
        ),
        if (note == null)
          const SizedBox.shrink()
        else if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              raftText(context, note),
              style: ink.sans(12, 16, ink.muted),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, window) in account.windows.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                    child: _window(context, ink, window),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// UsageWindowMeter: what is used, filling as it is used; cyan, orange from
  /// 80% used, a full orange bar when used up.
  Widget _window(
    BuildContext context,
    _UsageInk ink,
    RaftRuntimeUsageWindow window,
  ) {
    if (window.status == 'parse_unavailable') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            window.label,
            style: ink.sans(12, 16, ink.strong, FontWeight.w600),
          ),
          Text(
            raftText(context, 'Usage unavailable'),
            style: ink.sans(12, 16, ink.t.colors['warning-strong']!),
          ),
        ],
      );
    }
    final reset = window.reset;
    final value = window.usedUp
        ? (reset == null
              ? raftText(context, 'Used up')
              : raftFormat(context, 'Used up · back {reset}', {'reset': reset}))
        : (reset == null
              ? raftFormat(
                  context,
                  '{percent}% used · reset time unavailable',
                  {'percent': window.percent},
                )
              : raftFormat(context, '{percent}% used · resets {reset}', {
                  'percent': window.percent,
                  'reset': reset,
                }));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              window.label,
              style: ink.sans(12, 16, ink.strong, FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: ink.sans(12, 16, ink.muted),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Semantics(
            label: window.label,
            value: value,
            child: RaftProgressBar(
              value: window.usedUp ? 100 : window.percent.toDouble(),
              size: RaftProgressRecipeSize.sm,
              tone: window.usedUp || window.percent >= 80
                  ? RaftProgressRecipeVariant.warning
                  : RaftProgressRecipeVariant.information,
            ),
          ),
        ),
      ],
    );
  }
}

/// RuntimeAuthHeaderLine: the sign-in state under the title. The account line
/// shows only when the usage block does not already name the plan and email
/// below. A card with no usage (Qoder) says it is signed in, as nothing else
/// on it would.
class _AuthHeaderLine extends StatelessWidget {
  const _AuthHeaderLine({
    required this.auth,
    required this.usageShowsAccount,
    required this.authOnly,
  });
  final RaftRuntimeAuthData auth;
  final bool usageShowsAccount, authOnly;

  Widget _badge(
    BuildContext context,
    Key key,
    String label,
    bool success, {
    bool pixel = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: RaftBadge(
        key: key,
        label: raftText(context, label),
        appearance: RaftBadgeRecipeAppearance.soft,
        variant: success
            ? RaftBadgeRecipeVariant.success
            : RaftBadgeRecipeVariant.warning,
        leading: pixel
            ? RaftStatus(
                size: RaftStatusSize.md,
                variant: success
                    ? RaftStatusVariant.success
                    : RaftStatusVariant.warning,
              )
            : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ink = _UsageInk(RaftTokens.of(context));
    final status = auth.status;
    if (auth.perProvider) {
      // Its providers are listed below. None stored is no "signed out": a key
      // in the Computer's environment or Pi's models.json may still sign it
      // in, unseen here.
      if (status != 'logged_out') return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          raftText(context, 'No provider signed in on this Computer'),
          key: const ValueKey('runtime-auth-no-providers'),
          style: ink.sans(14, 20, ink.muted),
        ),
      );
    }
    if (auth.providerKey) {
      // Presence only: configured or not; anything else says nothing.
      if (status != 'logged_in' && status != 'logged_out') {
        return const SizedBox.shrink();
      }
      final configured = status == 'logged_in';
      return _badge(
        context,
        ValueKey(
          configured
              ? 'runtime-provider-configured'
              : 'runtime-provider-not-configured',
        ),
        configured ? 'Provider configured' : 'No provider configured',
        configured,
        pixel: true,
      );
    }
    if (status == 'logged_out') {
      // A soft chip in words, no pixel: a status light is for presence and
      // task status, not for a runtime's sign-in.
      return _badge(
        context,
        const ValueKey('runtime-auth-logged-out'),
        'Signed out',
        false,
      );
    }
    final account = status == 'logged_in' && !usageShowsAccount
        ? auth.accountText
        : null;
    if (account != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          account,
          key: const ValueKey('runtime-auth-account'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ink.sans(14, 20, ink.strong, FontWeight.w700),
        ),
      );
    }
    if (authOnly && status == 'logged_in') {
      return _badge(
        context,
        const ValueKey('runtime-auth-logged-in'),
        'Signed in',
        true,
      );
    }
    return const SizedBox.shrink();
  }
}

/// RuntimeReadinessNotice: what stops this runtime here, whose problem it is,
/// who fixes it, and the fixed portal link for a verification.
class _ReadinessNotice extends StatelessWidget {
  const _ReadinessNotice({required this.notice, required this.ink});
  final RaftRuntimeReadinessNotice notice;
  final _UsageInk ink;

  @override
  Widget build(BuildContext context) {
    final t = ink.t;
    return Container(
      key: const ValueKey('runtime-readiness-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.colors['line-hairline']!, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RaftIcon(
              RaftGlyph.alertTriangle,
              size: 16,
              color: t.colors['warning-strong'],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.heading,
                  style: ink.sans(14, 20, ink.strong, FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(notice.body, style: ink.sans(14, 20, ink.muted)),
                if (notice.linkText != null) ...[
                  const SizedBox(height: 4),
                  RaftTextLink(
                    key: const ValueKey('runtime-readiness-link'),
                    label: notice.linkText!,
                    onPressed: notice.onOpenLink,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageInk {
  _UsageInk(this.t);
  final RaftTokens t;
  Color get strong => t.colors['foreground-strong']!;
  Color get muted => t.colors['foreground-muted']!;
  Color get hint => t.colors['foreground-hint']!;
  TextStyle sans(double size, double line, Color color, [FontWeight? w]) =>
      raftCssText.merge(
        RaftTypography.body(
          t,
          size: size,
          line: line,
          color: color,
          weight: w ?? FontWeight.w400,
        ),
      );
}

/// The runtime chip in the state words: a warning Badge, no health dot,
/// carrying a suffix such as " (not signed in)" or a readiness " (title)".
class RaftRuntimeWarningChip extends StatelessWidget {
  const RaftRuntimeWarningChip({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => RaftBadge(
    label: label,
    appearance: RaftBadgeRecipeAppearance.soft,
    variant: RaftBadgeRecipeVariant.warning,
  );
}

/// Web RuntimeAccountUsageChip trigger + hover card: the runtime Badge as a
/// button (`cursor-help`) with its health Status; hovering opens the usage
/// card after 200ms (closes 160ms after leaving), keyboard focus opens it at
/// once and a click pins it until Escape, the close button or an outside
/// press. On narrow / touch layouts a tap opens [onOpenSheet] instead.
class RaftRuntimeUsageChip extends StatefulWidget {
  const RaftRuntimeUsageChip({
    super.key,
    required this.chip,
    required this.label,
    required this.data,
    required this.onOpen,
    required this.onRefresh,
    this.onOpenSheet,
    this.onVisibleChanged,
  });

  /// The runtime Badge (label + optional [RaftRuntimeUsageStatus]).
  final Widget chip;
  final String label;
  final RaftRuntimeUsageData data;

  /// The card opened: re-read the snapshot (Web `openNow` → `readSnapshot`).
  final VoidCallback onOpen;
  final VoidCallback onRefresh;

  /// Mobile BottomSheet presentation; when set and the layout is narrow or
  /// touch, a tap calls it instead of pinning the hover card.
  final void Function(BuildContext context)? onOpenSheet;

  /// The hover card opened or closed: the refresh countdown ticks only while
  /// it is on screen.
  final ValueChanged<bool>? onVisibleChanged;
  @override
  State<RaftRuntimeUsageChip> createState() => _RaftRuntimeUsageChipState();
}

class _RaftRuntimeUsageChipState extends State<RaftRuntimeUsageChip> {
  final card = RaftHoverCardController();
  @override
  void dispose() {
    card.dispose();
    super.dispose();
  }

  /// Web `useMediaQuery("(max-width: 767px)")` stands in for "no hover" there.
  /// A finger taps a sheet; a pointer hovers a card, at any window width.
  bool get mobile => RaftInteraction.of(context).touch;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftHoverCard(
      controller: card,
      enabled: !mobile,
      delay: const Duration(milliseconds: 200),
      closeDelay: const Duration(milliseconds: 160),
      // useViewportClamp "vertical-smart": centered on the chip, the side
      // with more room, 8px gutter.
      align: RaftHoverCardAlign.center,
      sideOffset: 8,
      collisionPadding: 8,
      surface: false,
      width: null,
      closeOnTriggerPress: false,
      onOpenChanged: (open) {
        widget.onVisibleChanged?.call(open);
        if (open) widget.onOpen();
      },
      card: (context) {
        final width = (MediaQuery.sizeOf(context).width - 16).clamp(0, 390);
        final style = RaftCardRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(),
          tokens: t.recipeTokens,
        ).root;
        return Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label:
              widget.data.dialogLabel ??
              raftFormat(context, '{runtime} runtime account usage', {
                'runtime': widget.data.name,
              }),
          child: RaftRecipeBox(
            key: const ValueKey('runtime-usage-card'),
            style: style,
            tokens: t.recipeTokens,
            width: width.toDouble(),
            padding: EdgeInsets.zero,
            clip: true,
            child: SingleChildScrollView(
              child: RaftRuntimeUsageSurface(
                data: widget.data,
                onRefresh: widget.onRefresh,
                onClose: card.close,
              ),
            ),
          ),
        );
      },
      child: RaftInteractive(
        semanticLabel: widget.label,
        onPressed: () {
          if (mobile && widget.onOpenSheet != null) {
            widget.onOpenSheet!(context);
          } else {
            card.open(pinned: true);
          }
        },
        builder: (context, state) => RaftHoverRegion(
          cursor: SystemMouseCursors.help,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: state.focusVisible
                  ? Border.all(color: t.strong, width: 2)
                  : null,
            ),
            child: widget.chip,
          ),
        ),
      ),
    );
  }
}

/// The chip's health Status (`size="sm" className="ml-1 size-2"`).
class RaftRuntimeUsageStatus extends StatelessWidget {
  const RaftRuntimeUsageStatus({super.key, required this.attention});
  final bool attention;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftStatusRecipe.resolve(
      theme: t.recipeTheme,
      size: RaftStatusRecipeSize.sm,
      variant: attention
          ? RaftStatusRecipeVariant.warning
          : RaftStatusRecipeVariant.success,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).root;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        label: raftText(
          context,
          attention ? 'Usage needs attention' : 'Usage healthy',
        ),
        child: RaftRecipeBox(
          key: ValueKey('runtime-usage-health-$attention'),
          style: style,
          tokens: t.recipeTokens,
          width: 8,
          height: 8,
        ),
      ),
    );
  }
}

/// Mobile presentation (Web BottomSheet `max-h-[82vh] overflow-y-auto`,
/// `fixed inset-x-0 bottom-0 p-3`): the same surface in a bottom card.
class RaftRuntimeUsageSheet extends StatelessWidget {
  const RaftRuntimeUsageSheet({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onClose,
  });
  final RaftRuntimeUsageData data;
  final VoidCallback onRefresh, onClose;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).root;
    final padding = MediaQuery.paddingOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          padding.bottom > 12 ? padding.bottom : 12,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: RaftRecipeBox(
            key: const ValueKey('runtime-usage-sheet'),
            style: style,
            tokens: t.recipeTokens,
            width: double.infinity,
            padding: EdgeInsets.zero,
            clip: true,
            child: SingleChildScrollView(
              child: RaftRuntimeUsageSurface(
                data: data,
                onRefresh: onRefresh,
                onClose: onClose,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [RaftRuntimeUsageSheet] over a dimmed backdrop; [data] is re-read
/// whenever [listenable] notifies so the sheet follows refreshes.
Future<void> showRaftRuntimeUsageSheet(
  BuildContext context, {
  required Listenable listenable,
  required RaftRuntimeUsageData Function(BuildContext context) data,
  required VoidCallback onRefresh,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: raftText(context, 'Close runtime usage'),
  barrierColor: Colors.black.withValues(alpha: .4),
  pageBuilder: (dialogContext, _, _) => Material(
    type: MaterialType.transparency,
    child: ListenableBuilder(
      listenable: listenable,
      builder: (sheetContext, _) => RaftRuntimeUsageSheet(
        data: data(sheetContext),
        onRefresh: onRefresh,
        // pop at once: an action that opens a dialog closes the sheet first, and
        // a pop that waits a turn would close that dialog instead.
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    ),
  ),
);
