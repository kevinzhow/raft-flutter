import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/background_inbox.dart';
import 'package:raft_flutter/platform/desktop_inbox_notifications.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/macos_dock_unread.dart';
import 'package:raft_flutter/platform/windows_tray.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.example',
        sessionStore: MemorySessionStore(),
        clientKind: 'desktop',
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  @override
  bool get signedIn => user != null;
  int directoryReads = 0, inboxReads = 0;
  final reads = <String>[];
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }

  Completer<dynamic>? policy;
  bool muted = false;
  String mode = 'all';
  List<Map<String, dynamic>> rows = [];
  @override
  Future<List<RaftRecord>> servers() async {
    directoryReads++;
    throw StateError('Workspace already owns this directory.');
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    if (path.endsWith('/notification-settings')) {
      return policy?.future ??
          {'serverPushMode': mode, 'serverPushMuted': muted};
    }
    if (path == '/channels/inbox') {
      inboxReads++;
      return {'items': rows};
    }
    throw StateError('Unexpected notification read: $path');
  }
}

class _Notifications extends NativeNotificationService {
  _Notifications(TargetPlatform platform) : super(platform: platform) {
    enabled = permitted = available = initialized = true;
  }
  bool allowed = true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
  final sent = <Map<String, dynamic>>[];
  @override
  Future<void> refreshPermission() async {
    enabled = permitted = allowed;
    notifyListeners();
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
    int? unread,
    bool quiet = false,
    String? conversation,
  }) async {
    if (allowed) {
      sent.add(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    }
  }
}

class _Storage extends BackgroundInboxStore {
  final states = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> state(String scope) async => states[scope];
  @override
  Future<void> save(String scope, Map<String, dynamic> state) async =>
      states[scope] = state;
}

Map<String, dynamic> _row(String id, {bool old = false}) => {
  'kind': 'dm',
  'channelId': 'c',
  'channelName': 'Carol',
  'lastMessageId': id,
  'lastMessagePreview': 'Hello',
  'unreadCount': 1,
  'lastMessageAt': old ? '2026-10-10T23:59:00Z' : '2026-10-11T00:00:01Z',
};

void main() {
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    group('$platform', () {
      late _Client client;
      late WorkspaceController w;
      late _Notifications notifications;
      late DesktopInboxNotifications desktop;
      void setup() {
        client = _Client();
        w = WorkspaceController(client, ownsClient: false)
          ..server = RaftRecord({'id': 's', 'role': 'owner'});
        w.activityUnread.start();
        notifications = _Notifications(platform);
        desktop = DesktopInboxNotifications(
          notifications: notifications,
          storage: _Storage(),
          clock: () => DateTime.utc(2026, 10, 11),
        )..bind(w);
      }

      void close() {
        desktop.dispose();
        w.dispose();
      }

      tearDown(() async {
        close();
        notifications.dispose();
        await client.dispose();
      });
      Future<void> accept(
        WidgetTester t,
        List<Map<String, dynamic>> rows,
      ) async {
        w.activityUnread.acceptWindow({
          'items': rows,
        }, scope: w.activityUnread.scope);
        await t.pump();
        await desktop.deliverPending();
      }

      Future<void> background(WidgetTester t) async {
        w.setForeground(false);
        await t.pump();
        await desktop.prepared;
      }

      if (platform == TargetPlatform.windows) {
        test('native tray hide after resume delivers a newly accepted DM without reading it', () async {
          setup();
          const channel = MethodChannel('test/windows-tray-inbox');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            channel,
            (_) async => {'available': true},
          );
          const windowChannel = MethodChannel('app.raft/windows-notifications');
          messenger.setMockMethodCallHandler(windowChannel, (_) async => true);
          addTearDown(
            () => messenger.setMockMethodCallHandler(windowChannel, null),
          );
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
          final coordinator = NativeContentCoordinator(
            notifications: notifications,
            links: const Stream.empty(),
            dockUnread: MacOSDockUnread(platform: TargetPlatform.linux),
            tray: WindowsTray(platform: platform, channel: channel),
          );
          await coordinator.init();
          coordinator.desktop!.dispose();
          coordinator.desktop = desktop;
          coordinator.onForegroundChanged = () =>
              w.setForeground(coordinator.appForeground);
          coordinator.bindWorkspace(w);
          coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
          expect(notifications.deliveryAllowed!(), false);
          final hidden = Completer<void>();
          messenger.handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('hidden', true),
            ),
            (_) => hidden.complete(),
          );
          await hidden.future;
          await desktop.prepared;
          expect(w.foreground, false);
          expect(coordinator.appForeground, false);
          w.activityUnread.acceptWindow({
            'items': [_row('after-tray-hide')],
          }, scope: w.activityUnread.scope);
          await desktop.deliverPending();
          expect(notifications.sent, hasLength(1));
          expect(
            notifications.sent.single['uri'],
            contains('/messages/after-tray-hide'),
          );
          expect(client.reads, ['/servers/s/notification-settings']);
          expect(w.activityUnread.totalUnreadCount, 1);
          coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
          expect(coordinator.appForeground, true);
          expect(w.foreground, true);
          expect(notifications.deliveryAllowed!(), false);
          w.activityUnread.acceptWindow({
            'items': [_row('after-tray-restore')],
          }, scope: w.activityUnread.scope);
          await desktop.deliverPending();
          expect(notifications.sent, hasLength(1));
          expect(client.directoryReads, 0);
          expect(client.inboxReads, 0);
          await coordinator.dispose();
        });
      }

      testWidgets(
        'accepted inbox reused: foreground and old backlog silent; new DM delivered once without inbox or directory reads',
        (t) async {
          setup();
          await accept(t, [_row('foreground')]);
          expect(client.reads, isEmpty);
          expect(notifications.sent, isEmpty);
          await background(t);
          await accept(t, [_row('old', old: true), _row('new')]);
          expect(notifications.sent, hasLength(1));
          expect(notifications.sent.single['principal'], 'alice');
          expect(notifications.sent.single['uri'], contains('/messages/new'));
          expect(client.directoryReads, 0);
          expect(client.inboxReads, 0);
          expect(client.clientKind, 'desktop');
          await accept(t, [_row('new')]);
          expect(notifications.sent, hasLength(1));
          // Existing unread owner has a one-shot boot read, no notification timer.
          await t.pump(const Duration(seconds: 2));
          final reads = client.reads.length;
          await t.pump(const Duration(minutes: 2));
          expect(client.reads.length, reads);
          w.setForeground(true);
          await accept(t, [_row('another')]);
          expect(notifications.sent, hasLength(1));
          close();
        },
      );

      for (final change in [
        'foreground',
        'account',
        'server',
        'role',
        'logout',
      ]) {
        testWidgets('$change during OS policy fetch retires private alert', (
          t,
        ) async {
          setup();
          await background(t);
          client.policy = Completer();
          w.activityUnread.acceptWindow({
            'items': [_row('new')],
          }, scope: w.activityUnread.scope);
          await t.pump();
          expect(client.reads, ['/servers/s/notification-settings']);
          switch (change) {
            case 'foreground':
              w.setForeground(true);
            case 'account':
              client.user = RaftRecord({'id': 'bob'});
            case 'server':
              client.selectServer('other');
            case 'role':
              w.server = RaftRecord({'id': 's', 'role': 'guest'});
            case 'logout':
              client.user = null;
          }
          w.notifyListeners();
          client.policy!.complete({'serverPushMode': 'all'});
          await t.pump();
          await desktop.deliverPending();
          expect(notifications.sent, isEmpty);
          close();
        });
      }

      testWidgets(
        'shared socket ingress refreshes once and posts from accepted projection',
        (t) async {
          setup();
          await background(t);
          client.rows = [_row('new')];
          // The badge and platform service use precisely the same data owner.
          for (var i = 0; i < 20; i++) {
            client.ingress.add(
              RaftEvent('message:new', {
                'id': 'new',
                'channelId': 'c',
                'seq': '1',
                'senderId': 'carol',
                'senderType': 'user',
              }),
            );
          }
          await t.pump(const Duration(milliseconds: 150));
          await desktop.deliverPending();
          expect(client.inboxReads, 1);
          expect(notifications.sent, hasLength(1));
          expect(w.activityUnread.totalUnreadCount, 1);
          close();
        },
      );

      testWidgets(
        'Done, unfollow, personal mentions, mute and OS revocation keep server eligibility',
        (t) async {
          setup();
          await background(t);
          client.mode = 'mentions';
          await accept(t, [
            _row('ordinary'),
            {..._row('done'), 'doneAt': '2026-10-11T00:00:02Z'},
            {
              ..._row('mention'),
              'hasMention': true,
              'firstMentionMessageId': 'mention',
            },
            {
              'kind': 'thread',
              'parentChannelId': 'c',
              'parentMessageId': 'p',
              'threadChannelId': 'thread',
              'latestActivityMessageId': 'unfollowed',
              'lastActivityAt': '2026-10-11T00:00:01Z',
              'unreadCount': 1,
              'isFollowing': false,
            },
          ]);
          expect(
            notifications.sent.map((p) => p['uri']).single,
            contains('/messages/mention'),
          );
          client.muted = true;
          await accept(t, [
            {
              ..._row('muted'),
              'hasMention': true,
              'firstMentionMessageId': 'muted',
            },
          ]);
          expect(notifications.sent, hasLength(1));
          client.muted = false;
          notifications.allowed = false;
          await notifications.refreshPermission();
          final before = client.reads.length;
          await accept(t, [
            {
              ..._row('revoked'),
              'hasMention': true,
              'firstMentionMessageId': 'revoked',
            },
          ]);
          expect(notifications.sent, hasLength(1));
          expect(client.reads.length, before);
          close();
        },
      );
    });
  }
}
