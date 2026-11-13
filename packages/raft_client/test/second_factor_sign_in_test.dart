// Server v1.24.0 two-step verification: POST /auth/login and POST
// /auth/mobile/oauth/complete can answer a challenge instead of tokens
// (routes/auth.ts, services/secondFactor/signIn.ts). Parsing that answer must
// never throw a cast error, and no session may exist until the second step.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final (int, Map<String, dynamic>) Function(RequestOptions) respond;
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
      jsonEncode(body),
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

Map<String, dynamic> _challenge({
  List<String> methods = const ['totp', 'backup_code'],
}) => {
  'secondFactorRequired': true,
  'challenge': _challengeToken,
  'expiresAt': '2030-01-01T00:05:00.000Z',
  'methods': methods,
  'maskedEmail': 'p***@example.invalid',
};

const _signedIn = {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'user': {'id': 'user-1', 'name': 'person'},
};

({RaftClient client, _Adapter adapter, MemorySessionStore store}) _setup(
  (int, Map<String, dynamic>) Function(RequestOptions) respond,
) {
  final adapter = _Adapter(respond), store = MemorySessionStore();
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: store,
    transport: Dio()..httpClientAdapter = adapter,
  );
  addTearDown(client.dispose);
  return (client: client, adapter: adapter, store: store);
}

Future<Object?> _caught(Future<void> Function() run) async {
  try {
    await run();
  } catch (e) {
    return e;
  }
  return null;
}

void main() {
  test(
    'a password sign-in challenge is not a cast error and stores nothing',
    () async {
      final s = _setup((_) => (200, _challenge()));
      final error = await _caught(
        () => s.client.login('p@example.invalid', 'pw'),
      );
      expect(error, isNotNull);
      expect(error, isNot(isA<TypeError>()));
      expect(error, isA<Exception>());
      expect(await s.store.read('https://example.invalid'), isNull);
      expect(s.client.user, isNull);
    },
  );

  test(
    'a mobile OAuth challenge is not a cast error and stores nothing',
    () async {
      final s = _setup((_) => (200, _challenge()));
      final error = await _caught(
        () => s.client.completeMobileOAuth('handoff', 'verifier-123'),
      );
      expect(error, isNotNull);
      expect(error, isNot(isA<TypeError>()));
      expect(error, isA<Exception>());
      expect(await s.store.read('https://example.invalid'), isNull);
    },
  );

  test('login reports the challenge; verify signs in with the code', () async {
    final s = _setup(
      (o) => o.path == '/auth/login' ? (200, _challenge()) : (200, _signedIn),
    );
    final error = await _caught(
      () => s.client.login('p@example.invalid', 'pw'),
    );
    final pending = error as SecondFactorRequired;
    expect(pending.challenge.maskedEmail, 'p***@example.invalid');
    expect(pending.challenge.methods, [
      SecondFactorMethod.totp,
      SecondFactorMethod.backupCode,
    ]);
    expect(pending.email, 'p@example.invalid');
    expect(pending.toString(), isNot(contains(_challengeToken)));

    await s.client.verifySecondFactor(pending, code: '123456');
    final verify = s.adapter.calls.last;
    expect(verify.path, '/auth/second-factor/verify');
    expect(verify.data, {'challenge': _challengeToken, 'code': '123456'});
    expect(s.client.user?.id, 'user-1');
    expect(
      (await s.store.read('https://example.invalid'))?.accessToken,
      'access',
    );
  });

  test(
    'a mobile OAuth second step sends the PKCE verifier and backup code',
    () async {
      final s = _setup(
        (o) => o.path == '/auth/mobile/oauth/complete'
            ? (200, _challenge())
            : (200, _signedIn),
      );
      final pending = await _caught(
        () => s.client.completeMobileOAuth('handoff', 'verifier-123'),
      ) as SecondFactorRequired;
      await s.client.verifySecondFactor(pending, backupCode: 'abcde-12345');
      expect(s.adapter.calls.last.data, {
        'challenge': _challengeToken,
        'backupCode': 'abcde-12345',
        'codeVerifier': 'verifier-123',
      });
      expect(s.client.user?.id, 'user-1');
    },
  );

  test(
    'an unreadable challenge fails the sign-in with a typed error',
    () async {
      final s = _setup(
        (_) => (200, {'secondFactorRequired': true, 'challenge': 'short'}),
      );
      final error = await _caught(
        () => s.client.login('p@example.invalid', 'pw'),
      );
      expect(error, isA<RaftApiException>());
      expect(await s.store.read('https://example.invalid'), isNull);
    },
  );

  test('a refused answer keeps its code, lock time and methods', () async {
    final s = _setup(
      (o) => o.path == '/auth/login'
          ? (200, _challenge())
          : (
              429,
              {
                'error': 'Too many wrong tries.',
                'code': 'second_factor_locked',
                'lockedUntil': '2030-01-01T00:15:00.000Z',
              },
            ),
    );
    final pending = await _caught(
      () => s.client.login('p@example.invalid', 'pw'),
    ) as SecondFactorRequired;
    final error = await _caught(
      () => s.client.verifySecondFactor(pending, code: '000000'),
    );
    final failure = SecondFactorFailure.of(error);
    expect(failure.code, 'second_factor_locked');
    expect(failure.lockedUntil, DateTime.utc(2030, 1, 1, 0, 15));
    expect(await s.store.read('https://example.invalid'), isNull);
  });

  test('a step-up refusal lists its methods', () async {
    final error = RaftApiException.response(
      'Verify it is you',
      status: 403,
      body: {
        'error': 'Verify it is you',
        'code': 'second_factor_step_up_required',
        'methods': ['totp', 'passkey', 'unknown'],
      },
    );
    expect(stepUpRequiredMethods(error), [
      SecondFactorMethod.totp,
      SecondFactorMethod.passkey,
    ]);
    expect(stepUpRequiredMethods(const RaftApiException('x')), isNull);
  });
}
