/// Why a streamed or local attachment could not be played, derived from what
/// each backend reports plus what the app itself knows (the proxy decision).
///
/// The classes are the ones a user can act on:
///
///  * [MediaFailureKind.proxyUnreachable] / [MediaFailureKind.proxyAuth]: the
///    HTTP proxy in use does not answer / wants credentials. Names host:port,
///    never credentials. Action: Network settings, Retry.
///  * [MediaFailureKind.network]: no route, refused, DNS, timeout, TLS, a
///    failing server. Action: Retry.
///  * [MediaFailureKind.expired]: the signed URL was refused (401/403/410)
///    even after the player signed again once. Action: Retry (signs again).
///  * [MediaFailureKind.notFound]: 404 or a missing local file.
///  * [MediaFailureKind.unsupported]: the bytes arrived but no demuxer or
///    decoder takes them (unknown container, corrupt file, missing codec).
///  * [MediaFailureKind.unknown]: nothing recognisable.
///
/// This file is pure Dart (no Flutter, no network): the classifiers are unit
/// tested with the real strings of mpv, ExoPlayer and AVPlayer. The network
/// probe that settles ambiguous cases lives in `media_probe.dart`.
library;

import 'package:flutter/services.dart' show PlatformException;

import 'attachment_player_log.dart';

enum MediaFailureKind {
  proxyUnreachable,
  proxyAuth,
  network,
  expired,
  notFound,
  unsupported,
  unknown,
}

class MediaFailure {
  const MediaFailure(this.kind, {this.proxy, this.cause = ''});

  final MediaFailureKind kind;

  /// `host:port` of the HTTP proxy the failure is attributed to (proxy kinds
  /// only). Never carries credentials.
  final String? proxy;

  /// The underlying cause, already sanitized (see [sanitizeMediaLog]): the
  /// line support reads in the journal. Never shown to the user.
  final String cause;

  /// Whether signing the URL again can help: an expired signature, or a
  /// failure whose cause is not known yet. A refused proxy, a missing network
  /// or an undecodable file will fail the same way again.
  bool get worthResigning =>
      kind == MediaFailureKind.expired || kind == MediaFailureKind.unknown;

  /// One diagnostic line (class, proxy host:port, sanitized cause).
  String get logLine =>
      'class=${kind.name}${proxy == null ? '' : ' proxy=$proxy'}'
      '${cause.isEmpty ? '' : ' cause="$cause"'}';

  MediaFailure withProxy(String? value) =>
      MediaFailure(kind, proxy: value, cause: cause);

  @override
  String toString() => 'MediaFailure($logLine)';
}

/// Thrown by a player's `open` when the source cannot be played; carries the
/// class so the card shows the right message.
class MediaPlaybackException implements Exception {
  const MediaPlaybackException(this.failure);
  final MediaFailure failure;
  @override
  String toString() => 'MediaPlaybackException(${failure.logLine})';
}

/// The class of an exception thrown while opening or preparing media: a
/// player's [MediaPlaybackException], a platform error, a failed request for
/// the signed URL.
MediaFailure failureOfError(Object error, {String? proxy}) {
  if (error is MediaPlaybackException) return error.failure;
  return classifyMediaError(error, proxy: proxy) ??
      MediaFailure(
        MediaFailureKind.unknown,
        cause: sanitizeMediaLog(mediaErrorText(error)),
      );
}

/// The text a failure is classified from: a platform error's code, message
/// and details, or the exception's own text.
String mediaErrorText(Object error) {
  if (error is PlatformException) {
    return '${error.code} ${error.message ?? ''} ${error.details ?? ''}';
  }
  return '$error';
}

/// The class of [error] from its text, or null when nothing in it is
/// recognisable (the caller then probes or reports unknown).
MediaFailure? classifyMediaError(Object error, {String? proxy}) =>
    classifyMediaText(mediaErrorText(error), proxy: proxy);

final _statusAfterContext = RegExp(
  r'(?:http(?:/\d(?:\.\d)?)?(?: error)?|response code|status(?: code)?|bad_http_status|error)[\s:=(-]*(\d{3})\b',
);
final _tcpTarget = RegExp(r'tcp://([^\s/:]+|\[[^\]]+\]):(\d+)');
final _resolveTarget = RegExp(
  r'resolve (?:hostname |host )?([^\s:]+)',
);

/// Classifies the text of one failure: the mpv log lines since the last open,
/// a `PlatformException` of `video_player` (ExoPlayer, AVPlayer), a Dart
/// network exception. Returns null when the text names no cause.
///
/// [proxy] is the `host:port` of the HTTP proxy the player was told to use,
/// when the app knows one: a connection-level failure while a proxy is in use
/// is the proxy's, unless the text names another host.
MediaFailure? classifyMediaText(String text, {String? proxy}) {
  // URLs carry path segments that look like status codes ("/403"); cut them
  // down to scheme://host:port first, which is also what may be logged.
  final clean = sanitizeMediaLog(text, maxLength: 600);
  final lower = clean.toLowerCase();
  MediaFailure make(MediaFailureKind kind, {bool proxyBlame = false}) =>
      MediaFailure(
        kind,
        proxy: proxyBlame ? proxy : null,
        cause: sanitizeMediaLog(text),
      );

  // -- HTTP status the backend reported ------------------------------------
  var status = int.tryParse(
    _statusAfterContext.firstMatch(lower)?.group(1) ?? '',
  );
  if (status == null) {
    if (lower.contains('proxy authentication required')) {
      status = 407;
    } else if (lower.contains('forbidden') ||
        lower.contains('coremediaerrordomain') && lower.contains('-12660')) {
      status = 403;
    } else if (lower.contains('unauthorized')) {
      status = 401;
    } else if (lower.contains('http') && lower.contains('not found') ||
        lower.contains('filenotfoundexception') ||
        lower.contains('error_code_io_file_not_found') ||
        lower.contains('coremediaerrordomain') && lower.contains('-12938') ||
        lower.contains('nsurlerrordomain') && lower.contains('-1100')) {
      status = 404;
    }
  }
  if (status != null) {
    if (status == 407) {
      return make(MediaFailureKind.proxyAuth, proxyBlame: proxy != null);
    }
    if (status == 401 || status == 403 || status == 410) {
      return make(MediaFailureKind.expired);
    }
    if (status == 404) return make(MediaFailureKind.notFound);
    if (status == 502 || status == 503 || status == 504) {
      // A proxy that cannot pass the request on, or an overloaded server.
      return make(MediaFailureKind.network, proxyBlame: false);
    }
    if (status == 429 || status >= 500) return make(MediaFailureKind.network);
  }

  // -- Cannot connect --------------------------------------------------------
  const connection = [
    'no route to host',
    'connection refused',
    'network is unreachable',
    'host is unreachable',
    'connection timed out',
    'timed out',
    'timeout',
    'name or service not known',
    'failed to resolve',
    'could not resolve',
    'unable to resolve',
    'temporary failure in name resolution',
    'nodename nor servname',
    'unknownhostexception',
    'connectexception',
    'failed to connect',
    'connection reset',
    'connection closed',
    'broken pipe',
    'network_connection',
    'sockettimeoutexception',
    'sockettimeout',
    'unreachable',
    'cleartext http traffic',
    // Apple: NSURLError localized descriptions and domain codes.
    'internet connection appears to be offline',
    'could not connect to the server',
    'hostname could not be found',
    'network connection was lost',
    'request timed out',
    'cannot find host',
  ];
  final appleNetwork = RegExp(
    r'nsurlerrordomain[^\d-]*-(1001|1003|1004|1005|1009|1018|1200|1201|1202|1203|1204|1205|1206)\b',
  );
  final connectionFailure =
      connection.any(lower.contains) || appleNetwork.hasMatch(lower);
  if (connectionFailure) {
    // Behind a proxy the player only ever dials the proxy, unless the text
    // names some other host (a redirect to a storage host).
    final dialed = proxy?.toLowerCase();
    var proxyBlame = dialed != null;
    // The text itself says the proxy is what was dialled.
    var namedProxy = false;
    if (dialed != null) {
      final target = _tcpTarget.firstMatch(lower);
      if (target != null) {
        proxyBlame = namedProxy = '${target.group(1)}:${target.group(2)}' == dialed;
      } else {
        final resolved = _resolveTarget.firstMatch(lower)?.group(1);
        if (resolved != null) proxyBlame = dialed.startsWith('$resolved:');
      }
    }
    final tls =
        lower.contains('ssl') ||
        lower.contains('tls') ||
        lower.contains('certificate') ||
        lower.contains('handshake');
    if (tls) return make(MediaFailureKind.network);
    if (!namedProxy &&
        (lower.contains('timed out') ||
            lower.contains('timeout') ||
            lower.contains('cleartext'))) {
      // A slow answer from nobody in particular is not evidence about the
      // proxy.
      return make(MediaFailureKind.network);
    }
    return make(
      proxyBlame ? MediaFailureKind.proxyUnreachable : MediaFailureKind.network,
      proxyBlame: proxyBlame,
    );
  }

  // -- The bytes arrived but cannot be played ------------------------------
  const unsupported = [
    'failed to recognize file format',
    'unrecognized file format',
    'unknown format',
    'invalid data found when processing input',
    'moov atom not found',
    'no decoder',
    'failed to initialize a decoder',
    'unsupported',
    'not supported',
    'error_code_parsing_',
    'error_code_decoder_',
    'error_code_decoding_',
    'error_code_audio_track',
    'parserexception',
    'unrecognizedinputformatexception',
    'none of the available extractors',
    'decoderinitializationexception',
    'mediacodec',
    'format_supported=no',
    'no audio or video data',
    // Apple: AVFoundationErrorDomain -11828 / -11829 / -11821 and their text.
    'cannot open',
    'cannot decode',
    'avfoundationerrordomain error -11828',
    'avfoundationerrordomain error -11829',
    'avfoundationerrordomain error -11821',
    'media format is not supported',
  ];
  if (unsupported.any(lower.contains)) return make(MediaFailureKind.unsupported);

  return null;
}
