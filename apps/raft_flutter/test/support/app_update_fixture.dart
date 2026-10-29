import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_flutter/platform/client_release_notes.dart';
import 'package:raft_ui/raft_ui.dart';

import '../workspace_source_location_contract_test.dart' show pageFixture, frames;
import 'memory_storage.dart';
import 'app_services_fixture.dart';

// AppUpdate fixtures only. The existing workspace transport/settling helper is
// reused as-is; this extraction does not change waiting or service ownership.
ClientReleaseNotes appUpdateNotes(String text) => ClientReleaseNotes(
  storage: MemoryStorage(),
  fetch: (_) async => jsonEncode({
    'items': [
      {
        'releaseId': 'v0.1.0+7',
        'tag': 'v0.1.0+7',
        'version': '0.1.0',
        'date': '2026-10-14',
        'state': 'published',
        'entries': [
          {'type': 'feature', 'text': text, 'emphasis': false},
        ],
      },
    ],
    'nextCursor': null,
  }),
);

AppUpdateService appUpdateFixture({
  int build = 20,
  String platform = 'macos-arm64',
  bool withNotes = false,
}) => AppUpdateService(
  currentVersion: '0.1.0',
  currentBuild: build,
  platformKey: platform,
  storage: MemoryStorage(),
  scheduleTimer: false,
  releaseNotes: withNotes ? appUpdateNotes('Fork guard notes') : null,
  fetch: (_) async => jsonEncode([
    {
      'platform': platform.split('-').first,
      'arch': platform.split('-').last,
      'version': '0.1.0',
      'buildNumber': '37',
      'releaseTag': 'v0.1.0+5',
      'artifact': 'raft-flutter-0.1.0+5-$platform.zip',
    },
  ]),
);

Future<WorkspaceController> mountAppUpdateWorkspace(
  WidgetTester t,
  AppUpdateService? update, {
  double width = 1280,
  bool dark = false,
}) async {
  final (w, api) = await pageFixture(t, section: 'chat');
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'items': [],
    'unread_total': 0,
  };
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
        update: update,
      ),
    ),
  );
  await frames(t, () {});
  await t.pumpAndSettle();
  return w;
}
