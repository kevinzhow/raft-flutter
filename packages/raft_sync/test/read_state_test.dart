import 'package:test/test.dart';
import 'package:raft_sync/raft_sync.dart';

void main() {
  Map<String, dynamic> fact(int seq, int version) => {
    'serverId': 'server',
    'scopeId': 'channel',
    'maxReadSeq': seq,
    'readStateVersion': version,
  };
  test('late HTTP absent cannot clear a newer socket frontier', () {
    final l = ReadStateLedger();
    final generation = l.generation;
    l.consumeUpdate(fact(10, 2), serverId: 'server', principalId: 'me');
    expect(
      l.consumeSnapshot(
        {'kind': 'absent'},
        serverId: 'server',
        principalId: 'me',
        scopeId: 'channel',
        generationAtRequest: generation,
      ),
      'stale',
    );
    expect(l.state('server', 'me', 'channel')!['maxReadSeq'], 10);
  });
  test('lagging projection absence cannot erase an acknowledged frontier even for a later request', () {
    final l = ReadStateLedger();
    l.consumeUpdate(fact(10, 2), serverId: 'server', principalId: 'me');
    expect(
      l.consumeSnapshot(
        {'kind': 'absent'},
        serverId: 'server',
        principalId: 'me',
        scopeId: 'channel',
        generationAtRequest: l.generation,
        authoritativeAbsence: false,
      ),
      'stale',
    );
    expect(l.state('server', 'me', 'channel')!['maxReadSeq'], 10);
    expect(
      l.consumeSnapshot(
        {'kind': 'absent'},
        serverId: 'server',
        principalId: 'me',
        scopeId: 'channel',
        generationAtRequest: l.generation,
      ),
      'cleared',
    );
    expect(l.state('server', 'me', 'channel'), isNull);
  });
  test('mark unread permits lower read seq at a newer version', () {
    final l = ReadStateLedger();
    l.consumeUpdate(fact(10, 2), serverId: 'server', principalId: 'me');
    expect(
      l.consumeUpdate(fact(0, 3), serverId: 'server', principalId: 'me'),
      'accepted',
    );
    expect(l.state('server', 'me', 'channel')!['maxReadSeq'], 0);
    expect(
      l.consumeUpdate(fact(20, 2), serverId: 'server', principalId: 'me'),
      'stale',
    );
  });
  test(
    'bad entries cannot contaminate another receiver or exact uint64 parser',
    () {
      final l = ReadStateLedger();
      l.consumeUpdate(fact(10, 2), serverId: 'server', principalId: 'me');
      expect(
        l.consumeUpdate(
          {...fact(1, 3), 'serverId': 'other'},
          serverId: 'server',
          principalId: 'me',
        ),
        'corrupt',
      );
      expect(
        l.consumeSnapshot(
          {
            'kind': 'present',
            'maxReadSeq': '9007199254740993',
            'readStateVersion': 3,
          },
          serverId: 'server',
          principalId: 'me',
          scopeId: 'channel',
          generationAtRequest: l.generation,
        ),
        'corrupt',
      );
      expect(l.state('server', 'me', 'channel')!['maxReadSeq'], 10);
      expect(
        canonicalUint64('18446744073709551615'),
        BigInt.parse('18446744073709551615'),
      );
      expect(canonicalUint64('18446744073709551616'), isNull);
      expect(canonicalUint64('01'), isNull);
    },
  );
}
