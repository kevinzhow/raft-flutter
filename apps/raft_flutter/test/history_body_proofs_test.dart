import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_body_proofs.dart';
import 'package:raft_flutter/data/workspace_cache_codec.dart';

void main() {
  test(
    'unchanged bodies reuse proof while new copies and edits are inspected',
    () async {
      final batches = <List<String>>[];
      final proof = HistoryBodyProofs(
        inspect: (versions, stored) {
          batches.add(versions.keys.toList());
          return inspectHistoryBodies(versions, stored);
        },
      );
      final first = {'id': 'a', 'content': '中文 first'},
          second = {'id': 'b', 'content': 'second'};
      final versions = <String, List<Map<String, dynamic>>>{
        'a': [first],
        'b': [second],
      };
      final stored = {
        'a': await encodeWorkspaceCache(first),
        'b': await encodeWorkspaceCache(second),
      };
      final initial = await proof(versions, stored);
      for (var n = 0; n < 10; n++) {
        expect(await proof(versions, stored), initial);
      }
      expect(batches, [
        ['a', 'b'],
      ], reason: 'No repeated JSON worker for held bodies');
      versions['a'] = [first, Map.of(first)];
      final duplicate = await proof(versions, stored);
      expect(batches.last, ['a']);
      expect(duplicate.first.bytes, initial.first.bytes * 2);
      versions['a'] = [
        {...first, 'content': 'unsaved edit'},
        first,
      ];
      final edited = await proof(versions, stored);
      expect(batches.last, ['a']);
      expect(edited.first.durable, isFalse);
      expect(edited.last, initial.last);
    },
  );

  test(
    'durability follows fresh disk payloads including deletion and replacement',
    () async {
      final proof = HistoryBodyProofs();
      final row = {'id': 'a', 'content': 'latest'};
      final versions = <String, List<Map<String, dynamic>>>{
        'a': [row],
      };
      final saved = await encodeWorkspaceCache(row);
      expect((await proof(versions, {'a': saved})).single.durable, isTrue);
      expect((await proof(versions, {})).single.durable, isFalse);
      expect(
        (await proof(versions, {
          'a': '{"id":"a","content":"older"}',
        })).single.durable,
        isFalse,
      );
      expect((await proof(versions, {'a': saved})).single.durable, isTrue);
    },
  );

  test(
    'an edit during worker inspection cannot inherit an older durable proof',
    () async {
      final entered = Completer<void>(), finish = Completer<void>();
      var firstJob = true;
      final proof = HistoryBodyProofs(
        inspect: (versions, stored) async {
          if (firstJob) {
            firstJob = false;
            entered.complete();
            await finish.future;
          }
          return inspectHistoryBodies(versions, stored);
        },
      );
      final row = {'id': 'a', 'content': 'saved'};
      final versions = <String, List<Map<String, dynamic>>>{
        'a': [row],
      };
      final saved = {'a': await encodeWorkspaceCache(row)};
      final pending = proof(versions, saved);
      await entered.future;
      versions['a'] = [
        {...row, 'content': 'new unsaved content'},
      ];
      finish.complete();
      expect((await pending).single.durable, isTrue);
      expect((await proof(versions, saved)).single.durable, isFalse);
    },
  );
}
