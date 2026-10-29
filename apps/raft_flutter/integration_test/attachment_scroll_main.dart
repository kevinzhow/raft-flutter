// Debug/profile-only entrypoint: the production RaftApp on a channel of many
// image messages (half with a server `thumbnailUrl`, half without), a loopback
// storage server that counts every request per path, and a fake API that counts
// every signed-URL request (`GET /attachments/<id>/url`, `POST
// /attachments/urls`). It proves on a device that
//
//   * scrolling images that have a thumbnail makes no signed-URL request,
//   * a signed URL is requested only for images without a thumbnail (visible
//     tiles, batched) and for an explicit open,
//   * list tiles never show "Connecting…", and
//   * after a fast fling through the whole channel every visible tile shows its
//     image within a few seconds (no tile stays on the placeholder).
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/attachment_scroll_main.dart
//   adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk
//   adb -s <emulator> forward tcp:18792 tcp:18792 && curl localhost:18792/__stats
//   curl localhost:18792/__probe        # what the screen shows right now
//   curl localhost:18792/__fling        # one fast sweep through the channel
//   curl localhost:18792/__reset        # zero the counters
//   curl 'localhost:18792/__config?delay=1500&api=600'   # storage / signing latency (ms)
//   curl localhost:18792/__select       # load the channel's messages (done once at start)
//
// Linux: `tool/flutter build linux --profile -t ...` and run the bundle; the
// same server listens on 127.0.0.1:18792. `--dart-define` knobs:
//   SC_ROWS (120), SC_DELAY_MS (120: storage latency per response),
//   SC_AUTO (0|1: run the fling check once, 4 s after start),
//   SC_THUMBS_ON_API (0|1: serve thumbnails under /api/attachments/<id>/thumbnail
//   like server-streamed storage; counted by the same per-path stats).
//
// Every request is logged as `attach-scroll: ...` (`adb logcat -s flutter`).
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
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _port = 18792;
const _rows = int.fromEnvironment('SC_ROWS', defaultValue: 120);
const _delayDefault = int.fromEnvironment('SC_DELAY_MS', defaultValue: 120);
var _delayMs = _delayDefault;
var _apiDelayMs = 80;
const _auto = int.fromEnvironment('SC_AUTO', defaultValue: 0);
const _thumbsOnApi = int.fromEnvironment('SC_THUMBS_ON_API', defaultValue: 0);

Future<Uint8List> _png(int w, int h, int seed) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final random = math.Random(seed);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()
      ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(w.toDouble(), h.toDouble()), [
        ui.Color(0xff000000 | random.nextInt(0xffffff)),
        ui.Color(0xff000000 | random.nextInt(0xffffff)),
      ]),
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

class ScrollLab {
  ScrollLab(this.thumbs, this.originals, this.apiCounts);
  final List<Uint8List> thumbs, originals;
  final Map<String, int> apiCounts;
  final hits = <String, int>{};
  Map<String, dynamic> lastProbe = {};
  Future<Map<String, dynamic>> Function()? fling;
  Map<String, dynamic> Function()? debug;
  Future<Map<String, dynamic>> Function()? select;

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port, shared: true);
    server.listen(_serve);
  }

  Future<void> _serve(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;
    Future<void> json(Object body) async {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
      await response.close();
    }

    if (path == '/__stats') {
      final thumbRequests = hits.entries.where((e) => e.key.startsWith('/t/') || e.key.endsWith('/thumbnail')).fold<int>(0, (a, e) => a + e.value);
      final originalRequests = hits.entries.where((e) => e.key.startsWith('/o/')).fold<int>(0, (a, e) => a + e.value);
      final urlRequests = (apiCounts['GET url'] ?? 0) + (apiCounts['POST urls'] ?? 0);
      return json({
        'thumbnailRequests': thumbRequests,
        'originalRequests': originalRequests,
        'signedUrlRequests': urlRequests,
        'api': apiCounts,
        'debug': debug?.call(),
        'perPathMax': hits.values.isEmpty ? 0 : hits.values.reduce(math.max),
      });
    }
    if (path == '/__reset') {
      hits.clear();
      apiCounts.clear();
      debugPrint('attach-scroll: counters reset');
      return json({'ok': true});
    }
    if (path == '/__config') {
      _delayMs = int.tryParse(request.uri.queryParameters['delay'] ?? '') ?? _delayMs;
      _apiDelayMs = int.tryParse(request.uri.queryParameters['api'] ?? '') ?? _apiDelayMs;
      return json({'storageDelayMs': _delayMs, 'apiDelayMs': _apiDelayMs});
    }
    if (path == '/__probe') return json(probe());
    if (path == '/__select') return json(await (select?.call() ?? Future.value({'error': 'not ready'})));
    if (path == '/__fling') {
      final result = await (fling?.call() ?? Future.value({'error': 'not ready'}));
      return json(result);
    }
    final match = RegExp(r'^/(?:t|o)/(\d+)\.png$').firstMatch(path) ??
        RegExp(r'^/api/attachments/[^/]+/thumbnail$').firstMatch(path);
    if (match == null) {
      response.statusCode = 404;
      await response.close();
      return;
    }
    final isThumb = path.startsWith('/t/') || path.endsWith('/thumbnail');
    final n = match.groupCount > 0 ? int.tryParse(match.group(1) ?? '') ?? 0 : request.uri.path.hashCode.abs();
    final body = isThumb ? thumbs[n % thumbs.length] : originals[n % originals.length];
    hits[path] = (hits[path] ?? 0) + 1;
    debugPrint('attach-scroll: storage GET $path');
    if (_delayMs > 0) await Future<void>.delayed(Duration(milliseconds: _delayMs));
    try {
      response.headers.contentType = ContentType('image', 'png');
      response.headers.contentLength = body.length;
      response.add(body);
      await response.close();
    } catch (_) {
      // The client gave up (a tile scrolled away): not an error.
    }
  }

  /// What the screen shows: every image card whose box intersects the window.
  Map<String, dynamic> probe() {
    var visible = 0, withImage = 0, pending = 0, failed = 0, connecting = 0, other = 0;
    final root = WidgetsBinding.instance.rootElement;
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    void visit(Element e) {
      final widget = e.widget;
      if (widget is Text && widget.data == 'Connecting…') connecting++;
      if (widget is RaftAttachmentCard && widget.imageExtent != null) {
        final box = e.renderObject;
        if (box is RenderBox && box.attached && box.hasSize) {
          final rect = box.localToGlobal(Offset.zero) & box.size;
          final shown = rect.intersect(screen);
          if (!shown.isEmpty && shown.height > rect.height * 0.25) {
            visible++;
            if (widget.preview != null) {
              withImage++;
            } else if (widget.error != null) {
              failed++;
            } else if (widget.previewPending) {
              pending++;
            } else {
              other++;
            }
          }
        }
      }
      e.visitChildren(visit);
    }

    if (root != null) visit(root);
    return lastProbe = {
      'visibleImageTiles': visible,
      'withImage': withImage,
      'placeholder': pending,
      'failed': failed,
      'other': other,
      'connectingTextCount': connecting,
    };
  }
}

Object? chatController;

ScrollPosition? _chatPosition() {
  ScrollPosition? best;
  void visit(Element e) {
    if (e is StatefulElement && e.state is ScrollableState) {
      final position = (e.state as ScrollableState).position;
      if (position.axis == Axis.vertical &&
          position.hasContentDimensions &&
          (best == null || position.maxScrollExtent > best!.maxScrollExtent)) {
        best = position;
      }
    }
    e.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return best;
}

/// One fast sweep from the newest message to the oldest and back: the position
/// moves by about 14 000 px per second in 50 ms steps (a hard fling), then
/// rests. Afterwards the probe is polled until every visible tile shows its
/// image or 20 s pass.
Future<Map<String, dynamic>> _flingAndCheck(ScrollLab lab) async {
  final position = _chatPosition();
  if (position == null) return {'error': 'no scrollable'};
  debugPrint('attach-scroll: scrollable extent ${position.minScrollExtent}..${position.maxScrollExtent} pixels ${position.pixels} viewport ${position.viewportDimension}');
  final started = DateTime.now();
  Future<void> sweep(double to) async {
    const step = Duration(milliseconds: 50);
    const perStep = 700.0;
    while ((position.pixels - to).abs() > perStep) {
      position.jumpTo(position.pixels + (to > position.pixels ? perStep : -perStep));
      await Future<void>.delayed(step);
    }
    position.jumpTo(to);
  }

  await sweep(position.minScrollExtent);
  await sweep(position.maxScrollExtent);
  await sweep(position.minScrollExtent + (position.maxScrollExtent - position.minScrollExtent) * 0.5);
  final restedAt = DateTime.now();
  Map<String, dynamic> last = lab.probe();
  Duration? settled;
  while (DateTime.now().difference(restedAt) < const Duration(seconds: 20)) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    last = lab.probe();
    if ((last['visibleImageTiles'] as int) > 0 && last['withImage'] == last['visibleImageTiles']) {
      settled = DateTime.now().difference(restedAt);
      break;
    }
  }
  final result = {
    'sweepMs': restedAt.difference(started).inMilliseconds,
    'settledMs': settled?.inMilliseconds,
    'allVisibleShowImage': settled != null,
    'final': last,
  };
  debugPrint('attach-scroll: fling result ${jsonEncode(result)}');
  return result;
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  AttachmentDiskCache.installed ??= AttachmentDiskCache(getApplicationCacheDirectory);
  unawaited(AttachmentDiskCache.installed!.warm());
  final images = await LabImages.start();
  final thumbs = [for (var i = 0; i < 8; i++) await _png(320, 240, 50 + i)];
  final originals = [for (var i = 0; i < 4; i++) await _png(1600, 1200, 90 + i)];
  final apiCounts = <String, int>{};
  final lab = ScrollLab(thumbs, originals, apiCounts);
  await lab.start();

  final channel = LabChannel('sc', const []);
  String base() => 'http://127.0.0.1:$_port';
  for (var n = 0; n < _rows; n++) {
    final id = 'pic-$n';
    final thumbed = n.isEven;
    channel.rows.add(
      labRow('sc', 'plain', n)
        ..['content'] = thumbed ? 'Photo $n with a thumbnail' : 'Photo $n without a thumbnail'
        ..['attachments'] = [
          {
            'id': id,
            'channelId': 'sc',
            'filename': 'IMG_$n.png',
            'mimeType': 'image/png',
            'width': 1600,
            'height': 1200,
            'sizeBytes': originals[n % originals.length].length,
            if (thumbed)
              'thumbnailUrl': _thumbsOnApi == 1
                  ? '${base()}/api/attachments/$id/thumbnail?n=$n'
                  : '${base()}/t/$n.png',
          },
        ],
    );
  }
  final (seed, api, client) = await labWorkspace([channel], images, mobile: true, ownsClient: false);
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
  api.routes['GET /channels/sc'] = (_) => channel.record.json;
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/saved'] = (_) => {'globalTotal': 0, 'saved': <dynamic>[]};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': <dynamic>[]};
  api.routes['GET /announcements/active'] = (_) => {'announcements': <dynamic>[]};
  api.routes['GET /product-feedback/tickets'] = (_) => {'unread_total': 0, 'tickets': <dynamic>[]};
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  api.routes['GET /messages/attachment-preview/enabled'] = (_) => {'enabled': true};
  void count(String key, [int by = 1]) {
    apiCounts[key] = (apiCounts[key] ?? 0) + by;
    debugPrint('attach-scroll: api $key (total ${apiCounts[key]})');
  }

  int originalIndex(String id) => int.tryParse(id.split('-').last) ?? 0;
  api.patterns.insert(0, (
    (o) => o.method == 'GET' && o.path.startsWith('/attachments/pic-') && o.path.endsWith('/url'),
    (o) async {
      count('GET url');
      if (originalIndex(o.path.split('/')[2]).isEven) count('GET url of thumbnailed image');
      await Future<void>.delayed(Duration(milliseconds: _apiDelayMs));
      return {'url': '${base()}/o/${originalIndex(o.path.split('/')[2])}.png'};
    },
  ));
  api.routes['POST /attachments/urls'] = (o) async {
    final ids = ((o.data as Map)['attachmentIds'] as List).cast<String>();
    count('POST urls');
    await Future<void>.delayed(Duration(milliseconds: _apiDelayMs));
    count('POST urls ids', ids.length);
    // Images with a thumbnail are the even ones: signing them is speculative.
    count('POST urls ids of thumbnailed images', ids.where((id) => originalIndex(id).isEven).length);
    return {
      'urls': [
        for (final id in ids) {'id': id, 'url': '${base()}/o/${originalIndex(id)}.png', 'expiresAt': null},
      ],
    };
  };

  lab.fling = () => _flingAndCheck(lab);
  lab.select = () async {
    final c = chatController as dynamic;
    if (c == null) return {'error': 'no controller'};
    await c.selectChannel(c.channel);
    return {'messages': c.messageDomain.messages.length};
  };
  lab.debug = () {
    Object? info;
    void visit(Element e) {
      if (info != null) return;
      if (e.widget.runtimeType.toString() == 'RaftChatView') {
        final c = (e.widget as dynamic).controller;
        info = {
          'channel': c.channel?.id,
          'channelLoading': c.messageDomain.state.channelLoading,
          'error': c.error,
          'messages': c.messageDomain.messages.length,
          'section': c.section,
          'canView': c.can('viewChannel', resource: c.channel),
          'role': c.server?.json['role'],
          'loading': c.loading,
          'channelJson': c.channel?.json,
        };
        chatController = c;
        return;
      }
      e.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);
    return {'hits': api.hits.keys.where((k) => k.contains('messages')).toList(), 'misses': api.misses, 'chat': info};
  };
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {MobileTabs.home, MobileTabs.tasks, MobileTabs.members, MobileTabs.computers},
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
      initialLocation: Uri(path: '/s/lab/channel/sc'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      // No workspace cache: the messages always come from the (fake) network.
      openWorkspaceCache: () async => null,
    ),
  );
  // The production route lands on the (empty) channel; load its messages the
  // way a tap on the channel row does.
  unawaited(() async {
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      lab.debug?.call();
      if (chatController != null) {
        await lab.select?.call();
        return;
      }
    }
  }());
  if (_auto == 1) {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 8), () async {
        apiCounts.clear();
        lab.hits.clear();
        final result = await _flingAndCheck(lab);
        debugPrint('attach-scroll: auto done ${jsonEncode(result)} stats api=${jsonEncode(apiCounts)}');
      }),
    );
  }
}
