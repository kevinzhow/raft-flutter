// Server v1.24.0 client contract (WP-WIRE): the per-deploy client config, the
// rate-limit mirror, the error `code` and a 401 that is about a password, not
// the session (Web api/client.ts).
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

Future<(RaftClient, _Adapter)> _client(
  (int, Object?) Function(RequestOptions) answer, {
  bool signedIn = true,
}) async {
  final store = MemorySessionStore();
  if (signedIn) {
    await store.write(
      'https://example.invalid',
      Session(accessToken: 'a', refreshToken: 'r'),
    );
  }
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
  group('GET /public/client-config', () {
    test('is read without credentials or a server, and checked', () async {
      final (client, adapter) = await _client(
        (_) => (
          200,
          {
            'appHosts': ['app.raft.build', 'localhost', 'Bad.Host', 'x:1'],
            'privacyMode': true,
            'artifactsEmbedOrigin': 'https://embed.example.invalid/',
          },
        ),
      );
      client.selectServer('s1');
      final config = await client.clientConfig();
      expect(config.appHosts, ['app.raft.build', 'localhost']);
      expect(config.privacyMode, isTrue);
      expect(config.artifactsEmbedOrigin, 'https://embed.example.invalid');
      final call = adapter.calls.single;
      expect(call.path, '/public/client-config');
      expect(call.headers.containsKey('Authorization'), isFalse);
      expect(call.headers.containsKey('X-Server-Id'), isFalse);
    });

    test('an older server (404) or an odd answer is the fallback', () async {
      final (old, _) = await _client((_) => (404, {'error': 'Not found'}));
      final missing = await old.clientConfig();
      expect(missing.appHosts, isNull);
      expect(missing.privacyMode, isFalse);
      expect(missing.artifactsEmbedOrigin, isNull);
      final (odd, _) = await _client(
        (_) => (
          200,
          {
            'appHosts': 'app.raft.build',
            'privacyMode': 'yes',
            'artifactsEmbedOrigin': 'http://embed.example.invalid',
          },
        ),
      );
      final value = await odd.clientConfig();
      expect(value.appHosts, isNull);
      expect(value.privacyMode, isFalse);
      // http only on localhost / *.localhost.
      expect(value.artifactsEmbedOrigin, isNull);
    });

    test('embed origins: only an origin, as URL.origin spells it', () {
      expect(raftEmbedOriginOf('https://a.example'), 'https://a.example');
      expect(
        raftEmbedOriginOf('http://x.localhost:8787'),
        'http://x.localhost:8787',
      );
      expect(raftEmbedOriginOf('https://a.example/path'), isNull);
      expect(raftEmbedOriginOf('https://u:p@a.example'), isNull);
      expect(raftEmbedOriginOf('https://a.example?x=1'), isNull);
      expect(raftEmbedOriginOf('ftp://a.example'), isNull);
      expect(raftEmbedOriginOf(''), isNull);
    });
  });

  group('v1.24 rate limits (server app.ts)', () {
    List<String> ids(String method, String path) => [
      for (final l in ServerRateLimits.forRequest(method, path)) l.id,
    ];

    test('the message budget is 120 a minute and covers task writes and a '
        'thread with its first reply', () {
      expect(ServerRateLimits.messages.max, 120);
      expect(ids('POST', '/tasks/channel/c1'), ['messages']);
      expect(ids('PATCH', '/tasks/t1'), ['messages']);
      expect(ids('GET', '/tasks/server'), isEmpty);
      expect(ids('POST', '/channels/c1/threads'), ['messages']);
      expect(ids('GET', '/channels/c1/threads'), isEmpty);
      expect(ids('POST', '/messages'), ['messages']);
    });

    test('seat previews have their own 30 a minute', () {
      expect(ids('POST', '/billing/seat-pack-quantity/preview'), [
        'billing-preview',
      ]);
      expect(ids('POST', '/billing/pack-quantity/preview'), [
        'billing-preview',
      ]);
      expect(ServerRateLimits.billingPreview.max, 30);
      expect(ids('POST', '/billing/seat-pack-quantity'), ['billing']);
      expect(ids('GET', '/billing/subscription'), isEmpty);
    });

    test('invite flow, search and retired routes', () {
      expect(ids('GET', '/auth/invite-info'), ['invite-flow']);
      expect(ids('POST', '/auth/accept-invite'), ['invite-flow']);
      expect(ids('POST', '/auth/login'), ['auth']);
      expect(ids('POST', '/auth/forgot-password'), ['forgot-password', 'auth']);
      expect(ids('GET', '/search'), ['search']);
      expect(ids('POST', '/me/account/deletion'), ['auth']);
      // Gone in v1.24: notification enrollment and the share-artifact limiter.
      expect(ids('POST', '/notifications/enrollment-grants'), isEmpty);
      expect(ids('POST', '/share-artifacts/message-selection'), isEmpty);
      expect(ServerRateLimits.byId('notification-enrollment'), isNull);
    });
  });

  test('the server error code is read from the body', () async {
    final (client, _) = await _client(
      (_) => (409, {'error': 'Taken', 'code': 'managed_mcp_app_name_taken'}),
    );
    try {
      await client.post('/mcp/servers', data: {'name': 'x'});
      fail('expected a refusal');
    } on RaftApiException catch (e) {
      expect(e.details['code'], 'managed_mcp_app_name_taken');
      expect((e as dynamic).code, 'managed_mcp_app_name_taken');
      expect(e.status, 409);
    }
  });

  test('a 401 for a wrong password is not refreshed or resent', () async {
    final (client, adapter) = await _client((o) {
      if (o.path == '/auth/me') return (200, {'id': 'u1'});
      if (o.path == '/auth/refresh') {
        return (200, {'accessToken': 'a2', 'refreshToken': 'r2'});
      }
      return (
        401,
        {'error': 'Password is incorrect', 'code': 'password_incorrect'},
      );
    });
    await client.restore();
    adapter.calls.clear();
    await expectLater(
      client.post('/me/account/deletion', data: {'password': 'wrong'}),
      throwsA(isA<RaftApiException>().having((e) => e.status, 'status', 401)),
    );
    expect([for (final c in adapter.calls) c.path], ['/me/account/deletion']);
  });
}
