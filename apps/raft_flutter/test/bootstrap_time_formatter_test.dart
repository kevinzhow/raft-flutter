import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';

void main() {
  test(
    'shared formatting remains awaitable after a widget clock retires',
    () async {
      final previousClock = FakeAsync();
      final initialization = previousClock.run(
        (_) => initializeSourceTimeFormatting(),
      );
      previousClock.flushMicrotasks();

      var completed = false;
      initialization.then((_) => completed = true);
      // Let the real-zone continuation run without advancing the retired clock.
      await Future<void>.value();
      try {
        expect(
          completed,
          isTrue,
          reason: 'Real asynchronous work must not depend on a previous widget clock.',
        );
      } finally {
        previousClock.flushMicrotasks();
      }
    },
  );
}
