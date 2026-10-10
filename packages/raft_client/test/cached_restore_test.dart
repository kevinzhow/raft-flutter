import 'dart:async';
import 'dart:convert';
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
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    paths.add('${o.method} ${o.path}');
    if (o.path == '/auth/me') await gate.future;
    final (body, code) = switch (o.path) {
      '/auth/me' => (me, status),
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
  expect(await client.restore(cachedFirst: true), isTrue);
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
}
