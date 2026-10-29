// Debug/profile-only entrypoint: the production RaftApp on perf-lab fixtures
// with a deliberately slow loopback file server, to watch attachment loading
// progress (bottom-edge bar and size chip) on a device. No login. Never built
// into the release app.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/attachment_progress_main.dart
//   adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # only the .linkperf package
//
// The channel `ap` holds: (1) a photo with a 320px thumbnail whose 3.4 MB
// original trickles in, (2) a photo without thumbnail that waits 5 s for its
// first byte, (3) a photo whose download fails, (4) a PDF that downloads
// slowly when previewed. `adb logcat -s flutter:*` prints `attach-progress`
// lines for every request, including client disconnects (cancelled downloads).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/app_services.dart';
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

/// Serves `/slow/<name>?size=<bytes>&rate=<bytes per second>&delay=<ms>`:
/// a valid PNG (or any bytes) padded to `size`, written at `rate` after
/// `delay`. `/fail` answers 500. `/fast` answers at once.
class SlowFiles {
  SlowFiles._(this.server, this.png);
  final HttpServer server;
  final Uint8List png;

  static Future<SlowFiles> start(Uint8List png) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final files = SlowFiles._(server, png);
    server.listen(files._serve);
    return files;
  }

  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  Future<void> _serve(HttpRequest request) async {
    final started = DateTime.now();
    final path = request.uri.path;
    void log(String text) => debugPrint(
      'attach-progress: $path $text (+${DateTime.now().difference(started).inMilliseconds} ms)',
    );
    final response = request.response;
    if (path.startsWith('/fail')) {
      response.statusCode = 500;
      await response.close();
      log('failed with 500');
      return;
    }
    if (path.startsWith('/fast')) {
      response.headers.contentType = ContentType('image', 'png');
      response.contentLength = png.length;
      response.add(png);
      await response.close();
      log('served ${png.length} bytes at once');
      return;
    }
    final size = int.parse(request.uri.queryParameters['size'] ?? '3565158');
    final rate = int.parse(request.uri.queryParameters['rate'] ?? '160000');
    final delay = int.parse(request.uri.queryParameters['delay'] ?? '0');
    log('request (size=$size rate=$rate/s delay=${delay}ms)');
    response.headers.contentType = ContentType.binary;
    response.contentLength = size;
    var sent = 0;
    var gone = false;
    // A cancelled download closes the socket; `done` then completes with an error.
    response.done.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (sent < size) {
        gone = true;
        log(
          'connection closed by the client after $sent / $size bytes (cancelled)',
        );
      }
    });
    try {
      if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
      final head = path.contains('pdf') ? Uint8List(0) : png;
      final step = (rate * .05).round();
      while (sent < size && !gone) {
        final end = (sent + step).clamp(0, size);
        final chunk = Uint8List(end - sent);
        for (var i = 0; i < chunk.length && sent + i < head.length; i++) {
          chunk[i] = head[sent + i];
        }
        response.add(chunk);
        await response.flush();
        sent = end;
        if (sent % (step * 20) < step) log('sent $sent / $size');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!gone) {
        await response.close();
        log('finished $size bytes');
      }
    } catch (error) {
      log('client went away after $sent / $size bytes (cancelled)');
    }
  }
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final images = await LabImages.start();
  final files = await SlowFiles.start(images.pngs.first.$3);

  Map<String, dynamic> row(
    int n,
    String text,
    List<Map<String, dynamic>> attachments,
  ) => labRow('ap', 'plain', n)
    ..['content'] = text
    ..['attachments'] = attachments;
  Map<String, dynamic> image(String id, {String? thumb}) => {
    'id': id,
    'channelId': 'ap',
    'filename': 'IMG_$id.jpg',
    'mimeType': 'image/jpeg',
    'width': 1600,
    'height': 1200,
    'sizeBytes': 3565158,
    'thumbnailUrl': ?thumb,
  };
  final channel = LabChannel('ap', const []);
  channel.rows.addAll([
    row(0, 'Photo with a thumbnail', [
      image('ap-thumb', thumb: files.url('/fast/thumb.png')),
    ]),
    row(1, 'Photo without a thumbnail, 5 s to the first byte', [
      image('ap-nothumb'),
    ]),
    row(2, 'Photo whose download fails', [image('ap-fail')]),
    row(3, 'Quarterly report', [
      {
        'id': 'ap-pdf',
        'channelId': 'ap',
        'filename': '2026Q3-report.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': 2936012,
      },
    ]),
  ]);
  final (seed, api, client) = await labWorkspace(
    [channel],
    images,
    mobile: true,
    ownsClient: false,
  );
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': 'zh',
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/ap'] = (_) => channel.record.json;
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
  // Slow originals: 3.4 MB at 160 KB/s (about 22 s); the second waits 5 s.
  const originals = {
    'ap-thumb': '/slow/thumb?size=3565158&rate=160000',
    'ap-nothumb': '/slow/nothumb?size=3565158&rate=160000&delay=5000',
    'ap-fail': '/fail/photo',
    'ap-pdf': '/slow/pdf?size=2936012&rate=100000&delay=1500',
  };
  api.patterns.insert(0, (
    (o) =>
        o.method == 'GET' &&
        o.path.startsWith('/attachments/ap-') &&
        o.path.endsWith('/url'),
    (o) => {'url': files.url(originals[o.path.split('/')[2]]!)},
  ));
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
    'raft.light': const String.fromEnvironment(
      'AP_THEME',
      defaultValue: 'brutal',
    ),
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  Timer.periodic(const Duration(seconds: 3), (_) {
    debugPrint('attach-progress: api hits=${api.hits} misses=${api.misses}');
  });
  final dir = await Directory.systemTemp.createTemp('raft-attach-progress-');
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab/channel/ap'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
}
