// Server v1.24.0 /auth/second-factor/* management (routes/secondFactor.ts;
// Web components/settings/secondFactorApi.ts, components/auth/
// secondFactorRecovery.ts): what each call sends and how the answers parse.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final (int, Object?) Function(RequestOptions) respond;
  final calls = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _challengeToken = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcde';

const _signedIn = {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'user': {'id': 'user-1', 'name': 'person'},
};

Future<({RaftClient client, _Adapter adapter})> _signedInClient(
  (int, Object?) Function(RequestOptions) respond,
) async {
  final adapter = _Adapter(
    (o) => o.path.endsWith('/auth/login') ? (200, _signedIn) : respond(o),
  );
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = adapter,
  );
  addTearDown(client.dispose);
  await client.login('p@example.invalid', 'pw');
  adapter.calls.clear();
  return (client: client, adapter: adapter);
}

Map<String, dynamic> _body(RequestOptions o) =>
    o.data is String ? jsonDecode(o.data as String) : o.data as dynamic;

void main() {
  test('status parses the counts and keeps an absent sessionVerified', () {
    final status = SecondFactorStatus.parse({
      'enabled': true,
      'methods': {'totp': true, 'passkeys': 2, 'backupCodesRemaining': 3},
    });
    expect(status.enabled, isTrue);
    expect(status.totp, isTrue);
    expect(status.passkeys, 2);
    expect(status.backupCodesRemaining, 3);
    expect(status.sessionVerified, isNull);
    // A shape this client doesn't know reads as off, never a cast error.
    final odd = SecondFactorStatus.parse(['x']);
    expect(odd.enabled, isFalse);
    expect(odd.backupCodesRemaining, 0);
  });

  test('recovery views parse only waiting or ready with valid times', () {
    final ready = SecondFactorRecovery.parse({
      'status': 'ready',
      'requestedAt': '2030-01-01T00:00:00.000Z',
      'eligibleAt': '2030-01-04T00:00:00.000Z',
      'expiresAt': '2030-01-11T00:00:00.000Z',
      'firstFactorRequired': 'set_password',
    })!;
    expect(ready.ready, isTrue);
    expect(ready.setPasswordFirst, isTrue);
    expect(
      SecondFactorRecovery.parse({
        'status': 'finished',
        'requestedAt': '2030-01-01T00:00:00.000Z',
        'eligibleAt': '2030-01-04T00:00:00.000Z',
        'expiresAt': '2030-01-11T00:00:00.000Z',
      }),
      isNull,
    );
    expect(
      SecondFactorRecovery.parse({
        'status': 'waiting',
        'requestedAt': 'soon',
        'eligibleAt': '2030-01-04T00:00:00.000Z',
        'expiresAt': '2030-01-11T00:00:00.000Z',
      }),
      isNull,
    );
  });

  test('management calls send what the server takes', () async {
    final s = await _signedInClient((o) {
      final path = o.path;
      if (path.endsWith('/totp/setup')) {
        return (200, {'secret': 'SECRET', 'otpauthUri': 'otpauth://totp/x'});
      }
      if (path.endsWith('/enable') || path.endsWith('/regenerate')) {
        return (200, {'backupCodes': List.filled(10, 'abcde-fghij')});
      }
      if (path.endsWith('/passkeys') && o.method == 'GET') {
        return (
          200,
          {
            'passkeys': [
              {
                'id': 'p1',
                'name': 'iCloud Keychain',
                'createdAt': '2030-01-01T00:00:00.000Z',
                'lastUsedAt': null,
                'synced': true,
              },
              {'id': 'broken'},
            ],
          },
        );
      }
      return (200, {'ok': true});
    });
    final c = s.client;
    final setup = await c.startTotpSetup();
    expect(setup.secret, 'SECRET');
    expect('$setup', isNot(contains('SECRET')));
    expect(await c.enableSecondFactor('123456'), hasLength(10));
    await c.disableSecondFactor(const StepUpAnswer.backupCode('abcde-fghij'));
    await c.regenerateBackupCodes('654321');
    await c.reauthenticateWithPassword('pw');
    final passkeys = await c.listPasskeys();
    await c.renamePasskey('p1', 'Laptop');
    await c.removePasskey('p1', answer: const StepUpAnswer.code('111111'));
    await c.removePasskey('p1');
    await c.cancelSecondFactorRecovery();

    expect(passkeys.single.name, 'iCloud Keychain');
    expect(passkeys.single.lastUsedAt, isNull);
    expect(passkeys.single.synced, isTrue);
    final sent = [for (final o in s.adapter.calls) (o.method, o.path)];
    expect(sent, [
      ('POST', '/auth/second-factor/totp/setup'),
      ('POST', '/auth/second-factor/enable'),
      ('POST', '/auth/second-factor/disable'),
      ('POST', '/auth/second-factor/backup-codes/regenerate'),
      ('POST', '/auth/second-factor/reauth/password'),
      ('GET', '/auth/second-factor/passkeys'),
      ('PATCH', '/auth/second-factor/passkeys/p1'),
      ('DELETE', '/auth/second-factor/passkeys/p1'),
      ('DELETE', '/auth/second-factor/passkeys/p1'),
      ('DELETE', '/auth/second-factor/recovery'),
    ]);
    final calls = s.adapter.calls;
    expect(_body(calls[1]), {'code': '123456'});
    expect(_body(calls[2]), {'backupCode': 'abcde-fghij'});
    expect(_body(calls[3]), {'code': '654321'});
    expect(_body(calls[4]), {'password': 'pw'});
    expect(_body(calls[6]), {'name': 'Laptop'});
    expect(_body(calls[7]), {'code': '111111'});
    // Without an answer the server says which methods it takes.
    expect(_body(calls[8]), isEmpty);
  });

  test('the recovery request goes signed out and trims the email', () async {
    final adapter = _Adapter((_) => (200, {'ok': true}));
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.dispose);
    await client.requestSecondFactorRecovery('  p@example.invalid ');
    final call = adapter.calls.single;
    expect(call.path, endsWith('/auth/second-factor/recovery'));
    expect(_body(call), {'email': 'p@example.invalid'});
    expect(call.headers['Authorization'], isNull);
  });

  test('finishing a ready reset answers the challenge with recovery', () async {
    final adapter = _Adapter((_) => (200, _signedIn));
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.dispose);
    final pending = SecondFactorRequired(
      SecondFactorChallenge.parse({
        'secondFactorRequired': true,
        'challenge': _challengeToken,
        'expiresAt': '2030-01-01T00:05:00.000Z',
        'methods': ['totp', 'recovery'],
        'maskedEmail': 'p***@example.invalid',
      })!,
    );
    expect(pending.challenge.recoveryReady, isTrue);
    await client.verifySecondFactor(pending, recovery: true);
    expect(_body(adapter.calls.single), {
      'challenge': _challengeToken,
      'recovery': true,
    });
    expect(client.user?.id, 'user-1');
    expect(
      () => client.verifySecondFactor(pending, code: '1', recovery: true),
      throwsArgumentError,
    );
  });
}
