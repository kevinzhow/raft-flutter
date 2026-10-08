import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/background_inbox.dart';
import 'package:raft_flutter/platform/background_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.example',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  @override
  bool get signedIn => user != null;
  bool muted = false;
  String mode = 'all';
  Completer<dynamic>? page;
  List<Map<String, dynamic>> rows = [];
  final reads = <String>[];
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'serverPushMuted': muted}),
  ];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    if (path.endsWith('/notification-settings')) {
      return {'serverPushMode': mode};
    }
    return page?.future ?? {'items': rows};
  }
}

Map<String, dynamic> row(String id, {String? at, int unread = 1}) => {
  'kind': 'channel',
  'channelId': 'c',
  'channelName': 'general',
  'lastMessageId': id,
  'lastMessageAt': at ?? '2026-10-08T01:00:01Z',
  'lastMessagePreview': 'New message',
  'unreadCount': unread,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late BackgroundInboxStore store;
  late String scope;
  late List<String> sent;
  late BackgroundInboxPoller poller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    store = BackgroundInboxStore();
    scope = notificationScope(client);
    sent = [];
    await store.select(scope);
    await (await SharedPreferences.getInstance()).setBool(
      notificationPreferenceKey(scope),
      true,
    );
    await store.save(scope, {
      'since': '2026-10-08T01:00:00Z',
      'seen': <String>[],
    });
    poller = BackgroundInboxPoller(
      client: client,
      store: store,
      authorize: (target, valid) async {
        expect(valid(), true);
      },
      deliver: (alert, selected) async {
        sent.add(alert.target.messageId!);
        return true;
      },
    );
  });
  tearDown(() => client.dispose());
  test('new unread activity delivers once across subsequent headless instances; old backlog and read rows do not', () async {
    client.rows = [
      row('old', at: '2026-10-07T00:00:00Z'),
      row('read', unread: 0),
      row('new'),
    ];
    await poller.run();
    await poller.run();
    expect(sent, ['new']);
    expect(await BackgroundInboxStore().seen(scope, 'new'), true);
    expect(
      client.reads.every(
        (p) => p == '/channels/inbox' || p.endsWith('/notification-settings'),
      ),
      true,
    );
  });
  test('server mentions-only never promotes an ordinary latest message or incomplete mention evidence', () async {
    client.mode = 'mentions';
    client.rows = [
      row('ordinary'),
      {...row('later'), 'hasMention': true, 'firstMentionMessageId': 'earlier'},
      {
        ...row('personal'),
        'hasMention': true,
        'firstMentionMessageId': 'personal',
      },
    ];
    await poller.run();
    expect(sent, ['personal']);
  });
  test('workspace change during fetch cannot alert', () async {
    client.page = Completer();
    final pending = poller.run();
    while (!client.reads.contains('/channels/inbox')) {
      await Future<void>.delayed(Duration.zero);
    }
    client.selectServer('other');
    client.page!.complete({
      'items': [row('new')],
    });
    await pending;
    expect(sent, isEmpty);
  });
  test(
    'disable during fetch prevents alerts without altering read state',
    () async {
      client.page = Completer();
      final pending = poller.run();
      while (!client.reads.contains('/channels/inbox')) {
        await Future<void>.delayed(Duration.zero);
      }
      await (await SharedPreferences.getInstance()).setBool(
        notificationPreferenceKey(scope),
        false,
      );
      client.page!.complete({
        'items': [row('new')],
      });
      await pending;
      expect(sent, isEmpty);
    },
  );
  test(
    'server mute and mismatched account do not fetch private inbox',
    () async {
      client.muted = true;
      await poller.run();
      expect(client.reads, isEmpty);
      client.muted = false;
      client.user = RaftRecord({'id': 'bob'});
      await poller.run();
      expect(client.reads, isEmpty);
    },
  );
  test(
    'Done after initial fetch suppresses alert after fresh projection',
    () async {
      client.rows = [row('new')];
      poller = BackgroundInboxPoller(
        client: client,
        store: store,
        authorize: (target, valid) async {
          client.rows = [];
        },
        deliver: (alert, selected) async {
          sent.add(alert.target.messageId!);
          return true;
        },
      );
      await poller.run();
      expect(sent, isEmpty);
    },
  );
  test(
    'unauthorized context fails closed and delivery failure remains retryable',
    () async {
      client.rows = [row('new')];
      poller = BackgroundInboxPoller(
        client: client,
        store: store,
        authorize: (target, valid) async {
          throw const RaftApiException('Forbidden');
        },
        deliver: (alert, selected) async {
          sent.add('invalid');
          return true;
        },
      );
      await expectLater(poller.run(), throwsA(isA<RaftApiException>()));
      expect(sent, isEmpty);
      poller = BackgroundInboxPoller(
        client: client,
        store: store,
        authorize: (target, valid) async {},
        deliver: (alert, scope) async => false,
      );
      await poller.run();
      expect(await store.seen(scope, 'new'), false);
    },
  );
  test('thread payload respects independent follow and personal mention; notification ID stable across processes and scopes', () {
    final r = {
      'kind': 'thread',
      'threadChannelId': 't',
      'parentChannelId': 'c',
      'parentMessageId': 'p',
      'latestActivityMessageId': 'm',
      'lastActivityAt': '2026-10-08T01:00:01Z',
      'unreadCount': 1,
      'isFollowing': false,
    };
    expect(
      BackgroundInboxAlert.fromRow(r, 's', DateTime.utc(2026, 10, 8, 1)),
      isNull,
    );
    final alert = BackgroundInboxAlert.fromRow(
      {...r, 'hasMention': true},
      's',
      DateTime.utc(2026, 10, 8, 1),
    )!;
    expect(alert.target.nativeUri('s').queryParameters['parentMessageId'], 'p');
    expect(
      messageNotificationId(scope, 'm'),
      messageNotificationId(scope, 'm'),
    );
    expect(
      messageNotificationId(scope, 'm'),
      isNot(messageNotificationId('$scope-other', 'm')),
    );
  });
  test('UI startup waits for existing worker session owner and delegates subsequent polling to one owner', () async {
    final worker = NativeSessionOwner(supported: true);
    await worker.acquire();
    final calls = <String>[];
    final ui = NativeSessionOwner(
      supported: true,
      poll: () async {
        calls.add('ui');
        return true;
      },
    );
    var acquired = false;
    final waiting = ui.acquire().then((_) => acquired = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(acquired, false);
    worker.release();
    await waiting;
    expect(acquired, true);
    final port = ReceivePort();
    IsolateNameServer.lookupPortByName('raft.native.session-owner.v1')!
        .send(['poll', port.sendPort]);
    expect(await port.first, true);
    expect(calls, ['ui']);
    port.close();
    ui.release();
  });
}
