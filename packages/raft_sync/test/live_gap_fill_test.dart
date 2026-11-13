import 'dart:async';

import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

class _Clock {
  final scheduled = <(Duration, void Function())>[];
  Timer timer(Duration delay, void Function() callback) {
    scheduled.add((delay, callback));
    return Timer(const Duration(days: 1), () {});
  }

  void runNext() => scheduled.removeAt(0).$2();
}

BigInt b(int v) => BigInt.from(v);

void main() {
  test('a remembered row schedules one fill per channel at once', () {
    final clock = _Clock();
    final fill = LiveGapFill(timer: clock.timer);
    final reads = <String>[];
    fill.reader = reads.add;
    fill.remember('c', 'm2', b(10));
    fill.remember('c', 'm3', b(12));
    fill.remember('c', 'm3', b(12));
    expect(clock.scheduled.map((e) => e.$1), [Duration.zero]);
    expect(fill.owedSince('c'), b(10));
    clock.runNext();
    expect(reads, ['c']);
  });

  test('a read settles the rows that arrived before it started', () {
    final clock = _Clock();
    final fill = LiveGapFill(timer: clock.timer);
    fill.remember('c', 'm2', b(10));
    clock.runNext();
    final read = fill.start('c');
    fill.remember('c', 'm3', b(12));
    expect(fill.settle('c', b(10), read, {}), 1, reason: 'm3 came later');
    fill.finish('c', read, GapReadOutcome.read, (_) {});
    expect(fill.owes('c'), isTrue);
    expect(clock.scheduled, hasLength(1), reason: 'm3 gets its own read');
  });

  test(
    'a read asked for while one runs reruns after it from the lowest seq',
    () {
      final fill = LiveGapFill(timer: _Clock().timer);
      final read = fill.start('c');
      expect(fill.joinInFlight('c', b(20)), isTrue);
      expect(fill.joinInFlight('c', b(15)), isTrue);
      final reruns = <BigInt>[];
      fill.finish('c', read, GapReadOutcome.read, reruns.add);
      expect(reruns, [b(15)]);
      expect(fill.joinInFlight('c', b(1)), isFalse);
    },
  );

  test('failed fills retry after 1, 2, 4, 8, 16 s, then leave it to the '
      'heartbeat', () {
    final clock = _Clock();
    final fill = LiveGapFill(timer: clock.timer);
    fill.remember('c', 'm2', b(10));
    clock.runNext();
    final delays = <Duration>[];
    for (var i = 0; i < 6; i++) {
      final read = fill.start('c');
      fill.finish('c', read, GapReadOutcome.failed, (_) {});
      if (clock.scheduled.isNotEmpty) {
        delays.add(clock.scheduled.single.$1);
        clock.runNext();
      }
    }
    expect(delays, [
      for (final s in [1, 2, 4, 8, 16]) Duration(seconds: s),
    ]);
    expect(fill.owes('c'), isTrue);
  });

  test('a reset drops every hole and a read started before it', () {
    final clock = _Clock();
    final fill = LiveGapFill(timer: clock.timer);
    fill.remember('c', 'm2', b(10));
    final read = fill.start('c');
    fill.clear();
    fill.remember('c', 'm9', b(90));
    final reruns = <BigInt>[];
    read.rerunSince = b(1);
    expect(fill.settle('c', b(10), read, {}), 0);
    fill.finish('c', read, GapReadOutcome.failed, reruns.add);
    expect(reruns, isEmpty);
    expect(fill.owedSince('c'), b(90));
  });
}
