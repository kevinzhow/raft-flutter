import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/macos_dock_unread.dart';
import 'package:raft_flutter/platform/native_notifications.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'notification_tap_navigation_test.dart' show notificationRoutes;
import 'native_notifications_test.dart'
    show MacPermissionFixture, NotificationPluginFixture;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

Future<void> _until(WidgetTester t, bool Function() ready) async {
  for (var attempt = 0; attempt < 30 && !ready(); attempt++) {
    await frames(t, () {});
  }
  expect(ready(), isTrue);
}

(NativeContentCoordinator, NotificationPluginFixture) _coordinator(
  WidgetTester t, {
  TargetPlatform platform = TargetPlatform.macOS,
}) {
  final plugin = NotificationPluginFixture()
    ..mac = (MacPermissionFixture()..allowed = true);
  plugin.initialized.complete(platform == TargetPlatform.android);
  final notifications = NativeNotificationService(
    plugin: plugin,
    platform: platform,
  );
  final coordinator = NativeContentCoordinator(
    notifications: notifications,
    links: const Stream.empty(),
    dockUnread: MacOSDockUnread(platform: TargetPlatform.android),
  );
  addTearDown(() async {
    var closed = false;
    final closing = coordinator.dispose().whenComplete(() => closed = true);
    await _until(t, () => closed);
    await closing;
    notifications.dispose();
  });
  return (coordinator, plugin);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cold background startup delivers without a Flutter lifecycle event',
    (tester) async {
      // Reset the test binding to the engine's real pre-event startup state.
      // No resumed/paused event is sent during this regression.
      binding.resetInternalState();
      final (workspace, api) = await pageFixture(tester);
      notificationRoutes(workspace, api);
      // Bind the same accepted inbox owner before notification subscription.
      workspace.activityUnread;
      api.routes['GET /servers/s1/notification-settings'] = (_) => {
        'serverPushMode': 'all',
        'serverPushMuted': false,
      };
      final plugin = NotificationPluginFixture()
        ..mac = (MacPermissionFixture()..allowed = true);
      plugin.initialized.complete(false);
      final notifications = NativeNotificationService(
        plugin: plugin,
        platform: TargetPlatform.macOS,
      );
      final coordinator = NativeContentCoordinator(
        notifications: notifications,
        links: const Stream.empty(),
        dockUnread: MacOSDockUnread(platform: TargetPlatform.android),
      );
      addTearDown(() async {
        var closed = false;
        final closing = coordinator.dispose().whenComplete(() => closed = true);
        for (var attempt = 0; attempt < 30 && !closed; attempt++) {
          await frames(tester, () {});
        }
        expect(closed, isTrue);
        await closing;
        notifications.dispose();
      });
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('app.raft/window'),
        (call) async => call.method == 'isActive' ? false : null,
      );
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('app.raft/window'),
          null,
        ),
      );
      expect(workspace.foreground, isTrue);
      var initialized = false;
      final starting = coordinator.init().then((_) => initialized = true);
      for (var attempt = 0; attempt < 30 && !initialized; attempt++) {
        await frames(tester, () {});
      }
      expect(initialized, isTrue);
      await starting;
      coordinator.bindWorkspace(workspace);
      for (var attempt = 0; attempt < 30 && !notifications.enabled; attempt++) {
        await frames(tester, () {});
      }
      var prepared = false;
      coordinator.desktop!.prepared.then((_) => prepared = true);
      for (var attempt = 0; attempt < 30 && !prepared; attempt++) {
        await frames(tester, () {});
      }
      expect(prepared, isTrue);
      expect(notifications.enabled, isTrue);
      workspace.activityUnread.acceptWindow({
        'items': [
          {
            'kind': 'channel',
            'channelId': 'c2',
            'channelName': 'Background fixture',
            'unreadCount': 1,
            'hasMention': true,
            'firstMentionMessageId': 'background-message',
            'lastMessageId': 'background-message',
            'lastMessagePreview': 'Arrived after background startup',
            'lastMessageAt': DateTime.now()
                .add(const Duration(minutes: 1))
                .toUtc()
                .toIso8601String(),
          },
        ],
      }, scope: workspace.activityUnread.scope);
      for (var attempt = 0; attempt < 30 && plugin.sent.isEmpty; attempt++) {
        await frames(tester, () {});
      }
      expect(
        plugin.sent,
        hasLength(1),
        reason:
            'foreground=${workspace.foreground}, '
            'gate=${notifications.deliveryAllowed?.call()}, '
            'identity=${coordinator.desktop!.identity}, '
            'rows=${workspace.activityUnread.acceptedRows}, '
            'calls=${api.calls.map((c) => c.path).toList()}',
      );
      expect(workspace.foreground, isFalse);
      expect(binding.lifecycleState, isNull);
    },
  );
  for (final active in [false, true]) {
    testWidgets('known lifecycle $active does not query native activation', (
      t,
    ) async {
      binding.handleAppLifecycleStateChanged(
        active ? AppLifecycleState.resumed : AppLifecycleState.paused,
      );
      var calls = 0;
      const channel = MethodChannel('app.raft/window');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
        calls++;
        return Future.value(!active);
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final (coordinator, _) = _coordinator(t);
      var ready = false;
      coordinator.init().then((_) => ready = true);
      await _until(t, () => ready);
      expect(coordinator.appForeground, active);
      expect(coordinator.notifications.deliveryAllowed?.call(), !active);
      expect(calls, 0);
    });

    testWidgets('a lifecycle event wins over a late native reply $active', (
      t,
    ) async {
      binding.resetInternalState();
      final reply = Completer<Object?>();
      var queried = false;
      const channel = MethodChannel('app.raft/window');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
        queried = true;
        return reply.future;
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final (coordinator, _) = _coordinator(t);
      var ready = false;
      coordinator.init().then((_) => ready = true);
      await _until(t, () => queried);
      binding.handleAppLifecycleStateChanged(
        active ? AppLifecycleState.resumed : AppLifecycleState.paused,
      );
      reply.complete(!active);
      await _until(t, () => ready);
      expect(coordinator.appForeground, active);
      expect(coordinator.notifications.deliveryAllowed?.call(), !active);
    });

    testWidgets(
      'restored root follows native activation $active with no lifecycle event',
      (t) async {
        binding.resetInternalState();
        final reply = Completer<Object?>();
        const channel = MethodChannel('app.raft/window');
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) => reply.future,
        );
        addTearDown(
          () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final (coordinator, _) = _coordinator(t);
        final fixture = RootFixture(contentOverride: coordinator);
        addTearDown(fixture.content.dispose);
        await fixture.mount(
          t,
          'light',
          1280,
          uri: Uri.parse('/s/alpha'),
          cachedSession: true,
        );
        final workspace = fixture.workspace(t);
        expect(
          workspace.foreground,
          isFalse,
          reason: 'A pending read never assumes foreground.',
        );
        reply.complete(active);
        await fixture.flush(t);
        expect(binding.lifecycleState, isNull);
        expect(workspace.foreground, active);
        // Onboarding returning to an existing workspace must use the same state.
        final dynamic root = t.state(find.byType(RaftApp));
        await root.finishOnboarding(fixture.client);
        await fixture.flush(t);
        expect(workspace.foreground, active);
        await fixture.close(t);
      },
    );
  }

  testWidgets(
    'a late activation reply cannot initialize a disposed coordinator',
    (t) async {
      binding.resetInternalState();
      final reply = Completer<Object?>();
      var queried = false, initialized = false;
      const channel = MethodChannel('app.raft/window');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
        queried = true;
        return reply.future;
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final (coordinator, plugin) = _coordinator(t);
      var callbacks = 0;
      coordinator.onForegroundChanged = () => callbacks++;
      coordinator.init().then((_) => initialized = true);
      await _until(t, () => queried);
      var disposed = false;
      coordinator.dispose().then((_) => disposed = true);
      await _until(t, () => disposed);
      reply.complete(true);
      await _until(t, () => initialized);
      expect(callbacks, 0);
      expect(plugin.settings, isNull);
    },
  );
  testWidgets(
    'session restoration during the focus read retains a cold notification click',
    (t) async {
      binding.resetInternalState();
      final reply = Completer<Object?>();
      const channel = MethodChannel('app.raft/window');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) => reply.future,
      );
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final (workspace, api) = await pageFixture(t);
      notificationRoutes(workspace, api);
      final (coordinator, plugin) = _coordinator(t);
      addTearDown(() {
        if (!reply.isCompleted) reply.complete(false);
      });
      plugin.launch = NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: jsonEncode({
            'origin': workspace.client.origin,
            'principal': 'alice',
            'serverId': 's1',
            'uri': 'raft://v1/servers/s1/channels/c2/messages/m2',
          }),
        ),
      );
      var initialized = false;
      coordinator.init().then((_) => initialized = true);
      coordinator.bindWorkspace(workspace);
      await _until(t, () => coordinator.notifications.enabled);
      expect(
        initialized,
        isFalse,
        reason: 'The native activation read is still pending.',
      );
      await _until(t, () => workspace.location.messageId == 'm2');
      var shown = false;
      coordinator.notifications
          .show(
            title: 'Pending focus',
            body: 'Fixture only',
            payload: 'fixture',
          )
          .then((_) => shown = true);
      await _until(t, () => shown);
      expect(
        plugin.sent,
        isEmpty,
        reason: 'An unresolved focus read cannot alert a foreground app.',
      );
      reply.complete(false);
      await _until(t, () => initialized);
      expect(workspace.location.messageId, 'm2');
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform unknown lifecycle keeps selected mobile channel foreground and read',
      (t) async {
        binding.resetInternalState();
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        var nativeQueries = 0;
        const channel = MethodChannel('app.raft/window');
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          nativeQueries++;
          return false;
        });
        addTearDown(
          () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final (coordinator, _) = _coordinator(t, platform: platform);
        final fixture = RootFixture(contentOverride: coordinator);
        addTearDown(fixture.content.dispose);
        addTearDown(() => fixture.close(t));
        await fixture.mount(t, 'light', 390);
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await fixture.flush(t);
        await t.tap(find.text('general-a').last);
        await fixture.flush(t);
        final workspace = fixture.workspace(t);
        expect(
          fixture.adapter.calls.where(
            (call) => call.method == 'POST' && call.path == '/channels/ca/read',
          ),
          isNotEmpty,
          reason: 'The visible channel must write its read receipt without waiting for resumed.',
        );
        expect(workspace.foreground, isTrue);
        expect(coordinator.appForeground, isTrue);
        expect(binding.lifecycleState, isNull);
        expect(nativeQueries, 0);
        expect(
          fixture.adapter.calls.where((call) => call.path == '/auth/me'),
          hasLength(1),
          reason: 'Startup does not manufacture a resume refresh.',
        );
        await fixture.close(t);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
