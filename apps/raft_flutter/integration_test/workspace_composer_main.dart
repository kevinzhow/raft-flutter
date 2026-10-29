// Isolated native acceptance entrypoint. Production RaftApp and SQLite own
// drafts; the lab supplies only the account, server and channel responses.
// Restart the same isolated application profile to verify persisted drafts.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
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
  await DevicePreferences.load();
  final channels = [
    LabChannel('alpha', ['plain', 'plain']),
    LabChannel('beta', ['plain', 'plain']),
  ];
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    channels,
    images,
    mobile: true,
    ownsClient: false,
    origin: 'https://composer-acceptance.invalid',
  );
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => client.user!.json;
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Composer Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /servers/unread-summary'] = (_) => <dynamic>[];
  for (final channel in channels) {
    api.routes['GET /channels/${channel.id}'] = (_) => channel.record.json;
    api.routes['POST /channels/${channel.id}/read-all'] = (_) => {
      'maxReadSeq': 2, 'readStateVersion': 1,
    };
  }
  api.routes['GET /channels/inbox'] = (_) => {
    'hasMore': false,
    'totalCount': channels.length,
    'totalUnreadCount': 0,
    'items': [
      for (final channel in channels) {
        'kind': 'channel',
        'channelId': channel.id,
        'channelName': channel.id,
        'lastMessageId': '${channel.id}-1',
        'lastMessagePreview': 'Composer acceptance ${channel.id}',
        'lastMessageSenderType': 'user',
        'lastMessageSenderId': 'alice',
        'lastMessageSenderName': 'Alice Zhang',
        'lastMessageAt': '2026-10-01T00:03:00Z',
        'latestActivitySeq': '2',
        'readState': {
          'kind': 'present', 'maxReadSeq': '2', 'readStateVersion': 1,
          'latestActivity': {'messageId': '${channel.id}-1', 'seq': '2'},
        },
        'unreadCount': 0,
        'firstUnreadMessageId': null,
        'hasMention': false,
      },
    ],
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
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}/composer-m3-slice1');
  await directory.create(recursive: true);
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab/channel/alpha'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${directory.path}/workspace.sqlite')),
    ),
  );
}
