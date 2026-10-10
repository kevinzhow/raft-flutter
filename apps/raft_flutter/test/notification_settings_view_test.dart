import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/notification_settings_view.dart';
import 'package:raft_flutter/platform/native_notifications.dart';

class Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  FutureOr<Map<String, dynamic>> Function(RequestOptions)? settings;
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final data = o.path == '/auth/login'
        ? {
            'accessToken': 'fixture',
            'refreshToken': 'fixture',
            'user': {'id': 'alice'},
          }
        : await settings!(o);
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class Service extends NativeNotificationService {
  Service() : super(platform: TargetPlatform.android) {
    available = true;
  }
  int enables = 0, tests = 0;
  Completer<void>? gate;
  @override
  Future<void> requestEnable(bool next) async {
    enables++;
    await (gate?.future ?? Future<void>.value());
    enabled = next;
    notifyListeners();
  }

  @override
  Future<void> test() async {
    tests++;
  }
}

Future<(WorkspaceController, Adapter, Service)> fixture() async {
  final a = Adapter();
  final c = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await c.login('fixture', 'fixture');
  c.selectServer('s1');
  final w = WorkspaceController(c);
  w.server = RaftRecord({'id': 's1', 'name': 'Fixture', 'role': 'guest'});
  w.servers = [w.server!];
  a.settings = (_) => {'serverPushMuted': false, 'prefsVersion': 1};
  return (w, a, Service());
}

Widget host(
  WorkspaceController w,
  Service s, {
  bool dark = false,
  RaftFamily family = RaftFamily.elegant,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: SingleChildScrollView(
      child: NotificationSettingsView(controller: w, service: s),
    ),
  ),
);
RaftNotificationSettingsCard card(WidgetTester t) =>
    t.widget(find.byType(RaftNotificationSettingsCard));
Future<void> drain(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 350));
}

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('member mute real checkbox/keyboard/save $theme', (t) async {
      final f = (await t.runAsync(fixture))!;
      final (w, a, s) = f;
      addTearDown(w.dispose);
      addTearDown(s.dispose);
      await t.pumpWidget(host(w, s, family: theme.$1, dark: theme.$2));
      await t.pumpAndSettle();
      expect(card(t).onSave, isNull);
      expect(card(t).muted, isFalse);
      await t.tap(find.byType(RaftCheckbox));
      await drain(t);
      expect(card(t).onSave, isNotNull);
      a.settings = (o) {
        expect(o.method, 'PATCH');
        expect(o.data, {'serverPushMuted': true});
        return {'serverPushMuted': true, 'prefsVersion': 2};
      };
      await t.ensureVisible(
        find.byKey(const ValueKey('notification-settings-save')),
      );
      await t.tap(find.byKey(const ValueKey('notification-settings-save')));
      await t.pumpAndSettle();
      expect(w.server!.json['serverPushMuted'], true);
      expect(card(t).onSave, isNull);
      expect(
        find.text('Notifications from Fixture are muted.'),
        findsOneWidget,
      );
      expect(a.calls.where((o) => o.method == 'PATCH').length, 1);
      // Keyboard traversal uses the actual recipe controls, not direct callbacks.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await drain(t);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'server projection seeds the first frame; channel switches keep it without reloading',
    (t) async {
      final (w, a, s) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      addTearDown(s.dispose);
      w.server = RaftRecord({
        ...w.server!.json,
        'serverPushMuted': true,
        'notificationPrefsVersion': 4,
      });
      w.channel = RaftChannel({'id': 'c1', 'name': 'design', 'joined': true});
      final gate = Completer<Map<String, dynamic>>();
      a.settings = (_) => gate.future;
      await t.pumpWidget(host(w, s));
      // First frame: final value, editable, no loading state.
      expect(card(t).muted, true);
      expect(card(t).status, isNot('Checking…'));
      expect(card(t).onMutedChanged, isNotNull);
      int reads() => a.calls
          .where((o) => o.path.endsWith('/notification-settings'))
          .length;
      final before = reads();
      for (var i = 0; i < 3; i++) {
        w.channel = RaftChannel({'id': 'c$i', 'name': 'c$i', 'joined': true});
        w.channelGeneration++;
        w.threadGeneration++;
        w.notifyListeners();
        await t.pump();
        expect(card(t).muted, true, reason: 'switch $i');
        expect(card(t).status, isNot('Checking…'), reason: 'switch $i');
      }
      expect(reads(), before);
      gate.complete({'serverPushMuted': true, 'prefsVersion': 4});
      await t.pumpAndSettle();
      expect(card(t).muted, true);
      // An identity change still clears before the new read lands.
      w.server = RaftRecord({'id': 's1', 'name': 'Fixture', 'role': 'member'});
      final next = Completer<Map<String, dynamic>>();
      a.settings = (_) => next.future;
      w.notifyListeners();
      await t.pump();
      expect(card(t).muted, false);
      expect(card(t).onMutedChanged, isNull);
      next.complete({'serverPushMuted': false, 'prefsVersion': 1});
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('late GET cannot undo accepted newer realtime preference', (
    t,
  ) async {
    final (w, a, s) = (await t.runAsync(fixture))!;
    addTearDown(w.dispose);
    addTearDown(s.dispose);
    final gate = Completer<Map<String, dynamic>>();
    a.settings = (_) => gate.future;
    await t.pumpWidget(host(w, s));
    await t.pump();
    w.server = RaftRecord({
      ...w.server!.json,
      'serverPushMuted': true,
      'notificationPrefsVersion': 8,
    });
    w.notifyListeners();
    await t.pump();
    expect(card(t).muted, true);
    gate.complete({'serverPushMuted': false, 'prefsVersion': 3});
    await t.pumpAndSettle();
    expect(card(t).muted, true);
    expect(w.server!.json['notificationPrefsVersion'], 8);
  });
  testWidgets(
    'scope retirement rejects old PATCH and immediately clears checkbox',
    (t) async {
      final (w, a, s) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      addTearDown(s.dispose);
      await t.pumpWidget(host(w, s));
      await t.pumpAndSettle();
      await t.tap(find.byType(RaftCheckbox));
      await drain(t);
      final gate = Completer<Map<String, dynamic>>();
      a.settings = (_) => gate.future;
      await t.tap(find.byKey(const ValueKey('notification-settings-save')));
      await t.pump();
      w.server = null;
      w.notifyListeners();
      await t.pump();
      expect(card(t).muteDescription, isNull);
      expect(card(t).muted, false);
      gate.complete({'serverPushMuted': true, 'prefsVersion': 9});
      await t.pumpAndSettle();
      expect(w.server, isNull);
      expect(card(t).message, isNull);
    },
  );
  testWidgets(
    'GET failure retries and PATCH 403 retires verified mutation admission',
    (t) async {
      final (w, a, s) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      addTearDown(s.dispose);
      a.status = 503;
      a.settings = (_) => {'error': 'unavailable'};
      await t.pumpWidget(host(w, s));
      await t.pumpAndSettle();
      expect(card(t).onMutedChanged, isNull);
      expect(find.text('Retry'), findsOneWidget);
      a.status = 200;
      a.settings = (_) => {'serverPushMuted': false, 'prefsVersion': 1};
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      await t.tap(find.byType(RaftCheckbox));
      await drain(t);
      a.status = 403;
      a.settings = (_) => {'error': 'revoked'};
      await t.tap(find.byKey(const ValueKey('notification-settings-save')));
      await t.pumpAndSettle();
      expect(card(t).onSave, isNull);
      expect(card(t).onMutedChanged, isNull);
      expect(
        find.text('Failed to update server notification setting.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'actual native permission action prevents duplicate opt-in and enables test after receipt',
    (t) async {
      final (w, a, s) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      addTearDown(s.dispose);
      await t.pumpWidget(host(w, s));
      await t.pumpAndSettle();
      s.gate = Completer<void>();
      await t.tap(find.text('Enable Push Notifications'));
      await t.pump();
      expect(s.enables, 1);
      expect(card(t).onEnable, isNull);
      expect(card(t).onMutedChanged, isNull);
      s.gate!.complete();
      await t.pumpAndSettle();
      expect(card(t).showTest, true);
      await t.tap(find.text('Send test notification'));
      await t.pumpAndSettle();
      expect(s.tests, 1);
    },
  );
  testWidgets(
    'same-principal replacement controller rejects retired pending GET',
    (t) async {
      final (old, a, s) = (await t.runAsync(fixture))!;
      final (next, b, unused) = (await t.runAsync(fixture))!;
      addTearDown(old.dispose);
      addTearDown(next.dispose);
      addTearDown(s.dispose);
      addTearDown(unused.dispose);
      final gate = Completer<Map<String, dynamic>>();
      a.settings = (_) => gate.future;
      await t.pumpWidget(host(old, s));
      await t.pump();
      b.settings = (_) => {'serverPushMuted': false, 'prefsVersion': 4};
      await t.pumpWidget(host(next, s));
      await t.pumpAndSettle();
      expect(card(t).muted, false);
      expect(next.server!.json['notificationPrefsVersion'], 4);
      gate.complete({'serverPushMuted': true, 'prefsVersion': 20});
      await t.pumpAndSettle();
      expect(card(t).muted, false);
      expect(next.server!.json['notificationPrefsVersion'], 4);
    },
  );
}
