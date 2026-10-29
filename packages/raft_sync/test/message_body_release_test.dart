import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

void main() {
  test('authoritative body replacement removes fields without changing sync progress or inventing rows', () {
    final sync = MessageSync();
    sync.consumeNew({
      'id': 'a',
      'channelId': 'chat',
      'seq': '10',
      'content': 'old',
      'attachments': [
        {'id': 'gone'},
      ],
    });
    final progress = Map.of(sync.core.scopeSyncState('messages', 'chat')!);
    sync.replaceBodies('chat', [
      {'id': 'a', 'channelId': 'chat', 'seq': '10', 'content': 'fresh'},
      {'id': 'missing', 'channelId': 'chat', 'seq': '11', 'content': 'unheld'},
      {'id': 'a', 'channelId': 'other', 'seq': '12', 'content': 'wrong scope'},
    ]);
    sync.replaceBodies('unseen', [
      {'id': 'new', 'channelId': 'unseen', 'seq': '20'},
    ]);
    expect(sync.messages('chat').single, {
      'id': 'a',
      'channelId': 'chat',
      'seq': '10',
      'content': 'fresh',
    });
    expect(sync.channelIds, ['chat']);
    expect(sync.core.scopeSyncState('messages', 'chat'), progress);
    expect(
      sync.consumeNew({'id': 'a', 'channelId': 'chat', 'seq': '10'}),
      isNull,
    );
    final ledger = MessageLedger()..switchServer('server');
    ledger.ingest([
      {
        'id': 'a',
        'channelId': 'chat',
        'seq': '10',
        'attachments': [1],
      },
    ], expectedGeneration: ledger.generation);
    ledger.ingest(
      [
        {'id': 'a', 'channelId': 'chat', 'seq': '10', 'content': 'fresh'},
      ],
      expectedGeneration: ledger.generation,
      complete: true,
    );
    expect(ledger.message('chat', 'a')!.containsKey('attachments'), isFalse);
    expect(ledger.watermark, BigInt.from(10));
  });

  test(
    'releasing bodies preserves sequence and activity through later messages',
    () {
      final ledger = MessageLedger()..switchServer('server');
      ledger.ingest([
        {
          'id': 'a',
          'channelId': 'chat',
          'seq': '10',
          'content': 'earlier',
          'createdAt': '2026-10-01T00:00:00Z',
        },
        {
          'id': 'b',
          'channelId': 'chat',
          'seq': '20',
          'content': 'latest',
          'createdAt': '2026-10-03T00:00:00Z',
        },
      ], expectedGeneration: ledger.generation);
      final generation = ledger.generation;
      ledger.releaseBodies('chat', {'a', 'b'});
      expect(ledger.messages('chat'), isEmpty);
      expect(ledger.watermark, BigInt.from(20));
      expect(ledger.generation, generation);
      expect(ledger.latestCreatedAt('chat'), DateTime.utc(2026, 10, 3));
      ledger.ingest([
        {
          'id': 'c',
          'channelId': 'chat',
          'seq': '30',
          'createdAt': '2026-10-02T00:00:00Z',
        },
      ], expectedGeneration: generation);
      expect(ledger.latestCreatedAt('chat'), DateTime.utc(2026, 10, 3));
      ledger.revokeChannel('chat');
      expect(ledger.latestCreatedAt('chat'), isNull);
      ledger.switchServer('other');
      expect(ledger.watermark, BigInt.zero);
    },
  );

  test('releasing a sync projection cannot reset replay deduplication or its epoch', () {
    final sync = MessageSync();
    Map<String, dynamic> row(int seq) => {
      'id': 'm$seq',
      'channelId': 'chat',
      'seq': '$seq',
      'content': 'body$seq',
    };
    sync.consumeNew(row(10));
    sync.consumeNew(row(20));
    final before = Map.of(sync.core.scopeSyncState('messages', 'chat')!);
    sync.releaseBodies('chat', {'m10', 'm20'});
    expect(sync.messages('chat'), isEmpty);
    expect(sync.core.scopeSyncState('messages', 'chat'), before);
    expect(sync.consumeNew(row(20)), isNull);
    expect(sync.consumeNew(row(25))?['id'], 'm25');
    expect(sync.messages('chat').single['id'], 'm25');
  });
}
