// A storage host that counts what it really sent, for the video cache tests.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// A storage host that counts what it really sent. Serves deterministic bytes
/// (`byteAt`) so a body can be checked without keeping a copy.
class FakeUpstream {
  FakeUpstream();

  late HttpServer server;
  final sizes = <String, int>{};
  final requests = <({String path, String? range, int status, int before})>[];
  int bytesSent = 0;

  /// The User-Agent of every request, in order.
  final userAgents = <String?>[];

  /// Per-path behaviour.
  final ignoreRange = <String>{};
  final unsized = <String>{};
  final failing = <String, int>{};

  /// Paths that fail only for requests starting at or after this byte.
  final failFrom = <String, int>{};
  final etags = <String, String>{};
  Duration pause = Duration.zero;

  /// Cut the connection after this many body bytes (per path).
  final cutAfter = <String, int>{};

  /// The same, for the next request of the path only.
  final cutOnceAfter = <String, int>{};

  /// With [failing]: fail this many requests of the path, then answer.
  final failCount = <String, int>{};

  /// Bytes per write of a body (and so the grain of [cutAfter] and [pause]).
  int blockSize = 16 * 1024;

  static int byteAt(int i) => (i * 31 + 7) & 0xff;
  static Uint8List bytes(int from, int to) =>
      Uint8List.fromList([for (var i = from; i <= to; i++) byteAt(i)]);

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');
  Future<void> stop() => server.close(force: true);

  int requestsFor(String path) => requests.where((r) => r.path == path).length;

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    userAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
    final size = sizes[path];
    final range = request.headers.value(HttpHeaders.rangeHeader);
    var start = 0, end = (size ?? 1) - 1, status = 200;
    if (size == null) {
      requests.add((path: path, range: range, status: 404, before: bytesSent));
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    if (size == 0 && range != null) {
      requests.add((path: path, range: range, status: 416, before: bytesSent));
      request.response
        ..statusCode = 416
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */0')
        ..contentLength = 0;
      await request.response.close();
      return;
    }
    if (range != null && !ignoreRange.contains(path)) {
      final m = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range)!;
      if (m[1]!.isNotEmpty) start = int.parse(m[1]!);
      if (m[2]!.isNotEmpty) end = int.parse(m[2]!).clamp(0, size - 1);
      if (m[1]!.isEmpty) {
        start = size - int.parse(m[2]!);
        end = size - 1;
      }
      status = 206;
    }
    final failStatus = failing[path];
    final failuresLeft = failCount[path];
    if (failStatus != null &&
        start >= (failFrom[path] ?? 0) &&
        (failuresLeft == null || failuresLeft > 0)) {
      if (failuresLeft != null) failCount[path] = failuresLeft - 1;
      requests.add((
        path: path,
        range: range,
        status: failStatus,
        before: bytesSent,
      ));
      request.response.statusCode = failStatus;
      await request.response.close();
      return;
    }
    requests.add((path: path, range: range, status: status, before: bytesSent));
    final response = request.response..statusCode = status;
    response.headers
      ..set(HttpHeaders.contentTypeHeader, 'video/mp4')
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    final etag = etags[path];
    if (etag != null) response.headers.set(HttpHeaders.etagHeader, etag);
    if (status == 206) {
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$size',
      );
    }
    if (!unsized.contains(path)) {
      response.contentLength = end - start + 1;
    } else {
      response.headers.chunkedTransferEncoding = true;
    }
    if (request.method == 'HEAD') {
      await response.close();
      return;
    }
    final cut = cutAfter[path] ?? cutOnceAfter.remove(path);
    // A body that is cut stops short of its declared length: closing then
    // makes dart:io drop the connection, which is what a network failure
    // looks like. (dart:io holds back writes under 8 KiB, so bodies that are
    // cut use larger blocks; the pause lets what was written reach the
    // client.)
    final stop = cut == null || start + cut - 1 >= end ? end : start + cut - 1;
    try {
      for (var at = start; at <= stop; at += blockSize) {
        final to = at + blockSize - 1 > stop ? stop : at + blockSize - 1;
        response.add(bytes(at, to));
        bytesSent += to - at + 1;
        await response.flush();
        if (pause > Duration.zero) await Future<void>.delayed(pause);
      }
      if (stop < end) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      await response.close();
    } on Object {
      // The proxy hung up.
    }
  }
}

class Answer {
  Answer(this.status, this.headers, this.body, {this.error});
  final int status;
  final HttpHeaders? headers;
  final Uint8List body;
  final Object? error;
  String? header(String name) => headers?.value(name);
}

Future<Answer> fetch(
  Uri url, {
  String? range,
  String method = 'GET',
  int? stopAfter,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, url);
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
    final out = BytesBuilder(copy: false);
    try {
      await for (final data in response) {
        out.add(data);
        if (stopAfter != null && out.length >= stopAfter) break;
      }
    } on Object catch (error) {
      return Answer(
        response.statusCode,
        response.headers,
        out.takeBytes(),
        error: error,
      );
    }
    return Answer(response.statusCode, response.headers, out.takeBytes());
  } finally {
    client.close(force: true);
  }
}
