import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/platform/media_failure.dart';
import 'package:raft_flutter/platform/media_probe.dart';

/// Classes from the strings the backends really produce.
///
///  * libmpv 0.41 / FFmpeg 7 (`stream`, `ffmpeg`, `cplayer` log lines): captured
///    from the bundled libmpv by integration_test/media_failure_linux_test.dart.
///  * ExoPlayer (Media3): `video_player_android` 2.12 sends
///    `PlatformException(VideoError, "Video player had error " + error)`, so
///    only `PlaybackException.toString()` reaches Dart: a source error says
///    nothing about its cause.
///  * AVPlayer: `video_player_avfoundation` sends the localized description
///    (`Failed to load video: ...`).
void main() {
  MediaFailureKind? kindOf(String text, {String? proxy}) =>
      classifyMediaText(text, proxy: proxy)?.kind;

  group('libmpv', () {
    test('a bare "Failed to open" names no cause (even with the status in the URL)', () {
      expect(kindOf('Failed to open http://192.168.0.19:42325/403.'), isNull);
      expect(kindOf('Failed to open http://192.168.0.19:42325/404.'), isNull);
      expect(kindOf('Failed to open http://nonexistent.invalid/x.mp4.'), isNull);
    });

    test('connection refused / no route / DNS are the network', () {
      expect(
        kindOf('tcp: Connection to tcp://192.168.0.19:34565 failed: Connection refused'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('tcp: Connection to tcp://192.168.5.7:6152 failed: No route to host'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('tcp: Failed to resolve hostname nonexistent.invalid: Name or service not known'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('tcp: Connection to tcp://x.invalid:443 failed: Connection timed out'),
        MediaFailureKind.network,
      );
    });

    test('a connection failure while a proxy is in use is the proxy, by host:port', () {
      final failure = classifyMediaText(
        'tcp: Connection to tcp://192.168.5.7:6152 failed: No route to host',
        proxy: '192.168.5.7:6152',
      )!;
      expect(failure.kind, MediaFailureKind.proxyUnreachable);
      expect(failure.proxy, '192.168.5.7:6152');
      expect(
        kindOf(
          'tcp: Connection to tcp://192.168.0.19:34565 failed: Connection refused',
          proxy: '192.168.0.19:34565',
        ),
        MediaFailureKind.proxyUnreachable,
      );
      // The proxy's own host that does not resolve.
      expect(
        kindOf(
          'tcp: Failed to resolve hostname proxy.corp: Name or service not known',
          proxy: 'proxy.corp:3128',
        ),
        MediaFailureKind.proxyUnreachable,
      );
    });

    test('another host named in the text is not blamed on the proxy', () {
      expect(
        kindOf(
          'tcp: Connection to tcp://storage.example:443 failed: Connection refused',
          proxy: '192.168.5.7:6152',
        ),
        MediaFailureKind.network,
      );
    });

    test('a timeout is the proxy only when the text says the proxy was dialled', () {
      expect(
        kindOf(
          'tcp: Connection to tcp://192.168.5.7:6152 failed: Connection timed out',
          proxy: '192.168.5.7:6152',
        ),
        MediaFailureKind.proxyUnreachable,
      );
      expect(
        kindOf('Connection timed out', proxy: '192.168.5.7:6152'),
        MediaFailureKind.network,
      );
    });

    test('HTTP statuses', () {
      expect(kindOf('http: HTTP error 403 Forbidden'), MediaFailureKind.expired);
      expect(kindOf('http: HTTP error 401 Unauthorized'), MediaFailureKind.expired);
      expect(kindOf('http: HTTP error 410 Gone'), MediaFailureKind.expired);
      expect(kindOf('http: HTTP error 404 Not Found'), MediaFailureKind.notFound);
      expect(kindOf('http: HTTP error 503 Service Unavailable'), MediaFailureKind.network);
      final auth = classifyMediaText(
        'http: HTTP error 407 Proxy Authentication Required',
        proxy: '10.0.0.2:3128',
      )!;
      expect(auth.kind, MediaFailureKind.proxyAuth);
      expect(auth.proxy, '10.0.0.2:3128');
    });

    test('an unreadable file is unsupported', () {
      expect(kindOf('Failed to recognize file format.'), MediaFailureKind.unsupported);
      expect(kindOf('Invalid data found when processing input'), MediaFailureKind.unsupported);
      expect(kindOf('moov atom not found'), MediaFailureKind.unsupported);
    });
  });

  group('ExoPlayer (video_player_android)', () {
    PlatformException source(String name) => PlatformException(
      code: 'VideoError',
      message: 'Video player had error androidx.media3.exoplayer.ExoPlaybackException: $name',
    );

    test('"Source error" alone names no cause', () {
      expect(classifyMediaError(source('Source error')), isNull);
    });

    test('causes that do reach Dart', () {
      expect(
        classifyMediaError(source('Source error\nCaused by: androidx.media3.datasource.HttpDataSource\$InvalidResponseCodeException: Response code: 403')),
        isA<MediaFailure>().having((f) => f.kind, 'kind', MediaFailureKind.expired),
      );
      expect(
        classifyMediaError(source('Source error: androidx.media3.datasource.HttpDataSource\$InvalidResponseCodeException: Response code: 404')),
        isA<MediaFailure>().having((f) => f.kind, 'kind', MediaFailureKind.notFound),
      );
      expect(
        kindOf('java.net.UnknownHostException: Unable to resolve host "media.example": No address associated with hostname'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('java.net.ConnectException: failed to connect to /192.168.5.7 (port 6152) from /10.0.2.15 (port 41234) after 15000ms'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('androidx.media3.datasource.HttpDataSource\$HttpDataSourceException: Cleartext HTTP traffic to media.example not permitted'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('PlaybackException: ERROR_CODE_IO_NETWORK_CONNECTION_FAILED (2001)'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT (2002)'),
        MediaFailureKind.network,
      );
      expect(kindOf('ERROR_CODE_IO_BAD_HTTP_STATUS (2004)'), isNull);
      expect(kindOf('ERROR_CODE_IO_FILE_NOT_FOUND (2005)'), MediaFailureKind.notFound);
      expect(
        kindOf('ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED (3003)'),
        MediaFailureKind.unsupported,
      );
      expect(
        kindOf('ERROR_CODE_DECODING_FORMAT_UNSUPPORTED (4002)'),
        MediaFailureKind.unsupported,
      );
      expect(
        kindOf('androidx.media3.exoplayer.source.UnrecognizedInputFormatException: None of the available extractors (FragmentedMp4Extractor, Mp4Extractor) could read the stream.'),
        MediaFailureKind.unsupported,
      );
      expect(
        kindOf('androidx.media3.exoplayer.ExoPlaybackException: MediaCodecVideoRenderer error, index=0, format=Format(1, null, video/hevc, hevc, null, -1, null, [3840, 2160, 60.0, ColorInfo()]), format_supported=NO_EXCEEDS_CAPABILITIES'),
        MediaFailureKind.unsupported,
      );
    });
  });

  group('AVPlayer (video_player_avfoundation)', () {
    test('NSURLError and CoreMedia text', () {
      expect(
        kindOf('Failed to load video: The Internet connection appears to be offline.'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('Failed to load video: Could not connect to the server.'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('Failed to load video: The request timed out.'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('Failed to load video: A server with the specified hostname could not be found.'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('Failed to load video: The operation couldn\'t be completed. (NSURLErrorDomain error -1004.)'),
        MediaFailureKind.network,
      );
      expect(
        kindOf('Failed to load video: The operation couldn\'t be completed. (CoreMediaErrorDomain error -12660.)'),
        MediaFailureKind.expired,
      );
      expect(
        kindOf('Failed to load video: Cannot Open: The media cannot be opened.'),
        MediaFailureKind.unsupported,
      );
      expect(
        kindOf('Failed to load video: Cannot Decode: The media cannot be decoded.'),
        MediaFailureKind.unsupported,
      );
    });

    test('a generic failure names no cause', () {
      expect(
        kindOf('Failed to load video: The operation could not be completed'),
        isNull,
      );
    });
  });

  test('the proxy is named, credentials never appear in the cause', () {
    final failure = classifyMediaText(
      'tcp: Connection to tcp://192.168.5.7:6152 failed: No route to host while opening http://user:secret@media.example/a.mp4?sig=abc',
      proxy: '192.168.5.7:6152',
    )!;
    expect(failure.cause, isNot(contains('secret')));
    expect(failure.cause, isNot(contains('sig=abc')));
    expect(failure.logLine, contains('proxy=192.168.5.7:6152'));
    expect(failure.worthResigning, isFalse);
  });

  test('only an expired link or an unknown cause is worth signing again', () {
    for (final kind in MediaFailureKind.values) {
      expect(
        MediaFailure(kind).worthResigning,
        kind == MediaFailureKind.expired || kind == MediaFailureKind.unknown,
        reason: kind.name,
      );
    }
  });

  test('failureOfError reads a MediaPlaybackException and plain exceptions', () {
    const failure = MediaFailure(MediaFailureKind.proxyAuth, proxy: 'p:1');
    expect(failureOfError(const MediaPlaybackException(failure)), same(failure));
    expect(failureOfError(StateError('no url')).kind, MediaFailureKind.unknown);
    expect(
      failureOfError(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
          error: const SocketException('Failed host lookup'),
          message: 'The connection errored: Failed host lookup',
        ),
      ).kind,
      isIn([MediaFailureKind.network, MediaFailureKind.unknown]),
    );
  });

  group('probe', () {
    late Future<MediaFailure?> Function(Uri, Map<String, String>, String?) real;
    late Future<String?> Function(String) realConnect;
    setUp(() {
      real = MediaDiagnosis.probe;
      realConnect = MediaDiagnosis.proxyConnect;
    });
    tearDown(() {
      MediaDiagnosis.probe = real;
      MediaDiagnosis.proxyConnect = realConnect;
    });
    final url = Uri.parse('https://media.example/a.mp4?sig=1');

    test('a status settles what the log did not say', () {
      expect(MediaDiagnosis.probeStatus(403).kind, MediaFailureKind.expired);
      expect(MediaDiagnosis.probeStatus(401).kind, MediaFailureKind.expired);
      expect(MediaDiagnosis.probeStatus(410).kind, MediaFailureKind.expired);
      expect(MediaDiagnosis.probeStatus(404).kind, MediaFailureKind.notFound);
      expect(MediaDiagnosis.probeStatus(500).kind, MediaFailureKind.network);
      expect(MediaDiagnosis.probeStatus(429).kind, MediaFailureKind.network);
      expect(MediaDiagnosis.probeStatus(206).kind, MediaFailureKind.unsupported);
      expect(
        MediaDiagnosis.probeStatus(407, proxy: 'p:3128').kind,
        MediaFailureKind.proxyAuth,
      );
    });

    DioException dio(DioExceptionType type, Object? inner) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      error: inner,
    );

    test('no connection through a proxy is the proxy, direct it is the network', () {
      final refused = dio(
        DioExceptionType.connectionError,
        const SocketException(
          'Connection failed (OS Error: No route to host, errno = 113), address = 192.168.5.7, port = 6152',
        ),
      );
      final viaProxy = MediaDiagnosis.probeError(refused, proxy: '192.168.5.7:6152');
      expect(viaProxy.kind, MediaFailureKind.proxyUnreachable);
      expect(viaProxy.proxy, '192.168.5.7:6152');
      expect(MediaDiagnosis.probeError(refused).kind, MediaFailureKind.network);
      expect(
        MediaDiagnosis.probeError(
          dio(DioExceptionType.connectionTimeout, null),
          proxy: '192.168.5.7:6152',
        ).kind,
        MediaFailureKind.network,
      );
      expect(
        MediaDiagnosis.probeError(
          dio(
            DioExceptionType.unknown,
            const HttpException('Proxy failed to establish tunnel (407 Proxy Authentication Required)'),
          ),
          proxy: 'p:3128',
        ).kind,
        MediaFailureKind.proxyAuth,
      );
      expect(
        MediaDiagnosis.probeError(
          dio(DioExceptionType.unknown, const HandshakeException('bad cert')),
          proxy: 'p:3128',
        ).kind,
        MediaFailureKind.network,
      );
    });

    test('decisive text skips the probe; an unnamed cause is probed', () async {
      var probes = 0;
      MediaDiagnosis.probe = (u, h, p) async {
        probes++;
        return MediaDiagnosis.probeStatus(403);
      };
      final decided = await MediaDiagnosis.diagnose(
        text: 'tcp: Connection to tcp://x:1 failed: Connection refused',
        url: url,
        playerFollowsApp: true,
      );
      expect(decided.kind, MediaFailureKind.network);
      expect(probes, 0);
      final probed = await MediaDiagnosis.diagnose(
        text: 'Failed to open https://media.example/a.mp4.',
        url: url,
        playerFollowsApp: true,
      );
      expect(probed.kind, MediaFailureKind.expired);
      expect(probes, 1);
      expect(probed.cause, contains('probe: HTTP 403'));
      expect(probed.cause, isNot(contains('sig=1')));
    });

    test('a host that serves the bytes: the file, or the link broke mid-stream', () async {
      MediaDiagnosis.probe = (u, h, p) async => MediaDiagnosis.probeStatus(206);
      expect(
        (await MediaDiagnosis.diagnose(text: 'Source error', url: url, playerFollowsApp: false)).kind,
        MediaFailureKind.unsupported,
      );
      expect(
        (await MediaDiagnosis.diagnose(text: 'Source error', url: url, playerFollowsApp: false, started: true)).kind,
        MediaFailureKind.network,
      );
    });

    test('a proxy that does not accept a connection is named, the target is not probed', () async {
      MediaDiagnosis.probe = (u, h, p) async => fail('probed');
      MediaDiagnosis.proxyConnect = (authority) async => 'No route to host';
      SystemProxy.instance.configure(
        const ProxySettings(mode: ProxyMode.manual, host: '192.168.5.7', port: 6152),
      );
      addTearDown(() => SystemProxy.instance.configure(ProxySettings.system));
      final failure = await MediaDiagnosis.diagnose(
        text: 'Failed to open https://media.example/a.mp4.',
        url: url,
        playerFollowsApp: true,
      );
      expect(failure.kind, MediaFailureKind.proxyUnreachable);
      expect(failure.proxy, '192.168.5.7:6152');
      expect(failure.cause, contains('No route to host'));
      // A proxy that accepts the connection leaves the question to the probe.
      MediaDiagnosis.proxyConnect = (authority) async => null;
      MediaDiagnosis.probe = (u, h, p) async => MediaDiagnosis.probeStatus(404);
      expect(
        (await MediaDiagnosis.diagnose(
          text: 'Failed to open https://media.example/a.mp4.',
          url: url,
          playerFollowsApp: true,
        )).kind,
        MediaFailureKind.notFound,
      );
    });

    test('a local file is never probed', () async {
      MediaDiagnosis.probe = (u, h, p) async => fail('probed');
      expect(
        (await MediaDiagnosis.diagnose(text: '', playerFollowsApp: true)).kind,
        MediaFailureKind.unknown,
      );
    });

    test('the proxy decision is named only when the player follows it', () {
      final saved = SystemProxy.instance.settings;
      addTearDown(() => SystemProxy.instance.configure(saved));
      SystemProxy.instance.configure(
        const ProxySettings(mode: ProxyMode.manual, host: '192.168.5.7', port: 6152, username: 'u', password: 'secret'),
      );
      expect(MediaDiagnosis.proxyFor(url, playerFollowsApp: true), '192.168.5.7:6152');
      // ExoPlayer and AVPlayer follow the OS only: a manual choice is not theirs.
      expect(MediaDiagnosis.proxyFor(url, playerFollowsApp: false), isNull);
      SystemProxy.instance.configure(const ProxySettings(mode: ProxyMode.direct));
      expect(MediaDiagnosis.proxyFor(url, playerFollowsApp: true), isNull);
    });
  });
}
