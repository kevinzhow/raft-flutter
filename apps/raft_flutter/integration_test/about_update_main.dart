// Debug/profile-only entrypoint: the production RaftApp on fixture data with
// the release update wiring (AppUpdateService.forThisBuild, as main() builds
// it), opened on Settings > About of a phone-width Android window. Proves the
// About version, the Updates card and Settings > Release notes on a device.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/about_update_main.dart \
//     --dart-define=RAFT_APP_VERSION=0.1.0 --dart-define=RAFT_BUILD_NUMBER=41 \
//     --dart-define=FAKE_ORIGIN=http://10.0.2.2:8799 --dart-define=START=/s/lab/settings/about
//   adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # .linkperf only
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _origin = String.fromEnvironment('FAKE_ORIGIN');
const _start = String.fromEnvironment(
  'START',
  defaultValue: '/s/lab/settings/about',
);

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final alpha = LabChannel('alpha', List.filled(6, 'plain'));
  // Newest rows: an agent and an external projection, each its own sender run.
  alpha.rows.addAll([
    {
      ...labRow('alpha', 'plain', 6),
      'id': 'alpha-agent',
      'seq': '7',
      'senderId': 'a1',
      'senderType': 'agent',
      'senderName': 'Cindy',
      'content': 'Agent row: tap my avatar for my profile.',
    },
    {
      ...labRow('alpha', 'plain', 7),
      'id': 'alpha-external',
      'seq': '8',
      'senderId': 'slack-ada',
      'senderType': 'external_projection',
      'senderName': 'Ada',
      'content': 'External row from Slack.',
      'externalAuthor': {
        'displayName': 'Ada Lovelace',
        'provider': 'slack',
        'actorKind': 'human',
        'workspaceName': 'Acme Product Studio',
      },
    },
  ]);
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    [alpha],
    images,
    mobile: true,
    ownsClient: false,
  );
  seed.dispose();
  const agent = {
    'id': 'a1',
    'name': 'cindy',
    'displayName': 'Cindy',
    'status': 'active',
    'runtime': 'claude',
    'model': 'sonnet',
  };
  api.routes['GET /agents'] = (_) => [agent];
  api.routes['GET /agents/a1'] = (_) => agent;
  api.routes['GET /agents/a1/skills'] = (_) => {'global': [], 'workspace': []};
  api.routes['GET /servers/s1/members'] = (_) => [
    for (final (id, name) in [
      ('alice', 'Alice Zhang'),
      ('bob', 'Bob Li'),
      ('chen', '陈思远'),
      ('dana', 'Dana Okafor'),
    ])
      {'userId': id, 'name': id, 'displayName': name, 'role': 'member'},
  ];
  client.user = RaftRecord({
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': 'en',
  });
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
  api.routes['GET /channels/alpha'] = (_) => alpha.record.json;
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
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': 'elegant',
  });
  final dir = await Directory.systemTemp.createTemp('raft-avatar-profile-');
  runApp(
    app.RaftApp(
      services: AppServices.withUpdates(
        AppUpdateService.forThisBuild(
          origin: _origin.isEmpty ? null : Uri.parse(_origin),
        )..start(),
      ),
      ownsAppUpdate: true,
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: _start),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
}
