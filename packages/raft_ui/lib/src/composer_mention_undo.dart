import 'package:flutter/services.dart';

/// Web `MentionUndoSnapshot`: what the composer held just before a mention was
/// inserted for the user (a suggestion chosen, or "mention the sender"), and
/// the text that insert produced. While the text is still [afterText],
/// Cmd/Ctrl+Z puts the "before" state back in one step.
class RaftMentionUndoSnapshot {
  RaftMentionUndoSnapshot({
    required this.beforeText,
    required this.beforeCursor,
    required Map<String, Map<String, dynamic>> beforeMentions,
    required this.afterText,
  }) : beforeMentions = {
         for (final entry in beforeMentions.entries) entry.key: entry.value,
       };
  final String beforeText, afterText;
  final int beforeCursor;
  final Map<String, Map<String, dynamic>> beforeMentions;
}

/// Web `handleKeyDown`: Cmd or Ctrl with Z, no Shift (that is redo), no Alt.
bool raftIsMentionUndoKey(KeyEvent event) {
  final keyboard = HardwareKeyboard.instance;
  return event is KeyDownEvent &&
      event.logicalKey == LogicalKeyboardKey.keyZ &&
      (keyboard.isMetaPressed || keyboard.isControlPressed) &&
      !keyboard.isShiftPressed &&
      !keyboard.isAltPressed;
}

/// The value the undo restores: the text before the insert, the caret where
/// it was, nothing composing.
TextEditingValue raftMentionUndoValue(RaftMentionUndoSnapshot snapshot) =>
    TextEditingValue(
      text: snapshot.beforeText,
      selection: TextSelection.collapsed(
        offset: snapshot.beforeCursor.clamp(0, snapshot.beforeText.length),
      ),
    );
