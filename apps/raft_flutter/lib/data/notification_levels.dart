// Source: packages/shared/src/notifications.ts and
// packages/web/src/notifications/pause.ts at v1.24.0-source.1 (1d689caf).
// The unified notification contract's pure rules: levels and their
// inheritance, account settings (pause, quiet hours, preview, sound, phone
// alerts, followed-thread replies), and the one badge number.
library;

/// One enum, three scopes (server, channel incl. DM, thread incl. task).
enum NotificationLevel {
  all,
  mentions,
  none;

  static NotificationLevel? parse(Object? value) => switch (value) {
    'all' => all,
    'mentions' => mentions,
    'none' => none,
    _ => null,
  };

  int get _rank => switch (this) {
    none => 0,
    mentions => 1,
    all => 2,
  };

  /// Web `NOTIFICATION_LEVEL_LABEL_ID` (notifications.level.*).
  String get label => switch (this) {
    all => 'All new messages',
    mentions => 'Only what involves me',
    none => 'Nothing',
  };
}

/// A stored setting: `null` is `default` (inherits the next wider scope).
NotificationLevel? parseLevelSetting(Object? value) =>
    value == 'default' ? null : NotificationLevel.parse(value);

bool isLevelSetting(Object? value) =>
    value == 'default' || NotificationLevel.parse(value) != null;

String levelSettingWire(NotificationLevel? level) => level?.name ?? 'default';

/// `resolveEffectiveLevel`: the most specific explicit setting wins
/// (thread > channel > server), then a mute caps it at `mentions`.
NotificationLevel resolveEffectiveLevel({
  required NotificationLevel server,
  NotificationLevel? channel,
  NotificationLevel? thread,
  bool muted = false,
}) {
  final level = thread ?? channel ?? server;
  if (muted && level._rank > NotificationLevel.mentions._rank) {
    return NotificationLevel.mentions;
  }
  return level;
}

/// The one badge number: Activity unread summed over every server whose
/// level is not `none` (`notificationBadgeCount`).
int notificationBadgeCount(
  Iterable<({NotificationLevel level, int activityUnreadCount})> servers,
) {
  var total = 0;
  for (final server in servers) {
    if (server.level == NotificationLevel.none) continue;
    if (server.activityUnreadCount > 0) total += server.activityUnreadCount;
  }
  return total;
}

enum NotificationPreviewMode {
  full('full', 'Sender and message'),
  senderOnly('sender_only', 'Sender only'),
  hidden('hidden', 'Hidden');

  const NotificationPreviewMode(this.wire, this.label);
  final String wire, label;

  static NotificationPreviewMode? parse(Object? value) {
    for (final mode in values) {
      if (mode.wire == value) return mode;
    }
    return null;
  }
}

/// "Phone alerts" (contract §1.3).
enum NotificationMobileDelay {
  always('always', "Always, even when I'm active on a computer"),
  inactive('inactive', "Only when I'm not active on a computer"),
  m1('1m', "If I'm away from my computer for 1 min and it's still unread"),
  m2('2m', "If I'm away from my computer for 2 min and it's still unread"),
  m5('5m', "If I'm away from my computer for 5 min and it's still unread"),
  m10('10m', "If I'm away from my computer for 10 min and it's still unread");

  const NotificationMobileDelay(this.wire, this.label);
  final String wire, label;

  /// ContentCard's order: the default first, then each step more eager to
  /// ring, "always" last.
  static const order = [inactive, m1, m2, m5, m10, always];

  static NotificationMobileDelay? parse(Object? value) {
    for (final delay in values) {
      if (delay.wire == value) return delay;
    }
    return null;
  }
}

class NotificationQuietHours {
  const NotificationQuietHours({
    required this.enabled,
    required this.startMinute,
    required this.endMinute,
    required this.timeZone,
  });
  final bool enabled;

  /// Minutes after local midnight, 0-1439. start > end spans midnight.
  final int startMinute, endMinute;
  final String timeZone;

  NotificationQuietHours copyWith({
    bool? enabled,
    int? startMinute,
    int? endMinute,
    String? timeZone,
  }) => NotificationQuietHours(
    enabled: enabled ?? this.enabled,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    timeZone: timeZone ?? this.timeZone,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'timeZone': timeZone,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationQuietHours &&
      other.enabled == enabled &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.timeZone == timeZone;

  @override
  int get hashCode => Object.hash(enabled, startMinute, endMinute, timeZone);
}

bool _isMinute(Object? value) => value is int && value >= 0 && value <= 1439;

/// `NotificationAccountSettings`: the same on every device of the account.
class NotificationAccountSettings {
  const NotificationAccountSettings({
    required this.pausedUntil,
    required this.quietHours,
    required this.previewMode,
    required this.sound,
    required this.mobileDelay,
    required this.followedThreadReplies,
    required this.version,
  });
  final DateTime? pausedUntil;
  final NotificationQuietHours quietHours;
  final NotificationPreviewMode previewMode;
  final bool sound;
  final NotificationMobileDelay mobileDelay;
  final bool followedThreadReplies;

  /// Optimistic concurrency: sent back on PATCH; a stale one gets 409.
  final int version;

  /// `parseNotificationAccountSettings`: closed, null when malformed.
  static NotificationAccountSettings? parse(Object? value) {
    if (value is! Map) return null;
    final quiet = value['quietHours'];
    if (quiet is! Map) return null;
    if (quiet['enabled'] is! bool ||
        !_isMinute(quiet['startMinute']) ||
        !_isMinute(quiet['endMinute']) ||
        quiet['timeZone'] is! String) {
      return null;
    }
    final paused = value['pausedUntil'];
    if (paused != null && paused is! String) return null;
    final preview = NotificationPreviewMode.parse(value['previewMode']);
    if (preview == null || value['sound'] is! bool) return null;
    final version = value['version'];
    if (version is! int || version < 0) return null;
    return NotificationAccountSettings(
      pausedUntil: paused is String ? DateTime.tryParse(paused) : null,
      quietHours: NotificationQuietHours(
        enabled: quiet['enabled'] as bool,
        startMinute: quiet['startMinute'] as int,
        endMinute: quiet['endMinute'] as int,
        timeZone: quiet['timeZone'] as String,
      ),
      previewMode: preview,
      sound: value['sound'] as bool,
      // Contract v1.1; an older server sends none (its behaviour is `inactive`).
      mobileDelay:
          NotificationMobileDelay.parse(value['mobileDelay']) ??
          NotificationMobileDelay.inactive,
      // Contract v1.2; an older server sends none (its behaviour is on).
      followedThreadReplies: value['followedThreadReplies'] != false,
      version: version,
    );
  }

  /// Paused or in quiet hours: no alert anywhere, badges still sync
  /// (`isNotificationQuiet`).
  bool quietAt(DateTime now) =>
      isPausedNow(pausedUntil, now) || isWithinQuietHours(quietHours, now);
}

bool isPausedNow(DateTime? pausedUntil, DateTime now) =>
    pausedUntil != null && pausedUntil.isAfter(now);

/// Inside the daily quiet hours (start inclusive, end exclusive; start > end
/// spans midnight). The minute of day is read in [localMinuteOf] (the
/// quiet hours' time zone, defaulting to the device's local time when the
/// stored zone is the device's or unknown here).
bool isWithinQuietHours(
  NotificationQuietHours quiet,
  DateTime now, {
  int? Function(DateTime now, String timeZone)? localMinuteOf,
}) {
  if (!quiet.enabled || quiet.startMinute == quiet.endMinute) return false;
  final minute = (localMinuteOf ?? _deviceMinute)(now, quiet.timeZone);
  if (minute == null) return false;
  return quiet.startMinute < quiet.endMinute
      ? minute >= quiet.startMinute && minute < quiet.endMinute
      : minute >= quiet.startMinute || minute < quiet.endMinute;
}

/// Dart has no IANA zone database: UTC is exact, any other zone is read as
/// the device's local time (the zone the device saved them for).
int? _deviceMinute(DateTime now, String timeZone) {
  final t = timeZone == 'UTC' || timeZone == 'Etc/UTC'
      ? now.toUtc()
      : now.toLocal();
  return t.hour * 60 + t.minute;
}

/// Pause presets (Web notifications/pause.ts).
enum PausePreset {
  m30('For 30 minutes'),
  h1('For 1 hour'),
  h2('For 2 hours'),
  tomorrow('Until tomorrow 9:00');

  const PausePreset(this.label);
  final String label;
}

/// 09:00 local time on the next calendar day.
DateTime nextMorningNine(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1, 9);
}

DateTime pausedUntilForPreset(PausePreset preset, DateTime now) =>
    switch (preset) {
      PausePreset.m30 => now.add(const Duration(minutes: 30)),
      PausePreset.h1 => now.add(const Duration(hours: 1)),
      PausePreset.h2 => now.add(const Duration(hours: 2)),
      PausePreset.tomorrow => nextMorningNine(now),
    };

String minutesToTime(int minutes) {
  final h = (minutes ~/ 60) % 24, m = minutes % 60;
  return '${'$h'.padLeft(2, '0')}:${'$m'.padLeft(2, '0')}';
}

int? timeToMinutes(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final h = int.parse(match[1]!), m = int.parse(match[2]!);
  if (h > 23 || m > 59) return null;
  return h * 60 + m;
}
