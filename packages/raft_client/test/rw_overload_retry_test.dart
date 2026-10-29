import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

/// Answers each path from a script of (status, body, headers).
class _Server implements HttpClientAdapter {
  final scripts =
      <String, List<(int, Map<String, dynamic>, Map<String, String>)>>{};
  final seen = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    seen.add('${o.method} ${o.path}');
    if (o.path == '/auth/login') {
      return _json(200, {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      }, const {});
    }
    final script = scripts[o.path];
    final (status, body, headers) = script == null || script.isEmpty
        ? (200, <String, dynamic>{'ok': true}, const <String, String>{})
        : script.removeAt(0);
    return _json(status, body, headers);
  }

  ResponseBody _json(
    int status,
    Map<String, dynamic> body,
    Map<String, String> headers,
  ) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      for (final e in headers.entries) e.key: [e.value],
    },
  );

  @override
  void close({bool force = false}) {}
}

const _overloaded = (
  503,
  <String, dynamic>{
    'error': 'Temporarily overloaded, retry shortly',
    'code': 'rw_overloaded',
    'retryable': true,
  },
  <String, String>{'retry-after': '2'},
);

Future<(RaftClient, _Server, List<Duration>)> _signedIn() async {
  final server = _Server();
  final slept = <Duration>[];
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = server,
    sleep: (d) async => slept.add(d),
  );
  await client.login('a', 'b');
  client.selectServer('s1');
  return (client, server, slept);
}

void main() {
  group('RisingWave overload (Web getWithRwOverloadRetry)', () {
    for (final path in [
      '/channels/unread',
      '/channels/inbox',
      '/servers/unread-summary',
    ]) {
      test(
        '[BP-READ-077] GET $path waits Retry-After and retries once',
        () async {
          final (client, server, slept) = await _signedIn();
          server.scripts[path] = [
            _overloaded,
            (200, {'ok': true}, const {}),
          ];
          final body = await client.get(path);
          expect(body['ok'], true);
          expect(server.seen.where((s) => s == 'GET $path'), hasLength(2));
          expect(slept, [const Duration(seconds: 2)]);
          await client.dispose();
        },
      );
    }

    test(
      '[BP-READ-077] a second overload is surfaced, never a third request',
      () async {
        final (client, server, slept) = await _signedIn();
        server.scripts['/channels/unread'] = [
          _overloaded,
          _overloaded,
          _overloaded,
        ];
        await expectLater(
          client.get('/channels/unread', query: {'summary': 1}),
          throwsA(
            isA<RaftApiException>().having((e) => e.status, 'status', 503),
          ),
        );
        expect(
          server.seen.where((s) => s == 'GET /channels/unread'),
          hasLength(2),
        );
        expect(slept, hasLength(1));
        await client.dispose();
      },
    );

    test(
      '[BP-READ-077] Retry-After is capped at 10 s and defaults to 2 s',
      () async {
        final (client, server, slept) = await _signedIn();
        server.scripts['/channels/inbox'] = [
          (503, _overloaded.$2, const {'retry-after': '90'}),
          (200, {'ok': true}, const {}),
        ];
        await client.get('/channels/inbox');
        server.scripts['/servers/unread-summary'] = [
          (503, _overloaded.$2, const {}),
          (200, {'ok': true}, const {}),
        ];
        await client.get('/servers/unread-summary');
        expect(slept, [
          const Duration(seconds: 10),
          const Duration(seconds: 2),
        ]);
        await client.dispose();
      },
    );

    test('[BP-READ-077] not retryable, other codes and other paths are not retried', () async {
      final (client, server, slept) = await _signedIn();
      server.scripts['/channels/unread'] = [
        (
          503,
          {
            'error': 'RisingWave is not configured',
            'code': 'rw_unconfigured',
            'retryable': false,
          },
          const {},
        ),
      ];
      await expectLater(
        client.get('/channels/unread'),
        throwsA(isA<RaftApiException>()),
      );
      server.scripts['/channels/unread'] = [
        (
          502,
          {'error': 'Read failed', 'code': 'rw_read_failed', 'retryable': true},
          const {},
        ),
      ];
      await expectLater(
        client.get('/channels/unread'),
        throwsA(isA<RaftApiException>()),
      );
      server.scripts['/channels/c1'] = [_overloaded];
      await expectLater(
        client.get('/channels/c1'),
        throwsA(isA<RaftApiException>()),
      );
      expect(
        server.seen.where((s) => s == 'GET /channels/unread'),
        hasLength(2),
      );
      expect(server.seen.where((s) => s == 'GET /channels/c1'), hasLength(1));
      expect(slept, isEmpty);
      await client.dispose();
    });
  });
}
