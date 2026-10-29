// Debug/profile-only entrypoint: the production RaftApp on fixture data, no
// login, opened on Home; tap lab-alpha for a phone chat that holds a human, an agent and an
// external sender. Used to prove on a phone-width Android window that tapping
// a sender avatar opens that person's / agent's profile page (Web `SenderAvatar`
// -> `openProfile`), and that Back returns to the chat.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/phone_avatar_profile_main.dart
//   adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # .linkperf only
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

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
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
}
