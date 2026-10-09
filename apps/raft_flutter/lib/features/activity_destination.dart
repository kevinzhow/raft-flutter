import '../data/raft_location.dart';

/// Pinned ThreadsInbox1036–1075 canonical and1111–1184 single-open contracts.
/// This owns DTO identity selection only; the mounted workspace owns history,
/// request authority and content presentation.
class ActivityDestination {
  const ActivityDestination({
    required this.channelId,
    required this.dm,
    this.messageId,
    this.parentMessageId,
    this.threadChannelId,
  });
  final String channelId;
  final bool dm;
  final String? messageId, parentMessageId, threadChannelId;
  bool get thread => parentMessageId != null;

  static String? _id(dynamic value) =>
      value is String && value.isNotEmpty ? value : null;

  static ActivityDestination? fromRow(
    Map<String, dynamic> row, {
    required bool canonical,
    bool mobile = false,
  }) {
    final unread = (row['unreadCount'] as num? ?? 0) > 0;
    if (row['kind'] == 'thread') {
      final channel = _id(row['parentChannelId']),
          parent = _id(row['parentMessageId']),
          thread = _id(row['threadChannelId']);
      if (channel == null || parent == null || thread == null) return null;
      final single = unread
          ? _id(row['firstUnreadMessageId']) ??
                _id(row['latestActivityMessageId'])
          : _id(row['latestActivityMessageId']);
      return ActivityDestination(
        channelId: channel,
        dm: row['parentChannelType'] == 'dm',
        parentMessageId: parent,
        threadChannelId: thread,
        messageId: canonical
            ? _id(row['firstMentionMessageId']) ?? single
            : single,
      );
    }
    final channel = _id(row['channelId']);
    if (channel == null) return null;
    if (row['kind'] == 'mention_action') {
      return ActivityDestination(
        channelId: channel,
        // Source's single-open mention action uses channel, even on mobile;
        // double activation chooses the actual channelType.
        dm: canonical && row['channelType'] == 'dm',
        messageId: _id(row['messageId']),
      );
    }
    if (!{'channel', 'dm'}.contains(row['kind'])) return null;
    final single = unread
        ? _id(row['firstUnreadMessageId']) ?? _id(row['lastMessageId'])
        : _id(row['lastMessageId']);
    return ActivityDestination(
      channelId: channel,
      dm: row['kind'] == 'dm',
      messageId: canonical
          ? _id(row['firstUnreadMessageId']) ?? _id(row['lastMessageId'])
          : mobile
          ? _id(row['firstMentionMessageId']) ?? single
          : single,
    );
  }

  RaftLocation canonicalLocation(String slug) => RaftLocation.at(
    serverSlug: slug,
    route: dm ? RaftRoute.dm : RaftRoute.channel,
    entityId: channelId,
    query: {
      if (thread) 'thread': '$channelId:$parentMessageId',
      'msg': ?messageId,
    },
  );
}
