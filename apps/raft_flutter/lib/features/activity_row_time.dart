// An Activity row's time (Web v1.24 `ActivityRowTime.tsx` and
// `utils/timeFormatting.ts` `formatRowTime` / `rowTimeKey`): "now", "3m", "2h"
// while the row is from today, the clock on any older row (shown on hover only,
// never on touch), the time in words for the tooltip and the row's name. One
// shared clock re-evaluates every row's time, and a row rebuilds only when what
// it says changed.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import 'icu_message.dart';

/// What a row's time says (`RowTime`).
class RowTime {
  const RowTime({
    required this.shown,
    required this.older,
    required this.words,
  });

  /// "now", "3m", "2h"; on an older row its clock.
  final String shown;

  /// Revealed only by hover or keyboard focus (never on touch).
  final bool older;

  /// "2 hours ago", "yesterday at 5:20 PM", "Tuesday at 9:05": the tooltip and
  /// the row's accessible name, shown or not.
  final String words;
}

/// The words of `activity.list.time.*`, as the row's locale says them.
class RowTimeCopy {
  const RowTimeCopy({
    required this.now,
    required this.minutes,
    required this.hours,
    required this.minutesAgo,
    required this.hoursAgo,
    required this.yesterdayAt,
    required this.dayAt,
  });

  final String now;
  final String Function(int count) minutes, hours, minutesAgo, hoursAgo;
  final String Function(String time) yesterdayAt;
  final String Function(String day, String time) dayAt;

  /// The copy of [context]'s language.
  factory RowTimeCopy.of(BuildContext context) => RowTimeCopy(
    now: raftText(context, 'now'),
    minutes: (count) => raftFormat(context, '{count}m', {'count': count}),
    hours: (count) => raftFormat(context, '{count}h', {'count': count}),
    minutesAgo: (count) => icuText(
      context,
      '{count, plural, one {# minute ago} other {# minutes ago}}',
      {'count': count},
    ),
    hoursAgo: (count) => icuText(
      context,
      '{count, plural, one {# hour ago} other {# hours ago}}',
      {'count': count},
    ),
    yesterdayAt: (time) =>
        raftFormat(context, 'yesterday at {time}', {'time': time}),
    dayAt: (day, time) =>
        raftFormat(context, '{day} at {time}', {'day': day, 'time': time}),
  );
}

enum _Step { now, minutes, hours, older }

({_Step step, int count}) _stepOf(
  DateTime at,
  DateTime now,
  SourceTimeFormatter formatter,
) {
  final elapsed = now.difference(at);
  // A time a little ahead of this device's clock reads as now.
  if (elapsed < const Duration(minutes: 1)) return (step: _Step.now, count: 0);
  if (elapsed < const Duration(hours: 1)) {
    return (step: _Step.minutes, count: elapsed.inMinutes);
  }
  if (formatter.dayKey(at) != formatter.dayKey(now)) {
    return (step: _Step.older, count: 0);
  }
  return (step: _Step.hours, count: elapsed.inHours);
}

/// Web `rowTimeKey`: changes exactly when what [formatRowTime] says changes. An
/// older row's words depend on the day ("yesterday at", then "Tuesday at").
String rowTimeKey(Object? value, DateTime now, SourceTimeFormatter formatter) {
  final at = _parse(value);
  if (at == null) return '';
  final s = _stepOf(at, now, formatter);
  return switch (s.step) {
    _Step.now => 'now',
    _Step.older => 'older:${formatter.dayKey(now)}',
    _Step.minutes => 'minutes:${s.count}',
    _Step.hours => 'hours:${s.count}',
  };
}

DateTime? _parse(Object? value) {
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

/// The clock of a list row in the person's 12-hour or 24-hour choice, with no
/// leading zero: "5:20 PM", "17:20", "9:05".
String formatRowClock(DateTime at, SourceTimeFormatter formatter) {
  final wall = formatter.wallTime(at);
  if (formatter.effectiveTimeFormat == SourceTimeFormat.twelveHour) {
    final chinese =
        formatter.locale == 'zh' || formatter.locale.startsWith('zh_');
    return DateFormat(
      chinese ? 'ah:mm' : 'h:mm a',
      formatter.locale,
    ).format(wall);
  }
  return '${wall.hour}:${wall.minute.toString().padLeft(2, '0')}';
}

/// Web `formatRowTime`: null when [value] is not a time.
RowTime? formatRowTime(
  Object? value, {
  required DateTime now,
  required SourceTimeFormatter formatter,
  required RowTimeCopy copy,
}) {
  final at = _parse(value);
  if (at == null) return null;
  final s = _stepOf(at, now, formatter);
  switch (s.step) {
    case _Step.now:
      return RowTime(shown: copy.now, older: false, words: copy.now);
    case _Step.minutes:
      return RowTime(
        shown: copy.minutes(s.count),
        older: false,
        words: copy.minutesAgo(s.count),
      );
    case _Step.hours:
      return RowTime(
        shown: copy.hours(s.count),
        older: false,
        words: copy.hoursAgo(s.count),
      );
    case _Step.older:
      final clock = formatRowClock(at, formatter);
      final today = formatter.dayKey(now), day = formatter.dayKey(at);
      final yesterday = DateTime.parse('${today}T12:00:00Z')
          .subtract(const Duration(days: 1));
      final yesterdayKey = yesterday.toIso8601String().substring(0, 10);
      if (day == yesterdayKey) {
        return RowTime(
          shown: clock,
          older: true,
          words: copy.yesterdayAt(clock),
        );
      }
      final daysAgo = DateTime.parse('${today}T12:00:00Z')
          .difference(DateTime.parse('${day}T12:00:00Z'))
          .inDays;
      final wall = formatter.wallTime(at);
      // A weekday names a day only within the last week; past that the name
      // needs its date.
      final name = daysAgo < 7
          ? DateFormat.EEEE(formatter.locale).format(wall)
          : (day.substring(0, 4) == today.substring(0, 4)
                    ? DateFormat.MMMMd(formatter.locale)
                    : DateFormat.yMMMMd(formatter.locale))
                .format(wall);
      return RowTime(shown: clock, older: true, words: copy.dayAt(name, clock));
  }
}

/// The one clock of every row's time. A tick re-evaluates each live row, which
/// rebuilds only when its [rowTimeKey] changed. Every 15 seconds, since each
/// row's minutes turn at their own second (Web `liveTimeClock`). It runs only
/// while a row listens and the app is in the foreground.
class ActivityRowClock {
  ActivityRowClock._();
  static final ActivityRowClock instance = ActivityRowClock._();

  static const Duration interval = Duration(seconds: 15);
  final Set<VoidCallback> _listeners = {};
  RaftForegroundPeriodic? _periodic;

  int get listenerCount => _listeners.length;

  /// Whether the clock's one timer is armed (rows listen, app in foreground).
  bool get running => _periodic?.isRunning ?? false;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    _periodic ??= RaftForegroundPeriodic(interval, tick);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _periodic?.dispose();
      _periodic = null;
    }
  }

  void tick() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }
}

/// The formatter of the row's person: their zone and 12 / 24-hour choice.
SourceTimeFormatter activityRowFormatter(
  BuildContext context,
  Map<String, dynamic>? user,
) => SourceTimeFormatter(
  locale: Localizations.localeOf(context).toLanguageTag(),
  preferredTimezone: _text(user?['preferredTimezone'] ?? user?['timezone']),
  preferredTimeFormat: sourceTimeFormatPreference(
    _text(user?['preferredTimeFormat'] ?? user?['timeFormat']),
  ),
  systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
      ? SourceTimeFormat.twentyFourHour
      : null,
);

String? _text(Object? value) => value is String ? value : null;

/// Builds a row's time and keeps it live: rebuilds [builder] only when the
/// shared clock's tick changes what [at] says.
class ActivityRowTimeBuilder extends StatefulWidget {
  const ActivityRowTimeBuilder({
    super.key,
    required this.at,
    required this.user,
    required this.builder,
  });

  final Object? at;
  final Map<String, dynamic>? user;
  final Widget Function(BuildContext context, RowTime? time) builder;

  @override
  State<ActivityRowTimeBuilder> createState() => _ActivityRowTimeBuilderState();
}

class _ActivityRowTimeBuilderState extends State<ActivityRowTimeBuilder> {
  String _key = '';
  SourceTimeFormatter? _formatter;

  @override
  void initState() {
    super.initState();
    ActivityRowClock.instance.addListener(_tick);
  }

  @override
  void dispose() {
    ActivityRowClock.instance.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    final formatter = _formatter;
    if (!mounted || formatter == null) return;
    final key = rowTimeKey(widget.at, sourceTimeNow(), formatter);
    if (key != _key) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final formatter = _formatter = activityRowFormatter(context, widget.user);
    final now = sourceTimeNow();
    _key = rowTimeKey(widget.at, now, formatter);
    return widget.builder(
      context,
      formatRowTime(
        widget.at,
        now: now,
        formatter: formatter,
        copy: RowTimeCopy.of(context),
      ),
    );
  }
}
