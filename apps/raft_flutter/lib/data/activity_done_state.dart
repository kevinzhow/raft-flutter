import 'package:raft_sync/raft_sync.dart' show canonicalUint64, maxSafeInteger;

/// Marker-bound pending Done bridge from Source inboxStore. Its lifetime ends
/// after the owned reconciliation; it is never persisted as a completed fact.
class ActivityDoneState {
  final _requests = <String, int>{};
  final _markers = <String, String>{};
  int _sequence = 0;
  DateTime? _until;

  static String? key(Map row) {
    final kind = row['kind'];
    if (kind == 'mention_action') return null;
    final id = kind == 'thread' ? row['threadChannelId'] : row['channelId'];
    return id is String && id.isNotEmpty ? '$kind:$id' : null;
  }

  /// Normalize row evidence from the authority union, using the shared uint64
  /// parser and the ledger's safe-number boundary. Display/storage frontiers
  /// cannot substitute for absent, corrupt or incomplete read-state evidence.
  static String? marker(Map row) {
    final frontier = row['readState'];
    if (frontier is! Map || frontier['kind'] != 'present') return null;
    final read = canonicalUint64(frontier['maxReadSeq']);
    final version = frontier['readStateVersion'];
    final latest = frontier['latestActivity'];
    if (read == null ||
        read > BigInt.from(maxSafeInteger) ||
        version is! int ||
        version < 0 ||
        version > maxSafeInteger ||
        latest is! Map ||
        latest['messageId'] is! String ||
        (latest['messageId'] as String).isEmpty ||
        canonicalUint64(latest['seq']) == null) {
      return null;
    }
    return latest['seq'] as String;
  }

  int begin(Map row, DateTime now) {
    final id = key(row)!;
    final ticket = _requests[id] = ++_sequence;
    final latest = marker(row);
    if (latest != null) {
      _markers[id] = latest;
      final expiry = now.add(const Duration(seconds: 30));
      if (_until == null || expiry.isAfter(_until!)) _until = expiry;
    }
    return ticket;
  }

  bool accepts(String key, int ticket) => _requests[key] == ticket;
  void disarm(String key, int ticket) {
    if (accepts(key, ticket)) _markers.remove(key);
  }

  void finish(String key, int ticket) {
    if (!accepts(key, ticket)) return;
    _markers.remove(key);
    _requests.remove(key);
  }

  void clear() {
    _requests.clear();
    _markers.clear();
    _until = null;
  }

  static List<Map<String, dynamic>> groups(
    List<Map<String, dynamic>> groups,
    List<Map<String, dynamic>> removed,
    String? selected,
  ) => groups.expand((group) {
    final count = removed
        .where(
          (row) =>
              (row['kind'] == 'thread'
                  ? row['parentChannelId']
                  : row['channelId']) ==
              group['channelId'],
        )
        .length;
    if (count == 0) return [group];
    final next = ((group['count'] as num? ?? 0).toInt() - count).clamp(
      0,
      1 << 53,
    );
    return next > 0 || group['channelId'] == selected
        ? [
            {...group, 'count': next},
          ]
        : <Map<String, dynamic>>[];
  }).toList();

  Map<String, dynamic> window(
    Map value,
    DateTime now, {
    String? selectedChannelId,
  }) {
    if (_until != null && now.isAfter(_until!)) {
      _markers.clear();
      _until = null;
    }
    final kept = <Map<String, dynamic>>[], removed = <Map<String, dynamic>>[];
    for (final entry
        in (value['items'] as List? ?? const []).whereType<Map>()) {
      final row = Map<String, dynamic>.from(entry), id = key(entry);
      if (id != null &&
          _markers.containsKey(id) &&
          _markers[id] == marker(entry)) {
        removed.add(row);
      } else {
        if (id != null) _markers.remove(id);
        kept.add(row);
      }
    }
    final unread = removed.fold<int>(
      0,
      (sum, row) => sum + (row['unreadCount'] as num? ?? 0).toInt(),
    );
    return {
      ...Map<String, dynamic>.from(value),
      'items': kept,
      for (final field in [
        'totalCount',
        'total',
        'allCount',
        'unfilteredCount',
      ])
        if (value[field] is num)
          field: ((value[field] as num).toInt() - removed.length).clamp(
            0,
            1 << 53,
          ),
      for (final field in ['totalUnreadCount', 'activeUnreadCount'])
        if (value[field] is num)
          field: ((value[field] as num).toInt() - unread).clamp(0, 1 << 53),
      if (value['groups'] is List)
        'groups': groups(
          (value['groups'] as List)
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList(),
          removed,
          selectedChannelId,
        ),
    };
  }
}
