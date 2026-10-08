import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

Map<String, dynamic> row(String id, dynamic seq, {String channel = 'c1'}) => {
  'id': id,
  'channelId': channel,
  'seq': seq,
  'content': 'loaded text',
  'senderName': 'Alice',
  'commentRef': {'id': 'comment'},
};
void main() {
  test('mounted sparse message core accepts jumps and drops duplicate or regressed channel facts', () {
    final sync = MessageSync();
    expect(sync.consumeNew(row('a', 2))?['id'], 'a');
    expect(sync.consumeNew(row('b', 99))?['id'], 'b');
    expect(sync.consumeNew(row('b', 99)), isNull);
    expect(sync.consumeNew(row('late', 10)), isNull);
    expect(sync.consumeNew(row('other', 1, channel: 'c2'))?['id'], 'other');
    expect(sync.core.pendingRequests(), isEmpty);
  });
  test('missing sequences use legacy ingress and large uint64 strings remain exact', () {
    final sync = MessageSync();
    expect(sync.consumeNew(row('legacy', null))?['id'], 'legacy');
    expect(sync.consumeNew(row('a', '9007199254740993'))?['id'], 'a');
    expect(sync.consumeNew(row('b', '9007199254740992')), isNull);
    expect(
      sync.core.scopeSyncState('messages', 'c1')?['appliedSeq'],
      '9007199254740993',
    );
  });
  test('revocation discards private folded projections and does not affect another channel', () {
    final sync = MessageSync();
    sync.consumeNew(row('secret', 10));
    sync.consumeNew(row('public', 30, channel: 'c2'));
    sync.revokeChannel('c1');
    expect(sync.core.state('messages', 'c1'), isNull);
    expect(sync.core.state('messages', 'c2'), isNotNull);
    sync.reset();
    expect(sync.core.state('messages', 'c2'), isNull);
  });
  test('socket task updates merge loaded fields and preserve shared-null comment references', () {
    final ledger = MessageLedger()..switchServer('s1');
    final generation = ledger.generation;
    ledger.ingest([row('a', 2)], expectedGeneration: generation);
    expect(
      ledger.ingestUpdate({
        'id': 'a',
        'channelId': 'c1',
        'taskStatus': 'done',
        'commentRef': null,
      }, expectedGeneration: generation),
      true,
    );
    final actual = ledger.messages('c1').single;
    expect(actual['content'], 'loaded text');
    expect(actual['senderName'], 'Alice');
    expect(actual['seq'], 2);
    expect(actual['commentRef'], {'id': 'comment'});
    expect(actual['taskStatus'], 'done');
    expect(
      ledger.ingestUpdate({
        'id': 'unknown',
        'channelId': 'c1',
        'taskStatus': 'done',
      }, expectedGeneration: generation),
      false,
    );
    expect(ledger.messages('c1'), hasLength(1));
    ledger.switchServer('s2');
    expect(
      ledger.ingestUpdate({
        'id': 'a',
        'channelId': 'c1',
      }, expectedGeneration: generation),
      false,
    );
  });
}
