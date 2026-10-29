// Measures the phases between "tap an attachment" and "first byte": the
// signed-URL request on the Raft API and the storage GET. Reads the ignored
// local fixture file (path in RAFT_FIXTURE, default .local/test-user.json),
// logs in in-process, and prints only timings, hosts' kind (local/remote),
// byte counts and the signed-URL lifetime. It never prints a token, a signed
// URL, or fixture credentials.
//
//   RAFT_FIXTURE=/path/test-user.json dart run tool/attachment_latency_probe.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';

final _clock = Stopwatch()..start();
int _ms() => _clock.elapsedMicroseconds;
String _fmt(int us) => '${(us / 1000).toStringAsFixed(1)}ms';

Dio _dio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ),
);

/// (headers, firstChunk, total, bytes)
Future<(int, int, int, int)> _get(Dio dio, String url) async {
  final start = _ms();
  final response = await dio.get<ResponseBody>(
    url,
    options: Options(responseType: ResponseType.stream),
  );
  final headers = _ms() - start;
  var first = -1, bytes = 0;
  await for (final chunk in response.data!.stream) {
    if (first < 0) first = _ms() - start;
    bytes += chunk.length;
  }
  return (headers, first, _ms() - start, bytes);
}

Future<void> main() async {
  final path = Platform.environment['RAFT_FIXTURE'] ?? '.local/test-user.json';
  final fixture = jsonDecode(File(path).readAsStringSync());
  final client = RaftClient(
    origin: fixture['origin'],
    sessionStore: MemorySessionStore(),
  );
  try {
    var t = _ms();
    await client.login(fixture['email'], fixture['password']);
    print('login (cold API connection + auth)   ${_fmt(_ms() - t)}');
    final servers = await client.servers();
    client.selectServer(servers.first.id);
    final channels = (await client.channels()).where((c) => c.joined);
    final images = <Map<String, dynamic>>[];
    for (final channel in channels) {
      final page = await client.messagePage(channel.id);
      for (final message in (page['messages'] as List)) {
        for (final a in (message['attachments'] as List? ?? const [])) {
          // Images preferred; any attachment shares the same /url + storage path.
          if (a is Map && !'${a['mimeType']}'.startsWith('text/html')) {
            images.add(Map<String, dynamic>.from(a));
          }
        }
      }
      if (images.length >= 8) break;
    }
    print('attachments found: ${images.length}');
    if (images.length < 2) return;
    final urlTimes = <int>[];
    final urls = <String>[];
    Map? last;
    for (final a in images.take(6)) {
      t = _ms();
      final value = await client.get(
        '/attachments/${a['id']}/url',
        query: {'disposition': 'inline'},
      );
      urlTimes.add(_ms() - t);
      urls.add(value['url'] as String);
      last = value;
    }
    print(
      'API /url first=${_fmt(urlTimes.first)} '
      'subsequent=${urlTimes.skip(1).map(_fmt).join(',')}',
    );
    final uri = Uri.parse(urls.first);
    final expires = uri.queryParameters.entries
        .where((e) => e.key.toLowerCase() == 'x-amz-expires')
        .map((e) => e.value)
        .firstOrNull;
    print('signed URL query keys: ${uri.queryParameters.keys.toList()} port=${uri.port} path-depth=${uri.pathSegments.length}');
    print(
      'signed URL: scheme=${uri.scheme} local=${uri.host == 'localhost' || uri.host == '127.0.0.1'} '
      'X-Amz-Expires=$expires s; response expiresAt=${last?['expiresAt'] == null ? 'null' : 'present'}',
    );
    // Cold: a brand new Dio (own HttpClient) per attachment, as today.
    final cold = <(int, int, int, int)>[];
    for (final url in urls.take(4)) {
      cold.add(await _get(_dio(), url));
    }
    // Warm: one Dio, sequential, keep-alive reuse.
    final shared = _dio();
    final warm = <(int, int, int, int)>[];
    for (final url in urls.skip(0).take(4)) {
      warm.add(await _get(shared, url));
    }
    String row((int, int, int, int) r) =>
        'ttfb=${_fmt(r.$1)} firstByte=${_fmt(r.$2)} total=${_fmt(r.$3)} bytes=${r.$4}';
    for (var i = 0; i < cold.length; i++) {
      print('storage GET new-Dio[$i]    ${row(cold[i])}');
    }
    for (var i = 0; i < warm.length; i++) {
      print('storage GET shared-Dio[$i] ${row(warm[i])}');
    }
    // Raw connection setup against the storage host.
    final tcp = _ms();
    final socket = await Socket.connect(uri.host, uri.port);
    print('storage TCP connect ${_fmt(_ms() - tcp)}');
    socket.destroy();
  } finally {
    await client.dispose();
  }
}
