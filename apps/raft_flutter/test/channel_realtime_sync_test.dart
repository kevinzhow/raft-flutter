import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;

/// A client whose socket the test drives and observes.
class _SocketClient extends RaftClient {
  _SocketClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final resumes = <BigInt>[];
  final joins = <String>[];
  var connects = 0;
  var live = true;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  bool get connected => live;
  @override
  void connect() => connects++;
  @override
  void resume(BigInt seq) => resumes.add(seq);
  @override
  void joinChannel(String channelId) => joins.add(channelId);
  void emit(String name, [dynamic payload]) =>
      stream.add(RaftEvent(name, payload));
}

class _MemoryCache implements WorkspaceCache {
  final values = <String, dynamic>{};
  @override
  Future<dynamic> read(o, p, s, String kind, String id) async =>
      values['$kind/$id'];
  @override
  Future<void> write(o, p, s, String kind, String id, value) async =>
      values['$kind/$id'] = value;
  @override
  Future<void> revokeChannel(o, p, s, String channel) async =>
      values.removeWhere((key, _) => key.endsWith('/$channel'));
  @override
  Future<void> clearAccount(o, p) async => values.clear();
  @override
  Future<void> revokeServer(o, p, s) async => values.clear();
  @override
  Future<List<Map<String, dynamic>>> readTranslations(o, p, s) async => [];
  @override
  Future<void> writeTranslations(o, p, s, entries) async {}
  @override
  Future<void> close() async {}
}

Map<String, dynamic> _c1() => {
  'id': 'c1',
  'serverId': 's1',
  'name': 'design',
  'joined': true,
  'channelCapabilities': {'viewChannel': true},
};
Map<String, dynamic> _c2() => {
  'id': 'c2',
  'serverId': 's1',
  'name': 'secret',
  'type': 'private',
  'joined': true,
};
Map<String, dynamic> _c3() => {
  'id': 'c3',
  'serverId': 's1',
  'name': 'release',
  'joined': true,
};
Map<String, dynamic> _dm(String id) => {
  'id': id,
  'serverId': 's1',
  'name': id,
  'type': 'dm',
  'peerType': 'user',
  'peerId': 'peer-$id',
};

Map<String, dynamic> _row(String id, String channel, int seq) => {
  'id': id,
  'channelId': channel,
  'seq': '$seq',
  'senderId': 'bob',
  'senderType': 'user',
  'senderName': 'bob',
  'content': 'Body $id',
  'createdAt': '2026-10-10T02:30:00Z',
};

typedef _Fixture = (
  WorkspaceController,
  MessageAdapter,
  _SocketClient,
  _MemoryCache,
);

Future<_Fixture> _login() async {
  final a = MessageAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes['GET /channels'] = (_) => [_c1(), _c2(), _c3()];
  a.routes['GET /channels/dm'] = (_) => [_dm('d1'), _dm('d2')];
  a.routes['GET /channels/unread'] = (_) => {'channels': {}};
  for (final row in [_c1(), _c2(), _c3(), _dm('d1'), _dm('d2')]) {
    a.routes['GET /channels/${row['id']}'] = (_) => row;
  }
  a.routes['GET /messages/channel/c1'] = (_) => {
    'messages': [_row('m1', 'c1', 11), _row('m2', 'c1', 12)],
  };
  a.routes['GET /messages/channel/c3'] = (_) => {
    'messages': [_row('r3', 'c3', 5)],
  };
  a.routes['GET /messages/channel/c2'] = (_) => {
    'messages': [_row('s1', 'c2', 21)],
  };
  a.routes['POST /channels/c1/read'] = (_) => {};
  a.routes['GET /servers'] = (_) => [
    {'id': 's1', 'role': 'member'},
  ];
  a.routes['GET /servers/s1/sidebar-order'] = (_) => {};
  a.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  final client = _SocketClient(a);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final cache = _MemoryCache();
  final w = WorkspaceController(client, cache: cache);
  w.server = RaftRecord({'id': 's1', 'role': 'member'});
  w.channels = [RaftChannel(_c1()), RaftChannel(_c2()), RaftChannel(_c3())];
  w.dms = [RaftChannel(_dm('d1')), RaftChannel(_dm('d2'))];
  w.ledger.switchServer('s1');
  return (w, a, client, cache);
}

Future<void> _drain() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

List<String> _paths(MessageAdapter a, int from) => [
  for (final call in a.calls.skip(from)) '${call.method} ${call.path}',
];

Iterable<String> _listReads(MessageAdapter a, int from) => _paths(
  a,
  from,
).where((p) => p == 'GET /channels' || p == 'GET /channels/dm');

void main() {
  group('channel events change one row', () {
    test('channel:updated with a row patches only that row, no HTTP', () async {
      final (w, a, client, cache) = await _login();
      addTearDown(w.dispose);
      w.channel = w.channels.first;
      final before = [...w.channels, ...w.dms];
      final calls = a.calls.length;
      client.emit('channel:updated', {
        'channel': {
          'id': 'c1',
          'serverId': 's1',
          'name': 'design-renamed',
          'description': 'new topic',
        },
      });
      await _drain();
      expect(_paths(a, calls), isEmpty);
      final patched = w.channels.first;
      expect(patched.name, 'design-renamed');
      expect(patched.description, 'new topic');
      // Viewer fields the room projection does not carry are kept.
      expect(patched.joined, isTrue);
      expect(patched.json['channelCapabilities'], {'viewChannel': true});
      expect(identical(w.channel, patched), isTrue);
      // Every other row keeps its object and its place.
      expect(w.channels.map((c) => c.id), ['c1', 'c2', 'c3']);
      for (final c in before.skip(1)) {
        expect(
          identical([...w.channels, ...w.dms][before.indexOf(c)], c),
          true,
        );
      }
      await w.flushCache();
      final saved = cache.values['channels/'] as Map;
      expect((saved['channels'] as List).first['name'], 'design-renamed');
      expect((saved['dms'] as List), hasLength(2));
    });

    test('a row from another server is ignored', () async {
      final (w, a, client, _) = await _login();
      addTearDown(w.dispose);
      final before = w.channels;
      final calls = a.calls.length;
      client.emit('channel:updated', {
        'channel': {'id': 'c1', 'serverId': 's2', 'name': 'elsewhere'},
      });
      await _drain();
      expect(_paths(a, calls), isEmpty);
      expect(identical(w.channels, before), isTrue);
    });

    test(
      'id-only channel:updated and members-updated read one channel',
      () async {
        final (w, a, client, _) = await _login();
        addTearDown(w.dispose);
        final calls = a.calls.length;
        a.routes['GET /channels/c3'] = (_) => {..._c3(), 'memberCount': 9};
        final c1 = w.channels.first;
        client.emit('channel:updated', {'channelId': 'c3'});
        client.emit('channel:members-updated', {'channelId': 'c1'});
        await _drain();
        expect(_paths(a, calls), ['GET /channels/c3', 'GET /channels/c1']);
        expect(_listReads(a, calls), isEmpty);
        expect(w.channels[2].json['memberCount'], 9);
        // An unchanged read keeps the held object.
        expect(identical(w.channels.first, c1), isTrue);
      },
    );

    test(
      'authority-updated reads that one channel; no id reloads lists',
      () async {
        final (w, a, client, _) = await _login();
        addTearDown(w.dispose);
        var calls = a.calls.length;
        client.emit('channel:authority-updated', {
          'channelId': 'c3',
          'channelRole': 'viewer',
        });
        await _drain();
        expect(_paths(a, calls), ['GET /channels/c3']);
        calls = a.calls.length;
        client.emit('channel:members-updated', {});
        await _drain();
        expect(_listReads(a, calls).toSet(), {
          'GET /channels',
          'GET /channels/dm',
        });
      },
    );

    test(
      'dm:new reads only a new DM; a held DM moves first without HTTP',
      () async {
        final (w, a, client, cache) = await _login();
        addTearDown(w.dispose);
        a.routes['GET /channels/d3'] = (_) => _dm('d3');
        var calls = a.calls.length;
        final d1 = w.dms.first, d2 = w.dms[1];
        client.emit('dm:new', {'channelId': 'd3'});
        await _drain();
        expect(_paths(a, calls), ['GET /channels/d3']);
        expect(client.joins, ['d3']);
        expect(w.dms.map((c) => c.id), ['d3', 'd1', 'd2']);
        expect(identical(w.dms[1], d1), isTrue);
        calls = a.calls.length;
        client.emit('dm:new', {'channelId': 'd2'});
        await _drain();
        expect(_paths(a, calls), isEmpty);
        expect(w.dms.map((c) => c.id), ['d2', 'd3', 'd1']);
        expect(identical(w.dms.first, d2), isTrue);
        await w.flushCache();
        final saved = cache.values['channels/'] as Map;
        expect(
          [for (final r in saved['dms'] as List) r['id']],
          ['d2', 'd3', 'd1'],
        );
      },
    );

    test(
      'lost access on the single read revokes exactly that channel',
      () async {
        final (w, a, client, cache) = await _login();
        addTearDown(w.dispose);
        await w.selectChannel(w.channels[2], autoRead: false); // c3
        await w.selectChannel(w.channels[1], autoRead: false); // c2
        await w.flushCache();
        expect(w.visibleIds['c2'], isNotEmpty);
        expect(cache.values['window/c2'], isNotNull);
        // The adapter answers an unrouted read with 404 Channel not found.
        a.routes.remove('GET /channels/c2');
        final calls = a.calls.length;
        client.emit('channel:members-updated', {'channelId': 'c2'});
        await _drain();
        await w.flushCache();
        expect(_paths(a, calls), ['GET /channels/c2']);
        expect(w.channels.map((c) => c.id), ['c1', 'c3']);
        expect(w.channel, isNull);
        expect(w.visibleIds['c2'], isNull);
        expect(w.ledger.messages('c2'), isEmpty);
        expect(cache.values['window/c2'], isNull);
        // The unrelated channel keeps its window.
        expect(w.visibleIds['c3'], isNotEmpty);
        final saved = cache.values['channels/'] as Map;
        expect(
          [for (final r in saved['channels'] as List) r['id']],
          ['c1', 'c3'],
        );
      },
    );

    test(
      'a private row no longer joined is revoked like a list omission',
      () async {
        final (w, a, client, _) = await _login();
        addTearDown(w.dispose);
        a.routes['GET /channels/c2'] = (_) => {..._c2(), 'joined': false};
        client.emit('channel:authority-updated', {'channelId': 'c2'});
        await _drain();
        expect(w.channels.map((c) => c.id), ['c1', 'c3']);
        // A patch saying the same is confirmed by a read, never trusted alone.
        final calls = a.calls.length;
        a.routes['GET /channels/c2'] = (_) => _c2();
        client.emit('channel:updated', {
          'channel': {..._c2(), 'joined': true},
        });
        await _drain();
        expect(_paths(a, calls), ['GET /channels/c2']);
        expect(w.channels.map((c) => c.id), ['c1', 'c3', 'c2']);
      },
    );

    test('a list read that started earlier never drops a newer row', () async {
      final (w, a, client, _) = await _login();
      addTearDown(w.dispose);
      final gate = Completer<void>();
      a.routes['GET /channels/dm'] = (_) async {
        await gate.future;
        return [_dm('d1'), _dm('d2')];
      };
      a.routes['GET /channels/d3'] = (_) => _dm('d3');
      final refresh = w.refreshChannels();
      await _drain();
      client.emit('dm:new', {'channelId': 'd3'});
      await _drain();
      expect(w.dms.map((c) => c.id), ['d3', 'd1', 'd2']);
      gate.complete();
      await refresh;
      expect(w.dms.map((c) => c.id), ['d3', 'd1', 'd2']);
    });
  });

  group('reconnect and resume', () {
    Future<_Fixture> open() async {
      final f = await _login();
      final (w, a, _, _) = f;
      await w.selectChannel(w.channels.first, autoRead: false);
      a.routes['GET /messages/sync'] = (o) => [
        if (o.queryParameters['channel_id'] == 'c1')
          for (final row in [_row('m3', 'c1', 30), _row('m4', 'c1', 31)])
            if (BigInt.parse('${row['seq']}') >
                BigInt.parse('${o.queryParameters['since_seq']}'))
              row,
      ];
      return f;
    }

    test(
      'connected waits; rooms:joined resumes, gap-syncs and reloads',
      () async {
        final (w, a, client, _) = await open();
        addTearDown(w.dispose);
        var calls = a.calls.length;
        client.emit('connected');
        await _drain();
        expect(client.resumes, isEmpty);
        expect(_listReads(a, calls), isEmpty);
        expect(_paths(a, calls), isNot(contains('GET /channels/unread')));
        calls = a.calls.length;
        client.emit('rooms:joined');
        await _drain();
        expect(client.resumes, [BigInt.from(12)]);
        final sync = a.calls.firstWhere((c) => c.path == '/messages/sync');
        expect(sync.queryParameters['since_seq'], '12');
        expect(sync.queryParameters['channel_id'], 'c1');
        expect(_listReads(a, calls).toSet(), {
          'GET /channels',
          'GET /channels/dm',
        });
        expect(_paths(a, calls), contains('GET /channels/unread'));
        expect(w.messages.map((m) => m.id), ['m1', 'm2', 'm3', 'm4']);
      },
    );

    test('heartbeat past the watermark gap-syncs once per seq', () async {
      final (w, a, client, _) = await open();
      addTearDown(w.dispose);
      int syncs() => a.calls.where((c) => c.path == '/messages/sync').length;
      client.emit('heartbeat', {'seq': 12, 'ts': 1});
      await _drain();
      expect(syncs(), 0, reason: 'no gap at the watermark');
      client.emit('heartbeat', {'seq': 40, 'ts': 2});
      await _drain();
      expect(syncs(), 1);
      expect(w.messages.map((m) => m.id), ['m1', 'm2', 'm3', 'm4']);
      // The server seq covers channels this window never shows.
      client.emit('heartbeat', {'seq': 40, 'ts': 3});
      await _drain();
      expect(syncs(), 1);
    });

    test('foreground resume on a live socket resumes and gap-syncs', () async {
      final (w, a, client, _) = await open();
      addTearDown(w.dispose);
      final calls = a.calls.length;
      w.resumeLiveSession();
      await _drain();
      expect(client.connects, 0);
      expect(client.resumes, [BigInt.from(12)]);
      expect(_listReads(a, calls), isEmpty);
      expect(w.messages.map((m) => m.id), ['m1', 'm2', 'm3', 'm4']);
      client.live = false;
      w.resumeLiveSession();
      expect(client.connects, 1, reason: 'rooms:joined will resume');
    });

    test('the open thread reads its own gap', () async {
      final (w, a, client, _) = await open();
      addTearDown(w.dispose);
      a.routes['GET /messages/channel/t1'] = (_) => {
        'messages': [_row('r1', 't1', 13)],
      };
      a.routes['POST /channels/t1/read'] = (_) => {};
      await w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'm1',
        initialThreadChannelId: 't1',
      );
      await _drain();
      expect(w.replies.map((m) => m.id), ['r1']);
      final inner = a.routes['GET /messages/sync']!;
      a.routes['GET /messages/sync'] = (o) =>
          o.queryParameters['channel_id'] == 't1'
          ? [_row('r2', 't1', 35)]
          : inner(o);
      client.emit('rooms:joined');
      await _drain();
      expect(w.replies.map((m) => m.id), ['r1', 'r2']);
      expect(w.messages.map((m) => m.id), ['m1', 'm2', 'm3', 'm4']);
    });

    test('a 404 on the gap read revokes through the channel read', () async {
      final (w, a, client, _) = await open();
      addTearDown(w.dispose);
      a.routes.remove('GET /messages/sync');
      a.routes.remove('GET /channels/c1');
      client.emit('heartbeat', {'seq': 50, 'ts': 1});
      await _drain();
      expect(a.calls.where((c) => c.path == '/channels/c1'), hasLength(1));
      expect(w.channels.map((c) => c.id), ['c2', 'c3']);
      expect(w.channel, isNull);
    });
  });

  testWidgets('reconnect gap sync appends without blanking displayed rows', (
    t,
  ) async {
    final (w, a, client, _) = (await t.runAsync(_login))!;
    addTearDown(w.dispose);
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 10));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await t.pump();
    }

    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    unawaited(w.selectChannel(w.channels.first, autoRead: false));
    await settle();
    final m1 = find.byKey(const ValueKey('message-m1'));
    final m2 = find.byKey(const ValueKey('message-m2'));
    expect(m1, findsOneWidget);
    expect(m2, findsOneWidget);
    final gate = Completer<List<Map<String, dynamic>>>();
    a.routes['GET /messages/sync'] = (_) => gate.future;
    final before = (t.getRect(m1), t.getRect(m2));

    client.emit('connected');
    client.emit('rooms:joined');
    // While the gap read is in flight nothing moves or blanks.
    for (var frame = 0; frame < 6; frame++) {
      await t.pump(const Duration(milliseconds: 16));
      expect(m1, findsOneWidget);
      expect((t.getRect(m1), t.getRect(m2)), before);
    }
    gate.complete([_row('m3', 'c1', 30)]);
    final m3 = find.byKey(const ValueKey('message-m3'));
    for (var i = 0; i < 10 && m3.evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump();
      // Never blanked or reloaded: until the new row lands, the held rows
      // are painted at their place.
      expect(m1, findsOneWidget);
      expect(m2, findsOneWidget);
      if (m3.evaluate().isEmpty) {
        expect((t.getRect(m1), t.getRect(m2)), before);
      }
    }
    expect(m3, findsOneWidget);
    // Like a live message:new at the bottom edge, the held rows move up once
    // as one block by the appended row; their own layout never changes.
    final after = (t.getRect(m1), t.getRect(m2));
    final shift = after.$1.top - before.$1.top;
    expect(after.$2.top - before.$2.top, shift);
    expect(after.$1.size, before.$1.size);
    expect(after.$2.size, before.$2.size);
    expect(-shift, moreOrLessEquals(t.getRect(m3).top - after.$2.top));
    for (var frame = 0; frame < 6; frame++) {
      await t.pump(const Duration(milliseconds: 16));
      expect((t.getRect(m1), t.getRect(m2)), after);
    }
    expect(w.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
  });
}
