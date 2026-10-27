import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/account_activity_unread.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/macos_dock_unread.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';

import 'notification_badge_alignment_test.dart' show FixturePlugin;

class AccountClient extends RaftClient {
  AccountClient(String principal)
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': principal});
  }
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  bool get signedIn => user != null;
  List<RaftRecord> members = [
    RaftRecord({'id': 's1'}),
    RaftRecord({'id': 's2'}),
  ];
  Object summary = [
    {'serverId': 's1', 'activityUnreadCount': 2},
    {'serverId': 's2', 'activityUnreadCount': 4},
  ];
  Future<dynamic> Function()? read;
  @override
  Future<List<RaftRecord>> accountServers() async => List.of(members);
  @override
  Future<dynamic> accountUnreadSummary() async =>
      read == null ? summary : await read!();
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('account count works before any server selection and survives chooser detach', () async {
    final client = AccountClient('alice');
    final writes = <int>[];
    final badge = MacOSDockUnread(
      platform: TargetPlatform.iOS,
      write: (value) async {
        writes.add(value);
      },
    );
    addTearDown(client.dispose);
    addTearDown(badge.dispose);
    badge.bindAccount(client);
    await badge.refresh();
    await badge.settled;
    expect(client.serverId, isNull);
    expect(writes.last, 6);
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..servers = client.members;
    addTearDown(w.dispose);
    w.activityUnread.acceptWindow({
      'items': [],
      'totalUnreadCount': 3,
    }, scope: w.activityUnread.scope);
    badge.bind(w);
    await badge.refresh();
    await badge.settled;
    expect(writes.last, 7);
    badge.bind(null);
    await badge.settled;
    expect(writes.last, 7);
    // The next account summary replaces the detached subtotal, without retaining w.
    await badge.refresh();
    await badge.settled;
    expect(writes.last, 6);
    badge.bindAccount(null);
    await badge.settled;
    expect(writes.last, 0);
  });
  test('other-server read, membership removal and failed summaries keep accepted boundaries', () async {
    final client = AccountClient('alice'), store = AccountActivityUnread();
    addTearDown(client.dispose);
    addTearDown(store.dispose);
    store.bindClient(client);
    await store.refresh();
    expect(store.total, 6);
    client.summary = [
      {'serverId': 's1', 'activityUnreadCount': 2},
      {'serverId': 's2', 'activityUnreadCount': 0},
    ];
    await store.refresh();
    expect(store.total, 2);
    client.read = () async => throw StateError('offline');
    await store.refresh();
    expect(store.total, 2);
    client.ingress.add(
      RaftEvent('server:membership-removed', {
        'serverId': 's1',
        'userId': 'alice',
      }),
    );
    expect(store.total, 0);
    client.members = [
      RaftRecord({'id': 's2'}),
    ];
    await store.refresh();
    expect(store.total, 0);
  });
  test('late account and revoked-membership responses cannot restore retired counts', () async {
    final first = AccountClient('alice'),
        second = AccountClient('bob'),
        store = AccountActivityUnread();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(store.dispose);
    final old = Completer<dynamic>();
    first.read = () => old.future;
    store.bindClient(first);
    final pending = store.refresh();
    await Future<void>.delayed(Duration.zero);
    second.members = [
      RaftRecord({'id': 's1'}),
    ];
    second.summary = [
      {'serverId': 's1', 'activityUnreadCount': 1},
    ];
    store.bindClient(second);
    await store.refresh();
    expect(store.total, 1);
    old.complete([
      {'serverId': 's1', 'activityUnreadCount': 99},
    ]);
    await pending;
    expect(store.total, 1);
    final stale = Completer<dynamic>();
    second.read = () => stale.future;
    final reading = store.refresh();
    await Future<void>.delayed(Duration.zero);
    second.ingress.add(
      RaftEvent('server:membership-removed', {
        'serverId': 's1',
        'userId': 'bob',
      }),
    );
    expect(store.total, 0);
    stale.complete([
      {'serverId': 's1', 'activityUnreadCount': 88},
    ]);
    await reading;
    expect(store.total, 0);
    store.bindClient(null);
    expect(store.total, isNull);
  });
  test('unknown members retain accepted values; authoritative removal without an event drops them', () async {
    final client = AccountClient('alice'), store = AccountActivityUnread();
    addTearDown(client.dispose);
    addTearDown(store.dispose);
    store.bindClient(client);
    await store.refresh();
    expect(store.total, 6);
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..servers = List.of(client.members);
    addTearDown(w.dispose);
    w.activityUnread;
    store.bindWorkspace(w);
    await store.refresh();
    client.summary = [
      {'serverId': 's1', 'activityUnreadCount': 2},
      {'serverId': 's2'},
    ];
    await store.refresh();
    expect(store.total, 6);
    client.summary = [
      {'serverId': 's1', 'activityUnreadCount': 2},
    ];
    await store.refresh();
    expect(
      store.total,
      6,
      reason: 'Still-authorized omitted member is unknown, not zero.',
    );
    final old = Completer<dynamic>();
    client.read = () => old.future;
    final pending = store.refresh();
    await Future<void>.delayed(Duration.zero);
    client.members = [
      RaftRecord({'id': 's1'}),
    ];
    old.complete([
      {'serverId': 's1', 'activityUnreadCount': 2},
      {'serverId': 's2', 'activityUnreadCount': 88},
    ]);
    await pending;
    expect(
      store.total,
      2,
      reason: 'Fresh directory fences an old summary member.',
    );
    w.notifyListeners();
    expect(
      store.total,
      2,
      reason: 'A stale attached directory cannot reintroduce it.',
    );
  });

  test(
    'role and selected-generation changes reject late workspace receipts',
    () async {
      for (final change in ['role', 'generation']) {
        final client = AccountClient('alice');
        client.selectServer('s1');
        final store = AccountActivityUnread();
        final w = WorkspaceController(client)
          ..server = RaftRecord({'id': 's1', 'role': 'owner'})
          ..servers = List.of(client.members);
        w.activityUnread;
        store.bindClient(client);
        store.bindWorkspace(w);
        await store.refresh();
        final old = Completer<dynamic>();
        client.read = () => old.future;
        final pending = store.refresh();
        await Future<void>.delayed(Duration.zero);
        client.read = null;
        if (change == 'role') {
          w.server = RaftRecord({'id': 's1', 'role': 'member'});
        } else {
          client.selectServer(null);
          client.selectServer('s1');
        }
        w.notifyListeners();
        await store.refresh();
        old.complete([
          {'serverId': 's1', 'activityUnreadCount': 99},
          {'serverId': 's2', 'activityUnreadCount': 4},
        ]);
        await pending;
        expect(store.total, 6, reason: change);
        store.dispose();
        w.dispose();
        await client.dispose();
      }
    },
  );
  test(
    'failed native count retries after an identical accepted account refresh',
    () async {
      final client = AccountClient('alice');
      final attempted = <int>[];
      var fail = true;
      final badge = MacOSDockUnread(
        platform: TargetPlatform.iOS,
        write: (count) async {
          attempted.add(count);
          if (fail) {
            throw StateError('native write failed');
          }
        },
      );
      addTearDown(client.dispose);
      addTearDown(badge.dispose);
      badge.bindAccount(client);
      await badge.refresh();
      await badge.settled;
      expect(attempted.where((count) => count == 6).length, 1);
      fail = false;
      await badge.refresh();
      await badge.settled;
      expect(attempted.where((count) => count == 6).length, 2);
      await badge.refresh();
      await badge.settled;
      expect(
        attempted.where((count) => count == 6).length,
        2,
        reason: 'A successful identical write is not repeated.',
      );
    },
  );
  test('managed count waits for the first account directory before using a cached workspace subset', () async {
    final client = AccountClient('alice');
    final held = Completer<dynamic>();
    client.read = () => held.future;
    final written = <int>[];
    final badge = MacOSDockUnread(
      platform: TargetPlatform.iOS,
      write: (value) async {
        written.add(value);
      },
    );
    addTearDown(client.dispose);
    addTearDown(badge.dispose);
    badge.bindAccount(client);
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..servers = [
        RaftRecord({'id': 's1'}),
      ];
    addTearDown(w.dispose);
    w.activityUnread.acceptWindow({
      'items': [],
      'totalUnreadCount': 3,
    }, scope: w.activityUnread.scope);
    badge.bind(w);
    await badge.settled;
    expect(badge.counts.total, isNull);
    expect(written, isNot(contains(3)));
    held.complete([
      {'serverId': 's1', 'activityUnreadCount': 2},
      {'serverId': 's2', 'activityUnreadCount': 4},
    ]);
    await badge.refresh();
    await badge.settled;
    expect(written.last, 7);
    expect(written, isNot(contains(3)));
  });

  test('successful same count is resynced only on an explicit visibility boundary and is account fenced', () async {
    final client = AccountClient('alice');
    final attempts = <int>[];
    final badge = MacOSDockUnread(
      platform: TargetPlatform.iOS,
      write: (value) async {
        attempts.add(value);
      },
    );
    addTearDown(client.dispose);
    addTearDown(badge.dispose);
    badge.bindAccount(client);
    await badge.refresh();
    await badge.settled;
    expect(attempts, [6]);
    await badge.refresh();
    await badge.settled;
    expect(attempts, [6]);
    await badge.resync();
    expect(attempts, [6, 6]);
    final retiring = badge.resync();
    badge.bindAccount(null);
    await retiring;
    await badge.settled;
    expect(attempts, [6, 6, 0]);
  });

  test(
    'unsupported icon platforms bind no account polling or summary requests',
    () async {
      for (final platform in [TargetPlatform.linux, TargetPlatform.fuchsia]) {
        final client = AccountClient('alice');
        var reads = 0;
        client.read = () async {
          reads++;
          return client.summary;
        };
        final badge = MacOSDockUnread(
          platform: platform,
          write: (_) async {
            fail('Unsupported native writer');
          },
          refreshInterval: const Duration(milliseconds: 5),
        );
        badge.bindAccount(client);
        await badge.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(reads, 0);
        expect(badge.counts.authority, isNull);
        await badge.dispose();
        await client.dispose();
      }
    },
  );

  test('the existing notification-settings signal resends a successfully written identical count', () async {
    final client = AccountClient('alice');
    final writes = <int>[];
    final service = NativeNotificationService(
      plugin: FixturePlugin(),
      platform: TargetPlatform.iOS,
    );
    final content = NativeContentCoordinator(
      notifications: service,
      links: const Stream.empty(),
      dockUnread: MacOSDockUnread(
        platform: TargetPlatform.iOS,
        write: (value) async {
          writes.add(value);
        },
      ),
    );
    addTearDown(client.dispose);
    addTearDown(() async {
      await content.dispose();
      service.dispose();
    });
    await content.init();
    content.bindAccount(client);
    await content.dockUnread.refresh();
    await content.dockUnread.settled;
    final before = writes.where((value) => value == 6).length;
    await service.refreshPermission();
    await content.dockUnread.settled;
    expect(writes.where((value) => value == 6).length, before + 1);
  });
}
