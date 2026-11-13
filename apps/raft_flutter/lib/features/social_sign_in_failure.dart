// Web v1.24 utils/desktopOAuth.ts `describeDesktopSignInFailure`: Raft
// Desktop signs in over the same `/auth/mobile/oauth/*` pair as this app, and
// says what a failed browser leg means instead of one generic line.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/oauth_broker.dart';

/// `FAILURE_MESSAGE_IDS` (auth.desktopSignIn.*), by the server's reason.
const socialSignInFailureCopy = <String, String>{
  'account_conflict': 'This email already has a Raft account created another way. Sign in with email and password (or an email code) first, then link {provider} in Settings → Connected accounts.',
  'registration_disabled': "Your {provider} account isn't registered with Raft yet and sign-up is currently closed. Ask for an invite, or sign in with an existing account.",
  'expired': 'The sign-in request expired before the browser finished. Please try again.',
  'request_not_pending':
      'That sign-in request was already used or cancelled. Please try again.',
  'provider_cancelled':
      '{provider} sign-in was cancelled before Raft was authorized.',
  'access_denied': '{provider} sign-in was denied at the provider. Try again if that was unintended.',
  'provider_exchange_failed': "Raft couldn't finish verifying your {provider} account. Please try again; if it keeps failing, an unverified email at {provider} is one possible cause.",
};

/// The sentence for a browser leg that came back with the server's reason, or
/// null for any other failure (the caller keeps its own text). A known reason
/// says what happened; an unknown one keeps the generic line plus the code to
/// quote to support (`auth.desktopSignIn.failedWithReason`).
String? socialSignInFailureText(
  BuildContext context,
  Object error,
  String providerLabel,
) {
  if (error is! OAuthCallbackFailure) return null;
  final code = error.code;
  final copy = code == null ? null : socialSignInFailureCopy[code];
  if (copy != null) {
    return raftFormat(context, copy, {'provider': providerLabel});
  }
  return code == null
      ? raftFormat(
          context,
          "Couldn't complete {provider} sign-in — please try again, or sign in with email and password.",
          {'provider': providerLabel},
        )
      : raftFormat(
          context,
          "Couldn't complete {provider} sign-in — please try again, or sign in with email and password. (reason: {reason})",
          {'provider': providerLabel, 'reason': code},
        );
}

/// Web v1.24 SocialAuthCallbackPage `linkFailureMessageId` (Settings →
/// "Connect"): the refusals the person can act on, never the raw server text
/// and never which account holds anything. `provider_conflict` covers more
/// than one case; only the server's English sentence tells them apart. Null
/// for any other failure.
String? socialLinkFailureText(
  BuildContext context,
  Object error,
  String providerLabel,
) {
  if (error is! RaftApiException) return null;
  final code = error.details['code'];
  final copy = switch (code) {
    'email_verification_required' => "Verify your Raft account email first. Until it's verified, you can only connect a {provider} account whose primary email matches your Raft email.",
    'provider_conflict'
        when error.message.contains('already linked to another') =>
      'This {provider} account is already connected to another Raft account. Disconnect it there first, then try again.',
    'provider_conflict' => "This {provider} account is already used by another Raft account, so it couldn't be connected here.",
    _ => null,
  };
  return copy == null
      ? socialSignInFailureText(context, error, providerLabel)
      : raftFormat(context, copy, {'provider': providerLabel});
}
