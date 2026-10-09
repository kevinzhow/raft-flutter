export 'package:raft_ui/raft_ui.dart'
    show
        SourceTaskRowExtent,
        RaftConversationCardRecipe,
        RaftConversationCard,
        RaftConversationTimestamp;

/// Source relativeTime.ts unit selection and numeric:auto words. The injected
/// clock keeps public visual fixtures reproducible without changing live time.
String resourceRelativeTime(
  String? value, {
  DateTime? now,
  bool chinese = false,
}) {
  final time = value == null ? null : DateTime.tryParse(value);
  if (time == null) return '';
  final delta = time.difference(now ?? DateTime.now()).inMilliseconds;
  final abs = delta.abs();
  final unit = abs < 3600000
      ? 'minute'
      : abs < 86400000
      ? 'hour'
      : 'day';
  final divisor = unit == 'minute'
      ? 60000
      : unit == 'hour'
      ? 3600000
      : 86400000;
  // JavaScript Math.round rounds negative half values toward positive infinity.
  final count = (delta / divisor + .5).floor();
  if (chinese) {
    if (count == 0) {
      return unit == 'minute'
          ? '此刻'
          : unit == 'hour'
          ? '这一小时'
          : '今天';
    }
    if (unit == 'day' && count == -1) return '昨天';
    if (unit == 'day' && count == 1) return '明天';
    final label = unit == 'minute'
        ? '分钟'
        : unit == 'hour'
        ? '小时'
        : '天';
    return '${count.abs()} $label${count < 0 ? '前' : '后'}';
  }
  if (count == 0) {
    return unit == 'minute'
        ? 'this minute'
        : unit == 'hour'
        ? 'this hour'
        : 'today';
  }
  if (unit == 'day' && count == -1) return 'yesterday';
  if (unit == 'day' && count == 1) return 'tomorrow';
  final label = '$unit${count.abs() == 1 ? '' : 's'}';
  return count < 0 ? '${count.abs()} $label ago' : 'in $count $label';
}
