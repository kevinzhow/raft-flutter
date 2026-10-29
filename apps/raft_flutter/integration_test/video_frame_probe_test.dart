// Device test of the native video frame probe (channel `app.raft/video-frame`):
// the first picture and the real shape of a video from its URL, reading only
// byte ranges. It runs against `tool/video-parity-range-server`, which counts
// the bytes it really sends, so "does not download the file" is measured, not
// assumed.
//
//   python3 tool/video-parity-range-server <media dir> 8792 &
//   adb -s <serial> reverse tcp:8792 tcp:8792
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/video_frame_probe_test.dart --dart-define=VFP_BASE=http://127.0.0.1:8792
//   tool/flutter drive --profile -d <serial> --no-pub --keep-app-running \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/video_frame_probe_test.dart --use-application-binary=<apk> \
//     --dart-define=VFP_BASE=http://127.0.0.1:8792
//
// The media directory holds portrait_fast.mp4 / portrait_end.mp4 (720x1280),
// landscape_fast.mp4 / landscape_end.mp4 (1280x720), rot_cw90.mp4 / rot_cw270.mp4
// (1280x720 stored, turned by the container), big_fast.mp4 / big_end.mp4
// (1920x1080, >= 100 MB; "fast" has the index first, "end" last), black_start.mp4 (1280x720,
// two black frames first), audio_only.mp4,
// corrupt.mp4 (random bytes) and truncated.mp4 (the first 4 kB of a clip).
// Every result line is printed as `VFP {json}`; the pictures as `VFPJPEG name index base64`.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_flutter/platform/video_frame_probe.dart';

const _base = String.fromEnvironment(
  'VFP_BASE',
  defaultValue: 'http://127.0.0.1:8792',
);
const _signature = 'X-Sig=secret-signature-must-not-be-logged';
const _probe = ChannelVideoFrameProbe();
const _mib = 1024 * 1024;

Uri _url(String file, [String extra = '']) =>
    Uri.parse('$_base/$file?$_signature$extra');

Future<Map<String, Object?>> _get(String path) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(Uri.parse('$_base$path'));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return jsonDecode(text) as Map<String, Object?>;
  } finally {
    client.close(force: true);
  }
}

class _Measured {
  _Measured(this.file, this.stats, this.wall);
  final String file;
  final Map<String, Object?> stats;
  final Duration wall;

  Map<String, Object?> get _entry =>
      ((stats['files']! as Map)[file] as Map?)?.cast<String, Object?>() ??
      const {'requests': 0, 'bytes': 0, 'size': 0};
  int get bytes => (_entry['bytes']! as num).toInt();
  int get requests => (_entry['requests']! as num).toInt();
  int get size => (_entry['size']! as num).toInt();
  List<String> get ranges => [
    for (final e in (stats['log']! as List).cast<Map>())
      if (e['file'] == file) '${e['range']}->${e['status']}',
  ];
}

Future<_Measured> _measure(String file, Future<void> Function() run) async {
  await _get('/__reset');
  final clock = Stopwatch()..start();
  await run();
  clock.stop();
  // The server counts as it writes; a short wait lets a closed connection show its last bytes.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return _Measured(file, await _get('/__stats'), clock.elapsed);
}

Future<ui.Size> _decodedSize(Uint8List jpeg) async {
  final codec = await ui.instantiateImageCodec(jpeg);
  final frame = await codec.getNextFrame();
  final size = ui.Size(
    frame.image.width.toDouble(),
    frame.image.height.toDouble(),
  );
  frame.image.dispose();
  codec.dispose();
  return size;
}

/// The picture, in numbered 700-character pieces `VFPJPEG name index data` (a log line is short).
Future<void> _dump(String name, Uint8List jpeg) async {
  final text = base64Encode(jpeg);
  for (var i = 0, n = 0; i < text.length; i += 700, n++) {
    final end = i + 700 < text.length ? i + 700 : text.length;
    // ignore: avoid_print
    print('VFPJPEG $name $n ${text.substring(i, end)}');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

// ignore: avoid_print
void _report(Map<String, Object?> row) => print('VFP ${jsonEncode(row)}');

Future<VideoFrameException> _failure(Future<Object?> call) async {
  try {
    await call;
  } on VideoFrameException catch (error) {
    return error;
  }
  fail('expected a VideoFrameException');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // file, displayed width x height, stored rotation, whether the index sits at the end.
  const shapes = <(String, int, int, int)>[
    ('portrait_fast.mp4', 720, 1280, 0),
    ('portrait_end.mp4', 720, 1280, 0),
    ('landscape_fast.mp4', 1280, 720, 0),
    ('landscape_end.mp4', 1280, 720, 0),
    ('rot_cw90.mp4', 720, 1280, 90),
    ('rot_cw270.mp4', 720, 1280, 270),
    ('big_fast.mp4', 1920, 1080, 0),
    ('big_end.mp4', 1920, 1080, 0),
  ];

  for (final (file, width, height, rotation) in shapes) {
    test('reads $file by ranges', () async {
      VideoFrameInfo? info;
      final m = await _measure(file, () async {
        info = await _probe.probe(id: 'shape-$file', url: _url(file));
      });
      final got = info!;
      final jpeg = got.jpeg;
      final decoded = jpeg == null ? null : await _decodedSize(jpeg);
      _report({
        'case': file,
        'fileSize': m.size,
        'bytes': m.bytes,
        'requests': m.requests,
        'ranges': m.ranges,
        'width': got.width,
        'height': got.height,
        'rotation': got.rotation,
        'durationMs': got.duration.inMilliseconds,
        'jpegBytes': jpeg?.length,
        'jpegWidth': decoded?.width,
        'jpegHeight': decoded?.height,
        'wallMs': m.wall.inMilliseconds,
      });
      if (jpeg != null) await _dump(file, jpeg);

      expect([got.width, got.height], [width, height]);
      expect(got.rotation, rotation);
      expect(got.duration.inSeconds, greaterThan(10));
      expect(jpeg, isNotNull);
      expect(decoded, isNotNull);
      expect(
        decoded!.width / decoded.height,
        closeTo(width / height, 0.02),
        reason: 'the picture is upright and has the displayed aspect',
      );
      expect(
        decoded.longestSide,
        lessThanOrEqualTo(640),
        reason: 'the default maxEdge',
      );
      expect(
        m.bytes,
        lessThan(8 * _mib),
        reason: 'ranges only: ${m.bytes} of ${m.size} bytes',
      );
      if (m.size > 100 * _mib) {
        expect(
          m.bytes,
          lessThan(2 * _mib),
          reason: 'the large file costs ${m.bytes} bytes',
        );
      }
    });
  }

  test('a smaller maxEdge gives a smaller picture', () async {
    final info = await _probe.probe(
      id: 'edge',
      url: _url('landscape_fast.mp4'),
      maxEdge: 200,
    );
    final decoded = await _decodedSize(info.jpeg!);
    _report({
      'case': 'maxEdge-200',
      'jpegWidth': decoded.width,
      'jpegHeight': decoded.height,
    });
    expect(decoded.longestSide, lessThanOrEqualTo(200));
    expect(decoded.width / decoded.height, closeTo(16 / 9, 0.03));
  });

  for (final file in ['audio_only.mp4', 'corrupt.mp4', 'truncated.mp4']) {
    test('$file fails without a crash', () async {
      late VideoFrameException error;
      final m = await _measure(file, () async {
        error = await _failure(_probe.probe(id: 'bad-$file', url: _url(file)));
      });
      _report({
        'case': file,
        'error': error.kind.name,
        'bytes': m.bytes,
        'requests': m.requests,
        'wallMs': m.wall.inMilliseconds,
      });
      expect(error.kind, VideoFrameFailure.failed);
    });
  }

  test('a missing file fails', () async {
    final error = await _failure(
      _probe.probe(id: 'missing', url: _url('nope.mp4')),
    );
    _report({'case': 'missing', 'error': error.kind.name});
    expect(error.kind, VideoFrameFailure.failed);
  });

  for (final status in [401, 403, 410]) {
    test('HTTP $status is expired', () async {
      await _get('/__reset');
      await _get('/__fail?file=portrait_fast.mp4&status=$status&count=5');
      final error = await _failure(
        _probe.probe(id: 'expired-$status', url: _url('portrait_fast.mp4')),
      );
      final stats = await _get('/__stats');
      _report({
        'case': 'expired-$status',
        'error': error.kind.name,
        'requests': (stats['log']! as List).length,
      });
      await _get('/__reset');
      expect(error.kind, VideoFrameFailure.expired);
    });
  }

  test('HTTP 500 is failed, not expired', () async {
    await _get('/__reset');
    await _get('/__fail?file=portrait_fast.mp4&status=500&count=5');
    final error = await _failure(
      _probe.probe(id: 'e500', url: _url('portrait_fast.mp4')),
    );
    await _get('/__reset');
    _report({'case': 'http-500', 'error': error.kind.name});
    expect(error.kind, VideoFrameFailure.failed);
  });

  test('a signed URL that works again after a failure', () async {
    final info = await _probe.probe(
      id: 'again',
      url: _url('portrait_fast.mp4'),
    );
    expect(info.valid, isTrue);
  });

  test('cancel stops a slow read at once and closes the connection', () async {
    await _get('/__reset');
    final clock = Stopwatch()..start();
    final pending = _failure(
      _probe.probe(
        id: 'slow-cancel',
        url: _url('big_end.mp4', '&rate=20000'),
        timeout: const Duration(seconds: 60),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    await _probe.cancel('slow-cancel');
    final error = await pending.timeout(const Duration(seconds: 5));
    final answered = clock.elapsed;
    await Future<void>.delayed(const Duration(seconds: 1));
    final atCancel = await _get('/__stats');
    await Future<void>.delayed(const Duration(seconds: 3));
    final later = await _get('/__stats');
    int sent(Map<String, Object?> s) =>
        (((s['files']! as Map)['big_end.mp4'] as Map?)?['bytes'] as num? ?? 0)
            .toInt();
    _report({
      'case': 'cancel',
      'error': error.kind.name,
      'answeredMs': answered.inMilliseconds,
      'serverBytesAt1sAfter': sent(atCancel),
      'serverBytes3sLater': sent(later),
    });
    expect(error.kind, VideoFrameFailure.cancelled);
    expect(answered, lessThan(const Duration(seconds: 3)));
    expect(
      sent(later),
      lessThan(sent(atCancel) + 64 * 1024),
      reason: 'the server saw the connection close and stopped sending',
    );
  });

  test('cancel of an unknown id is a no-op', () async {
    await _probe.cancel('nothing-here');
  });

  test('the time budget ends a slow read as failed', () async {
    final clock = Stopwatch()..start();
    final error = await _failure(
      _probe.probe(
        id: 'slow-timeout',
        url: _url('big_end.mp4', '&rate=20000'),
        timeout: const Duration(seconds: 3),
      ),
    );
    _report({
      'case': 'timeout-3s',
      'error': error.kind.name,
      'wallMs': clock.elapsedMilliseconds,
    });
    expect(error.kind, VideoFrameFailure.failed);
    expect(clock.elapsed, lessThan(const Duration(seconds: 6)));
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  test('the byte budget ends the read as failed', () async {
    late VideoFrameException error;
    final m = await _measure('big_end.mp4', () async {
      error = await _failure(
        _probe.probe(
          id: 'budget',
          url: _url('big_end.mp4'),
          maxBytes: 64 * 1024,
        ),
      );
    });
    _report({
      'case': 'maxBytes-64KiB',
      'error': error.kind.name,
      'bytes': m.bytes,
      'requests': m.requests,
    });
    expect(error.kind, VideoFrameFailure.failed);
    expect(m.bytes, lessThan(2 * 256 * 1024 + 64 * 1024));
  });

  test('only http and https are read', () async {
    for (final url in [
      'file:///data/local/tmp/x.mp4',
      'ftp://127.0.0.1/x.mp4',
    ]) {
      final error = await _failure(
        _probe.probe(id: 'scheme', url: Uri.parse(url)),
      );
      _report({'case': 'scheme-$url', 'error': error.kind.name});
      expect(error.kind, VideoFrameFailure.failed);
    }
  });

  test('a first frame that is black is replaced by the next picture', () async {
    final info = await _probe.probe(id: 'black', url: _url('black_start.mp4'));
    await _dump('black_start.mp4', info.jpeg!);
    final image = (await (await ui.instantiateImageCodec(
      info.jpeg!,
    )).getNextFrame()).image;
    final data = (await image.toByteData())!;
    var sum = 0;
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      sum += data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
    }
    final mean = sum / (data.lengthInBytes / 4) / 3;
    image.dispose();
    _report({'case': 'black_start', 'meanLuma': mean.round()});
    expect(mean, greaterThan(30), reason: 'not the black frame 0');
  });

  group('an unusual host', () {
    late Uint8List clip;
    late HttpServer host;
    final seen = <String>[];
    var sentBytes = 0;

    Future<void> serve(HttpRequest request, {required bool ranges}) async {
      seen.add(
        '${request.uri.path} range=${request.headers.value('range')} '
        'auth=${request.headers.value('authorization')} '
        'host=${request.headers.value('host')?.split(':').first}',
      );
      final response = request.response;
      var start = 0, end = clip.length - 1;
      final match = RegExp(
        r'bytes=(\d+)-(\d*)',
      ).firstMatch(request.headers.value('range') ?? '');
      if (ranges && match != null) {
        start = int.parse(match[1]!);
        if (match[2]!.isNotEmpty) end = int.parse(match[2]!);
        end = end < clip.length ? end : clip.length - 1;
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          'content-range',
          'bytes $start-$end/${clip.length}',
        );
      }
      response.contentLength = end - start + 1;
      try {
        for (var at = start; at <= end; at += 64 * 1024) {
          final to = at + 64 * 1024 - 1 < end ? at + 64 * 1024 : end + 1;
          response.add(Uint8List.sublistView(clip, at, to));
          await response.flush();
          sentBytes += to - at;
        }
        await response.close();
      } on Object {
        // The reader hung up: what a probe that has read enough does.
      }
    }

    setUpAll(() async {
      final client = HttpClient();
      final response = await (await client.getUrl(
        _url('portrait_fast.mp4'),
      )).close();
      clip = Uint8List.fromList(
        await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
      );
      client.close(force: true);
      host = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      host.listen((request) async {
        switch (request.uri.pathSegments.first) {
          case 'norange':
            await serve(request, ranges: false);
          case 'redirect':
            seen.add(
              '${request.uri.path} range=${request.headers.value('range')} '
              'auth=${request.headers.value('authorization')} '
              'host=${request.headers.value('host')?.split(':').first}',
            );
            // Same host name, another path; then a second hop to another host name.
            request.response
              ..statusCode = HttpStatus.found
              ..headers.set(
                'location',
                'http://localhost:${host.port}/direct/clip.mp4?hop=2',
              )
              ..contentLength = 0;
            await request.response.close();
          default:
            await serve(request, ranges: true);
        }
      });
    });

    tearDownAll(() => host.close(force: true));

    test(
      'a host that ignores Range still gives the picture of an index-first file',
      () async {
        seen.clear();
        sentBytes = 0;
        final info = await _probe.probe(
          id: 'norange',
          url: Uri.parse(
            'http://127.0.0.1:${host.port}/norange/clip.mp4?$_signature',
          ),
        );
        _report({
          'case': 'host-ignores-range',
          'size': '${info.width}x${info.height}',
          'fileSize': clip.length,
          'serverFlushedBytes': sentBytes,
          'requests': seen,
        });
        expect(info.jpeg, isNotNull);
        expect([info.width, info.height], [720, 1280]);
      },
    );

    test(
      'a redirect is followed, and custom headers do not cross to another host name',
      () async {
        seen.clear();
        final info = await _probe.probe(
          id: 'redirect',
          url: Uri.parse(
            'http://127.0.0.1:${host.port}/redirect/clip.mp4?$_signature',
          ),
          headers: const {'Authorization': 'Bearer secret-token'},
        );
        _report({
          'case': 'redirect',
          'size': '${info.width}x${info.height}',
          'requests': seen,
        });
        expect(info.jpeg, isNotNull);
        expect(seen.first, contains('auth=Bearer secret-token'));
        expect(
          seen.where((r) => r.contains('/direct/')),
          everyElement(contains('auth=null')),
          reason: 'the redirect target is another host name (localhost)',
        );
      },
    );
  });

  test('four probes at once all finish (two run, two wait)', () async {
    await _get('/__reset');
    final clock = Stopwatch()..start();
    final files = [
      'portrait_fast.mp4',
      'landscape_end.mp4',
      'rot_cw270.mp4',
      'big_end.mp4',
    ];
    final infos = await Future.wait([
      for (final f in files) _probe.probe(id: 'par-$f', url: _url(f)),
    ]);
    final stats = await _get('/__stats');
    _report({
      'case': 'four-at-once',
      'wallMs': clock.elapsedMilliseconds,
      'sizes': [for (final i in infos) '${i.width}x${i.height}'],
      'bytes': {
        for (final e in ((stats['files']! as Map).entries))
          e.key: (e.value as Map)['bytes'],
      },
    });
    expect(
      [for (final i in infos) (i.width, i.height)],
      [(720, 1280), (1280, 720), (720, 1280), (1920, 1080)],
    );
  });
}
