// "Sign in and connect" (Web v1.21.23 LoginPage `accountLink`): a social
// sign-in whose email already has an account asks the person to sign in to
// that account, which then also connects the provider. Presentation only: the
// app owns the pending handle and every request.
import 'package:flutter/widgets.dart';

import 'auth_page.dart';
import 'design_primitives.dart';
import 'localization.dart';

/// The state of a pending account link, as the sign-in page shows it.
@immutable
class RaftAuthAccountLink {
  const RaftAuthAccountLink({
    required this.providerLabel,
    required this.passwordSignIn,
    required this.onCancel,
    required this.onRestart,
    this.expired = false,
    this.conflict = false,
  });

  /// "Google", "GitHub" or "Apple".
  final String providerLabel;

  /// The existing account has a password: the form signs in with it.
  final bool passwordSignIn;

  /// The handle ran out: the only way on is to start the provider again.
  final bool expired;

  /// The provider account belongs to another account: nothing left to try.
  final bool conflict;

  /// "Don't connect {provider}" / "Back to Sign In" (null while busy).
  final VoidCallback? onCancel;

  /// "Continue with {provider}" after [expired].
  final VoidCallback? onRestart;

  bool get terminal => expired || conflict;
}

/// What follows the form and the social buttons on the account-link page:
/// the restart button of an expired link, then the cancel button.
class RaftAuthAccountLinkActions extends StatelessWidget {
  const RaftAuthAccountLinkActions({super.key, required this.link});
  final RaftAuthAccountLink link;

  @override
  Widget build(BuildContext context) {
    final provider = {'provider': link.providerLabel};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (link.expired) ...[
          const SizedBox(height: 16),
          RaftAuthWideButton(
            key: const Key('account-link-restart'),
            label: raftFormat(context, 'Continue with {provider}', provider),
            variant: RaftControlVariant.accent,
            onPressed: link.onRestart,
          ),
        ],
        const SizedBox(height: 16),
        RaftAuthWideButton(
          key: const Key('account-link-cancel'),
          label: link.terminal
              ? raftText(context, 'Back to Sign In')
              : raftFormat(context, "Don't connect {provider}", provider),
          variant: RaftControlVariant.outline,
          onPressed: link.onCancel,
        ),
      ],
    );
  }
}
