// Raft Desktop's only notification source in v1.24: the server's
// `notification:desktop` stream (Web desktopNative/serverNotificationStream.ts,
// notificationGate.ts). Device-local gates only; delivered alerts are acked
// with this socket's id so the server keeps the phone quiet.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/desktop_server_notifications.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart' show raftChinese;

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.example',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  String? get socketId => 'socket-1';
}

class _Notifications extends NativeNotificationService {
  _Notifications() : super(platform: TargetPlatform.macOS) {
    enabled = true;
    permitted = true;
    available = true;
  }
  final shown = <({String title, String body, Map payload, bool quiet})>[];
  final tests = <({String? title, String? body})>[];
  bool testShown = true;
  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
    int? unread,
    bool quiet = false,
    String? conversation,
  }) async => shown.add((
    title: title,
    body: body,
    payload: jsonDecode(payload) as Map,
    quiet: quiet,
  ));

  @override
  Future<bool> test({String? title, String? body}) async {
    tests.add((title: title, body: body));
    return testShown;
  }
}

Map<String, dynamic> envelope({
  String id = 'n1',
  String? testId,
  Map<String, dynamic>? localization,
  DateTime? createdAt,
  String serverId = 's1',
  bool silent = false,
}) => {
  'v': 1,
  'id': id,
  'kind': testId == null ? 'thread' : 'mention',
  'event': testId == null ? 'message' : 'test',
  'title': testId == null ? 'Thread in #general' : 'Raft test notification',
  'subtitle': 'Alpha',
  'body': testId == null
      ? 'Ada: ship it'
      : 'If you can read this, notifications reach this device.',
  'serverId': serverId,
  'serverName': 'Alpha',
  'channelId': 't1',
  'threadId': 't1',
  'parentChannelId': 'c1',
  'parentMessageId': 'p1',
  'messageId': 'm1',
  'mentioned': false,
  'sender': {'id': 'u2', 'type': 'user', 'name': 'Ada'},
  'url': '/s/alpha/channel/c1?thread=c1:p1&msg=m1',
  'route': {
    'type': 'thread',
    'serverId': serverId,
    'parentChannelId': 'c1',
    'parentChannelType': 'channel',
    'parentMessageId': 'p1',
    'messageId': 'm1',
  },
  'groupKey': '$serverId:t1',
  'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
  'silent': silent,
  'testId': ?testId,
  'localization': ?localization,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late _Notifications service;
  late DesktopServerNotifications desktop;
  late List<(String, bool)> acked;
  var attended = false;

  setUp(() {
    client = _Client();
    service = _Notifications()..deliveryAllowed = () => !attended;
    attended = false;
    acked = [];
    desktop = DesktopServerNotifications(
      notifications: service,
      ackTest: (_, testId, shown) async => acked.add((testId, shown)),
    )..bind(client, isMemberOf: (id) => id == 's1');
  });
  tearDown(() async {
    desktop.dispose();
    service.dispose();
    await client.stream.close();
  });

  test('a valid alert is posted once, opens its thread and is acked with this socket', () async {
    final acks = <Object?>[];
    client.stream.add(
      RaftEvent('notification:desktop', envelope(), ack: acks.add),
    );
    client.stream.add(
      RaftEvent('notification:desktop', envelope(), ack: acks.add),
    );
    await pumpEventQueue();
    expect(service.shown, hasLength(1), reason: 'each id once');
    final shown = service.shown.single;
    expect(shown.title, 'Thread in #general · Alpha');
    expect(shown.body, 'Ada: ship it');
    expect(
      shown.payload['uri'],
      'raft://v1/servers/s1/channels/c1/threads/t1?parentMessageId=p1&messageId=m1',
    );
    // The repeat is held back on purpose: delivered, so acked too.
    expect(acks, [
      {'received': true, 'socketId': 'socket-1'},
      {'received': true, 'socketId': 'socket-1'},
    ]);
  });

  test('an attended window raises nothing but still acks; a stale, foreign or malformed payload is not acked', () async {
    attended = true;
    expect(
      await desktop.deliver(client, envelope(id: 'held')),
      DesktopDelivery.held,
    );
    attended = false;
    for (final payload in [
      envelope(
        id: 'old',
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      envelope(id: 'foreign', serverId: 's9'),
      {...envelope(id: 'v2'), 'v': 2},
      {...envelope(id: 'blank'), 'title': ' '},
    ]) {
      expect(
        await desktop.deliver(client, payload),
        DesktopDelivery.dropped,
        reason: payload['id'] as String,
      );
    }
    expect(service.shown, isEmpty);
  });

  test(
    'system notifications off: not delivered, so the server alerts the phone',
    () async {
      service.enabled = false;
      final acks = <Object?>[];
      client.stream.add(
        RaftEvent('notification:desktop', envelope(), ack: acks.add),
      );
      await pumpEventQueue();
      expect(service.shown, isEmpty);
      expect(acks, isEmpty);
    },
  );

  test(
    'a test notification shows even while attended and acks its show result',
    () async {
      attended = true;
      expect(
        await desktop.deliver(client, envelope(id: 'test:1', testId: 'T1')),
        DesktopDelivery.posted,
      );
      expect(service.tests.single.title, 'Raft test notification');
      service.testShown = false;
      expect(
        await desktop.deliver(client, envelope(id: 'test:2', testId: 'T2')),
        DesktopDelivery.dropped,
      );
      expect(acked, [('T1', true), ('T2', false)]);
    },
  );

  test('silent (sound off) posts quietly; zh shows the server keys localized', () async {
    service.localize = (english) => raftChinese[english] ?? english;
    await desktop.deliver(
      client,
      envelope(
        silent: true,
        localization: {
          'titleKey': 'push.title.thread_in_channel',
          'titleArgs': ['general'],
          'bodyKey': 'push.body.sender_attachments',
          'bodyArgs': ['Ada', '3'],
        },
      ),
    );
    final shown = service.shown.single;
    expect(shown.quiet, isTrue);
    expect(
      shown.title,
      '${raftChinese['Thread in #{0}']!.replaceAll('{0}', 'general')} · Alpha',
    );
    expect(
      shown.body,
      raftChinese['{0}: Sent {1} attachments']!
          .replaceAll('{0}', 'Ada')
          .replaceAll('{1}', '3'),
    );
    // A key this build lacks, or a missing arg, keeps the English.
    await desktop.deliver(
      client,
      envelope(
        id: 'n2',
        localization: {
          'titleKey': 'push.title.unknown',
          'bodyKey': 'push.body.sender_attachments',
          'bodyArgs': ['Ada'],
        },
      ),
    );
    expect(service.shown.last.title, 'Thread in #general · Alpha');
    expect(service.shown.last.body, 'Ada: ship it');
  });
}
