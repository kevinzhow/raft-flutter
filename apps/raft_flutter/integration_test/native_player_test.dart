import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:raft_flutter/platform/attachment_player.dart';

import '../test/fixtures/preview_samples.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native private local video decodes and advances', (
    tester,
  ) async {
    final report = Directory(const String.fromEnvironment('RAFT_TEST_REPORT'));
    await report.create(recursive: true);
    final input = await File('${report.path}/generated.webm')
        .writeAsBytes(previewVideo());
    final player = NativeAttachmentPlayer();
    final logs = <Map<String, String>>[];
    final errors = <String>[];
    String safe(String value) => value.replaceAll(
      RegExp(r'(?:https?://|file://|/data/|/home/)\S+'),
      '[local input]',
    );
    final log = player.player.stream.log.listen((entry) {
      if (logs.length < 40) {
        logs.add({
          'prefix': entry.prefix,
          'level': entry.level,
          'text': safe(entry.text),
        });
      }
    });
    final error = player.player.stream.error.listen(
      (value) => errors.add(safe(value)),
    );
    final boundary = GlobalKey();
    final proof = <String, Object?>{};
    var completed = false;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: Center(
                child: SizedBox(width: 320, height: 180, child: player.video()),
              ),
            ),
          ),
        ),
      );
      final opened = player.open(AttachmentSource.file(input));
      for (
        var i = 0;
        i < 100 && player.player.state.duration == Duration.zero;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await opened;
      expect(player.player.state.duration, greaterThan(Duration.zero));
      await player.toggle();
      for (
        var i = 0;
        i < 100 &&
            player.player.state.position < const Duration(milliseconds: 300);
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        player.player.state.position,
        greaterThan(const Duration(milliseconds: 300)),
      );
      expect(player.controller!.rect.value?.width, greaterThanOrEqualTo(160));
      expect(player.controller!.rect.value?.height, greaterThanOrEqualTo(90));
      proof['playingPositionMs'] = player.player.state.position.inMilliseconds;
      proof['width'] = player.controller!.rect.value!.width;
      proof['height'] = player.controller!.rect.value!.height;
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${report.path}/video-playing.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
      await player.pause();
      expect(player.player.state.playing, false);
      await player.seek(const Duration(milliseconds: 1500));
      for (
        var i = 0;
        i < 50 &&
            (player.player.state.position.inMilliseconds - 1500).abs() > 300;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        (player.player.state.position.inMilliseconds - 1500).abs(),
        lessThanOrEqualTo(300),
      );
      await player.volume(40);
      for (var i = 0; i < 50 && player.player.state.volume != 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(player.player.state.volume, 40);
      proof['paused'] = !player.player.state.playing;
      proof['seekPositionMs'] = player.player.state.position.inMilliseconds;
      proof['volume'] = player.player.state.volume;
      completed = true;
    } finally {
      final properties = <String, String>{};
      final native = player.player.platform;
      if (native is NativePlayer) {
        for (final name in [
          'idle-active',
          'pause',
          'duration',
          'time-pos',
          'eof-reached',
          'playlist-count',
          'vo',
        ]) {
          properties[name] = await native
              .getProperty(name)
              .timeout(const Duration(seconds: 2));
        }
      }
      final result = jsonEncode({
        'runId': const String.fromEnvironment('RAFT_TEST_RUN_ID'),
        'completed': completed,
        'platform': Platform.operatingSystem,
        'durationMs': player.player.state.duration.inMilliseconds,
        'positionMs': player.player.state.position.inMilliseconds,
        'playing': player.player.state.playing,
        'native': properties,
        'logs': logs,
        'errors': errors,
        'proof': proof,
        'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
      });
      debugPrint('Native player result: $result');
      await File('${report.path}/result.json').writeAsString(result);
      final wait = Stopwatch()..start();
      while (!File('${report.path}/collected').existsSync() &&
          wait.elapsed < const Duration(seconds: 5)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await log.cancel();
      await error.cancel();
      await player.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await input.delete();
    }
  });
  testWidgets('native decoding failure remains failed after normal events', (
    tester,
  ) async {
    final report = Directory(const String.fromEnvironment('RAFT_TEST_REPORT'));
    await report.create(recursive: true);
    final input = await File('${report.path}/invalid-media.bin')
        .writeAsString('invalid generated media');
    final player = NativeAttachmentPlayer(video: false);
    AttachmentPlayback latest = const AttachmentPlayback();
    final events = player.changes.listen((value) => latest = value);
    try {
      await player.open(AttachmentSource.file(input));
      for (var i = 0; i < 50 && !latest.error; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(latest.error, true);
      await player.volume(40);
      await tester.pump(const Duration(milliseconds: 100));
      expect(latest.error, true);
    } finally {
      await events.cancel();
      await player.dispose();
      await input.delete();
    }
  });

  testWidgets('native streaming: mpv reads the URL itself and signs again after a 403', (
    tester,
  ) async {
    final bytes = previewVideo();
    var requests = 0, ranged = 0, refused = 0, sent = 0;
    var failFirst = true;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      final response = request.response;
      if (failFirst && request.uri.queryParameters['sig'] == '1') {
        failFirst = false;
        refused++;
        response.statusCode = 403;
        await response.close();
        return;
      }
      final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(request.headers.value('range') ?? '');
      var start = 0, end = bytes.length - 1;
      response.headers.set('accept-ranges', 'bytes');
      if (m != null) {
        ranged++;
        start = int.parse(m[1]!);
        if (m[2]!.isNotEmpty) end = int.parse(m[2]!).clamp(0, end);
        response.statusCode = 206;
        response.headers.set('content-range', 'bytes $start-$end/${bytes.length}');
      }
      response.contentLength = end - start + 1;
      response.add(bytes.sublist(start, end + 1));
      sent += end - start + 1;
      await response.close();
    });
    final player = NativeAttachmentPlayer();
    final boundary = GlobalKey();
    var signed = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: Center(child: SizedBox(width: 320, height: 180, child: player.video())),
            ),
          ),
        ),
      );
      Uri url(int sig) => Uri.parse('http://127.0.0.1:${server.port}/clip.webm?sig=$sig');
      final opened = player.open(
        AttachmentSource.network(
          url(1),
          refresh: () async {
            signed++;
            return url(2);
          },
        ),
      );
      for (var i = 0; i < 150 && player.player.state.duration == Duration.zero; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await opened;
      expect(refused, 1, reason: 'the first signature was refused');
      expect(signed, 1, reason: 'one fresh signature');
      expect(player.player.state.duration, greaterThan(Duration.zero));
      expect(player.playback.error, isFalse);
      await player.toggle();
      for (var i = 0; i < 100 && player.player.state.position < const Duration(milliseconds: 300); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(player.player.state.position, greaterThan(const Duration(milliseconds: 300)));
      expect(sent, greaterThan(0));
      debugPrint('Native streaming: requests=$requests ranged=$ranged refused=$refused sent=$sent of ${bytes.length}');
    } finally {
      await player.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await server.close(force: true);
    }
  });
}
