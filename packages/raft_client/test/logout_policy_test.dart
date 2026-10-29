// What signs the account out, and what must not (docs/architecture.md, "登出策略").
//
// The rule under test: the stored session ends only when the server says
// definitively that the credentials are dead (401 with the server's JSON error
// from the refresh endpoint, or from /auth/me after a fresh access token).
// Every other answer keeps the session and its stored credentials.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

const _origin = 'https://example.invalid';

/// A scripted server reply.
class _Reply {
  const _Reply(this.status, this.body, {this.html = false});
  final int status;
  final Object? body;
  final bool html;

  /// The server's own auth failure bodies (routes/auth.ts).
  static const refreshDead = _Reply(401, {
    'error': 'Invalid or expired refresh token',
  });
  static const tokenDead = _Reply(401, {
    'error': 'Invalid or expired token',
    'code': 'auth_required',
  });
  static const refreshOk = _Reply(200, {
    'accessToken': 'fixture-access-2',
    'refreshToken': 'fixture-refresh-2',
  });
}

class _Fault implements Exception {
  const _Fault(this.type);
  final DioExceptionType type;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  _Reply Function(RequestOptions) handler = (_) => const _Reply(200, {});
  final holds = <String, Completer<void>>{};

  int count(String key) =>
      requests.where((r) => '${r.method} ${r.path}' == key).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    requests.add(o);
    final reply = handler(o);
    final held = holds[o.path];
    if (held != null) await held.future;
    if (reply.body is _Fault) {
      throw DioException(
        requestOptions: o,
        type: (reply.body as _Fault).type,
        error: 'fixture',
      );
    }
    final text = reply.html
        ? (reply.body as String)
        : reply.body == null
        ? ''
        : jsonEncode(reply.body);
    return ResponseBody.fromString(
      text,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [
          reply.html ? 'text/html' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Sink implements SessionAuditSink {
  final events = <SessionAuditEvent>[];
  @override
  void record(SessionAuditEvent event) => events.add(event);
  Iterable<String> get ended =>
      events.where((e) => e.kind == 'session_end').map((e) => e.reason);
}

class _Store extends MemorySessionStore {
  Object? readError;
  int clears = 0;
  @override
  Future<Session?> read(String origin) async {
    if (readError != null) throw readError!;
    return super.read(origin);
  }

  @override
  Future<void> write(String origin, Session? session) {
    if (session == null) clears++;
    return super.write(origin, session);
  }
}

Session _session({bool cached = true}) => Session(
  accessToken: 'fixture-access-1',
  refreshToken: 'fixture-refresh-1',
  cachedUser: cached ? {'id': 'alice', 'name': 'Alice'} : null,
);

class _Rig {
  _Rig({
    bool cached = true,
    bool allowSessionEnd = true,
    List<Duration> backoff = const [],
  }) {
    client = RaftClient(
      origin: _origin,
      sessionStore: store,
      transport: Dio()..httpClientAdapter = adapter,
      auditSink: sink,
      allowSessionEnd: allowSessionEnd,
      recoveryBackoff: backoff,
    );
    store.write(_origin, _session(cached: cached));
  }
  final adapter = _Adapter();
  final sink = _Sink();
  final store = _Store();
  late final RaftClient client;
  final events = <String>[];

  Future<void> listen() async => client.events.listen((e) => events.add(e.name));

  /// The wire: expired access token on resources, scripted refresh and /me.
  void serve({
    required _Reply refresh,
    _Reply me = const _Reply(200, {'id': 'alice', 'name': 'Alice'}),
    _Reply resource = const _Reply(200, {'ok': true}),
  }) {
    adapter.handler = (o) {
      switch (o.path) {
        case '/auth/refresh':
          return refresh;
        case '/auth/me':
          return me;
        case '/auth/logout':
          return const _Reply(200, {'ok': true});
        default:
          final bearer = o.headers['Authorization'];
          return bearer == 'Bearer fixture-access-1'
              ? _Reply.tokenDead
              : resource;
      }
    };
  }

  /// Signs in through the real login call so the client holds the session.
  Future<void> signIn() async {
    adapter.handler = (o) => const _Reply(200, {
      'accessToken': 'fixture-access-1',
      'refreshToken': 'fixture-refresh-1',
      'user': {'id': 'alice', 'name': 'Alice'},
    });
    await client.login('alice@example.invalid', 'fixture');
    adapter.requests.clear();
    sink.events.clear();
    events.clear();
  }

  Future<void> dispose() => client.dispose();

  bool get revokedOnServer => adapter.count('POST /auth/logout') > 0;
}

Future<void> until(bool Function() test, {int ms = 5000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!test()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  // ---------------------------------------------------------------- refresh
  group('refresh endpoint answer decides sign-out', () {
    // name, reply, signs out
    final cases = <(String, _Reply, bool)>[
      ('401 with the server error (token invalid, expired or revoked)',
          _Reply.refreshDead, true),
      ('401 from a proxy: HTML page', _Reply(401, '<html>Sign in</html>', html: true), false),
      ('401 with an empty body', _Reply(401, null), false),
      ('400 missing token or bad replay binding',
          _Reply(400, {'error': 'Invalid refresh replay binding'}), false),
      ('403 from a WAF or captive portal', _Reply(403, {'error': 'Forbidden'}), false),
      ('403 HTML', _Reply(403, '<html>blocked</html>', html: true), false),
      ('404 behind a broken route', _Reply(404, {'error': 'Not found'}), false),
      ('408 request timeout', _Reply(408, {'error': 'Timeout'}), false),
      ('409 conflict', _Reply(409, {'error': 'Conflict'}), false),
      ('429 rate limited', _Reply(429, {'error': 'Slow down'}), false),
      ('500 refresh failed', _Reply(500, {'error': 'Token refresh failed'}), false),
      ('502 bad gateway', _Reply(502, '<html>bad gateway</html>', html: true), false),
      ('503 outage', _Reply(503, {'error': 'Temporary outage'}), false),
      ('504 gateway timeout', _Reply(504, null), false),
      ('200 that is not a token pair (captive portal)',
          _Reply(200, '<html>Welcome</html>', html: true), false),
      ('200 with an empty object', _Reply(200, {}), false),
      ('connection error', _Reply(0, _Fault(DioExceptionType.connectionError)), false),
      ('connect timeout', _Reply(0, _Fault(DioExceptionType.connectionTimeout)), false),
      ('receive timeout', _Reply(0, _Fault(DioExceptionType.receiveTimeout)), false),
    ];
    for (final (name, reply, signsOut) in cases) {
      test('$name -> ${signsOut ? 'sign out' : 'stay signed in'}', () async {
        final rig = _Rig();
        await rig.signIn();
        await rig.listen();
        rig.serve(refresh: reply);
        await expectLater(
          rig.client.get('/servers'),
          throwsA(isA<RaftApiException>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(rig.client.signedIn, !signsOut);
        final stored = await rig.store.read(_origin);
        expect(stored == null, signsOut, reason: 'stored credentials');
        if (signsOut) {
          expect(rig.events, contains('session:ended'));
          expect(rig.sink.ended, [SessionEndReason.refreshRejected.code]);
          expect(rig.client.lastEndReason, SessionEndReason.refreshRejected);
        } else {
          expect(rig.events, isNot(contains('session:ended')));
          expect(rig.sink.ended, isEmpty);
          expect(stored!.refreshToken, 'fixture-refresh-1');
          expect(
            rig.sink.events.map((e) => e.reason),
            contains('refresh_failed'),
          );
          expect(rig.client.sessionDegraded, isTrue);
        }
        // An involuntary end never revokes: the token is already dead, and
        // revoking with a stale one would revoke a newer owner's family.
        expect(rig.revokedOnServer, isFalse);
        await rig.dispose();
      });
    }
  });

  // ---------------------------------------------------------- resource 4xx/5xx
  group('resource answers never sign out', () {
    for (final status in [400, 402, 403, 404, 405, 409, 410, 413, 422, 423, 429, 500, 502, 503, 504]) {
      for (final structured in [true, false]) {
        test('$status ${structured ? 'JSON' : 'HTML'} on a resource keeps the session without a refresh', () async {
          final rig = _Rig();
          await rig.signIn();
          rig.serve(
            refresh: _Reply.refreshOk,
            resource: structured
                ? _Reply(status, {'error': 'Not a member of this server'})
                : _Reply(status, '<html>x</html>', html: true),
          );
          // A valid token: the resource itself answers.
          rig.adapter.handler = (o) => o.path == '/auth/logout'
              ? const _Reply(200, {})
              : structured
              ? _Reply(status, {'error': 'Not a member of this server'})
              : _Reply(status, '<html>x</html>', html: true);
          await expectLater(
            rig.client.get('/channels'),
            throwsA(isA<RaftApiException>().having((e) => e.status, 'status', status)),
          );
          expect(rig.client.signedIn, isTrue);
          expect(rig.adapter.count('POST /auth/refresh'), 0);
          expect((await rig.store.read(_origin))?.refreshToken, 'fixture-refresh-1');
          expect(rig.sink.ended, isEmpty);
          await rig.dispose();
        });
      }
    }

    test('403 for a server or channel never reaches the refresh endpoint', () async {
      final rig = _Rig();
      await rig.signIn();
      rig.client.selectServer('server-gone');
      rig.adapter.handler = (o) => const _Reply(403, {'error': 'Not a member of this server'});
      await expectLater(rig.client.get('/channels'), throwsA(isA<RaftApiException>()));
      expect(rig.client.signedIn, isTrue);
      expect(rig.adapter.requests.map((r) => r.path), ['/channels']);
      await rig.dispose();
    });

    test('401 on a resource refreshes once and retries with the new token', () async {
      final rig = _Rig();
      await rig.signIn();
      rig.serve(refresh: _Reply.refreshOk);
      expect(await rig.client.get('/servers'), {'ok': true});
      expect(rig.adapter.count('POST /auth/refresh'), 1);
      expect((await rig.store.read(_origin))!.refreshToken, 'fixture-refresh-2');
      await rig.dispose();
    });

    test('a request that was in flight during a rotation retries without rotating again', () async {
      final rig = _Rig();
      await rig.signIn();
      rig.adapter.handler = (o) {
        if (o.path == '/auth/refresh') return _Reply.refreshOk;
        return o.headers['Authorization'] == 'Bearer fixture-access-1'
            ? _Reply.tokenDead
            : const _Reply(200, {'ok': true});
      };
      // /slow was sent with the old token; its 401 arrives only after /fast
      // already rotated the credentials.
      rig.adapter.holds['/slow'] = Completer<void>();
      final slow = rig.client.get('/slow');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await rig.client.get('/fast'), {'ok': true});
      expect(rig.adapter.count('POST /auth/refresh'), 1);
      rig.adapter.holds['/slow']!.complete();
      expect(await slow, {'ok': true});
      expect(rig.adapter.count('POST /auth/refresh'), 1, reason: 'no second rotation');
      await rig.dispose();
    });
  });

  // ------------------------------------------------------ restore validation
  group('cached restore: /auth/me answer', () {
    // name, /me reply, refresh reply, signs out
    final cases = <(String, _Reply, _Reply, bool)>[
      ('200 account', _Reply(200, {'id': 'alice'}), _Reply.refreshOk, false),
      ('401 then refresh 401 (dead refresh token)', _Reply.tokenDead, _Reply.refreshDead, true),
      ('401 then refresh ok then 401 again (account retired)', _Reply.tokenDead, _Reply.refreshOk, true),
      ('401 then refresh 503', _Reply.tokenDead, _Reply(503, {'error': 'x'}), false),
      ('401 then refresh 403 from a proxy', _Reply.tokenDead, _Reply(403, {'error': 'x'}), false),
      ('401 HTML (proxy) then refresh ok', _Reply(401, '<html>login</html>', html: true), _Reply.refreshOk, false),
      ('400', _Reply(400, {'error': 'Bad request'}), _Reply.refreshOk, false),
      ('403', _Reply(403, {'error': 'Forbidden'}), _Reply.refreshOk, false),
      ('404', _Reply(404, {'error': 'Not found'}), _Reply.refreshOk, false),
      ('408', _Reply(408, {'error': 'Timeout'}), _Reply.refreshOk, false),
      ('429', _Reply(429, {'error': 'Slow down'}), _Reply.refreshOk, false),
      ('500', _Reply(500, {'error': 'Failed to get user'}), _Reply.refreshOk, false),
      ('503', _Reply(503, {'error': 'Temporary outage'}), _Reply.refreshOk, false),
      ('200 that is not an account (captive portal)', _Reply(200, '<html>Welcome</html>', html: true), _Reply.refreshOk, false),
      ('connection error', _Reply(0, _Fault(DioExceptionType.connectionError)), _Reply.refreshOk, false),
      ('receive timeout', _Reply(0, _Fault(DioExceptionType.receiveTimeout)), _Reply.refreshOk, false),
    ];
    for (final (name, me, refresh, signsOut) in cases) {
      test('$name -> ${signsOut ? 'sign out' : 'keep the session'}', () async {
        final rig = _Rig();
        await rig.listen();
        // /me with the expired token is the scripted `me`; after a refresh the
        // account check repeats the same answer unless it is a 200.
        rig.adapter.handler = (o) {
          if (o.path == '/auth/refresh') return refresh;
          if (o.path == '/auth/me') return me;
          return const _Reply(200, {});
        };
        expect(await rig.client.restore(cachedFirst: true), isTrue);
        await rig.client.sessionValidated;
        await Future<void>.delayed(Duration.zero);
        expect(rig.client.signedIn, !signsOut);
        final stored = await rig.store.read(_origin);
        expect(stored == null, signsOut);
        if (signsOut) {
          expect(rig.events, contains('session:ended'));
          expect(rig.client.user, isNull);
        } else {
          expect(rig.client.user?.id, 'alice');
          expect(stored!.refreshToken, anyOf('fixture-refresh-1', 'fixture-refresh-2'));
          if (me.status != 200 || me.body is! Map) {
            expect(rig.client.restoredOffline, isTrue);
          }
        }
        expect(rig.revokedOnServer, isFalse);
        await rig.dispose();
      });
    }
  });

  // ------------------------------------------------------- restore failures
  group('restore failure kinds', () {
    test('nothing stored is the only case that is plainly signed out', () async {
      final rig = _Rig();
      await rig.store.write(_origin, null);
      expect(await rig.client.restore(cachedFirst: true), isFalse);
      expect(rig.client.lastEndReason, isNull);
      await rig.dispose();
    });

    final storageErrors = <String, Object>{
      'Keystore/Keychain exception': StateError('KeyStoreException'),
      'unreadable record': const FormatException('Data has been reset'),
    };
    storageErrors.forEach((name, error) {
      test('secure storage failure ($name) is a retryable error and deletes nothing', () async {
        final rig = _Rig();
        rig.store.readError = error;
        await expectLater(
          rig.client.restore(cachedFirst: true),
          throwsA(
            isA<SessionRestoreException>().having(
              (e) => e.kind,
              'kind',
              SessionRestoreFailureKind.storage,
            ),
          ),
        );
        expect(rig.store.clears, 0);
        rig.store.readError = null;
        rig.serve(refresh: _Reply.refreshOk);
        expect(await rig.client.restore(cachedFirst: true), isTrue);
        expect(rig.client.user?.id, 'alice');
        expect(rig.sink.events.map((e) => e.reason), contains('storage_read'));
        await rig.dispose();
      });
    });

    final noCache = <(String, _Reply, SessionRestoreFailureKind)>[
      ('503', _Reply(503, {'error': 'x'}), SessionRestoreFailureKind.network),
      ('500', _Reply(500, {'error': 'x'}), SessionRestoreFailureKind.network),
      ('429', _Reply(429, {'error': 'x'}), SessionRestoreFailureKind.network),
      ('connection error', _Reply(0, _Fault(DioExceptionType.connectionError)), SessionRestoreFailureKind.network),
      ('timeout', _Reply(0, _Fault(DioExceptionType.receiveTimeout)), SessionRestoreFailureKind.network),
      ('403', _Reply(403, {'error': 'Forbidden'}), SessionRestoreFailureKind.unexpected),
      ('404', _Reply(404, {'error': 'x'}), SessionRestoreFailureKind.unexpected),
      ('HTML 200', _Reply(200, '<html>x</html>', html: true), SessionRestoreFailureKind.unexpected),
    ];
    for (final (name, reply, kind) in noCache) {
      test('no cached account and /auth/me $name -> recovery ($kind), credentials kept', () async {
        final rig = _Rig(cached: false);
        rig.adapter.handler = (o) => o.path == '/auth/me' ? reply : _Reply.refreshOk;
        await expectLater(
          rig.client.restore(cachedFirst: true),
          throwsA(isA<SessionRestoreException>().having((e) => e.kind, 'kind', kind)),
        );
        expect(rig.store.clears, 0);
        expect((await rig.store.read(_origin))?.refreshToken, 'fixture-refresh-1');
        expect(rig.client.lastEndReason, isNull);
        await rig.dispose();
      });
    }

    test('no cached account and a dead refresh token is a definitive sign-out', () async {
      final rig = _Rig(cached: false);
      rig.adapter.handler = (o) =>
          o.path == '/auth/me' ? _Reply.tokenDead : _Reply.refreshDead;
      expect(await rig.client.restore(cachedFirst: true), isFalse);
      expect(rig.client.lastEndReason, SessionEndReason.refreshRejected);
      expect(await rig.store.read(_origin), isNull);
      expect(rig.revokedOnServer, isFalse);
      await rig.dispose();
    });
  });

  // --------------------------------------------------------------- races
  group('refresh races and handoff', () {
    test('a refresh token rotated by another owner is adopted, not treated as rejected', () async {
      final rig = _Rig();
      await rig.signIn();
      await rig.listen();
      rig.adapter.handler = (o) {
        if (o.path == '/auth/refresh') {
          // The other owner stored its rotation while this request flew.
          rig.store.write(
            _origin,
            Session(
              accessToken: 'fixture-access-9',
              refreshToken: 'fixture-refresh-9',
              cachedUser: {'id': 'alice'},
            ),
          );
          return _Reply.refreshDead;
        }
        return o.headers['Authorization'] == 'Bearer fixture-access-9'
            ? const _Reply(200, {'ok': true})
            : _Reply.tokenDead;
      };
      expect(await rig.client.get('/servers'), {'ok': true});
      expect(rig.client.signedIn, isTrue);
      expect(rig.events, contains('session:credentials-updated'));
      expect(rig.revokedOnServer, isFalse);
      expect(rig.sink.events.map((e) => e.reason), contains('adopted_rotated_credentials'));
      await rig.dispose();
    });

    test('explicit logout revokes exactly once; involuntary end never does', () async {
      final rig = _Rig();
      await rig.signIn();
      rig.serve(refresh: _Reply.refreshOk);
      await rig.client.logout();
      expect(rig.adapter.count('POST /auth/logout'), 1);
      expect(rig.sink.ended, [SessionEndReason.userRequested.code]);
      await rig.dispose();
    });

    test('a background guest never signs the account out', () async {
      final rig = _Rig(allowSessionEnd: false);
      await rig.signIn();
      rig.serve(refresh: _Reply.refreshDead);
      await expectLater(rig.client.get('/servers'), throwsA(isA<RaftApiException>()));
      expect(rig.client.signedIn, isTrue);
      expect(rig.store.clears, 0);
      expect((await rig.store.read(_origin))?.refreshToken, 'fixture-refresh-1');
      expect(rig.sink.events.map((e) => e.kind), contains('session_end_suppressed'));
      await rig.dispose();
    });

    test('a failed credential write after rotation never signs out', () async {
      final rig = _Rig();
      rig.serve(refresh: _Reply.refreshOk);
      final failing = _FailingWriteStore(rig.store);
      final client = RaftClient(
        origin: _origin,
        sessionStore: failing,
        transport: Dio()..httpClientAdapter = rig.adapter,
        auditSink: rig.sink,
        recoveryBackoff: const [],
      );
      await client.restore(cachedFirst: true);
      failing.failWrites = true;
      await expectLater(client.get('/servers'), throwsA(anything));
      expect(client.signedIn, isTrue);
      await client.dispose();
      await rig.dispose();
    });

    test('requests that meet a failing refresh do not hammer the endpoint', () async {
      final rig = _Rig();
      await rig.signIn();
      rig.serve(refresh: _Reply(503, {'error': 'Temporary outage'}));
      for (var i = 0; i < 4; i++) {
        await expectLater(rig.client.get('/servers'), throwsA(isA<RaftApiException>()));
      }
      expect(rig.adapter.count('POST /auth/refresh'), 1);
      expect(rig.client.signedIn, isTrue);
      await rig.dispose();
    });
  });

  // -------------------------------------------------------------- recovery
  group('recovery of a kept session', () {
    test('a transient account check is retried with backoff until the server confirms', () async {
      final rig = _Rig(backoff: const [Duration(milliseconds: 20)]);
      await rig.listen();
      var up = false;
      rig.adapter.handler = (o) {
        if (o.path == '/auth/me') {
          return up ? const _Reply(200, {'id': 'alice', 'name': 'Alice'}) : const _Reply(503, {'error': 'x'});
        }
        return const _Reply(200, {});
      };
      expect(await rig.client.restore(cachedFirst: true), isTrue);
      await rig.client.sessionValidated;
      expect(rig.client.restoredOffline, isTrue);
      expect(rig.client.sessionDegraded, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(rig.adapter.count('GET /auth/me'), greaterThan(1), reason: 'retried');
      up = true;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(rig.client.restoredOffline, isFalse);
      expect(rig.client.sessionDegraded, isFalse);
      expect(rig.events, containsAllInOrder(['session:degraded', 'session:recovered']));
      await rig.dispose();
    });

    test('a manual retry settles true once the server answers', () async {
      final rig = _Rig();
      var up = false;
      rig.adapter.handler = (o) => o.path == '/auth/me'
          ? (up ? const _Reply(200, {'id': 'alice'}) : const _Reply(0, _Fault(DioExceptionType.connectionError)))
          : const _Reply(200, {});
      await rig.client.restore(cachedFirst: true);
      await rig.client.sessionValidated;
      expect(await rig.client.retrySession(), isFalse);
      up = true;
      expect(await rig.client.retrySession(), isTrue);
      expect(rig.client.restoredOffline, isFalse);
      await rig.dispose();
    });

    test('a definitive rejection found by a retry signs out', () async {
      final rig = _Rig();
      var phase = 0;
      rig.adapter.handler = (o) {
        if (o.path == '/auth/refresh') return _Reply.refreshDead;
        if (o.path == '/auth/me') return phase == 0 ? const _Reply(503, {'error': 'x'}) : _Reply.tokenDead;
        return const _Reply(200, {});
      };
      await rig.client.restore(cachedFirst: true);
      await rig.client.sessionValidated;
      expect(rig.client.signedIn, isTrue);
      phase = 1;
      await rig.client.retrySession();
      expect(rig.client.signedIn, isFalse);
      expect(rig.sink.ended, [SessionEndReason.refreshRejected.code]);
      await rig.dispose();
    });
  });

  // ---------------------------------------------------------------- audit
  group('structured log', () {
    test('records the reason and never a token, password or response body', () async {
      final rig = _Rig();
      await rig.signIn();
      rig.serve(refresh: _Reply.refreshDead);
      await expectLater(rig.client.get('/servers'), throwsA(isA<RaftApiException>()));
      final text = rig.sink.events.map((e) => e.toString()).join('\n');
      expect(text, contains('session_end reason=refresh_rejected status=401 endpoint=/auth/refresh'));
      expect(text, isNot(contains('fixture-access')));
      expect(text, isNot(contains('fixture-refresh')));
      expect(text, isNot(contains('Invalid or expired')));
      await rig.dispose();
    });

    test('free-form detail is stripped of token-like strings and emails', () {
      expect(
        sanitizeAuditDetail('bad eyJhbGciOiJIUzI1NiJ9.abcdefghijklmnop for a@b.example'),
        'bad <redacted> for <email>',
      );
      expect(sanitizeAuditDetail('word ' * 60).length, 120);
    });

    test('events round trip through JSON', () {
      final event = SessionAuditEvent('session_end', 'refresh_rejected', status: 401, endpoint: '/auth/refresh');
      final back = SessionAuditEvent.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(event.toJson()))),
      );
      expect(back.toString(), event.toString());
    });
  });

  // --------------------------------------------------------------- socket
  group('websocket authentication', () {
    test('[BP-RT-064] an expired token is refreshed and the handshake retried', () async {
      final server = await _EngineServer.start();
      addTearDown(server.close);
      server.script = (n, auth) => auth['token'] == 'fixture-access-2'
          ? null
          : 'Invalid or expired token';
      final rig = _Rig(backoff: const [Duration(milliseconds: 20)]);
      final store = MemorySessionStore();
      final origin = server.origin;
      await store.write(origin, _session());
      final adapter = _Adapter()
        ..handler = (o) => o.path == '/auth/refresh' ? _Reply.refreshOk : const _Reply(200, {});
      final client = RaftClient(
        origin: origin,
        sessionStore: store,
        transport: Dio()..httpClientAdapter = adapter,
        recoveryBackoff: const [Duration(milliseconds: 20)],
      );
      await client.restore();
      client.selectServer('server-a');
      client.connect();
      await until(() => server.connections.any((c) => c.accepted));
      expect(client.signedIn, isTrue);
      expect(adapter.count('POST /auth/refresh'), 1);
      expect(server.handshakeTokens.first, 'fixture-access-1');
      expect(server.handshakeTokens.last, 'fixture-access-2');
      await client.dispose();
      await rig.dispose();
    });

    test('a refresh token the server rejects ends the session; a transient refresh failure does not', () async {
      for (final dead in [true, false]) {
        final server = await _EngineServer.start();
        addTearDown(server.close);
        server.script = (n, auth) => 'Invalid or expired token';
        final store = MemorySessionStore();
        await store.write(server.origin, _session());
        final adapter = _Adapter()
          ..handler = (o) => o.path == '/auth/refresh'
              ? (dead ? _Reply.refreshDead : _Reply(503, {'error': 'x'}))
              : const _Reply(200, {});
        final sink = _Sink();
        final client = RaftClient(
          origin: server.origin,
          sessionStore: store,
          transport: Dio()..httpClientAdapter = adapter,
          auditSink: sink,
          recoveryBackoff: const [Duration(milliseconds: 30)],
        );
        final events = <String>[];
        client.events.listen((e) => events.add(e.name));
        await client.restore();
        client.selectServer('server-a');
        client.connect();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (dead) {
          expect(client.signedIn, isFalse, reason: 'dead refresh token');
          expect(events, contains('session:ended'));
          expect(await store.read(server.origin), isNull);
        } else {
          expect(client.signedIn, isTrue, reason: 'transient failure');
          expect(await store.read(server.origin), isNotNull);
          expect(server.connections.length, greaterThan(1), reason: 'retried with backoff');
          expect(sink.ended, isEmpty);
        }
        await client.dispose();
      }
    });

    test('"Authentication changed; reconnect required" reconnects without ending the session', () async {
      final server = await _EngineServer.start();
      addTearDown(server.close);
      server.script = (n, auth) => n == 0 ? 'Authentication changed; reconnect required' : null;
      final store = MemorySessionStore();
      await store.write(server.origin, _session());
      final adapter = _Adapter()..handler = (o) => const _Reply(200, {});
      final client = RaftClient(
        origin: server.origin,
        sessionStore: store,
        transport: Dio()..httpClientAdapter = adapter,
        recoveryBackoff: const [Duration(milliseconds: 30)],
      );
      await client.restore();
      client.selectServer('server-a');
      client.connect();
      await until(() => server.connections.any((c) => c.accepted));
      expect(client.signedIn, isTrue);
      expect(adapter.count('POST /auth/refresh'), 0);
      await client.dispose();
    });

    test('"Not a member of this server" is a server-level event and never touches the session', () async {
      final server = await _EngineServer.start();
      addTearDown(server.close);
      server.script = (n, auth) => 'Not a member of this server';
      final store = MemorySessionStore();
      await store.write(server.origin, _session());
      final adapter = _Adapter()..handler = (o) => const _Reply(200, {});
      final client = RaftClient(
        origin: server.origin,
        sessionStore: store,
        transport: Dio()..httpClientAdapter = adapter,
        recoveryBackoff: const [Duration(milliseconds: 30)],
      );
      final payloads = <dynamic>[];
      client.events.where((e) => e.name == 'connection:error').listen((e) => payloads.add(e.payload));
      await client.restore();
      client.selectServer('server-gone');
      client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(payloads.first, {'notServerMember': true});
      expect(client.signedIn, isTrue);
      expect(adapter.count('POST /auth/refresh'), 0);
      expect(await store.read(server.origin), isNotNull);
      await client.dispose();
    });

    test('a server-initiated disconnect (signed out elsewhere) reconnects, and the handshake decides', () async {
      final server = await _EngineServer.start();
      addTearDown(server.close);
      // First connection is accepted then dropped by the server; the second
      // handshake is told the token is dead, the refresh endpoint agrees.
      server.script = (n, auth) => n == 0 ? null : 'Invalid or expired token';
      server.disconnectAfterConnect = 1;
      final store = MemorySessionStore();
      await store.write(server.origin, _session());
      final adapter = _Adapter()
        ..handler = (o) => o.path == '/auth/refresh' ? _Reply.refreshDead : const _Reply(200, {});
      final client = RaftClient(
        origin: server.origin,
        sessionStore: store,
        transport: Dio()..httpClientAdapter = adapter,
        recoveryBackoff: const [Duration(milliseconds: 30)],
      );
      await client.restore();
      client.selectServer('server-a');
      client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(client.signedIn, isFalse);
      expect(client.lastEndReason, SessionEndReason.refreshRejected);
      await client.dispose();
    });
  });
}

class _FailingWriteStore implements SessionStore {
  _FailingWriteStore(this.inner);
  final SessionStore inner;
  bool failWrites = false;
  @override
  Future<Session?> read(String origin) => inner.read(origin);
  @override
  Future<void> write(String origin, Session? session) {
    if (failWrites) throw StateError('storage unavailable');
    return inner.write(origin, session);
  }
}

class _EngineConn {
  bool accepted = false;
}

/// A minimal Engine.IO v4 / Socket.IO v5 server over a real WebSocket.
class _EngineServer {
  _EngineServer(this._server);
  final HttpServer _server;
  final connections = <_EngineConn>[];
  final handshakeTokens = <String?>[];

  /// Returns null to accept the handshake, or the CONNECT_ERROR message.
  String? Function(int n, Map<String, dynamic> auth) script = (_, _) => null;
  int disconnectAfterConnect = 0;

  String get origin => 'http://127.0.0.1:${_server.port}';

  static Future<_EngineServer> start() async {
    final server = _EngineServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    server._server.listen(server._handle);
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(request);
    final conn = _EngineConn();
    final n = connections.length;
    connections.add(conn);
    ws.add(
      '0${jsonEncode({'sid': 'engine$n', 'upgrades': [], 'pingInterval': 25000, 'pingTimeout': 20000, 'maxPayload': 1000000})}',
    );
    ws.listen((message) {
      if (message is! String) return;
      if (message.startsWith('40')) {
        final raw = message.substring(2);
        final auth = raw.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(raw));
        handshakeTokens.add(auth['token'] as String?);
        final error = script(n, auth);
        if (error != null) {
          ws.add('44${jsonEncode({'message': error})}');
        } else {
          conn.accepted = true;
          ws.add('40${jsonEncode({'sid': 'socket$n'})}');
          if (n < disconnectAfterConnect) {
            Future<void>.delayed(const Duration(milliseconds: 50), () => ws.add('41'));
          }
        }
      } else if (message == '2') {
        ws.add('3');
      }
    }, onError: (_) {});
  }

  Future<void> close() => _server.close(force: true);
}
