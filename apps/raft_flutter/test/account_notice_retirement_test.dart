import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/notification_reconciler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_badge_alignment_test.dart' show FixturePlugin;

class _Permission extends AndroidFlutterLocalNotificationsPlugin {
  bool allowed = true;
  @override
  Future<bool?> areNotificationsEnabled() async => allowed;
  @override
  Future<bool?> requestNotificationsPermission() async => allowed;
}

class _HeldNotice extends FixturePlugin {
  final permission = _Permission();
  int shows = 0;
  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => T == AndroidFlutterLocalNotificationsPlugin
      ? permission as T
      : super.resolvePlatformSpecificImplementation<T>();
  final entered = Completer<void>(), release = Completer<void>();
  final summaryGroups = <String?>[];
  bool holdUpdate = false;
  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shows++;
    if (notificationDetails?.android?.setAsGroupSummary == true) {
      summaryGroups.add(notificationDetails?.android?.groupKey);
    }
    if (holdUpdate && notificationDetails?.android?.number == 3) {
      holdUpdate = false;
      entered.complete();
      await release.future;
    }
    await super.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final replacement in ['alice', 'bob']) {
    test(
      'completed old maintenance cannot publish a summary under replacement $replacement scope',
      () async {
        SharedPreferences.setMockInitialValues({});
        final plugin = _HeldNotice();
        final service = NativeNotificationService(
          plugin: plugin,
          platform: TargetPlatform.android,
        );
        addTearDown(service.dispose);
        const account = 'https://fixture.invalid\nalice';
        await service.bind('$account\ns1');
        await service.requestEnable(true);
        await service.show(
          title: 'Real card',
          body: 'Still unread',
          payload: 'raft-activity',
          conversation: 'c1',
          unread: 2,
        );
        await service.show(
          title: 'Unread',
          body: 'Other activity',
          payload: NotificationReconciler.moreNotificationPayload,
          conversation: NotificationReconciler.moreKey,
          unread: 4,
          quiet: true,
        );
        await service.detachWorkspace(account);
        plugin.holdUpdate = true;
        final pending = service.maintainAccountUnread(
          account: account,
          total: 5,
          members: {'s1'},
          residualKey: NotificationReconciler.moreKey,
          residualPayload: NotificationReconciler.moreNotificationPayload,
        );
        await plugin.entered.future;
        final rebinding = service.bind(
          'https://fixture.invalid\n$replacement\ns2',
        );
        plugin.release.complete();
        await pending;
        await rebinding;
        expect(
          plugin.summaryGroups,
          isNot(contains('raft.messages.s2')),
          reason:
              'Old accepted data has no authority in the replacement scope.',
        );
        expect(service.liveUnread, isEmpty);
        expect(plugin.live, isEmpty);
      },
    );
  }
  test('denied Android permission retains positive authorized notices without a native update', () async {
    SharedPreferences.setMockInitialValues({});
    final plugin = _HeldNotice();
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.android,
    );
    addTearDown(service.dispose);
    const account = 'https://fixture.invalid\nalice';
    await service.bind('$account\ns1');
    await service.requestEnable(true);
    await service.show(
      title: 'Real card',
      body: 'Still unread',
      payload: 'raft-activity',
      conversation: 'c1',
      unread: 2,
    );
    await service.show(
      title: 'Unread',
      body: 'Other activity',
      payload: NotificationReconciler.moreNotificationPayload,
      conversation: NotificationReconciler.moreKey,
      unread: 4,
      quiet: true,
    );
    await service.detachWorkspace(account);
    final before = plugin.shows;
    plugin.permission.allowed = false;
    await service.maintainAccountUnread(
      account: account,
      total: 5,
      members: {'s1'},
      residualKey: NotificationReconciler.moreKey,
      residualPayload: NotificationReconciler.moreNotificationPayload,
    );
    expect(plugin.shows, before);
    expect(service.liveUnread, {'c1': 2, NotificationReconciler.moreKey: 4});
    expect(plugin.launcherBadge, 6);
    plugin.permission.allowed = true;
    await service.maintainAccountUnread(
      account: account,
      total: 5,
      members: {'s1'},
      residualKey: NotificationReconciler.moreKey,
      residualPayload: NotificationReconciler.moreNotificationPayload,
    );
    expect(service.liveUnread, {'c1': 2, NotificationReconciler.moreKey: 3});
  });
}
