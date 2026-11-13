// Source: packages/shared/src/readStateContract.ts at v1.24.0-source.1
// (`MARK_UNREAD_OUTCOMES`, `resolveMarkUnreadOutcome`).

/// What a Mark as Unread answer (`POST /channels/{id}/unread`) left on the
/// conversation, decided by the server from the read state it wrote:
/// - [counted]: a message from someone else lies past the read position, so
///   the conversation shows a number (`unreadCount`);
/// - [marked]: nothing countable lies past it (a thread of only the person's
///   own replies), so the conversation carries the marked-unread flag and no
///   number;
/// - [nothing]: it stays read (no messages, or not a member).
enum MarkUnreadOutcome { counted, marked, nothing }

/// The server's `outcome` when it sends one, else the inference clients used
/// before it: a count wins over the mark, an answer with neither is
/// [MarkUnreadOutcome.nothing].
MarkUnreadOutcome resolveMarkUnreadOutcome(Object? answer) {
  final map = answer is Map ? answer : const {};
  switch (map['outcome']) {
    case 'counted':
      return MarkUnreadOutcome.counted;
    case 'marked':
      return MarkUnreadOutcome.marked;
    case 'nothing':
      return MarkUnreadOutcome.nothing;
  }
  final count = map['unreadCount'];
  if (count is num && count > 0) return MarkUnreadOutcome.counted;
  return map['markedUnread'] == true
      ? MarkUnreadOutcome.marked
      : MarkUnreadOutcome.nothing;
}
