import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/background_inbox.dart';
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
  Future<dynamic> accountUnreadSummary() async => summaryRead != null
      ? await summaryRead!()
      : summary ?? await get('/servers/unread-summary');
  @override
  bool get signedIn => user != null;
  bool muted = false;
  String mode = 'all';
  Completer<dynamic>? page;
  List<Map<String, dynamic>> rows = [];
  List<RaftRecord>? memberships, accountMemberships;
  Object? summary;
  Future<dynamic> Function()? summaryRead;
  int? inboxTotal;
  final reads = <String>[];
  @override
  Future<List<RaftRecord>> accountServers() async =>
      accountMemberships ?? await servers();
  @override
  Future<List<RaftRecord>> servers() async =>
      memberships ??
      [
        RaftRecord({'id': 's', 'serverPushMuted': muted}),
      ];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    if (path.endsWith('/notification-settings')) {
      return {'serverPushMode': mode};
    }
    return page?.future ??
        {'items': rows, if (inboxTotal != null) 'totalUnreadCount': inboxTotal};
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
  test(
    'background badge sums memberships and keeps unknown on summary failure',
    () async {
      client.memberships = [
        RaftRecord({'id': 's'}),
        RaftRecord({'id': 'other'}),
      ];
      client.rows = [row('new', unread: 2)];
      client.inboxTotal = 2;
      client.summary = [
        {'serverId': 's', 'activityUnreadCount': 8},
        {'serverId': 'other', 'activityUnreadCount': 4},
      ];
      await poller.run();
      expect(poller.totalUnread, 6);
      client.summary = [
        {'serverId': 's', 'activityUnreadCount': 8},
        {'serverId': 'other', 'activityUnreadCount': 0},
      ];
      await poller.run();
      expect(poller.totalUnread, 2);
      client.summaryRead = () async => throw StateError('unavailable');
      await poller.run();
      expect(
        poller.totalUnread,
        isNull,
        reason: 'The delivery leaves a known OS badge unchanged, never replacing it with 2.',
      );
    },
  );

  test('background badge does not replace a global badge with a partial member count', () async {
    client.memberships = [
      RaftRecord({'id': 's'}),
      RaftRecord({'id': 'other'}),
    ];
    client.rows = [row('new', unread: 2)];
    client.inboxTotal = 2;
    for (final summary in [
      [
        {'serverId': 's', 'activityUnreadCount': 2},
      ],
      [
        {'serverId': 's', 'activityUnreadCount': 2},
        {'serverId': 'other'},
      ],
      [
        {'serverId': 's', 'activityUnreadCount': 2},
        {'serverId': 'other', 'activityUnreadCount': '4'},
      ],
      <Object>[],
    ]) {
      client.summary = summary;
      await poller.run();
      expect(poller.totalUnread, isNull);
    }
    client.memberships = [
      RaftRecord({'id': 's'}),
    ];
    client.summary = [
      {'serverId': 's', 'activityUnreadCount': 2},
    ];
    await poller.run();
    expect(
      poller.totalUnread,
      2,
      reason: 'Removed membership is not an unknown count.',
    );
  });

  test('headless badge confirms current membership after the summary, not the pre-inbox snapshot', () async {
    client.rows = [row('new', unread: 2)];
    client.inboxTotal = 2;
    client.memberships = [
      RaftRecord({'id': 's'}),
      RaftRecord({'id': 'other'}),
    ];
    client.accountMemberships = [
      RaftRecord({'id': 's'}),
    ];
    client.summary = [
      {'serverId': 's', 'activityUnreadCount': 2},
      {'serverId': 'other', 'activityUnreadCount': 88},
    ];
    await poller.run();
    expect(poller.totalUnread, 2);
    client.memberships = [
      RaftRecord({'id': 's'}),
    ];
    client.accountMemberships = [
      RaftRecord({'id': 's'}),
      RaftRecord({'id': 'other'}),
    ];
    client.summary = [
      {'serverId': 's', 'activityUnreadCount': 2},
      {'serverId': 'other', 'activityUnreadCount': 4},
    ];
    await poller.run();
    expect(poller.totalUnread, 6);
  });

  test(
    'a late background global summary cannot deliver after account retirement',
    () async {
      client.rows = [row('new')];
      final delayed = Completer<dynamic>();
      client.summaryRead = () => delayed.future;
      final running = poller.run();
      await Future<void>.delayed(Duration.zero);
      client.user = null;
      delayed.complete([
        {'serverId': 's', 'activityUnreadCount': 88},
      ]);
      await running;
      expect(sent, isEmpty);
    },
  );

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
        (p) =>
            p == '/channels/inbox' ||
            p == '/servers/unread-summary' ||
            p.endsWith('/notification-settings'),
      ),
      true,
    );
  });
  test('server mentions-only alerts on hasMention with unread, not on firstMentionMessageId equality', () async {
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
    // `later`: firstMentionMessageId is the OLDEST unread mention, so it
    // legitimately differs from the latest message id.
    expect(sent, unorderedEquals(['later', 'personal']));
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
  test('notification copy identifies channel, DM sender and thread without exposing IDs', () {
    final since = DateTime.utc(2026, 10, 8, 1);
    final channel = BackgroundInboxAlert.fromRow(
      {...row('m'), 'lastMessageSenderName': 'Alice'},
      's',
      since,
    )!;
    expect(channel.title, '#general');
    expect(channel.body, 'Alice: New message');
    final dm = BackgroundInboxAlert.fromRow(
      {
        ...row('m'),
        'kind': 'dm',
        'channelName': 'Internal conversation label',
        'lastMessageSenderName': '陈小明',
      },
      's',
      since,
    )!;
    expect(dm.title, '陈小明');
    expect(dm.body, 'New message');
    final thread = BackgroundInboxAlert.fromRow(
      {
        'kind': 'thread',
        'threadChannelId': 't',
        'parentChannelId': 'c',
        'parentChannelName': 'general',
        'parentMessageId': 'p',
        'latestActivityMessageId': 'm',
        'latestActivityPreview': 'A reply',
        'latestActivitySenderName': 'Bob',
        'lastActivityAt': '2026-10-08T01:00:01Z',
        'unreadCount': 1,
        'isFollowing': true,
      },
      's',
      since,
    )!;
    expect(thread.title, '#general · Thread');
    expect(thread.body, 'Bob: A reply');
    expect(thread.target.threadId, 't');
    final unnamed = BackgroundInboxAlert.fromRow(
      {...row('m'), 'kind': 'dm', 'channelName': '  '},
      's',
      since,
    )!;
    expect(unnamed.title, 'Direct message');
    final unicode = BackgroundInboxAlert.fromRow(
      {...row('m'), 'kind': 'dm', 'lastMessageSenderName': '😀' * 161},
      's',
      since,
    )!;
    expect(unicode.title, '😀' * 160);
  });
}
