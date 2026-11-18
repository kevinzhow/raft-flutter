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
  bool denyTaskConversation = false;
  final contextChannels = <(String, Object?)>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'slug': 'team', 'serverPushMuted': serverMuted}),
  ];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/task-conv') {
      if (denyTaskConversation) throw const RaftApiException('Unavailable');
      return {
        'id': 'task-conv',
        'serverId': 's',
        'type': 'task',
        'taskId': 'task-1',
        'parentChannelId': 'c',
      };
    }
    if (path.startsWith('/channels/')) {
      return {'id': 'c', 'serverId': 's', 'type': 'channel', 'joined': true};
    }
    if (path.startsWith('/messages/context/')) {
      contextChannels.add((path.split('/').last, query?['channelId']));
    }
    return {
      'messages': [
        {'id': path.split('/').last, 'channelId': query?['channelId'] ?? 'c'},
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
  final payloads = <String>[];
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
  }) async {
    shown.add((title: title, body: body));
    payloads.add(payload);
  }
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
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'slug': 'team', 'role': 'owner'})
      ..foreground = false;
    w.bindNavigation();
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

  test(
    'mounted task socket route delivers and opens the precise reply once',
    () async {
      const event = {
        'title': '#8 Scoped actual task · #general',
        'subtitle': '#general',
        'body': 'Ada: needle',
        'tag': 'event-1',
        'id': 'event-1',
        'category': 'mention',
        'priority': 'high',
        'seq': 7,
        'groupKey': 'task-group',
        'serverId': 's',
        'kind': 'channel',
        'channelId': 'c',
        'threadId': null,
        'parentChannelId': 'c',
        'parentMessageId': null,
        'messageId': null,
        'conversationId': 'task-conv',
        'route': {
          'type': 'task',
          'serverId': 's',
          'parentChannelId': 'c',
          'parentChannelType': 'channel',
          'taskId': 'task-1',
          'messageId': 'matched-reply',
        },
        'routeUrl': '/s/team/channel/c?task=c%3Atask%3Atask-1',
        'url':
            'https://fixture.example/s/team/channel/c?task=c%3Atask%3Atask-1',
        'silent': false,
        'previewMode': 'full',
        'phoneAlert': true,
      };
      client.denyTaskConversation = true;
      await deliver({...event, 'messageId': 'legacy-anchor'});
      expect(n.shown, isEmpty);
      client.denyTaskConversation = false;
      w.foreground = true;
      await deliver(event);
      expect(n.shown, isEmpty);
      w.foreground = false;
      await Future.wait([
        deliver(event),
        deliver({...event, 'messageId': 'legacy-anchor'}),
      ]);
      expect(n.shown, hasLength(1));
      expect(client.contextChannels, [('matched-reply', 'task-conv')]);

      n.onTap?.call(n.payloads.single);
      await pumpEventQueue();
      expect(w.location.query('task'), 'c:task:task-1');
      expect(w.location.query('taskMsg'), 'task-1:matched-reply');
      expect(client.contextChannels, [
        ('matched-reply', 'task-conv'),
        ('matched-reply', 'task-conv'),
      ]);
    },
  );

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
