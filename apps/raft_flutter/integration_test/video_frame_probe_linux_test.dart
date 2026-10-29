// Real libmpv, real sockets: drives MpvVideoFrameProbe (the Windows/Linux
// first-frame probe of video cards) against a local byte-counting HTTP server
// that supports Range, and checks the picture, the shape, the bytes read, the
// error classes, cancel and that no player is left behind.
//
//   xvfb-run -a tool/flutter test integration_test/video_frame_probe_linux_test.dart \
//     -d linux [--dart-define=VIDEO_FRAME_MEDIA=<dir> --dart-define=VIDEO_FRAME_REPORT=<dir>]
//
// The test makes its own media with ffmpeg (a portrait and a landscape H.264
// clip, one with the moov box at the end, a 90 degree rotated one, a ~140 MB
// one, a corrupt file, an audio-only file) into VIDEO_FRAME_MEDIA (default: a
// temporary directory). VIDEO_FRAME_REPORT, when set, receives one line per
// case and the decoded JPEGs.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/platform/video_frame_probe.dart';
import 'package:raft_flutter/platform/video_frame_probe_mpv.dart';

const _mediaDir = String.fromEnvironment('VIDEO_FRAME_MEDIA');
const _reportDir = String.fromEnvironment('VIDEO_FRAME_REPORT');

/// One request the server saw.
class _Hit {
  _Hit(this.path, this.range, this.status);
  final String path;
  final String? range;
  final int status;
  int sent = 0;
  bool finished = false;
}

/// HTTP server over a directory: Range support, per-request byte counts, a
/// small send buffer (so `sent` is close to what the client consumed), error
/// statuses on demand (`/403/x`) and a throttled mode (`/slow/x`).
class _Server {
  _Server(this.root);
  final Directory root;
  late final HttpServer server;
  final hits = <_Hit>[];

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_serve);
  }

  Uri url(String mode, String name) => Uri.parse('http://127.0.0.1:${server.port}/$mode/$name');

  void reset() => hits.clear();
  int get total => hits.fold(0, (a, h) => a + h.sent);

  Future<void> close() => server.close(force: true);

  Future<void> _serve(HttpRequest request) async {
    final parts = request.uri.pathSegments;
    final mode = parts.isEmpty ? '' : parts.first;
    final name = parts.length > 1 ? parts.last : '';
    final range = request.headers.value('range');
    final status = int.tryParse(mode);
    final response = request.response;
    if (status != null) {
      hits.add(_Hit(request.uri.path, range, status)..finished = true);
      response.statusCode = status;
      await response.close();
      return;
    }
    final file = File('${root.path}/$name');
    if (!file.existsSync()) {
      hits.add(_Hit(request.uri.path, range, 404)..finished = true);
      response.statusCode = 404;
      await response.close();
      return;
    }
    final size = file.lengthSync();
    var start = 0, end = size - 1, code = 200;
    final match = range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
    if (match != null) {
      code = 206;
      if (match.group(1)!.isEmpty) {
        start = size - int.parse(match.group(2)!);
      } else {
        start = int.parse(match.group(1)!);
        if (match.group(2)!.isNotEmpty) {
          end = int.parse(match.group(2)!).clamp(0, size - 1);
        }
      }
    }
    final hit = _Hit(request.uri.path, range, code);
    hits.add(hit);
    response
      ..statusCode = code
      ..headers.set('accept-ranges', 'bytes')
      ..headers.contentType = ContentType('video', 'mp4')
      ..contentLength = end - start + 1;
    if (code == 206) {
      response.headers.set('content-range', 'bytes $start-$end/$size');
    }
    final socket = await response.detachSocket(writeHeaders: true);
    try {
      // SOL_SOCKET = 1, SO_SNDBUF = 7 on Linux.
      socket.setRawOption(RawSocketOption.fromInt(1, 7, 32768));
    } on Object {
      // best effort
    }
    final slow = mode == 'slow';
    final reader = await file.open();
    try {
      await reader.setPosition(start);
      var left = end - start + 1;
      while (left > 0) {
        final chunk = await reader.read(left < 16384 ? left : 16384);
        if (chunk.isEmpty) break;
        socket.add(chunk);
        await socket.flush();
        hit.sent += chunk.length;
        left -= chunk.length;
        if (slow) await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } on Object {
      // the client closed the connection
    } finally {
      hit.finished = true;
      await reader.close();
      socket.destroy();
    }
  }
}

Future<void> _ffmpeg(List<String> args) async {
  final result = await Process.run('nice', ['-n', '10', 'ffmpeg', '-y', '-loglevel', 'error', ...args]);
  if (result.exitCode != 0) fail('ffmpeg ${args.join(' ')}: ${result.stderr}');
}

Future<Directory> _makeMedia() async {
  final dir = _mediaDir.isNotEmpty
      ? Directory(_mediaDir)
      : Directory.systemTemp.createTempSync('raft_frame_media_');
  dir.createSync(recursive: true);
  String path(String name) => '${dir.path}/$name';
  bool missing(String name) => !File(path(name)).existsSync();
  List<String> testsrc(String size, int seconds, [String extra = '']) => [
    '-f', 'lavfi', '-i', 'testsrc2=size=$size:rate=30:duration=$seconds$extra',
  ];
  const h264 = ['-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p'];
  if (missing('portrait_start.mp4')) {
    await _ffmpeg([...testsrc('720x1280', 30), ...h264, '-b:v', '2M', '-movflags', '+faststart', path('portrait_start.mp4')]);
  }
  if (missing('landscape_end.mp4')) {
    // No faststart: the moov box is at the end of the file.
    await _ffmpeg([...testsrc('1280x720', 30), ...h264, '-b:v', '2M', path('landscape_end.mp4')]);
  }
  if (missing('rotated90.mp4')) {
    // Stored 1280x720, the container asks for a 90 degree turn: shown 720x1280.
    await _ffmpeg(['-display_rotation', '270', '-i', path('landscape_end.mp4'), '-c', 'copy', '-movflags', '+faststart', path('rotated90.mp4')]);
  }
  if (missing('big_end.mp4')) {
    await _ffmpeg([
      '-f', 'lavfi', '-i', 'testsrc2=size=1920x1080:rate=30:duration=100,noise=alls=40:allf=t',
      '-c:v', 'libx264', '-preset', 'ultrafast', '-b:v', '12M', '-maxrate', '12M', '-bufsize', '24M', '-pix_fmt', 'yuv420p',
      path('big_end.mp4'),
    ]);
  }
  if (missing('audio_only.m4a')) {
    await _ffmpeg(['-f', 'lavfi', '-i', 'sine=frequency=330:duration=20', '-c:a', 'aac', path('audio_only.m4a')]);
  }
  if (missing('corrupt.mp4')) {
    File(path('corrupt.mp4')).writeAsBytesSync(List.generate(5000, (i) => (i * 7919 + 13) % 251));
  }
  if (missing('truncated.mp4')) {
    File(path('truncated.mp4')).writeAsBytesSync(File(path('landscape_end.mp4')).readAsBytesSync().sublist(0, 200000));
  }
  return dir;
}

/// Decodes [jpeg] and returns its size and mean brightness (0..255).
Future<(int, int, double)> _decode(Uint8List jpeg) async {
  final codec = await ui.instantiateImageCodec(jpeg);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = (await image.toByteData())!;
  var sum = 0, n = 0;
  for (var i = 0; i + 3 < data.lengthInBytes; i += 4 * 97) {
    sum += data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
    n += 3;
  }
  final result = (image.width, image.height, sum / n);
  image.dispose();
  codec.dispose();
  return result;
}

/// Linux process counters: resident set in KiB and thread count.
({int rssKiB, int threads}) _counters() {
  final status = File('/proc/self/status').readAsLinesSync();
  int field(String name) =>
      int.parse(RegExp(r'\d+').firstMatch(status.firstWhere((l) => l.startsWith(name)))!.group(0)!);
  return (rssKiB: field('VmRSS:'), threads: field('Threads:'));
}

/// libmpv instances alive in this process: each runs one thread named `core`.
int _mpvInstances() {
  var count = 0;
  for (final dir in Directory('/proc/self/task').listSync()) {
    try {
      if (File('${dir.path}/comm').readAsStringSync().trim() == 'core') count++;
    } on Object {
      // the thread ended
    }
  }
  return count;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first frame and shape from ranged reads, errors, cancel, no leak', (tester) async {
    await tester.runAsync(() async {
      SystemProxy.instance.configure(const ProxySettings(mode: ProxyMode.direct));
      final media = await _makeMedia();
      final server = _Server(media);
      await server.start();
      addTearDown(server.close);
      final report = <String>[];
      final reportDir = _reportDir.isEmpty ? null : Directory(_reportDir);
      reportDir?.createSync(recursive: true);
      void note(String line) {
        // ignore: avoid_print
        print('VIDEO_FRAME $line');
        report.add(line);
      }

      final probe = MpvVideoFrameProbe();
      var counter = 0;
      String nextId() => 'p${counter++}';

      Future<VideoFrameInfo> run(String name, {String mode = 'm', int maxEdge = 640, Duration timeout = const Duration(seconds: 20), int maxBytes = 16 * 1024 * 1024, String? id}) =>
          probe.probe(id: id ?? nextId(), url: server.url(mode, name), maxEdge: maxEdge, timeout: timeout, maxBytes: maxBytes);

      /// Probes [name], checks the shape and the picture, records the bytes.
      Future<void> ok(String name, {required int shownWidth, required int shownHeight, required int pictureWidth, required int pictureHeight, int rotation = 0, int maxServed = 4 * 1024 * 1024}) async {
        server.reset();
        final clock = Stopwatch()..start();
        final info = await run(name);
        clock.stop();
        final size = File('${media.path}/$name').lengthSync();
        expect((info.width, info.height), (shownWidth, shownHeight), reason: name);
        expect(info.rotation, rotation, reason: name);
        expect(info.duration, greaterThan(const Duration(seconds: 1)), reason: name);
        final (w, h, brightness) = await _decode(info.jpeg!);
        expect((w, h), (pictureWidth, pictureHeight), reason: '$name picture');
        expect(brightness, greaterThan(25), reason: '$name picture is not black');
        expect(server.total, lessThan(maxServed), reason: '$name read ${server.total} of $size');
        note('$name size=$size served=${server.total} requests=${server.hits.length} '
            'ranges=${server.hits.map((h) => h.range).join('|')} shown=${info.width}x${info.height} rotation=${info.rotation} '
            'jpeg=${w}x$h (${info.jpeg!.length} B) duration=${info.duration.inSeconds}s time=${clock.elapsedMilliseconds}ms');
        if (reportDir != null) File('${reportDir.path}/$name.jpg').writeAsBytesSync(info.jpeg!);
        expect(probe.activeCount, 0);
      }

      await ok('portrait_start.mp4', shownWidth: 720, shownHeight: 1280, pictureWidth: 360, pictureHeight: 640);
      await ok('landscape_end.mp4', shownWidth: 1280, shownHeight: 720, pictureWidth: 640, pictureHeight: 360);
      await ok('rotated90.mp4', shownWidth: 720, shownHeight: 1280, pictureWidth: 360, pictureHeight: 640, rotation: 90);
      await ok('big_end.mp4', shownWidth: 1920, shownHeight: 1080, pictureWidth: 640, pictureHeight: 360);
      // A small edge limit scales further, and a limit above the size never enlarges.
      final small = await run('landscape_end.mp4', maxEdge: 200);
      expect((await _decode(small.jpeg!)).$1, 200);
      final big = await run('landscape_end.mp4', maxEdge: 4000);
      expect((await _decode(big.jpeg!)).$1, 1280);
      final bigSize = File('${media.path}/big_end.mp4').lengthSync();
      expect(bigSize, greaterThan(100 * 1024 * 1024));

      // Expired signatures.
      for (final status in ['403', '401', '410']) {
        server.reset();
        await expectLater(
          run('portrait_start.mp4', mode: status),
          throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.expired)),
          reason: status,
        );
        note('HTTP $status -> expired (requests=${server.hits.length})');
      }
      // Not found, unreachable host, corrupt, truncated, audio-only: failed.
      Future<void> failed(String label, Future<VideoFrameInfo> future) async {
        await expectLater(
          future,
          throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.failed)),
          reason: label,
        );
        note('$label -> failed');
      }

      await failed('HTTP 404', run('portrait_start.mp4', mode: '404'));
      await failed('corrupt.mp4', run('corrupt.mp4'));
      await failed('truncated.mp4', run('truncated.mp4'));
      await failed('audio_only.m4a', run('audio_only.m4a'));
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = closed.port;
      await closed.close();
      await failed(
        'closed port',
        probe.probe(id: nextId(), url: Uri.parse('http://127.0.0.1:$closedPort/x.mp4')),
      );

      // Budgets.
      server.reset();
      final spent = Stopwatch()..start();
      await failed('byte budget', run('big_end.mp4', maxBytes: 64 * 1024));
      note('byte budget served=${server.total} time=${spent.elapsedMilliseconds}ms');
      spent
        ..reset()
        ..start();
      await failed('timeout', run('big_end.mp4', mode: 'slow', timeout: const Duration(seconds: 2)));
      note('timeout 2s elapsed=${spent.elapsedMilliseconds}ms');
      expect(spent.elapsedMilliseconds, lessThan(5000));

      // Cancel: stops the matching probe, its player is gone, the server is left alone.
      server.reset();
      final pending = probe.probe(id: 'cancel-me', url: server.url('slow', 'big_end.mp4'));
      final outcome = pending.then<Object?>((v) => v, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(probe.activeCount, 1);
      await probe.cancel('cancel-me');
      expect(probe.activeCount, 0);
      final cancelled = await outcome;
      expect(cancelled, isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.cancelled));
      await probe.cancel('unknown-id');
      // The connection closes a moment after the player is told to stop.
      await Future<void>.delayed(const Duration(seconds: 1));
      final settled = server.total;
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(server.total, settled, reason: 'no reads after cancel');
      note('cancel -> cancelled; served=$settled and nothing after');

      // Resource check: 12 sequential, then 30 probes two at a time. A
      // player is reused between probes (see LibmpvPlayerPool), so the number
      // of libmpv instances stays at most 2 and nothing grows.
      final pool = LibmpvPlayerPool.shared;
      await pool.drain();
      // media_kit ends a disposed libmpv instance 5 s later.
      await Future<void>.delayed(const Duration(seconds: 7));
      final before = _counters();
      note('baseline rss=${before.rssKiB}KiB threads=${before.threads} mpvInstances=${_mpvInstances()} pool(created=${pool.created} ended=${pool.ended})');
      var peak = 0;
      for (var i = 0; i < 12; i++) {
        await run('portrait_start.mp4');
        peak = peak < _mpvInstances() ? _mpvInstances() : peak;
      }
      final afterSequential = _counters();
      note('after 12 sequential rss=${afterSequential.rssKiB}KiB threads=${afterSequential.threads} mpvInstances=${_mpvInstances()} idle=${pool.idleCount}');
      final names = ['portrait_start.mp4', 'landscape_end.mp4', 'rotated90.mp4'];
      for (var i = 0; i < 15; i++) {
        await Future.wait([run(names[i % 3]), run(names[(i + 1) % 3])]);
        peak = peak < _mpvInstances() ? _mpvInstances() : peak;
      }
      final after = _counters();
      note('after 30 (2 concurrent) rss=${after.rssKiB}KiB threads=${after.threads} mpvInstances=${_mpvInstances()} peak=$peak idle=${pool.idleCount} pool(created=${pool.created} ended=${pool.ended})');
      expect(probe.activeCount, 0);
      expect(pool.alive, pool.idleCount, reason: 'a player is still leased');
      // Another 30 probes cost nothing more: no thread, no memory growth.
      for (var i = 0; i < 15; i++) {
        await Future.wait([run(names[i % 3]), run(names[(i + 2) % 3])]);
        peak = peak < _mpvInstances() ? _mpvInstances() : peak;
      }
      final again = _counters();
      note('after 60 (2 concurrent) rss=${again.rssKiB}KiB threads=${again.threads} mpvInstances=${_mpvInstances()} peak=$peak pool(created=${pool.created} ended=${pool.ended})');
      expect(peak, lessThanOrEqualTo(2));
      expect(again.threads, lessThanOrEqualTo(after.threads + 4), reason: 'threads grew');
      expect(again.rssKiB - after.rssKiB, lessThan(40 * 1024), reason: 'resident memory grew');
      expect(probe.activeCount, 0);
      // Nothing is left once the pool is drained.
      await pool.drain();
      await Future<void>.delayed(const Duration(seconds: 7));
      final ended = _counters();
      note('after drain rss=${ended.rssKiB}KiB threads=${ended.threads} mpvInstances=${_mpvInstances()} alive=${pool.alive}');
      expect(_mpvInstances(), 0, reason: 'a libmpv instance is still alive');
      expect(pool.alive, 0);

      if (reportDir != null) File('${reportDir.path}/report.txt').writeAsStringSync('${report.join('\n')}\n');
    });
  });
}
