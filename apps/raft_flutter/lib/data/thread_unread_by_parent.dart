import 'package:flutter/foundation.dart';

/// Web `utils/threadUnreadByParent.ts`: followed-thread unread folded onto one
/// parent channel. Never part of the channel's own unread count.
@immutable
class ParentThreadUnread {
  const ParentThreadUnread(this.count, this.hasMention);
  static const none = ParentThreadUnread(0, false);

  /// Followed threads under the channel with unread replies (threads, not
  /// replies).
  final int count;

  /// One of those threads has an unread reply that mentions the member.
  final bool hasMention;

  @override
  bool operator ==(Object other) =>
      other is ParentThreadUnread &&
      other.count == count &&
      other.hasMention == hasMention;

  @override
  int get hashCode => Object.hash(count, hasMention);
}

num _unread(Map<String, dynamic> row) {
  final value = row['unreadCount'];
  return value is num ? value : 0;
}

/// Followed-thread unread of every parent channel, in one pass over [threads].
Map<String, ParentThreadUnread> groupThreadUnreadByParent(
  Iterable<Map<String, dynamic>> threads,
) {
  final byParent = <String, ParentThreadUnread>{};
  for (final thread in threads) {
    final parent = thread['parentChannelId'];
    if (parent is! String || _unread(thread) <= 0) continue;
    final current = byParent[parent];
    byParent[parent] = ParentThreadUnread(
      (current?.count ?? 0) + 1,
      current?.hasMention == true || thread['hasMention'] == true,
    );
  }
  return byParent;
}

double _positionTime(Map<String, dynamic> thread) {
  // An older server does not send the parent's time: fall back to the latest
  // reply (the old order). No usable time sorts last.
  final time = DateTime.tryParse(
    '${thread['parentMessageCreatedAt'] ?? thread['lastReplyAt'] ?? ''}',
  );
  return time == null
      ? double.infinity
      : time.millisecondsSinceEpoch.toDouble();
}

/// Unread followed threads of [parentChannelId] in jump order: top to bottom as
/// the channel shows them, by parent message time (earliest parent first), so
/// "Earliest" lands on the topmost and "Next" moves down. Mentions get no
/// priority (the sidebar's @ mark already surfaces them).
List<Map<String, dynamic>> orderParentUnreadThreadsForJump(
  Iterable<Map<String, dynamic>> threads,
  String parentChannelId,
) {
  final matching = [
    for (final thread in threads)
      if (thread['parentChannelId'] == parentChannelId && _unread(thread) > 0)
        thread,
  ];
  // Stable for equal times: Dart's sort is not, so index breaks ties.
  final order = {for (var i = 0; i < matching.length; i++) matching[i]: i};
  matching.sort((a, b) {
    final c = _positionTime(a).compareTo(_positionTime(b));
    return c != 0 ? c : order[a]!.compareTo(order[b]!);
  });
  return matching;
}
