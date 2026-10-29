import 'dart:async';

import 'package:flutter/services.dart';
import 'package:raft_flutter/platform/macos_dock_unread.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_notifications_test.dart'
    show MacPermissionFixture, NotificationPluginFixture;
import 'workspace_source_location_contract_test.dart' show pageFixture;

Future<void> turn(WidgetTester t) async {
  // Bounded frame/microtask turns, with no wall-clock sleep.
  for (var i = 0; i < 30; i++) {
    await t.pump();
  }
}

Future<(NativeContentCoordinator, NativeNotificationService)> coordinator(
  WidgetTester t,
  MacPermissionFixture permission,
) async {
  final plugin = NotificationPluginFixture()..mac = permission;
  plugin.initialized.complete(false);
  final service = NativeNotificationService(
    plugin: plugin,
    platform: TargetPlatform.macOS,
  );
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('app.raft/window'),
    (_) async => false,
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.raft/window'),
      null,
    ),
  );
  final content = NativeContentCoordinator(
    notifications: service,
    links: const Stream.empty(),
    dockUnread: MacOSDockUnread(platform: TargetPlatform.linux),
  );
  addTearDown(() async {
    var closed = false;
    final closing = content.dispose().whenComplete(() => closed = true);
    await turn(t);
    expect(closed, isTrue);
    await closing;
    service.dispose();
  });
  var ready = false;
  final starting = content.init().whenComplete(() => ready = true);
  await turn(t);
  expect(ready, isTrue);
  await starting;
  return (content, service);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'macOS never prompts on workspace entry; explicit enable requests once',
    (t) async {
      final (w, _) = await pageFixture(t);
      final permission = MacPermissionFixture();
      final (content, service) = await coordinator(t, permission);
      await turn(t);
      expect(permission.requests, 0, reason: 'No prompt on the login screen.');
      content.bindWorkspace(null);
      await turn(t);
      expect(permission.requests, 0);
      content.bindWorkspace(w);
      await turn(t);
      expect(permission.requests, 0);
      expect(service.enabled, isFalse);
      await service.requestEnable(true);
      expect(permission.requests, 1);
      expect(service.enabled, isTrue);
      content.bindWorkspace(w);
      w.notifyListeners();
      await turn(t);
      expect(permission.requests, 1);
    },
  );
  testWidgets('macOS remembers denial across logout and a fresh coordinator', (
    t,
  ) async {
    final (w, _) = await pageFixture(t);
    final permission = MacPermissionFixture()
      ..prompt = (Completer<bool?>()..complete(false));
    final (first, service) = await coordinator(t, permission);
    first.bindWorkspace(w);
    await turn(t);
    expect(permission.requests, 0);
    await service.requestEnable(true);
    await turn(t);
    expect(permission.requests, 1);
    expect(service.enabled, isFalse);
    first.bindWorkspace(null);
    await turn(t);
    final (reopened, reopenedService) = await coordinator(t, permission);
    reopened.bindWorkspace(w);
    await turn(t);
    expect(
      permission.requests,
      1,
      reason: 'A fresh service must use the persisted device marker.',
    );
    expect(reopenedService.enabled, isFalse);
  });
  testWidgets('macOS existing permission needs no new system request', (
    t,
  ) async {
    final (w, _) = await pageFixture(t);
    final permission = MacPermissionFixture()..allowed = true;
    final (content, service) = await coordinator(t, permission);
    content.bindWorkspace(w);
    await turn(t);
    expect(permission.requests, 0);
    expect(service.enabled, isTrue);
    content.bindWorkspace(null);
    await turn(t);
    permission.allowed = false;
    final (reopened, _) = await coordinator(t, permission);
    reopened.bindWorkspace(w);
    await turn(t);
    expect(permission.requests, 0);
  });
  testWidgets('macOS permission response after logout cannot enable delivery', (
    t,
  ) async {
    final (w, _) = await pageFixture(t);
    final permission = MacPermissionFixture()..prompt = Completer<bool?>();
    final (content, service) = await coordinator(t, permission);
    content.bindWorkspace(w);
    await turn(t);
    expect(permission.requests, 0);
    final enabling = service.requestEnable(true);
    await turn(t);
    expect(permission.requests, 1);
    content.bindWorkspace(null);
    permission.prompt!.complete(true);
    await enabling;
    await turn(t);
    expect(service.enabled, isFalse);
    content.bindWorkspace(w);
    await turn(t);
    expect(permission.requests, 1);
    expect(service.enabled, isTrue);
  });
}
