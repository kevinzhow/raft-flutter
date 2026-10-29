// Debug/profile-only entrypoint: the production RaftApp on perf-lab fixtures
// with channels that exercise heavy resources (4000x3000 JPEG attachments, a
// 24-page PDF, a DOM-heavy HTML page) served by an external HTTP server. Used
// to measure what stays resident after pages, previews and the app itself are
// hidden (`dumpsys meminfo`, RSS). No login. Never built into the release app.
//
//   python3 /path/server.py 8792        # serves /files/* and /api/attachments/*/html-preview
//   tool/flutter build apk --profile -t integration_test/resource_release_main.dart \
//     --dart-define=RR_BASE=http://10.0.2.2:8792 --dart-define=RR_MOBILE=true \
//     --dart-define=RR_LOC=/s/lab
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/memory_release.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _base = String.fromEnvironment(
  'RR_BASE',
  defaultValue: 'http://127.0.0.1:8792',
);

/// (file, width, height) of the served photos.
const _photos = [
  ('photo0.jpg', 4000, 3000),
  ('photo1.jpg', 3000, 4000),
  ('photo2.jpg', 4032, 3024),
  ('photo3.jpg', 3840, 2160),
];

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  // Memory probe: one line per second with every tier (RaftMemoryRelease).
  Timer.periodic(
    const Duration(seconds: 1),
    // ignore: avoid_print
    (_) => print('RRMEM2 ${RaftMemoryRelease.instance.snapshot()}'),
  );
  runApp(
    await buildResourceReleaseApp(
      mobile: const bool.fromEnvironment('RR_MOBILE', defaultValue: true),
      location: const String.fromEnvironment('RR_LOC', defaultValue: '/s/lab'),
    ),
  );
}

/// The production [app.RaftApp] on the fixture workspace (also mounted by
/// `resource_release_linux_test.dart`).
Future<Widget> buildResourceReleaseApp({
  required bool mobile,
  required String location,
}) async {
  final images = await LabImages.start();

  Map<String, dynamic> row(
    String channel,
    int n,
    String text,
    List<Map<String, dynamic>> attachments,
  ) => labRow(channel, 'plain', n)
    ..['content'] = text
    ..['attachments'] = attachments;

  final img = LabChannel('img', const []);
  for (var n = 0; n < 40; n++) {
    img.rows.add(
      row('img', n, 'Photos $n', [
        for (var a = 0; a < 1 + n % 3; a++)
          () {
            final (file, w, h) = _photos[(n + a) % _photos.length];
            return {
              'id': 'rr-$file-$n-$a',
              'channelId': 'img',
              'filename': 'IMG_${n}_$a.jpg',
              'mimeType': 'image/jpeg',
              'sizeBytes': 4400000,
              'width': w,
              'height': h,
            };
          }(),
      ]),
    );
  }
  final docs = LabChannel('docs', const []);
  for (var n = 0; n < 6; n++) {
    docs.rows.add(
      row('docs', n, n.isEven ? 'Report $n (PDF)' : 'Page $n (HTML)', [
        n.isEven
            ? {
                'id': 'rr-pdf-$n',
                'channelId': 'docs',
                'filename': 'report-$n.pdf',
                'mimeType': 'application/pdf',
                'sizeBytes': 6801415,
              }
            : {
                'id': 'rr-html-$n',
                'channelId': 'docs',
                'filename': 'page-$n.html',
                'mimeType': 'text/html',
                'sizeBytes': 91328,
              },
      ]),
    );
  }
  final other = LabChannel('other', mixKinds(60));
  final more = LabChannel('more', mixKinds(60));

  final channels = [img, docs, other, more];
  final (seed, api, client) = await labWorkspace(
    channels,
    images,
    mobile: mobile,
    ownsClient: false,
    origin: _base,
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
  for (final c in channels) {
    api.routes['GET /channels/${c.id}'] = (_) => c.record.json;
  }
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
        o.path.startsWith('/attachments/rr-') &&
        o.path.endsWith('/html-preview-url'),
    (o) => {
      'url':
          '$_base/api/attachments/${o.path.split('/')[2]}/html-preview'
          '?previewToken=fixture&serverId=s1',
    },
  ));
  api.patterns.insert(0, (
    (o) =>
        o.method == 'GET' &&
        o.path.startsWith('/attachments/rr-') &&
        o.path.endsWith('/url'),
    (o) {
      final id = o.path.split('/')[2];
      final file = id.startsWith('rr-pdf-')
          ? 'report.pdf'
          : id.startsWith('rr-html-')
          ? 'page.html'
          : id.split('-')[1];
      return {'url': '$_base/files/$file?X-Amz-Expires=3600&X-Amz-Signature=x'};
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
    'raft.light': 'brutal',
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  final dir = await Directory.systemTemp.createTemp('raft-resource-release-');
  return app.RaftApp(
    services: const AppServices.updatesDisabledForTestOrPreview(),
    sessionStore: client.sessionStore,
    createClient: (_, _, _) => client,
    initialLocation: Uri(path: location),
    nativeContent: LabNavigationContent(),
    nativeSharing: NativeSharing(supported: false),
    openWorkspaceCache: () async =>
        LabNavigationCache(File('${dir.path}/workspace.sqlite')),
  );
}
