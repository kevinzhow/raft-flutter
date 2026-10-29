import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'appimage_failure.dart';

/// Opens an HTTP client for [url] (the app passes its proxy-aware one, which
/// is why the package never constructs a client itself).
typedef AppImageHttpClientFactory = Future<HttpClient> Function(Uri url);

/// The little HTTP the delta update needs: whole small bodies and byte
/// ranges, following GitHub's redirect from the release asset URL to its
/// short-lived CDN URL by hand so a `Range` header survives every hop.
class AppImageHttp {
  AppImageHttp(this._factory, {this.idleTimeout = const Duration(seconds: 30)});

  final AppImageHttpClientFactory _factory;
  final Duration idleTimeout;
  HttpClient? _client;
  final Map<Uri, Uri> _resolved = {};

  /// Response body bytes received so far (whole bodies and ranges).
  int bytesReceived = 0;

  /// Requests that carried a `Range` header.
  int rangeRequests = 0;

  Future<HttpClient> _clientFor(Uri url) async {
    final existing = _client;
    if (existing != null) return existing;
    final client = await _factory(url);
    client.connectionTimeout = const Duration(seconds: 15);
    return _client = client;
  }

  void close() {
    _client?.close(force: true);
    _client = null;
  }

  Future<HttpClientResponse> _open(Uri url, {String? range}) async {
    var current = _resolved[url] ?? url;
    for (var hop = 0; hop < 8; hop++) {
      final client = await _clientFor(current);
      final request = await client.getUrl(current);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
      final response = await request.close();
      if (response.isRedirect ||
          const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null) {
          throw AppImageUpdateFailure(
            AppImageUpdateFailureKind.http,
            '${response.statusCode}',
          );
        }
        current = current.resolve(location);
        continue;
      }
      if (current != url) _resolved[url] = current;
      return response;
    }
    throw const AppImageUpdateFailure(
      AppImageUpdateFailureKind.http,
      'redirects',
    );
  }

  AppImageUpdateFailure _failure(Object error, Uri url) {
    if (error is AppImageUpdateFailure) return error;
    if (error is SocketException ||
        error is HandshakeException ||
        error is TlsException ||
        error is HttpException ||
        error is TimeoutException) {
      return AppImageUpdateFailure(AppImageUpdateFailureKind.network, url.host);
    }
    return AppImageUpdateFailure(
      AppImageUpdateFailureKind.unexpected,
      '$error',
    );
  }

  /// The whole body at [url] (at most [limit] bytes). A 404 is reported as
  /// [AppImageUpdateFailureKind.noDeltaFile] only when [missing] says so.
  Future<Uint8List> getBytes(
    Uri url, {
    int limit = 8 << 20,
    AppImageUpdateFailureKind? missing,
  }) async {
    try {
      var response = await _open(url).timeout(idleTimeout);
      if (const {401, 403, 410}.contains(response.statusCode)) {
        // A stale CDN link: resolve the asset URL again, once.
        await response.drain<void>();
        _resolved.remove(url);
        response = await _open(url).timeout(idleTimeout);
      }
      if (response.statusCode == 404 && missing != null) {
        await response.drain<void>();
        throw AppImageUpdateFailure(missing, url.pathSegments.last);
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw AppImageUpdateFailure(
          AppImageUpdateFailureKind.http,
          '${response.statusCode}',
        );
      }
      final out = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(idleTimeout)) {
        out.add(chunk);
        bytesReceived += chunk.length;
        if (out.length > limit) {
          throw const AppImageUpdateFailure(
            AppImageUpdateFailureKind.unexpected,
            'response too large',
          );
        }
      }
      return out.takeBytes();
    } on Object catch (error) {
      throw _failure(error, url);
    }
  }

  /// Streams bytes `[start, end)` of [url] to [onData], retrying a broken
  /// connection from the first byte not yet delivered.
  Future<void> getRange(
    Uri url,
    int start,
    int end,
    FutureOr<void> Function(int offset, Uint8List chunk) onData, {
    int attempts = 4,
  }) async {
    var next = start;
    for (var attempt = 1; ; attempt++) {
      try {
        rangeRequests++;
        final response = await _open(
          url,
          range: 'bytes=$next-${end - 1}',
        ).timeout(idleTimeout);
        if (response.statusCode == 200) {
          await response.drain<void>();
          throw const AppImageUpdateFailure(
            AppImageUpdateFailureKind.rangesUnsupported,
          );
        }
        if (response.statusCode != 206) {
          await response.drain<void>();
          // The CDN link may have expired; resolve again once.
          if (_resolved.remove(url) != null &&
              const {401, 403, 404, 410}.contains(response.statusCode) &&
              attempt < attempts) {
            continue;
          }
          throw AppImageUpdateFailure(
            AppImageUpdateFailureKind.http,
            '${response.statusCode}',
          );
        }
        final reported =
            response.headers.value(HttpHeaders.contentRangeHeader) ?? '';
        final match = RegExp(r'^bytes (\d+)-(\d+)/').firstMatch(reported);
        if (match == null ||
            int.parse(match[1]!) != next ||
            int.parse(match[2]!) != end - 1) {
          await response.drain<void>();
          throw const AppImageUpdateFailure(
            AppImageUpdateFailureKind.rangesUnsupported,
          );
        }
        await for (final chunk in response.timeout(idleTimeout)) {
          final data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
          bytesReceived += data.length;
          await onData(next, data);
          next += data.length;
        }
        if (next != end) {
          throw const SocketException('connection closed early');
        }
        return;
      } on Object catch (error) {
        final failure = _failure(error, url);
        if (failure.kind != AppImageUpdateFailureKind.network ||
            attempt >= attempts) {
          throw failure;
        }
        _resolved.remove(url);
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
}
