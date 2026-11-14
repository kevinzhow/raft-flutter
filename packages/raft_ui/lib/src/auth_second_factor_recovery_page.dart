// Web v1.24.0 SecondFactorRecoveryScreens (components/auth/
// SecondFactorRecoveryScreens.tsx): the sign-in's second step when the person
// can't answer it.
//
//   - [RaftAuthRecoveryRequestPage]: "Can't verify?". Backup codes first when
//     the account has them; otherwise (or "No backup codes?") ask for the
//     emailed reset link. The answer is the same for every address, so the
//     page never says whether the account exists.
//   - [RaftAuthFinishRecoveryPage]: the request is past its 72-hour wait and
//     the challenge lists `recovery`. It says what finishing removes before
//     the step is answered with `{recovery: true}`.
//
// Presentation only: the app owns the email field, the request and the
// session.
import 'package:flutter/widgets.dart';

import 'auth_page.dart';
import 'raft/button.dart';
import 'raft/ui_tokens.dart';
import 'recipes/button_variants.g.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'theme.dart';

class RaftAuthRecoveryRequestPage extends StatelessWidget {
  const RaftAuthRecoveryRequestPage({
    super.key,
    required this.emailField,
    required this.onSubmit,
    required this.onBack,
    required this.onBackToSignIn,
    this.onUseBackupCode,
    this.fieldError,
    this.failure,
    this.busy = false,
    this.canSubmit = false,
    this.sent = false,
  });

  /// The email input (the app's [RaftTextInput]).
  final Widget emailField;

  /// Under the field / above Reset by email (already localized).
  final String? fieldError, failure;
  final bool busy, canSubmit;

  /// The email went: "Check your email" with Back to sign in.
  final bool sent;
  final VoidCallback onSubmit, onBack, onBackToSignIn;

  /// Present when the account has backup codes: offered before the email.
  final VoidCallback? onUseBackupCode;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    if (sent) {
      return RaftAuthShell(
        child: Column(
          key: const Key('second-factor-recovery-sent'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftAuthIntro(
              title: tr('Check your email'),
              description: tr(
                'If an account uses this email, we sent it a link to reset two-step verification.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RaftAuthBanner(
                text: tr(
                  'The link works for 30 minutes. The 72-hour wait starts when you open it.',
                ),
                info: true,
              ),
            ),
            RaftAuthWideButton(
              key: const Key('second-factor-recovery-back-to-sign-in'),
              label: tr('Back to sign in'),
              variant: RaftControlVariant.accent,
              leading: const RaftIcon(RaftGlyph.arrowLeft, size: 16),
              onPressed: onBackToSignIn,
            ),
          ],
        ),
      );
    }
    final emailDescription = tr(
      "We can email you a link that resets two-step verification. For your safety, the reset takes 72 hours, and you can cancel it from any browser where you're still signed in.",
    );
    final reset = RaftButton(
      key: const Key('second-factor-recovery-reset'),
      label: tr('Reset by email'),
      variant: onUseBackupCode == null
          ? RaftControlVariant.accent
          : RaftControlVariant.outline,
      size: RaftButtonRecipeSize.lg,
      metricsKey: onUseBackupCode == null ? 'authSubmit' : null,
      expand: true,
      busy: busy,
      onPressed: busy || !canSubmit ? null : onSubmit,
    );
    return RaftAuthShell(
      child: Column(
        key: const Key('second-factor-recovery-request'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAuthIntro(
            title: tr("Can't verify?"),
            description: onUseBackupCode == null
                ? emailDescription
                : tr(
                    'A backup code works in place of your authenticator app or passkey.',
                  ),
          ),
          if (onUseBackupCode != null) ...[
            RaftAuthWideButton(
              key: const Key('second-factor-recovery-use-backup-code'),
              label: tr('Use a backup code'),
              variant: RaftControlVariant.accent,
              leading: const RaftIcon(RaftGlyph.ticket, size: 16),
              gap: 12,
              onPressed: busy ? null : onUseBackupCode,
            ),
            // `Separator className="my-4"`.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(height: 1, color: t.ui.lineHairline),
            ),
            Text(
              tr('No backup codes?'),
              style: RaftTypography.heading(t, size: 17, line: 22),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                emailDescription,
                style: RaftTypography.body(
                  t,
                  size: 14,
                  line: 20,
                  color: t.muted,
                ),
              ),
            ),
          ],
          RaftAuthField(
            label: tr('Email'),
            error: fieldError,
            child: emailField,
          ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: RaftAuthBanner(text: failure!),
            ),
          const SizedBox(height: 16),
          reset,
          const SizedBox(height: 16),
          RaftAuthTextLink(
            key: const Key('second-factor-recovery-back'),
            label: tr('Back'),
            onTap: busy ? null : onBack,
            bold: true,
            centered: true,
          ),
        ],
      ),
    );
  }
}

class RaftAuthFinishRecoveryPage extends StatelessWidget {
  const RaftAuthFinishRecoveryPage({
    super.key,
    required this.maskedEmail,
    required this.onFinish,
    required this.onBack,
    this.failure,
    this.busy = false,
  });

  /// Who is signing in, bold.
  final String maskedEmail;

  /// Why the last try didn't finish (already localized).
  final String? failure;
  final bool busy;
  final VoidCallback onFinish, onBack;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    final template = tr('Signing in as {email}.');
    final at = template.indexOf('{email}');
    return RaftAuthShell(
      child: Column(
        key: const Key('second-factor-recovery-finish'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAuthIntro(
            title: tr('Finish the reset'),
            descriptionSpan: at < 0
                ? TextSpan(text: template)
                : TextSpan(
                    children: [
                      TextSpan(text: template.substring(0, at)),
                      TextSpan(
                        text: maskedEmail,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: t.semantic.foreground,
                        ),
                      ),
                      TextSpan(text: template.substring(at + 7)),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RaftAuthBanner(
              text: tr(
                'Finishing removes your authenticator app, passkeys and backup codes, and turns two-step verification off. Every other browser, device and app signed in to your account is signed out, and the agent keys they created stop working.',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              tr(
                "You'll be signed in here. You can turn two-step verification on again in Settings › Account.",
              ),
              style: RaftTypography.body(t, size: 14, line: 20, color: t.muted),
            ),
          ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RaftAuthBanner(text: failure!),
            ),
          RaftButton(
            key: const Key('second-factor-recovery-finish-button'),
            label: tr('Finish reset'),
            variant: RaftControlVariant.danger,
            size: RaftButtonRecipeSize.lg,
            expand: true,
            busy: busy,
            onPressed: busy ? null : onFinish,
          ),
          const SizedBox(height: 16),
          RaftAuthTextLink(
            key: const Key('second-factor-recovery-finish-back'),
            label: tr('Back'),
            onTap: busy ? null : onBack,
            bold: true,
            centered: true,
          ),
        ],
      ),
    );
  }
}
