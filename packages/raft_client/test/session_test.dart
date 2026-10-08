import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class FakeAdapter implements HttpClientAdapter {
  int rotates = 0;
  final bindings = <Map<String, dynamic>>[];
  bool offline = false, revoked = false;
  Completer<void>? gate, exitGate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    if (o.path == '/servers/server-a' && o.method == 'DELETE') {
      await exitGate?.future;
      return body({'ok': true});
    }
    if (o.path == '/auth/login')
      return body({
        'accessToken': 'old',
        'refreshToken': 'rotate-once',
        'user': {'id': 'test-user'},
      });
    if (o.path == '/auth/refresh') {
      rotates++;
      bindings.add(Map.from(o.headers));
      if (gate != null) await gate!.future;
      if (offline) return body({'error': 'Temporary outage'}, 503);
      if (revoked) return body({'error': 'Session revoked'}, 401);
      return body({'accessToken': 'new', 'refreshToken': 'rotated'});
    }
    if (o.path == '/auth/logout') return body({'ok': true});
    if (o.headers['Authorization'] == 'Bearer old')
      return body({'error': 'Expired'}, 401);
    return body({'ok': true});
  }

  ResponseBody body(dynamic value, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeAdapter adapter;
  late RaftClient client;
  setUp(() async {
    adapter = FakeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: dio,
    );
    await client.login('fixture', 'fixture');
  });
  tearDown(() async => client.dispose());
  test('concurrent 401s share one refresh rotation', () async {
    adapter.gate = Completer<void>();
    final a = client.get('/servers');
    final b = client.get('/channels');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    adapter.gate!.complete();
    expect(await a, {'ok': true});
    expect(await b, {'ok': true});
    expect(adapter.rotates, 1);
  });
  test('transient refresh failure preserves account', () async {
    adapter.offline = true;
    await expectLater(
      client.get('/servers'),
      throwsA(isA<RaftApiException>().having((e) => e.status, 'status', 503)),
    );
    expect(client.signedIn, true);
  });
  test('refresh replay binding survives a failed response and retry', () async {
    adapter.offline = true;
    await expectLater(client.refresh(), throwsA(isA<RaftApiException>()));
    adapter.offline = false;
    await client.refresh();
    final first = adapter.bindings.first, second = adapter.bindings.last;
    final attempt = first['X-Slock-Auth-Refresh-Attempt-Id'];
    final installation = first['X-Slock-Auth-Installation-Id'];
    expect(attempt, matches(RegExp(r'^arf_[0-9a-f]{16}$')));
    expect(installation, matches(RegExp(r'^ari_[0-9a-f]{32}$')));
    expect(second['X-Slock-Auth-Refresh-Attempt-Id'], attempt);
    expect(second['X-Slock-Auth-Installation-Id'], installation);
  });
  test('terminal refresh rejection clears account', () async {
    adapter.revoked = true;
    await expectLater(client.get('/servers'), throwsA(isA<RaftApiException>()));
    expect(client.signedIn, false);
    expect(client.user, isNull);
  });
  test('logout during rotation cannot resurrect the session', () async {
    adapter.gate = Completer<void>();
    final refresh = client.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await client.logout();
    adapter.gate!.complete();
    await refresh;
    expect(client.signedIn, false);
  });
  test(
    'server exit acknowledgement survives its own membership revocation',
    () async {
      client.selectServer('server-a');
      adapter.exitGate = Completer<void>();
      final exit = client.exitServer('server-a', delete: true);
      await Future<void>.delayed(Duration.zero);
      client.selectServer(null);
      adapter.exitGate!.complete();
      expect(await exit, {'ok': true});
    },
  );
  test('server exit never bypasses logout and new authentication, even for the same user', () async {
    client.selectServer('server-a');
    adapter.exitGate = Completer<void>();
    final exit = client.exitServer('server-a', delete: true);
    final rejected = expectLater(exit, throwsA(isA<RaftApiException>()));
    await Future<void>.delayed(Duration.zero);
    await client.logout();
    await client.login('fixture', 'fixture');
    adapter.exitGate!.complete();
    await rejected;
  });
}
