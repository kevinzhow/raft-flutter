import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _sourceWidth = 5120, _sourceHeight = 2880;

Future<Uint8List> _png(WidgetTester tester, int w, int h) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF3366CC),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

/// Serves [body] on loopback; counts the requests it answered.
class _Server {
  _Server._(this._server, this.body) {
    _server.listen((request) {
      requests++;
      request.response
        ..persistentConnection = false
        ..headers.contentType = ContentType('image', 'png')
        ..add(body);
      request.response.close();
    });
  }
  final HttpServer _server;
  final Uint8List body;
  var requests = 0;

  static Future<_Server> start(Uint8List body) async =>
      _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0), body);

  String url(String path) => 'http://127.0.0.1:${_server.port}$path';
  Future<void> close() => _server.close(force: true);
}

/// Lets the engine finish real async work (HTTP, decode) between pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

Widget _bubble(String markdown, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: RaftMessageBody(content: markdown, enableProseSelection: false),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => HttpOverrides.global = null);
  tearDown(() => PaintingBinding.instance.imageCache.clear());

  void useView(WidgetTester tester, {double dpr = 2}) {
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = Size(500 * dpr, 900 * dpr);
    addTearDown(tester.view.reset);
  }

  testWidgets('a Markdown image decodes at its bubble width, not its source', (
    tester,
  ) async {
    useView(tester);
    final png = await _png(tester, _sourceWidth, _sourceHeight);
    final server = await tester.runAsync(() => _Server.start(png));
    addTearDown(() => server!.close());
    await tester.pumpWidget(
      _bubble('Look\n\n![chart](${server!.url('/big.png')})'),
    );
    await _settle(tester);

    final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
    // 400 dp x 2 = 800 px; 64 px buckets allow up to 832.
    expect(decoded.width, lessThanOrEqualTo(832));
    expect(decoded.width, greaterThanOrEqualTo(800));
    expect(decoded.height, lessThan(500));
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.currentSizeBytes, lessThan(832 * 468 * 4 + 1024));
    // Laid out inside the bubble, aspect kept.
    final box = tester.getSize(find.byType(RawImage));
    expect(box.width, 400);
    expect(box.height, closeTo(225, 1));
  });

  testWidgets('near widths share one decoded bucket, wider bubbles re-decode', (
    tester,
  ) async {
    useView(tester);
    final png = await _png(tester, _sourceWidth, _sourceHeight);
    final server = await tester.runAsync(() => _Server.start(png));
    addTearDown(() => server!.close());
    final md = '![chart](${server!.url('/big.png')})';
    await tester.pumpWidget(_bubble(md, width: 400));
    await _settle(tester);
    final first = tester.widget<RawImage>(find.byType(RawImage)).image!;
    await tester.pumpWidget(_bubble(md, width: 410));
    await _settle(tester);
    final second = tester.widget<RawImage>(find.byType(RawImage)).image!;
    // 820 px and 800 px both round up to 832.
    expect(second.width, first.width);
    expect(PaintingBinding.instance.imageCache.liveImageCount, lessThan(3));
  });

  testWidgets('a data: Markdown image is decoded at display size too', (
    tester,
  ) async {
    useView(tester);
    final bytes = await _png(tester, _sourceWidth, _sourceHeight);
    await tester.pumpWidget(
      _bubble('![d](data:image/png;base64,${base64Encode(bytes)})'),
    );
    await _settle(tester);
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).image!.width,
      lessThanOrEqualTo(832),
    );
  });

  testWidgets('a small image is never upscaled; alt text is its label', (
    tester,
  ) async {
    useView(tester);
    final semantics = tester.ensureSemantics();
    final bytes = await _png(tester, 120, 60);
    await tester.pumpWidget(
      _bubble('![tiny logo](data:image/png;base64,${base64Encode(bytes)})'),
    );
    await _settle(tester);
    final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(decoded.width, 120);
    final labelled = find.bySemanticsLabel('tiny logo').evaluate().length;
    semantics.dispose();
    expect(labelled, 1);
  });

  testWidgets('a broken Markdown image collapses without an exception', (
    tester,
  ) async {
    useView(tester);
    final server = await tester.runAsync(
      () => _Server.start(Uint8List.fromList(utf8.encode('not an image'))),
    );
    addTearDown(() => server!.close());
    await tester.pumpWidget(_bubble('a ![x](${server!.url('/bad.png')}) b'));
    await _settle(tester);
    expect(find.byType(RawImage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('message_body never goes back to the package default image builder', () {
    // Found from the working directory (packages/raft_ui, or
    // apps/raft_flutter under tool/preflight).
    var dir = Directory.current.absolute;
    while (!File('${dir.path}/packages/raft_ui/pubspec.yaml').existsSync()) {
      if (dir.parent.path == dir.path) fail('repository root not found');
      dir = dir.parent;
    }
    final source = File(
      '${dir.path}/packages/raft_ui/lib/src/message_body.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('imageBuilder: null')));
    expect(source, contains('imageBuilder:'));
  });
}
