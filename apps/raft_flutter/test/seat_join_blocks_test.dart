import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/seat_join_blocks.dart';
import 'package:raft_flutter/data/system_notification_projection.dart';
import 'package:raft_flutter/data/system_notification_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_flutter/platform/web_billing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Web v1.24 useSeatJoinBlocks + useSystemNotifications section 0b: the people
// a full invite or join link turned away, as warning entries in the
// notification center, behind `pro_seat_add` and for a role that is not guest.
class _Memory implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

Map<String, dynamic> blocks(List<(String, String)> rows) => {
  'blocks': [
    for (final (id, name) in rows)
      {'id': id, 'name': name, 'createdAt': '2026-11-01T00:00:00.000Z'},
  ],
};

SystemNotificationContext scope(
  String name, {
  String role = 'owner',
  String server = 's',
}) => SystemNotificationContext(
  scope: name,
  origin: 'https://public.invalid',
  principal: 'alice',
  server: {'id': server, 'name': 'Acme', 'role': role},
  channels: [],
  canViewMachines: true,
  canViewAgents: true,
  mobile: false,
);

Future<void> flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('SystemNotificationStore seat-join blocks', () {
    late List<String> reads;
    late int flagReads;
    SystemNotificationStore build({
      required Future<dynamic> Function(String path) seat,
      bool? flag = true,
      SearchMemoryStorage? storage,
    }) {
      reads = [];
      flagReads = 0;
      return SystemNotificationStore(
        storage: storage ?? _Memory(),
        get: (path, {query}) async {
          if (path.contains('seat-join-blocks')) {
            reads.add(path);
            return seat(path);
          }
          if (path.endsWith('/machines')) return {'machines': []};
          if (path == '/agents') return [];
          return {'unread_total': 0};
        },
        post: (path) async => {'ok': true},
        seatAddEnabled: (server) async {
          flagReads++;
          return flag;
        },
      );
    }

    test(
      'flag on, owner: one warning per block, in useSystemNotifications order',
      () async {
        final store = build(
          seat: (_) async => blocks([('b1', 'Dana'), ('b2', 'Eli')]),
        );
        await store.bind(scope('one'));
        await flush();
        expect(reads, ['/servers/s/seat-join-blocks']);
        final seats = store.entries
            .where((n) => n.destination == SystemNoticeDestination.seatJoin)
            .toList();
        expect(seats.map((n) => n.id), [
          'seat-join-blocked:b1',
          'seat-join-blocked:b2',
        ]);
        expect(seats.first.kind, SystemNoticeKind.warning);
        expect(seats.first.title, "Acme · Dana couldn't join");
        expect(seats.first.body, 'Upgrade needed for Dana to join');
        store.dispose();
      },
    );

    test('flag off: nothing is read and nothing shows', () async {
      final store = build(
        flag: false,
        seat: (_) async => blocks([('b1', 'Dana')]),
      );
      await store.bind(scope('one'));
      await flush();
      expect(flagReads, 1);
      expect(reads, isEmpty);
      expect(
        store.entries.where(
          (n) => n.destination == SystemNoticeDestination.seatJoin,
        ),
        isEmpty,
      );
      store.dispose();
    });

    test('a guest does not even ask the flag', () async {
      final store = build(seat: (_) async => blocks([('b1', 'Dana')]));
      await store.bind(scope('one', role: 'guest'));
      await flush();
      expect(flagReads, 0);
      expect(reads, isEmpty);
      store.dispose();
    });

    test('a flag turned off clears the list; a failed read keeps it', () async {
      var fail = false;
      var flag = true;
      final store = SystemNotificationStore(
        storage: _Memory(),
        get: (path, {query}) async {
          if (path.contains('seat-join-blocks')) {
            if (fail) throw const RaftApiException('boom');
            return blocks([('b1', 'Dana')]);
          }
          return path.endsWith('/machines') ? {'machines': []} : [];
        },
        post: (path) async => {'ok': true},
        seatAddEnabled: (_) async => flag,
      );
      await store.bind(scope('one'));
      await flush();
      expect(store.seatJoinBlocks, hasLength(1));
      fail = true;
      await store.refreshSeatJoinBlocks();
      expect(store.seatJoinBlocks, hasLength(1), reason: 'keeps the last list');
      fail = false;
      flag = false;
      await store.refreshSeatJoinBlocks(reevaluate: true);
      expect(store.seatJoinBlocks, isEmpty);
      store.dispose();
    });

    test(
      'a pro_seat_add answer that could not be read keeps the last one',
      () async {
        var answer = true as bool?;
        final store = SystemNotificationStore(
          storage: _Memory(),
          get: (path, {query}) async => path.contains('seat-join-blocks')
              ? blocks([('b1', 'Dana')])
              : (path.endsWith('/machines') ? {'machines': []} : []),
          post: (path) async => {'ok': true},
          seatAddEnabled: (_) async => answer,
        );
        await store.bind(scope('one'));
        await flush();
        answer = null;
        await store.refreshSeatJoinBlocks(reevaluate: true);
        expect(store.seatJoinBlocks, hasLength(1));
        store.dispose();
      },
    );

    test('a response for a server the person left is dropped', () async {
      final late = Completer<dynamic>();
      var first = true;
      final store = build(
        seat: (_) {
          if (first) {
            first = false;
            return late.future;
          }
          return Future.value(blocks([]));
        },
      );
      await store.bind(scope('one'));
      await flush();
      await store.bind(scope('two', server: 't'));
      await flush();
      late.complete(blocks([('old', 'Dana')]));
      await flush();
      expect(store.seatJoinBlocks, isEmpty);
      store.dispose();
    });

    test(
      'dismissal is per block id, survives a restart, and a new block shows',
      () async {
        final memory = _Memory();
        var rows = [('b1', 'Dana')];
        var store = build(storage: memory, seat: (_) async => blocks(rows));
        await store.bind(scope('one'));
        await flush();
        store.dismiss('one', 'seat-join-blocked:b1');
        await flush();
        expect(
          store.entries.where(
            (n) => n.destination == SystemNoticeDestination.seatJoin,
          ),
          isEmpty,
        );
        store.dispose();
        // Restart: a new store over the same storage.
        store = build(storage: memory, seat: (_) async => blocks(rows));
        await store.bind(scope('one'));
        await flush();
        expect(
          store.entries.where(
            (n) => n.destination == SystemNoticeDestination.seatJoin,
          ),
          isEmpty,
          reason: 'the same block stays dismissed after a restart',
        );
        // The person turned away again later: a new block id, shown.
        rows = [('b1', 'Dana'), ('b3', 'Dana')];
        await store.refreshSeatJoinBlocks();
        expect(
          store.entries
              .where((n) => n.destination == SystemNoticeDestination.seatJoin)
              .map((n) => n.id),
          ['seat-join-blocked:b3'],
        );
        store.dispose();
      },
    );

    test('parse: rows without an id or a name are skipped', () {
      expect(
        parseSeatJoinBlocks({
          'blocks': [
            {'id': 'a', 'name': 'A'},
            {'id': '', 'name': 'x'},
            {'name': 'y'},
            {'id': 'c'},
          ],
        }).map((b) => b.id),
        ['a'],
      );
      expect(parseSeatJoinBlocks(null), isEmpty);
      expect(parseSeatJoinBlocks({'blocks': 'no'}), isEmpty);
    });
  });

  group('notification center entry', () {
    late _Client client;

    Future<WorkspaceController> boot(
      WidgetTester t, {
      String role = 'owner',
      bool flag = true,
      Size size = const Size(390, 844),
      TargetPlatform platform = TargetPlatform.linux,
      bool mobile = true,
    }) async {
      SharedPreferences.setMockInitialValues({});
      client = _Client(flag: flag);
      final w = WorkspaceController(client)
        ..server = RaftRecord({
          'id': 's',
          'name': 'Acme',
          'slug': 'acme',
          'role': role,
        })
        ..section = 'home';
      await t.binding.setSurfaceSize(size);
      addTearDown(() async {
        webBillingLauncher = (_) async => false;
        await t.pumpWidget(const SizedBox.shrink());
        w.dispose();
        await client.dispose();
        await t.binding.setSurfaceSize(null);
      });
      await t.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: raftTheme(platform: platform),
          builder: (context, child) => RaftToastHost(child: child!),
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

    Future<void> openCenter(WidgetTester t) async {
      await t.tap(find.byType(RaftMobileNotificationButton));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    final sizes = <(String, Size, TargetPlatform)>[
      ('fold 856x944 (Android)', const Size(856, 944), TargetPlatform.android),
      ('fold 944x856 (Android)', const Size(944, 856), TargetPlatform.android),
      (
        'narrow desktop 390x844 (Linux)',
        const Size(390, 844),
        TargetPlatform.linux,
      ),
    ];
    for (final (name, size, platform) in sizes) {
      testWidgets('owner: Add seats opens the Web billing page ($name)', (
        t,
      ) async {
        final opened = <Uri>[];
        webBillingLauncher = (uri) async {
          opened.add(uri);
          return true;
        };
        await boot(t, size: size, platform: platform);
        await openCenter(t);
        expect(find.text("Acme · Dana couldn't join"), findsOneWidget);
        expect(find.text('Upgrade needed for Dana to join'), findsOneWidget);
        expect(find.text('Add seats'), findsOneWidget);
        expect(find.text('Ask an owner'), findsNothing);
        await t.tap(find.text('Add seats'));
        await t.pump(const Duration(milliseconds: 300));
        expect(
          opened.single.toString(),
          'https://app.raft.build/s/acme/settings/billing',
        );
        expect(
          opened.single.hasQuery,
          isFalse,
          reason: 'seats are not an upgrade gate',
        );
      });
    }

    testWidgets('a browser that cannot open shows a toast', (t) async {
      webBillingLauncher = (_) async => false;
      await boot(t);
      await openCenter(t);
      await t.tap(find.text('Add seats'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Could not open this address.'), findsOneWidget);
    });

    testWidgets('a member: Ask an owner, and it opens the same page', (
      t,
    ) async {
      final opened = <Uri>[];
      webBillingLauncher = (uri) async {
        opened.add(uri);
        return true;
      };
      await boot(t, role: 'member');
      await openCenter(t);
      expect(find.text('Ask an owner'), findsOneWidget);
      expect(find.text('Add seats'), findsNothing);
      await t.tap(find.text('Ask an owner'));
      await t.pump(const Duration(milliseconds: 300));
      expect(opened.single.path, '/s/acme/settings/billing');
    });

    testWidgets('Dismiss removes the entry and it stays gone', (t) async {
      await boot(t);
      await openCenter(t);
      expect(find.text("Acme · Dana couldn't join"), findsOneWidget);
      await t.tap(find.text('Dismiss').first);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text("Acme · Dana couldn't join"), findsNothing);
      // Reads again on the safety poll: still dismissed.
      await t.pump(const Duration(minutes: 5, seconds: 1));
      expect(find.text("Acme · Dana couldn't join"), findsNothing);
    });

    testWidgets('flag off: no entry, the list is never read', (t) async {
      await boot(t, flag: false);
      expect(client.seatReads, 0);
      expect(find.byType(RaftNotificationAttention), findsNothing);
    });

    testWidgets('a guest sees nothing and asks nothing', (t) async {
      await boot(t, role: 'guest');
      expect(client.seatReads, 0);
      expect(client.seatFlagReads, 0);
    });

    testWidgets(
      'a seat-join-blocks:changed ping reads again; the poll runs every 5 minutes',
      (t) async {
        await boot(t);
        expect(client.seatReads, 1);
        client.stream.add(
          const RaftEvent('seat-join-blocks:changed', {'serverId': 's'}),
        );
        await t.pump(const Duration(milliseconds: 200));
        expect(client.seatReads, 2);
        await t.pump(const Duration(minutes: 5, seconds: 1));
        expect(client.seatReads, greaterThanOrEqualTo(3));
      },
    );
  });
}

class _Client extends RaftClient {
  _Client({required this.flag})
    : super(
        origin: 'https://api.raft.build',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    serverId = 's';
  }
  final bool flag;
  int seatReads = 0, seatFlagReads = 0;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/seat-join-blocks') {
      seatReads++;
      return blocks([('b1', 'Dana')]);
    }
    if (path == '/servers/s/machines') return {'machines': []};
    if (path == '/product-feedback/tickets') return {'unread_total': 0};
    if (path == '/servers/s/system-notifications-v2') {
      return {
        'contractVersion': 'server-system-attention-v1',
        'notifications': [],
        'unseenCount': 0,
      };
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path == '/feature-flags/evaluate') {
      seatFlagReads++;
      return {
        'evaluations': [
          {'key': 'pro_seat_add', 'enabled': flag},
        ],
      };
    }
    return super.post(path, data: data);
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
