import 'package:test/test.dart';
import 'package:raft_sync/raft_sync.dart';

Map<String, dynamic> row(
  String id,
  String seq, {
  String channel = 'general',
  String content = 'hello',
}) => {'id': id, 'channelId': channel, 'seq': seq, 'content': content};
void main() {
  test(
    'sparse receiver sequences deduplicate and retain exact uint64 order',
    () {
      final l = MessageLedger()..switchServer('a');
      l.ingest([
        row('b', '9007199254740993'),
        row('a', '9007199254740992'),
        row('c', '9007199254741000'),
      ], expectedGeneration: l.generation);
      l.ingest([
        row('b', '9007199254740993', content: 'updated'),
      ], expectedGeneration: l.generation);
      expect(l.messages('general').map((m) => m['id']), ['a', 'b', 'c']);
      expect(l.messages('general')[1]['content'], 'updated');
      expect(l.watermark, BigInt.parse('9007199254741000'));
    },
  );
  test(
    'server switch rejects stale ingress and removes former private cache',
    () {
      final l = MessageLedger()..switchServer('a');
      final old = l.generation;
      l.ingest([
        row('secret', '2', channel: 'private'),
      ], expectedGeneration: old);
      l.switchServer('b');
      expect(l.messages('private'), isEmpty);
      expect(
        l.ingest([
          row('secret', '3', channel: 'private'),
        ], expectedGeneration: old),
        false,
      );
      expect(l.watermark, BigInt.zero);
    },
  );
  test(
    'revoke discards a channel without deleting unrelated conversations',
    () {
      final l = MessageLedger()..switchServer('a');
      l.ingest([
        row('a', '1', channel: 'private'),
        row('b', '7'),
      ], expectedGeneration: l.generation);
      l.revokeChannel('private');
      expect(l.messages('private'), isEmpty);
      expect(l.messages('general'), hasLength(1));
    },
  );
}
