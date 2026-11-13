import 'client.dart';

/// The terms and privacy versions an explicit acceptance names. Web sends
/// `CURRENT_LEGAL_ACCEPTANCE` from `@botiverse/raft-shared` (legalAcceptance
/// .ts), built into the same release as its server; it never reads them at
/// runtime. A native client ships that release's constants as [current] and,
/// because it outlives the server it was built against, takes the versions
/// the server names in a `TERMS_CHANGED` rejection (`legal`) for the next
/// explicit acceptance ([fromError]).
class LegalVersions {
  const LegalVersions({
    required this.termsVersion,
    required this.privacyVersion,
  });

  /// Raft v1.24.0 `CURRENT_TERMS_VERSION` / `CURRENT_PRIVACY_VERSION`. The
  /// 2026-10-14 privacy version adds the usage-data notice the sign-up pages
  /// show under Continue.
  static const current = LegalVersions(
    termsVersion: '2026-05-12',
    privacyVersion: '2026-10-14',
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
