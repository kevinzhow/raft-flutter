import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

/// Answers each request from a script and records what was asked.
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

const _token = 'pending-link-handle-0123456789';
const _conflict = {
  'code': 'account_link_required',
  'error': 'An account with this email already exists.',
  'pendingLinkToken': _token,
  'provider': 'github',
  'email': 'person@example.invalid',
  'expiresAt': '2026-10-21T12:00:00.000Z',
  'signInMethods': {
    'password': true,
    'providers': ['google'],
  },
  'returnUri': 'raft://oauth/callback',
};

Map<String, dynamic> _session({String? linked}) => {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'user': {'id': 'user-1', 'name': 'person'},
  if (linked != null) 'linkedProvider': linked,
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

Future<RaftApiException> _conflictError() async {
  final s = _setup((_) => (409, _conflict));
  try {
    await s.client.completeMobileOAuth('code', 'verifier');
  } on RaftApiException catch (e) {
    return e;
  }
  throw StateError('the conflict was not raised');
}

void main() {
  test('the 409 conflict answer parses into a pending link', () async {
    final pending = PendingAccountLink.fromError(await _conflictError());
    expect(pending, isNotNull);
    expect(pending!.token, _token);
    expect(pending.provider, 'github');
    expect(pending.email, 'person@example.invalid');
    expect(pending.passwordSignIn, true);
    expect(pending.providers, ['google']);
    expect(pending.continuation.token, _token);
  });

  test('other failures and malformed handles are not a pending link', () async {
    expect(PendingAccountLink.fromError(StateError('x')), isNull);
    for (final bad in [
      {..._conflict, 'pendingLinkToken': 'short'},
      {..._conflict, 'provider': 'myspace'},
      {..._conflict, 'expiresAt': 'tomorrow'},
      {
        ..._conflict,
        'signInMethods': {'password': 'yes', 'providers': <String>[]},
      },
      {..._conflict, 'code': 'something_else'},
    ]) {
      final s = _setup((_) => (409, bad));
      Object? error;
      try {
        await s.client.completeMobileOAuth('c', 'v');
      } catch (e) {
        error = e;
      }
      expect(PendingAccountLink.fromError(error), isNull, reason: '$bad');
    }
  });

  test(
    'password sign-in carries the handle and needs the provider confirmed',
    () async {
      final s = _setup((_) => (200, _session(linked: 'github')));
      await s.client.login(
        'person@example.invalid',
        'secret',
        link: const AccountLinkContinuation(token: _token, provider: 'github'),
      );
      expect(s.adapter.calls.single.path, '/auth/login');
      expect(s.adapter.calls.single.data, {
        'email': 'person@example.invalid',
        'password': 'secret',
        'pendingLinkToken': _token,
      });
      expect(s.client.signedIn, true);
    },
  );

  test(
    'a sign-in that did not connect the provider publishes no session',
    () async {
      for (final linked in [null, 'google']) {
        final s = _setup((_) => (200, _session(linked: linked)));
        await expectLater(
          s.client.login(
            'person@example.invalid',
            'secret',
            link: const AccountLinkContinuation(
              token: _token,
              provider: 'github',
            ),
          ),
          throwsA(
            isA<RaftApiException>().having(
              (e) => e.details['code'],
              'code',
              'account_link_unconfirmed',
            ),
          ),
        );
        expect(s.client.signedIn, false);
        expect(s.client.user, isNull);
        expect(await s.store.read(s.client.origin), isNull);
      }
    },
  );

  test('browser sign-in completes the link with the same checks', () async {
    final s = _setup((_) => (200, _session(linked: 'github')));
    await s.client.completeMobileOAuth(
      'code',
      'verifier',
      link: const AccountLinkContinuation(token: _token, provider: 'github'),
    );
    expect(s.adapter.calls.single.path, '/auth/mobile/oauth/complete');
    expect(s.adapter.calls.single.data['pendingLinkToken'], _token);
    expect(s.client.signedIn, true);

    final unlinked = _setup((_) => (200, _session()));
    await expectLater(
      unlinked.client.completeMobileOAuth(
        'code',
        'verifier',
        link: const AccountLinkContinuation(token: _token, provider: 'github'),
      ),
      throwsA(isA<RaftApiException>()),
    );
    expect(unlinked.client.signedIn, false);
  });

  test(
    'an ordinary sign-in sends no handle and needs no confirmation',
    () async {
      final s = _setup((_) => (200, _session()));
      await s.client.login('person@example.invalid', 'secret');
      expect(
        s.adapter.calls.single.data.containsKey('pendingLinkToken'),
        false,
      );
      expect(s.client.signedIn, true);
    },
  );
}
