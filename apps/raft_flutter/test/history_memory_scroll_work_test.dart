import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_memory.dart';

void main() {
  testWidgets(
    'scroll position samples do not request global body maintenance',
    (tester) async {
      final changes = ValueNotifier(0);
      var captures = 0, samples = 0;
      final pool = HistoryMemoryPool((scope, versions) async => []);
      addTearDown(() {
        pool.close();
        changes.dispose();
      });
      pool.register(
        changes,
        HistoryMemoryPort(
          changes: changes,
          stamp: () => changes.value,
          capture: () async {
            captures++;
            return [];
          },
        ),
      );
      await pool.maintain();
      expect(captures, 1);
      for (var n = 0; n < 20; n++) {
        pool.samplePosition(changes, () => samples++);
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(samples, 20);
      expect(captures, 1, reason: 'Scrolling changes no body or memory budget');
      changes.value++;
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        captures,
        2,
        reason: 'Real data changes must still maintain the budget',
      );
    },
  );
}
