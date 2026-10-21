import 'client.dart';

/// Social providers an account can be connected to (Web `SocialAuthProviderId`).
const accountLinkProviders = {'google', 'github', 'apple'};

/// What a sign-in must carry to finish a pending "sign in and connect": the
/// short-lived server handle and the provider it was issued for. Web
/// `PendingAccountLink`; the handle is neither an OAuth token nor an address.
class AccountLinkContinuation {
  const AccountLinkContinuation({required this.token, required this.provider});
  final String token, provider;
}

/// The server's `409 account_link_required` answer to a social sign-in whose
/// email already belongs to an account (opt-in through `linkOnConflict`).
/// Web `parsePendingAccountLink` / `pendingAccountLinkFromError`.
class PendingAccountLink {
  const PendingAccountLink({
    required this.token,
    required this.provider,
    required this.email,
    required this.expiresAt,
    required this.passwordSignIn,
    required this.providers,
  });

  final String token, provider, email;
  final DateTime expiresAt;

  /// The existing account has a password, so "sign in and connect" can use it.
  final bool passwordSignIn;

  /// Providers the existing account already uses (other ways to sign in).
  final List<String> providers;

  AccountLinkContinuation get continuation =>
      AccountLinkContinuation(token: token, provider: provider);

  static final _tokenShape = RegExp(r'^[A-Za-z0-9_-]{16,512}$');

  /// Null unless [error] is the opt-in conflict answer with a well-formed
  /// handle; any other failure stays an ordinary error.
  static PendingAccountLink? fromError(Object? error) {
    if (error is! RaftApiException ||
        error.details['code'] != 'account_link_required') {
      return null;
    }
    final d = error.details;
    final token = d['pendingLinkToken'], provider = d['provider'];
    final email = d['email'], expiresAt = d['expiresAt'];
    final methods = d['signInMethods'];
    if (token is! String || !_tokenShape.hasMatch(token)) return null;
    if (provider is! String || !accountLinkProviders.contains(provider)) {
      return null;
    }
    final expires = expiresAt is String ? DateTime.tryParse(expiresAt) : null;
    if (email is! String || expires == null || methods is! Map) return null;
    final password = methods['password'], providers = methods['providers'];
    if (password is! bool ||
        providers is! List ||
        !providers.every(
          (p) => p is String && accountLinkProviders.contains(p),
        )) {
      return null;
    }
    return PendingAccountLink(
      token: token,
      provider: provider,
      email: email,
      expiresAt: expires,
      passwordSignIn: password,
      providers: List<String>.unmodifiable(providers.cast<String>()),
    );
  }
}

/// A finished sign-in must say it connected the provider (Web
/// `assertAccountLinkCompleted`): an older server that ignored the handle
/// would otherwise sign the person in without the connection.
RaftApiException? accountLinkNotCompleted(
  Object? result,
  AccountLinkContinuation? link,
) {
  if (link == null) return null;
  if (result is Map && result['linkedProvider'] == link.provider) return null;
  return RaftApiException.response(
    'ACCOUNT_LINK_NOT_COMPLETED',
    body: const {
      'error': 'ACCOUNT_LINK_NOT_COMPLETED',
      'code': 'account_link_unconfirmed',
    },
  );
}
