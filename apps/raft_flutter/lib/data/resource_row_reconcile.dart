import 'package:raft_sync/raft_sync.dart' show canonicalUint64;

/// Source inboxStore getInboxItemKey: one row per conversation scope.
String? activityItemKey(Map row) {
  final kind = row['kind'];
  if (kind == 'mention_action') {
    final id = row['id'];
    return id is String && id.isNotEmpty ? 'mention_action:$id' : null;
  }
  final id = kind == 'thread' ? row['threadChannelId'] : row['channelId'];
  return kind is String && id is String && id.isNotEmpty ? '$kind:$id' : null;
}

/// The read/unread scope of an Activity row (thread rows read their thread).
String? activityScopeId(Map row) {
  final kind = row['kind'];
  if (kind == 'mention_action') return null;
  final id = kind == 'thread' ? row['threadChannelId'] : row['channelId'];
  return id is String && id.isNotEmpty ? id : null;
}

/// Every channel identity a row discloses (thread, parent and own channel).
Iterable<String> rowChannelIds(Map row) sync* {
  for (final field in ['channelId', 'parentChannelId', 'threadChannelId']) {
    final value = row[field];
    if (value is String && value.isNotEmpty) yield value;
  }
}

bool rowDeepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !rowDeepEquals(entry.value, b[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!rowDeepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Reuse the current row object wherever the accepted content is unchanged so
/// identity-fenced row actions, keyed elements and their state survive a
/// background reconcile.
List<Map<String, dynamic>> stabilizeRows(
  List<Map<String, dynamic>> next,
  List<Map<String, dynamic>> current,
  String? Function(Map row) keyOf,
) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final row in current) {
    final key = keyOf(row);
    if (key != null) byKey.putIfAbsent(key, () => row);
  }
  return [
    for (final row in next)
      switch (keyOf(row)) {
        final key? when byKey[key] != null && rowDeepEquals(byKey[key], row) =>
          byKey[key]!,
        _ => row,
      },
  ];
}

/// The newest activity frontier a row is known to contain.
BigInt? activityFrontier(Map row) {
  final frontier = row['readState'];
  final latest = frontier is Map ? frontier['latestActivity'] : null;
  final authority = latest is Map ? canonicalUint64(latest['seq']) : null;
  final display = canonicalUint64(row['latestActivitySeq']);
  if (authority == null) return display;
  if (display == null) return authority;
  return authority > display ? authority : display;
}

int _count(Object? value) => value is num ? value.toInt() : 0;

/// Result of reconciling an accepted first window with the rows on screen.
class ActivityReconcile {
  const ActivityReconcile(this.rows, this.unreadDelta);
  final List<Map<String, dynamic>> rows;

  /// Unread retained from newer local rows that the response predates.
  final int unreadDelta;
}

/// Source loadInbox background reset: keep newer locally received activity
/// (preserveNewerThreadActivity), keep the already loaded tail of the
/// unfiltered window (preserveLoadedInboxTail), de-duplicate by item key and
/// reuse unchanged row objects.
ActivityReconcile reconcileActivityWindow({
  required List<Map<String, dynamic>> incoming,
  required List<Map<String, dynamic>> current,
  required bool hasMore,
  required bool preserveTail,
  required Map<String, BigInt> localFrontiers,
  String? Function(Map row) keyOf = activityItemKey,
  bool newestFirst = true,
}) {
  final currentByKey = <String, Map<String, dynamic>>{};
  for (final row in current) {
    final key = keyOf(row);
    if (key != null) currentByKey.putIfAbsent(key, () => row);
  }
  var unreadDelta = 0;
  final refreshed = <Map<String, dynamic>>[], newer = <Map<String, dynamic>>[];
  for (final row in incoming) {
    final key = keyOf(row);
    final local = key == null ? null : localFrontiers[key];
    final existing = key == null ? null : currentByKey[key];
    if (local == null || existing == null) {
      if (key != null) localFrontiers.remove(key);
      refreshed.add(row);
      continue;
    }
    final served = activityFrontier(row);
    if (served != null && served >= local) {
      localFrontiers.remove(key);
      refreshed.add(row);
      continue;
    }
    // The response predates activity this client already presented.
    unreadDelta += _count(existing['unreadCount']) - _count(row['unreadCount']);
    (newestFirst ? newer : refreshed).add(existing);
  }
  if (newer.isNotEmpty) {
    // Keep the presented order of newer local rows ahead of the stale window
    // instead of moving them back down to their served position.
    newer.sort((a, b) => current.indexOf(a).compareTo(current.indexOf(b)));
    refreshed.insertAll(0, newer);
  }
  final seen = <String>{};
  final merged = <Map<String, dynamic>>[];
  void add(Map<String, dynamic> row) {
    final key = keyOf(row);
    if (key != null && !seen.add(key)) return;
    merged.add(row);
  }

  refreshed.forEach(add);
  if (preserveTail && hasMore && current.length > refreshed.length) {
    current.forEach(add);
  }
  return ActivityReconcile(stabilizeRows(merged, current, keyOf), unreadDelta);
}

/// Source applyReadStateProjection for a fully read scope: a read frontier at
/// or beyond the row's newest known activity clears its unread presentation.
/// Partial reads are left to the canonical reconcile.
Map<String, dynamic> projectFullyRead(
  Map<String, dynamic> row,
  BigInt? maxReadSeq,
) {
  if (maxReadSeq == null || _count(row['unreadCount']) == 0) return row;
  final latest = activityFrontier(row);
  if (latest == null || maxReadSeq < latest) return row;
  return {
    ...row,
    'unreadCount': 0,
    'firstUnreadMessageId': null,
    'firstMentionMessageId': null,
    'hasMention': false,
  };
}

String? _seqString(Object? value) => value is int && value >= 0
    ? '$value'
    : value is String && canonicalUint64(value) != null
    ? value
    : null;

/// Source receiveThreadReply, extended to channel/DM rows: a live message
/// strictly newer than the row's frontier advances that row's preview. Returns
/// null when the message does not advance any loaded row.
Map<String, dynamic>? advanceActivityRow(Map<String, dynamic> row, Map message) {
  final kind = row['kind'];
  if (kind == 'mention_action') return null;
  final id = message['id'], channel = message['channelId'];
  if (id is! String || channel is! String || activityScopeId(row) != channel) {
    return null;
  }
  final thread = kind == 'thread';
  if ((thread ? row['latestActivityMessageId'] : row['lastMessageId']) == id) {
    return null;
  }
  final incoming = _seqString(message['seq']);
  final current = activityFrontier(row);
  if (current != null) {
    // Fail closed: only a safe, strictly newer seq advances an activated row.
    final next = incoming == null ? null : canonicalUint64(incoming);
    if (next == null || next <= current) return null;
  }
  final senderName =
      message['senderName'] ??
      message['senderDisplayName'] ??
      (message['sender'] is Map
          ? (message['sender'] as Map)['displayName'] ??
                (message['sender'] as Map)['name']
          : null);
  final at = message['createdAt'];
  return {
    ...row,
    if (thread) ...{
      'latestActivityPreview': message['content'],
      'latestActivitySenderType': message['senderType'],
      'latestActivitySenderId': message['senderId'],
      'latestActivitySenderName': senderName,
      'latestActivityMessageId': id,
      'replyCount': _count(row['replyCount']) + 1,
      'lastActivityAt': ?at,
      'lastReplyAt': ?at,
    } else ...{
      'lastMessagePreview': message['content'],
      'lastMessageSenderType': message['senderType'],
      'lastMessageSenderId': message['senderId'],
      'lastMessageSenderName': senderName,
      'lastMessageId': id,
      'lastMessageAt': ?at,
    },
    'latestActivitySeq': incoming ?? row['latestActivitySeq'],
  };
}
