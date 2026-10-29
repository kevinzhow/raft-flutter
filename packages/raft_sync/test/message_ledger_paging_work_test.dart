import 'dart:math';

import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

class Sequence {
  Sequence(this.value);
  final int value;
  int reads = 0;
  @override
  String toString() {
    reads++;
    return '$value';
  }
}

void main() {
  test('a history page reuses retained sequence ordering work', () {
    final ledger = MessageLedger()..switchServer('s');
    final seqs = [for (var i = 100; i < 1100; i++) Sequence(i)];
    ledger.ingest([
      for (final seq in seqs)
        {'id': '${seq.value}', 'channelId': 'c', 'seq': seq},
    ], expectedGeneration: ledger.generation);
    ledger.messages('c');
    for (final seq in seqs) {
      seq.reads = 0;
    }
    ledger.ingest([
      for (var i = 50; i < 100; i++)
        {'id': '$i', 'channelId': 'c', 'seq': '$i'},
    ], expectedGeneration: ledger.generation);
    final rows = ledger.messages('c');
    expect(rows.map((r) => r['id']), [for (var i = 50; i < 1100; i++) '$i']);
    expect(
      seqs.fold<int>(0, (n, s) => n + s.reads),
      0,
      reason: 'Paging must not parse every retained sequence again',
    );
  });
  test('incremental ordering matches a fresh sort after edits, removals and release', () {
    final ledger = MessageLedger()..switchServer('s');
    final expected = <String, Map<String, dynamic>>{};
    final random = Random(507);
    for (var step = 0; step < 200; step++) {
      final id = '${random.nextInt(80)}';
      if (step % 5 == 0) {
        ledger.remove('c', id);
        expected.remove(id);
      } else {
        final row = {
          'id': id,
          'channelId': 'c',
          'seq':
              '${BigInt.parse('9007199254740993') + BigInt.from(random.nextInt(90))}',
          'content': '$step',
        };
        ledger.ingest([row], expectedGeneration: ledger.generation);
        expected[id] = row;
      }
      if (step % 13 == 0) {
        ledger.releaseBodies('c', {id});
        expected.remove(id);
      }
      final sorted = expected.values.toList()
        ..sort((a, b) {
          final c = BigInt.parse(a['seq'] as String)
              .compareTo(BigInt.parse(b['seq'] as String));
          return c == 0 ? (a['id'] as String).compareTo(b['id'] as String) : c;
        });
      final actual = ledger.messages('c');
      expect(actual, sorted, reason: 'step $step');
      actual.clear();
      expect(
        ledger.messages('c'),
        sorted,
        reason: 'caller does not own the cached order',
      );
    }
    ledger.revokeChannel('c');
    expect(ledger.messages('c'), isEmpty);
  });
}
