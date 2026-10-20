import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/usage_limit_attention.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> incident(
  String id, {
  String provider = 'claude',
  String? seenAt,
  String? resetsAt = '2026-10-21T10:00:00.000Z',
  int agents = 2,
}) => {
  'id': id,
  'kind': 'usage_limit_reached',
  'severity': 'warning',
  'state': 'active',
  'activatedAt': '2026-10-21T08:00:00.000Z',
  'lastObservedAt': '2026-10-21T08:30:00.000Z',
  'seenAt': seenAt,
  'machine': {'id': 'm1', 'name': 'Studio Mac'},
  'provider': provider,
  'windowKey': 'five_hour',
  'resetsAt': resetsAt,
  'affectedAgentIds': [for (var i = 0; i < agents; i++) 'a$i'],
};

class _Client extends RaftClient {
  _Client({this.flag = true, List<Map<String, dynamic>>? rows})
    : rows = rows ?? [incident('i1')],
      super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    serverId = 's';
  }
  bool flag;
  List<Map<String, dynamic>> rows;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final reads = <String>[], writes = <String>[];
  int flagReads = 0;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/system-notifications-v2') {
      reads.add(path);
      return {
        'contractVersion': serverSystemAttentionContract,
        'generatedAt': '2026-10-21T08:31:00.000Z',
        'snapshotMode': 'replace',
        'unseenCount': rows.where((r) => r['seenAt'] == null).length,
        'notifications': rows,
      };
    }
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'm1',
            'name': 'Studio Mac',
            'status': 'online',
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
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path == '/feature-flags/evaluate') {
      flagReads++;
      return {
        'evaluations': [
          {'key': usageLimitAttentionFlag, 'enabled': flag},
        ],
      };
    }
    return super.post(path, data: data);
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (method == 'POST' && path.contains('/system-notifications-v2/')) {
      writes.add(path);
      final id = path.split('/')[4];
      final action = path.split('/').last;
      rows = [
        for (final r in rows)
          if (r['id'] != id || action != 'dismiss')
            r['id'] == id ? {...r, 'seenAt': '2026-10-21T09:00:00.000Z'} : r,
      ];
      return {'ok': true};
    }
    return super.request(method, path, data: data, query: query);
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

  Future<WorkspaceController> boot(
    WidgetTester t,
    _Client client, {
    bool mobile = true,
    Locale? locale,
    Map<String, Object?> server = const {},
  }) async {
    final w = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 's',
        'name': 'Fixture',
        'role': 'owner',
        ...server,
      })
      ..section = 'home';
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
      await t.binding.setSurfaceSize(null);
    });
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
              onBilling: () {},
              mobile: mobile,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    return w;
  }

  Finder active(String count) =>
      find.bySemanticsLabel(RegExp('Notification center \\($count active\\)'));

  testWidgets(
    'unread incident lights the bell; opening the center marks it seen',
    (t) async {
      final handle = t.ensureSemantics();
      final client = _Client();
      await boot(t, client);
      expect(find.byType(RaftNotificationAttention), findsOneWidget);
      expect(active('1'), findsOneWidget);
      expect(
        client.writes,
        isEmpty,
        reason: 'nothing is marked before opening',
      );

      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Claude usage limit reached'), findsOneWidget);
      expect(
        find.text(
          '2 agents on Studio Mac may pause. Usage is expected to reset '
          '${_expectedReset(const Locale('en'))}.',
        ),
        findsOneWidget,
      );
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(client.writes, ['/servers/s/system-notifications-v2/i1/seen']);
      // Seen: the dot and the active count go, the entry stays listed.
      expect(find.byType(RaftNotificationAttention), findsNothing);
      expect(find.bySemanticsLabel(RegExp('active')), findsNothing);
      expect(find.text('Claude usage limit reached'), findsOneWidget);

      // Reopening does not repeat the receipt.
      await t.tapAt(const Offset(12, 600));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump(const Duration(milliseconds: 200));
      expect(client.writes, hasLength(1));
      handle.dispose();
    },
  );

  testWidgets('an already seen incident leaves the bell quiet but is listed', (
    t,
  ) async {
    final client = _Client(
      rows: [incident('i1', seenAt: '2026-10-21T08:45:00.000Z')],
    );
    await boot(t, client);
    expect(find.byType(RaftNotificationAttention), findsNothing);
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Claude usage limit reached'), findsOneWidget);
    expect(client.writes, isEmpty);
  });

  testWidgets('Dismiss posts the receipt and removes the entry for good', (
    t,
  ) async {
    final client = _Client();
    await boot(t, client);
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text('Dismiss'));
    await t.pump(const Duration(milliseconds: 100));
    expect(client.writes.last, '/servers/s/system-notifications-v2/i1/dismiss');
    expect(find.text('Claude usage limit reached'), findsNothing);
    expect(find.text('No notifications right now'), findsOneWidget);
    // The next poll reads the server snapshot, which no longer has it.
    await t.pump(const Duration(seconds: 61));
    expect(find.text('Claude usage limit reached'), findsNothing);
  });

  testWidgets('legacy entries keep counting as unread next to a seen one', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final client = _Client(
      rows: [incident('i1', seenAt: '2026-10-21T08:45:00.000Z')],
    );
    final w = await boot(
      t,
      client,
      server: {
        'plan': 'free',
        'planDowngradedAt': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      },
    );
    expect(w.server?.string('plan'), 'free');
    // Seen usage entry (no count) + the plan-downgrade entry (no unread field).
    expect(active('1'), findsOneWidget);
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Claude usage limit reached'), findsOneWidget);
    expect(find.text('Plan downgraded to Free'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    // Opening the center does not clear a legacy entry.
    expect(find.byType(RaftNotificationAttention), findsOneWidget);
    handle.dispose();
  });

  testWidgets('flag off: nothing is read and the bell stays quiet', (t) async {
    final client = _Client(flag: false);
    await boot(t, client);
    await t.pump(const Duration(seconds: 61));
    expect(client.reads, isEmpty);
    expect(find.byType(RaftNotificationAttention), findsNothing);
    expect(client.flagReads, 1, reason: 'a resolved flag is evaluated once');
  });

  testWidgets('polls every 60 seconds and on app resume', (t) async {
    final client = _Client(rows: []);
    await boot(t, client);
    expect(client.reads, hasLength(1));
    expect(find.byType(RaftNotificationAttention), findsNothing);

    client.rows = [incident('i1')];
    await t.pump(const Duration(seconds: 30));
    expect(client.reads, hasLength(1));
    await t.pump(const Duration(seconds: 31));
    expect(client.reads, hasLength(2));
    expect(find.byType(RaftNotificationAttention), findsOneWidget);

    // The server resolved it: the next replace snapshot drops the entry.
    client.rows = [];
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 200));
    expect(client.reads.length, greaterThanOrEqualTo(3));
    expect(find.byType(RaftNotificationAttention), findsNothing);
  });

  testWidgets('zh copy comes from the Web zh-cn catalog', (t) async {
    final client = _Client();
    await boot(t, client, locale: const Locale('zh', 'CN'));
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Claude 已达到用量限制'), findsOneWidget);
    expect(
      find.text(
        'Studio Mac 上的 2 个 Agent 可能会暂停。预计 '
        '${_expectedReset(const Locale('zh', 'CN'))} 重置用量。',
      ),
      findsOneWidget,
    );
    expect(find.text('查看'), findsOneWidget);
    expect(find.text('关闭'), findsWidgets);
  });

  testWidgets(
    'without a reset time the shorter copy is used, one agent is singular',
    (t) async {
      final client = _Client(rows: [incident('i1', resetsAt: null, agents: 1)]);
      await boot(t, client);
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump(const Duration(milliseconds: 200));
      expect(
        find.text(
          '1 agent on Studio Mac may pause until usage is available again.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('View opens the Computer', (t) async {
    final client = _Client();
    await boot(t, client);
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text('View'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(RaftNotificationCenter), findsNothing);
    expect(find.byType(FleetDetail), findsOneWidget);
  });

  testWidgets('desktop hover opening marks seen as well', (t) async {
    final client = _Client();
    await boot(t, client, mobile: false);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.byType(RaftMobileNotificationButton)));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(RaftNotificationCenter), findsOneWidget);
    expect(client.writes, ['/servers/s/system-notifications-v2/i1/seen']);
    await mouse.removePointer();
  });
}

String _expectedReset(Locale locale) {
  final reset = DateTime.parse('2026-10-21T10:00:00.000Z').toLocal();
  final code = locale.languageCode == 'zh' ? 'zh_CN' : 'en';
  return '${DateFormat.yMMMd(code).format(reset)} ${DateFormat.jm(code).format(reset)}';
}
