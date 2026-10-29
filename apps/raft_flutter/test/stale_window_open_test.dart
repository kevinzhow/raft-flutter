import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

import 'message_presentation_test.dart' show MessageAdapter;

/// A client whose socket events the test drives.
class _EventClient extends RaftClient {
  _EventClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void emit(String name, dynamic payload) =>
      stream.add(RaftEvent(name, payload));
}

final _c1 = RaftChannel({'id': 'c1', 'name': 'design', 'joined': true});
final _dm = RaftChannel({'id': 'dm1', 'type': 'dm', 'joined': true});

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

/// The server's messages per channel; the page route serves its tail.
class _Server {
  final Map<String, List<Map<String, dynamic>>> rows = {};
  int pages(MessageAdapter a, String channel) =>
      a.calls.where((c) => c.path == '/messages/channel/$channel').length;
}

Future<(WorkspaceController, MessageAdapter, _EventClient, _Server)>
_login() async {
  final a = MessageAdapter();
  final server = _Server();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes['GET /agents'] = (_) => [];
  a.routes['GET /servers/s1/members'] = (_) => [];
  a.routes['GET /channels'] = (_) => [_c1.json];
  a.routes['GET /channels/dm'] = (_) => [_dm.json];
  a.routes['GET /channels/unread'] = (_) => {'channels': {}};
  for (final c in [_c1, _dm]) {
    a.routes['GET /channels/${c.id}'] = (_) => c.json;
    a.routes['GET /messages/channel/${c.id}'] = (_) => {
      'messages': server.rows[c.id] ?? [],
    };
    a.routes['POST /channels/${c.id}/read'] = (_) => {};
  }
  final client = _EventClient(a);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'member'});
  w.channels = [_c1];
  w.dms = [_dm];
  w.channel = _c1;
  w.messageDomain.ledger.switchServer('s1');
  return (w, a, client, server);
}

Future<void> _drain() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  test(
    'opening a retained window the socket never updated fetches the tail and shows the new rows',
    () async {
      final (w, a, _, server) = await _login();
      addTearDown(w.dispose);
      server.rows['dm1'] = [_row('m1', 'dm1', 10)];
      await w.selectChannel(_dm, autoRead: false);
      await w.selectChannel(_c1, autoRead: false);
      expect(server.pages(a, 'dm1'), 1);
      // Messages the socket missed while the app was away.
      server.rows['dm1'] = [
        _row('m1', 'dm1', 10),
        for (var i = 2; i <= 8; i++) _row('m$i', 'dm1', 9 + i),
      ];
      // An Activity row / notification tap targets the oldest unread, which
      // the retained window already holds.
      await w.jumpToMessage('dm1', 'm1', navigate: false);
      await _drain();
      expect(
        server.pages(a, 'dm1'),
        2,
        reason: 'a retained window is revalidated on open',
      );
      expect(w.messageDomain.messages.map((m) => m.id), [for (var i = 1; i <= 8; i++) 'm$i']);
    },
  );

  test(
    'live rows for a channel that is not open join its retained window',
    () async {
      final (w, a, client, server) = await _login();
      addTearDown(w.dispose);
      server.rows['dm1'] = [_row('m1', 'dm1', 10)];
      await w.selectChannel(_dm, autoRead: false);
      await w.selectChannel(_c1, autoRead: false);
      client.emit('message:new', _row('m2', 'dm1', 11));
      client.emit('message:new', _row('m3', 'dm1', 12));
      expect(w.messageDomain.visibleIds['dm1'], {'m1', 'm2', 'm3'});
      server.rows['dm1'] = [
        _row('m1', 'dm1', 10),
        _row('m2', 'dm1', 11),
        _row('m3', 'dm1', 12),
      ];
      await w.jumpToMessage('dm1', 'm1', navigate: false);
      await _drain();
      expect(w.messageDomain.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
    },
  );

  test('a live row after unseen newer rows fills the gap', () async {
    final (w, a, client, server) = await _login();
    addTearDown(w.dispose);
    server.rows['c1'] = [_row('p', 'c1', 10)];
    await w.selectChannel(_c1, autoRead: false);
    // Rows 11 and 12 reached the ledger (e.g. a resume or another surface)
    // but not this window; row 13 arrives live.
    w.messageDomain.ledger.ingest([
      _row('g1', 'c1', 11),
      _row('g2', 'c1', 12),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    server.rows['c1'] = [
      for (final (i, id) in ['p', 'g1', 'g2', 'live'].indexed)
        _row(id, 'c1', 10 + i),
    ];
    final before = server.pages(a, 'c1');
    client.emit('message:new', _row('live', 'c1', 13));
    await _drain();
    expect(w.messageDomain.messages.map((m) => m.id), ['p', 'g1', 'g2', 'live']);
    expect(server.pages(a, 'c1'), before + 1, reason: 'one tail refresh');
  });

  test('revalidation keeps rows unique and the reading order stable', () async {
    final (w, a, client, server) = await _login();
    addTearDown(w.dispose);
    server.rows['dm1'] = [_row('m1', 'dm1', 10), _row('m2', 'dm1', 11)];
    await w.selectChannel(_dm, autoRead: false);
    await w.selectChannel(_c1, autoRead: false);
    final rows = [..._rows(server, 'dm1'), _row('m3', 'dm1', 12)];
    server.rows['dm1'] = rows;
    // m3 is delivered live and again by the page: still one row.
    client.emit('message:new', _row('m3', 'dm1', 12));
    final unread = w.conversationReads.unread['dm1'];
    await w.jumpToMessage('dm1', 'm1', navigate: false);
    await _drain();
    expect(server.pages(a, 'dm1'), 2);
    expect(w.messageDomain.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
    client.emit('message:new', _row('m3', 'dm1', 12));
    await _drain();
    final ids = w.messageDomain.messages.map((m) => m.id).toList();
    expect(ids, ['m1', 'm2', 'm3']);
    expect(ids.toSet().length, ids.length);
    expect(w.conversationReads.unread['dm1'], unread, reason: 'a redelivery counts once');
    expect(w.messageDomain.state.highlightedMessageId, 'm1', reason: 'the target stays focused');
  });

  test(
    'a jump inside the channel being followed does not re-read it',
    () async {
      final (w, a, _, server) = await _login();
      addTearDown(w.dispose);
      server.rows['dm1'] = [_row('m1', 'dm1', 10), _row('m2', 'dm1', 11)];
      await w.selectChannel(_dm, autoRead: false);
      await w.jumpToMessage('dm1', 'm1', navigate: false);
      await _drain();
      expect(server.pages(a, 'dm1'), 1);
    },
  );

  test('a failed revalidation leaves the shown window as it was', () async {
    final (w, a, _, server) = await _login();
    addTearDown(w.dispose);
    server.rows['dm1'] = [_row('m1', 'dm1', 10)];
    await w.selectChannel(_dm, autoRead: false);
    await w.selectChannel(_c1, autoRead: false);
    a.routes['GET /messages/channel/dm1'] = (_) =>
        throw const RaftApiException('offline');
    await w.jumpToMessage('dm1', 'm1', navigate: false);
    await _drain();
    expect(w.messageDomain.messages.map((m) => m.id), ['m1']);
    expect(w.error, isNull);
  });
}

List<Map<String, dynamic>> _rows(_Server server, String id) =>
    server.rows[id] ?? [];
