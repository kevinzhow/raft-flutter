// Debug/profile-only entrypoint: the production RaftApp on two channels of
// video cards (server poster `thumbnailUrl`) and image messages (server
// thumbnail), served by an in-process loopback server that counts every
// request by kind. It measures what the cache saves: poster / thumbnail /
// original requests across channel switches, an ImageCache flood and cold
// starts. Video bytes are never requested (the clips are over the auto-load
// size), so only the poster path is exercised here.
//
//   tool/poster-cache-smoke/run --serial <emulator> --apk <app-profile.apk> --label new --out <dir>
//
// Endpoints (127.0.0.1:18841, in the app process):
//   /__stats          request counters by kind since the last reset
//   /__reset          zero the counters
//   /__run?name=...   browse | switch | flood | clearcache | settle
//   /__strip?on=1     next start serves the same messages WITHOUT thumbnailUrl
//                     (what a message restored without it looks like)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/attachment_disk_cache.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _port = 18841;
const _rows = int.fromEnvironment('PC_ROWS', defaultValue: 120);
const _delayMs = int.fromEnvironment('PC_DELAY_MS', defaultValue: 60);

Future<Uint8List> _png(int w, int h, int seed) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final random = math.Random(seed);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(w.toDouble(), h.toDouble()),
        [
          ui.Color(0xff000000 | random.nextInt(0xffffff)),
          ui.Color(0xff000000 | random.nextInt(0xffffff)),
        ],
      ),
  );
  for (var i = 0; i < 40; i++) {
    canvas.drawCircle(
      ui.Offset(random.nextDouble() * w, random.nextDouble() * h),
      4 + random.nextDouble() * h / 6,
      ui.Paint()..color = ui.Color((0x70 << 24) | random.nextInt(0xffffff)),
    );
  }
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

class PosterLab {
  PosterLab(this.posters, this.thumbs, this.originals, this.strip);
  final List<Uint8List> posters, thumbs, originals;
  final bool strip;
  final hits = <String, int>{};
  Object? chat; // the WorkspaceController

  Future<void> start() async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      _port,
      shared: true,
    );
    server.listen(_serve);
  }

  void reset() => hits.clear();

  static String _kind(String path) => switch (path.split('/')[1]) {
    'p' => 'poster',
    't' => 'thumbnail',
    'o' => 'original',
    'v' => 'video',
    _ => 'other',
  };

  Future<void> _serve(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;
    Future<void> json(Object body) async {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
      await response.close();
    }

    if (path == '/__stats') return json(stats());
    if (path == '/__reset') {
      reset();
      return json({'ok': true});
    }
    if (path == '/__strip') {
      final marker = File('${(await getApplicationSupportDirectory()).path}/strip');
      request.uri.queryParameters['on'] == '1'
          ? marker.writeAsStringSync('1')
          : (marker.existsSync() ? marker.deleteSync() : null);
      return json({'strip': marker.existsSync()});
    }
    if (path == '/__run') {
      return json(
        await _scenario(
          request.uri.queryParameters['name'] ?? 'browse',
          request.uri.queryParameters,
        ),
      );
    }
    if (path == '/__select') return json(await _select('a'));
    final match = RegExp(r'^/(p|t|o)/(\d+)\.png$').firstMatch(path);
    hits.update(path, (v) => v + 1, ifAbsent: () => 1);
    if (match == null) {
      response.statusCode = 404;
      return response.close();
    }
    final n = int.parse(match.group(2)!);
    final body = switch (match.group(1)) {
      'p' => posters[n % posters.length],
      't' => thumbs[n % thumbs.length],
      _ => originals[n % originals.length],
    };
    if (_delayMs > 0) {
      await Future<void>.delayed(const Duration(milliseconds: _delayMs));
    }
    try {
      response.headers.contentType = ContentType('image', 'png');
      response.headers.contentLength = body.length;
      response.add(body);
      await response.close();
    } catch (_) {}
  }

  Map<String, dynamic> stats() {
    final byKind = <String, int>{};
    final urls = <String, Set<String>>{};
    final maxPerUrl = <String, int>{};
    hits.forEach((path, count) {
      final kind = _kind(path);
      byKind.update(kind, (v) => v + count, ifAbsent: () => count);
      (urls[kind] ??= {}).add(path);
      maxPerUrl.update(kind, (v) => math.max(v, count), ifAbsent: () => count);
    });
    final cache = PaintingBinding.instance.imageCache;
    return {
      'requests': byKind,
      'urls': {for (final e in urls.entries) e.key: e.value.length},
      'maxPerUrl': maxPerUrl,
      'strip': strip,
      'imageCacheBytes': cache.currentSizeBytes,
      'imageCacheImages': cache.currentSize,
    };
  }

  // -- driving the product ---------------------------------------------------

  dynamic get _c => chat;

  Future<Map<String, dynamic>> _select(String id) async {
    final c = _c;
    if (c == null) return {'error': 'no controller'};
    final channel = (c.channels as List).firstWhere((x) => x.id == id);
    await c.selectChannel(channel);
    return {'channel': id, 'messages': c.messageDomain.messages.length};
  }

  ScrollPosition? _position() {
    ScrollPosition? best;
    void visit(Element e) {
      if (e is StatefulElement && e.state is ScrollableState) {
        final p = (e.state as ScrollableState).position;
        if (p.axis == Axis.vertical &&
            p.hasContentDimensions &&
            (best == null || p.maxScrollExtent > best!.maxScrollExtent)) {
          best = p;
        }
      }
      e.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);
    return best;
  }

  Future<void> _sweep(double to, {double perStep = 420}) async {
    final p = _position();
    if (p == null) return;
    while ((p.pixels - to).abs() > perStep) {
      p.jumpTo(p.pixels + (to > p.pixels ? perStep : -perStep));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    p.jumpTo(to);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _scrollThrough() async {
    final p = _position();
    if (p == null) return;
    await _sweep(p.minScrollExtent);
    await _sweep(p.maxScrollExtent);
  }

  /// Decoded bitmaps pushed into the shared ImageCache, as opening a few
  /// image-heavy messages in the viewer does (each ~4 MB, 40 of them).
  Future<int> _flood(int count) async {
    final cache = PaintingBinding.instance.imageCache;
    for (var i = 0; i < count; i++) {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 1024, 1024),
        ui.Paint()..color = Color(0xff000000 | (i * 977) % 0xffffff),
      );
      final image = await recorder.endRecording().toImage(1024, 1024);
      cache.putIfAbsent(
        'flood-$i',
        () =>
            OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
      );
    }
    return cache.currentSizeBytes;
  }

  Future<void> _settle([int ms = 1200]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<Map<String, dynamic>> _scenario(
    String name,
    Map<String, String> q,
  ) async {
    reset();
    final watch = Stopwatch()..start();
    Object? extra;
    switch (name) {
      case 'browse':
        for (var round = 0; round < 2; round++) {
          await _select('a');
          await _settle();
          await _scrollThrough();
          await _select('b');
          await _settle();
          await _scrollThrough();
        }
        await _select('a');
        await _settle();
      case 'switch':
        for (final id in ['a', 'b', 'a', 'b', 'a']) {
          await _select(id);
          await _settle(900);
        }
      case 'flood':
        extra = {
          'imageCacheBytesAfterFlood': await _flood(int.parse(q['n'] ?? '40')),
        };
        for (final id in ['b', 'a', 'b', 'a']) {
          await _select(id);
          await _settle(900);
        }
      case 'clearcache':
        extra = {
          'sizeBefore': await AttachmentDiskCache.installed!.sizeBytes(),
        };
        await AttachmentDiskCache.installed!.clear();
        extra = {
          ...(extra as Map<String, Object?>),
          'sizeAfter': await AttachmentDiskCache.installed!.sizeBytes(),
        };
        for (final id in ['b', 'a', 'b', 'a']) {
          await _select(id);
          await _settle(900);
        }
      case 'sizes':
        extra = {'diskBytes': await AttachmentDiskCache.installed!.sizeBytes()};
      case 'settle':
        await _settle(int.parse(q['ms'] ?? '3000'));
      default:
        return {'error': 'unknown scenario $name'};
    }
    return {
      'scenario': name,
      'ms': watch.elapsedMilliseconds,
      ...stats(),
      'extra': ?extra,
    };
  }
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  AttachmentDiskCache.installed ??= AttachmentDiskCache(
    getApplicationCacheDirectory,
  );
  unawaited(AttachmentDiskCache.installed!.warm());
  final strip = File(
    '${(await getApplicationSupportDirectory()).path}/strip',
  ).existsSync();
  final images = await LabImages.start();
  final posters = [for (var i = 0; i < 6; i++) await _png(320, 180, 20 + i)];
  final thumbs = [for (var i = 0; i < 8; i++) await _png(320, 240, 50 + i)];
  final originals = [
    for (var i = 0; i < 4; i++) await _png(1600, 1200, 90 + i),
  ];
  final lab = PosterLab(posters, thumbs, originals, strip);
  await lab.start();
  final base = 'http://127.0.0.1:$_port';

  // Every attachment has its own URLs, like a real server's.
  LabChannel channel(String id, int offset) {
    final c = LabChannel(id, const []);
    for (var n = 0; n < _rows; n++) {
      final row = labRow(id, 'plain', n);
      if (n % 4 == 3) {
        row['content'] = 'Photo $n';
        row['attachments'] = [
          {
            'id': 'pic-$id-$n',
            'channelId': id,
            'filename': 'IMG_$n.png',
            'mimeType': 'image/png',
            'width': 1600,
            'height': 1200,
            'sizeBytes': originals[n % originals.length].length,
            if (!strip) 'thumbnailUrl': '$base/t/${n + offset}.png',
          },
        ];
      } else if (n % 4 == 1) {
        row['content'] = 'Clip $n';
        row['attachments'] = [
          {
            'id': 'vid-$id-$n',
            'channelId': id,
            'filename': 'clip_$n.mp4',
            'mimeType': 'video/mp4',
            // Over the auto-load size: the card idles on its poster.
            'sizeBytes': 60 * 1024 * 1024,
            if (!strip) 'thumbnailUrl': '$base/p/${n + offset}.png',
          },
        ];
      }
      c.rows.add(row);
    }
    return c;
  }

  final a = channel('a', 0), b = channel('b', 1000);
  final adapter = LabAdapter();
  final (seed, api, client) = await labWorkspace(
    [a, b],
    images,
    mobile: true,
    ownsClient: false,
    origin: base,
    adapter: adapter,
  );
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': 'en',
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/a'] = (_) => a.record.json;
  api.routes['GET /channels/b'] = (_) => b.record.json;
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/saved'] = (_) => {
    'globalTotal': 0,
    'saved': <dynamic>[],
  };
  api.routes['GET /channels/threads/followed'] = (_) => {
    'threads': <dynamic>[],
  };
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  api.routes['GET /messages/attachment-preview/enabled'] = (_) => {
    'enabled': true,
  };
  api.patterns.insert(0, (
    (o) =>
        o.method == 'GET' &&
        (o.path.startsWith('/attachments/pic-') ||
            o.path.startsWith('/attachments/vid-')) &&
        o.path.endsWith('/url'),
    (o) {
      final id = o.path.split('/')[2];
      final n = int.tryParse(id.split('-').last) ?? 0;
      return {'url': '$base/${id.startsWith('vid-') ? 'v' : 'o'}/$n.png'};
    },
  ));
  api.routes['POST /attachments/urls'] = (o) => {
    'urls': [
      for (final id
          in ((o.data as Map)['attachmentIds'] as List).cast<String>())
        {
          'id': id,
          'url': '$base/o/${int.tryParse(id.split('-').last) ?? 0}.png',
          'expiresAt': null,
        },
    ],
  };
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {
      MobileTabs.home,
      MobileTabs.tasks,
      MobileTabs.members,
      MobileTabs.computers,
    },
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': 'elegant',
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab/channel/a'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async => null,
    ),
  );
  unawaited(() async {
    for (var i = 0; i < 150; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      void visit(Element e) {
        if (lab.chat != null) return;
        if (e.widget.runtimeType.toString() == 'RaftChatView') {
          lab.chat = (e.widget as dynamic).controller;
          return;
        }
        e.visitChildren(visit);
      }

      final root = WidgetsBinding.instance.rootElement;
      if (root != null) visit(root);
      if (lab.chat != null) {
        await lab._select('a');
        debugPrint('poster-cache: ready');
        return;
      }
    }
  }());
}
