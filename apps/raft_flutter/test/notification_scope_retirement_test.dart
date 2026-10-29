import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/notification_reconciler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_badge_alignment_test.dart'
    show FixtureClient, FixturePlugin, row;

class _PolicyClient extends FixtureClient {
  final requested = Completer<void>();
  final response = Completer<Object>();

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/notification-settings')) {
      if (!requested.isCompleted) requested.complete();
      return response.future;
    }
    return super.get(path, query: query);
  }
}

class _TrackingPlugin extends FixturePlugin {
  final posted = <String?>[];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    posted.add(title);
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
  for (final change in ['account', 'server', 'role', 'generation', 'denial']) {
    test(
      '$change during delayed policy cannot post retired inbox rows',
      () async {
        SharedPreferences.setMockInitialValues({});
        final client = _PolicyClient();
        final w = WorkspaceController(client)
          ..server = RaftRecord({'id': 's1', 'role': 'owner'});
        final plugin = _TrackingPlugin();
        final service = NativeNotificationService(
          plugin: plugin,
          platform: TargetPlatform.android,
        );
        service.deliveryAllowed = () => !w.foreground;
        await service.bind('https://fixture.invalid\nalice\ns1');
        await service.requestEnable(true);
        final store = w.activityUnread;
        final reconciler = NotificationReconciler(notifications: service);
        addTearDown(() {
          reconciler.dispose();
          service.dispose();
          w.dispose();
        });
        w.setForeground(false);
        reconciler.bind(w);
        store.acceptWindow({
          'items': [row('old-private', 4)],
          'totalUnreadCount': 4,
        }, scope: store.scope);
        await client.requested.future;
        switch (change) {
          case 'account':
            client.user = RaftRecord({'id': 'bob'});
          case 'server':
            client.selectServer('s2');
            w.server = RaftRecord({'id': 's2', 'role': 'owner'});
          case 'role':
            w.server = RaftRecord({'id': 's1', 'role': 'guest'});
          case 'generation':
            client.selectServer(null);
            client.selectServer('s1');
          case 'denial':
            store.deny(scope: store.scope);
        }
        w.notifyListeners();
        client.response.complete({
          'serverPushMode': 'all',
          'serverPushMuted': false,
        });
        await reconciler.settled;
        await service.idle;
        await reconciler.settled;
        expect(
          plugin.posted,
          isEmpty,
          reason:
              'a late policy cannot post old rows, even briefly before cancel',
        );
      },
    );
  }
}
