// Debug/profile-only entrypoint: the production RaftApp on perf-lab fixtures,
// no login. Device repro for sticky hover/selected/pressed states on touch
// (message rows, text selection, focus rings). Never built into the release app.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/touch_hover_main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final channel = LabChannel('kb', [for (var i = 0; i < 8; i++) ...['plain', 'markdown', 'reactions', 'attachments', 'image']]);
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace([channel], images, mobile: true, ownsClient: false);
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice', 'name': 'Alice Zhang', 'email': 'alice@example.invalid', 'emailVerified': true, 'displayLanguage': 'en',
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/kb'] = (_) => channel.record.json;
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/saved'] = (_) => {'globalTotal': 0, 'saved': <dynamic>[]};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': <dynamic>[]};
  api.routes['GET /announcements/active'] = (_) => {'announcements': <dynamic>[]};
  api.routes['GET /product-feedback/tickets'] = (_) => {'unread_total': 0, 'tickets': <dynamic>[]};
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {MobileTabs.home, MobileTabs.tasks, MobileTabs.members, MobileTabs.computers},
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': const String.fromEnvironment('KB_THEME', defaultValue: 'brutal'),
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  final dir = await Directory.systemTemp.createTemp('raft-keyboard-repro-');
  runApp(app.RaftApp(
    services: const AppServices.updatesDisabledForTestOrPreview(),
    sessionStore: client.sessionStore,
    createClient: (_, _, _) => client,
    initialLocation: Uri(path: '/s/lab'),
    nativeContent: LabNavigationContent(),
    nativeSharing: NativeSharing(supported: false),
    openWorkspaceCache: () async => LabNavigationCache(File('${dir.path}/workspace.sqlite')),
  ));
}
