import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;

/// A verified boundary-only extension of immutable presented message versions.
/// Interior edits, deletions and reordering use the general reconciliation path.
class TimelineBoundaryChange {
  const TimelineBoundaryChange(this.before, this.after);
  final int before, after;

  static TimelineBoundaryChange? between(
    List<chat.Message> previous,
    List<chat.Message> next,
  ) {
    if (identical(previous, next)) return const TimelineBoundaryChange(0, 0);
    if (previous.isEmpty || next.length < previous.length) return null;
    var start = 0;
    while (start < next.length && !identical(next[start], previous.first)) {
      start++;
    }
    if (start + previous.length > next.length) return null;
    for (var i = 1; i < previous.length; i++) {
      if (!identical(previous[i], next[start + i])) return null;
    }
    return TimelineBoundaryChange(start, next.length - start - previous.length);
  }
}
