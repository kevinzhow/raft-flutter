import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Avatar image path against a loopback server: request counts and whether the
/// placeholder shows in the first frame of a remount. Written to run on the
/// pre-fix code too (red) using only [RaftAvatarContent].
///
/// Loopback fixture server that counts requests per path.
class _Fixture {
  _Fixture(this.server, this.png);
  final HttpServer server;
  final Uint8List png;
  final requests = <String, int>{};
  int get total => requests.values.fold(0, (a, b) => a + b);
  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  static Future<_Fixture> start(Uint8List png) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final f = _Fixture(server, png);
    server.listen((request) {
      final path = request.uri.path;
      request.response.persistentConnection = false;
      f.requests[path] = (f.requests[path] ?? 0) + 1;
      if (path.startsWith('/missing')) {
        request.response.statusCode = 404;
      } else {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(png);
      }
      request.response.close();
    });
    return f;
  }
}

Future<Uint8List> _png(WidgetTester tester, int side) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
      Paint()..color = const Color(0xFF3366CC),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(side, side);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

class _DiskStandIn implements RaftImageByteStore {
  _DiskStandIn(this.files);
  final Map<String, Uint8List> files;
  @override
  Future<RaftStoredImage?> readEntry(String key) async {
    final bytes = files[key];
    return bytes == null
        ? null
        : RaftStoredImage(bytes, expires: DateTime(2100));
  }

  @override
  Future<void> write(
    String key,
    Uint8List bytes, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) async => files[key] = bytes;
  @override
  Future<void> touch(
    String key, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  }) async {}
}

const _placeholder = ColoredBox(key: Key('placeholder'), color: Colors.grey);

Widget _row(
  List<String> urls, {
  double size = 36,
  int generation = 0,
  bool gravatar = false,
}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: ListView(
      key: ValueKey('list-$generation'),
      children: [
        for (final url in urls)
          SizedBox.square(
            dimension: size,
            child: RaftAvatarContent(
              name: 'Ada',
              uploadedUrl: gravatar ? null : url,
              gravatarUrl: gravatar ? url : null,
              fallback: _placeholder,
            ),
          ),
      ],
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
}

/// Fills the shared decoded-image cache with [count] 4 MB bitmaps, as a few
/// screens of attachment images would.
Future<void> _flood(WidgetTester tester, int count) async {
  final images = <ui.Image>[];
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1000, 1000),
      Paint()..color = Colors.red,
    );
    final picture = recorder.endRecording();
    for (var i = 0; i < count; i++) {
      images.add(await picture.toImage(1000, 1000));
    }
    picture.dispose();
  });
  for (var i = 0; i < count; i++) {
    PaintingBinding.instance.imageCache.putIfAbsent(
      'flood-$i',
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: images[i].clone())),
      ),
    );
  }
  for (final image in images) {
    image.dispose();
  }
}

void main() {
  late _Fixture fixture;
  late Uint8List png;

  setUp(() {
    HttpOverrides.global = null;
  });
  tearDown(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await fixture.server.close(force: true);
  });

  Future<void> boot(WidgetTester tester) async {
    png = await _png(tester, 128);
    fixture = (await tester.runAsync(() => _Fixture.start(png)))!;
  }

  testWidgets(
    'one avatar shown 20 times is one request; a remount paints in the first frame',
    (tester) async {
      await boot(tester);
      final url = fixture.url('/api/avatars/users/abcdef.webp');
      await tester.pumpWidget(_row(List.filled(20, url)));
      await _settle(tester);
      expect(find.byKey(const Key('placeholder')), findsNothing);
      final first = fixture.total;
      // Switch "channel": the whole list is replaced.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_row(List.filled(20, url), generation: 1));
      final placeholdersFirstFrame = find
          .byKey(const Key('placeholder'))
          .evaluate()
          .length;
      await _settle(tester);
      debugPrint(
        'MEASURE same-url: requests initial=$first after-remount='
        '${fixture.total} placeholders-in-first-frame=$placeholdersFirstFrame',
      );
      expect(first, 1);
      expect(fixture.total, 1);
      expect(placeholdersFirstFrame, 0);
    },
  );

  testWidgets('one avatar URL at three display sizes is one request', (
    tester,
  ) async {
    await boot(tester);
    final url = fixture.url('/api/avatars/users/abcdef.webp');
    for (final size in [20.0, 36.0, 64.0]) {
      await tester.pumpWidget(_row([url], size: size));
      await _settle(tester);
    }
    debugPrint('MEASURE sizes: requests=${fixture.total} for 3 sizes');
    expect(fixture.total, 1);
  });

  testWidgets(
    'an avatar still paints in the first frame after attachments flood the image cache',
    (tester) async {
      await boot(tester);
      final url = fixture.url('/api/avatars/users/abcdef.webp');
      await tester.pumpWidget(_row([url]));
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
      await _flood(tester, 30);
      await tester.pumpWidget(_row([url], generation: 1));
      final placeholders = find
          .byKey(const Key('placeholder'))
          .evaluate()
          .length;
      await _settle(tester);
      debugPrint(
        'MEASURE flood: requests=${fixture.total} '
        'placeholders-in-first-frame=$placeholders '
        'cache=${PaintingBinding.instance.imageCache.currentSizeBytes} B',
      );
      expect(fixture.total, 1);
      expect(placeholders, 0);
    },
  );

  testWidgets('a re-signed URL for the same avatar is the same image', (
    tester,
  ) async {
    await boot(tester);
    final base = fixture.url('/api/avatars/users/abcdef.webp');
    await tester.pumpWidget(
      _row(['$base?X-Amz-Signature=aaa&X-Amz-Expires=60']),
    );
    await _settle(tester);
    // The directory refreshed and handed out a new signature: same widget,
    // new URL string. Must not blank the avatar or ask the server again.
    await tester.pumpWidget(
      _row(['$base?X-Amz-Signature=bbb&X-Amz-Expires=60']),
    );
    final placeholders = find.byKey(const Key('placeholder')).evaluate().length;
    await _settle(tester);
    // A later mount with a third signature.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _row(['$base?X-Amz-Signature=ccc&X-Amz-Expires=60'], generation: 2),
    );
    final remountPlaceholders = find
        .byKey(const Key('placeholder'))
        .evaluate()
        .length;
    await _settle(tester);
    debugPrint(
      'MEASURE signed: requests=${fixture.total} '
      'placeholders resign=$placeholders remount=$remountPlaceholders',
    );
    expect(fixture.total, 1);
    expect(placeholders, 0);
    expect(remountPlaceholders, 0);
  });

  testWidgets('after a restart the disk store serves the avatar, no request', (
    tester,
  ) async {
    await boot(tester);
    final url = fixture.url('/api/avatars/users/abcdef.webp');
    final disk = <String, Uint8List>{};
    final store = _DiskStandIn(disk);
    RaftImageBytes.instance = RaftImageBytes(store: store);
    await tester.pumpWidget(_row([url]));
    await _settle(tester);
    expect(fixture.total, 1);
    expect(disk, hasLength(1));
    // Process restart: nothing in memory, the same disk.
    await tester.pumpWidget(const SizedBox());
    RaftHotImages.instance.releaseAll();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    RaftImageBytes.instance = RaftImageBytes(store: store);
    await tester.pumpWidget(_row([url], generation: 1));
    await _settle(tester);
    debugPrint('MEASURE restart: requests=${fixture.total}');
    expect(fixture.total, 1);
    expect(find.byKey(const Key('placeholder')), findsNothing);
  });

  testWidgets(
    'after Clear cache the next mount fetches once, then is served again',
    (tester) async {
      await boot(tester);
      final url = fixture.url('/api/avatars/users/abcdef.webp');
      await tester.pumpWidget(_row([url]));
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
      expect(fixture.total, 1);
      // What the app does when Settings > Storage clears the cache.
      RaftHotImages.instance.evictAll();
      RaftImageBytes.instance
        ..clearMemory()
        ..forgetFailures();
      await tester.pumpWidget(_row([url], generation: 1));
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_row([url], generation: 2));
      final placeholders = find
          .byKey(const Key('placeholder'))
          .evaluate()
          .length;
      await _settle(tester);
      debugPrint(
        'MEASURE clear: requests=${fixture.total} remount placeholders=$placeholders',
      );
      expect(fixture.total, 2, reason: 'one refetch, then served from memory');
      expect(placeholders, 0);
    },
  );

  testWidgets('an avatar that 404s is not requested again by every mount', (
    tester,
  ) async {
    await boot(tester);
    final url = fixture.url('/missing/avatar?s=80&d=404');
    for (var i = 0; i < 4; i++) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_row([url], generation: i, gravatar: true));
      await _settle(tester);
    }
    debugPrint('MEASURE 404: requests=${fixture.total} for 4 mounts');
    expect(fixture.total, 1);
  });
}
