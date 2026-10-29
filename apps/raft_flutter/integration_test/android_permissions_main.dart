// Android permission fixture: the production RaftApp and the production
// NativeContentCoordinator / NativeNotificationService (real plugin calls, real
// SharedPreferences that survive a cold start) on lab data without login. Used
// on an emulator to tap through the notification permission flows (first
// request, deny, deny twice, revoke while backgrounded, cold start). Isolated
// app id only.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/android_permissions_main.dart
//   adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # .linkperf only
//
// --dart-define=LAN_ORIGIN=http://10.0.2.2:8793 makes the fixture's server a
// private address, so sign-in and invite paths ask for the Android 17 local
// network permission exactly as for a self-hosted server; SIGNED_IN=false
// starts at the sign-in form instead of a restored session. With a LAN origin
// the fixture also logs a raw TCP probe of it ("lan-probe ...") at start and on
// every resume, so the OS-level access state is visible without a real server
// (start `python3 -m http.server 8793 --bind 0.0.0.0` on the host for "open").
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/file_selection.dart'
    show configureAndroidPhotoPicker;
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _origin = String.fromEnvironment(
  'LAN_ORIGIN',
  defaultValue: 'https://example.invalid',
);

const _signedIn = bool.fromEnvironment('SIGNED_IN', defaultValue: true);

class _ResumeProbe with WidgetsBindingObserver {
  _ResumeProbe(this.origin);
  final Uri origin;
  Future<void> run(String when) async {
    try {
      final socket = await Socket.connect(
        origin.host,
        origin.port,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      debugPrint('lan-probe $when: connected');
    } catch (e) {
      debugPrint('lan-probe $when: failed ${e.runtimeType} $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(run('resume'));
  }
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  configureAndroidPhotoPicker();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final alpha = LabChannel('alpha', List.filled(6, 'plain'));
  final beta = LabChannel('beta', List.filled(5, 'plain'));
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    [alpha, beta],
    images,
    mobile: true,
    ownsClient: false,
    origin: _origin,
  );
  seed.dispose();
  const user = {
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': 'en',
  };
  client.user = RaftRecord(user);
  api.routes['GET /auth/me'] = (_) => user;
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  for (final c in [alpha, beta]) {
    api.routes['GET /channels/${c.id}'] = (_) => c.record.json;
  }
  api.routes['GET /channels/inbox'] = (_) => {
    'hasMore': false,
    'totalCount': 2,
    'totalUnreadCount': 0,
    'items': [
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
  api.routes['GET /servers/s1/notification-settings'] = (_) => {
    'serverPushMuted': false,
  };
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  // Real preferences: the notification opt-in marker and the member's choice
  // must survive the cold starts this fixture exists to test.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('raft.origin', client.origin);
  await prefs.setString('raft.mode', 'light');
  await prefs.setString('raft.light', 'elegant');
  if (_origin.startsWith('http://')) {
    final probe = _ResumeProbe(Uri.parse(_origin));
    WidgetsBinding.instance.addObserver(probe);
    unawaited(probe.run('start'));
  }
  final unsigned = LabClient(api, origin: _origin);
  final dir = await Directory.systemTemp.createTemp('raft-permissions-');
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: _signedIn ? client.sessionStore : MemorySessionStore(),
      createClient: (_, _, _) => _signedIn ? client : unsigned,
      initialLocation: Uri(path: '/s/lab/activity'),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
}
