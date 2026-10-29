import 'package:flutter/services.dart';

bool _high(int value) => value >= 0xd800 && value <= 0xdbff;
bool _low(int value) => value >= 0xdc00 && value <= 0xdfff;

/// Programmatic offsets use UTF-16, but must not separate a surrogate pair.
int raftSafeEditingOffset(String text, int offset, {bool forward = false}) {
  var value = offset.clamp(0, text.length);
  if (value > 0 &&
      value < text.length &&
      _high(text.codeUnitAt(value - 1)) &&
      _low(text.codeUnitAt(value))) {
    value += forward ? 1 : -1;
  }
  return value;
}

/// Normalizes only app-supplied drafts, never an in-progress platform edit.
String raftProgrammaticEditingText(String text) {
  final units = text.codeUnits;
  List<int>? fixed;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (_high(unit) && i + 1 < units.length && _low(units[i + 1])) {
      fixed?.add(unit);
      fixed?.add(units[i + 1]);
      i++;
    } else if (_high(unit) || _low(unit)) {
      fixed ??= units.take(i).toList();
      fixed.add(0xfffd);
    } else {
      fixed?.add(unit);
    }
  }
  return fixed == null ? text : String.fromCharCodes(fixed);
}

({int start, int end, String insertion}) _change(String before, String after) {
  var start = 0;
  while (start < before.length &&
      start < after.length &&
      before.codeUnitAt(start) == after.codeUnitAt(start)) {
    start++;
  }
  start = raftSafeEditingOffset(before, start);
  start = raftSafeEditingOffset(after, start);
  var oldEnd = before.length, newEnd = after.length;
  while (oldEnd > start &&
      newEnd > start &&
      before.codeUnitAt(oldEnd - 1) == after.codeUnitAt(newEnd - 1)) {
    oldEnd--;
    newEnd--;
  }
  oldEnd = raftSafeEditingOffset(before, oldEnd, forward: true);
  newEnd = raftSafeEditingOffset(after, newEnd, forward: true);
  return (start: start, end: oldEnd, insertion: after.substring(start, newEnd));
}

/// A deferred external draft rebases onto text that the IME keeps editing.
/// Ordinary shared captions append; failed sends prepend. For overlapping
/// replacements, preserve both texts instead of discarding live input.
class RaftDeferredComposerDraft {
  RaftDeferredComposerDraft(
    this.base,
    String requested, {
    this.following,
    this.preferPrepend = false,
  }) : requested = raftProgrammaticEditingText(requested);
  final String base, requested;
  final RaftDeferredComposerDraft? following;
  final bool preferPrepend;

  String resolve(String current) =>
      _resolve(following?.resolve(current) ?? current);

  TextEditingValue resolveValue(TextEditingValue current) {
    final before = following?.resolveValue(current) ?? current;
    final next = _resolve(before.text);
    return TextEditingValue(
      text: next,
      selection: raftProgrammaticSelection(
        before,
        next,
        preferPrepend: preferPrepend,
      ),
    );
  }

  String _resolve(String current) {
    if (current == base) return requested;
    if (requested == base) return current;
    if (preferPrepend && requested.endsWith(base)) {
      return requested.substring(0, requested.length - base.length) + current;
    }
    if (requested.startsWith(base)) {
      return current + requested.substring(base.length);
    }
    if (requested.endsWith(base)) {
      return requested.substring(0, requested.length - base.length) + current;
    }
    final position = base.isEmpty ? -1 : requested.indexOf(base);
    if (position >= 0) {
      return requested.substring(0, position) +
          current +
          requested.substring(position + base.length);
    }
    final external = _change(base, requested), live = _change(base, current);
    if (external.end <= live.start) {
      return current.replaceRange(
        external.start,
        external.end,
        external.insertion,
      );
    }
    if (external.start >= live.end) {
      final shift = live.insertion.length - (live.end - live.start);
      return current.replaceRange(
        external.start + shift,
        external.end + shift,
        external.insertion,
      );
    }
    if (requested.isEmpty || current.isEmpty) {
      return current.isEmpty ? requested : current;
    }
    return current == requested ? current : '$current\n$requested';
  }
}

/// Maps the caret through one programmatic edit without splitting UTF-16 pairs.
TextSelection raftProgrammaticSelection(
  TextEditingValue old,
  String next, {
  bool preferPrepend = false,
}) {
  if (!old.selection.isValid) {
    return TextSelection.collapsed(offset: next.length);
  }
  final unchanged = old.text.isEmpty
      ? -1
      : preferPrepend && next.endsWith(old.text)
      ? next.length - old.text.length
      : next.startsWith(old.text)
      ? 0
      : next.endsWith(old.text)
      ? next.length - old.text.length
      : next.indexOf(old.text);
  final change = _change(old.text, next);
  int map(int offset) {
    if (unchanged >= 0) return raftSafeEditingOffset(next, unchanged + offset);
    var result = offset;
    if (offset > change.start ||
        (offset == change.start && change.start < old.text.length)) {
      result = offset >= change.end
          ? offset + change.insertion.length - (change.end - change.start)
          : change.start + change.insertion.length;
    }
    return raftSafeEditingOffset(next, result);
  }

  return TextSelection(
    baseOffset: map(old.selection.baseOffset),
    extentOffset: map(old.selection.extentOffset),
    affinity: old.selection.affinity,
    isDirectional: old.selection.isDirectional,
  );
}
