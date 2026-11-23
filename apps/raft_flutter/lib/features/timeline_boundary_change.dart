import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;

/// A verified boundary extension of immutable presented message versions.
/// Extent tracking can also accept edits that keep every existing row in order.
class TimelineBoundaryChange {
  const TimelineBoundaryChange(
    this.before,
    this.after, [
    this.edits = const [],
  ]);
  final int before, after;
  final List<int> edits;

  static TimelineBoundaryChange? between(
    List<chat.Message> previous,
    List<chat.Message> next, {
    bool allowEdits = false,
  }) {
    if (identical(previous, next)) return const TimelineBoundaryChange(0, 0);
    if (previous.isEmpty || next.length < previous.length) return null;
    bool matches(chat.Message old, chat.Message current) =>
        identical(old, current) || allowEdits && old.id == current.id;
    var start = 0;
    while (start < next.length && !matches(previous.first, next[start])) {
      start++;
    }
    if (start + previous.length > next.length) return null;
    List<int>? edits;
    for (var i = 0; i < previous.length; i++) {
      final index = start + i;
      if (identical(previous[i], next[index])) continue;
      if (!matches(previous[i], next[index])) return null;
      (edits ??= []).add(index);
    }
    return TimelineBoundaryChange(
      start,
      next.length - start - previous.length,
      edits ?? const [],
    );
  }
}
