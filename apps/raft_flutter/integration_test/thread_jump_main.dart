// Thread page fixture: the production RaftApp on lab data (no login) with
// channel alpha and an Activity row for a thread of 80 replies (the app opens at
// Activity; the same thread also opens from alpha's thread-summary row). Used on
// an emulator to scroll the thread up, tap the jump-to-latest prompt and check
// the header and composer stay intact. Isolated app id only.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/thread_jump_main.dart
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
  final alpha = LabChannel('alpha', [
    'plain',
    'plain',
    'thread-summary',
    'plain',
    'plain',
    'markdown',
    'plain',
    'plain',
  ]);
  alpha.rows.add({
    ...labRow('alpha', 'plain', 8),
    'id': 'alpha-agent',
    'seq': '9',
    'senderId': 'a1',
    'senderType': 'agent',
    'senderName': 'Cindy',
    'content': 'Agent row: tap my avatar for my profile.',
  });
  final beta = LabChannel('beta', List.filled(5, 'plain'));
  final parentId = alpha.rows[2]['id'] as String;
  final threadId = 'thread-$parentId';
  final thread = LabChannel(threadId, List.filled(80, 'plain'));
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    [alpha, beta, thread],
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
  api.routes['GET /messages/context/$parentId'] = (_) => {
    'messages': [alpha.rows[2]],
    'hasMore': false,
    'hasNewer': true,
    'threadSummariesByParentMessageId': alpha.summaries,
  };
  api.routes['GET /channels/threads/followers'] = (_) => {
    'threads': <dynamic>[],
  };
  // The Activity row focuses reply 40: a window in the middle of the thread
  // with newer replies not loaded, so "Back to bottom" has to reload.
  api.routes['GET /messages/context/$threadId-40'] = (_) => {
    'messages': thread.rows.sublist(30, 52),
    'hasMore': true,
    'hasNewer': true,
    'threadSummariesByParentMessageId': <String, dynamic>{},
  };
  api.routes['GET /channels/alpha/threads/$parentId'] = (_) => {
    ...alpha.summaries[parentId] as Map<String, dynamic>,
  };
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
  for (final c in [alpha, beta]) {
    api.routes['GET /channels/${c.id}'] = (_) => c.record.json;
  }
  api.routes['GET /channels/inbox'] = (_) => {
    'hasMore': false,
    'totalCount': 3,
    'totalUnreadCount': 0,
    'items': [
      {
        'kind': 'thread',
        'threadChannelId': threadId,
        'parentChannelId': 'alpha',
        'parentMessageId': parentId,
        'parentMessagePreview': 'Parent message of the long thread',
        'latestActivityPreview': 'A reply',
        'latestActivityMessageId': '$threadId-40',
        'lastActivityAt': '2026-10-12T02:36:00.000Z',
        'unreadCount': 0,
        'isFollowing': true,
      },
      for (final n in ['alpha', 'beta'])
        {
          'kind': 'channel',
          'channelId': n,
          'channelName': 'lab-$n',
          'channelType': 'channel',
          'lastMessageId': null,
          'firstUnreadMessageId': null,
          'firstMentionMessageId': null,
          'lastMessageAt': '2026-10-12T02:35:00.000Z',
          'lastMessagePreview': 'Preview row for $n',
          'lastMessageSenderType': 'user',
          'lastMessageSenderId': 'alice',
          'lastMessageSenderName': 'Alice',
          'unreadCount': 0,
          'hasMention': false,
        },
    ],
  };
  // The production roster shape ({humans, agents}); the lab default is a bare
  // list, which channel settings (correctly) refuses.
  api.patterns.insert(0, (
    (o) =>
        o.method == 'GET' &&
        o.path.startsWith('/channels/') &&
        o.path.endsWith('/members'),
    (_) => {
      'humans': [
        for (final (id, name) in [('alice', 'Alice Zhang'), ('bob', 'Bob Li')])
          {'userId': id, 'name': id, 'displayName': name, 'role': 'member'},
      ],
      'agents': [agent],
    },
  ));
  const dm = {
    'id': 'dm1',
    'name': 'cindy',
    'type': 'dm',
    'joined': true,
    'peerId': 'a1',
    'peerType': 'agent',
    'peerDisplayName': 'Cindy',
  };
  api.routes['POST /channels/dm'] = (_) => dm;
  api.routes['GET /channels/dm1'] = (_) => dm;
  api.routes['GET /messages/channel/dm1'] = (_) => {
    'messages': <dynamic>[],
    'hasMore': false,
    'hasNewer': false,
  };
  api.routes['POST /channels/dm1/read'] = (_) => <String, dynamic>{};
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
  final dir = await Directory.systemTemp.createTemp('raft-dm-profile-');
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab/activity'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
}
