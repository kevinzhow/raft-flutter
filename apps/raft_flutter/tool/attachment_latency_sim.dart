// Models the attachment-open critical path against local fake servers whose
// latency is injected, so the effect of connection reuse, URL caching and
// prefetch can be compared before/after without a production network.
//
//   dart run tool/attachment_latency_sim.dart [--rtt=100] [--runs=5]
//
// Measured: this process's real HTTP client behaviour (dio, HttpClient, TLS
// handshake CPU, pool reuse, the real AttachmentUrlCache and AttachmentHttp).
// Injected (an assumption, not a measurement): network round trips.
//   request latency        = rtt + server processing (40 ms API, 30 ms storage)
//   new storage connection = 3 * rtt (DNS + TCP + TLS 1.3) before the handshake
// Nothing here talks to a real server or reads credentials.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:raft_flutter/data/attachment_url_cache.dart';
import 'package:raft_flutter/platform/attachment_http.dart';

late int rtt;

Future<void> delay(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

/// Accepts, waits [connectMs], then pipes to [port]. Counts connections.
class DelayedFront {
  DelayedFront(this.server, this.connectMs, this.upstream);
  final ServerSocket server;
  final int connectMs, upstream;
  int accepted = 0;
  static Future<DelayedFront> start(int connectMs, int upstream) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final front = DelayedFront(server, connectMs, upstream);
    server.listen((client) async {
      front.accepted++;
      client.setOption(SocketOption.tcpNoDelay, true);
      final buffered = <List<int>>[];
      Socket? up;
      final sub = client.listen(buffered.add, onDone: () => up?.destroy());
      await delay(connectMs);
      up = await Socket.connect(InternetAddress.loopbackIPv4, upstream);
      up.setOption(SocketOption.tcpNoDelay, true);
      sub.pause();
      for (final b in buffered) {
        up.add(b);
      }
      sub.onData(up.add);
      sub.onDone(() => up!.destroy());
      sub.resume();
      up.listen(client.add, onDone: () => client.destroy(), onError: (_) {});
    });
    return front;
  }

  int get port => server.port;
}

final payload = List<int>.filled(200 * 1024, 7);

Future<(HttpServer, String)> storage() async {
  final dir = Directory.systemTemp.createTempSync('latency-sim-');
  final key = '${dir.path}/k.pem', cert = '${dir.path}/c.pem';
  Process.runSync('openssl', [
    'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out',
    cert, '-subj', '/CN=localhost', '-days', '1',
  ]);
  final context = SecurityContext()
    ..useCertificateChain(cert)
    ..usePrivateKey(key);
  final server = await HttpServer.bindSecure(
    InternetAddress.loopbackIPv4,
    0,
    context,
  );
  server.listen((request) async {
    await delay(rtt + 30);
    request.response
      ..statusCode = 200
      ..add(payload);
    await request.response.close();
  });
  return (server, dir.path);
}

Future<HttpServer> api(int storagePort) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await delay(rtt + 40);
    final path = request.uri.path;
    final signed = 'https://localhost:$storagePort/object/';
    request.response.headers.contentType = ContentType.json;
    if (request.method == 'POST') {
      final ids = (await request.cast<List<int>>().expand((b) => b).length);
      request.response.write(
        '{"urls":[${[for (final id in _batchIds) '{"id":"$id","url":"$signed$id?sig=x"}'].join(',')}]}',
      );
      ids;
    } else {
      final id = path.split('/')[2];
      request.response.write('{"url":"$signed$id?sig=x","expiresAt":null}');
    }
    await request.response.close();
  });
  return server;
}

List<String> _batchIds = const [];

class Result {
  Result(this.first, this.second);
  final int first, second;
}

Dio apiDio(int port) => Dio(BaseOptions(baseUrl: 'http://localhost:$port'));

Future<int> firstByte(Dio dio, String url) async {
  final sw = Stopwatch()..start();
  final r = await dio.get<ResponseBody>(
    url,
    options: Options(responseType: ResponseType.stream),
  );
  var t = -1;
  await for (final _ in r.data!.stream) {
    if (t < 0) t = sw.elapsedMilliseconds;
  }
  return t;
}

void allowCert(HttpClient c) => c.badCertificateCallback = (_, _, _) => true;

Dio oldStorageDio() {
  final d = Dio();
  d.httpClientAdapter = _Adapter();
  return d;
}

class _Adapter extends HttpClientAdapterShim {}

class HttpClientAdapterShim implements HttpClientAdapter {
  final inner = AttachmentHttp.create(configure: allowCert).httpClientAdapter;
  @override
  Future<ResponseBody> fetch(o, s, c) => inner.fetch(o, s, c);
  @override
  void close({bool force = false}) => inner.close(force: force);
}

Future<void> main(List<String> args) async {
  rtt = int.parse(
    args.firstWhere((a) => a.startsWith('--rtt='), orElse: () => '--rtt=100').substring(6),
  );
  final runs = int.parse(
    args.firstWhere((a) => a.startsWith('--runs='), orElse: () => '--runs=5').substring(7),
  );
  final (store, tmp) = await storage();
  final front = await DelayedFront.start(rtt * 3, store.port);
  final apiServer = await api(front.port);
  final ids = ['a1', 'b2', 'c3', 'd4'];
  _batchIds = ids;
  final base = apiServer.port;
  print('rtt=${rtt}ms  request=rtt+40/30ms  new storage connection=${rtt * 3}ms (assumed)');
  final names = ['before (Dio per card, /url per open)', 'shared Dio only', 'shared Dio + URL cache (signs on open only, no prefetch)'];
  final firsts = List.generate(3, (_) => <int>[]);
  final seconds = List.generate(3, (_) => <int>[]);
  for (var run = 0; run < runs; run++) {
    // 0: before. The API client is warm (the channel just loaded).
    {
      final client = apiDio(base);
      await client.get<dynamic>('/warm/up');
      Future<int> open(String id) async {
        final sw = Stopwatch()..start();
        final body = (await client.get<Map>('/attachments/$id/url')).data!;
        final dio = oldStorageDio(); // AttachmentFiles() inside AttachmentView
        await firstByte(dio, body['url'] as String);
        return sw.elapsedMilliseconds;
      }
      firsts[0].add(await open('a1'));
      seconds[0].add(await open('b2'));
    }
    // 1: shared Dio, still one /url per open.
    {
      final shared = AttachmentHttp.create(configure: allowCert);
      final client = apiDio(base);
      await client.get<dynamic>('/warm/up');
      Future<int> open(String id) async {
        final sw = Stopwatch()..start();
        final body = (await client.get<Map>('/attachments/$id/url')).data!;
        await firstByte(shared, body['url'] as String);
        return sw.elapsedMilliseconds;
      }
      firsts[1].add(await open('a1'));
      seconds[1].add(await open('b2'));
      shared.close();
    }
    // 2: shared Dio + URL cache. Nothing is signed ahead of the click.
    {
      final shared = AttachmentHttp.create(configure: allowCert);
      final client = apiDio(base);
      await client.get<dynamic>('/warm/up');
      final cache = AttachmentUrlCache();
      Future<int> open(String id) async {
        final sw = Stopwatch()..start();
        final url = await cache.resolve(
          id,
          scope: 's',
          fetch: () async => (await client.get<Map>('/attachments/$id/url')).data,
        );
        await firstByte(shared, url);
        return sw.elapsedMilliseconds;
      }
      firsts[2].add(await open('a1'));
      seconds[2].add(await open('b2'));
      shared.close();
      cache.dispose();
    }
  }
  num avg(List<int> v) => v.reduce((a, b) => a + b) / v.length;
  for (var i = 0; i < 3; i++) {
    print('${names[i]}\n   first open ${avg(firsts[i]).round()} ms   second open ${avg(seconds[i]).round()} ms   (runs: ${firsts[i].join(",")} / ${seconds[i].join(",")})');
  }
  print('storage connections accepted (all runs): ${front.accepted}');
  await store.close(force: true);
  await apiServer.close(force: true);
  await front.server.close();
  Directory(tmp).deleteSync(recursive: true);
}
