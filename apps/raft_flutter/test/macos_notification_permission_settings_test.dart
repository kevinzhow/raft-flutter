import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/windows_tray_settings.dart';

import 'native_notifications_test.dart' show deferredMacNotifications;
import 'notification_settings_view_test.dart' show host, fixture, card;

void main() {
  for (final (dark) in [(false), (true)]) {
    testWidgets(
      'macOS denied permission links to system settings and clears after a grant ${dark ? 'dark' : 'light'}',
      (t) async {
        final (w, _, unused) = (await t.runAsync(fixture))!;
        final (service, _, permission) = deferredMacNotifications();
        addTearDown(w.dispose);
        addTearDown(unused.dispose);
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
        expect(card(t).status, 'Off in system settings');
        expect(find.byType(WindowsTraySettings), findsNothing);
        expect(card(t).hint, isNot(contains('首次发出通知')));
        expect(find.text('系统里没开'), findsOneWidget);
        final settings = find.text('打开通知设置');
        expect(settings, findsOneWidget);
        await t.ensureVisible(settings);
        await t.tap(settings);
        await t.pumpAndSettle();
        expect(opened, 1);
        expect(permission.requests, 0);
        permission.allowed = true;
        await service.refreshPermission();
        await t.pumpAndSettle();
        expect(card(t).status, 'Enabled');
        expect(find.text('系统里没开'), findsNothing);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          host(w, service, dark: dark, locale: const Locale('zh')),
        );
        await t.pumpAndSettle();
        expect(card(t).status, 'Enabled');
        expect(card(t).error, isNull);
        expect(find.text('系统里没开'), findsNothing);
      },
    );
  }
}
