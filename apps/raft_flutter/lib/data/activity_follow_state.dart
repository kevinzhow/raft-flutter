/// Source inboxStore's acknowledged thread follow state. The owner clears this
/// transient projection when its principal/server/capability scope retires.
class ActivityFollowState {
  final _states = <String, _AcknowledgedFollow>{};
  final _operations = <String, int>{};
  int _sequence = 0;
  bool get busy => _operations.isNotEmpty;

  int begin(String threadId) => _operations[threadId] = ++_sequence;
  bool accepts(String threadId, int ticket) => _operations[threadId] == ticket;
  void finish(String threadId, int ticket) {
    if (accepts(threadId, ticket)) _operations.remove(threadId);
  }

  void clear() {
    _states.clear();
    _operations.clear();
  }

  void acknowledge(Map<String, dynamic> row, {required bool following}) {
    final id = row['threadChannelId'];
    if (row['kind'] != 'thread' || id is! String) return;
    final previous = _states[id];
    _states[id] = _AcknowledgedFollow(
      following: following,
      clearedMessageId: following
          ? previous?.clearedMessageId
          : row['latestActivityMessageId'],
      clearedSeq: following ? previous?.clearedSeq : row['latestActivitySeq'],
    );
  }

  /// A delayed read cannot undo a successful mutation. The follow overlay ends
  /// when a response confirms it. The unread overlay applies only to the exact
  /// activity frontier cleared at ACK; genuinely newer activity stays visible.
  Map<String, dynamic> project(
    Map<String, dynamic> row, {
    bool reconcile = false,
  }) {
    final id = row['threadChannelId'];
    final state = row['kind'] == 'thread' ? _states[id] : null;
    if (state == null) return row;
    final sameActivity =
        state.clearedMessageId != null &&
        row['latestActivityMessageId'] == state.clearedMessageId &&
        row['latestActivitySeq'] == state.clearedSeq;
    final clearUnread = sameActivity && state.clearUnread;
    final result = <String, dynamic>{
      ...row,
      if (state.pendingFollow) 'isFollowing': state.following,
      'unfollowedAt': null,
      if (clearUnread) ...{
        'unreadCount': 0,
        'firstUnreadMessageId': null,
        'hasMention': false,
      },
    };
    if (reconcile) {
      if (row['isFollowing'] == state.following) state.pendingFollow = false;
      if (state.clearUnread &&
          (!sameActivity || (row['unreadCount'] as num? ?? 0) == 0)) {
        state.clearUnread = false;
      }
      if (!state.pendingFollow && !state.clearUnread) _states.remove(id);
    }
    return result;
  }

  Map<String, dynamic> window(Map value) {
    final items = (value['items'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    var cleared = 0;
    final projected = items.map((row) {
      final result = project(row, reconcile: true);
      cleared +=
          (row['unreadCount'] as num? ?? 0).toInt() -
          (result['unreadCount'] as num? ?? 0).toInt();
      return result;
    }).toList();
    return {
      ...Map<String, dynamic>.from(value),
      'items': projected,
      for (final key in ['totalUnreadCount', 'activeUnreadCount'])
        if (value[key] is num)
          key: ((value[key] as num).toInt() - cleared).clamp(0, 1 << 53),
    };
  }
}

class _AcknowledgedFollow {
  _AcknowledgedFollow({
    required this.following,
    this.clearedMessageId,
    this.clearedSeq,
  }) : clearUnread = clearedMessageId != null;
  final bool following;
  final Object? clearedMessageId, clearedSeq;
  bool pendingFollow = true;
  bool clearUnread;
}
