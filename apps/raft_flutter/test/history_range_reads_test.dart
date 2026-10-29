import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_gaps.dart';
import 'package:raft_flutter/data/history_range_reads.dart';

void main() {
  test(
    'wire completion is shared until acceptance, then only metadata is reused',
    () async {
      // Initial: HTTP has returned but admission is held. Event: a second
      // consumer asks for the page. Expected: both await the same acceptance.
      final owner = HistoryRangeReads(), gate = Completer<HistoryRangeProof?>();
      final range = owner.scope('connection', 'conversation');
      var calls = 0, accepted = false;
      Future<HistoryRangeProof?> read() => range.read(BigInt.from(201), () {
        calls++;
        return gate.future;
      });
      final first = read().then((proof) {
        accepted = true;
        return proof;
      });
      final second = read();
      await Future<void>.value();
      expect(calls, 1);
      expect(accepted, isFalse);
      gate.complete(
        HistoryRangeProof(BigInt.from(151), BigInt.from(200), firstId: 'm151'),
      );
      expect(await first, same(await second));
      expect(await read(), isNotNull);
      expect(calls, 1);
    },
  );

  test(
    'sequential accepted intervals merge and advance the oldest boundary',
    () async {
      // Initial: 1000 sequential pages. Event: the other consumer reaches the
      // first boundary. Expected: it advances across merged metadata at once.
      final range = HistoryRangeReads().scope('connection', 'conversation');
      for (var before = 50001; before > 1; before -= 50) {
        await range.read(
          BigInt.from(before),
          () async => HistoryRangeProof(
            BigInt.from(before - 50),
            BigInt.from(before - 1),
            firstId: 'm${before - 50}',
          ),
        );
      }
      var reread = false;
      final proof = await range.read(BigInt.from(50001), () async {
        reread = true;
        return null;
      });
      expect(proof!.lower, BigInt.one);
      expect(reread, isFalse);
      expect(
        range.remaining([
          HistoryGap('m50001', BigInt.from(50001), older: BigInt.zero),
        ]),
        isEmpty,
      );
    },
  );

  test(
    'failed or retired acceptance cannot cover the next connection',
    () async {
      final owner = HistoryRangeReads(), gate = Completer<HistoryRangeProof?>();
      final old = owner.scope('connection', 'conversation');
      final pending = old.read(BigInt.from(201), () => gate.future);
      owner.restart();
      final next = owner.scope('connection', 'conversation');
      expect(old.current, isFalse);
      expect(next.token, isNot(old.token));
      var calls = 0;
      Future<HistoryRangeProof?> failed() =>
          next.read(BigInt.from(201), () async {
            calls++;
            return null;
          });
      expect(await failed(), isNull);
      expect(await failed(), isNull);
      expect(calls, 2);
      gate.complete(HistoryRangeProof(BigInt.from(151), BigInt.from(200)));
      expect(await pending, isNull);
      expect(await failed(), isNull);
      expect(calls, 3);
    },
  );

  test(
    'window or destructive-storage changes retire transient coverage',
    () async {
      final owner = HistoryRangeReads();
      final old = owner.scope(('window', 0), 'conversation');
      await old.read(
        BigInt.from(201),
        () async => HistoryRangeProof(BigInt.from(151), BigInt.from(200)),
      );
      final next = owner.scope(('window', 1), 'conversation');
      expect(old.current, isFalse);
      var calls = 0;
      await next.read(BigInt.from(201), () async {
        calls++;
        return null;
      });
      expect(calls, 1);
    },
  );
}
