// Source: packages/web/src/store/inboxInPlaceUnread.ts at v1.24.0-source.1
// Source: packages/web/src/store/applyReadStateUpdate.ts at v1.24.0-source.1
// Source: packages/web/src/store/inboxStore.ts at v1.24.0-source.1
//   (receiveThreadReply, receiveChannelMessage, preserveNewer*Activity)
import 'package:raft_sync/raft_sync.dart'
    show canonicalUint64, canonicalWireSeq;

import 'inbox_counted_ids.dart';
import 'resource_row_reconcile.dart';

/// What a live message does to its row's unread, decided where it arrives
/// (Web `InboxLiveUnread`): one more unread (not the person's own, not read on
/// screen, not already read), and whether it @-mentions the person.
class LiveUnread {
  const LiveUnread({required this.counts, required this.mention, this.viewer});
  final bool counts, mention;

  /// The person reading (a system line they caused does not count on a thread).
  final String? viewer;
}

/// `POST /feature-flags/evaluate` key of Web step 3a (server-scoped, default off).
const inboxReadInplaceFlagKey = 'inbox_read_inplace_v1';

/// The unread fields a live message moves on a row.
const inPlaceUnreadKeys = [
  'unreadCount',
  'hasMention',
  'firstUnreadMessageId',
  'firstMentionMessageId',
];

int _count(Object? value) => value is num ? value.toInt() : 0;

/// The unread fields of a row, for a served row still behind one patched in
/// place (Web `inPlaceUnreadOf`).
Map<String, dynamic> inPlaceUnreadOf(Map row) => {
  for (final key in inPlaceUnreadKeys) key: row[key],
};

// The followed-thread unread rule: these system lines never count.
const _uncountedThreadSystemSubtypes = {
  'channel.self_unfollow_thread',
  'task.deleted_summary',
};

/// Does a system message count on a thread row? As the server counts it: yes,
/// unless the person caused it or it is one of the uncounted subtypes; never on
/// a task conversation's row. A message without its provenance
/// (`systemSubtype` absent, not null) cannot be judged and does not count (the
/// re-read brings the server's count).
bool threadSystemMessageCounts(Map row, Map message, String? viewer) {
  if (row['conversationKind'] == 'task') return false;
  if (!message.containsKey('systemSubtype')) return false;
  final subtype = message['systemSubtype'];
  if (subtype is String && _uncountedThreadSystemSubtypes.contains(subtype)) {
    return false;
  }
  return !(message['causalActorType'] == 'user' &&
      viewer != null &&
      message['causalActorId'] == viewer);
}

/// The unread fields of a row a live message advanced (Web
/// `liveUnreadFields`). An unfollowed thread row counts nothing, and a thread
/// row or reply without a seq is left to the re-read.
Map<String, dynamic> liveUnreadFields(Map row, Map message, LiveUnread? live) {
  if (live == null || !live.counts) return const {};
  if (row['kind'] == 'thread' &&
      (row['isFollowing'] == false ||
          row['latestActivitySeq'] == null ||
          canonicalWireSeq(message['seq']) == null)) {
    return const {};
  }
  final counts =
      !(row['kind'] == 'thread' &&
          message['messageType'] == 'system' &&
          !threadSystemMessageCounts(row, message, live.viewer));
  final unread = _count(row['unreadCount']);
  return {
    if (counts) 'unreadCount': unread + 1,
    if (counts && unread == 0) 'firstUnreadMessageId': message['id'],
    if (live.mention) 'hasMention': true,
    if (live.mention && row['hasMention'] != true)
      'firstMentionMessageId': message['id'],
  };
}

/// A live message at or below its row's seq (it came after a newer one): the
/// unread fields to apply when the row has not counted it since its last served
/// answer, else null. Only the unread fields: preview, order and seq stay.
Map<String, dynamic>? lateLiveUnreadFields(
  Map row,
  Map message,
  LiveUnread? live,
  InboxCountedIds counted, {
  BigInt? readSeq,
}) {
  final scope = activityScopeId(row), id = message['id'];
  final seq = canonicalWireSeq(message['seq']);
  if (live == null ||
      scope == null ||
      id is! String ||
      seq == null ||
      !counted.isLateUncounted(scope, id, seq)) {
    return null;
  }
  // Read already (another device's read, accepted here).
  if (readSeq != null && seq <= readSeq) return null;
  final fields = liveUnreadFields(row, message, live);
  return fields.isEmpty ? null : fields;
}

/// Web `readPersistedSkipsReread` (step 3a, `inbox_read_inplace_v1`): a
/// persisted read of a listed row that still shows the read sends no re-read.
/// Needs the flag on, a settled list and the row listed with no unread. A row
/// not listed, or one showing unread again, re-reads as before.
bool readPersistedSkipsReread(
  Iterable<Map> items,
  String scopeId, {
  required bool listSettled,
  required bool flagOn,
}) {
  final row = items.where((r) => activityScopeId(r) == scopeId).firstOrNull;
  if (row == null) return false;
  return flagOn && listSettled && _count(row['unreadCount']) == 0;
}

/// Web `clearActivityRowReadThrough`: a read this client cannot project (the
/// conversation's messages are not loaded here: read on another device) still
/// clears its Activity row when it covers the row's latest message. Covered =
/// the row's read-state frontier (the cursor's seq domain) and its display
/// seq, which a live reply advances, are both at or below the read. A row with
/// a newer message, or a read the server says leaves some unread, keeps its
/// count for the re-read. Returns the cleared row, or null when unchanged.
Map<String, dynamic>? clearedByReadThrough(
  Map<String, dynamic> row, {
  required BigInt maxReadSeq,
  required bool markedUnread,
  int? unreadCount,
}) {
  if (markedUnread || (unreadCount ?? 0) > 0) return null;
  if (row['kind'] == 'mention_action') return null;
  final frontier = row['readState'];
  final latest = frontier is Map && frontier['latestActivity'] is Map
      ? canonicalUint64((frontier['latestActivity'] as Map)['seq'])
      : null;
  final display = canonicalUint64(row['latestActivitySeq']);
  if (latest == null || display == null) return null;
  if (latest > maxReadSeq || display > maxReadSeq) return null;
  if (_count(row['unreadCount']) == 0 &&
      row['hasMention'] != true &&
      row['firstUnreadMessageId'] == null &&
      row['firstMentionMessageId'] == null) {
    return null;
  }
  return {
    ...row,
    'unreadCount': 0,
    'hasMention': false,
    'firstUnreadMessageId': null,
    'firstMentionMessageId': null,
  };
}

/// Result of applying a live message to one list of rows.
typedef InPlaceApplied = ({List<Map<String, dynamic>> rows, int delta});

/// The in-place unread state of one Activity window owner: the counted-ids
/// ledger and the local high-water that keeps a served row still behind a row
/// patched in place from flickering its unread back (Web
/// `inboxChannelActivityHighWater` / `inboxThreadActivityHighWater`).
class InboxInPlaceUnread {
  /// The stale-list bound (Web INBOX_LOCAL_MUTATION_HOLD_MS): an answer later
  /// than this is not lag any more.
  static const hold = Duration(seconds: 90);

  final counted = InboxCountedIds();
  final _highWater = <String, ({BigInt seq, DateTime until, bool counts})>{};

  void reset() {
    counted.reset();
    _highWater.clear();
  }

  /// Patches [message]'s row of [rows] in place (Web `receiveChannelMessage` /
  /// `receiveThreadReply`). Null when no loaded row is touched. The caller
  /// patches every list it shows, then calls [noteApplied] once.
  InPlaceApplied? apply(
    List<Map<String, dynamic>> rows,
    Map message,
    LiveUnread live, {
    required DateTime now,
    BigInt? readSeq,
    bool newestFirst = true,
  }) {
    final scope = message['channelId'], id = message['id'];
    final incoming = canonicalWireSeq(message['seq']);
    if (scope is! String || id is! String || incoming == null) return null;
    final at = rows.indexWhere(
      (row) => row['kind'] != 'mention_action' && activityScopeId(row) == scope,
    );
    if (at < 0) return null;
    final row = rows[at];
    final current = canonicalUint64(row['latestActivitySeq']);
    if (current == null) return null;
    if (incoming <= current) {
      final late = lateLiveUnreadFields(
        row,
        message,
        live,
        counted,
        readSeq: readSeq,
      );
      if (late == null) return null;
      final next = {...row, ...late};
      final local = _highWater[scope];
      if (local != null &&
          local.seq == current &&
          _count(next['unreadCount']) > _count(row['unreadCount'])) {
        _highWater[scope] = (seq: local.seq, until: local.until, counts: true);
      }
      return (
        rows: [...rows]..[at] = next,
        delta: _count(next['unreadCount']) - _count(row['unreadCount']),
      );
    }
    final advanced = advanceActivityRow(row, message);
    if (advanced == null) return null;
    final next = {...advanced, ...liveUnreadFields(row, message, live)};
    _highWater[scope] = (
      seq: incoming,
      until: now.add(hold),
      counts: live.counts || _highWater[scope]?.counts == true,
    );
    final moved = newestFirst
        ? [next, ...rows.take(at), ...rows.skip(at + 1)]
        : ([...rows]..[at] = next);
    return (
      rows: moved,
      delta: _count(next['unreadCount']) - _count(row['unreadCount']),
    );
  }

  /// A live message was applied to its row(s). False when the row's counted
  /// set is full: ask for a re-read.
  bool noteApplied(Map message) {
    final scope = message['channelId'], id = message['id'];
    final seq = canonicalWireSeq(message['seq']);
    if (scope is! String || id is! String || seq == null) return true;
    return counted.noteCounted(scope, id, seq);
  }

  /// A served window ([served]) over the rows shown ([current]): a served row
  /// still behind a row patched in place stays as the live message left it,
  /// with its unread, and where it put it (Web `preserveNewer*Activity` with
  /// `inPlaceUnreadOf`). Returns the rows and the unread they add over [served].
  ({List<Map<String, dynamic>> rows, int delta}) keepAhead(
    List<Map<String, dynamic>> served,
    List<Map<String, dynamic>> current, {
    required DateTime now,
    bool newestFirst = true,
  }) {
    if (_highWater.isEmpty) return (rows: served, delta: 0);
    final shown = {for (final row in current) ?activityScopeId(row): row};
    var delta = 0;
    final kept = <Map<String, dynamic>>[];
    final rows = [
      for (final row in served)
        () {
          final scope = row['kind'] == 'mention_action'
              ? null
              : activityScopeId(row);
          final local = scope == null ? null : _highWater[scope];
          if (local == null) return row;
          final here = shown[scope];
          final seen = canonicalUint64(row['latestActivitySeq']);
          if (here == null ||
              canonicalUint64(here['latestActivitySeq']) != local.seq ||
              now.isAfter(local.until) ||
              seen == null ||
              seen >= local.seq) {
            _highWater.remove(scope);
            return row;
          }
          // The row as the live message left it (preview, seq, order), over
          // the served frontier; the unread is the local one only if the
          // message counted.
          final next = {
            ...here,
            if (row.containsKey('readState')) 'readState': row['readState'],
            if (!local.counts) ...inPlaceUnreadOf(row),
          };
          delta += _count(next['unreadCount']) - _count(row['unreadCount']);
          kept.add(next);
          return next;
        }(),
    ];
    if (!newestFirst || kept.isEmpty) return (rows: rows, delta: delta);
    return (
      rows: [
        ...rows.where(kept.contains),
        ...rows.where((row) => !kept.contains(row)),
      ],
      delta: delta,
    );
  }
}
