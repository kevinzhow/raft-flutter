// Debug/profile-only entrypoint: the production RaftApp on two long channels
// whose senders have uploaded avatars, served by an in-process loopback server
// that counts every request. It measures what a user sees when avatars are
// reused: requests per avatar URL, and how long each avatar slot shows its
// placeholder before the picture is painted.
//
//   tool/avatar-cache-smoke/run --platform android --serial <emulator> --out /tmp/x
//
// Endpoints (127.0.0.1:18795, in the app process):
//   /__stats          counters since the last reset (avatar requests per path,
//                     attachment requests, avatar slots seen / placeholder at
//                     first sight / delay until painted, placeholder frames)
//   /__reset          zero the counters
//   /__run?name=...   browse | switch | flood | resume (see _scenario)
//   /__select         load the first channel (done once at start)
//
// Every avatar slot is a `RaftAvatarContent`; a slot "shows its picture" when
// a `RawImage` with a decoded image sits below it. Nothing here changes
// product behaviour: the same file runs against an older checkout (lines
// marked NEW-ONLY are removed there by tool/avatar-cache-smoke/run).
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
import 'package:raft_flutter/data/avatar_image_store.dart'; // NEW-ONLY
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _port = 18795;
const _rows = int.fromEnvironment('AV_ROWS', defaultValue: 160);
const _users = int.fromEnvironment('AV_USERS', defaultValue: 14);
const _delayMs = int.fromEnvironment('AV_DELAY_MS', defaultValue: 80);

Future<Uint8List> _png(int w, int h, int seed, {bool circle = false}) async {
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
  for (var i = 0; i < (circle ? 12 : 40); i++) {
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

String _hex(int user) =>
    (0xa0b0c0d0e0f0 + user * 7919).toRadixString(16).padLeft(32, '0');

class _Slot {
  _Slot(this.firstSeen, this.paintedAtFirstSight);
  final DateTime firstSeen;
  final bool paintedAtFirstSight;
  DateTime? painted;
  Element? element;
  bool abandoned = false;
}

class AvatarLab {
  AvatarLab(this.avatars, this.thumbs, this.originals);
  final List<Uint8List> avatars, thumbs, originals;
  final avatarHits = <String, int>{};
  final otherHits = <String, int>{};
  final _slots = Expando<_Slot>();
  final _seen = <_Slot>[];
  var frames = 0, placeholderFrames = 0, maxPlaceholders = 0, avatarFrames = 0;
  var _lastFrame = DateTime.now();
  var longFrames = 0;
  Object? chat; // the WorkspaceController
  final log = <String>[];

  Future<void> start() async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      _port,
      shared: true,
    );
    server.listen(_serve);
    WidgetsBinding.instance.addPersistentFrameCallback(_frame);
  }

  void reset() {
    avatarHits.clear();
    otherHits.clear();
    _seen.clear();
    frames = placeholderFrames = maxPlaceholders = avatarFrames = longFrames =
        0;
  }

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
    if (path == '/__run') {
      return json(
        await _scenario(
          request.uri.queryParameters['name'] ?? 'browse',
          request.uri.queryParameters,
        ),
      );
    }
    if (path == '/__select') return json(await _select('a'));
    final avatar = RegExp(r'^/api/avatars/users/([0-9a-f]{32})\.webp$')
        .firstMatch(path);
    final match = avatar ?? RegExp(r'^/(?:t|o)/(\d+)\.png$').firstMatch(path);
    if (match == null) {
      response.statusCode = 404;
      return response.close();
    }
    (avatar != null ? avatarHits : otherHits).update(
      path,
      (v) => v + 1,
      ifAbsent: () => 1,
    );
    final Uint8List body;
    if (avatar != null) {
      final k = int.parse(avatar.group(1)!, radix: 16);
      body = avatars[((k - 0xa0b0c0d0e0f0) ~/ 7919) % avatars.length];
      response.headers.set(
        'cache-control',
        'public, max-age=31536000, immutable',
      );
    } else {
      final n = int.parse(match.group(1)!);
      body = path.startsWith('/t/')
          ? thumbs[n % thumbs.length]
          : originals[n % originals.length];
    }
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
    final delays = [
      for (final s in _seen)
        if (s.painted != null)
          s.painted!.difference(s.firstSeen).inMilliseconds,
    ]..sort();
    final neverPainted = _seen
        .where((s) => s.painted == null && !s.abandoned)
        .length;
    final abandoned = _seen
        .where((s) => s.painted == null && s.abandoned)
        .length;
    final cache = PaintingBinding.instance.imageCache;
    return {
      'avatarRequests': avatarHits.values.fold<int>(0, (a, b) => a + b),
      'avatarUrlsRequested': avatarHits.length,
      'avatarMaxPerUrl': avatarHits.values.fold<int>(0, math.max),
      'avatarPerUrl': avatarHits,
      'attachmentRequests': otherHits.values.fold<int>(0, (a, b) => a + b),
      'slotsSeen': _seen.length,
      'slotsPlaceholderAtFirstSight': _seen
          .where((s) => !s.paintedAtFirstSight)
          .length,
      'slotsNeverPainted': neverPainted,
      'slotsLeftBeforePainted': abandoned,
      'delayMsP50': delays.isEmpty ? 0 : delays[delays.length ~/ 2],
      'delayMsP95': delays.isEmpty
          ? 0
          : delays[(delays.length * 0.95).floor().clamp(0, delays.length - 1)],
      'delayMsMax': delays.isEmpty ? 0 : delays.last,
      'frames': frames,
      'framesWithAvatarSlots': avatarFrames,
      'placeholderFrames': placeholderFrames,
      'maxPlaceholdersInOneFrame': maxPlaceholders,
      'imageCacheBytes': cache.currentSizeBytes,
      'imageCacheImages': cache.currentSize,
      'imageCacheMaxBytes': cache.maximumSizeBytes,
    };
  }

  /// After every frame: each visible avatar slot either shows its picture or
  /// its placeholder/fallback.
  void _frame(Duration _) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    final now = DateTime.now();
    frames++;
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    var slots = 0, placeholders = 0;
    void visit(Element e) {
      if (e.widget is RaftAvatarContent) {
        final box = e.renderObject;
        if (box is RenderBox &&
            box.attached &&
            box.hasSize &&
            box.paintBounds.size.shortestSide > 4) {
          final rect = box.localToGlobal(Offset.zero) & box.size;
          if (rect.overlaps(screen)) {
            slots++;
            var has = false;
            void find(Element c) {
              if (has) return;
              final w = c.widget;
              if (w is RawImage && w.image != null) {
                has = true;
                return;
              }
              c.visitChildren(find);
            }

            e.visitChildren(find);
            var slot = _slots[e];
            if (slot == null) {
              slot = _slots[e] = _Slot(now, has)..element = e;
              _seen.add(slot);
            }
            if (has) {
              slot.painted ??= now;
            } else {
              placeholders++;
            }
          }
        }
        return; // do not look for nested slots
      }
      e.visitChildren(visit);
    }

    visit(root);
    // A slot that left the tree (row recycled, channel switched) before its
    // picture arrived is not a placeholder the user kept looking at.
    for (final slot in _seen) {
      if (slot.painted == null && !slot.abandoned) {
        final e = slot.element;
        if (e == null || !e.mounted) slot.abandoned = true;
      }
    }
    if (slots > 0) avatarFrames++;
    if (placeholders > 0) placeholderFrames++;
    maxPlaceholders = math.max(maxPlaceholders, placeholders);
    if (now.difference(_lastFrame) > const Duration(milliseconds: 100)) {
      longFrames++;
    }
    _lastFrame = now;
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

  Future<void> _settle([int ms = 1200]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

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

  /// browse: scroll channel a through, switch to b and scroll, back to a
  /// (twice). switch: channel a -> b -> a -> b without scrolling. flood: fill
  /// the image cache, then switch a -> b -> a. All report stats for the run.
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
        // Settings > Storage > Clear cache.
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
  installAvatarImageCache(AttachmentDiskCache.installed!); // NEW-ONLY
  final images = await LabImages.start();
  final avatars = [
    for (var i = 0; i < _users; i++)
      await _png(192, 192, 700 + i, circle: true),
  ];
  final thumbs = [for (var i = 0; i < 8; i++) await _png(320, 240, 50 + i)];
  final originals = [
    for (var i = 0; i < 4; i++) await _png(1600, 1200, 90 + i),
  ];
  final lab = AvatarLab(avatars, thumbs, originals);
  await lab.start();
  final base = 'http://127.0.0.1:$_port';

  LabChannel channel(String id, int offset) {
    final c = LabChannel(id, const []);
    for (var n = 0; n < _rows; n++) {
      final user = (n + offset) % _users;
      final row = labRow(id, 'plain', n)
        ..['senderId'] = 'u$user'
        ..['senderName'] = 'Member $user'
        ..['senderAvatarUrl'] = '/api/avatars/users/${_hex(user)}.webp';
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
            'thumbnailUrl': '$base/t/$n.png',
          },
        ];
      }
      c.rows.add(row);
    }
    return c;
  }

  final a = channel('a', 0), b = channel('b', 5);
  final adapter = LabAdapter();
  // Roster without rows for these senders: the message-carried avatar (the
  // first-paint source) is what the slot shows, as for any sender the
  // directory has not listed yet.
  adapter.patterns.add((
    (o) =>
        o.method == 'GET' &&
        o.path.startsWith('/channels/') &&
        o.path.endsWith('/members'),
    (_) => <dynamic>[],
  ));
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
        o.path.startsWith('/attachments/pic-') &&
        o.path.endsWith('/url'),
    (o) => {
      'url':
          '$base/o/${int.tryParse(o.path.split('/')[2].split('-').last) ?? 0}.png',
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
        debugPrint('avatar-cache: ready');
        return;
      }
    }
  }());
}
