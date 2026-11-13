// Web v1.24.0 SecondFactorSignInStep (components/auth/SecondFactorSignInStep
// .tsx, SecondFactorCodeEntry.tsx): the "Two-step verification" page a
// sign-in shows when the first step answered `secondFactorRequired`.
// Presentation only: the app owns the challenge, the answer and the session.
import 'package:flutter/widgets.dart';

import 'auth_page.dart';
import 'design_primitives.dart';
import 'theme.dart';
import 'icons.dart';
import 'localization.dart';

/// The code-typed methods the page can switch between.
enum RaftSecondFactorCodeMethod { totp, backupCode }

/// One "Use …" alternative under "or" (Web `MethodSwitch appearance="buttons"`).
class RaftSecondFactorSwitch {
  const RaftSecondFactorSwitch(this.method, this.onTap);
  final RaftSecondFactorCodeMethod method;
  final VoidCallback? onTap;
}

class RaftAuthSecondFactorPage extends StatelessWidget {
  const RaftAuthSecondFactorPage({
    super.key,
    required this.maskedEmail,
    required this.onBack,
    this.expiresAt,
    this.method,
    this.codeField,
    this.fieldError,
    this.banner,
    this.ended,
    this.passkeyUnsupported = false,
    this.busy = false,
    this.canVerify = false,
    this.onVerify,
    this.switches = const [],
  });

  /// `a***@example.com`, shown in bold.
  final String maskedEmail;

  /// The challenge's end as a clock ("14:05"); the description names it.
  final String? expiresAt;

  /// The method being answered; null when none can be used here (only a
  /// passkey is set up): the page then ends with the passkey reason.
  final RaftSecondFactorCodeMethod? method;

  /// The code input (the app's [RaftTextInput]).
  final Widget? codeField;

  /// A wrong or used code, under the field (already localized).
  final String? fieldError;

  /// A failure above the form (already localized).
  final String? banner;

  /// This sign-in is over (expired, out of tries, locked): only "Back to sign
  /// in" is left (already localized).
  final String? ended;

  /// A passkey is listed but this client cannot use one.
  final bool passkeyUnsupported;
  final bool busy, canVerify;
  final VoidCallback? onVerify;
  final VoidCallback onBack;
  final List<RaftSecondFactorSwitch> switches;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final title = tr('Two-step verification');
    final over = ended ?? (method == null ? _noMethodReason(context) : null);
    if (over != null) {
      return RaftAuthShell(
        child: Column(
          key: const Key('second-factor-sign-in-ended'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftAuthIntro(
              title: title,
              descriptionSpan: _emailSpan(context, 'Signing in as {email}.'),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RaftAuthBanner(text: over),
            ),
            RaftAuthWideButton(
              key: const Key('second-factor-back-button'),
              label: tr('Back to sign in'),
              variant: RaftControlVariant.accent,
              onPressed: onBack,
            ),
          ],
        ),
      );
    }
    final totp = method == RaftSecondFactorCodeMethod.totp;
    return RaftAuthShell(
      child: Column(
        key: const Key('second-factor-sign-in'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAuthIntro(
            title: title,
            descriptionSpan: expiresAt == null
                ? _emailSpan(context, 'Signing in as {email}.')
                : _emailSpan(
                    context,
                    'Signing in as {email}. This sign-in expires at {time}.',
                    time: expiresAt,
                  ),
          ),
          if (passkeyUnsupported)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RaftAuthBanner(
                text: tr(
                  "This browser can't use passkeys. Use another way, or open Raft in a browser that has your passkey.",
                ),
                info: true,
              ),
            ),
          if (banner != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RaftAuthBanner(text: banner!),
            ),
          RaftAuthField(
            label: tr(totp ? 'Authenticator code' : 'Backup code'),
            helper: tr(
              totp ? 'Enter the 6-digit code from your authenticator app.' : 'Each code works once. Capitals and the hyphen are optional.',
            ),
            error: fieldError,
            child: codeField ?? const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          RaftAuthWideButton(
            key: const Key('second-factor-verify'),
            label: tr('Verify'),
            variant: RaftControlVariant.accent,
            onPressed: busy || !canVerify ? null : onVerify,
          ),
          if (switches.isNotEmpty) ...[
            RaftAuthOrDivider(label: tr('or')),
            for (final (i, s) in switches.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              RaftAuthWideButton(
                key: Key('second-factor-use-${s.method.name}'),
                label: tr(
                  s.method == RaftSecondFactorCodeMethod.totp
                      ? 'Use authenticator code'
                      : 'Use a backup code',
                ),
                variant: RaftControlVariant.outline,
                leading: s.method == RaftSecondFactorCodeMethod.totp
                    ? const RaftIcon(RaftGlyph.smartphone, size: 16)
                    : null,
                gap: 12,
                onPressed: busy ? null : s.onTap,
              ),
            ],
          ],
          const SizedBox(height: 16),
          RaftAuthTextLink(
            key: const Key('second-factor-back'),
            label: tr('Back to sign in'),
            onTap: busy ? null : onBack,
            bold: true,
            centered: true,
          ),
        ],
      ),
    );
  }

  String _noMethodReason(BuildContext context) => raftText(
    context,
    passkeyUnsupported
        ? "This browser can't use passkeys. Use another way, or open Raft in a browser that has your passkey."
        : "Two-step verification isn't available right now. Try again later.",
  );

  /// `{email}` in `<strong className="font-semibold text-foreground">`.
  InlineSpan _emailSpan(BuildContext context, String template, {String? time}) {
    final t = RaftTokens.of(context);
    final text = raftFormat(context, template, {'time': time ?? ''});
    final at = text.indexOf('{email}');
    if (at < 0) return TextSpan(text: text);
    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, at)),
        TextSpan(
          text: maskedEmail,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: t.semantic.foreground,
          ),
        ),
        TextSpan(text: text.substring(at + '{email}'.length)),
      ],
    );
  }
}
