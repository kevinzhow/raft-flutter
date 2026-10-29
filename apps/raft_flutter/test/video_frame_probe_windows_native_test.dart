// Real Windows libmpv, not a fake player. Opt in with VIDEO_FRAME_URL (a
// loopback Range server containing landscape.mp4, portrait.mp4, rotated.mp4
// and audio.m4a) and VIDEO_FRAME_MPV (the DLL shipped in the Windows bundle).
// The first three fixtures are 1280x720, 720x1280 and a 90-degree rotation of
// the landscape clip. No account or remote service is used.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/platform/video_frame_probe.dart';
import 'package:raft_flutter/platform/video_frame_probe_mpv.dart';

const _base = String.fromEnvironment('VIDEO_FRAME_URL');
const _library = String.fromEnvironment('VIDEO_FRAME_MPV');

void main() {
  final skip = !Platform.isWindows || _base.isEmpty || _library.isEmpty
      ? 'Requires Windows, the shipped libmpv DLL and an isolated Range fixture server.'
      : false;

  group('Windows native first-frame probe', skip: skip, () {
    final probe = MpvVideoFrameProbe();
    var next = 0;

    setUpAll(() {
      final base = Uri.parse(_base);
      expect(base.scheme, 'http');
      expect(base.host, '127.0.0.1');
      MediaKit.ensureInitialized(libmpv: _library);
      SystemProxy.instance.configure(
        const ProxySettings(mode: ProxyMode.direct),
      );
    });

    tearDownAll(() async {
      await LibmpvPlayerPool.shared.drain();
      expect(LibmpvPlayerPool.shared.alive, 0);
    });

    Future<VideoFrameInfo> run(String file, {int edge = 640}) => probe.probe(
      id: 'windows-native-${next++}',
      url: Uri.parse('$_base/$file'),
      maxEdge: edge,
      timeout: const Duration(seconds: 5),
      maxBytes: 2 * 1024 * 1024,
    );

    Future<void> picture(
      String file,
      (int, int) shown,
      (int, int) jpegSize, {
      int edge = 640,
    }) async {
      final info = await run(file, edge: edge);
      expect((info.width, info.height), shown);
      expect(info.duration, greaterThan(const Duration(seconds: 1)));
      expect(info.jpeg, isNotEmpty);
      final codec = await ui.instantiateImageCodec(info.jpeg!);
      try {
        final frame = await codec.getNextFrame();
        try {
          expect((frame.image.width, frame.image.height), jpegSize);
          expect(frame.image.width, lessThanOrEqualTo(edge));
          expect(frame.image.height, lessThanOrEqualTo(edge));
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      expect(probe.activeCount, 0);
      expect(LibmpvPlayerPool.shared.alive, LibmpvPlayerPool.shared.idleCount);
    }

    test(
      'landscape video yields a bounded JPEG with the shipped DLL',
      () async {
        await picture('landscape.mp4', (1280, 720), (640, 360));
      },
    );

    test('portrait video yields a bounded JPEG with the shipped DLL', () async {
      await picture('portrait.mp4', (720, 1280), (360, 640));
    });

    test('container rotation keeps the JPEG upright and bounded', () async {
      await picture('rotated.mp4', (720, 1280), (360, 640));
    });

    test(
      'a reused player changes shape and edge without a stale full-size frame',
      () async {
        final created = LibmpvPlayerPool.shared.created;
        await picture('landscape.mp4', (1280, 720), (200, 112), edge: 200);
        await picture('portrait.mp4', (720, 1280), (540, 960), edge: 960);
        await picture('landscape.mp4', (1280, 720), (1280, 720), edge: 2000);
        expect(LibmpvPlayerPool.shared.created, lessThanOrEqualTo(created + 1));
      },
    );

    test('audio-only input fails and releases its lease', () async {
      await expectLater(run('audio.m4a'), throwsA(isA<VideoFrameException>()));
      expect(probe.activeCount, 0);
      expect(LibmpvPlayerPool.shared.alive, LibmpvPlayerPool.shared.idleCount);
    });
  });
}
