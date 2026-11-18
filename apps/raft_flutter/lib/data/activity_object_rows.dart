// Source: packages/shared/src/activityObjectsContract.ts and
// packages/web/src/store/{inboxStore,objectActivityRow}.ts at v1.24.0.
// `kind: "object"` rows ride in `/channels/inbox` items beside conversations.

import 'package:raft_client/raft_client.dart' show RaftEvent;
import 'package:raft_sync/raft_sync.dart' show ActivityChangedEvent;

/// Whether [row] is an object Activity row.
bool isActivityObjectRow(Map row) => row['kind'] == 'object';

bool isArtifactActivityRow(Map row) =>
    isActivityObjectRow(row) && row['objectKind'] == 'artifact';

String? objectActivityChangedServer(RaftEvent event) {
  if (event.name != ActivityChangedEvent.name) return null;
  return switch (ActivityChangedEvent.read(event.payload)) {
    ActivityChangedEvent(source: 'object', :final serverId)
        when serverId.isNotEmpty =>
      serverId,
    _ => null,
  };
}

/// Row key `object:<objectKind>:<objectId>` (Web `getInboxItemKey`).
String? activityObjectKey(Map row) {
  final kind = row['objectKind'], id = row['objectId'];
  return kind is String && kind.isNotEmpty && id is String && id.isNotEmpty
      ? 'object:$kind:$id'
      : null;
}

/// An object row shows read: no unread parts and no mention.
bool activityObjectRowIsRead(Map row) =>
    ((row['unreadCount'] as num?) ?? 0) == 0 && row['hasMention'] != true;

int _count(Object? value) => value is num && value >= 0 ? value.toInt() : 0;

/// The object counts of an inbox answer. They are never part of `totalCount`,
/// `totalUnreadCount` or `activeUnreadCount`; an answer without them (the
/// Artifacts flag off, a scoped empty) reads as 0, as Web does.
class ActivityObjectCounts {
  const ActivityObjectCounts({
    this.objectCount = 0,
    this.objectUnreadCount = 0,
    this.objectMentionUnreadCount = 0,
  });

  /// Object rows matching this request's filter.
  final int objectCount;

  /// Unread object rows over every page, any filter.
  final int objectUnreadCount;
  final int objectMentionUnreadCount;

  static const none = ActivityObjectCounts();

  factory ActivityObjectCounts.fromWindow(Object? window) {
    if (window is! Map) return none;
    return ActivityObjectCounts(
      objectCount: _count(window['objectCount']),
      objectUnreadCount: _count(window['objectUnreadCount']),
      objectMentionUnreadCount: _count(window['objectMentionUnreadCount']),
    );
  }

  /// Web `objectUnreadCountForFilter`: Mentions counts the mentioning rows,
  /// Unread+Mentions the listed ones, every other filter all unread rows.
  int unreadForFilter(String filter) => switch (filter) {
    'mentions' => objectMentionUnreadCount,
    'unread_mentions' => objectCount,
    _ => objectUnreadCount,
  };

  @override
  bool operator ==(Object other) =>
      other is ActivityObjectCounts &&
      other.objectCount == objectCount &&
      other.objectUnreadCount == objectUnreadCount &&
      other.objectMentionUnreadCount == objectMentionUnreadCount;
  @override
  int get hashCode =>
      Object.hash(objectCount, objectUnreadCount, objectMentionUnreadCount);
}
