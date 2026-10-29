// Phone acceptance for the migrated settings, tasks, and saved pages.
// Production RaftApp and root. The account and HTTP service use the existing
// lab fixtures. Tasks are pageTasksFixture. Saved is pageSavedFixture.
//
//   tool/flutter build apk --profile \
//     -t integration_test/m6_pages_main.dart
//
// Phone settings, tasks, and saved read the workspace. Starts at /s/lab/tasks.
// Saved is Home, then nav-saved. Settings is the Settings tab. Use a phone-sized
// simulator so these routes stay in the phone shell. This entry does not choose
// an application id.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/page_alignment_fixtures.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  final channels = [
    LabChannel('channel-design', const ['plain']),
  ];
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    channels,
    images,
    mobile: true,
    ownsClient: false,
    origin: 'https://m6-pages.invalid',
  );
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => client.user!.json;
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Pages Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /servers/unread-summary'] = (_) => <dynamic>[];
  for (final channel in channels) {
    api.routes['GET /channels/${channel.id}'] = (_) => {
      ...channel.record.json,
      'serverId': 's1',
    };
  }
  api.routes['GET /channels/inbox'] = (_) => {
    'hasMore': false,
    'totalCount': 0,
    'totalUnreadCount': 0,
    'items': <dynamic>[],
  };
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  api.routes['GET /tasks/server'] = (options) {
    final status = options.queryParameters['status'];
    return {
      'tasks': [
        for (final task in pageTasksFixture['tasks'] as List)
          if (status == null || task['status'] == status) task,
      ],
      'next_cursor': null,
    };
  };
  // The fixture is the first page. A later offset is the end of that page,
  // so the list does not append the same rows again.
  api.routes['GET /channels/saved'] = (options) {
    final offset =
        int.tryParse('${options.queryParameters['offset'] ?? 0}') ?? 0;
    if (offset > 0) {
      return {
        'hasMore': false,
        'total': pageSavedFixture['total'],
        'saved': <dynamic>[],
      };
    }
    return pageSavedFixture;
  };
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': 'elegant',
  });
  await DevicePreferences.load();
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}/m6-pages');
  await directory.create(recursive: true);
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab/tasks'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${directory.path}/workspace.sqlite')),
    ),
  );
}
