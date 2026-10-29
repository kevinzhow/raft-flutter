import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';

void main() {
  test('formatMediumDateTime follows the preferred zone, locale and hour cycle', () async {
    await initializeSourceTimeFormatting();
    const instant = '2026-06-10T09:05:00Z';
    SourceTimeFormatter f(String locale, SourceTimeFormat format, [String zone = 'UTC']) =>
        SourceTimeFormatter(
          locale: locale,
          preferredTimezone: zone,
          preferredTimeFormat: format,
        );
    expect(
      f('en', SourceTimeFormat.twentyFourHour).mediumDateTime(instant),
      'Jun 10, 2026, 09:05',
    );
    expect(
      f('en', SourceTimeFormat.twelveHour).mediumDateTime(instant),
      matches(RegExp(r'^Jun 10, 2026, 9:05\s?AM$')),
    );
    expect(
      f('en', SourceTimeFormat.twentyFourHour, 'Asia/Tokyo').mediumDateTime(instant),
      'Jun 10, 2026, 18:05',
    );
    expect(
      f('zh_CN', SourceTimeFormat.twentyFourHour).mediumDateTime(instant),
      '2026年6月10日 09:05',
    );
    expect(f('en', SourceTimeFormat.twentyFourHour).mediumDateTime('nope'), 'nope');
  });

  test('followPreference: false uses the locale hour cycle (react-intl formatDate)', () async {
    await initializeSourceTimeFormatting();
    const instant = '2026-06-10T21:05:00Z';
    final f = SourceTimeFormatter(
      locale: 'en',
      preferredTimezone: 'UTC',
      preferredTimeFormat: SourceTimeFormat.twentyFourHour,
    );
    expect(f.mediumDateTime(instant), 'Jun 10, 2026, 21:05');
    expect(
      f.mediumDateTime(instant, followPreference: false),
      matches(RegExp(r'^Jun 10, 2026, 9:05\s?PM$')),
    );
  });
}
