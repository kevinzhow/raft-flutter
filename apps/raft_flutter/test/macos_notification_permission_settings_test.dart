import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/windows_tray_settings.dart';

import 'native_notifications_test.dart' show deferredMacNotifications;
import 'notification_settings_view_test.dart' show host, fixture;

void main() {
  for (final (dark) in [(false), (true)]) {
    testWidgets(
      'macOS: the system owns the switch; Open System Settings opens it ${dark ? 'dark' : 'light'}',
      (t) async {
        final (w, _) = await fixture(t);
        final (service, _, permission) = deferredMacNotifications();
        addTearDown(service.dispose);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        });
        var opened = 0;
        const channel = MethodChannel(
          'dexterous.com/flutter/local_notifications',
        );
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          if (call.method == 'openAppNotificationSettings') opened++;
          return true;
        });
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await service.bind('alice');
        await t.pumpWidget(
          host(w, service, dark: dark, locale: const Locale('zh')),
        );
        await t.pumpAndSettle();
        // Web v1.24 DesktopDeviceCard: "Managed by the system", whatever the
        // OS switch says; the system settings are one click away.
        expect(find.text('桌面通知'), findsOneWidget);
        expect(find.text('由系统管理'), findsOneWidget);
        expect(find.byType(WindowsTraySettings), findsNothing);
        final settings = find.text('打开系统设置');
        expect(settings, findsOneWidget);
        await t.ensureVisible(settings);
        await t.tap(settings);
        await t.pumpAndSettle();
        expect(opened, 1);
        expect(permission.requests, 0);
      },
    );
  }
}
