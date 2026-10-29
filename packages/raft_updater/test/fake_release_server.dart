import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// GitHub's release download behaviour in miniature: `releases/download/<tag>/<name>`
/// answers 302 to a short-lived `/objects/<token>/<name>` that serves the bytes
/// with `Range` support.
class FakeReleaseServer {
  FakeReleaseServer._(this._server)
    : origin = Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<FakeReleaseServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeReleaseServer._(server);
    server.listen(fake._handle);
    return fake;
  }

  final HttpServer _server;
  final Map<String, Uint8List> files = {};

  /// Every request as `METHOD path range`.
  final List<String> requests = [];

  /// Serve whole bodies and ignore `Range`.
  bool ignoreRange = false;

  /// Answer this many object requests with 403 first (an expired CDN link).
  int expireLinks = 0;

  /// The same, but only for ranged requests.
  int expireRangeLinks = 0;

  /// Cut the first ranged response after this many bytes (once).
  int? dropRangeAfter;

  int served = 0;

  final Uri origin;
  Future<void> close() => _server.close(force: true);

  int get rangeBytes => _rangeBytes;
  int _rangeBytes = 0;

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    requests.add(
      '${request.method} ${Uri.decodeFull(path)} ${range ?? ''}'.trim(),
    );
    final response = request.response;
    final release = RegExp(r'^/[^/]+/[^/]+/releases/download/[^/]+/(.+)$')
        .firstMatch(path);
    if (release != null) {
      final name = Uri.decodeComponent(release[1]!);
      if (!files.containsKey(name)) {
        response.statusCode = 404;
      } else {
        response.statusCode = 302;
        response.headers.set(
          HttpHeaders.locationHeader,
          '/objects/${++served}/${Uri.encodeComponent(name)}',
        );
      }
      await response.close();
      return;
    }
    final object = RegExp(r'^/objects/\d+/(.+)$').firstMatch(path);
    final name = object == null ? null : Uri.decodeComponent(object[1]!);
    if (name == null || !files.containsKey(name)) {
      response.statusCode = 404;
      await response.close();
      return;
    }
    if (expireLinks > 0) {
      expireLinks--;
      response.statusCode = 403;
      await response.close();
      return;
    }
    if (expireRangeLinks > 0 && range != null) {
      expireRangeLinks--;
      response.statusCode = 403;
      await response.close();
      return;
    }
    final data = files[name]!;
    var start = 0, end = data.length - 1;
    var status = 200;
    final match = range == null
        ? null
        : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
    if (match != null && !ignoreRange) {
      start = int.parse(match[1]!);
      end = match[2]!.isEmpty ? end : int.parse(match[2]!);
      end = end >= data.length ? data.length - 1 : end;
      status = 206;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${data.length}',
      );
    }
    var body = data.sublist(start, end + 1);
    response.statusCode = status;
    response.headers.contentLength = body.length;
    final cut = status == 206 ? dropRangeAfter : null;
    if (cut != null && cut < body.length) {
      dropRangeAfter = null;
      // Promise the whole range, deliver part of it, then drop the connection.
      response.add(body.sublist(0, cut));
      _rangeBytes += cut;
      try {
        await response.close();
      } on HttpException {
        // The server aborts the connection: that is the point.
      }
      return;
    }
    if (status == 206) _rangeBytes += body.length;
    response.add(body);
    await response.close();
  }

  static Uint8List text(String value) => Uint8List.fromList(utf8.encode(value));
}
