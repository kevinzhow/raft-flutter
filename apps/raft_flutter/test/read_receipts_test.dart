import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/read_receipts.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

/// Source readReceiptStore / readReceiptDomain (flag `read_receipts_v0`):
/// hydrating a scope is the gate, live peer frames merge a max, a summary
/// frame re-hydrates, and a sent message projects read / count.
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
  int detailReads = 0;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.startsWith('/channels/') &&
        details.containsKey(path.substring(10))) {
      detailReads++;
      return details[path.substring(10)];
    }
    return [];
  }
}

Map<String, dynamic> _peer(String kind, String id, int seq) => {
  'peerKind': kind,
  'peerId': id,
  'maxReadSeq': seq,
};

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('[BP-READ-060] hydrating a scope reads peerReadStates or peerReadSummary; anything else disables receipts', () {
    final peers = normalizeReadReceiptHydrate({
      'peerReadStates': [_peer('human', 'bob', 5), _peer('agent', 'a1', 3)],
    });
    expect(peers!.peers!.map((p) => p.key), ['human:bob', 'agent:a1']);
    final summary = normalizeReadReceiptHydrate({
      'peerReadSummary': {
        'peerCount': 4,
        'readCountAtSeq': [
          {'seq': 5, 'count': 3},
          {'seq': 9, 'count': 1},
        ],
      },
    });
    expect(summary!.isSummary, isTrue);
    expect(
      normalizeReadReceiptHydrate({'id': 'c'}),
      isNull,
      reason: 'flag off',
    );
    expect(
      normalizeReadReceiptHydrate({
        'peerReadStates': [],
        'peerReadSummary': {'peerCount': 0, 'readCountAtSeq': []},
      }),
      isNull,
      reason: 'both shapes',
    );
    expect(
      normalizeReadReceiptHydrate({
        'peerReadStates': [_peer('human', 'bob', 1), _peer('human', 'bob', 2)],
      }),
      isNull,
      reason: 'duplicate peer',
    );
    expect(
      normalizeReadReceiptHydrate({
        'peerReadSummary': {
          'peerCount': 2,
          'readCountAtSeq': [
            {'seq': 5, 'count': 1},
            {'seq': 4, 'count': 0},
          ],
        },
      }),
      isNull,
      reason: 'ladder out of order',
    );
  });

  test('[BP-READ-062] a sent message projects read and read count from peers or the summary ladder', () {
    final peers = ReadReceiptScope.peers([
      const PeerReadState('human', 'bob', 5),
      const PeerReadState('agent', 'a1', 9),
      const PeerReadState('agent', 'a2', 0),
    ]);
    final five = projectReadReceipt(peers, 5);
    expect([five.read, five.readCount, five.peerCount], [true, 2, 3]);
    final ten = projectReadReceipt(peers, 10);
    expect([ten.read, ten.readCount], [false, 0]);
    expect(projectAgentReadReceipt(peers, 'a1', 6), isTrue);
    expect(projectAgentReadReceipt(peers, 'a2', 6), isFalse);
    expect(projectAgentReadReceipt(peers, 'nobody', 6), isNull);
    final ladder = ReadReceiptScope.summary(4, [(5, 3), (9, 1)]);
    expect(projectReadReceipt(ladder, 4).readCount, 3);
    expect(projectReadReceipt(ladder, 7).readCount, 1);
    expect(projectReadReceipt(ladder, 12).readCount, 0);
    expect(projectAgentReadReceipt(ladder, 'a1', 6), isNull);
    expect(projectReadReceipt(null, 5).peerCount, 0);
    expect(projectReadReceipt(peers, null).read, isFalse);
  });

  test('[BP-READ-061] live peer frames merge a max, wait for hydration, and a summary frame re-reads the detail', () async {
    final c = _Client();
    final w = WorkspaceController(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.bootstrap();
    final receipts = w.readReceipts;
    // Before hydration a frame is ignored.
    c.stream.add(
      RaftEvent('scope_read:updated', {
        'scopeId': 'c1',
        ..._peer('human', 'bob', 4),
      }),
    );
    expect(receipts.scope('c1'), isNull);
    c.details['c1'] = {
      'peerReadStates': [_peer('human', 'bob', 2)],
    };
    await receipts.hydrate('c1');
    expect(receipts.project('c1', 3).read, isFalse);
    c.stream.add(
      RaftEvent('scope_read:updated', {
        'scopeId': 'c1',
        ..._peer('human', 'bob', 4),
      }),
    );
    expect(receipts.project('c1', 3).read, isTrue);
    // A lower frame never moves a frontier back.
    c.stream.add(
      RaftEvent('scope_read:updated', {
        'scopeId': 'c1',
        ..._peer('human', 'bob', 1),
      }),
    );
    expect(receipts.project('c1', 3).read, isTrue);
    // A hydrate older than the live frame keeps the higher frontier.
    await receipts.hydrate('c1');
    expect(receipts.project('c1', 3).read, isTrue);
    // A scope the server stops describing is disabled.
    c.details['c1'] = {'id': 'c1'};
    await receipts.hydrate('c1');
    expect(receipts.scope('c1'), isNull);
    // Summary scopes re-hydrate on summaryChanged.
    c.details['c2'] = {
      'peerReadSummary': {'peerCount': 5, 'readCountAtSeq': []},
    };
    await receipts.hydrate('c2');
    final reads = c.detailReads;
    c.stream.add(
      const RaftEvent('scope_read:updated', {
        'scopeId': 'c2',
        'summaryChanged': true,
      }),
    );
    await _settle();
    expect(c.detailReads, reads + 1);
  });
}
