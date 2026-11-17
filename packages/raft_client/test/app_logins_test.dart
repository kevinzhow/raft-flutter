// Settings › Account › Apps you signed in to with Raft (Web
// features/settings/account/appLoginsApi.ts; server v1.24.0 routes/me.ts).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final (int, Object?) Function(RequestOptions) answer;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final (status, body) = answer(options);
    return ResponseBody.fromString(
      status == 204 ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(RaftClient, _Adapter)> _client(
  (int, Object?) Function(RequestOptions) answer,
) async {
  final store = MemorySessionStore();
  await store.write(
    'https://example.invalid',
    Session(accessToken: 'a', refreshToken: 'r'),
  );
  final adapter = _Adapter(answer);
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: store,
    transport: Dio()..httpClientAdapter = adapter,
  );
  addTearDown(client.dispose);
  return (client, adapter);
}

void main() {
  test('lists the Apps as GET /me/app-logins gives them', () async {
    final (client, adapter) = await _client(
      (_) => (
        200,
        [
          {
            'id': 'g1',
            'clientId': 'app_one',
            'name': 'Notes',
            'logoUrl': 'https://cdn.example.invalid/n.png',
            'scopes': ['openid', 'profile'],
            'grantedAt': '2026-11-01T08:00:00.000Z',
          },
          {
            'id': 'g2',
            'clientId': 'app_two',
            'name': 'Plain',
            'logoUrl': null,
            'scopes': [],
            'grantedAt': '2025-01-02T00:00:00.000Z',
          },
          // Not an App: nothing to show or revoke.
          {'name': 'No key'},
          'junk',
        ],
      ),
    );
    final logins = await client.listAppLogins();
    expect(adapter.calls.single.method, 'GET');
    expect(adapter.calls.single.path, '/me/app-logins');
    expect(logins.map((l) => l.clientId), ['app_one', 'app_two']);
    expect(logins.first.name, 'Notes');
    expect(logins.first.logoUrl, 'https://cdn.example.invalid/n.png');
    expect(logins.first.scopes, ['openid', 'profile']);
    expect(logins.first.grantedAt!.toUtc(), DateTime.utc(2026, 11, 1, 8));
    expect(logins.last.logoUrl, isNull);
  });

  test('an answer that is not an array is no Apps; a failure throws', () async {
    final (odd, _) = await _client((_) => (200, {'logins': []}));
    expect(await odd.listAppLogins(), isEmpty);
    final (failing, _) = await _client((_) => (500, {'error': 'nope'}));
    await expectLater(
      failing.listAppLogins(),
      throwsA(isA<RaftApiException>()),
    );
  });

  test('revoke sends DELETE with the client key escaped', () async {
    final (client, adapter) = await _client((_) => (204, null));
    await client.revokeAppLogin('app one/2');
    final call = adapter.calls.single;
    expect(call.method, 'DELETE');
    expect(Uri.decodeFull(call.path), '/me/app-logins/app one/2');
    expect(call.path, '/me/app-logins/app%20one%2F2');
  });
}
