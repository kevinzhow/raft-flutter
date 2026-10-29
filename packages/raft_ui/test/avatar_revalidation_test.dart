import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Stale-while-revalidate for avatars whose picture can change under the same
/// URL (external avatars: `no-cache` + `ETag`): what is on screen swaps when a
/// conditional request brings other bytes, and a 304 changes nothing.

Future<Uint8List> _png(WidgetTester tester, Color color) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 16, 16), Paint()..color = color);
    final picture = recorder.endRecording();
    final image = await picture.toImage(16, 16);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

Widget _app(String url, {int rows = 1}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      children: [
        for (var i = 0; i < rows; i++)
          SizedBox.square(
            dimension: 36,
            child: RaftAvatarContent(
              name: 'Ada',
              gravatarUrl: url,
              fallback: const SizedBox(),
            ),
          ),
      ],
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<int> _pixel(WidgetTester tester, Finder image) async {
  final render = tester.renderObject<RenderImage>(image);
  final data = await tester.runAsync(() => render.image!.toByteData());
  return (data!.getUint8(0) << 16) | (data.getUint8(1) << 8) | data.getUint8(2);
}

/// Loopback stand-in for `/api/external-avatars/:id.webp`: `no-cache` plus a
/// strong ETag, 304 for a matching `If-None-Match`, error for [failWith].
class _Server {
  _Server(this.server) {
    server.listen((request) {
      final tag = request.headers.value('if-none-match');
      requests.add(tag ?? '-');
      final response = request.response..persistentConnection = false;
      if (failWith != null) {
        response.statusCode = failWith!;
      } else {
        response.headers
          ..set('cache-control', 'public, no-cache, must-revalidate')
          ..set('etag', etag);
        if (tag == etag) {
          response.statusCode = 304;
        } else {
          bodyBytes += body.length;
          response.headers.contentType = ContentType('image', 'png');
          response.add(body);
        }
      }
      response.close();
    });
  }
  final HttpServer server;
  final requests = <String>[];
  var etag = '"1"';
  var bodyBytes = 0;
  int? failWith;
  late Uint8List body;
  String url() => 'http://127.0.0.1:${server.port}/api/external-avatars/a.webp';
}

void main() {
  late Uint8List red, blue;
  late _Server server;
  var clock = DateTime(2026, 10, 14);

  setUp(() {
    HttpOverrides.global = null;
    clock = DateTime(2026, 10, 14);
  });
  tearDown(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await server.server.close(force: true);
  });

  Future<void> boot(WidgetTester tester) async {
    red = await _png(tester, const Color(0xFFFF0000));
    blue = await _png(tester, const Color(0xFF0000FF));
    server = (await tester.runAsync(
      () async =>
          _Server(await HttpServer.bind(InternetAddress.loopbackIPv4, 0)),
    ))!..body = red;
    // The default fetcher and revalidator: the Flutter client, which follows
    // HttpOverrides (the app points it at the proxy decision).
    RaftImageBytes.instance = RaftImageBytes(now: () => clock);
  }

  testWidgets('a changed picture swaps in on the avatar already on screen', (
    tester,
  ) async {
    await boot(tester);
    await tester.pumpWidget(_app(server.url()));
    await _settle(tester);
    expect(server.requests, ['-']);
    expect(await _pixel(tester, find.byType(Image)), 0xFF0000);

    server
      ..etag = '"2"'
      ..body = blue;
    clock = clock.add(const Duration(minutes: 11));
    // More rows of the same avatar mount: stale bytes first, then one check.
    await tester.pumpWidget(_app(server.url(), rows: 3));
    await _settle(tester);

    expect(server.requests, ['-', '"1"']);
    expect(server.bodyBytes, red.length + blue.length);
    final images = find.byType(Image);
    expect(images, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      expect(
        await _pixel(tester, images.at(i)),
        0x0000FF,
        reason: 'every row shows the new picture',
      );
    }
    expect(RaftImageBytes.instance.revisionOf(server.url()), 1);
  });

  testWidgets('a 304 changes nothing on screen and decodes nothing again', (
    tester,
  ) async {
    await boot(tester);
    await tester.pumpWidget(_app(server.url()));
    await _settle(tester);
    final before = tester.renderObject<RenderImage>(find.byType(Image)).image;

    clock = clock.add(const Duration(minutes: 11));
    await tester.pumpWidget(_app(server.url(), rows: 3));
    await _settle(tester);

    expect(server.requests, ['-', '"1"'], reason: 'three rows, one request');
    expect(server.bodyBytes, red.length, reason: 'the 304 has no body');
    expect(RaftImageBytes.instance.revisionOf(server.url()), 0);
    expect(
      tester.renderObject<RenderImage>(find.byType(Image).first).image,
      same(before),
    );
  });

  testWidgets('an error during revalidation leaves the picture alone', (
    tester,
  ) async {
    await boot(tester);
    await tester.pumpWidget(_app(server.url()));
    await _settle(tester);
    server.failWith = 503;
    clock = clock.add(const Duration(minutes: 11));
    await tester.pumpWidget(_app(server.url(), rows: 2));
    await _settle(tester);
    expect(server.requests, ['-', '"1"']);
    expect(await _pixel(tester, find.byType(Image).first), 0xFF0000);
    expect(find.byType(Image), findsNWidgets(2));
    // No failure memory for a picture that is on screen.
    expect(await RaftImageBytes.instance.load(server.url()), red);
  });

  // The leak check of the last test of a file runs before its tree and image
  // cache are torn down, so the last test holds no picture (the same reason
  // avatar_image_cache_test.dart ends with its 404 test).
  testWidgets('with nothing stored, a 404 is an error and is remembered', (
    tester,
  ) async {
    await boot(tester);
    server.failWith = 404;
    final service = RaftImageBytes(now: () => clock);
    for (var i = 0; i < 3; i++) {
      final error = await tester.runAsync<Object?>(() async {
        try {
          await service.load(server.url());
          return null;
        } on RaftImageHttpError catch (e) {
          return e;
        }
      });
      expect(error, isA<RaftImageHttpError>());
    }
    expect(server.requests, hasLength(1));
    expect(service.revalidationCount, 0);
  });
}
