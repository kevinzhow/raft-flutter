/// Receiver-visible message projections. Channel seq is sparse (server-wide
/// sequence); missing adjacent values do not imply a missing channel message.
library;

export 'src/core.dart';
export 'src/read_state.dart';
export 'src/reaction_viewer.dart';
export 'src/messages.dart';
export 'src/thread_replies.dart';
export 'src/notification_prefs.dart';

import 'src/messages.dart';

/// One mutation a reader can apply without walking the retained history.
///
/// A null [messageId] clears every row recorded for [channelId].
class MessageLedgerChange {
  const MessageLedgerChange({
    required this.revision,
    required this.channelId,
    this.messageId,
    this.removed = false,
  });

  final int revision;
  final String channelId;
  final String? messageId;
  final bool removed;
}

class MessageLedger {
  /// Incremental mutations kept for readers. Past this, the record is dropped
  /// and the next reader rebuilds from the current rows.
  static const int incrementalChangeLimit = 1000;

  String? _serverId;
  int generation = 0;

  /// Bumped on every content change, so readers can cache derived views.
  int revision = 0;
  BigInt watermark = BigInt.zero;
  final Map<String, Map<String, Map<String, dynamic>>> _channels = {};
  final Map<String, List<Map<String, dynamic>>> _sorted = {};
  final _sortDirty = <String, Set<String>>{};
  final _sortSequences = Expando<BigInt>();
  final Map<String, DateTime?> _latestCreatedAt = {};
  final _releasedLatest = <String, (String, DateTime)>{};
  final List<MessageLedgerChange> _changes = [];

  /// Revisions at or below this floor are not described incrementally.
  int _changeFloor = 0;

  /// Highest revision a discarding reader has finished applying.
  ///
  /// Null until the first [discardChangesThrough]. Readers registered with
  /// [noteChangesRead] keep every later revision until they catch up.
  int? _finishedThrough;

  /// Revision each holding reader has applied, keyed by that reader's identity.
  final Map<Object, int> _readThrough = {};

  /// Retained incremental mutations. Stays at or below [incrementalChangeLimit].
  int get debugChangeCount => _changes.length;
  String? get serverId => _serverId;
  Iterable<String> get channelIds => List.unmodifiable(_channels.keys);
  void switchServer(String? id) {
    if (_serverId == id) return;
    _serverId = id;
    generation++;
    revision++;
    watermark = BigInt.zero;
    _channels.clear();
    _sorted.clear();
    _sortDirty.clear();
    _latestCreatedAt.clear();
    _releasedLatest.clear();
    _changes.clear();
    _changeFloor = revision;
  }

  /// Mutations with a revision greater than [since], in apply order.
  ///
  /// Null means [since] is outside the retained window, including after a
  /// server switch or when the unread record passed [incrementalChangeLimit].
  /// The caller rebuilds from the current rows in that case.
  List<MessageLedgerChange>? changesAfter(int since) {
    if (since < _changeFloor || since > revision) return null;
    var start = 0;
    while (start < _changes.length && _changes[start].revision <= since) {
      start++;
    }
    if (start == _changes.length) return const [];
    if (start == 0) return List<MessageLedgerChange>.unmodifiable(_changes);
    return List<MessageLedgerChange>.unmodifiable(_changes.sublist(start));
  }

  /// Drops revisions at or below [through] once every holding reader has
  /// applied them.
  ///
  /// A reader registered with [noteChangesRead] keeps a revision it has not
  /// applied. Past [incrementalChangeLimit] the whole record is still dropped
  /// and every reader rebuilds.
  void discardChangesThrough(int through) {
    if (_finishedThrough == null || through > _finishedThrough!) {
      _finishedThrough = through;
    }
    _trimShared();
  }

  /// Records that [reader] has applied every revision at or below [through].
  ///
  /// The key is the reader's identity. A higher revision replaces a lower one.
  /// This does not discard by itself; it releases the hold so a previous or
  /// later [discardChangesThrough] can move forward.
  void noteChangesRead(Object reader, int through) {
    final current = _readThrough[reader];
    if (current != null && through <= current) return;
    _readThrough[reader] = through;
    _trimShared();
  }

  void _trimShared() {
    final finished = _finishedThrough;
    if (finished == null) return;
    var through = finished;
    for (final read in _readThrough.values) {
      if (read < through) through = read;
    }
    _dropThrough(through);
  }

  /// Drops the incremental record of revisions at or below [through].
  void _dropThrough(int through) {
    if (through <= _changeFloor) return;
    _changeFloor = through;
    var start = 0;
    while (start < _changes.length && _changes[start].revision <= through) {
      start++;
    }
    if (start > 0) _changes.removeRange(0, start);
  }

  BigInt _orderSequence(Map<String, dynamic> row) =>
      _sortSequences[row] ??= _seq(row);

  int _compareRows(Map<String, dynamic> a, Map<String, dynamic> b) {
    final order = _orderSequence(a).compareTo(_orderSequence(b));
    return order != 0
        ? order
        : (a['id'] as String).compareTo(b['id'] as String);
  }

  List<Map<String, dynamic>> messages(String channelId) {
    var sorted = _sorted[channelId];
    final dirty = _sortDirty.remove(channelId);
    if (sorted == null) {
      sorted =
          _channels[channelId]?.values.toList() ?? <Map<String, dynamic>>[];
      sorted.sort(_compareRows);
      _sorted[channelId] = sorted;
    } else if (dirty != null && dirty.isNotEmpty) {
      // Sort only changed versions, then merge with the retained order. A
      // fifty-row page must not reparse and sort the entire loaded history.
      final changed = <Map<String, dynamic>>[
        for (final id in dirty)
          if (_channels[channelId]?[id] case final row?) row,
      ]..sort(_compareRows);
      final next = <Map<String, dynamic>>[];
      var at = 0;
      for (final row in sorted) {
        if (dirty.contains(row['id'])) continue;
        while (at < changed.length && _compareRows(changed[at], row) < 0) {
          next.add(changed[at++]);
        }
        next.add(row);
      }
      next.addAll(changed.skip(at));
      _sorted[channelId] = sorted = next;
    }
    // Callers own the returned list; the cached order stays private.
    return List.of(sorted);
  }

  /// Latest valid creation timestamp among the held channel messages.
  ///
  /// This follows dates rather than sparse sequence order. Missing and invalid
  /// dates do not contribute; server timestamps remain the authority. Results
  /// (including null) are reused until this channel changes, so responsive
  /// rebuilds do not repeatedly copy, sort and parse the held history.
  DateTime? latestCreatedAt(String channelId) {
    if (_latestCreatedAt.containsKey(channelId)) {
      return _latestCreatedAt[channelId];
    }
    final messages = _channels[channelId];
    if (messages == null) return null;
    DateTime? latest = _releasedLatest[channelId]?.$2;
    for (final message in messages.values) {
      final stamp = DateTime.tryParse('${message['createdAt'] ?? ''}');
      if (stamp != null && (latest == null || stamp.isAfter(latest))) {
        latest = stamp;
      }
    }
    _latestCreatedAt[channelId] = latest;
    return latest;
  }

  /// Whether [messageId] is held for [channelId], without copying or sorting.
  bool contains(String channelId, String messageId) =>
      _channels[channelId]?.containsKey(messageId) ?? false;

  /// The held row for [messageId], without copying or sorting the channel.
  Map<String, dynamic>? message(String channelId, String messageId) =>
      _channels[channelId]?[messageId];

  void _changed(
    String channelId, {
    String? messageId,
    bool removed = false,
    bool clearChannel = false,
  }) {
    revision++;
    if (clearChannel || messageId == null) {
      _sorted.remove(channelId);
      _sortDirty.remove(channelId);
    } else if (_sorted.containsKey(channelId)) {
      _sortDirty.putIfAbsent(channelId, () => {}).add(messageId);
    }
    _latestCreatedAt.remove(channelId);
    _remember(
      MessageLedgerChange(
        revision: revision,
        channelId: channelId,
        messageId: clearChannel ? null : messageId,
        removed: removed || clearChannel,
      ),
    );
  }

  void _remember(MessageLedgerChange change) {
    if (_changes.length >= incrementalChangeLimit) {
      _changes.clear();
      _changeFloor = revision;
      return;
    }
    _changes.add(change);
  }

  static BigInt _seq(Map<String, dynamic> m) =>
      BigInt.tryParse('${m['seq']}') ?? BigInt.zero;
  bool ingest(
    Iterable<Map<String, dynamic>> messages, {
    required int expectedGeneration,
    bool complete = false,
  }) {
    if (expectedGeneration != generation || _serverId == null) return false;
    for (final message in messages) {
      final id = message['id'], channelId = message['channelId'];
      if (id is! String || channelId is! String) continue;
      final bucket = _channels[channelId] ??= {};
      bucket[id] = complete
          ? Map<String, dynamic>.from(message)
          : mergeMessageProjection(bucket[id], message);
      _changed(channelId, messageId: id);
      final seq = _seq(message);
      if (seq > watermark) watermark = seq;
    }
    return true;
  }

  /// Socket task/status updates are merge-only; they cannot create a message.
  bool ingestUpdate(
    Map<String, dynamic> message, {
    required int expectedGeneration,
  }) {
    if (expectedGeneration != generation || _serverId == null) return false;
    final id = message['id'], channelId = message['channelId'];
    if (id is! String ||
        channelId is! String ||
        _channels[channelId]?[id] == null) {
      return false;
    }
    _channels[channelId]![id] = mergeMessageProjection(
      _channels[channelId]![id],
      message,
    );
    _changed(channelId, messageId: id);
    return true;
  }

  void remove(String channelId, String messageId) {
    _channels[channelId]?.remove(messageId);
    if (_releasedLatest[channelId]?.$1 == messageId) {
      _releasedLatest.remove(channelId);
    }
    _changed(channelId, messageId: messageId, removed: true);
  }

  /// Drops reconstructable bodies without moving the receiver's generation,
  /// sequence watermark or last known channel timestamp.
  void releaseBodies(String channelId, Set<String> ids) {
    final rows = _channels[channelId];
    if (rows == null || !ids.any(rows.containsKey)) return;
    for (final id in ids) {
      final stamp = DateTime.tryParse('${rows[id]?['createdAt'] ?? ''}');
      if (stamp != null &&
          (_releasedLatest[channelId] == null ||
              stamp.isAfter(_releasedLatest[channelId]!.$2))) {
        _releasedLatest[channelId] = (id, stamp);
      }
    }
    latestCreatedAt(channelId);
    final removed = [
      for (final id in ids)
        if (rows.containsKey(id)) id,
    ];
    rows.removeWhere((id, _) => ids.contains(id));
    if (rows.isEmpty) _channels.remove(channelId);
    _sorted.remove(channelId);
    _sortDirty.remove(channelId);
    revision++;
    for (final id in removed) {
      _remember(
        MessageLedgerChange(
          revision: revision,
          channelId: channelId,
          messageId: id,
          removed: true,
        ),
      );
    }
  }

  void revokeChannel(String id) {
    _channels.remove(id);
    _releasedLatest.remove(id);
    _changed(id, clearChannel: true);
  }
}
