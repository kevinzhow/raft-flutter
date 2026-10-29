import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

RaftChannel _channel(String id, {bool public = false}) => RaftChannel({
  'id': id,
  'name': id,
  'type': public ? 'channel' : 'private',
  'joined': true,
});

class _Client extends RaftClient {
  _Client({super.origin = 'https://reply-authority.invalid'})
    : super(sessionStore: MemorySessionStore()) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  Future<void>? closing;
  int? forcedGeneration;
  @override
  int get generation => forcedGeneration ?? super.generation;
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels') return <dynamic>[];
    if (path.startsWith('/channels/')) {
      return _channel(path.split('/').last).json;
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
  @override
  Future<void> dispose() => closing ??= _close();
  Future<void> _close() async {
    await bus.close();
    await super.dispose();
  }
}

class _Fixture {
  _Fixture({String origin = 'https://reply-authority.invalid'}) {
    client = _Client(origin: origin);
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..servers = [
        RaftRecord({'id': 's1', 'role': 'owner'}),
      ]
      ..channels = [
        _channel('a'),
        _channel('b'),
        _channel('public', public: true),
      ];
    addTearDown(() async {
      workspace.dispose();
      await client.dispose();
    });
  }
  late final _Client client;
  late final WorkspaceController workspace;
  void emit(String name, dynamic payload) =>
      client.bus.add(RaftEvent(name, payload));
  void role(String value, {String user = 'alice', String server = 's1'}) =>
      workspace.applyMembershipRole({
        'serverId': server,
        'userId': user,
        'role': value,
      });
}

List<dynamic> _ticket(WorkspaceController w, String channel) =>
    jsonDecode(w.messageHistoryTicket(channel) as String) as List<dynamic>;

void main() {
  test('[R01] ticket shape and repeated reads are stable', () {
    final f = _Fixture(), w = f.workspace;
    final before = w.messageHistoryTicket('a');
    expect(_ticket(w, 'a'), [
      jsonEncode([
        f.client.origin,
        f.client.generation,
        's1',
        'alice',
        'owner',
      ]),
      0,
      'a',
      0,
    ]);
    expect(w.messageHistoryTicket('a'), before);
    expect(w.messageHistoryTicket('b'), isNot(before));
    expect(w.messageHistoryTicket('a'), before);
  });

  test('[R02] named authority event changes only its channel', () {
    final f = _Fixture(), w = f.workspace;
    final other = w.messageHistoryTicket('b');
    f.emit('channel:authority-updated', {'channelId': 'a'});
    expect(_ticket(w, 'a').sublist(1), [0, 'a', 1]);
    expect(w.messageHistoryTicket('b'), other);
  });

  test('[R03] repeated named events keep incrementing', () {
    final f = _Fixture(), w = f.workspace;
    f.emit('channel:authority-updated', {'channelId': 'a'});
    f.emit('channel:authority-updated', {'channelId': 'a'});
    expect(_ticket(w, 'a').sublist(1), [0, 'a', 2]);
    f.emit('channel:authority-updated', {'channelId': 'a'});
    expect(_ticket(w, 'a').sublist(1), [0, 'a', 3]);
  });

  test('[R04] id alias and unknown channel keep exact key', () {
    final f = _Fixture(), w = f.workspace;
    f.emit('channel:authority-updated', {'id': 'unknown'});
    expect(_ticket(w, 'unknown').sublist(1), [0, 'unknown', 1]);
    expect(_ticket(w, 'a').sublist(1), [0, 'a', 0]);
  });

  for (final payload in [
    <String, dynamic>{},
    {'channelId': ''},
    {'channelId': 4},
  ]) {
    test('[R05] invalid named scope fails closed globally: $payload', () {
      final f = _Fixture(), w = f.workspace;
      f.emit('channel:authority-updated', payload);
      expect(_ticket(w, 'a').sublist(1), [1, 'a', 0]);
      expect(_ticket(w, 'unvisited').sublist(1), [1, 'unvisited', 0]);
    });
  }

  test('[R06] global retirement preserves per-channel counters', () {
    final f = _Fixture(), w = f.workspace;
    f.emit('channel:authority-updated', {'channelId': 'a'});
    f.emit('channel:authority-updated', {});
    expect(_ticket(w, 'a').sublist(1), [1, 'a', 1]);
    expect(_ticket(w, 'b').sublist(1), [1, 'b', 0]);
    f.emit('channel:authority-updated', {'channelId': 'a'});
    f.emit('channel:authority-updated', {});
    expect(_ticket(w, 'a').sublist(1), [2, 'a', 2]);
  });

  test('[R07] public members do not retire private authority', () {
    final f = _Fixture(), w = f.workspace;
    final before = w.messageHistoryTicket('public');
    f.emit('channel:members-updated', {'channelId': 'public'});
    expect(w.messageHistoryTicket('public'), before);
    expect(_ticket(w, 'a').last, 0);
    f.emit('channel:members-updated', {'channelId': 'a'});
    expect(_ticket(w, 'a').last, 1);
    expect(w.messageHistoryTicket('public'), before);
  });

  test('[R08] channel removal retires only named reply authority', () {
    final f = _Fixture(), w = f.workspace;
    final other = w.messageHistoryTicket('b');
    f.emit('channel:removed', {'channelId': 'a'});
    expect(_ticket(w, 'a').sublist(1), [0, 'a', 1]);
    expect(w.messageHistoryTicket('b'), other);
  });

  test('[R09] unchanged role leaves the token untouched', () {
    final f = _Fixture(), w = f.workspace;
    final before = w.messageHistoryTicket('a');
    f.role('owner');
    expect(w.messageHistoryTicket('a'), before);
  });

  test('[R10] actual role change advances epoch and changes identity', () {
    final f = _Fixture(), w = f.workspace;
    final before = w.messageHistoryTicket('a');
    f.role('guest');
    expect(w.messageHistoryTicket('a'), isNot(before));
    final ticket = _ticket(w, 'a');
    expect(ticket.sublist(1), [1, 'a', 0]);
    expect((jsonDecode(ticket.first as String) as List).last, 'guest');
  });

  test('[R11] role ABA keeps identity but retires old tokens', () {
    final f = _Fixture(), w = f.workspace;
    final before = _ticket(w, 'a');
    f.role('guest');
    f.role('owner');
    expect(_ticket(w, 'a').first, before.first);
    expect(_ticket(w, 'a').sublist(1), [2, 'a', 0]);
  });

  test('[R12] another principal or server does not change this authority', () {
    final f = _Fixture(), w = f.workspace;
    final before = w.messageHistoryTicket('a');
    f.role('guest', user: 'bob');
    f.role('guest', server: 'other');
    expect(w.messageHistoryTicket('a'), before);
  });

  test('[R13] live generation is not cached by token owner', () {
    final f = _Fixture(), w = f.workspace;
    final before = w.messageHistoryTicket('a');
    f.client.forcedGeneration = 123;
    expect(w.messageHistoryTicket('a'), isNot(before));
    expect((jsonDecode(_ticket(w, 'a').first as String) as List)[1], 123);
    expect(_ticket(w, 'a').sublist(1), [0, 'a', 0]);
  });

  test('[R14] live principal and nullable role remain token inputs', () {
    final f = _Fixture(), w = f.workspace;
    final before = w.messageHistoryTicket('a');
    f.client.user = RaftRecord({'id': 'bob'});
    expect(w.messageHistoryTicket('a'), isNot(before));
    w.server = null;
    final identity = jsonDecode(_ticket(w, 'a').first as String) as List;
    expect(identity[3], 'bob');
    expect(identity[4], isNull);
    expect(_ticket(w, '').sublist(1), [0, '', 0]);
  });

  test('[R15] shared presentation keeps receiver-local epoch state', () {
    final f = _Fixture(), w = f.workspace;
    final borrowed = WorkspaceController(
      f.client,
      presentationSource: w,
      ownsClient: false,
    )..server = RaftRecord({'id': 's1', 'role': 'owner'});
    addTearDown(borrowed.dispose);
    final before = borrowed.messageHistoryTicket('a');
    f.role('guest');
    expect(_ticket(w, 'a')[1], 1);
    expect(borrowed.messageHistoryTicket('a'), before);
  });

  test('[R16] disposal and a new controller do not share counters', () {
    final f = _Fixture(), w = f.workspace;
    f.emit('channel:authority-updated', {'channelId': 'a'});
    expect(_ticket(w, 'a').last, 1);
    w.dispose();
    final other = _Fixture();
    expect(_ticket(other.workspace, 'a').sublist(1), [0, 'a', 0]);
  });
}
