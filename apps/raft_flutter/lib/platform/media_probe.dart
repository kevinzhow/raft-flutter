import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_client/system_proxy.dart';

import 'attachment_http.dart';
import 'attachment_player_log.dart';
import 'media_failure.dart';

/// Settles a playback failure whose backend text names no cause.
///
/// Neither player says why a stream failed: libmpv at `warn` logs only
/// `Failed to open <url>` for a 403, a 404, a DNS miss or a proxy that
/// refuses; ExoPlayer reports `Source error` for all of them; AVPlayer a
/// localized sentence. So when the text is not decisive the app asks the
/// host itself with one tiny ranged request, through the same proxy decision
/// ([SystemProxy]) the player was given, and classifies the answer.
class MediaDiagnosis {
  MediaDiagnosis._();

  /// Test seam: replaces the HTTP probe.
  @visibleForTesting
  static Future<MediaFailure?> Function(Uri url, Map<String, String> headers, String? proxy)
  probe = _httpProbe;

  /// Test seam: replaces the TCP connect to the proxy.
  @visibleForTesting
  static Future<String?> Function(String authority) proxyConnect = _connectProxy;

  /// `host:port` of the HTTP proxy used for [url], or null. [playerFollowsApp]:
  /// the player takes the app's decision (libmpv: the `http-proxy` property).
  /// ExoPlayer and AVPlayer follow the OS proxy only, so a Settings > Network
  /// choice is not theirs and no proxy is named unless it is the system's.
  static String? proxyFor(Uri url, {required bool playerFollowsApp}) {
    try {
      final status = SystemProxy.instance.status(url);
      final proxy = status.proxy;
      if (proxy == null) return null;
      if (!playerFollowsApp &&
          status.source != ProxySource.system &&
          status.source != ProxySource.pac) {
        return null;
      }
      return proxy;
    } on Object {
      return null;
    }
  }

  /// The class of a failure: [text] (backend log lines or exception text)
  /// first; when it names no cause and [url] is a network source, one probe.
  ///
  /// [started]: the stream had played before it failed. A host that answers
  /// the probe is then a dropped connection, not an undecodable file.
  static Future<MediaFailure> diagnose({
    required String text,
    Uri? url,
    Map<String, String> headers = const {},
    required bool playerFollowsApp,
    bool started = false,
  }) async {
    final proxy = url == null
        ? null
        : proxyFor(url, playerFollowsApp: playerFollowsApp);
    final decided = classifyMediaText(text, proxy: proxy);
    if (decided != null) return decided;
    final cause = sanitizeMediaLog(text);
    if (url == null || (url.scheme != 'http' && url.scheme != 'https')) {
      return MediaFailure(MediaFailureKind.unknown, cause: cause);
    }
    // Behind a proxy the player only ever dials the proxy: if it does not
    // answer a plain TCP connect, that is the failure, whatever the target.
    if (proxy != null) {
      final why = await proxyConnect(proxy);
      if (why != null) {
        return MediaFailure(
          MediaFailureKind.proxyUnreachable,
          proxy: proxy,
          cause: [
            if (cause.isNotEmpty) cause,
            'proxy connect: $why',
          ].join(' | '),
        );
      }
    }
    MediaFailure? probed;
    try {
      probed = await probe(url, headers, proxy);
    } on Object {
      probed = null;
    }
    if (probed == null) {
      return MediaFailure(MediaFailureKind.unknown, cause: cause);
    }
    // The host served the bytes: what failed is the file, or the link broke.
    final reachable = probed.kind == MediaFailureKind.unsupported;
    final kind = reachable && started ? MediaFailureKind.network : probed.kind;
    return MediaFailure(
      kind,
      proxy: probed.proxy,
      cause: [
        if (cause.isNotEmpty) cause,
        'probe: ${probed.cause}',
      ].join(' | '),
    );
  }

  /// Why a TCP connection to [authority] (`host:port`) cannot be made, or
  /// null when it can.
  static Future<String?> _connectProxy(String authority) async {
    final colon = authority.lastIndexOf(':');
    final port = int.tryParse(authority.substring(colon + 1));
    if (colon <= 0 || port == null) return null;
    var host = authority.substring(0, colon);
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      return null;
    } on SocketException catch (error) {
      // ignore: raft_lints/avoid_caught_exception_text -- The OS reason a TCP connect to the proxy failed; it becomes the sanitized cause line of a MediaFailure, which only the journal shows. The user sees one of the fixed media failure messages.
      return error.osError?.message ?? error.message;
    } on TimeoutException {
      return 'connection timed out';
    } on Object {
      return null;
    }
  }

  static Future<MediaFailure?> _httpProbe(
    Uri url,
    Map<String, String> headers,
    String? proxy,
  ) async {
    final cancel = CancelToken();
    try {
      final response = await AttachmentHttp.shared
          .get<ResponseBody>(
            url.toString(),
            cancelToken: cancel,
            options: Options(
              responseType: ResponseType.stream,
              headers: {...headers, 'range': 'bytes=0-1023'},
              validateStatus: (_) => true,
              followRedirects: true,
              receiveTimeout: const Duration(seconds: 8),
            ),
          )
          .timeout(const Duration(seconds: 10));
      final code = response.statusCode ?? 0;
      cancel.cancel('probe done');
      return probeStatus(code, proxy: proxy);
    } on DioException catch (error) {
      return probeError(error, proxy: proxy);
    } on TimeoutException {
      return const MediaFailure(
        MediaFailureKind.network,
        cause: 'probe timed out',
      );
    } on Object {
      return null;
    }
  }

  /// The class of a probe answered with HTTP [code]: 2xx means the host
  /// serves the bytes (so the file is what the player rejected).
  @visibleForTesting
  static MediaFailure probeStatus(int code, {String? proxy}) {
    final cause = 'HTTP $code';
    if (code >= 200 && code < 300) {
      return MediaFailure(MediaFailureKind.unsupported, cause: cause);
    }
    return switch (code) {
      407 => MediaFailure(MediaFailureKind.proxyAuth, proxy: proxy, cause: cause),
      401 || 403 || 410 => MediaFailure(MediaFailureKind.expired, cause: cause),
      404 => MediaFailure(MediaFailureKind.notFound, cause: cause),
      // An empty file: nothing to decode.
      416 => MediaFailure(MediaFailureKind.unsupported, cause: cause),
      _ => MediaFailure(MediaFailureKind.network, cause: cause),
    };
  }

  /// The class of a probe that did not get an answer. A connection that could
  /// not be made while a proxy is in use is the proxy's.
  @visibleForTesting
  static MediaFailure probeError(DioException error, {String? proxy}) {
    final inner = error.error;
    final cause = sanitizeMediaLog('${error.type.name} ${inner ?? error.message ?? ''}');
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return MediaFailure(MediaFailureKind.network, cause: cause);
      case DioExceptionType.badCertificate:
        return MediaFailure(MediaFailureKind.network, cause: cause);
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (inner is HandshakeException || inner is TlsException) {
          return MediaFailure(MediaFailureKind.network, cause: cause);
        }
        // An HTTPS tunnel through a proxy that refuses it: dart:io throws
        // an HttpException that names the proxy's status.
        final text = '$inner'.toLowerCase();
        if (text.contains('407') || text.contains('proxy authentication')) {
          return MediaFailure(
            MediaFailureKind.proxyAuth,
            proxy: proxy,
            cause: cause,
          );
        }
        if (inner is SocketException ||
            error.type == DioExceptionType.connectionError ||
            text.contains('tunnel')) {
          return MediaFailure(
            proxy == null
                ? MediaFailureKind.network
                : MediaFailureKind.proxyUnreachable,
            proxy: proxy,
            cause: cause,
          );
        }
        return MediaFailure(MediaFailureKind.unknown, cause: cause);
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return MediaFailure(MediaFailureKind.unknown, cause: cause);
    }
  }
}
