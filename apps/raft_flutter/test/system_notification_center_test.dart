import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_flutter/features/fleet_views.dart';
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
  Map<String, dynamic>? agent;
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
    if (path == '/agents') return [if (agent != null) agent];
    if (path == '/agents/a1') return agent;
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
    Size viewport = const Size(390, 844),
    double titleBarHeight = 0,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = viewport;
    addTearDown(t.view.reset);
    await t.binding.setSurfaceSize(viewport);
    await t.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(),
        builder: (context, child) => Padding(
          padding: EdgeInsets.only(top: titleBarHeight),
          child: child,
        ),
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
      await frame(t, controller, titleBarHeight: 48);
      final bell = find.byType(RaftMobileNotificationButton);
      final bellBottom = t.getRect(bell).bottom;
      await t.tap(bell);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(RaftNotificationCenter), findsOneWidget);
      final popup = t.getRect(find.byType(RaftNotificationCenter));
      expect(popup.left, 8);
      expect(popup.right, 382);
      expect(popup.top, bellBottom + 8);
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
      expect(find.text('No notifications'), findsOneWidget);
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
    'computer notice opens its Agent and Back returns to the Computer',
    (t) async {
      addTearDown(() => t.binding.setSurfaceSize(null));
      final client = _Client()
        ..agent = {
          'id': 'a1',
          'name': 'sensor',
          'displayName': 'Sensor Agent',
          'status': 'active',
          'runtime': 'claude',
          'model': 'sonnet',
          'machineId': 'm',
        };
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..section = 'home';
      addTearDown(client.dispose);
      addTearDown(w.dispose);
      await frame(t, w);
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pumpAndSettle();
      expect(find.text('Computers need attention'), findsOneWidget);
      await t.tap(find.text('View').hitTestable());
      await t.pumpAndSettle();

      final computer = find.byWidgetPredicate(
        (widget) => widget is FleetDetail && widget.computers,
      );
      final profile = find.byWidgetPredicate(
        (widget) => widget is FleetDetail && !widget.computers,
      );
      expect(computer, findsOneWidget);
      final agent = find.descendant(
        of: computer,
        matching: find.text('Sensor Agent'),
      );
      await t.ensureVisible(agent);
      await t.tap(agent.hitTestable());
      await t.pumpAndSettle();
      expect(
        find.descendant(of: profile, matching: find.text('Sensor Agent')),
        findsWidgets,
      );
      final back = find.byTooltip('Back').hitTestable();
      expect(back, findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(profile, findsNothing);
      expect(computer, findsOneWidget);
      expect(find.byKey(const Key('computer-mobile-back')), findsOneWidget);
      expect(back, findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(RaftMobileNotificationButton), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
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
  testWidgets(
    'joining channels and agent events keep dismissals and accepted rows without refetching the bell',
    (t) async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..channels = [
          RaftChannel({'id': 'c1', 'name': 'design', 'joined': true}),
        ]
        ..section = 'home';
      await frame(t, w);
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Computers need attention'), findsOneWidget);
      await t.tap(find.text('Dismiss'));
      await t.pump();
      expect(find.text('No notifications'), findsOneWidget);
      int reads(String path) => client.calls.where((p) => p == path).length;
      final feedback = reads('/product-feedback/tickets');
      final machines = reads('/servers/s/machines');

      // Join/create a channel and receive capability changes.
      w.channels = [
        ...w.channels,
        RaftChannel({
          'id': 'c2',
          'name': 'release',
          'joined': true,
          'channelCapabilities': {'manage': true},
        }),
      ];
      w.notifyListeners();
      for (var frame = 0; frame < 6; frame++) {
        await t.pump(const Duration(milliseconds: 50));
        expect(find.byType(RaftNotificationCenter), findsOneWidget);
        expect(find.text('No notifications'), findsOneWidget);
        expect(find.text('Computers need attention'), findsNothing);
      }
      expect(reads('/product-feedback/tickets'), feedback);

      // Agent events revalidate the shared directory once; the bell does not
      // issue its own machines/agents/feedback reads.
      for (final name in ['agent:updated', 'agent:activity', 'agent:created']) {
        client.stream.add(RaftEvent(name, {'agentId': 'a'}));
      }
      for (var frame = 0; frame < 6; frame++) {
        await t.pump(const Duration(milliseconds: 50));
        expect(find.text('No notifications'), findsOneWidget);
      }
      expect(reads('/product-feedback/tickets'), feedback);
      expect(reads('/servers/s/machines'), lessThanOrEqualTo(machines + 1));

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

  testWidgets('desktop bell keeps the 36 px hit area around its 34 px box', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1280, 800);
    addTearDown(t.view.reset);
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'guest'});
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: RaftWorkspaceTopBar(
              workspace: const SizedBox.shrink(),
              onSearch: () {},
              trailing: [
                SystemNotificationBell(
                  controller: w,
                  onBilling: () {},
                  mobile: false,
                  topBar: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump();
    final bell = t.getRect(find.byType(RaftMobileNotificationButton));
    expect(bell.size, const Size.square(34));
    expect(bell.right, 1267);
    await t.tapAt(
      Offset(bell.left - 2, bell.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsNothing);
    await t.tapAt(
      Offset(bell.left - .5, bell.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    w.dispose();
    await client.dispose();
  });

  for (final keyboard in [0.0, 180.0]) {
    testWidgets('system popup clears window bars and IME $keyboard', (t) async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
      t.view.physicalSize = const Size(390, 400);
      t.view.devicePixelRatio = 1;
      t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
      t.view.padding = FakeViewPadding(top: 24, bottom: keyboard == 0 ? 48 : 0);
      t.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(t.view.reset);
      await frame(t, w, viewport: const Size(390, 400));
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump();
      final rect = t.getRect(find.byType(RaftNotificationCenter));
      expect(rect.top, greaterThanOrEqualTo(24 + 8));
      expect(
        rect.bottom,
        lessThanOrEqualTo(400 - (keyboard == 0 ? 48 : keyboard) - 8),
      );
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
      await t.binding.setSurfaceSize(null);
    });
  }
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
