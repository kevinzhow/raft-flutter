// HDR is read from the file's own colour boxes (never from the codec or the
// extension): PQ/HLG transfer in `colr`, or a Dolby Vision configuration.
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/mp4_hdr_probe.dart';

Uint8List box(String type, [List<int> body = const []]) {
  final size = 8 + body.length;
  return Uint8List.fromList([
    size >> 24 & 255, size >> 16 & 255, size >> 8 & 255, size & 255,
    ...type.codeUnits,
    ...body,
  ]);
}

Uint8List cat(Iterable<List<int>> parts) =>
    Uint8List.fromList([for (final p in parts) ...p]);

Uint8List colr(int primaries, int transfer, int matrix) => box('colr', [
  ...'nclx'.codeUnits,
  primaries >> 8, primaries & 255,
  transfer >> 8, transfer & 255,
  matrix >> 8, matrix & 255,
  0,
]);

/// A `moov` with one video track whose sample entry [codec] carries [children].
Uint8List moov(String codec, List<Uint8List> children) {
  final entry = box(codec, [...List.filled(78, 0), for (final c in children) ...c]);
  final stsd = box('stsd', [0, 0, 0, 0, 0, 0, 0, 1, ...entry]);
  return box('moov', box('trak', box('mdia', box('minf', box('stbl', stsd)))));
}

Uint8List mp4({required Uint8List moovBox, bool moovFirst = true, int mdat = 5000}) {
  final ftyp = box('ftyp', [...'isom'.codeUnits, 0, 0, 0, 0]);
  final data = box('mdat', List.filled(mdat, 7));
  return cat(moovFirst ? [ftyp, moovBox, data] : [ftyp, data, moovBox]);
}

void main() {
  // flutter_test answers every HttpClient with 400; these tests talk to a
  // loopback server of their own.
  setUpAll(() => HttpOverrides.global = null);
  group('colour boxes', () {
    test('BT.709 HEVC is SDR (the codec does not make it HDR)', () {
      final info = Mp4Boxes.colorOfMoov(moov('hvc1', [colr(1, 1, 1)]))!;
      expect(info.transfer, 1);
      expect(info.hdr, isFalse);
    });
    test('PQ and HLG transfer are HDR', () {
      expect(Mp4Boxes.colorOfMoov(moov('hvc1', [colr(9, 16, 9)]))!.hdr, isTrue);
      expect(Mp4Boxes.colorOfMoov(moov('hvc1', [colr(9, 18, 9)]))!.hdr, isTrue);
    });
    test('a Dolby Vision configuration is HDR whatever the base colour says', () {
      final info = Mp4Boxes.colorOfMoov(
        moov('dvh1', [colr(1, 1, 1), box('dvcC', List.filled(24, 0))]),
      )!;
      expect(info.dolbyVision, isTrue);
      expect(info.hdr, isTrue);
      expect(Mp4Boxes.colorOfMoov(moov('dvhe', [box('dvvC', List.filled(24, 0))]))!.hdr, isTrue);
    });
    test('no colour box means SDR; an audio-only moov has no verdict', () {
      expect(Mp4Boxes.colorOfMoov(moov('avc1', []))!.hdr, isFalse);
      expect(Mp4Boxes.colorOfMoov(box('moov', box('trak'))), isNull);
    });
    test('truncated or hostile boxes never throw', () {
      final good = moov('hvc1', [colr(9, 18, 9)]);
      for (var n = 0; n < good.length; n += 7) {
        Mp4Boxes.colorOfMoov(Uint8List.sublistView(good, 0, n));
      }
      final lie = Uint8List.fromList(good)..[3] = 255;
      Mp4Boxes.colorOfMoov(lie);
    });
  });

  group('ranged probe over HTTP', () {
    late HttpServer server;
    late Uint8List body;
    var requests = <String>[];
    var rangeSupported = true;
    setUp(() async {
      requests = [];
      rangeSupported = true;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final range = request.headers.value('range');
        requests.add(range ?? 'none');
        final response = request.response;
        final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range ?? '');
        if (m == null || !rangeSupported) {
          response.statusCode = 200;
          response.contentLength = body.length;
          response.add(body);
        } else {
          final start = int.parse(m[1]!);
          final end = m[2]!.isEmpty ? body.length - 1 : int.parse(m[2]!).clamp(0, body.length - 1);
          response.statusCode = 206;
          response.headers.set('content-range', 'bytes $start-$end/${body.length}');
          response.contentLength = end - start + 1;
          response.add(body.sublist(start, end + 1));
        }
        await response.close();
      });
    });
    tearDown(() => server.close(force: true));
    Uri url() => Uri.parse('http://127.0.0.1:${server.port}/clip.mp4');

    test('moov first: one request', () async {
      body = mp4(moovBox: moov('hvc1', [colr(9, 18, 9)]));
      final info = await probeMp4Color(Dio(), url());
      expect(info!.hdr, isTrue);
      expect(requests, hasLength(1));
    });

    test('moov behind a large mdat: reads the box headers, then the moov only', () async {
      body = mp4(moovBox: moov('hvc1', [colr(1, 1, 1)]), moovFirst: false, mdat: 500000);
      final info = await probeMp4Color(Dio(), url());
      expect(info!.hdr, isFalse);
      expect(info.transfer, 1);
      expect(requests.length, lessThanOrEqualTo(3));
      // Never the whole 500 kB.
      expect(requests.every((r) => r != 'none'), isTrue);
    });

    test('a server that ignores ranges gives no verdict (the caller assumes SDR)', () async {
      rangeSupported = false;
      body = mp4(moovBox: moov('hvc1', [colr(9, 18, 9)]));
      expect(await probeMp4Color(Dio(), url()), isNull);
    });

    test('something that is not an MP4 gives no verdict', () async {
      body = Uint8List.fromList(List.filled(100000, 3));
      expect(await probeMp4Color(Dio(), url()), isNull);
    });
  });

  // The sample clips of the player work (docs/media-playback.md). They are
  // large, so they are not in the repository: the checks run where the files
  // exist (the Linux development host keeps them under /tmp).
  group('sample files', () {
    Future<Mp4ColorInfo?> probe(String path) async {
      final file = File(path);
      if (!file.existsSync()) {
        markTestSkipped('$path is not on this machine');
        return null;
      }
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(request.headers.value('range') ?? '');
        final length = file.lengthSync();
        final start = int.parse(m![1]!);
        final end = m[2]!.isEmpty ? length - 1 : int.parse(m[2]!).clamp(0, length - 1);
        request.response.statusCode = 206;
        request.response.headers.set('content-range', 'bytes $start-$end/$length');
        request.response.contentLength = end - start + 1;
        await request.response.addStream(file.openRead(start, end + 1));
        await request.response.close();
      });
      try {
        return await probeMp4Color(Dio(), Uri.parse('http://127.0.0.1:${server.port}/x.mp4'));
      } finally {
        await server.close(force: true);
      }
    }

    test('Kevin\'s android.mp4 (HEVC, BT.709) is SDR', () async {
      final info = await probe('/tmp/kevin-media/android.mp4');
      if (info != null) expect(info.hdr, isFalse, reason: '$info');
    });
    test('dolby.mp4 (Dolby Vision 8.4, HLG base) is HDR', () async {
      final info = await probe('/tmp/kevin-media/dolby.mp4');
      if (info != null) expect(info.hdr, isTrue, reason: '$info');
    });
    test('720p H.264 portrait.mp4 (moov at the end) is SDR', () async {
      final info = await probe('/tmp/system-player/media/portrait.mp4');
      if (info != null) expect(info.hdr, isFalse, reason: '$info');
    });
  });
}
