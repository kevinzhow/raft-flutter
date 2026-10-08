import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:raft_flutter/data/source_time_formatter.dart';

void main() {
  setUpAll(initializeSourceTimeFormatting);

  final receipt = jsonDecode(
    File('test/data/source_time_golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final raw in receipt['cases'] as List) {
    final row = Map<String, dynamic>.from(raw as Map);
    test('original source ${row['id']} ${row['host']} '
        '${row['locale']} ${row['format']}', () {
      final zh = row['locale'] == 'zh-CN';
      final formatter = SourceTimeFormatter(
        locale: row['locale'] as String,
        preferredTimezone: row['zone'] as String?,
        hostTimezone: row['host'] as String,
        preferredTimeFormat: sourceTimeFormatPreference(
          row['format'] as String?,
        ),
        todayLabel: zh ? '今天' : 'Today',
        yesterdayLabel: zh ? '昨天' : 'Yesterday',
      );
      final value = row['value'] as String;
      final now = DateTime.parse(row['now'] as String);
      expect(formatter.clock(value), row['clock']);
      expect(formatter.clock(value, force24: true), row['clock24']);
      expect(formatter.clock(value, seconds: true), row['seconds']);
      expect(formatter.messageTime(value, now: now), row['messageTime']);
      expect(formatter.dayLabel(value, now: now), row['dayLabel']);
    });
  }

  test('public Shanghai instant is 10:30 rather than the host UTC 02:30', () {
    final formatter = SourceTimeFormatter(
      preferredTimezone: 'Asia/Shanghai',
      hostTimezone: 'UTC',
      preferredTimeFormat: SourceTimeFormat.twentyFourHour,
    );
    expect(formatter.clock(DateTime.parse('2026-10-08T02:30:00Z')), '10:30');
  });

  test('IANA conversion skips the nonexistent New York spring hour', () {
    final formatter = SourceTimeFormatter(
      preferredTimezone: 'America/New_York',
    );
    final before = formatter.wallTime(DateTime.parse('2026-03-08T06:59:00Z'));
    final after = formatter.wallTime(DateTime.parse('2026-03-08T07:00:00Z'));
    expect(before.hour, 1);
    expect(before.timeZoneOffset, const Duration(hours: -5));
    expect(after.hour, 3);
    expect(after.timeZoneOffset, const Duration(hours: -4));
    expect(formatter.dayKey(before), formatter.dayKey(after));
  });

  test(
    'repeated fall hour retains two distinct real instants and DST offsets',
    () {
      final formatter = SourceTimeFormatter(
        preferredTimezone: 'America/New_York',
      );
      final first = formatter.wallTime(DateTime.parse('2026-11-01T05:30:00Z'));
      final second = formatter.wallTime(DateTime.parse('2026-11-01T06:30:00Z'));
      expect(first.hour, 1);
      expect(second.hour, 1);
      expect(first.timeZoneOffset, const Duration(hours: -4));
      expect(second.timeZoneOffset, const Duration(hours: -5));
      expect(second.difference(first), const Duration(hours: 1));
    },
  );

  test(
    'non-hour IANA zone and offset-bearing inputs project the same instant',
    () {
      final formatter = SourceTimeFormatter(
        preferredTimezone: 'Asia/Kolkata',
        preferredTimeFormat: SourceTimeFormat.twentyFourHour,
      );
      expect(formatter.clock('2026-10-08T02:30:00Z'), '08:00');
      expect(formatter.clock('2026-10-08T10:30:00+08:00'), '08:00');
    },
  );

  test(
    'preferred-zone boundary drives day grouping rather than device date',
    () {
      final formatter = SourceTimeFormatter(
        preferredTimezone: 'Asia/Shanghai',
        hostTimezone: 'UTC',
      );
      expect(
        formatter.dayKey(DateTime.parse('2026-10-07T15:59:00Z')),
        '2026-10-07',
      );
      expect(
        formatter.dayKey(DateTime.parse('2026-10-07T16:00:00Z')),
        '2026-10-08',
      );
    },
  );

  test('blank/null preference falls back to genuine host IANA zone', () {
    for (final zone in [null, '', '   ']) {
      final formatter = SourceTimeFormatter(
        preferredTimezone: zone,
        hostTimezone: 'America/New_York',
        preferredTimeFormat: SourceTimeFormat.twentyFourHour,
      );
      expect(formatter.clock('2026-10-08T02:30:00Z'), '22:30');
      expect(
        formatter.dayKey(DateTime.parse('2026-10-08T02:30:00Z')),
        '2026-10-07',
      );
    }
  });

  test('no host identity uses actual OS local, never timezone global UTC', () {
    final instant = DateTime.parse('2026-10-08T02:30:00Z');
    final formatter = SourceTimeFormatter();
    expect(formatter.wallTime(instant), instant.toLocal());
    final zonedInput = tz.TZDateTime.from(
      instant,
      tz.getLocation('Asia/Kolkata'),
    );
    expect(
      formatter.wallTime(zonedInput).timeZoneOffset,
      instant.toLocal().timeZoneOffset,
    );
    expect(
      formatter.wallTime(instant).timeZoneOffset,
      instant.toLocal().timeZoneOffset,
    );
  });

  test('shipped locale defaults and distinct host clock preference', () {
    final stamp = DateTime.parse('2026-10-08T02:30:00Z');
    expect(
      SourceTimeFormatter(
        locale: 'en-US',
        preferredTimezone: 'UTC',
      ).clock(stamp),
      '02:30 AM',
    );
    expect(
      SourceTimeFormatter(
        locale: 'zh-CN',
        preferredTimezone: 'UTC',
      ).clock(stamp),
      '02:30',
    );
    expect(
      SourceTimeFormatter(
        locale: 'zh-CN',
        preferredTimezone: 'UTC',
        systemTimeFormat: SourceTimeFormat.twelveHour,
      ).clock(stamp),
      '上午02:30',
    );
    expect(
      SourceTimeFormatter(
        locale: 'en-US',
        preferredTimezone: 'UTC',
        systemTimeFormat: SourceTimeFormat.twelveHour,
        preferredTimeFormat: SourceTimeFormat.twentyFourHour,
      ).clock(stamp),
      '02:30',
    );
  });

  test('12h midnight/noon and fixed 24h override do not invent 24:00', () {
    final formatter = SourceTimeFormatter(
      preferredTimezone: 'UTC',
      preferredTimeFormat: SourceTimeFormat.twelveHour,
    );
    expect(formatter.clock('2026-10-08T00:05:00Z'), '12:05 AM');
    expect(formatter.clock('2026-10-08T12:05:00Z'), '12:05 PM');
    expect(formatter.clock('2026-10-08T00:05:00Z', force24: true), '00:05');
  });

  test(
    'null and invalid date behavior matches the separate source surfaces',
    () {
      final formatter = SourceTimeFormatter();
      expect(formatter.clock(null), '');
      expect(formatter.clock('invalid'), 'invalid');
      expect(formatter.messageTime('invalid'), 'invalid');
      expect(formatter.dayLabel('invalid'), '');
      expect(formatter.clock(double.nan), 'NaN');
    },
  );

  test('ISO date-only is a UTC instant as in ECMAScript', () {
    final formatter = SourceTimeFormatter(
      preferredTimezone: 'Asia/Shanghai',
      hostTimezone: 'America/New_York',
      preferredTimeFormat: SourceTimeFormat.twentyFourHour,
    );
    expect(formatter.clock('2026-10-08'), '08:00');
    expect(
      formatter.clock('2026-10-08'),
      formatter.clock('2026-10-08T00:00:00Z'),
    );
  });

  test('numeric timestamp is epoch milliseconds, not Unix seconds', () {
    final stamp = DateTime.parse('2026-10-08T02:30:00Z');
    final formatter = SourceTimeFormatter(
      preferredTimezone: 'Asia/Shanghai',
      preferredTimeFormat: SourceTimeFormat.twentyFourHour,
    );
    expect(formatter.clock(stamp.millisecondsSinceEpoch), '10:30');
  });

  test(
    'unknown preferred zone fails explicitly instead of silently wrong time',
    () {
      expect(
        () => SourceTimeFormatter(preferredTimezone: 'Not/AZone'),
        throwsA(isA<tz.LocationNotFoundException>()),
      );
    },
  );
}
