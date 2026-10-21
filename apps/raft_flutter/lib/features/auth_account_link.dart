import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/server_error_code.dart';

/// Runs one sign-in step on the app's session client (the app owns it); the
/// "sign in and connect" and legal-acceptance steps need request fields the
/// plain `onLogin` / `onOAuth` callbacks do not carry.
typedef AuthAuthenticate = Future<void> Function(
  String origin,
  Future<void> Function(RaftClient client) action,
);

/// "Google", "GitHub" or "Apple" (Web `useAccountLinkSignIn` providerLabel).
String socialProviderLabel(String provider) => switch (provider) {
  'google' => 'Google',
  'github' => 'GitHub',
  _ => 'Apple',
};

/// A pending account link ended in a way the person has to be told about, or
/// moved to its dead end. Web `failPendingAccountLink` keeps the server code.
bool isAccountLinkFailure(Object error) {
  final code = serverErrorCode(error);
  return code != null &&
      code != 'pending_link_token_invalid' &&
      (code.startsWith('pending_link_') ||
          code == 'provider_conflict' ||
          code == 'account_link_unconfirmed');
}

/// The page's red banner for a failed link attempt (Web `auth.accountLink.*`;
/// anything unrecognised is the plain sign-in failure).
String accountLinkFailureText(
  BuildContext context,
  String? code,
  PendingAccountLink link,
) {
  final values = {
    'provider': socialProviderLabel(link.provider),
    'email': link.email,
  };
  final template = switch (code) {
    'pending_link_expired' => 'This {provider} sign-in has expired. Please sign in with {provider} again.',
    'pending_link_account_mismatch' => "You signed in to a different account than {email}, so {provider} wasn't connected. Please sign in with {email}.",
    'provider_conflict' => "This {provider} account is already connected to another Raft account, so it couldn't be connected here.",
    'account_link_unconfirmed' => "We couldn't connect {provider}, so you haven't been signed in. Please try again.",
    _ => 'Login failed',
  };
  return raftFormat(context, template, values);
}
