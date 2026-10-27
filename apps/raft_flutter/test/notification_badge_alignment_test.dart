import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/activity_attention.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/macos_dock_unread.dart';
import 'package:raft_flutter/platform/desktop_inbox_notifications.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/notification_reconciler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The numbers that must line up: the app icon badge, the system notification
/// set and the in-app Activity badge all follow the accepted Activity window.

class _Android extends AndroidFlutterLocalNotificationsPlugin {
  @override
  Future<bool?> areNotificationsEnabled() async => true;
  @override
  Future<bool?> requestNotificationsPermission() async => true;
}

class _Mac extends MacOSFlutterLocalNotificationsPlugin {
  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool providesAppNotificationSettings = false,
  }) async => true;
  @override
  Future<NotificationsEnabledOptions?> checkPermissions() async =>
      const NotificationsEnabledOptions(
        isEnabled: true,
        isSoundEnabled: true,
        isAlertEnabled: true,
        isBadgeEnabled: true,
        isProvisionalEnabled: false,
        isCriticalEnabled: false,
        isProvidesAppNotificationSettingsEnabled: false,
      );
}

class FixturePlugin implements FlutterLocalNotificationsPlugin {
  final android = _Android();
  final mac = _Mac();
  final live = <int, ({String? title, String? body, NotificationDetails? d})>{};
  final cancelled = <int>[];
  int cancelAlls = 0;
  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => T == AndroidFlutterLocalNotificationsPlugin
      ? android as T
      : T == MacOSFlutterLocalNotificationsPlugin
      ? mac as T
      : null;
  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async =>
      const NotificationAppLaunchDetails(false);
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;
  @override
  Future<void> cancelAll() async {
    cancelAlls++;
    live.clear();
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled.add(id);
    live.remove(id);
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    live[id] = (title: title, body: body, d: notificationDetails);
  }

  /// What the launcher counts: the numbers of the non-summary notifications
  /// (Launcher3 skips group summaries; a notification without a number is 1).
  int get launcherBadge => live.values
      .where((n) => n.d?.android?.setAsGroupSummary != true)
      .fold(0, (sum, n) => sum + (n.d?.android?.number ?? 1));
  List<({String? title, String? body, NotificationDetails? d})> get children =>
      live.values
          .where((n) => n.d?.android?.setAsGroupSummary != true)
          .toList();
  bool get hasSummary =>
      live.values.any((n) => n.d?.android?.setAsGroupSummary == true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureClient extends RaftClient {
  FixtureClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
  @override
  Future<dynamic> accountUnreadSummary() => get('/servers/unread-summary');
  @override
  bool get signedIn => user != null;
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }

  List<RaftRecord> Function()? memberRead;
  @override
  Future<List<RaftRecord>> accountServers() async =>
      memberRead?.call() ??
      [
        RaftRecord({'id': 's1'}),
      ];
  Object settings = {'serverPushMode': 'all', 'serverPushMuted': false};
  final requests = <String>[];
  List<Object> summary = [];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    requests.add(path);
    if (path == '/servers/unread-summary') return summary;
    if (path.endsWith('/notification-settings')) {
      return settings;
    }
    return {'items': []};
  }
}

Map<String, Object?> row(
  String id,
  int unread, {
  String kind = 'channel',
  bool mention = false,
  String? frontier,
  String? doneAt,
}) => {
  'kind': kind,
  if (kind == 'thread') ...{
    'threadChannelId': id,
    'parentChannelId': 'p-$id',
    'parentMessageId': 'pm-$id',
    'latestActivityMessageId': 'm-$id',
    'lastActivityAt': '2026-10-14T10:00:00Z',
    'parentChannelName': 'general',
    'isFollowing': true,
  } else ...{
    'channelId': id,
    'lastMessageId': 'm-$id',
    'lastMessageAt': '2026-10-14T10:00:00Z',
    'channelName': kind == 'dm' ? 'Ada' : 'general-$id',
    'lastMessagePreview': 'hello from $id',
    'lastMessageSenderName': 'Ada',
  },
  'unreadCount': unread,
  'hasMention': mention,
  'doneAt': doneAt,
  if (frontier != null)
    'readState': {
      'kind': 'present',
      'latestActivity': {'seq': frontier},
    },
};

class BadgeRig {
  BadgeRig(this.w, this.client, this.plugin, this.service, this.reconciler);
  final WorkspaceController w;
  final FixtureClient client;
  final FixturePlugin plugin;
  final NativeNotificationService service;
  final NotificationReconciler reconciler;

  /// The accepted Activity window, as the in-app badge sees it.
  void window(List<Map<String, Object?>> rows, {int? total}) {
    w.activityUnread.acceptWindow({
      'items': rows,
      'totalUnreadCount':
          total ??
          rows.fold<int>(0, (sum, r) => sum + (r['unreadCount']! as int)),
    }, scope: w.activityUnread.scope);
  }

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await reconciler.settled;
    await service.idle;
    await reconciler.settled;
  }

  /// A socket push alert, as the coordinator delivers it.
  Future<void> alert(String id, int unread, {String kind = 'channel'}) {
    final uri = switch (kind) {
      'thread' =>
        'raft://v1/servers/s1/channels/p-$id/threads/$id?parentMessageId=pm-$id&messageId=m-$id',
      'dm' => 'raft://v1/servers/s1/dms/$id/messages/m-$id',
      _ => 'raft://v1/servers/s1/channels/$id/messages/m-$id',
    };
    return service.show(
      title: '#general-$id',
      body: 'Ada: hello from $id',
      payload: jsonEncode({
        'origin': 'https://fixture.invalid',
        'principal': 'alice',
        'serverId': 's1',
        'uri': uri,
      }),
      unread: unread,
    );
  }
}

Future<BadgeRig> rig({TargetPlatform platform = TargetPlatform.android}) async {
  SharedPreferences.setMockInitialValues({});
  final client = FixtureClient();
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  client.memberRead = () => w.servers.isEmpty ? [w.server!] : w.servers;
  final plugin = FixturePlugin();
  final service = NativeNotificationService(plugin: plugin, platform: platform);
  service.deliveryAllowed = () => !w.foreground;
  await service.bind('https://fixture.invalid\nalice\ns1');
  await service.requestEnable(true);
  final reconciler = NotificationReconciler(notifications: service);
  // The session owns the projection; the reconciler only follows.
  w.activityUnread;
  addTearDown(() {
    reconciler.dispose();
    service.dispose();
    w.dispose();
  });
  w.setForeground(false);
  reconciler.bind(w);
  return BadgeRig(w, client, plugin, service, reconciler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android allowed residual uses the account sum and follows other-server reads', () async {
    final r = await rig();
    r.w.servers = [
      r.w.server!,
      RaftRecord({'id': 's2', 'role': 'member'}),
    ];
    r.client.summary = [
      {'serverId': 's1', 'activityUnreadCount': 2},
      {'serverId': 's2', 'activityUnreadCount': 4},
    ];
    r.w.notifyListeners();
    r.window([row('c1', 2)]);
    await r.settle();
    expect(r.plugin.launcherBadge, 6);
    r.client.summary = [
      {'serverId': 's1', 'activityUnreadCount': 2},
      {'serverId': 's2', 'activityUnreadCount': 0},
    ];
    await r.reconciler.accountUnread.refresh();
    await r.settle();
    expect(r.plugin.launcherBadge, 2);
    r.client.summary = [
      {'serverId': 's1', 'activityUnreadCount': 2},
      {'serverId': 's2', 'activityUnreadCount': 4},
    ];
    await r.reconciler.accountUnread.refresh();
    await r.settle();
    expect(r.plugin.launcherBadge, 6);
    r.w.servers.removeWhere((s) => s.id == 's2');
    r.w.notifyListeners();
    await r.settle();
    expect(r.plugin.launcherBadge, 2);
  });

  group('the counting rule', () {
    test('sums member servers; the open server uses its live window', () {
      final summary = {'s1': 10, 's2': 3, 's3': null, 'gone': 90};
      expect(
        activityBadgeTotal(
          currentServerId: 's1',
          currentTotal: 2,
          memberServerIds: ['s1', 's2', 's3'],
          summaryCount: (id) => summary[id],
        ),
        5,
        reason: 's1 live 2 + s2 3 + unknown s3 0; a non-member never counts',
      );
      expect(
        activityBadgeTotal(
          currentServerId: 's1',
          currentTotal: null,
          memberServerIds: ['s2'],
          summaryCount: (id) => summary[id],
        ),
        13,
        reason: 'before the window is accepted the summary stands in',
      );
    });

    test('a row counts unread messages, never conversations', () {
      final rows = [row('c1', 4), row('c2', 0), row('c3', 2, doneAt: 'x')];
      expect(activityRowUnread(rows, 'c1'), 4);
      expect(activityRowUnread(rows, 'c2'), 0);
      expect(activityRowUnread(rows, 'c3'), 0, reason: 'Done is read');
      expect(activityRowUnread(rows, 'missing'), isNull);
      expect(
        activityRowUnread([row('t1', 3, kind: 'thread')], 't1'),
        3,
        reason: 'a thread row is its own channel',
      );
    });
  });

  group('one notification per conversation', () {
    test(
      'a later message replaces the conversation, counts follow Activity',
      () async {
        final r = await rig();
        await r.alert('c1', 1);
        await r.alert('c1', 2);
        await r.alert('c1', 3);
        await r.alert('c2', 1);
        expect(r.plugin.children, hasLength(2), reason: 'not one per message');
        expect(r.plugin.hasSummary, isTrue);
        expect(r.plugin.launcherBadge, 4);
        expect(r.service.liveUnread, {'c1': 3, 'c2': 1});
        final c1 = r.plugin.children.first.d!.android!;
        expect(c1.number, 3);
        expect(c1.groupKey, startsWith('raft.messages.'));
        expect(c1.onlyAlertOnce, isFalse, reason: 'a new message alerts');
      },
    );

    test('a thread and its channel are different conversations', () async {
      final r = await rig();
      await r.alert('t1', 1, kind: 'thread');
      await r.alert('t1', 2, kind: 'thread');
      await r.alert('c1', 1);
      expect(r.service.liveUnread, {'t1': 2, 'c1': 1});
    });

    test('a DM keeps its own notification', () async {
      final r = await rig();
      await r.alert('d1', 2, kind: 'dm');
      await r.alert('c1', 1);
      expect(r.service.liveUnread, {'d1': 2, 'c1': 1});
    });
  });

  group('cancel on read', () {
    test(
      'local read: the conversation window row reaching 0 removes it',
      () async {
        final r = await rig();
        await r.alert('c1', 2);
        await r.alert('c2', 1);
        r.window([row('c1', 2), row('c2', 1)]);
        await r.settle();
        expect(r.plugin.launcherBadge, 3);
        // The app reads c1 (the persisted read refreshes the window).
        r.window([row('c1', 0), row('c2', 1)]);
        await r.settle();
        expect(r.service.liveUnread, {'c2': 1});
        expect(r.plugin.launcherBadge, 1);
        expect(r.w.activityUnread.totalUnreadCount, 1);
        expect(r.plugin.hasSummary, isTrue);
      },
    );

    test(
      'remote read event: another device reading clears the shade',
      () async {
        final r = await rig();
        await r.alert('c1', 2);
        await r.alert('c2', 1);
        r.window([row('c1', 2, frontier: '5'), row('c2', 1, frontier: '9')]);
        await r.settle();
        expect(r.plugin.launcherBadge, 3);
        // read_state:updated from the Web / another phone: c1 read to seq 5.
        r.client.ingress.add(
          RaftEvent('read_state:updated', {
            'serverId': 's1',
            'scopeId': 'c1',
            'maxReadSeq': 5,
            'readStateVersion': 1,
          }),
        );
        await r.settle();
        expect(r.service.liveUnread, {'c2': 1});
        expect(r.plugin.launcherBadge, 1);
        expect(r.w.activityUnread.totalUnreadCount, 1);
      },
    );

    test(
      'mark all read: a total of 0 removes every notification and the summary',
      () async {
        final r = await rig();
        await r.alert('c1', 2);
        await r.alert('c2', 1);
        await r.alert('t1', 1, kind: 'thread');
        r.window([row('c1', 2), row('c2', 1), row('t1', 1, kind: 'thread')]);
        await r.settle();
        expect(r.plugin.launcherBadge, 4);
        r.window([row('c1', 0), row('c2', 0), row('t1', 0, kind: 'thread')]);
        await r.settle();
        expect(r.service.liveUnread, isEmpty);
        expect(r.plugin.live, isEmpty, reason: 'no children and no summary');
        expect(r.plugin.launcherBadge, 0);
      },
    );

    test(
      'a server total of 0 removes notifications the window no longer lists',
      () async {
        final r = await rig();
        await r.alert('old', 3);
        r.window([], total: 0);
        await r.settle();
        expect(r.service.liveUnread, isEmpty);
        expect(r.plugin.live, isEmpty);
      },
    );

    test('Done removes it; absence from a bounded window does not', () async {
      final r = await rig();
      await r.alert('c1', 2);
      await r.alert('c2', 1);
      r.window([row('c1', 2, doneAt: '2026-10-14T10:05:00Z')], total: 1);
      await r.settle();
      expect(r.service.liveUnread, {
        'c2': 1,
      }, reason: 'c1 is Done; c2 unlisted');
    });

    test('nothing is cancelled before a window is accepted', () async {
      final r = await rig();
      await r.alert('c1', 2);
      r.w.notifyListeners();
      await r.settle();
      expect(r.service.liveUnread, {'c1': 2});
    });
  });

  group('count changes', () {
    test('a moved count refreshes in place without an alert', () async {
      final r = await rig();
      await r.alert('c1', 1);
      r.window([row('c1', 3)]);
      await r.settle();
      expect(r.service.liveUnread, {'c1': 3});
      expect(r.plugin.launcherBadge, 3);
      final android = r.plugin.children.single.d!.android!;
      expect(android.number, 3);
      expect(android.onlyAlertOnce, isTrue);
      expect(
        android.channelId,
        'raft_messages_v1',
        reason: 'an alert that already popped up stays where it is',
      );
    });

    test(
      'a count refresh is allowed while the app is in the foreground',
      () async {
        final r = await rig();
        await r.alert('c1', 1);
        r.w.setForeground(true);
        r.window([row('c1', 2)]);
        await r.settle();
        expect(r.service.liveUnread, {'c1': 2});
      },
    );
  });

  group('Android backlog: badge equals the Activity total', () {
    test('unread conversations without a notification get a quiet one when backgrounded', () async {
      final r = await rig();
      r.window([row('c1', 4), row('c2', 0), row('d1', 2, kind: 'dm')]);
      await r.settle();
      expect(r.service.liveUnread, {'c1': 4, 'd1': 2});
      expect(r.plugin.launcherBadge, r.w.activityUnread.totalUnreadCount);
      for (final n in r.plugin.children) {
        expect(n.d!.android!.channelId, 'raft_unread_v1');
        expect(n.d!.android!.importance, Importance.low, reason: 'no alert');
      }
    });

    test('nothing is posted while the app is in the foreground', () async {
      final r = await rig();
      r.w.setForeground(true);
      r.window([row('c1', 4)]);
      await r.settle();
      expect(r.plugin.live, isEmpty);
      r.w.setForeground(false);
      await r.settle();
      expect(r.service.liveUnread, {'c1': 4}, reason: 'restored on background');
    });

    test(
      'unread beyond the Activity window is one more quiet notification',
      () async {
        final r = await rig();
        // The server counts 30 unread; the first page lists 13 of them.
        r.window([row('d1', 13, kind: 'dm'), row('c2', 0)], total: 30);
        await r.settle();
        expect(r.service.liveUnread, {
          'd1': 13,
          NotificationReconciler.moreKey: 17,
        });
        expect(r.plugin.launcherBadge, 30, reason: 'the Activity total');
        final more = r.plugin.children.firstWhere((n) => n.title == 'Raft');
        expect(more.d!.android!.channelId, 'raft_unread_v1');
        expect(more.body, '17 unread');
        // Reading the DM elsewhere leaves the unlisted 17.
        r.window([row('d1', 0), row('c2', 0)], total: 17);
        await r.settle();
        expect(r.plugin.launcherBadge, 17);
        expect(r.service.liveUnread, {NotificationReconciler.moreKey: 17});
        // Mark all read.
        r.window([row('d1', 0), row('c2', 0)], total: 0);
        await r.settle();
        expect(r.plugin.live, isEmpty);
      },
    );

    test('mentions-only and a muted server post no backlog', () async {
      final r = await rig();
      r.client.settings = {
        'serverPushMode': 'mentions',
        'serverPushMuted': false,
      };
      r.window([row('c1', 4), row('c2', 2, mention: true)]);
      await r.settle();
      expect(r.service.liveUnread, {'c2': 2}, reason: 'no residual either');
      final muted = await rig();
      muted.client.settings = {
        'serverPushMode': 'all',
        'serverPushMuted': true,
      };
      muted.window([row('c1', 4)]);
      await muted.settle();
      expect(muted.plugin.live, isEmpty);
    });

    test('a signed-out or disabled service posts nothing', () async {
      final r = await rig();
      await r.service.requestEnable(false);
      r.window([row('c1', 4)]);
      await r.settle();
      expect(r.plugin.live, isEmpty);
    });
  });

  test('the reconciler borrows a passive session projection', () async {
    SharedPreferences.setMockInitialValues({});
    final client = FixtureClient();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    final store = w.activityUnread;
    final service = NativeNotificationService(
      plugin: FixturePlugin(),
      platform: TargetPlatform.android,
    );
    final reconciler = NotificationReconciler(notifications: service);
    addTearDown(() {
      reconciler.dispose();
      service.dispose();
      w.dispose();
    });
    reconciler.bind(w);
    w.notifyListeners();
    await reconciler.settled;
    expect(w.activityUnreadIfBound, same(store));
    expect(store.hasAcceptedWindow, isFalse);
    reconciler.dispose();
    expect(w.activityUnreadIfBound, same(store));
    store.acceptWindow({
      'items': [],
      'totalUnreadCount': 3,
    }, scope: store.scope);
    expect(store.totalUnreadCount, 3);
    w.dispose();
    expect(w.activityUnreadIfBound, isNull);
    expect(store.hasAcceptedWindow, isFalse);
  });

  testWidgets('notification followers do not create or activate Activity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = FixtureClient();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    final service = NativeNotificationService(
      plugin: FixturePlugin(),
      platform: TargetPlatform.android,
    );
    final desktop = DesktopInboxNotifications(notifications: service)..bind(w);
    final reconciler = NotificationReconciler(notifications: service)..bind(w);
    final badge = MacOSDockUnread(
      platform: TargetPlatform.iOS,
      write: (_) async {},
    )..bind(w);
    try {
      await tester.pump(const Duration(seconds: 3));
      expect(w.activityUnreadIfBound, isNull);
      expect(
        client.requests.every((path) => path == '/servers/unread-summary'),
        isTrue,
      );
      final store = w.activityUnread;
      w.notifyListeners();
      await tester.pump(const Duration(seconds: 3));
      expect(w.activityUnreadIfBound, same(store));
      expect(
        client.requests.where((path) => path == '/channels/inbox'),
        isEmpty,
      );
      expect(store.hasAcceptedWindow, isFalse);
    } finally {
      desktop.dispose();
      reconciler.dispose();
      await badge.dispose();
      service.dispose();
      w.dispose();
    }
  });

  group('app icon badge (iOS)', () {
    test('follows the Activity badge on every change', () async {
      final client = FixtureClient();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
      w.activityUnread;
      addTearDown(w.dispose);
      client.summary = [
        {'serverId': 's1', 'unreadCount': 99, 'activityUnreadCount': 7},
      ];
      final writes = <int>[];
      final badge = MacOSDockUnread(
        platform: TargetPlatform.iOS,
        write: (count) async => writes.add(count),
      );
      addTearDown(badge.dispose);
      badge.bind(w);
      await badge.refresh();
      await badge.settled;
      expect(writes.last, 7, reason: 'before the window: the summary');
      w.activityUnread.acceptWindow({
        'items': [row('c1', 2), row('c2', 1)],
        'totalUnreadCount': 3,
      }, scope: w.activityUnread.scope);
      await badge.settled;
      expect(writes.last, 3, reason: 'the in-app Activity badge number');
      w.activityUnread.acceptWindow({
        'items': [row('c1', 0), row('c2', 1)],
        'totalUnreadCount': 1,
      }, scope: w.activityUnread.scope);
      await badge.settled;
      expect(writes.last, 1);
      w.activityUnread.acceptWindow({
        'items': [row('c1', 0), row('c2', 0)],
        'totalUnreadCount': 0,
      }, scope: w.activityUnread.scope);
      await badge.settled;
      expect(writes.last, 0, reason: 'mark all read clears the icon');
      badge.bind(null);
      await badge.settled;
      expect(writes.last, 0);
    });

    test('is not a badge on platforms whose launcher counts notifications', () {
      final badge = MacOSDockUnread(
        platform: TargetPlatform.android,
        write: (_) async => fail('Android launchers sum the notifications'),
      );
      expect(badge.supported, isFalse);
      addTearDown(badge.dispose);
    });
  });

  test(
    'desktop: Linux/macOS also replace per conversation and cancel on read',
    () async {
      for (final platform in [TargetPlatform.linux, TargetPlatform.macOS]) {
        final r = await rig(platform: platform);
        await r.alert('c1', 1);
        await r.alert('c1', 2);
        expect(r.plugin.live, hasLength(1), reason: '$platform: in place');
        r.window([row('c1', 0)], total: 0);
        await r.settle();
        expect(r.plugin.live, isEmpty, reason: '$platform: read');
        expect(r.plugin.cancelled, isNotEmpty);
      }
    },
  );
}
