import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

/// Source `messageGrouping.ts` computeMessageGrouping: [message] continues
/// [previous]'s sender group when both are chat rows from the same sender on
/// the same calendar day and neither is [standalone] (a thread reply or a task
/// renders on its own with its own header).
bool messageContinuesGroup(
  RaftMessage? previous,
  RaftMessage message, {
  required String Function(DateTime) dayKey,
  required bool Function(RaftMessage) standalone,
}) {
  if (previous == null) return false;
  if (previous.string('messageType') == 'system' ||
      message.string('messageType') == 'system') {
    return false;
  }
  final before = previous.createdAt, now = message.createdAt;
  if (before == null || now == null || dayKey(before) != dayKey(now)) {
    return false;
  }
  if (standalone(previous) || standalone(message)) return false;
  return previous.string('senderType') == message.string('senderType') &&
      previous.string('senderId') == message.string('senderId');
}

/// Source `messageGrouping.ts` followedByFor: the kind of row that follows
/// [message] (a system note always breaks the run), null at the list end. The
/// row writes it as `data-followed-by` for the rhythm of its bottom padding.
RaftMessageFollowedBy? messageFollowedBy(
  RaftMessage message,
  RaftMessage? following, {
  required String Function(DateTime) dayKey,
  required bool Function(RaftMessage) standalone,
}) {
  if (following == null) return null;
  if (following.string('messageType') == 'system') {
    return RaftMessageFollowedBy.group;
  }
  return messageContinuesGroup(
        message,
        following,
        dayKey: dayKey,
        standalone: standalone,
      )
      ? RaftMessageFollowedBy.compact
      : RaftMessageFollowedBy.group;
}
