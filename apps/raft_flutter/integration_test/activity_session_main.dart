// Debug fixture for native Activity session verification. The production
// RaftApp owns selection/bootstrap and the only WorkspaceController. Each
// actual inbox request returns a visible window number; transport calls and
// the accepted store can be read through the debug VM without invoking code.
// Build only as the isolated .linkperf Android package or an isolated Linux
// runner. OS notification delivery and performance are separate verifications.
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

int _inboxReads = 0;

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  const names = ['alpha', 'beta', 'gamma'];
  final channels = [
    for (final n in names) LabChannel(n, List.filled(6, 'plain')),
  ];
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    channels,
    images,
    mobile: true,
    ownsClient: false,
  );
  seed.dispose();
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
  for (final c in channels) {
    api.routes['GET /channels/${c.id}'] = (_) => c.record.json;
  }
  api.routes['GET /channels/inbox'] = (_) {
    final serial = ++_inboxReads;
    return {
      'hasMore': false,
      'totalCount': 3,
      'totalUnreadCount': 3,
      'items': [
        for (final c in channels)
          {
            'kind': 'channel',
            'channelId': c.id,
            'channelName': 'lab-${c.id}',
            'channelType': 'channel',
            'lastMessageId': c.rows.last['id'],
            'lastMessageAt': '2026-10-14T10:00:00Z',
            'lastMessagePreview': 'Window $serial for ${c.id}',
            'lastMessageSenderType': 'user',
            'lastMessageSenderId': 'alice',
            'lastMessageSenderName': 'Alice',
            'unreadCount': 1,
            'hasMention': false,
          },
      ],
    };
  };
  api.routes['GET /servers/unread-summary'] = (_) => [
    {'serverId': 's1', 'unreadCount': 3, 'activityUnreadCount': 3},
  ];
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
  final dir = await Directory.systemTemp.createTemp('raft-activity-session-');
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
