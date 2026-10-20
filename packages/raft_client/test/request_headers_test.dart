import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Server implements HttpClientAdapter {
  final headers = <String, Map<String, dynamic>>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    headers['${o.method} ${o.path}'] = Map.of(o.headers);
    return ResponseBody.fromString(
      jsonEncode(
        o.path == '/auth/login'
            ? {
                'accessToken': 'fixture-only',
                'refreshToken': 'fixture-only',
                'user': {'id': 'alice'},
              }
            : {'ok': true},
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'runWithHeaders adds headers to the requests started inside it only',
    () async {
      final server = _Server();
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = server,
      );
      await client.login('a', 'b');
      client.selectServer('s1');
      await RaftClient.runWithHeaders({
        'Accept-Language': 'zh-CN',
      }, () => client.get('/inside'));
      await client.get('/outside');
      expect(server.headers['GET /inside']!['Accept-Language'], 'zh-CN');
      expect(
        server.headers['GET /outside']!.containsKey('Accept-Language'),
        false,
      );
      // Nested scopes add up; an explicit header of the request wins.
      await RaftClient.runWithHeaders({'X-A': '1'}, () async {
        await RaftClient.runWithHeaders({
          'X-B': '2',
        }, () => client.get('/nested'));
        await RaftClient.runWithHeaders(
          {'Accept-Language': 'en'},
          () => client.request(
            'GET',
            '/explicit',
            headers: {'Accept-Language': 'zh-CN'},
          ),
        );
      });
      expect(server.headers['GET /nested']!['X-A'], '1');
      expect(server.headers['GET /nested']!['X-B'], '2');
      expect(server.headers['GET /explicit']!['Accept-Language'], 'zh-CN');
      // The scope belongs to the zone, not to the client: nothing leaks.
      expect(RaftClient.currentRequestHeaders, isEmpty);
      await client.dispose();
    },
  );
}
