import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/read_receipts.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_read_badge.dart';

/// Web MentionLink #693: the read marker on an @mentioned agent shows only to
/// the human who sent the message, only for agents, and only once the
/// channel's read frontiers are known.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final details = <String, dynamic>{};
  final reads = <String>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels') {
      return [
        {'id': 'c1', 'name': 'general', 'type': 'channel'},
        {'id': 'c2', 'name': 'all', 'type': 'channel'},
        {'id': 'c3', 'name': 'joint', 'type': 'joint'},
      ];
    }
    if (path.startsWith('/channels/') && path.length > 10) {
      final id = path.substring(10);
      if (details.containsKey(id)) {
        reads.add(id);
        return details[id];
      }
    }
    return [];
  }
}

Map<String, dynamic> _peer(String kind, String id, int seq) => {
  'peerKind': kind,
  'peerId': id,
  'maxReadSeq': seq,
};

RaftMessage _message({
  String channel = 'c1',
  String sender = 'alice',
  String type = 'user',
  int seq = 10,
}) => RaftMessage({
  'id': 'm1',
  'channelId': channel,
  'senderId': sender,
  'senderType': type,
  'seq': '$seq',
});

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Client client;
  late WorkspaceController w;
  setUp(() async {
    client = _Client();
    w = WorkspaceController(client);
    await w.bootstrap();
  });
  tearDown(() async {
    w.dispose();
    await client.stream.close();
  });

  test(
    'one read of the channel per session, then the frontiers decide',
    () async {
      client.details['c1'] = {
        'peerReadStates': [_peer('agent', 'ada', 12), _peer('agent', 'bo', 9)],
      };
      watchReadFrontiers(w, 'c1');
      watchReadFrontiers(w, 'c1');
      await _settle();
      expect(client.reads, ['c1']);
      final scope = w.readReceipts.scope('c1');
      expect(projectAgentReadReceipt(scope, 'ada', 10), isTrue);
      expect(projectAgentReadReceipt(scope, 'bo', 10), isFalse);
      expect(projectAgentReadReceipt(scope, 'stranger', 10), isNull);
    },
  );

  test('only the sender, for a human message in a scope with frontiers', () {
    final general = RaftChannel({
      'id': 'c1',
      'name': 'general',
      'type': 'channel',
    });
    RaftChannel channel(String name, String type) =>
        RaftChannel({'id': 'c', 'name': name, 'type': type});
    expect(agentReadEligible(general, _message(), 'alice'), isTrue);
    expect(agentReadEligible(channel('d', 'dm'), _message(), 'alice'), isTrue);
    expect(agentReadEligible(general, _message(), 'bob'), isFalse);
    expect(
      agentReadEligible(general, _message(sender: 'bob'), 'alice'),
      isFalse,
    );
    expect(
      agentReadEligible(general, _message(type: 'agent'), 'alice'),
      isFalse,
    );
    expect(
      agentReadEligible(channel('all', 'channel'), _message(), 'alice'),
      isFalse,
    );
    expect(
      agentReadEligible(channel('j', 'joint'), _message(), 'alice'),
      isFalse,
    );
    expect(
      agentReadEligible(channel('t', 'thread'), _message(), 'alice'),
      isFalse,
    );
    expect(agentReadEligible(null, _message(), 'alice'), isFalse);
    expect(agentReadEligible(general, _message(), null), isFalse);
  });

  test('a live frame repaints the rows', () async {
    client.details['c1'] = {
      'peerReadStates': [_peer('agent', 'ada', 3)],
    };
    watchReadFrontiers(w, 'c1');
    await _settle();
    expect(
      projectAgentReadReceipt(w.readReceipts.scope('c1'), 'ada', 10),
      isFalse,
    );
    var notified = 0;
    w.addListener(() => notified++);
    client.stream.add(
      RaftEvent('scope_read:updated', {
        'scopeId': 'c1',
        ..._peer('agent', 'ada', 11),
      }),
    );
    await _settle();
    expect(
      projectAgentReadReceipt(w.readReceipts.scope('c1'), 'ada', 10),
      isTrue,
    );
    expect(notified, greaterThan(0));
  });
}
