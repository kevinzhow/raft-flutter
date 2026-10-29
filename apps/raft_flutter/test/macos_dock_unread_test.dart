import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/macos_dock_unread.dart';

import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:dio/dio.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
  @override
  Future<dynamic> accountUnreadSummary() => get('/servers/unread-summary');
  @override
  bool get signedIn => user != null;
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }

  List<RaftRecord> Function()? memberRead;
  @override
  Future<List<RaftRecord>> accountServers() async =>
      memberRead?.call() ??
      [
        RaftRecord({'id': 's1'}),
      ];
  int? inboxTotal;
  FutureOr<dynamic> Function() summaryRead = () => [];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      path == '/servers/unread-summary'
      ? await summaryRead()
      : {'items': [], if (inboxTotal != null) 'totalUnreadCount': inboxTotal};
}

(WorkspaceController, _Client) fixture() {
  final client = _Client();
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  client.memberRead = () => w.servers.isEmpty ? [w.server!] : w.servers;
  w.activityUnread;
  addTearDown(w.dispose);
  return (w, client);
}

Map<String, Object> summary(String id, int count) => {
  'serverId': id,
  'unreadCount': 1000,
  'activityUnreadCount': count,
};

Future<void> run(Future<void> Function() action) => action();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Windows tray uses accepted Activity plus other member servers and clears on logout', () async {
    final (w, api) = fixture();
    w.servers = [
      w.server!,
      RaftRecord({'id': 's2', 'role': 'member'}),
    ];
    api.summaryRead = () => [
      summary('s1', 10),
      summary('s2', 3),
      summary('revoked', 90),
    ];
    final writes = <int>[];
    final badge = MacOSDockUnread(
      platform: TargetPlatform.windows,
      write: (count) async => writes.add(count),
    );
    addTearDown(badge.dispose);
    expect(badge.supported, isTrue);
    badge.bind(w);
    await badge.refresh();
    await badge.settled;
    expect(writes.last, 13);
    w.activityUnread.acceptWindow({
      'items': [],
      'totalUnreadCount': 2,
    }, scope: w.activityUnread.scope);
    await badge.settled;
    expect(writes.last, 5);
    w.servers.removeWhere((server) => server.id == 's2');
    w.notifyListeners();
    await badge.settled;
    expect(writes.last, 2);
    api.user = null;
    w.notifyListeners();
    await badge.settled;
    expect(writes.last, 0);
  });
  test(
    'Dock totals known servers once; reads, foreground and revocation',
    () async {
      final (w, api) = fixture();
      w.servers = [
        w.server!,
        RaftRecord({'id': 's2', 'role': 'member'}),
      ];
      api.summaryRead = () => [
        summary('s1', 10),
        summary('s2', 3),
        summary('not-a-member', 90),
      ];
      final writes = <int>[];
      final badge = MacOSDockUnread(
        platform: TargetPlatform.macOS,
        write: (count) async => writes.add(count),
      );
      addTearDown(badge.dispose);
      await run(() async {
        badge.bind(w);
        await badge.refresh();
        await badge.settled;
      });
      expect(writes.last, 13);
      // Same shared accepted inbox used by Activity; the old summary's 10 is
      // replaced, while arbitrary Chat counts never get added to the app badge.
      w.conversationReads.unread['c1'] = 999;
      w.activityUnread.acceptWindow({
        'items': [],
        'totalUnreadCount': 2,
      }, scope: w.activityUnread.scope);
      await badge.settled;
      expect(writes.last, 5);
      w.setForeground(false);
      w.setForeground(true);
      w.notifyListeners();
      await badge.settled;
      expect(writes.last, 5, reason: 'activation is not a read receipt');
      w.activityUnread.acceptWindow({
        'items': [],
        'totalUnreadCount': 0,
      }, scope: w.activityUnread.scope);
      await badge.settled;
      expect(writes.last, 3);
      w.servers.removeWhere((server) => server.id == 's2');
      w.notifyListeners();
      await badge.settled;
      expect(
        writes.last,
        0,
        reason: 'revoked membership cannot retain an app badge',
      );
    },
  );

  test(
    'Dock ignores late account/role receipts and clears on retirement',
    () async {
      final (w, api) = fixture();
      final old = Completer<dynamic>();
      api.summaryRead = () => old.future;
      final writes = <int>[];
      final badge = MacOSDockUnread(
        platform: TargetPlatform.macOS,
        write: (count) async => writes.add(count),
      );
      addTearDown(badge.dispose);
      badge.bind(w);
      late Future<void> pending;
      await run(() async {
        pending = badge.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      badge.bind(null);
      await run(() async {
        old.complete([summary('s1', 78)]);
        await pending;
        await badge.settled;
      });
      expect(writes.last, 0);
      expect(writes, isNot(contains(78)));
      api.summaryRead = () => [summary('s1', 4)];
      await run(() async {
        badge.bind(w);
        await badge.refresh();
        await badge.settled;
      });
      expect(writes.last, 4);
      w.client.user = null;
      w.notifyListeners();
      await badge.settled;
      expect(writes.last, 0);
    },
  );

  test(
    'Dock preserves accepted unread on refresh error; permission independent',
    () async {
      final (w, api) = fixture();
      api.summaryRead = () => [summary('s1', 6)];
      final writes = <int>[];
      final badge = MacOSDockUnread(
        platform: TargetPlatform.macOS,
        write: (count) async => writes.add(count),
      );
      addTearDown(badge.dispose);
      await run(() async {
        badge.bind(w);
        await badge.refresh();
        await badge.settled;
      });
      api.summaryRead = () => throw StateError('offline');
      await run(() async {
        await badge.refresh();
        await badge.settled;
      });
      expect(writes.last, 6);
      await badge.dispose();
      expect(writes.last, 0);
    },
  );

  test(
    'Queued native writes cannot restore retired unread; failed writes retry',
    () async {
      final (w, api) = fixture();
      api.summaryRead = () => [summary('s1', 7)];
      final held = Completer<void>(), writes = <int>[];
      var block = true;
      final badge = MacOSDockUnread(
        platform: TargetPlatform.macOS,
        write: (count) async {
          if (block && count == 7) {
            await held.future;
          }
          writes.add(count);
        },
      );
      addTearDown(badge.dispose);
      await run(() async {
        badge.bind(w);
        await badge.refresh();
        await Future<void>.delayed(Duration.zero);
      });
      badge.bind(null);
      await run(() async {
        block = false;
        held.complete();
        await badge.settled;
      });
      expect(writes.last, 0);
      var fail = true;
      final retried = <int>[];
      final retry = MacOSDockUnread(
        platform: TargetPlatform.macOS,
        write: (count) async {
          if (fail) throw PlatformException(code: 'temporary');
          retried.add(count);
        },
      );
      addTearDown(retry.dispose);
      await run(() async {
        retry.bind(w);
        await retry.refresh();
        await retry.settled;
      });
      fail = false;
      await run(() async {
        retry.bind(w);
        await retry.settled;
      });
      expect(retried.last, 7);
    },
  );

  test(
    'Socket arrival and persisted read refresh cross-server totals',
    () async {
      final (w, client) = fixture();
      w.servers = [
        w.server!,
        RaftRecord({'id': 's2'}),
      ];
      var other = 1;
      client.summaryRead = () => [summary('s1', 0), summary('s2', other)];
      final writes = <int>[];
      final badge = MacOSDockUnread(
        platform: TargetPlatform.macOS,
        write: (count) async => writes.add(count),
      );
      addTearDown(badge.dispose);
      badge.bind(w);
      await badge.refresh();
      await badge.settled;
      expect(writes.last, 1);
      other = 4;
      client.ingress.add(
        RaftEvent('message:new', {'serverId': 's2', 'channelId': 'c2'}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 190));
      await badge.settled;
      expect(writes.last, 4);
      other = 0;
      final response = Response<dynamic>(
        requestOptions: RequestOptions(
          path: '/channels/c2/read-all',
          method: 'POST',
        ),
        data: {},
      );
      for (final interceptor in List<Interceptor>.of(
        client.http.interceptors,
      )) {
        interceptor.onResponse(response, ResponseInterceptorHandler());
      }
      await Future<void>.delayed(const Duration(milliseconds: 190));
      await badge.settled;
      expect(writes.last, 0);
    },
  );

  test('Role change rejects late summary; periodic reconciliation stops on dispose', () async {
    final (w, client) = fixture();
    final old = Completer<dynamic>();
    client.summaryRead = () => old.future;
    final writes = <int>[];
    final badge = MacOSDockUnread(
      platform: TargetPlatform.macOS,
      write: (count) async => writes.add(count),
      refreshInterval: const Duration(milliseconds: 30),
    );
    addTearDown(badge.dispose);
    badge.bind(w);
    final pending = badge.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    var reads = 0;
    client.summaryRead = () {
      reads++;
      return [summary('s1', 2)];
    };
    client.inboxTotal = 2;
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.notifyListeners();
    old.complete([summary('s1', 87)]);
    await pending;
    await Future<void>.delayed(const Duration(milliseconds: 75));
    await badge.settled;
    expect(writes.last, 2);
    expect(writes, isNot(contains(87)));
    expect(reads, greaterThanOrEqualTo(2));
    await badge.dispose();
    final retired = reads;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(reads, retired);
    expect(writes.last, 0);
  });

  test('macOS method channel receives zero and positive counts; hosts without an icon badge untouched', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app_badge_plus'), (
          call,
        ) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('app_badge_plus'),
            null,
          ),
    );
    final (w, api) = fixture();
    api.summaryRead = () => [summary('s1', 105)];
    final mac = MacOSDockUnread(platform: TargetPlatform.macOS);
    addTearDown(mac.dispose);
    await run(() async {
      mac.bind(null);
      await mac.settled;
      mac.bind(w);
      await mac.refresh();
      await mac.settled;
    });
    expect(calls.first.arguments, {'count': 0});
    expect(calls.last.method, 'updateBadge');
    expect(calls.last.arguments, {'count': 105});
    // Android launchers count notifications; Windows/Linux have no icon badge.
    final other = MacOSDockUnread(platform: TargetPlatform.android);
    final length = calls.length;
    other.bind(w);
    await other.dispose();
    expect(calls.length, length);
  });
}
