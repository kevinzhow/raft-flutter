import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.me, {this.status = 200});
  final Map<String, dynamic> me;
  final int status;
  final gate = Completer<void>();
  final paths = <String>[];
  final requests = <RequestOptions>[];
  bool rotated = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    paths.add('${o.method} ${o.path}');
    requests.add(o);
    if (o.path == '/auth/me') await gate.future;
    final (body, code) = switch (o.path) {
      '/auth/me' => (me, status),
      '/auth/refresh' when rotated => (
        <String, dynamic>{
          'accessToken': 'refreshed-fixture',
          'refreshToken': 'refreshed-fixture',
        },
        200,
      ),
      '/auth/refresh' => (<String, dynamic>{'error': 'Revoked'}, 401),
      _ => (<String, dynamic>{'ok': true}, 200),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(RaftClient, _Adapter, MemorySessionStore)> _restore(
  Map<String, dynamic> me, {
  int status = 200,
  Future<void>? credentialsReady,
}) async {
  final store = MemorySessionStore();
  await store.write(
    'https://example.invalid',
    Session(
      accessToken: 'fixture-only',
      refreshToken: 'fixture-only',
      cachedUser: {'id': 'alice', 'name': 'Alice'},
    ),
  );
  final adapter = _Adapter(me, status: status);
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: store,
    transport: Dio()..httpClientAdapter = adapter,
  );
  // The account record is available before /auth/me answers.
  expect(
    await client.restore(cachedFirst: true, credentialsReady: credentialsReady),
    isTrue,
  );
  expect(client.user?.id, 'alice');
  return (client, adapter, store);
}

void main() {
  test(
    'cached-first restore revalidates and survives a server switch',
    () async {
      final (client, adapter, store) = await _restore({
        'id': 'alice',
        'name': 'Alice Renamed',
      });
      final events = <String>[];
      client.events.listen((e) => events.add(e.name));
      client.selectServer('server-a');
      adapter.gate.complete();
      await client.sessionValidated;
      await Future<void>.delayed(Duration.zero);
      expect(client.user?.string('name'), 'Alice Renamed');
      expect(events, contains('account:updated'));
      expect(
        (await store.read('https://example.invalid'))?.cachedUser?['name'],
        'Alice Renamed',
      );
      await client.dispose();
    },
  );

  test('cached-first restore ends a rejected session', () async {
    final (client, adapter, store) = await _restore({
      'error': 'Expired',
    }, status: 401);
    final events = <String>[];
    client.events.listen((e) => events.add(e.name));
    adapter.gate.complete();
    await client.sessionValidated;
    await Future<void>.delayed(Duration.zero);
    expect(client.user, isNull);
    expect(events, contains('session:ended'));
    expect(await store.read('https://example.invalid'), isNull);
    await client.dispose();
  });

  test('cached-first restore stays offline on an unreachable server', () async {
    final (client, adapter, _) = await _restore({
      'error': 'Unavailable',
    }, status: 503);
    adapter.gate.complete();
    await client.sessionValidated;
    expect(client.user?.id, 'alice');
    expect(client.restoredOffline, isTrue);
    await client.dispose();
  });

  for (final status in [400, 404, 408, 429]) {
    test(
      'cached-first restore preserves credentials on HTTP $status',
      () async {
        final (client, adapter, store) = await _restore({
          'error': 'Validation temporarily unavailable',
        }, status: status);
        final before = await store.read(client.origin);
        final events = <String>[];
        client.events.listen((e) => events.add(e.name));
        adapter.gate.complete();
        await client.sessionValidated;
        await Future<void>.delayed(Duration.zero);
        expect(client.user?.id, 'alice');
        expect(client.signedIn, isTrue);
        expect(client.restoredOffline, isTrue);
        expect(await store.read(client.origin), same(before));
        expect(events, isNot(contains('session:ended')));
        expect(adapter.paths, isNot(contains('POST /auth/logout')));
        await client.dispose();
      },
    );
  }

  // The server never answers 403 on /auth/me (a retired account or revoked
  // session is `401 {"error":...}`), so a 403 is a proxy or WAF and says
  // nothing about the credentials: keep them (docs/architecture.md, "登出策略").
  test(
    'cached-first restore preserves credentials on forbidden validation',
    () async {
      final (client, adapter, store) = await _restore({
        'error': 'Forbidden',
      }, status: 403);
      final before = await store.read(client.origin);
      adapter.gate.complete();
      await client.sessionValidated;
      expect(client.user?.id, 'alice');
      expect(client.signedIn, isTrue);
      expect(client.restoredOffline, isTrue);
      expect(await store.read(client.origin), same(before));
      expect(adapter.paths, isNot(contains('POST /auth/logout')));
      await client.dispose();
    },
  );

  test(
    'requests and the cached account never wait for a guest to settle',
    () async {
      final guest = Completer<void>();
      final (client, adapter, store) = await _restore({
        'id': 'alice',
      }, credentialsReady: guest.future);
      final read = await client.get('/servers');
      expect(read, isNotNull);
      expect(client.user?.id, 'alice');
      expect(
        adapter.requests
            .singleWhere((r) => r.path == '/servers')
            .headers['Authorization'],
        'Bearer fixture-only',
      );
      // The guest rotated meanwhile; only after it stops does the client move
      // to the latest stored record.
      await store.write(
        client.origin,
        Session(
          accessToken: 'worker-rotated-fixture',
          refreshToken: 'worker-rotated-fixture',
          cachedUser: {'id': 'alice', 'name': 'Alice'},
        ),
      );
      guest.complete();
      adapter.gate.complete();
      await client.sessionValidated;
      await client.get('/channels');
      expect(
        adapter.requests
            .singleWhere((r) => r.path == '/channels')
            .headers['Authorization'],
        'Bearer worker-rotated-fixture',
      );
      await client.dispose();
    },
  );

  test(
    'refresh waits for the guest to settle and retries its persisted attempt',
    () async {
      final guest = Completer<void>();
      final (client, adapter, store) = await _restore({
        'id': 'alice',
      }, credentialsReady: guest.future);
      adapter.rotated = true;
      final refresh = client.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.paths.where((p) => p.contains('/auth/refresh')), isEmpty);
      await store.write(
        client.origin,
        Session(
          accessToken: 'worker-fixture',
          refreshToken: 'worker-fixture',
          installationId: 'ari_fixture',
          refreshAttemptId: 'arf_worker_fixture',
          cachedUser: {'id': 'alice'},
        ),
      );
      guest.complete();
      await refresh;
      final request = adapter.requests.singleWhere(
        (r) => r.path == '/auth/refresh',
      );
      expect(request.data['refreshToken'], 'worker-fixture');
      expect(
        request.headers['X-Slock-Auth-Refresh-Attempt-Id'],
        'arf_worker_fixture',
      );
      expect(request.headers['X-Slock-Auth-Installation-Id'], 'ari_fixture');
      adapter.gate.complete();
      await client.sessionValidated;
      expect(
        (await store.read(client.origin))?.refreshToken,
        'refreshed-fixture',
      );
      await client.dispose();
    },
  );

  test('refresh adopts credentials the guest already rotated', () async {
    final guest = Completer<void>();
    final (client, adapter, store) = await _restore({
      'id': 'alice',
    }, credentialsReady: guest.future);
    final refresh = client.refresh();
    await store.write(
      client.origin,
      Session(
        accessToken: 'worker-rotated-fixture',
        refreshToken: 'worker-rotated-fixture',
        cachedUser: {'id': 'alice'},
      ),
    );
    guest.complete();
    await refresh;
    expect(adapter.paths.where((p) => p.contains('/auth/refresh')), isEmpty);
    await client.get('/servers');
    expect(
      adapter.requests
          .singleWhere((r) => r.path == '/servers')
          .headers['Authorization'],
      'Bearer worker-rotated-fixture',
    );
    await client.dispose();
  });

  for (final replaced in [false, true]) {
    test(
      'guest handoff ${replaced ? 'to another account' : 'after revocation'} retires the cached identity',
      () async {
        final guest = Completer<void>();
        final (client, adapter, store) = await _restore({
          'id': 'alice',
        }, credentialsReady: guest.future);
        final ended = client.events.firstWhere(
          (e) => e.name == 'session:ended',
        );
        await store.write(
          client.origin,
          replaced
              ? Session(
                  accessToken: 'bob-fixture',
                  refreshToken: 'bob-fixture',
                  cachedUser: {'id': 'bob'},
                )
              : null,
        );
        guest.complete();
        await ended;
        expect(client.user, isNull);
        await client.get('/servers');
        expect(
          adapter.requests
              .singleWhere((r) => r.path == '/servers')
              .headers['Authorization'],
          isNull,
          reason: 'the retired identity\'s credentials are never sent again',
        );
        expect(
          (await store.read(client.origin))?.cachedUser?['id'],
          replaced ? 'bob' : null,
        );
        await client.dispose();
      },
    );
  }

  test('logout while a guest settles never restores the cached identity', () async {
    final guest = Completer<void>();
    final (client, adapter, store) = await _restore({
      'id': 'alice',
    }, credentialsReady: guest.future);
    final logout = client.logout();
    guest.complete();
    await logout;
    adapter.gate.complete();
    await client.sessionValidated;
    expect(adapter.paths, contains('POST /auth/logout'));
    expect(await store.read(client.origin), isNull);
    expect(client.user, isNull);
    await client.dispose();
  });

  test('a failed guest signal cannot poison the session', () async {
    final guest = Completer<void>();
    final (client, adapter, store) = await _restore({
      'id': 'alice',
    }, credentialsReady: guest.future);
    guest.completeError(const RaftApiException('Fixture guest unavailable'));
    adapter.rotated = true;
    await client.refresh();
    expect(
      (await store.read(client.origin))?.refreshToken,
      'refreshed-fixture',
    );
    expect(client.user?.id, 'alice');
    adapter.gate.complete();
    await client.sessionValidated;
    await client.dispose();
  });

  test(
    'logout retires requests immediately and revokes the final guest record',
    () async {
      final guest = Completer<void>(), revocation = Completer<Session?>();
      final (client, adapter, _) = await _restore({
        'id': 'alice',
      }, credentialsReady: guest.future);
      final logout = client.logout(revocationSession: revocation.future);
      expect(client.signedIn, false);
      expect(client.user, isNull);
      guest.complete();
      revocation.complete(
        Session(
          accessToken: 'worker-fixture',
          refreshToken: 'worker-fixture',
          cachedUser: {'id': 'alice'},
        ),
      );
      await logout;
      final out = adapter.requests.singleWhere((r) => r.path == '/auth/logout');
      expect(out.data['refreshToken'], 'worker-fixture');
      await client.dispose();
    },
  );

  test('socket connection starts at once without waiting for a guest', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<void>();
    final subscription = server.listen((request) async {
      if (!accepted.isCompleted) accepted.complete();
      request.response.statusCode = 503;
      await request.response.close();
    });
    final origin = 'http://127.0.0.1:${server.port}';
    final store = MemorySessionStore();
    await store.write(
      origin,
      Session(
        accessToken: 'fixture-only',
        refreshToken: 'fixture-only',
        cachedUser: {'id': 'alice'},
      ),
    );
    final adapter = _Adapter({'id': 'alice'});
    final client = RaftClient(
      origin: origin,
      sessionStore: store,
      transport: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
      await subscription.cancel();
    });
    final guest = Completer<void>();
    expect(
      await client.restore(cachedFirst: true, credentialsReady: guest.future),
      true,
    );
    client.selectServer('server-a');
    client.connect();
    await accepted.future.timeout(const Duration(seconds: 2));
    expect(guest.isCompleted, false);
    adapter.gate.complete();
    await client.sessionValidated;
    guest.complete();
  });
}
