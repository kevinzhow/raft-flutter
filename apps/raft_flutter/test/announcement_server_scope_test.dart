// Web v1.21.23: announcement reads and dismissals carry `server_id`; without
// it the server never delivers a server-targeted announcement.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/announcement_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/announcement_host.dart';
import 'package:raft_ui/raft_ui.dart';

const _s1 = '11111111-1111-4111-8111-111111111111';
const _s2 = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> _row(String id, {String? server, int? version}) => {
  'id': id,
  'title': 'Title $id',
  'pages': [
    {'body': 'Body'},
  ],
  'publishedAt': '2026-10-01T00:00:00.000Z',
  'startsAt': '2026-10-01T00:00:00.000Z',
  'endsAt': null,
  'locale': 'en',
  'deliveryVersion': ?version,
  if (server != null)
    'deliveryScope': {'type': 'server', 'serverId': server}
  else if (version != null)
    'deliveryScope': {'type': 'account'},
};

class _Wire {
  final gets = <Map<String, dynamic>?>[];
  final posts = <(String, Map<String, dynamic>?)>[];
  Completer<dynamic>? hold;
  Object? Function(Map<String, dynamic>? query) answer = (_) => {
    'announcements': [_row('a1')],
  };
  final failPosts = <String>{};
  String? server;

  AnnouncementStore store() => AnnouncementStore(
    get: (path, {query}) async {
      gets.add(query);
      if (hold != null) return hold!.future;
      return answer(query);
    },
    post: (path, {query}) async {
      posts.add((path, query));
      if (failPosts.contains(server)) throw StateError('500');
      return {'ok': true};
    },
    principal: () => 'u1',
    serverId: () => server,
  );
}

void main() {
  group('AnnouncementStore server context', () {
    test(
      'load sends server_id of the selected server, none without one',
      () async {
        final wire = _Wire();
        final store = wire.store();
        await store.load();
        expect(wire.gets.single, isNull);
        store.reset();
        wire.server = _s1;
        await store.load();
        expect(wire.gets.last, {'server_id': _s1});
      },
    );

    test('dismiss sends server_id; account context sends none', () async {
      final wire = _Wire()..server = _s1;
      final store = wire.store();
      await store.load();
      await store.dismiss('a1');
      expect(wire.posts.single.$1, '/announcements/a1/dismiss');
      expect(wire.posts.single.$2, {'server_id': _s1});
      final account = _Wire();
      final accountStore = account.store();
      await accountStore.load();
      await accountStore.dismiss('a1');
      expect(account.posts.single.$1, '/announcements/a1/dismiss');
      expect(account.posts.single.$2, isNull);
    });

    test('a switch of server drops the other server rows and retires the in-flight read', () async {
      final wire = _Wire()
        ..server = _s1
        ..answer = (_) => {
          'announcements': [_row('x', server: _s1), _row('acct')],
        };
      final store = wire.store();
      await store.load();
      expect(store.pending.map((a) => a.id), ['x', 'acct']);
      wire.server = _s2;
      expect(store.needsReload, isTrue);
      await store.load();
      // The switch kept the account row and dropped the server one; a
      // presented row still owns the presentation, so nothing was read.
      expect(store.pending.map((a) => a.id), ['acct']);
      expect(store.loaded, isFalse);
      expect(wire.gets, hasLength(1));
      store.close('acct');
      wire.hold = Completer();
      final held = wire.hold!;
      final stale = store.load();
      expect(wire.gets.last, {'server_id': _s2});
      wire.hold = null;
      wire.answer = (_) => {
        'announcements': [_row('b', server: _s1)],
      };
      wire.server = _s1;
      await store.load();
      expect(store.pending.map((a) => a.id), ['b']);
      // The late answer of the previous server never lands.
      held.complete({
        'announcements': [_row('late', server: _s2)],
      });
      await stale;
      expect(store.pending.map((a) => a.id), ['b']);
    });

    test(
      'write failures advance only the queue of their own context',
      () async {
        final wire = _Wire()
          ..server = _s1
          ..failPosts.add(_s1);
        final store = wire.store();
        await store.load();
        await store.dismiss('a1');
        expect(store.writeFailedIds, ['a1']);
        store.reset();
        wire.server = _s1;
        await store.load();
        await store.dismiss('a1');
        await store.load();
        expect(wire.gets.last, {'after': 'a1', 'server_id': _s1});
        wire.server = _s2;
        await store.load();
        expect(wire.gets.last, {'server_id': _s2});
        store.close('a1');
        wire.server = null;
        await store.load();
        expect(wire.gets.last, isNull);
      },
    );

    test(
      'parses deliveryVersion and deliveryScope, legacy rows are account scope',
      () {
        final scoped = Announcement.fromJson(
          _row('a', server: _s1, version: 3),
        )!;
        expect((scoped.deliveryVersion, scoped.deliveryServerId), (3, _s1));
        final account = Announcement.fromJson(_row('b', version: 2))!;
        expect((account.deliveryVersion, account.deliveryServerId), (2, null));
        final legacy = Announcement.fromJson(_row('c'))!;
        expect((legacy.deliveryVersion, legacy.deliveryServerId), (null, null));
      },
    );
  });

  group('AnnouncementHost', () {
    testWidgets(
      'reads and dismisses with server_id and re-reads after a switch',
      (t) async {
        final requests = <String>[];
        final client = _Client((method, path, query) {
          requests.add('$method $path ${query ?? ''}');
          if (path == '/announcements/active') {
            return {
              'announcements': [
                _row(
                  's-${query?['server_id']}',
                  server: query?['server_id'] as String?,
                ),
              ],
            };
          }
          if (path.endsWith('/setup-projection')) return {'phase': null};
          return {'ok': true};
        });
        final w = WorkspaceController(client);
        addTearDown(w.dispose);
        final one = RaftRecord({
          'id': _s1,
          'slug': 'one',
          'name': 'One',
          'role': 'owner',
        });
        final two = RaftRecord({
          'id': _s2,
          'slug': 'two',
          'name': 'Two',
          'role': 'owner',
        });
        client.selectServer(_s1);
        w
          ..servers = [one, two]
          ..server = one;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            builder: (context, child) => RaftToastHost(child: child!),
            home: AnnouncementHost(
              controller: w,
              deployment: 'production',
              child: const Scaffold(body: Text('workspace')),
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(
          requests.where((r) => r.startsWith('GET /announcements/active')),
          ['GET /announcements/active {server_id: $_s1}'],
        );
        expect(
          find.byKey(const ValueKey('announcement-modal')),
          findsOneWidget,
        );
        await t.tap(find.text('Got it'));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(
          requests,
          contains('POST /announcements/s-$_s1/dismiss {server_id: $_s1}'),
        );
        client.selectServer(_s2);
        w.server = two;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        w.notifyListeners();
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(
          requests,
          contains('GET /announcements/active {server_id: $_s2}'),
        );
        expect(find.text('Title s-$_s2'), findsOneWidget);
      },
    );
  });
}

class _Client extends RaftClient {
  _Client(this.route)
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'u1', 'name': 'Kevin', 'displayName': 'Kevin'});
  }
  final FutureOr<dynamic> Function(String, String, Map<String, dynamic>?) route;
  final _events = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => _events.stream;
  @override
  void connect() {}
  @override
  Future<void> dispose() async => _events.close();
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
  }) async => route(method, path, query);
}
