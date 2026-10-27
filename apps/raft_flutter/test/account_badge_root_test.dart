import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/macos_dock_unread.dart';
import 'package:raft_flutter/platform/native_notifications.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'notification_badge_alignment_test.dart' show FixturePlugin;

class _BadgeContent extends NativeContentCoordinator {
  _BadgeContent(
    List<int> writes, {
    TargetPlatform platform = TargetPlatform.iOS,
    FixturePlugin? plugin,
  }) : super(
         notifications: NativeNotificationService(
           plugin: plugin ?? FixturePlugin(),
           platform: platform,
         ),
         dockUnread: MacOSDockUnread(
           platform: platform,
           write: (value) async {
             writes.add(value);
           },
         ),
         links: const Stream.empty(),
       );
  @override
  Future<void> init({List<String> initialArguments = const []}) async {}
  @override
  Future<void> dispose() async {
    await super.dispose();
    notifications.dispose();
  }
}

void main() {
  testWidgets(
    'actual root keeps the account badge on initial chooser and chooser return, then clears on logout',
    (t) async {
      final writes = <int>[];
      final content = _BadgeContent(writes);
      final f = RootFixture(contentOverride: content);
      f.overrides['GET /servers/unread-summary'] = (_) => [
        {'serverId': 'a', 'activityUnreadCount': 2},
        {'serverId': 'b', 'activityUnreadCount': 4},
      ];
      await f.mount(t, 'light', 390);
      addTearDown(() => f.close(t));
      Future<void> refreshBadge() async {
        var done = false;
        final read = content.dockUnread.refresh().whenComplete(
          () => done = true,
        );
        for (var i = 0; i < 20 && !done; i++) {
          await f.flush(t);
        }
        expect(
          done,
          isTrue,
          reason:
              'Account summary finishes through the root fixture transport.',
        );
        await read;
      }

      await refreshBadge();
      await content.dockUnread.settled;
      expect(find.byType(GlobalServerSelector), findsOneWidget);
      expect(f.client.serverId, isNull);
      expect(
        writes,
        contains(6),
        reason: 'Initial signed-in chooser receives the account count.',
      );
      expect(writes.last, 6);
      final beforeResume = writes.where((value) => value == 6).length;
      content.didChangeAppLifecycleState(AppLifecycleState.inactive);
      content.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await content.dockUnread.settled;
      expect(writes.where((value) => value == 6).length, beforeResume + 1);
      await t.tap(find.byKey(const ValueKey('global-server-a')));
      await f.flush(t);
      final w = f.workspace(t);
      w.activityUnread.acceptWindow({
        'items': [],
        'totalUnreadCount': 2,
      }, scope: w.activityUnread.scope);
      await refreshBadge();
      await content.dockUnread.settled;
      expect(writes.last, 6);
      t.widget<WorkspaceView>(find.byType(WorkspaceView)).onChooseServer!();
      await f.flush(t);
      await content.dockUnread.settled;
      expect(find.byType(GlobalServerSelector), findsOneWidget);
      expect(writes.last, 6);
      w.activityUnread.acceptWindow({
        'items': [],
        'totalUnreadCount': 99,
      }, scope: w.activityUnread.scope);
      await content.dockUnread.settled;
      expect(
        writes.last,
        6,
        reason: 'The account owner dropped its workspace listener.',
      );
      final loggingOut = t
          .widget<GlobalServerSelector>(find.byType(GlobalServerSelector))
          .onLogout();
      var loggedOut = false;
      final retirement = loggingOut.whenComplete(() => loggedOut = true);
      for (var i = 0; i < 20 && !loggedOut; i++) {
        await f.flush(t);
      }
      expect(loggedOut, isTrue);
      await retirement;
      await content.dockUnread.settled;
      expect(writes.last, 0);
    },
  );
  testWidgets(
    'Android chooser retains allowed real cards, updates existing residual and clears on logout',
    (t) async {
      final plugin = FixturePlugin();
      final content = _BadgeContent(
        [],
        platform: TargetPlatform.android,
        plugin: plugin,
      );
      final f = RootFixture(contentOverride: content);
      var other = 4;
      f.overrides['GET /servers/unread-summary'] = (_) => [
        {'serverId': 'a', 'activityUnreadCount': 2},
        {'serverId': 'b', 'activityUnreadCount': other},
      ];
      final unreadRow = <String, Object?>{
        'kind': 'channel',
        'channelId': 'cunread',
        'channelName': 'unread',
        'lastMessageId': 'm-new',
        'lastMessageAt': '2026-10-14T10:00:00Z',
        'lastMessagePreview': 'Unread card',
        'lastMessageSenderName': 'Ada',
        'unreadCount': 2,
        'doneAt': null,
        'readState': {
          'kind': 'present',
          'latestActivity': {'seq': '2'},
        },
      };
      f.overrides['GET /channels/inbox'] = (_) => {
        'items': [unreadRow],
        'totalUnreadCount': 2,
      };
      f.overrides['GET /servers/a/notification-settings'] = (_) => {
        'serverPushMode': 'all',
        'serverPushMuted': false,
      };
      await f.mount(t, 'light', 390);
      addTearDown(() => f.close(t));
      expect(
        plugin.live,
        isEmpty,
        reason:
            'No dummy badge notification is created on the initial chooser.',
      );
      await t.tap(find.byKey(const ValueKey('global-server-a')));
      await f.flush(t);
      final w = f.workspace(t);
      Future<void> finish(Future<void> action) async {
        var done = false;
        final ending = action.whenComplete(() => done = true);
        for (var i = 0; i < 25 && !done; i++) {
          await f.flush(t);
        }
        expect(done, isTrue);
        await ending;
      }

      await finish(content.notifications.requestEnable(true).then((_) {}));
      w.setForeground(false);
      w.activityUnread.acceptWindow({
        'items': [unreadRow],
        'totalUnreadCount': 2,
      }, scope: w.activityUnread.scope);
      await finish(content.reconciler.settled);
      await finish(content.notifications.idle);
      await finish(content.reconciler.settled);
      expect(plugin.launcherBadge, 6);
      expect(content.notifications.liveUnread['cunread'], 2);
      final realId = plugin.children
          .firstWhere((notice) => notice.title == '#unread')
          .title;
      t.widget<WorkspaceView>(find.byType(WorkspaceView)).onChooseServer!();
      await f.flush(t);
      await finish(content.reconciler.settled);
      expect(plugin.launcherBadge, 6);
      expect(content.notifications.liveUnread['cunread'], 2);
      other = 0;
      await finish(content.dockUnread.refresh());
      await finish(content.reconciler.settled);
      expect(plugin.launcherBadge, 2);
      expect(content.notifications.liveUnread['cunread'], 2);
      expect(plugin.children.single.title, realId);
      await finish(
        content.notifications.show(
          title: 'forbidden new alert',
          body: 'no workspace authority',
          payload: 'raft-activity',
        ),
      );
      expect(plugin.children.single.title, realId);
      other = 4;
      await finish(content.dockUnread.refresh());
      await finish(content.reconciler.settled);
      expect(
        plugin.children.length,
        1,
        reason: 'A removed quiet residual is not recreated on the chooser.',
      );
      await finish(
        t
            .widget<GlobalServerSelector>(find.byType(GlobalServerSelector))
            .onLogout(),
      );
      await finish(content.notifications.idle);
      expect(plugin.live, isEmpty);
      expect(plugin.launcherBadge, 0);
    },
  );
}
