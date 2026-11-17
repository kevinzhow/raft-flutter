// Web v1.24.0 Settings › Account › Two-step verification
// (components/settings/TwoStepVerificationSection.tsx): turn on an
// authenticator app, see / copy / download / regenerate the backup codes,
// turn it off. People who never turn it on see only the offer.
//
// The server (routes/secondFactor.ts) decides what proof each change needs:
// turning on answers 403 `reauth_required` without a recent sign-in, so the
// password comes first (POST /reauth/password); one code on POST /enable
// confirms the app and turns it on; regenerating and turning off take a code
// in the same request (turning off also a backup code). This client has no
// passkeys: Web's passkey choices never show (Web `canUsePasskeys()` false).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'account_security_answer.dart';
import 'account_security_dialogs.dart';
import 'account_security_qr.dart';
import 'icu_message.dart';
import 'settings_anchor.dart';

/// What the Account page's Passkeys and Two-step verification sections share
/// (Web `useSecondFactorSettings`): either one changing reloads both, and
/// the Passkeys section's last-passkey reason opens Turn Off here.
class SecondFactorSettings extends ChangeNotifier {
  int revision = 0;
  bool turnOffRequested = false;

  void changed() {
    revision++;
    notifyListeners();
  }

  void requestTurnOff() {
    turnOffRequested = true;
    notifyListeners();
  }
}

/// The last status each account read on this client: a revisit paints it at
/// once and reads again in place.
final _lastStatus = Expando<(String?, SecondFactorStatus)>();

SecondFactorStatus? lastSecondFactorStatus(RaftClient client) {
  final last = _lastStatus[client];
  return last != null && last.$1 == client.user?.id ? last.$2 : null;
}

void rememberSecondFactorStatus(RaftClient client, SecondFactorStatus s) =>
    _lastStatus[client] = (client.user?.id, s);

/// Whether the account has a password (`GET /auth/identities`
/// `passwordConfigured`); null when that can't be read.
Future<bool?> accountPasswordConfigured(RaftClient client) async {
  try {
    final data = await client.get('/auth/identities');
    final value = data is Map ? data['passwordConfigured'] : null;
    return value is bool ? value : null;
  } catch (_) {
    return null;
  }
}

class TwoStepVerificationSection extends StatefulWidget {
  const TwoStepVerificationSection({
    super.key,
    required this.controller,
    required this.settings,
  });
  final WorkspaceController controller;
  final SecondFactorSettings settings;

  @override
  State<TwoStepVerificationSection> createState() => _TwoStepState();
}

class _TwoStepState extends State<TwoStepVerificationSection> {
  RaftClient get client => widget.controller.client;
  late SecondFactorStatus? status = lastSecondFactorStatus(client);

  /// The server says the feature is not there (404): the section stays away.
  bool absent = false;
  bool loadFailed = false, starting = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when Turn on is pressed again; the section state is dropped with the page.
  String? startError;
  int request = 0, revision = 0;
  bool turnOffOpen = false;

  @override
  void initState() {
    super.initState();
    revision = widget.settings.revision;
    widget.settings.addListener(settingsChanged);
    unawaited(load());
  }

  @override
  void dispose() {
    widget.settings.removeListener(settingsChanged);
    super.dispose();
  }

  void settingsChanged() {
    if (widget.settings.revision != revision) {
      revision = widget.settings.revision;
      unawaited(load());
    }
    if (widget.settings.turnOffRequested && status?.enabled == true) {
      unawaited(turnOff());
    }
  }

  Future<void> load() async {
    final mine = ++request, user = client.user?.id;
    try {
      final next = await client.secondFactorStatus();
      if (!mounted || mine != request || client.user?.id != user) return;
      rememberSecondFactorStatus(client, next);
      setState(() {
        status = next;
        loadFailed = false;
      });
    } catch (error) {
      if (!mounted || mine != request) return;
      // The server evaluates the feature for the person alone: its 404 is
      // the final word. A reload that fails keeps what was shown.
      setState(() {
        if (error is RaftApiException && error.status == 404) {
          absent = true;
        } else {
          loadFailed = true;
        }
      });
    }
  }

  Future<void> turnOn() async {
    if (starting) return;
    setState(() => startError = null);
    // An app already confirmed while it is off only needs a code on /enable.
    // An unconfirmed secret from an earlier setup is not in the status, so
    // Turn on sets up again and shows the new QR code and key.
    if (status?.totp == true) {
      await enable(null);
      return;
    }
    setState(() => starting = true);
    try {
      final setup = await client.startTotpSetup();
      if (!mounted) return;
      setState(() => starting = false);
      await enable(setup);
    } catch (error) {
      if (!mounted) return;
      final code = SecondFactorFailure.of(error).code;
      if (code == 'reauth_required') {
        final password = await accountPasswordConfigured(client);
        if (!mounted) return;
        setState(() => starting = false);
        if (password == false) {
          await showSecondFactorNotice(
            context,
            title: "Verify it's you",
            description: raftText(
              context,
              'Your account signs in without a password. Sign out and sign in again, then turn on two-step verification within 10 minutes.',
            ),
          );
          return;
        }
        final setup = await reauthThenSetup();
        if (setup != null && mounted) await enable(setup);
      } else if (code == 'step_up_required' ||
          code == 'second_factor_already_enabled') {
        // Turned on from another sign-in meanwhile.
        widget.settings.changed();
      } else {
        setState(
          () => startError = secondFactorFailureText(
            context,
            client,
            error,
            SecondFactorAnswerKind.totp,
          ),
        );
      }
    } finally {
      if (mounted && starting) setState(() => starting = false);
    }
  }

  /// The password again, then the setup (Web `TurnOnDialog` password step).
  Future<TotpSetup?> reauthThenSetup() => showSecondFactorStep<TotpSetup>(
    context,
    label: "Verify it's you",
    builder: (context) => SecondFactorAnswerStep<TotpSetup>(
      client: client,
      title: "Verify it's you",
      description: raftText(
        context,
        "Enter your password to set up an authenticator app. You won't be asked again for 10 minutes.",
      ),
      kinds: const [SecondFactorAnswerKind.password],
      commitLabel: 'Verify',
      run: (_, password) async {
        await client.reauthenticateWithPassword(password);
        return client.startTotpSetup();
      },
    ),
  );

  /// The QR code and key for [setup] (null: an app already confirmed), one
  /// code on /enable, then the backup codes.
  Future<void> enable(TotpSetup? setup) async {
    final signsOut = secondFactorBanner(
      raftText(
        context,
        'Turning it on signs you out of your other browsers. Computers and the raft CLI stay connected.',
      ),
      status: RaftBannerRecipeStatus.info,
      live: false,
    );
    var alreadyOn = false;
    final codes = await showSecondFactorStep<List<String>>(
      context,
      label: setup == null
          ? 'Turn on two-step verification'
          : 'Set up authenticator app',
      builder: (context) => SecondFactorAnswerStep<List<String>>(
        key: const ValueKey('two-step-turn-on-dialog'),
        client: client,
        title: setup == null
            ? 'Turn on two-step verification'
            : 'Set up authenticator app',
        kinds: const [SecondFactorAnswerKind.totp],
        commitLabel: 'Turn on',
        before: [
          if (setup != null) ...[
            TotpQrCode(setup.otpauthUri),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // ds-allow: the key line mirrors Web spacing in the setup step
              spacing: 6,
              children: [
                Text(
                  raftText(context, "Can't scan it? Enter this key instead:"),
                  style: RaftTypography.body(
                    RaftTokens.of(context),
                    size: 13,
                    line: 18,
                    color: RaftTokens.of(context).muted,
                  ),
                ),
                RaftCopyableCode(
                  setup.secret,
                  copyLabel: 'Copy key',
                  codeKey: const ValueKey('two-step-totp-secret'),
                ),
              ],
            ),
          ],
        ],
        after: [signsOut],
        run: (_, code) => client.enableSecondFactor(code),
        handled: (context, error) {
          if (SecondFactorFailure.of(error).code !=
              'second_factor_already_enabled') {
            return false;
          }
          alreadyOn = true;
          Navigator.of(context).pop();
          return true;
        },
      ),
    );
    if (codes == null) {
      if (alreadyOn) widget.settings.changed();
      return;
    }
    widget.settings.changed();
    if (!mounted) return;
    await showBackupCodes(
      context,
      client,
      codes,
      title: 'Turn on two-step verification',
      enabledNotice: true,
    );
  }

  Future<void> regenerate() async {
    final current = status;
    if (current == null) return;
    final codes = await showSecondFactorStep<List<String>>(
      context,
      label: 'Regenerate backup codes?',
      builder: (context) => SecondFactorAnswerStep<List<String>>(
        key: const ValueKey('two-step-regenerate-dialog'),
        client: client,
        title: 'Regenerate backup codes?',
        description: raftText(
          context,
          "Your old backup codes stop working right away, and your other browsers are signed out. Computers and the raft CLI stay connected. You'll get 10 new ones to save.",
        ),
        // An authenticator code: the server refuses a backup code here.
        kinds: [if (current.totp) SecondFactorAnswerKind.totp],
        commitLabel: 'Regenerate',
        commitVariant: RaftButtonRecipeVariant.warning,
        run: (_, code) => client.regenerateBackupCodes(code),
      ),
    );
    if (codes == null) return;
    widget.settings.changed();
    if (!mounted) return;
    await showBackupCodes(context, client, codes, title: 'New backup codes');
  }

  Future<void> turnOff() async {
    final current = status;
    if (current == null || turnOffOpen) return;
    turnOffOpen = true;
    var changed = false;
    try {
      await showSecondFactorStep<bool>(
        context,
        label: 'Turn off two-step verification?',
        builder: (context) => SecondFactorAnswerStep<bool>(
          key: const ValueKey('two-step-turn-off-dialog'),
          client: client,
          title: 'Turn off two-step verification?',
          description: raftText(
            context,
            current.passkeys > 0
                ? 'Signing in will only ask for your password or connected account. Your authenticator app and backup codes stop working; your passkeys stay. Your other browsers are signed out. Computers and the raft CLI stay connected.'
                : 'Signing in will only ask for your password or connected account. Your authenticator app and backup codes stop working. Your other browsers are signed out. Computers and the raft CLI stay connected.',
          ),
          kinds: [
            if (current.totp) SecondFactorAnswerKind.totp,
            SecondFactorAnswerKind.backupCode,
          ],
          commitLabel: 'Turn off',
          commitVariant: RaftButtonRecipeVariant.warning,
          run: (kind, entered) async {
            await client.disableSecondFactor(
              kind == SecondFactorAnswerKind.backupCode
                  ? StepUpAnswer.backupCode(entered)
                  : StepUpAnswer.code(entered),
            );
            changed = true;
            return true;
          },
          handled: (context, error) {
            if (SecondFactorFailure.of(error).code !=
                'second_factor_not_enabled') {
              return false;
            }
            changed = true;
            Navigator.of(context).pop(true);
            return true;
          },
        ),
      );
    } finally {
      turnOffOpen = false;
      widget.settings.turnOffRequested = false;
    }
    if (changed) widget.settings.changed();
  }

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (absent) return const SizedBox.shrink();
    // Still loading: nothing yet. Only a first load that fails says so.
    if (s == null && !loadFailed) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('two-step-verification-section'),
      padding: const EdgeInsets.only(bottom: RaftSpace.x6),
      // `#two-step` (settings search index; TwoStepVerificationSection.tsx `id`).
      child: RaftSettingsAnchor(
        id: 'two-step',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RaftSettingsSectionHeader(
              label: 'Two-step verification',
              glyph: RaftGlyph.shieldCheck,
            ),
            if (s == null)
              secondFactorBanner(
                raftText(
                  context,
                  "Couldn't load two-step verification. Reload the page to try again.",
                ),
              )
            else
              RaftListRowGroup(
                key: const ValueKey('two-step-verification-rows'),
                children: [
                  _settingRow(context, s),
                  if (s.enabled) ...[
                    if (s.totp)
                      _methodRow(
                        glyph: RaftGlyph.smartphone,
                        title: 'Authenticator app',
                      ),
                    if (s.passkeys > 0)
                      _methodRow(
                        key: const ValueKey('two-step-passkeys-row'),
                        glyph: RaftGlyph.keyRound,
                        title: 'Passkeys',
                        description: icuText(
                          context,
                          '{count, plural, one {# passkey also works for this step} other {# passkeys also work for this step}}',
                          {'count': s.passkeys},
                        ),
                      ),
                    _methodRow(
                      key: const ValueKey('two-step-backup-codes-row'),
                      glyph: RaftGlyph.ticket,
                      title: 'Backup codes',
                      description:
                          raftFormat(context, '{remaining} of {total} left', {
                            'remaining': s.backupCodesRemaining,
                            'total': backupCodeSetSize,
                          }),
                      notice: s.backupCodesRemaining <= lowBackupCodes
                          ? secondFactorBanner(
                              icuText(
                                context,
                                "{count, plural, one {Only # backup code left.} other {Only # backup codes left.}} Regenerate them so you don't get locked out.",
                                {'count': s.backupCodesRemaining},
                              ),
                              live: false,
                              key: const ValueKey('two-step-low-codes'),
                            )
                          : null,
                      action: RaftButton(
                        key: const ValueKey('two-step-regenerate'),
                        label: raftText(context, 'Regenerate'),
                        tone: RaftButtonRecipeVariant.outline,
                        size: RaftButtonRecipeSize.md,
                        onPressed: regenerate,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// The setting with its state badge after the title and Turn on / Turn off
  /// at its end (under the text where the row is under 32rem wide).
  Widget _settingRow(BuildContext context, SecondFactorStatus s) {
    final on = s.enabled;
    final button = on
        ? RaftButton(
            key: const ValueKey('two-step-turn-off'),
            label: raftText(context, 'Turn off'),
            tone: RaftButtonRecipeVariant.warning,
            size: RaftButtonRecipeSize.md,
            onPressed: turnOff,
          )
        : RaftButton(
            key: const ValueKey('two-step-turn-on'),
            label: raftText(context, 'Turn on'),
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            busy: starting,
            onPressed: starting ? null : turnOn,
          );
    final body = RaftListRowBody(
      children: [
        Row(
          spacing: RaftSpace.x2,
          children: [
            const Flexible(child: RaftListRowTitle('Two-step verification')),
            RaftSettingsRecipeBadge(
              key: const ValueKey('two-step-verification-state'),
              label: on ? 'On' : 'Off',
              variant: on
                  ? RaftBadgeRecipeVariant.success
                  : RaftBadgeRecipeVariant.default_,
              appearance: RaftBadgeRecipeAppearance.soft,
            ),
          ],
        ),
        RaftListRowDescription(
          on
              ? 'Required every time you sign in to this account, including with Google, GitHub or Apple.'
              : 'Ask for a second step every time you sign in, including with Google, GitHub or Apple.',
          wrap: true,
        ),
        if (startError case final error?)
          Padding(
            padding: const EdgeInsets.only(top: RaftSpace.x2),
            child: secondFactorBanner(error),
          ),
      ],
    );
    return RaftListRow(
      variant: RaftListRowVariant.plain,
      interactive: false,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 512
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftSpace.x3,
                    children: [body, button],
                  )
                : Row(
                    spacing: RaftSpace.x3,
                    children: [
                      Expanded(child: body),
                      button,
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _methodRow({
    Key? key,
    required RaftGlyph glyph,
    required String title,
    String? description,
    Widget? notice,
    Widget? action,
  }) => RaftListRow(
    key: key,
    variant: RaftListRowVariant.plain,
    interactive: false,
    semanticLabel: raftText(context, title),
    children: [
      RaftIconTile(glyph: glyph),
      RaftListRowBody(
        children: [
          RaftListRowTitle(title),
          if (description != null) RaftListRowDescription(description),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(top: RaftSpace.x2),
              child: notice,
            ),
        ],
      ),
      ?action,
    ],
  );
}

/// Settings › Account's Passkeys then Two-step verification (Web
/// AccountSection), sharing one [SecondFactorSettings].
class AccountSecuritySections extends StatefulWidget {
  const AccountSecuritySections({
    super.key,
    required this.controller,
    required this.passkeys,
  });
  final WorkspaceController controller;

  /// The Passkeys section ([PasskeysSection]); a builder keeps the import
  /// one way.
  final Widget Function(SecondFactorSettings settings) passkeys;

  @override
  State<AccountSecuritySections> createState() => _AccountSecurityState();
}

class _AccountSecurityState extends State<AccountSecuritySections> {
  final settings = SecondFactorSettings();

  @override
  void dispose() {
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      widget.passkeys(settings),
      TwoStepVerificationSection(
        controller: widget.controller,
        settings: settings,
      ),
    ],
  );
}
