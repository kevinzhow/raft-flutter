import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';

class GetCacheWire implements HttpClientAdapter {
  final reads = <String, int>{};
  final versions = <String, int>{};
  final holds = <String, Completer<void>>{};
  final statuses = <String, int>{};
  final cacheControl = <String, String>{};
  final responses = <String, Object>{};
  Completer<void>? writeHold;
  String account = 'alice';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancellation,
  ) async {
    final server = options.headers['X-Server-Id'];
    final path = options.uri.path.substring('/api'.length);
    final version = versions[path] ?? 1;
    final status = statuses['${options.method} $path'] ?? 200;
    if (options.method == 'GET') {
      reads.update(
        '$server ${options.uri.path}',
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (holds[path] case final hold?) await hold.future;
    } else if (writeHold case final hold?) {
      await hold.future;
    }
    final body = switch (path) {
      '/auth/login' => {
        'accessToken': 'access-for-$account',
        'refreshToken': 'refresh-for-$account',
        'user': {'id': account},
      },
      _ =>
        responses[path] ??
            {
              'server': server,
              'version': version,
              'query': options.uri.query,
              'rows': ['original'],
            },
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (cacheControl[path] case final header?) 'cache-control': [header],
      },
    );
  }

  int requests(String path, [String server = 's1']) =>
      reads['$server /api$path'] ?? 0;

  @override
  void close({bool force = false}) {}
}

Future<RaftClient> openGetCacheClient(
  GetCacheWire wire,
  DateTime Function() now,
) async {
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = wire,
    governor: RateLimitGovernor(now: now),
  );
  await client.login('fixture', 'local-only');
  client.selectServer('s1');
  return client;
}
