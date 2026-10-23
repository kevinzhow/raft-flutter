// RFC 075 section 4.5: pending joint invites (`GET /channels/joint-invites`)
// are polled for owners and admins only, listed first in the notification
// center, and accepted there (Web usePendingJointInvites + useSystemNotifications).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/system_notification_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> invite(String id, {String channel = 'launch-room'}) => {
  'id': id,
  'fromServerName': 'Acme Partners',
  'fromServerSlug': 'acme',
  'channelName': channel,
  'expiresAt': '2026-11-01T00:00:00.000Z',
};

class _Client extends RaftClient {
  _Client({List<Map<String, dynamic>>? rows})
    : rows = rows ?? [invite('i1')],
      super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    serverId = 's';
  }
  List<Map<String, dynamic>> rows;
  bool failRead = false;
  RaftApiException? acceptFailure;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final reads = <String>[], accepts = <String>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/joint-invites') {
      reads.add(path);
      if (failRead) throw const RaftApiException('offline');
      return {'invites': rows};
    }
    if (path == '/servers/s/machines') return {'machines': []};
    if (path == '/product-feedback/tickets') return {'unread_total': 0};
    return [];
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
    if (method == 'POST' && path.startsWith('/channels/joint-invites/')) {
      accepts.add(path);
      final failure = acceptFailure;
      if (failure != null) throw failure;
      final id = path.split('/')[3];
      rows = [
        for (final r in rows)
          if (r['id'] != id) r,
      ];
      return {'id': 'c-joined', 'name': 'launch-room', 'type': 'joint'};
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

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  String? selected;
  int refreshes = 0;
  @override
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  }) async {
    selected = next.id;
  }

  @override
  Future<void> refreshChannels() async {
    refreshes++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_Workspace> boot(
    WidgetTester t,
    _Client client, {
    String role = 'owner',
    Locale? locale,
  }) async {
    final w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': role})
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
        home: RaftToastHost(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SystemNotificationBell(
                controller: w,
                onBilling: () {},
                mobile: true,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    return w;
  }

  Future<void> openCenter(WidgetTester t) async {
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump(const Duration(milliseconds: 200));
  }

  testWidgets('an owner sees the invite with Accept and Dismiss', (t) async {
    final client = _Client();
    await boot(t, client);
    expect(client.reads, hasLength(1));
    await openCenter(t);
    expect(find.text('Invitation to join #launch-room'), findsOneWidget);
    expect(
      find.text('Acme Partners invited this server to a joint channel.'),
      findsOneWidget,
    );
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('only owners and admins read the invites', (t) async {
    for (final role in ['member', 'guest']) {
      final client = _Client();
      await boot(t, client, role: role);
      expect(client.reads, isEmpty, reason: role);
      await t.pumpWidget(const SizedBox.shrink());
    }
    final admin = _Client();
    await boot(t, admin, role: 'admin');
    expect(admin.reads, hasLength(1));
  });

  testWidgets('Accept posts to the invite, opens the channel and clears it', (
    t,
  ) async {
    final client = _Client();
    final w = await boot(t, client);
    await openCenter(t);
    await t.tap(find.text('Accept'));
    await t.pump(const Duration(milliseconds: 200));
    expect(client.accepts, ['/channels/joint-invites/i1/accept']);
    expect(w.refreshes, 1);
    expect(w.selected, 'c-joined');
    // The list is read again after the accept.
    expect(client.reads.length, greaterThanOrEqualTo(2));
    await openCenter(t);
    expect(find.text('Invitation to join #launch-room'), findsNothing);
  });

  testWidgets(
    'a limit rejection shows the Web limit copy and keeps the invite',
    (t) async {
      final client = _Client()
        ..acceptFailure = RaftApiException.response(
          'Joint channel limit',
          status: 409,
          body: {
            'error': 'Joint channel limit',
            'code': 'joint_free_server_limit',
          },
        );
      final w = await boot(t, client);
      await openCenter(t);
      await t.tap(find.text('Accept'));
      await t.pump(const Duration(milliseconds: 200));
      expect(
        find.text(
          'This Joint Channel already has 2 free servers. Upgrade either side to Pro, or have a free server leave, to continue (30 servers max).',
        ),
        findsOneWidget,
      );
      expect(w.selected, isNull);
      await t.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('polls every 60 seconds and when the app resumes', (t) async {
    final client = _Client(rows: []);
    await boot(t, client);
    expect(client.reads, hasLength(1));
    client.rows = [invite('i2')];
    await t.pump(const Duration(seconds: 30));
    expect(client.reads, hasLength(1));
    await t.pump(const Duration(seconds: 31));
    expect(client.reads, hasLength(2));
    await openCenter(t);
    expect(find.text('Invitation to join #launch-room'), findsOneWidget);
    await t.tapAt(const Offset(12, 600));
    await t.pump(const Duration(milliseconds: 200));
    client.rows = [];
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 200));
    expect(client.reads.length, greaterThanOrEqualTo(3));
    await openCenter(t);
    expect(find.text('Invitation to join #launch-room'), findsNothing);
  });

  testWidgets('a failed read keeps the last known invites', (t) async {
    final client = _Client();
    await boot(t, client);
    client.failRead = true;
    await t.pump(const Duration(seconds: 61));
    expect(client.reads, hasLength(2));
    await openCenter(t);
    expect(find.text('Invitation to join #launch-room'), findsOneWidget);
  });

  testWidgets('Dismiss hides the invite for good, even after the next poll', (
    t,
  ) async {
    final client = _Client();
    await boot(t, client);
    await openCenter(t);
    await t.tap(find.text('Dismiss'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Invitation to join #launch-room'), findsNothing);
    await t.pump(const Duration(seconds: 61));
    expect(find.text('Invitation to join #launch-room'), findsNothing);
    expect(client.accepts, isEmpty);
  });

  test('the invites come first, before other notices', () async {
    final client = _Client();
    final w = _Workspace(client)
      ..server = RaftRecord({
        'id': 's',
        'role': 'owner',
        'plan': 'free',
        'planDowngradedAt': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      });
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    final store = SystemNotificationStore(get: w.query);
    addTearDown(store.dispose);
    await store.bind(
      SystemNotificationContext(
        scope: 's',
        origin: 'o',
        principal: 'alice',
        server: w.server!.json,
        channels: const [],
        canViewMachines: false,
        canViewAgents: false,
        mobile: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.entries.map((e) => e.id).toList(), [
      'joint-invite:i1',
      'plan-downgrade',
    ]);
  });

  testWidgets('zh copy comes from the Web zh-cn catalog', (t) async {
    final client = _Client();
    await boot(t, client, locale: const Locale('zh', 'CN'));
    await openCenter(t);
    expect(find.text('邀请加入 #launch-room'), findsOneWidget);
    expect(find.text('Acme Partners 邀请本服务器加入联合频道。'), findsOneWidget);
    expect(find.text('接受'), findsOneWidget);
  });
}
