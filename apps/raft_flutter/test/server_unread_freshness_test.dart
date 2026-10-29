import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_server_unread.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Failure {
  const _Failure();
}

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  FutureOr<dynamic> Function(RequestOptions) followed = (_) => {'threads': []};
  int get summaries =>
      calls.where((o) => o.path == '/servers/unread-summary').length;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final answer = o.path == '/channels/threads/followed'
        ? await followed(o)
        : null;
    if (answer is _Failure) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'Fixture failure'}),
        500,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    final body = switch (o.path) {
      '/channels/threads/followed' => answer,
      '/auth/login' => {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      },
      '/servers/unread-summary' => [
        {'serverId': 's2', 'unreadCount': 1, 'activityUnreadCount': 1},
      ],
      _ => {'error': 'Unexpected endpoint'},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      body is Map && body.containsKey('error') ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Adapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void emit(String name, [dynamic payload]) =>
      stream.add(RaftEvent(name, payload));
}

Map<String, dynamic> _prefs(Map<String, dynamic> prefs) => {
  'serverId': 's1',
  'scopeId': 's1',
  'prefsVersion': 2,
  'prefs': prefs,
};

/// Sidebar.tsx / LeftRail.tsx: the other servers' badges are read again every
/// two minutes and when the server-level notification prefs change (the
/// socket only reports the selected server). Web `coalesce` shares one read.
void main() {
  Future<(WorkspaceController, _Adapter, _Client)> fixture() async {
    final adapter = _Adapter();
    final client = _Client(adapter);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    final w = WorkspaceController(client);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    addTearDown(w.dispose);
    return (w, adapter, client);
  }

  test(
    '[BP-READ-051] a first read arms the 2-minute sweep; dispose stops it',
    () async {
      final (w, adapter, _) = await fixture();
      final store = SourceServerUnreadStore(w);
      fakeAsync((async) {
        void settle() {
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
        }

        unawaited(store.refresh());
        settle();
        expect(adapter.summaries, 1);
        async.elapse(SourceServerUnreadStore.sweepInterval * 3);
        settle();
        expect(adapter.summaries, 4, reason: 'one read per sweep');
        store.dispose();
        async.elapse(SourceServerUnreadStore.sweepInterval * 3);
        settle();
        expect(adapter.summaries, 4);
      });
    },
  );

  test('nothing is read before the first refresh', () async {
    final (w, adapter, _) = await fixture();
    final store = SourceServerUnreadStore(w);
    addTearDown(store.dispose);
    fakeAsync((async) {
      async.elapse(SourceServerUnreadStore.sweepInterval * 2);
      async.elapse(const Duration(seconds: 1));
      expect(adapter.summaries, 0);
    });
  });

  test('[BP-READ-059] a server-level prefs update refreshes; a channel-level one does not', () async {
    final (w, adapter, client) = await fixture();
    final store = SourceServerUnreadStore(w);
    addTearDown(store.dispose);
    await store.refresh();
    expect(adapter.summaries, 1);
    client.emit(
      'notification_prefs:updated',
      _prefs({'activityMuted': true, 'muteFromSeq': '4'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(adapter.summaries, 1, reason: 'channel prefs leave the summary');
    client.emit(
      'notification_prefs:updated',
      _prefs({'serverPushMuted': true}),
    );
    // The read is issued at once; give a loaded machine time to answer it.
    for (var i = 0; i < 100 && adapter.summaries < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(adapter.summaries, 2, reason: 'one read for the prefs update');
    expect(store['s2']!.activityUnreadCount, 1);
  });

  test('concurrent refreshes share one read', () async {
    final (w, adapter, _) = await fixture();
    final store = SourceServerUnreadStore(w);
    addTearDown(store.dispose);
    await Future.wait([store.refresh(), store.refresh(), store.refresh()]);
    expect(adapter.summaries, 1);
    await store.refresh();
    expect(adapter.summaries, 2, reason: 'a later refresh reads again');
  });

  group('followed threads are read a page at a time', () {
    Map<String, dynamic> row(String id) => {
      'parentMessageId': 'p-$id',
      'threadChannelId': 't-$id',
      'parentChannelId': 'c1',
      'unreadCount': 0,
    };

    test('limit, then each `next` cursor until none is named', () async {
      final (w, adapter, _) = await fixture();
      adapter.followed = (o) => switch (o.queryParameters['cursor']) {
        null => {
          'threads': [row('1')],
          'next': 'cursor 1',
        },
        'cursor 1' => {
          'threads': [row('2'), row('3')],
          'next': 'cursor 2',
        },
        _ => {
          'threads': [row('4')],
          'next': null,
        },
      };
      w.followedThreads.start();
      await w.followedThreads.idle;
      final asked = adapter.calls
          .where((o) => o.path == '/channels/threads/followed')
          .toList();
      expect(
        [for (final o in asked) o.queryParameters],
        [
          {'limit': 200},
          {'limit': 200, 'cursor': 'cursor 1'},
          {'limit': 200, 'cursor': 'cursor 2'},
        ],
      );
      expect(
        [for (final r in w.followedThreads.threads) r['threadChannelId']],
        ['t-1', 't-2', 't-3', 't-4'],
      );
      expect(w.followedThreads.loaded, isTrue);
    });

    test('a server before paging answers once, without a cursor', () async {
      final (w, adapter, _) = await fixture();
      adapter.followed = (_) => {
        'threads': [row('1'), row('2')],
      };
      w.followedThreads.start();
      await w.followedThreads.idle;
      expect(
        adapter.calls.where((o) => o.path == '/channels/threads/followed'),
        hasLength(1),
      );
      expect(w.followedThreads.threads, hasLength(2));
    });

    test('a failing later page keeps the rows already accepted', () async {
      final (w, adapter, _) = await fixture();
      adapter.followed = (_) => {
        'threads': [row('1')],
      };
      w.followedThreads.start();
      await w.followedThreads.idle;
      adapter.followed = (o) => o.queryParameters['cursor'] == null
          ? {
              'threads': [row('2')],
              'next': 'broken',
            }
          : const _Failure();
      await w.followedThreads.refresh();
      expect(
        [for (final r in w.followedThreads.threads) r['threadChannelId']],
        ['t-1'],
        reason: 'the half-read list is not accepted',
      );
    });
  });
}
