// Web v1.21.23 SocialAuthCallbackPage `needsLegalAcceptance`: after a social
// sign-in the server can ask for an explicit acceptance of the current terms
// before it creates the account. Presentation only: the app keeps the
// one-time sign-in code and sends it again with the acceptance.
import 'package:flutter/widgets.dart';

import 'auth_page.dart';
import 'design_primitives.dart';
import 'localization.dart';

class RaftAuthLegalPage extends StatelessWidget {
  const RaftAuthLegalPage({
    super.key,
    required this.providerLabel,
    required this.accepted,
    required this.busy,
    required this.changed,
    required this.onAccepted,
    required this.onContinue,
    required this.onBack,
    required this.onTerms,
    required this.onPrivacy,
    this.error,
  });

  /// "Google", "GitHub" or "Apple": the page is "{provider} sign-in".
  final String providerLabel;
  final bool accepted, busy;

  /// The terms changed since the account accepted them (`TERMS_CHANGED`).
  final bool changed;

  /// A failed attempt to finish (already localized).
  final String? error;
  final ValueChanged<bool> onAccepted;
  final VoidCallback onContinue, onBack, onTerms, onPrivacy;

  @override
  Widget build(BuildContext context) {
    final banner =
        error ??
        (changed
            ? raftText(
                context,
                'The Terms of Service or Privacy Policy changed. Review and continue.',
              )
            : null);
    return RaftAuthShell(
      // Native only: Web leaves through the browser's own navigation.
      overlayLink: RaftAuthTextLink(
        key: const Key('legal-back'),
        label: raftText(context, 'Back to Sign In'),
        onTap: busy ? null : onBack,
        centered: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAuthIntro(
            title: raftFormat(context, '{provider} sign-in', {
              'provider': providerLabel,
            }),
          ),
          if (banner != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RaftAuthBanner(text: banner),
            ),
          RaftAuthLegalCheckbox(
            key: const Key('legal-checkbox'),
            checked: accepted,
            onChanged: busy ? null : onAccepted,
            onTerms: onTerms,
            onPrivacy: onPrivacy,
          ),
          const SizedBox(height: 16),
          RaftAuthWideButton(
            key: const Key('legal-continue'),
            label: raftText(context, busy ? 'Finishing…' : 'Continue'),
            variant: RaftControlVariant.accent,
            onPressed: accepted && !busy ? onContinue : null,
          ),
        ],
      ),
    );
  }
}
