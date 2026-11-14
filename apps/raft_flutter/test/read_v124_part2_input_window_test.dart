// Source: packages/web/src/store/messageStore.ts:881-890 and
// packages/shared/src/notifications.ts:383 (ACTIVE_INPUT_WINDOW_MS) at
// v1.24.0-source.1
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/user_activity.dart';

void main() {
  tearDown(() {
    RaftUserActivity.clock = DateTime.now;
    RaftUserActivity.forget();
  });

  test('[BP-READ-015] input within 3 minutes counts as the person using the window', () {
    var now = DateTime.utc(2026, 11, 15, 9);
    RaftUserActivity.clock = () => now;
    RaftUserActivity.mark();
    expect(RaftUserActivity.window, const Duration(minutes: 3));
    now = now.add(const Duration(minutes: 2, seconds: 59));
    expect(RaftUserActivity.recent, isTrue);
    now = now.add(const Duration(seconds: 2));
    expect(RaftUserActivity.recent, isFalse);
  });
}
