// A phone without native push posts the server's `notification:push`
// itself (server v1.24 mobileSocket.ts, "GMS-less Android posts it"). The
// server decides who is notified (levels, mutes, pause, quiet hours) and
// whether the phone alerts now (`phoneAlert`: false while a computer is in
// use, docs/contracts/notifications.md §1.3); the fixed phrases arrive as
// `push.*` keys for the display language.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart' show raftChinese;
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.example',
        sessionStore: MemorySessionStore(),
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  bool serverMuted = false;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'slug': 'team', 'serverPushMuted': serverMuted}),
  ];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.startsWith('/channels/')) return {'id': 'c', 'serverId': 's'};
    return {
      'messages': [
        {'id': path.split('/').last, 'channelId': 'c'},
      ],
    };
  }
}

class _Notifications extends NativeNotificationService {
  _Notifications() : super(platform: TargetPlatform.android) {
    enabled = true;
    permitted = true;
    available = true;
  }
  final shown = <({String title, String body})>[];
  @override
  bool get receivesMessages => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
    int? unread,
    bool quiet = false,
    String? conversation,
  }) async => shown.add((title: title, body: body));
}

Map<String, Object?> push(String message, {Object? phoneAlert = _absent}) => {
  'serverId': 's',
  'kind': 'channel',
  'channelId': 'c',
  'messageId': message,
  'title': '#general · Team',
  'subtitle': 'Team',
  'body': 'Ada: hello',
  if (!identical(phoneAlert, _absent)) 'phoneAlert': phoneAlert,
};

const _absent = Object();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late WorkspaceController w;
  late _Notifications n;
  late NativeContentCoordinator links;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s');
    w = WorkspaceController(client)..foreground = false;
    n = _Notifications();
    links = NativeContentCoordinator(
      notifications: n,
      links: const Stream.empty(),
    );
    await links.init();
    links.bindWorkspace(w);
    // The phone is in the background (a foreground app shows no OS alert).
    links.didChangeAppLifecycleState(AppLifecycleState.paused);
  });
  tearDown(() async {
    await links.dispose();
    w.dispose();
    n.dispose();
    await client.stream.close();
  });

  Future<void> deliver(Map<String, Object?> payload) async {
    client.stream.add(RaftEvent('notification:push', payload));
    await pumpEventQueue();
  }

  test('phoneAlert false (a computer is in use) posts nothing; true or absent posts', () async {
    await deliver(push('quiet', phoneAlert: false));
    expect(n.shown, isEmpty);
    await deliver(push('alert', phoneAlert: true));
    await deliver(push('older-server'));
    expect(n.shown, hasLength(2));
  });

  test('the server decided: a server row at Nothing does not hold back a channel that notifies', () async {
    client.serverMuted = true;
    await deliver(push('channel-level-all'));
    expect(n.shown, hasLength(1));
  });

  test('zh: a keyed title is translated and joined with its subtitle; the body stays the sender text', () async {
    n.localize = (english) => raftChinese[english] ?? english;
    await deliver({
      ...push('keyed'),
      'kind': 'channel',
      'title': 'Thread in #general · Team',
      'localization': {
        'titleKey': 'push.title.thread_in_channel',
        'titleArgs': ['general'],
      },
    });
    expect(
      n.shown.single.title,
      '${raftChinese['Thread in #{0}']!.replaceAll('{0}', 'general')} · Team',
    );
    expect(n.shown.single.body, 'Ada: hello');
  });
}
