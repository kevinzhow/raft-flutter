import 'package:intl/intl.dart';

import '../data/display_relative_times.g.dart';
import '../data/source_number_format.dart';

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
  String? locale,
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
  final patterns =
      displayRelativeTimes[locale?.toLowerCase().replaceAll('_', '-')];
  if (patterns != null) {
    final (words, before, after) =
        patterns[unit == 'minute'
            ? 0
            : unit == 'hour'
            ? 1
            : 2];
    final word = words[count];
    if (word != null) return word;
    final forms = count < 0 ? before : after;
    final magnitude = count.abs();
    final pattern = Intl.pluralLogic(
      magnitude,
      locale: locale,
      one: forms['one'],
      two: forms['two'],
      few: forms['few'],
      many: forms['many'],
      other: forms['other']!,
      useExplicitNumberCases: false,
    );
    return pattern.replaceFirst('{number}', sourceDecimal(magnitude, locale));
  }
  if (chinese || locale?.toLowerCase().startsWith('zh') == true) {
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
