import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    serverId = 's';
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  Completer<dynamic>? pending;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add(path);
    if (path == '/servers/s/machines') {
      return pending?.future ??
          {
            'machines': [
              {
                'id': 'm',
                'name': 'Local',
                'status': 'offline',
                'isComputer': true,
              },
            ],
          };
    }
    if (path == '/agents') return [];
    if (path == '/product-feedback/tickets') return {'unread_total': 0};
    return [];
  }

  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<void> dispose() async {
    await stream.close();
    await super.dispose();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> frame(
    WidgetTester t,
    WorkspaceController w, {
    VoidCallback? billing,
    Locale? locale,
  }) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SystemNotificationBell(
              controller: w,
              onBilling: billing ?? () {},
              mobile: true,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'bell opens actual system popup without visiting message Activity or reading chat',
    (t) async {
      final client = _Client();
      final controller = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..section = 'home';
      await frame(t, controller);
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(RaftNotificationCenter), findsOneWidget);
      expect(find.text('Computers need attention'), findsOneWidget);
      expect(controller.section, 'home');
      expect(
        client.calls.any(
          (p) =>
              p.contains('/messages') ||
              p.contains('/activity') ||
              p.endsWith('/read'),
        ),
        isFalse,
      );
      await t.tap(find.text('Dismiss'));
      await t.pump();
      expect(find.text('Computers need attention'), findsNothing);
      expect(find.text('No notifications right now'), findsOneWidget);
      await t.tapAt(const Offset(12, 500));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(RaftNotificationCenter), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await client.dispose();
      await t.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'same-generation role change removes popup and rejects late private machine rows',
    (t) async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..section = 'home';
      await frame(t, w);
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Computers need attention'), findsOneWidget);
      client.pending = Completer<dynamic>();
      client.stream.add(RaftEvent('machine:updated', {}));
      await t.pump(const Duration(milliseconds: 200));
      w.server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'guest'});
      w.notifyListeners();
      await t.pump();
      expect(find.byType(RaftNotificationCenter), findsNothing);
      client.pending!.complete({
        'machines': [
          {
            'id': 'secret',
            'name': 'Private Computer',
            'status': 'offline',
            'isComputer': true,
          },
        ],
      });
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Computers need attention'), findsNothing);
      expect(find.text('Private Computer'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
      await t.binding.setSurfaceSize(null);
    },
  );
  testWidgets('system popup handles Back and Escape without leaving Home', (
    t,
  ) async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
      ..section = 'home';
    await frame(t, w);
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsNothing);
    expect(w.section, 'home');
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump();
    final center = find.byType(RaftNotificationCenter);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(center, findsNothing);
    expect(w.section, 'home');
    await t.pumpWidget(const SizedBox.shrink());
    w.dispose();
    await client.dispose();
    await t.binding.setSurfaceSize(null);
  });
  testWidgets(
    'keyboard opening immediately activates the first authorized action',
    (t) async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({
          'id': 's',
          'name': 'Fixture',
          'role': 'owner',
          'plan': 'free',
          'planDowngradedAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        })
        ..section = 'home';
      var visits = 0;
      await frame(
        t,
        w,
        billing: () => visits++,
        locale: const Locale('zh', 'CN'),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(find.byType(RaftNotificationCenter), findsOneWidget);
      expect(find.text('升级'), findsOneWidget);
      expect(find.text('关闭'), findsWidgets);
      expect(find.text('Computers need attention'), findsNothing);
      // No manual focus or extra Tab: actual keyboard-open selects the first action.
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(visits, 1);
      expect(find.byType(RaftNotificationCenter), findsNothing);
      expect(w.section, 'home');
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
      await t.binding.setSurfaceSize(null);
    },
  );
  testWidgets('keyboard trigger restores its real focus after Escape', (
    t,
  ) async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
      ..section = 'home';
    await frame(t, w);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    final triggerFocus = FocusManager.instance.primaryFocus;
    expect(triggerFocus, isNotNull);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsNothing);
    expect(FocusManager.instance.primaryFocus, same(triggerFocus));
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsNothing);
    expect(FocusManager.instance.primaryFocus, same(triggerFocus));
    await t.pumpWidget(const SizedBox.shrink());
    w.dispose();
    await client.dispose();
    await t.binding.setSurfaceSize(null);
  });
}
