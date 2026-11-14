// A scripted /auth/second-factor/* server (v1.24.0 routes/secondFactor.ts)
// for the Settings › Account security tests.
import 'package:raft_client/raft_client.dart';

RaftApiException secondFactorRefusal(
  int status,
  String code, {
  Map<String, Object?> extra = const {},
}) => RaftApiException.response(
  code,
  status: status,
  body: {'error': code, 'code': code, ...extra},
);

class SecondFactorServerClient extends RaftClient {
  SecondFactorServerClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'owner', 'email': 'fixture@example.invalid'});
  }

  bool enabled = false, totp = false, reauthed = false;
  bool passwordConfigured = true;
  int codesRemaining = 0;

  /// The status read answers 404 (feature off) or fails.
  int? statusFailure;
  final passkeys = <Map<String, Object?>>[];
  final calls = <({String method, String path, dynamic data})>[];

  static const goodCode = '123456';
  static const goodBackup = 'abcde-fghij';
  static List<String> freshCodes() => [
    for (var i = 0; i < 10; i++) 'code${i}x-fresh',
  ];

  Map<String, Object?> get status => {
    'enabled': enabled,
    'methods': {
      'totp': totp,
      'passkeys': passkeys.length,
      'backupCodesRemaining': codesRemaining,
    },
    'sessionVerified': true,
  };

  List<({String method, String path, dynamic data})> to(String path) => [
    for (final c in calls)
      if (c.path == path) c,
  ];

  void checkAnswer(dynamic data, {bool allowBackup = true}) {
    final body = data is Map ? data : const {};
    if (body['code'] == goodCode) return;
    if (allowBackup && body['backupCode'] == goodBackup) return;
    if (body['backupCode'] != null) {
      throw secondFactorRefusal(400, 'second_factor_code_invalid');
    }
    throw secondFactorRefusal(400, 'second_factor_code_invalid');
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    calls.add((method: method, path: path, data: data));
    const base = '/auth/second-factor';
    switch ((method, path)) {
      case ('GET', '$base/status'):
        if (statusFailure case final failure?) {
          throw secondFactorRefusal(failure, 'nope');
        }
        return status;
      case ('GET', '/auth/identities'):
        return {'passwordConfigured': passwordConfigured, 'identities': []};
      case ('POST', '$base/reauth/password'):
        if ((data as Map)['password'] != 'right-password') {
          throw secondFactorRefusal(401, 'password_incorrect');
        }
        reauthed = true;
        return null;
      case ('POST', '$base/totp/setup'):
        if (!reauthed) throw secondFactorRefusal(403, 'reauth_required');
        return {
          'secret': 'JBSWY3DPEHPK3PXP',
          'otpauthUri': 'otpauth://totp/Raft:fixture@example.invalid?secret=JBSWY3DPEHPK3PXP&issuer=Raft',
        };
      case ('POST', '$base/enable'):
        checkAnswer(data, allowBackup: false);
        enabled = totp = true;
        codesRemaining = 10;
        return {'backupCodes': freshCodes()};
      case ('POST', '$base/backup-codes/regenerate'):
        checkAnswer(data, allowBackup: false);
        codesRemaining = 10;
        return {'backupCodes': freshCodes()};
      case ('POST', '$base/disable'):
        checkAnswer(data);
        enabled = totp = false;
        codesRemaining = 0;
        return {'ok': true};
      case ('POST', '$base/step-up'):
        checkAnswer(data);
        return null;
      case ('GET', '$base/passkeys'):
        return {'passkeys': passkeys};
    }
    if (path.startsWith('$base/passkeys/')) {
      final id = Uri.decodeComponent(path.substring('$base/passkeys/'.length));
      final row = passkeys.where((p) => p['id'] == id).firstOrNull;
      if (row == null) throw secondFactorRefusal(404, 'passkey_not_found');
      if (method == 'PATCH') {
        final name = '${(data as Map)['name']}'.trim();
        if (name.isEmpty || name.length > 64) {
          throw secondFactorRefusal(400, 'invalid_request');
        }
        row['name'] = name;
        return {'passkey': row};
      }
      if (method == 'DELETE') {
        if (enabled) {
          if (!totp && passkeys.length <= 1) {
            throw secondFactorRefusal(409, 'last_factor');
          }
          final body = data is Map ? data : const {};
          if (body.isEmpty) {
            throw secondFactorRefusal(
              403,
              'step_up_required',
              extra: {
                'methods': [if (totp) 'totp', 'passkey', 'backup_code'],
              },
            );
          }
          checkAnswer(body);
        }
        passkeys.remove(row);
        return {'removed': true};
      }
    }
    return {};
  }
}

Map<String, Object?> fixturePasskey(
  String id,
  String name, {
  bool synced = false,
  String? lastUsedAt,
}) => {
  'id': id,
  'name': name,
  'createdAt': '2026-01-05T10:00:00.000Z',
  'lastUsedAt': lastUsedAt,
  'synced': synced,
};
