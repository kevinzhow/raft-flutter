// Server v1.24.0 socket/index.ts: a failed member-room lookup sends
// `rooms:join_failed`, keeps retrying, and sends `rooms:joined` only once the
// rooms are joined. Until then no channel message:new arrives. Web
// (heartbeatGate noteRoomsJoinDegraded) does not take the connection for
// joined: it re-reads the visible scopes on every heartbeat, and runs the
// rooms:joined reads only when rooms:joined comes.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  final paths = <String>[];
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  bool get connected => true;
  @override
  void connect() {}
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
    paths.add('$method $path');
    return switch (path) {
      '/servers' => [
        {'id': 's', 'role': 'owner', 'name': 'Fixture'},
      ],
      '/channels/unread' => {'channels': {}},
      _ when path.startsWith('/messages') => {
        'messages': [],
        'hasMore': false,
        'hasNewer': false,
      },
      _ => <dynamic>[],
    };
  }
}

void main() {
  late _Client c;
  late WorkspaceController w;
  setUp(() async {
    c = _Client();
    w = WorkspaceController(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    w.channel = RaftChannel({'id': 'c1', 'name': 'general', 'joined': true});
    w.channels = [w.channel!];
    w.messageDomain.ledger.switchServer('s');
    w.messageDomain.ledger.ingest([
      {
        'id': 'm1',
        'channelId': 'c1',
        'seq': '1',
        'messageType': 'chat',
        'content': 'Shown',
        'senderName': 'Alice',
      },
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
  });
  tearDown(() async {
    w.dispose();
    await c.ingress.close();
    await c.dispose();
  });

  Future<List<String>> after(List<RaftEvent> events) async {
    final from = c.paths.length;
    for (final e in events) {
      c.ingress.add(e);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return c.paths.sublist(from);
  }

  bool roomsJoinedReads(List<String> paths) =>
      paths.contains('GET /channels') || paths.contains('GET /channels/unread');
  bool visibleScopeRead(List<String> paths) =>
      paths.contains('GET /messages/sync');

  test('after rooms:join_failed the first heartbeat is not rooms:joined, '
      'and each heartbeat re-reads the visible scope', () async {
    await after([const RaftEvent('connected', null)]);
    final failed = await after([
      const RaftEvent('rooms:join_failed', null),
      const RaftEvent('heartbeat', {'seq': '1'}),
    ]);
    expect(roomsJoinedReads(failed), isFalse, reason: '$failed');
    expect(visibleScopeRead(failed), isTrue, reason: '$failed');

    final again = await after([
      const RaftEvent('heartbeat', {'seq': '1'}),
    ]);
    expect(roomsJoinedReads(again), isFalse, reason: '$again');
    expect(visibleScopeRead(again), isTrue, reason: '$again');

    final joined = await after([const RaftEvent('rooms:joined', null)]);
    expect(roomsJoinedReads(joined), isTrue, reason: '$joined');

    // Joined: a heartbeat whose seq did not move reads nothing.
    final quiet = await after([
      const RaftEvent('heartbeat', {'seq': '1'}),
    ]);
    expect(visibleScopeRead(quiet), isFalse, reason: '$quiet');
  });

  test('a lost rooms:joined: the first heartbeat still stands in', () async {
    await after([const RaftEvent('connected', null)]);
    final first = await after([
      const RaftEvent('heartbeat', {'seq': '1'}),
    ]);
    expect(roomsJoinedReads(first), isTrue, reason: '$first');
  });
}
