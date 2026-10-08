import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as database;
import 'package:timezone/timezone.dart' as tz;

/// Initialize once before constructing a formatter. This does not assign
/// timezone's process-global `local`, which otherwise defaults to UTC.
Future<void>? _initialization;
Future<void> initializeSourceTimeFormatting() =>
    _initialization ??= _initialize();
Future<void> _initialize() async {
  database.initializeTimeZones();
  await initializeDateFormatting();
}

enum SourceTimeFormat { twelveHour, twentyFourHour }

SourceTimeFormat? sourceTimeFormatPreference(String? value) => switch (value) {
  '12h' => SourceTimeFormat.twelveHour,
  '24h' => SourceTimeFormat.twentyFourHour,
  _ => null,
};

/// Source useTimeFormatter/timeFormatting.ts projection, independent of widgets,
/// account state and the device's current UTC offset. All timestamps are instants.
///
/// [hostTimezone] is optional native-host IANA identity. When absent, Dart's OS
/// local conversion provides the fallback; never use `tz.local` as the device
/// zone. [systemTimeFormat] projects the host preference separately from the UI
/// locale, as Web's effectiveTimeFormat is detected outside useIntl.
class SourceTimeFormatter {
  SourceTimeFormatter({
    String locale = 'en',
    String? preferredTimezone,
    String? hostTimezone,
    this.preferredTimeFormat,
    this.systemTimeFormat,
    this.todayLabel = 'Today',
    this.yesterdayLabel = 'Yesterday',
  }) : locale = Intl.canonicalizedLocale(locale),
       preferredZone = _location(preferredTimezone),
       hostZone = _location(hostTimezone) {
    unawaited(initializeSourceTimeFormatting());
  }

  final String locale;
  final tz.Location? preferredZone, hostZone;
  final SourceTimeFormat? preferredTimeFormat, systemTimeFormat;
  final String todayLabel, yesterdayLabel;

  static tz.Location? _location(String? name) {
    final normalized = name?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    // Unknown named zones fail explicitly, matching Intl's RangeError. Silently
    // substituting UTC/device local would make accepted times misleading.
    unawaited(initializeSourceTimeFormatting());
    return tz.getLocation(normalized);
  }

  DateTime hostWallTime(DateTime instant) => hostZone == null
      ? DateTime.fromMicrosecondsSinceEpoch(instant.microsecondsSinceEpoch)
      : tz.TZDateTime.from(instant, hostZone!);

  DateTime wallTime(DateTime instant) => preferredZone == null
      ? hostWallTime(instant)
      : tz.TZDateTime.from(instant, preferredZone!);

  bool get _chinese => locale == 'zh' || locale.startsWith('zh_');

  bool get _localeUsesTwelveHours {
    return DateFormat.jm(locale).pattern!.contains('h');
  }

  SourceTimeFormat get effectiveTimeFormat =>
      preferredTimeFormat ??
      systemTimeFormat ??
      (_localeUsesTwelveHours
          ? SourceTimeFormat.twelveHour
          : SourceTimeFormat.twentyFourHour);

  /// Preferred-zone calendar identity, also used by timeline grouping and
  /// sticky day headers. Not UTC duration buckets or device-local DateTimes.
  String dayKey(DateTime instant) {
    final date = wallTime(instant);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      // ECMAScript ISO date-only values are UTC; ISO values with a time but no
      // offset are host-local. Dart otherwise treats both as local.
      if (parsed != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        return DateTime.utc(parsed.year, parsed.month, parsed.day);
      }
      return parsed;
    }
    if (value is num && value.isFinite) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      } on ArgumentError {
        return null;
      }
    }
    return null;
  }

  String _clock(DateTime date, {bool seconds = false, bool force24 = false}) {
    final wall = wallTime(date);
    if (!force24 && effectiveTimeFormat == SourceTimeFormat.twelveHour) {
      // Preserve shipped locale AM/PM placement and two-digit hour requested
      // by toLocaleTimeString. Intl's generic jm omits the leading hour zero.
      final pattern = _chinese
          ? (seconds ? 'ahh:mm:ss' : 'ahh:mm')
          : (seconds ? 'hh:mm:ss a' : 'hh:mm a');
      return DateFormat(pattern, locale).format(wall);
    }
    // Original source executed with the recorded Node/ICU uses 00 at midnight
    // in both shipped locales. Preserve that receipt; no invented 24:00 shift.
    final hour = wall.hour;
    final clock =
        '${hour.toString().padLeft(2, '0')}:'
        '${wall.minute.toString().padLeft(2, '0')}';
    return seconds ? '$clock:${wall.second.toString().padLeft(2, '0')}' : clock;
  }

  String clock(Object? value, {bool seconds = false, bool force24 = false}) {
    final date = _date(value);
    return date == null
        ? (value?.toString() ?? '')
        : _clock(date, seconds: seconds, force24: force24);
  }

  DateTime _previousHostDay(DateTime now) {
    final host = hostWallTime(now);
    // Exact source operation is host Date.setDate(getDate()-1), not subtracting
    // 24 hours and not shifting the preferred-zone calendar. Preserve local DST.
    return hostZone == null
        ? DateTime(
            host.year,
            host.month,
            host.day - 1,
            host.hour,
            host.minute,
            host.second,
            host.millisecond,
            host.microsecond,
          )
        : tz.TZDateTime(
            hostZone!,
            host.year,
            host.month,
            host.day - 1,
            host.hour,
            host.minute,
            host.second,
            host.millisecond,
            host.microsecond,
          );
  }

  String _numericDate(DateTime date, {required bool year}) {
    final template = year ? DateFormat.yMd(locale) : DateFormat.Md(locale);
    final pattern = template.pattern!
        .replaceAll(RegExp(r'M+'), 'MM')
        .replaceAll(RegExp(r'd+'), 'dd');
    return DateFormat(pattern, locale).format(wallTime(date));
  }

  String messageTime(Object? value, {DateTime? now}) {
    final date = _date(value);
    if (date == null) return value?.toString() ?? '';
    final current = now ?? DateTime.now();
    final time = _clock(date);
    if (dayKey(date) == dayKey(current)) return time;
    if (dayKey(date) == dayKey(_previousHostDay(current))) {
      return '$yesterdayLabel $time';
    }
    return '${_numericDate(date, year: wallTime(date).year != wallTime(current).year)} $time';
  }

  /// useTimeFormatter.formatShortDateTime: preferred-zone abbreviated month,
  /// numeric day and the explicit two-digit chosen hour cycle, without a year.
  String shortDateTime(Object? value) {
    final date = _date(value);
    if (date == null) return value?.toString() ?? '';
    final day = DateFormat.MMMd(locale).format(wallTime(date));
    return '$day${_chinese ? ' ' : ', '} ${_clock(date)}'.replaceAll('  ', ' ');
  }

  String dayLabel(Object? value, {DateTime? now}) {
    final date = _date(value);
    if (date == null) return '';
    final current = now ?? DateTime.now();
    if (dayKey(date) == dayKey(current)) return todayLabel;
    if (dayKey(date) == dayKey(_previousHostDay(current))) {
      return yesterdayLabel;
    }
    // DateDivider.tsx compares getFullYear in the host zone; messageTime above
    // instead compares preferred-zone years. Preserve the separate source rules.
    final sameYear = hostWallTime(date).year == hostWallTime(current).year;
    final format = sameYear
        ? DateFormat.MMMMEEEEd(locale)
        : DateFormat.yMMMMEEEEd(locale);
    return format.format(wallTime(date));
  }
}
