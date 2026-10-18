import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/device_timezone.dart';

void main() {
  testWidgets(
    'the shared bootstrap resolves native timezone without advancing time',
    (tester) async {
      var completed = false;
      String? timezone;
      final pending = readDeviceTimezone().then((value) {
        timezone = value;
        completed = true;
      });
      try {
        await tester.pump();
        expect(
          completed,
          isTrue,
          reason: 'Widget tests must not wait on a real platform channel.',
        );
        expect(
          timezone,
          isNull,
          reason: 'The shared fixture has no device timezone.',
        );
      } finally {
        // Retain a clean failure when the shared native fixture is missing.
        if (!completed) await tester.pump(const Duration(milliseconds: 501));
        await pending;
      }
    },
  );
}
