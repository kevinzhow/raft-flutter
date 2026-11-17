// Server v1.24.0 account deletion (middleware/auth.ts): while a deletion is
// scheduled every API but GET/DELETE /me/account/deletion and POST
// /auth/logout answers 403 `account_deletion_pending` with `scheduledFor`.
// The client records it once, tells the app (`auth:account-deletion`) and
// keeps the session (Web store/accountDeletionPending.ts).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

const _scheduledFor = '2026-12-05T10:00:00.000Z';

class _Adapter implements HttpClientAdapter {
  _Adapter({this.meRefused = false});

  /// GET /auth/me is refused too (the restore of a person already scheduled).
  final bool meRefused;
  final calls = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add('${options.method} ${options.path}');
    if (options.path == '/auth/me' && !meRefused) {
      return ResponseBody.fromString(
        jsonEncode({'id': 'u1', 'name': 'Alice', 'email': 'a@example.invalid'}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    final allowed =
        options.path == '/logout' ||
        options.path == '/me/account/deletion' ||
        options.path.startsWith('/me/account/deletion/requests/');
    return ResponseBody.fromString(
      jsonEncode(
        allowed
            ? {'status': 'none'}
            : {
                'error': 'This account is scheduled for deletion. Cancel the deletion to use it again.',
                'code': 'account_deletion_pending',
                'scheduledFor': _scheduledFor,
              },
      ),
      allowed ? 200 : 403,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Every sign-in was revoked at the server: the API and the refresh say 401.
class _RevokedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode({'error': 'Invalid or expired refresh token'}),
    options.path == '/auth/me' ? 200 : 401,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _SignInAdapter implements HttpClientAdapter {
  final calls = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add('${options.method} ${options.path}');
    return ResponseBody.fromString(
      jsonEncode({
        'user': {'id': 'u1', 'name': 'Alice'},
        'accessToken': 'a',
        'refreshToken': 'r',
        'accountDeletion': {
          'status': 'scheduled',
          'scheduledFor': _scheduledFor,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(RaftClient, _Adapter, List<RaftEvent>)> _client({
  Map<String, dynamic>? cachedUser,
  bool meRefused = false,
}) async {
  final store = MemorySessionStore();
  await store.write(
    'https://example.invalid',
    Session(accessToken: 'a', refreshToken: 'r', cachedUser: cachedUser),
  );
  final adapter = _Adapter(meRefused: meRefused);
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: store,
    transport: Dio()..httpClientAdapter = adapter,
  );
  addTearDown(client.dispose);
  final events = <RaftEvent>[];
  client.events.listen(events.add);
  return (client, adapter, events);
}

void main() {
  test('403 account_deletion_pending is recorded once and announced', () async {
    final (client, _, events) = await _client();
    await client.restore();
    for (var i = 0; i < 2; i++) {
      await expectLater(
        client.get('/servers'),
        throwsA(isA<RaftApiException>()),
      );
    }
    await Future<void>.delayed(Duration.zero);
    // Dynamic so this file also compiles (and fails) on the code before it.
    final gate = (client as dynamic).accountDeletion;
    expect(gate.pending, isTrue);
    expect(gate.scheduledFor, _scheduledFor);
    expect(
      events.where((e) => e.name == 'auth:account-deletion'),
      hasLength(1),
    );
    // The person keeps the sign-in: Cancel Deletion and Sign Out need it.
    expect(client.signedIn, isTrue);
  });

  test('the routes a scheduled deletion still allows do not set it', () async {
    final (client, adapter, events) = await _client();
    await client.restore();
    await client.get('/me/account/deletion');
    await Future<void>.delayed(Duration.zero);
    expect((client as dynamic).accountDeletion.active, isFalse);
    expect(events.where((e) => e.name == 'auth:account-deletion'), isEmpty);
    expect(adapter.calls, contains('GET /me/account/deletion'));
  });

  test('a restore the server answers 403 pending still restores', () async {
    final (client, _, events) = await _client(meRefused: true);
    final restored = await client.restore();
    expect(restored, isTrue);
    expect((client as dynamic).accountDeletion.pending, isTrue);
    expect((client as dynamic).accountDeletion.scheduledFor, _scheduledFor);
    await Future<void>.delayed(Duration.zero);
    expect(events.where((e) => e.name == 'auth:account-deletion'), isNotEmpty);
    expect(client.user, isNotNull);
  });

  test(
    'a sign-in that says it is scheduled marks it before any request',
    () async {
      final adapter = _SignInAdapter();
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.dispose);
      await client.login('a@example.invalid', 'secret');
      final gate = (client as dynamic).accountDeletion;
      expect(gate.pending, isTrue);
      expect(gate.scheduledFor, _scheduledFor);
      expect(adapter.calls, ['POST /auth/login']);
    },
  );

  test('requested replaces the shell and clear hands it back', () async {
    final (client, _, events) = await _client(
      cachedUser: {'id': 'u1', 'name': 'Alice'},
    );
    await client.restore(cachedFirst: true);
    final gate = (client as dynamic).accountDeletion;
    gate.markRequested(_scheduledFor);
    expect(gate.active, isTrue);
    expect(gate.requestedScheduledFor, _scheduledFor);
    gate.clear();
    expect(gate.active, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(
      events.where((e) => e.name == 'auth:account-deletion').length,
      greaterThanOrEqualTo(2),
    );
  });

  for (final requested in [true, false]) {
    test(
      'a 401 after the sign-ins were revoked '
      '${requested ? 'keeps the confirmation' : 'ends the session'}',
      () async {
        final store = MemorySessionStore();
        await store.write(
          'https://example.invalid',
          Session(
            accessToken: 'a',
            refreshToken: 'r',
            cachedUser: {'id': 'u1'},
          ),
        );
        final client = RaftClient(
          origin: 'https://example.invalid',
          sessionStore: store,
          transport: Dio()..httpClientAdapter = _RevokedAdapter(),
        );
        addTearDown(client.dispose);
        final events = <RaftEvent>[];
        client.events.listen(events.add);
        await client.restore(cachedFirst: true);
        await client.sessionValidated;
        if (requested) {
          (client as dynamic).accountDeletion.markRequested(_scheduledFor);
        }
        await expectLater(
          client.get('/servers'),
          throwsA(isA<RaftApiException>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(client.signedIn, requested);
        expect(events.any((e) => e.name == 'session:ended'), !requested);
      },
    );
  }
}
