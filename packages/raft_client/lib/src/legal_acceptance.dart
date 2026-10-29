import 'client.dart';

/// The terms and privacy versions an explicit acceptance names. Web sends its
/// own `CURRENT_LEGAL_ACCEPTANCE`; a native client asks the server instead
/// (the rejection carries `legal`) so the versions cannot drift from it.
class LegalVersions {
  const LegalVersions({
    required this.termsVersion,
    required this.privacyVersion,
  });

  /// What this build shipped with (`CURRENT_TERMS_VERSION`).
  static const current = LegalVersions(
    termsVersion: '2026-05-12',
    privacyVersion: '2026-05-12',
  );

  final String termsVersion, privacyVersion;

  /// The versions the server named in a legal-acceptance rejection, or null.
  static LegalVersions? fromError(Object? error) {
    final legal = error is RaftApiException ? error.details['legal'] : null;
    if (legal is! Map) return null;
    final terms = legal['termsVersion'], privacy = legal['privacyVersion'];
    return terms is String &&
            terms.isNotEmpty &&
            privacy is String &&
            privacy.isNotEmpty
        ? LegalVersions(termsVersion: terms, privacyVersion: privacy)
        : null;
  }
}

/// `LEGAL_ACCEPTANCE_REQUIRED` (nothing accepted yet) or `TERMS_CHANGED` (the
/// versions sent are not the current ones): the sign-in needs an explicit
/// acceptance before the server creates the account.
bool isLegalAcceptanceRejection(Object? error) =>
    error is RaftApiException &&
    (error.message == 'LEGAL_ACCEPTANCE_REQUIRED' ||
        error.message == 'TERMS_CHANGED');
