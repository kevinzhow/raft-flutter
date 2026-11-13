// Two-step verification (server v1.24.0, Web components/auth/
// secondFactorSignIn.ts and components/settings/secondFactorApi.ts).
//
// POST /auth/login and POST /auth/mobile/oauth/complete answer
// `{secondFactorRequired: true, challenge, expiresAt, methods, maskedEmail}`
// instead of tokens for a person who turned two-step verification on. The
// second step is POST /auth/second-factor/verify `{challenge, code |
// backupCode, codeVerifier?}`; it answers with the body the first step would
// have given. Sensitive writes answer 403 `second_factor_step_up_required`
// with `methods` until POST /auth/second-factor/step-up passes.
import 'account_link.dart';
import 'client.dart';

/// A second factor the server lists: only what the person set up.
enum SecondFactorMethod {
  totp('totp'),
  passkey('passkey'),
  backupCode('backup_code');

  const SecondFactorMethod(this.wire);
  final String wire;

  static SecondFactorMethod? parse(Object? value) {
    for (final method in values) {
      if (method.wire == value) return method;
    }
    return null;
  }
}

/// The `methods` of a challenge, a lock or a step-up refusal; unknown entries
/// dropped (Web `parseMethods`).
List<SecondFactorMethod> parseSecondFactorMethods(Object? value) => [
  if (value is List)
    for (final entry in value)
      if (SecondFactorMethod.parse(entry) case final method?) method,
];

/// The methods a native client can answer with, in Web's order (D4: passkey,
/// authenticator code, backup code). This client cannot use passkeys, so a
/// listed passkey only sets [passkeyUnsupported] (Web `usableMethodsOf` in a
/// browser without WebAuthn).
({List<SecondFactorMethod> methods, bool passkeyUnsupported})
usableSecondFactorMethods(List<SecondFactorMethod> listed) => (
  methods: [
    for (final method in const [
      SecondFactorMethod.totp,
      SecondFactorMethod.backupCode,
    ])
      if (listed.contains(method)) method,
  ],
  passkeyUnsupported: listed.contains(SecondFactorMethod.passkey),
);

/// The opaque sign-in challenge the first step answered with.
class SecondFactorChallenge {
  const SecondFactorChallenge({
    required this.challenge,
    required this.expiresAt,
    required this.methods,
    required this.recoveryReady,
    required this.maskedEmail,
  });

  /// Single use, five minutes; never logged.
  final String challenge;
  final DateTime expiresAt;
  final List<SecondFactorMethod> methods;

  /// The challenge also lists `recovery`: an email reset is ready to finish.
  final bool recoveryReady;

  /// `a***@example.com`.
  final String maskedEmail;

  static final _token = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// A first step's answer that asks for the second step; null for any other
  /// answer (Web `parseSecondFactorChallenge`).
  static SecondFactorChallenge? parse(Object? data) {
    if (data is! Map || data['secondFactorRequired'] != true) return null;
    final challenge = data['challenge'], expires = data['expiresAt'];
    final masked = data['maskedEmail'];
    if (challenge is! String || !_token.hasMatch(challenge)) return null;
    final expiresAt = expires is String ? DateTime.tryParse(expires) : null;
    if (expiresAt == null || masked is! String) return null;
    final methods = data['methods'];
    return SecondFactorChallenge(
      challenge: challenge,
      expiresAt: expiresAt,
      methods: parseSecondFactorMethods(methods),
      recoveryReady: methods is List && methods.contains('recovery'),
      maskedEmail: masked,
    );
  }

  /// [parse] for a sign-in answer: a second step in a shape this client
  /// cannot read fails the sign-in instead of reading as signed in (Web
  /// `readSecondFactorChallenge`).
  static SecondFactorChallenge? read(Object? data) {
    final challenge = parse(data);
    if (challenge == null &&
        data is Map &&
        data['secondFactorRequired'] == true) {
      throw const RaftApiException('Sign-in failed');
    }
    return challenge;
  }

  @override
  String toString() => 'SecondFactorChallenge(redacted)';
}

/// The first sign-in step passed and the server asks for the second one.
/// Thrown by [RaftClient.login] and [RaftClient.completeMobileOAuth]; the
/// sign-in page shows the "Two-step verification" step and answers with
/// [RaftClient.verifySecondFactor]. No session exists yet.
class SecondFactorRequired implements Exception {
  const SecondFactorRequired(
    this.challenge, {
    this.email,
    this.codeVerifier,
    this.link,
  });
  final SecondFactorChallenge challenge;

  /// The email typed at the first step (a password sign-in).
  final String? email;

  /// The mobile OAuth PKCE verifier, sent back with the answer.
  final String? codeVerifier;

  /// The "sign in and connect" this sign-in continues.
  final AccountLinkContinuation? link;

  @override
  String toString() => 'Two-step verification required';
}

/// A refused second-factor call (Web `secondFactorFailureOf`).
class SecondFactorFailure {
  const SecondFactorFailure({
    this.status,
    this.code,
    this.lockedUntil,
    this.methods = const [],
  });
  final int? status;
  final String? code;

  /// On `second_factor_locked` / `reauth_locked`.
  final DateTime? lockedUntil;

  /// On `second_factor_step_up_required` / `step_up_required`.
  final List<SecondFactorMethod> methods;

  static SecondFactorFailure of(Object? error) {
    if (error is! RaftApiException) return const SecondFactorFailure();
    final code = error.details['code'], locked = error.details['lockedUntil'];
    return SecondFactorFailure(
      status: error.status,
      code: code is String ? code : null,
      lockedUntil: locked is String ? DateTime.tryParse(locked) : null,
      methods: parseSecondFactorMethods(error.details['methods']),
    );
  }
}

/// The methods of a 403 `second_factor_step_up_required`, or null for any
/// other outcome (Web `stepUpRequiredMethods`).
List<SecondFactorMethod>? stepUpRequiredMethods(Object? error) {
  final failure = SecondFactorFailure.of(error);
  return failure.status == 403 &&
          failure.code == 'second_factor_step_up_required'
      ? failure.methods
      : null;
}

/// What the person typed, as the server takes it: no spaces (Web
/// `normalizeEnteredCode`).
String normalizeSecondFactorCode(String value) =>
    value.replaceAll(RegExp(r'\s+'), '');
