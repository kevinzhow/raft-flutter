// A person managing their own two-step verification (server v1.24.0
// routes/secondFactor.ts; Web components/settings/secondFactorApi.ts and
// components/auth/secondFactorRecovery.ts).
//
// Every signed-in call needs a full sign-in (a password or social sign-in,
// not a device login): otherwise 403 `session_family_required`. The server
// decides what proof each change needs: turning on needs a recent sign-in or
// POST /reauth/password (403 `reauth_required`); turning off, regenerating
// backup codes and removing a passkey take a second-factor answer in the same
// request (403 `step_up_required` with `methods` without one).
import 'client.dart';
import 'second_factor.dart';

/// `GET /auth/second-factor/status`.
class SecondFactorStatus {
  const SecondFactorStatus({
    required this.enabled,
    required this.totp,
    required this.passkeys,
    required this.backupCodesRemaining,
    this.sessionVerified,
  });
  final bool enabled, totp;
  final int passkeys, backupCodesRemaining;

  /// This sign-in passed the second step (at sign-in or by POST /step-up);
  /// null from servers that do not say.
  final bool? sessionVerified;

  static SecondFactorStatus parse(Object? data) {
    final body = data is Map ? data : const {};
    final methods = body['methods'] is Map ? body['methods'] as Map : const {};
    int count(Object? value) => value is num ? value.toInt() : 0;
    final verified = body['sessionVerified'];
    return SecondFactorStatus(
      enabled: body['enabled'] == true,
      totp: methods['totp'] == true,
      passkeys: count(methods['passkeys']),
      backupCodesRemaining: count(methods['backupCodesRemaining']),
      sessionVerified: verified is bool ? verified : null,
    );
  }
}

/// How many backup codes a fresh set has (server backupCodes.ts).
const backupCodeSetSize = 10;

/// From this many left and below, the section asks to regenerate.
const lowBackupCodes = 3;

/// A second-factor answer sent with the change it confirms. This client has
/// no passkeys: a code or a backup code.
class StepUpAnswer {
  const StepUpAnswer.code(String this.code) : backupCode = null;
  const StepUpAnswer.backupCode(String this.backupCode) : code = null;
  final String? code, backupCode;

  Map<String, String> get body => {
    if (code != null) 'code': code!,
    if (backupCode != null) 'backupCode': backupCode!,
  };
}

/// `{secret, otpauthUri}` of POST /totp/setup; never logged.
class TotpSetup {
  const TotpSetup(this.secret, this.otpauthUri);
  final String secret, otpauthUri;
  @override
  String toString() => 'TotpSetup(redacted)';
}

/// One of the person's passkeys (`GET /auth/second-factor/passkeys`).
class PasskeySummary {
  const PasskeySummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastUsedAt,
    required this.synced,
  });
  final String id;

  /// The person's label, the provider's name ("iCloud Keychain"), or "Passkey".
  final String name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  /// Backed up by its provider: shown as Synced.
  final bool synced;

  static PasskeySummary? parse(Object? value) {
    if (value is! Map) return null;
    final id = value['id'], name = value['name'];
    final created = value['createdAt'], used = value['lastUsedAt'];
    final createdAt = created is String ? DateTime.tryParse(created) : null;
    if (id is! String || name is! String || createdAt == null) return null;
    return PasskeySummary(
      id: id,
      name: name,
      createdAt: createdAt,
      lastUsedAt: used is String ? DateTime.tryParse(used) : null,
      synced: value['synced'] == true,
    );
  }
}

/// A request to reset two-step verification by email that is waiting or
/// ready (the server's RecoveryView).
class SecondFactorRecovery {
  const SecondFactorRecovery({
    required this.ready,
    required this.requestedAt,
    required this.eligibleAt,
    required this.expiresAt,
    required this.setPasswordFirst,
  });

  /// `status: ready`: [eligibleAt] passed, the next sign-in can finish it.
  final bool ready;
  final DateTime requestedAt, eligibleAt, expiresAt;

  /// `firstFactorRequired: set_password`: the account has no password and no
  /// connected sign-in, so it sets a password first.
  final bool setPasswordFirst;

  /// A RecoveryView, or null for anything else (Web `parseRecovery`).
  static SecondFactorRecovery? parse(Object? value) {
    if (value is! Map) return null;
    final status = value['status'];
    if (status != 'waiting' && status != 'ready') return null;
    DateTime? time(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final requested = time(value['requestedAt']);
    final eligible = time(value['eligibleAt']);
    final expires = time(value['expiresAt']);
    if (requested == null || eligible == null || expires == null) return null;
    return SecondFactorRecovery(
      ready: status == 'ready',
      requestedAt: requested,
      eligibleAt: eligible,
      expiresAt: expires,
      setPasswordFirst: value['firstFactorRequired'] == 'set_password',
    );
  }
}

const _base = '/auth/second-factor';

extension SecondFactorSettings on RaftClient {
  Future<SecondFactorStatus> secondFactorStatus() async =>
      SecondFactorStatus.parse(await get('$_base/status'));

  /// Off: needs a recent sign-in or [reauthenticateWithPassword] first (403
  /// `reauth_required`).
  Future<TotpSetup> startTotpSetup() async {
    final data = await post('$_base/totp/setup', data: const {});
    final body = data is Map ? data : const {};
    final secret = body['secret'], uri = body['otpauthUri'];
    if (secret is! String || uri is! String) {
      throw const RaftApiException('Something went wrong');
    }
    return TotpSetup(secret, uri);
  }

  /// A code from the app set up by [startTotpSetup] (or already confirmed)
  /// confirms it and turns two-step verification on. Returns the backup
  /// codes, once.
  Future<List<String>> enableSecondFactor(String code) async =>
      _codes(await post('$_base/enable', data: {'code': code}));

  Future<void> disableSecondFactor(StepUpAnswer answer) =>
      post('$_base/disable', data: answer.body);

  /// An authenticator code (the server refuses a backup code here).
  Future<List<String>> regenerateBackupCodes(String code) async => _codes(
    await post('$_base/backup-codes/regenerate', data: {'code': code}),
  );

  /// 204: this sign-in counts as re-authenticated for 10 minutes.
  Future<void> reauthenticateWithPassword(String password) =>
      post('$_base/reauth/password', data: {'password': password});

  /// Before approving an app login: the methods to step up with when two-step
  /// verification is on and this sign-in has not passed it, otherwise null
  /// (also when the status cannot be read: the approval then goes as before,
  /// with its 403 as the fallback). Web `stepUpBeforeApproval`.
  Future<List<SecondFactorMethod>?> stepUpBeforeApproval() async {
    final SecondFactorStatus status;
    try {
      status = await secondFactorStatus();
    } catch (_) {
      return null;
    }
    if (!status.enabled || status.sessionVerified != false) return null;
    return [
      if (status.totp) SecondFactorMethod.totp,
      if (status.passkeys > 0) SecondFactorMethod.passkey,
      if (status.backupCodesRemaining > 0) SecondFactorMethod.backupCode,
    ];
  }

  Future<List<PasskeySummary>> listPasskeys() async {
    final data = await get('$_base/passkeys');
    final rows = data is Map ? data['passkeys'] : null;
    return [
      if (rows is List)
        for (final row in rows)
          if (PasskeySummary.parse(row) case final passkey?) passkey,
    ];
  }

  Future<PasskeySummary?> renamePasskey(String id, String name) async {
    final data = await patch(
      '$_base/passkeys/${Uri.encodeComponent(id)}',
      data: {'name': name},
    );
    return PasskeySummary.parse(data is Map ? data['passkey'] : null);
  }

  /// With two-step verification on it needs [answer] (403 `step_up_required`
  /// with `methods` without one), and never takes the last factor (409
  /// `last_factor`).
  Future<void> removePasskey(String id, {StepUpAnswer? answer}) => delete(
    '$_base/passkeys/${Uri.encodeComponent(id)}',
    data: answer?.body ?? const <String, String>{},
  );

  /// Asks for the emailed reset link. Answers the same way whether or not
  /// the account exists. Signed out.
  Future<void> requestSecondFactorRecovery(String email) => request(
    'POST',
    '$_base/recovery',
    data: {'email': email.trim()},
    authorized: false,
  );

  /// This person's waiting or ready reset, or null.
  Future<SecondFactorRecovery?> secondFactorRecovery() async {
    final data = await get('$_base/recovery');
    return SecondFactorRecovery.parse(data is Map ? data['recovery'] : null);
  }

  /// Cancels this person's reset from a signed-in session: one step, no
  /// step-up.
  Future<void> cancelSecondFactorRecovery() => delete('$_base/recovery');
}

List<String> _codes(Object? data) {
  final codes = data is Map ? data['backupCodes'] : null;
  if (codes is! List || codes.any((c) => c is! String)) {
    throw const RaftApiException('Something went wrong');
  }
  return codes.cast<String>();
}
