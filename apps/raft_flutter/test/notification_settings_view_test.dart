// Settings › Notifications v2 (Web v1.24.0 NotificationSettingsSection):
// this device, pause and schedule, the content every device shows, every
// server's level, and the link to this server's own. The HTTP fixture answers
// the v1.24 routes; the requests are asserted exactly.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/notification_levels.dart';
import 'package:raft_flutter/data/notification_settings_api.dart';
import 'package:raft_flutter/data/notification_settings_store.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/notification_level_menu.dart';
import 'package:raft_flutter/features/notification_settings_view.dart';
import 'package:raft_flutter/platform/battery_optimization.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

typedef Reply = ({int status, Object body});

class Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, FutureOr<Reply> Function(RequestOptions)>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final Reply reply = o.path == '/auth/login'
        ? (
            status: 200,
            body: {
              'accessToken': 'fixture',
              'refreshToken': 'fixture',
              'user': {'id': 'alice'},
            },
          )
        : route == null
        ? (status: 404, body: {'error': 'Unexpected'})
        : await route(o);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  List<RequestOptions> sent(String method, String path) => [
    for (final c in calls)
      if (c.method == method && c.path == path) c,
  ];

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> settings({
  int version = 3,
  String? pausedUntil,
  bool quiet = false,
  String previewMode = 'full',
  bool sound = true,
  String mobileDelay = 'inactive',
  bool followed = true,
}) => {
  'pausedUntil': pausedUntil,
  'quietHours': {
    'enabled': quiet,
    'startMinute': 22 * 60,
    'endMinute': 8 * 60,
    'timeZone': 'Europe/Berlin',
  },
  'previewMode': previewMode,
  'sound': sound,
  'mobileDelay': mobileDelay,
  'followedThreadReplies': followed,
  'version': version,
};

class Service extends NativeNotificationService {
  Service({TargetPlatform platform = TargetPlatform.android})
    : super(platform: platform) {
    addTearDown(dispose);
    available = true;
    initialized = true;
    permitted = true;
  }
  int enables = 0, tests = 0, settingsOpened = 0;
  bool grant = true;
  @override
  Future<void> requestEnable(bool next) async {
    enables++;
    enabled = next && grant;
    permitted = grant;
    notifyListeners();
  }

  @override
  Future<bool> test({String? title, String? body}) async {
    tests++;
    return true;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class _Battery extends BatteryOptimization {
  _Battery(this.value) : super(supported: true);
  bool? value;
  @override
  Future<bool?> exempt() async => value;
}

Future<(WorkspaceController, Adapter)> fixture(WidgetTester t) async {
  final a = Adapter();
  final w = (await t.runAsync(() async {
    final c = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = a,
    );
    await c.login('fixture', 'fixture');
    c.selectServer('s1');
    return WorkspaceController(c);
  }))!;
  addTearDown(w.dispose);
  w.server = RaftRecord({
    'id': 's1',
    'slug': 'alpha',
    'name': 'Alpha',
    'role': 'member',
  });
  w.servers = [
    RaftRecord({'id': 's2', 'slug': 'beta', 'name': 'Beta', 'role': 'member'}),
    w.server!,
  ];
  w.channels = [
    RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
  ];
  a.routes['GET /me/notification-settings'] = (_) => (
    status: 200,
    body: {
      'settings': settings(),
      'servers': [
        {'serverId': 's1', 'level': 'all'},
        {'serverId': 's2', 'level': 'mentions'},
      ],
    },
  );
  a.routes['GET /notification-levels'] = (o) => (
    status: 200,
    body: {
      'serverId': o.headers['X-Server-Id'],
      'server': o.headers['X-Server-Id'] == 's2' ? 'mentions' : 'all',
      'channels': o.headers['X-Server-Id'] == 's1'
          ? [
              {'id': 'c1', 'level': 'mentions'},
            ]
          : [],
      'threads': [],
    },
  );
  return (w, a);
}

Widget host(
  WorkspaceController w,
  NativeNotificationService s, {
  bool dark = false,
  Locale? locale,
  BatteryOptimization? battery,
  Future<TestNotificationOutcome> Function()? runDesktopTest,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en'), Locale('zh')],
  theme: raftTheme(dark: dark),
  home: RaftToastHost(
    child: Scaffold(
      body: SingleChildScrollView(
        child: NotificationSettingsView(
          controller: w,
          service: s,
          battery: battery ?? _Battery(true),
          now: () => DateTime.utc(2026, 11, 14, 10),
          timeZone: () async => 'Europe/Berlin',
          runDesktopTest: runDesktopTest,
        ),
      ),
    ),
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> body(RequestOptions o) =>
    Map<String, dynamic>.from(o.data as Map);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'v2 sections in Web order; account values from the server ${dark ? 'dark' : 'light'}',
      (t) async {
        final (w, a) = await fixture(t);
        await t.pumpWidget(host(w, Service(), dark: dark));
        await settle(t);
        double y(String key) => t.getTopLeft(find.byKey(ValueKey(key))).dy;
        expect(y('push-notifications') < y('notification-pause-card'), isTrue);
        expect(
          y('notification-pause-card') < y('notification-content-card'),
          isTrue,
        );
        expect(
          y('notification-content-card') < y('notification-servers-card'),
          isTrue,
        );
        expect(
          y('notification-servers-card') <
              y('settings-server-notifications-link'),
          isTrue,
        );
        for (final title in [
          'This device',
          'Pause and schedule',
          'All devices',
          'Servers',
          'Pause notifications',
          'Quiet hours',
          'Notification preview',
          'Phone alerts',
          'Sound',
          'Replies in threads I follow',
          'Alpha (current)',
          'Beta',
          'Notifications on Alpha',
        ]) {
          expect(find.text(title), findsOneWidget, reason: title);
        }
        // The current server first; Beta at its own level.
        expect(
          y('notification-server-row-s1') < y('notification-server-row-s2'),
          isTrue,
        );
        expect(
          t
              .widget<RaftSettingsSelect<NotificationLevelChoice>>(
                find.byKey(const ValueKey('notification-server-level-s2')),
              )
              .value,
          NotificationLevelChoice.mentions,
        );
        expect(a.sent('GET', '/me/notification-settings'), hasLength(1));
        expect(
          {
            for (final c in a.sent('GET', '/notification-levels'))
              c.headers['X-Server-Id'],
          },
          {'s1', 's2'},
        );
        // The legacy per-server route is not used any more (API-15 / API-18).
        expect(a.calls.where((c) => c.path.startsWith('/servers/')), isEmpty);
      },
    );
  }

  testWidgets(
    'pause presets PATCH pausedUntil with the held version; Resume clears it',
    (t) async {
      final (w, a) = await fixture(t);
      final until = DateTime.utc(2026, 11, 14, 10, 30).toIso8601String();
      a.routes['PATCH /me/notification-settings'] = (o) => (
        status: 200,
        body: {
          'settings': settings(
            version: 4,
            pausedUntil: body(o)['pausedUntil'] as String?,
          ),
        },
      );
      await t.pumpWidget(host(w, Service()));
      await settle(t);
      t
          .widget<RaftSettingsSelect<Object>>(
            find.byKey(const ValueKey('notification-pause-select')),
          )
          .onChanged!(PausePreset.m30);
      await settle(t);
      final patch = a.sent('PATCH', '/me/notification-settings').single;
      expect(body(patch), {'pausedUntil': until, 'version': 3});
      expect(
        find.textContaining('Paused on all your devices until'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification-pause-resume')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('notification-pause-resume')));
      await settle(t);
      expect(body(a.sent('PATCH', '/me/notification-settings').last), {
        'pausedUntil': null,
        'version': 4,
      });
      expect(
        find.byKey(const ValueKey('notification-pause-select')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a 409 from another device says so and reloads its values', (
    t,
  ) async {
    final (w, a) = await fixture(t);
    a.routes['PATCH /me/notification-settings'] = (_) =>
        (status: 409, body: {'error': 'Version conflict'});
    await t.pumpWidget(host(w, Service()));
    await settle(t);
    a.routes['GET /me/notification-settings'] = (_) => (
      status: 200,
      body: {'settings': settings(version: 9, quiet: true), 'servers': []},
    );
    t
        .widget<RaftSwitch>(
          find.byKey(const ValueKey('notification-quiet-hours-switch')),
        )
        .onChanged!(true);
    await settle(t);
    expect(
      find.text(
        'These settings were just changed on another device. The latest values are shown; try again.',
      ),
      findsOneWidget,
    );
    expect(a.sent('GET', '/me/notification-settings'), hasLength(2));
    expect(
      t
          .widget<RaftSwitch>(
            find.byKey(const ValueKey('notification-quiet-hours-switch')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets(
    'quiet hours save in this device\'s zone; times commit on submit',
    (t) async {
      final (w, a) = await fixture(t);
      a.routes['PATCH /me/notification-settings'] = (o) {
        final quiet = body(o)['quietHours'] as Map;
        return (
          status: 200,
          body: {
            'settings': {
              ...settings(version: 5, quiet: quiet['enabled'] == true),
              'quietHours': quiet,
            },
          },
        );
      };
      await t.pumpWidget(host(w, Service()));
      await settle(t);
      t
          .widget<RaftSwitch>(
            find.byKey(const ValueKey('notification-quiet-hours-switch')),
          )
          .onChanged!(true);
      await settle(t);
      expect(body(a.sent('PATCH', '/me/notification-settings').single), {
        'quietHours': {
          'enabled': true,
          'startMinute': 1320,
          'endMinute': 480,
          'timeZone': 'Europe/Berlin',
        },
        'version': 3,
      });
      final start = find.descendant(
        of: find.byKey(const ValueKey('notification-quiet-hours-start')),
        matching: find.byType(EditableText),
      );
      await t.enterText(start, '21:30');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      expect(
        (body(a.sent('PATCH', '/me/notification-settings').last)['quietHours']
            as Map)['startMinute'],
        21 * 60 + 30,
      );
    },
  );

  testWidgets(
    'All devices: preview, phone alerts, sound and followed replies PATCH one field each',
    (t) async {
      final (w, a) = await fixture(t);
      a.routes['PATCH /me/notification-settings'] = (o) =>
          (status: 200, body: {'settings': settings(version: 4)});
      await t.pumpWidget(host(w, Service()));
      await settle(t);
      t
          .widget<RaftSettingsSelect<NotificationPreviewMode>>(
            find.byKey(const ValueKey('notification-preview-select')),
          )
          .onChanged!(NotificationPreviewMode.senderOnly);
      t
          .widget<RaftSettingsSelect<NotificationMobileDelay>>(
            find.byKey(const ValueKey('notification-mobile-delay-select')),
          )
          .onChanged!(NotificationMobileDelay.m5);
      t
          .widget<RaftSwitch>(
            find.byKey(const ValueKey('notification-sound-switch')),
          )
          .onChanged!(false);
      t
          .widget<RaftSwitch>(
            find.byKey(
              const ValueKey('notification-followed-thread-replies-switch'),
            ),
          )
          .onChanged!(false);
      await settle(t);
      expect(
        [for (final c in a.sent('PATCH', '/me/notification-settings')) body(c)],
        [
          {'previewMode': 'sender_only', 'version': 3},
          {'mobileDelay': '5m', 'version': 3},
          {'sound': false, 'version': 3},
          {'followedThreadReplies': false, 'version': 3},
        ],
      );
    },
  );

  testWidgets(
    'a server level PUTs /notification-levels; a customized channel resets to default',
    (t) async {
      final (w, a) = await fixture(t);
      a.routes['PUT /notification-levels'] = (o) => (
        status: 200,
        body: {
          ...body(o),
          'serverId': o.headers['X-Server-Id'],
          'effective': body(o)['level'] == 'default' ? 'all' : body(o)['level'],
          'muted': false,
          'prefsVersion': 7,
        },
      );
      await t.pumpWidget(host(w, Service()));
      await settle(t);
      t
          .widget<RaftSettingsSelect<NotificationLevelChoice>>(
            find.byKey(const ValueKey('notification-server-level-s2')),
          )
          .onChanged!(NotificationLevelChoice.none);
      await settle(t);
      final put = a.sent('PUT', '/notification-levels').single;
      expect(body(put), {'scope': 'server', 'id': 's2', 'level': 'none'});
      // "1 channel customized" opens #general (Only what involves me).
      t
          .widget<RaftTextLink>(
            find.byKey(const ValueKey('notification-server-customized-s1')),
          )
          .onPressed!();
      await settle(t);
      expect(find.text('#general'), findsOneWidget);
      expect(find.text('Only what involves me'), findsWidgets);
      t
          .widget<RaftButton>(
            find.byKey(const ValueKey('customized-channel-reset-c1')),
          )
          .onPressed!();
      await settle(t);
      expect(body(a.sent('PUT', '/notification-levels').last), {
        'scope': 'channel',
        'id': 'c1',
        'level': 'default',
      });
      expect(find.byKey(const ValueKey('customized-channel-c1')), findsNothing);
      expect(
        find.byKey(const ValueKey('notification-server-customized-s1')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'another device\'s change arrives as a frame and replaces the page values; a stale one does not',
    (t) async {
      final (w, _) = await fixture(t);
      await t.pumpWidget(host(w, Service()));
      await settle(t);
      final store = NotificationSettingsStore.of(w.client);
      expect(
        store.applyPrefsUpdate({
          'type': 'account',
          'settings': settings(version: 6, sound: false),
        }),
        isTrue,
      );
      expect(
        store.applyPrefsUpdate({
          'type': 'server',
          'serverId': 's2',
          'scopeId': 's2',
          'level': 'none',
          'prefsVersion': 2,
        }),
        isTrue,
      );
      await t.pump();
      expect(
        t
            .widget<RaftSwitch>(
              find.byKey(const ValueKey('notification-sound-switch')),
            )
            .value,
        isFalse,
      );
      expect(
        t
            .widget<RaftSettingsSelect<NotificationLevelChoice>>(
              find.byKey(const ValueKey('notification-server-level-s2')),
            )
            .value,
        NotificationLevelChoice.none,
      );
      expect(
        store.applyPrefsUpdate({
          'type': 'account',
          'settings': settings(version: 5, sound: true),
        }),
        isFalse,
      );
      expect(
        store.applyPrefsUpdate({
          'type': 'server',
          'serverId': 's2',
          'scopeId': 's2',
          'level': 'all',
          'prefsVersion': 1,
        }),
        isFalse,
      );
    },
  );

  testWidgets(
    '"Notifications on Alpha" opens Settings › On Alpha › Notifications',
    (t) async {
      final (w, _) = await fixture(t);
      await t.pumpWidget(host(w, Service()));
      await settle(t);
      expect(find.text('All new messages'), findsWidgets);
      t
          .widget<RaftListRow>(
            find.byKey(const ValueKey('settings-server-notifications-link')),
          )
          .onPressed!();
      await t.pump();
      expect(w.location.route, RaftRoute.settings);
      expect(w.location.settingsPath, ['server-notifications']);
    },
  );

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.linux,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      'desktop $platform: system-managed card; the test goes through the server',
      (t) async {
        final (w, _) = await fixture(t);
        final outcomes = <TestNotificationOutcome>[
          (state: TestNotificationState.shown, reason: null),
          (state: TestNotificationState.notShown, reason: null),
          (state: TestNotificationState.failed, reason: 'no_socket'),
        ];
        final service = Service(platform: platform);
        await t.pumpWidget(
          host(w, service, runDesktopTest: () async => outcomes.removeAt(0)),
        );
        await settle(t);
        expect(find.text('Desktop notifications'), findsOneWidget);
        expect(find.text('Managed by the system'), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey('desktop-open-system-notification-settings'),
          ),
          platform == TargetPlatform.linux ? findsNothing : findsOneWidget,
        );
        for (final expected in [
          'Test notification shown on this device.',
          'The test was sent, but the system didn’t show it. Allow notifications for Raft in the system’s notification settings, and check that Do Not Disturb or Focus is off.',
          'Couldn’t send the test notification (no_socket).',
        ]) {
          await t.tap(find.byKey(const ValueKey('send-test-notification')));
          await settle(t);
          expect(find.text(expected), findsOneWidget);
        }
        // No local post: the server's notification:desktop is the test.
        expect(service.tests, 0);
      },
    );
  }

  testWidgets('desktop: an unavailable build says so and cannot test', (
    t,
  ) async {
    final (w, _) = await fixture(t);
    final service = Service(platform: TargetPlatform.linux)..available = false;
    await t.pumpWidget(host(w, service));
    await settle(t);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      find.text('This desktop build cannot show system notifications.'),
      findsOneWidget,
    );
    expect(
      t
          .widget<RaftButton>(
            find.byKey(const ValueKey('send-test-notification')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'phone: enable asks for the permission, then the test posts here',
    (t) async {
      final (w, _) = await fixture(t);
      final service = Service();
      await t.pumpWidget(host(w, service, battery: _Battery(false)));
      await settle(t);
      expect(find.text('Phone notifications'), findsOneWidget);
      expect(find.text('Not enabled'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('battery-optimization-notice')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('phone-notifications-enable')));
      await settle(t);
      expect(service.enables, 1);
      expect(find.text('Enabled'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('send-test-notification')));
      await settle(t);
      expect(service.tests, 1);
      expect(
        find.byKey(const ValueKey('test-notification-posted')),
        findsOneWidget,
      );
    },
  );

  testWidgets('zh: the v2 sections read the Web zh-cn wording', (t) async {
    final (w, _) = await fixture(t);
    await t.pumpWidget(
      host(
        w,
        Service(platform: TargetPlatform.iOS),
        locale: const Locale('zh'),
      ),
    );
    await settle(t);
    for (final text in [
      '暂停与时段',
      '暂停通知',
      '安静时段',
      '通知预览',
      '手机提醒',
      '我关注的消息列中的回复',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(
      find.byKey(const ValueKey('battery-optimization-notice')),
      findsNothing,
    );
  });
}
