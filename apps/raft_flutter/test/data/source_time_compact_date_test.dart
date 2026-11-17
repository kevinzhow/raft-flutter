// Web utils/timeFormatting.ts formatCompactDate, the Files card row's time:
// the clock today, "Nov 3" earlier this year, the calendar day before that,
// all in the preferred time zone.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';

void main() {
  final formatter = SourceTimeFormatter(
    preferredTimezone: 'Asia/Shanghai',
    hostTimezone: 'UTC',
    preferredTimeFormat: SourceTimeFormat.twentyFourHour,
  );
  final now = DateTime.parse('2026-11-17T12:00:00Z'); // 20:00 in Shanghai

  test('today: the clock', () {
    expect(formatter.compactDate('2026-11-17T02:30:00Z', now: now), '10:30');
  });

  test('today in the preferred zone, not in UTC', () {
    // 2026-11-16 17:00 UTC is already the 17th, 01:00, in Shanghai.
    expect(formatter.compactDate('2026-11-16T17:00:00Z', now: now), '01:00');
  });

  test('earlier this year: month and day', () {
    expect(formatter.compactDate('2026-11-03T02:30:00Z', now: now), 'Nov 3');
  });

  test('an earlier year: the calendar day', () {
    expect(
      formatter.compactDate('2025-12-30T02:30:00Z', now: now),
      '2025-12-30',
    );
  });

  test('not a date: as given', () {
    expect(formatter.compactDate('soon', now: now), 'soon');
  });
}
