// What Delete Account's page and its proof dialogs share (Web
// features/settings/account/deleteAccountFlow.ts): the request's outcome as a
// step sees it, how a step words a failed request, and the sign-in-again
// banner (DeleteAccountSignInAgainBanner.tsx, 403 `session_family_required`:
// this sign-in cannot delete the account; Sign in again signs out).
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'account_security_answer.dart';

/// What a step does with a failed request: another phase took over, Sign in
/// again, or the error to show.
sealed class AccountDeletionOutcome {
  const AccountDeletionOutcome();
}

class AccountDeletionMoved extends AccountDeletionOutcome {
  const AccountDeletionMoved();
}

class AccountDeletionNeedsSignIn extends AccountDeletionOutcome {
  const AccountDeletionNeedsSignIn();
}

class AccountDeletionFailed extends AccountDeletionOutcome {
  const AccountDeletionFailed(this.error);
  final Object error;
}

/// Sends the request; "moved" once another phase took over, the scheduled
/// confirmation included.
typedef AccountDeletionSubmit = Future<AccountDeletionOutcome> Function(
  AccountDeletionProof proof,
);

/// The failures the existing step-up copy words (a wrong password, a lock);
/// anything else is "couldn't delete".
const _stepUpFailureCodes = {
  'password_incorrect',
  'reauth_locked',
  'second_factor_locked',
};

/// Where a step shows a failed request (Web `useStepFailure`): the field's
/// error and a banner, or Sign in again.
({String? field, String? banner, bool signInAgain}) accountDeletionFailure(
  BuildContext context,
  RaftClient client,
  AccountDeletionOutcome? outcome,
  SecondFactorAnswerKind kind,
) {
  if (outcome == null || outcome is AccountDeletionMoved) {
    return (field: null, banner: null, signInAgain: false);
  }
  if (outcome is AccountDeletionNeedsSignIn) {
    return (field: null, banner: null, signInAgain: true);
  }
  final error = (outcome as AccountDeletionFailed).error;
  final code = SecondFactorFailure.of(error).code;
  if (code == 'email_code_invalid') {
    return (
      field: raftText(
        context,
        "That code didn't work. Check the email or ask for a new code.",
      ),
      banner: null,
      signInAgain: false,
    );
  }
  if (code != null && _stepUpFailureCodes.contains(code)) {
    final text = secondFactorFailureText(context, client, error, kind);
    final underField = secondFactorFailureUnderField(error);
    return (
      field: underField ? text : null,
      banner: underField ? null : text,
      signInAgain: false,
    );
  }
  return (
    field: null,
    banner: raftText(context, "Couldn't delete your account. Try again."),
    signInAgain: false,
  );
}

/// Web `DeleteAccountSignInAgainBanner`.
class AccountDeletionSignInAgainBanner extends StatelessWidget {
  const AccountDeletionSignInAgainBanner({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => RaftBanner(
    key: const ValueKey('account-deletion-sign-in-again'),
    status: RaftBannerRecipeStatus.warning,
    size: RaftBannerRecipeSize.sm,
    description: raftText(
      context,
      "This sign-in can't be used to delete your account. Sign in again, then try once more.",
    ),
    action: RaftButton(
      key: const ValueKey('account-deletion-sign-in-again-button'),
      label: raftText(context, 'Sign in again'),
      variant: RaftControlVariant.outline,
      onPressed: onSignOut,
    ),
  );
}
