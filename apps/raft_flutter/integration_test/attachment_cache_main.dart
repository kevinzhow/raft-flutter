// Debug/profile-only entrypoint: the production RaftApp (with the real
// on-disk attachment cache installed, like main()) on perf-lab fixtures, with
// a loopback storage server that counts every request per path, to prove on a
// device that a second open of an attachment makes no request.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/attachment_cache_main.dart
//   adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # only the .linkperf package
//   adb -s <emulator> forward tcp:18791 tcp:18791 && curl localhost:18791/__stats
//
// Linux: build with `tool/flutter build linux --profile -t ...` and run the
// bundle; the same server listens on 127.0.0.1:18791.
//
// Channel `ac`: a photo with a thumbnail, a photo without one, a PDF, a
// text document and a message with three photos (the image viewer gallery). The storage server (port 18791) counts requests and bytes
// per path (`/__stats`, `/__reset`); the fake API counts signed-URL and
// document-preview requests. Every request is logged as `attach-cache: ...`
// (`adb logcat -s flutter`). Launch `-e AC_LOC` is not available through
// `am start`; use `--dart-define=AC_LOC=/s/lab/settings/storage` to start on
// Settings > Storage.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

import '../test/fixtures/preview_samples.dart';
import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _port = 18791;

class CacheStorage {
  CacheStorage._(this.server, this.bodies, this.apiCounts);
  final HttpServer server;
  final Map<String, Uint8List> bodies;
  final Map<String, int> apiCounts;
  final hits = <String, int>{};
  final bytes = <String, int>{};

  static Future<CacheStorage> start(
    Map<String, Uint8List> bodies,
    Map<String, int> apiCounts,
  ) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      _port,
      shared: true,
    );
    final storage = CacheStorage._(server, bodies, apiCounts);
    server.listen(storage._serve);
    return storage;
  }

  String url(String path) => 'http://127.0.0.1:$_port$path';

  Future<void> _serve(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;
    if (path == '/__stats') {
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'storage': {
            for (final e in hits.entries)
              e.key: {'requests': e.value, 'bytes': bytes[e.key] ?? 0},
          },
          'api': apiCounts,
        }),
      );
      await response.close();
      return;
    }
    if (path == '/__reset') {
      hits.clear();
      bytes.clear();
      apiCounts.clear();
      await response.close();
      debugPrint('attach-cache: counters reset');
      return;
    }
    final body = bodies[path];
    if (body == null) {
      response.statusCode = 404;
      await response.close();
      return;
    }
    hits[path] = (hits[path] ?? 0) + 1;
    bytes[path] = (bytes[path] ?? 0) + body.length;
    debugPrint('attach-cache: storage GET $path (${body.length} bytes)');
    response.headers.contentLength = body.length;
    response.add(body);
    await response.close();
  }
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  // Like main(): the persistent attachment cache survives restarts.
  AttachmentDiskCache.installed ??= AttachmentDiskCache(
    getApplicationCacheDirectory,
  );
  unawaited(AttachmentDiskCache.installed!.warm());
  final images = await LabImages.start();
  final pdf = previewPdf();
  final apiCounts = <String, int>{};
  final storage = await CacheStorage.start({
    '/img/thumb.png': images.pngs[3].$3,
    '/img/photo.png': images.pngs[0].$3,
    '/img/plain.png': images.pngs[1].$3,
    '/doc/report.pdf': pdf,
    // Gallery message: three originals, no thumbnails (viewer test).
    '/img/g1.png': images.pngs[0].$3,
    '/img/g2.png': images.pngs[1].$3,
    '/img/g3.png': images.pngs[2].$3,
  }, apiCounts);

  Map<String, dynamic> row(
    int n,
    String text,
    List<Map<String, dynamic>> attachments,
  ) => labRow('ac', 'plain', n)
    ..['content'] = text
    ..['attachments'] = attachments;
  Map<String, dynamic> image(
    String id,
    (int, int, Uint8List) png, {
    String? thumb,
  }) => {
    'id': id,
    'channelId': 'ac',
    'filename': 'IMG_$id.png',
    'mimeType': 'image/png',
    'width': png.$1,
    'height': png.$2,
    'sizeBytes': png.$3.length,
    'thumbnailUrl': ?thumb,
  };
  final channel = LabChannel('ac', const []);
  channel.rows.addAll([
    row(0, 'Photo with a thumbnail', [
      image('ac-photo', images.pngs[0], thumb: storage.url('/img/thumb.png')),
    ]),
    row(1, 'Photo without a thumbnail', [image('ac-plain', images.pngs[1])]),
    row(2, 'Quarterly report', [
      {
        'id': 'ac-pdf',
        'channelId': 'ac',
        'filename': '2026Q3-report.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': pdf.length,
      },
    ]),
    row(4, 'Three photos', [
      image('ac-g1', images.pngs[0]),
      image('ac-g2', images.pngs[1]),
      image('ac-g3', images.pngs[2]),
    ]),
    row(3, 'Meeting notes', [
      {
        'id': 'ac-note',
        'channelId': 'ac',
        'filename': 'notes.txt',
        'mimeType': 'text/plain',
        'sizeBytes': 120,
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
    'displayLanguage': 'en',
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/ac'] = (_) => channel.record.json;
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
  const originals = {
    'ac-photo': '/img/photo.png',
    'ac-plain': '/img/plain.png',
    'ac-pdf': '/doc/report.pdf',
    'ac-g1': '/img/g1.png',
    'ac-g2': '/img/g2.png',
    'ac-g3': '/img/g3.png',
  };
  void count(String key) {
    apiCounts[key] = (apiCounts[key] ?? 0) + 1;
    debugPrint('attach-cache: api $key (total ${apiCounts[key]})');
  }

  api.patterns.insert(0, (
    (o) =>
        o.method == 'GET' &&
        o.path.startsWith('/attachments/ac-') &&
        o.path.endsWith('/url'),
    (o) {
      final id = o.path.split('/')[2];
      count('sign:$id');
      return {'url': storage.url(originals[id]!)};
    },
  ));
  api.patterns.insert(0, (
    (o) =>
        o.method == 'GET' &&
        o.path.startsWith('/attachments/ac-') &&
        o.path.endsWith('/preview'),
    (o) {
      count('preview:${o.path.split('/')[2]}');
      return {
        'status': 'ok',
        'data': {
          'kind': 'text',
          'text': 'Weekly sync notes: ship the attachment cache.',
        },
      };
    },
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
    'raft.light': 'elegant',
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  final dir = await Directory.systemTemp.createTemp('raft-attach-cache-');
  const location = String.fromEnvironment(
    'AC_LOC',
    defaultValue: '/s/lab/channel/ac',
  );
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: location),
      nativeContent: LabNavigationContent(),
      // AC_SHARE=true exercises the system share sheet and gallery save.
      nativeSharing: NativeSharing(
        supported: const bool.fromEnvironment('AC_SHARE'),
      ),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
  // The production route lands on the (empty) channel; load its messages the
  // way a tap on the channel row does.
  unawaited(() async {
    for (var i = 0; i < 150; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      dynamic controller;
      void visit(Element e) {
        if (controller != null) return;
        if (e.widget.runtimeType.toString() == 'RaftChatView') {
          controller = (e.widget as dynamic).controller;
          return;
        }
        e.visitChildren(visit);
      }

      final root = WidgetsBinding.instance.rootElement;
      if (root != null) visit(root);
      if (controller != null) {
        await controller.selectChannel(controller.channel);
        return;
      }
    }
  }());
}
