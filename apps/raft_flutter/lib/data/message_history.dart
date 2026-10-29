import 'dart:collection';
import 'dart:async';
import 'dart:convert';

import 'package:raft_sync/raft_sync.dart' show mergeMessageProjection;
import 'package:raft_ui/raft_ui.dart' show RaftIdleTimer;

import 'history_read_policy.dart';
import 'history_capacity.dart';
import 'history_memory.dart';
import 'reading_positions.dart';
import 'history_gaps.dart';

/// Receiver authority for persisted rows. A saved role never grants access.
class MessageHistoryScope {
  const MessageHistoryScope({
    required this.origin,
    required this.principal,
    required this.server,
    required this.channel,
    required this.parentChannel,
    required this.authority,
    this.parentMessage,
  });
  final String origin, principal, server, channel, parentChannel, authority;
  final String? parentMessage;
  List<String> get key => [origin, principal, server, channel];
}

/// Fixed-width decimal keys preserve unsigned 64-bit ordering on every host.
String historySequenceKey(Object? value) {
  if (value is int && (value < 0 || value > 9007199254740991)) {
    throw const FormatException('Message sequence must be an exact decimal.');
  }
  final text = '$value';
  if (!RegExp(r'^(0|[1-9][0-9]{0,19})$').hasMatch(text)) {
    throw const FormatException('Invalid unsigned message sequence.');
  }
  final sequence = BigInt.parse(text);
  if (sequence > historyMaxSequence) {
    throw const FormatException('Message sequence exceeds uint64.');
  }
  return text.padLeft(20, '0');
}

final historyMaxSequence = (BigInt.one << 64) - BigInt.one;

/// A completed local page, including its proven older boundary.
class LocalMessageHistoryPage {
  LocalMessageHistoryPage(
    Iterable<Map<String, dynamic>> rows, {
    required this.hasMore,
    required this.historyLimited,
    required this.verifiedAt,
    this.summaries = const {},
  }) : rows = List.unmodifiable(rows);
  final List<Map<String, dynamic>> rows;
  final bool hasMore, historyLimited;
  final DateTime verifiedAt;

  /// Reply previews of the parents in [rows], by parent message id.
  final Map<String, dynamic> summaries;
  Map<String, dynamic> get page => {
    'messages': rows,
    'historyLimited': historyLimited,
    'hasMore': hasMore,
    if (summaries.isNotEmpty) 'threadSummariesByParentMessageId': summaries,
  };
}

/// Request metadata belongs to the client object, never to the server payload.
class MessageHistoryPage extends MapBase<String, dynamic> {
  MessageHistoryPage(
    Map<String, dynamic> page, {
    required this.scope,
    required this.revision,
    required this.before,
    required this.after,
    required this.local,
    this.limit = 50,
    this.remotePage,
    this.focused = false,
    this.target,
    this.verifiedAt,
    this.heldBeforeAdmission = const {},
  }) : _page = Map.of(page);
  final Map<String, dynamic> _page;
  final Map<String, dynamic>? remotePage;
  final MessageHistoryScope scope;
  final int revision, limit;
  final BigInt? before, after;
  final bool local;
  final bool focused;
  final String? target;
  final DateTime? verifiedAt;

  /// Receiver-owned rows that existed before this response was presented.
  final Map<String, Map<String, dynamic>> heldBeforeAdmission;
  String get queryKey => historyQueryKey(
    before: before,
    after: after,
    limit: limit,
    target: target,
  );
  @override
  dynamic operator [](Object? key) => _page[key];
  @override
  void operator []=(String key, dynamic value) => _page[key] = value;
  @override
  void clear() => _page.clear();
  @override
  Iterable<String> get keys => _page.keys;
  @override
  dynamic remove(Object? key) => _page.remove(key);
}

String historyQueryKey({
  BigInt? before,
  BigInt? after,
  int limit = 50,
  String? target,
}) => jsonEncode(['$before', '$after', limit, target]);

HistoryReadKey historyReadKey(
  MessageHistoryScope scope,
  Object ticket,
  String queryKey,
) => (
  scope.origin,
  scope.principal,
  scope.server,
  scope.channel,
  scope.authority,
  '$ticket',
  queryKey,
);

/// Optional device capability. Existing in-memory cache doubles keep working.
abstract interface class MessageHistoryProvider {
  bool get messageHistoryEnabled;
  MessageHistoryStorage get messageHistory;
}

/// Persistent accepted projections and proven page ranges, independent of UI.
abstract interface class MessageHistoryStorage {
  HistoryReadPolicy get reads;
  HistoryCapacity get capacity;
  HistoryMemoryPool get memory;
  HistoryGapQueries get gaps;
  Future<SavedReadingPosition?> readPosition(MessageHistoryScope scope);
  Future<void> savePosition(
    MessageHistoryScope scope,
    SavedReadingPosition? position,
  );
  Future<void> get positionsSettled;
  Future<DateTime?> lastVerified(MessageHistoryScope scope, String queryKey);
  Future<bool> wasEvicted(
    MessageHistoryScope scope, {
    BigInt? before,
    BigInt? after,
    String? target,
  });
  Future<Map<String, Map<String, dynamic>?>> projections(
    MessageHistoryScope scope,
    Iterable<String> ids,
  );
  Future<int> migrateLegacy(MessageHistoryScope scope, {int limit = 4});

  /// Reply previews follow their parent rows: stored only for a live row,
  /// and removed with it. The network page remains the authority.
  Future<void> saveSummaries(
    MessageHistoryScope scope,
    Map<String, dynamic> summaries,
  );

  /// Orders receiver events, including asynchronous parent-scope resolution.
  /// This queue is separate from the database queue to avoid nested writes.
  HistoryReceiverQueue get receiver;
  Future<MessageHistoryScope?> knownScope(
    String origin,
    String principal,
    String server,
    String channel,
  );

  /// Oldest retained body per authorized conversation, for reconnect checks.
  Future<List<(MessageHistoryScope, BigInt)>> savedRanges(
    String origin,
    String principal,
    String server,
  );
  Future<BigInt> resumeSequence(MessageHistoryScope scope);
  Future<void> checkpoint(
    MessageHistoryScope scope,
    BigInt sequence, {
    bool initializeOnly = false,
  });
  Future<int> revision(MessageHistoryScope scope);
  Future<int> receiverRevision(MessageHistoryScope scope);
  Future<LocalMessageHistoryPage?> readPage(
    MessageHistoryScope scope, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  });
  Future<Map<String, dynamic>?> readContext(
    MessageHistoryScope scope,
    String messageId, {
    int radius = 15,
  });

  /// Resolve a late HTTP response against already committed live projections.
  Future<Map<String, dynamic>> reconcilePage(
    MessageHistoryScope scope,
    Map<String, dynamic> page, {
    required int requestedRevision,
    BigInt? before,
    BigInt? after,
    bool focused = false,
  });

  /// Commit after the receiver admitted the response through its scope ticket.
  Future<void> acceptPage(MessageHistoryPage page);
  /// [live] marks rows that arrived on a connected socket: each one extends
  /// the saved tail it follows instead of leaving a gap before it.
  Future<bool> acceptEvents(
    MessageHistoryScope scope,
    Iterable<Map<String, dynamic>> rows, {
    bool updateOnly = false,
    int? requestedRevision,
    bool live = false,
  });

  /// Compatibility snapshots are imported without inventing continuity.
  Future<void> importWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    Map<String, dynamic> snapshot,
  );
  Future<Map<String, dynamic>?> readWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  );
}

/// A retention operation retired an in-flight read. Retry with a fresh fence.
class HistoryReadRetired implements Exception {
  const HistoryReadRetired();
}

class HistoryReceiverQueue {
  Future<void> _tail = Future<void>.value();
  final _edits = <Object, _HistoryEditBatch>{};
  final _waitingEdits = <_HistoryEditBatch>{};
  final _zone = Zone.current;
  bool _closed = false;
  final _rows = <(String, String, String, String, String), Object>{};
  Iterable<HistoryProtectedRows> get protectedRows sync* {
    final grouped = <(String, String, String, String), List<String>>{};
    for (final key in _rows.keys) {
      grouped
          .putIfAbsent((key.$1, key.$2, key.$3, key.$4), () => [])
          .add(key.$5);
    }
    for (final entry in grouped.entries) {
      final key = entry.key;
      yield HistoryProtectedRows(
        HistoryAccount(key.$1, key.$2),
        key.$3,
        key.$4,
        entry.value,
      );
    }
  }

  bool hasRow(MessageHistoryScope scope, String id) => _rows.containsKey((
    scope.origin,
    scope.principal,
    scope.server,
    scope.channel,
    id,
  ));
  HistoryRowReceipt beginRow(
    MessageHistoryScope scope,
    String channel,
    String id,
  ) {
    final key = (scope.origin, scope.principal, scope.server, channel, id),
        token = Object();
    _rows[key] = token;
    return HistoryRowReceipt._(() => identical(_rows[key], token), () {
      if (identical(_rows[key], token)) _rows.remove(key);
    });
  }

  final _pending = <(String, String, String), _HistoryPending>{};
  HistoryReceipt? begin(
    MessageHistoryScope scope,
    Iterable<Map<String, dynamic>> rows,
  ) {
    final materialized = rows.toList();
    final sequences =
        materialized
            .map((r) => BigInt.tryParse('${r['seq']}'))
            .nonNulls
            .where((s) => s > BigInt.zero)
            .toList()
          ..sort();
    if (sequences.isEmpty) return null;
    final identities = <(String, String), BigInt>{};
    for (final row in materialized) {
      final sequence = BigInt.tryParse('${row['seq']}');
      if (row['channelId'] is String &&
          row['id'] is String &&
          sequence != null &&
          sequence > BigInt.zero) {
        identities[(row['channelId'] as String, row['id'] as String)] =
            sequence;
      }
    }
    final key = (scope.origin, scope.principal, scope.server);
    final pending = _pending.putIfAbsent(
      key,
      () => _HistoryPending(sequences.first),
    );
    pending.count++;
    if (sequences.first < pending.lower) pending.lower = sequences.first;
    return HistoryReceipt._((success, through, unresolved, resolved) {
      if (!identical(_pending[key], pending)) return;
      pending.count--;
      if (!success && unresolved) {
        pending.unresolved.addAll(identities);
      } else if (!success) {
        final failed = sequences.last;
        if (pending.failedThrough == null || failed > pending.failedThrough!) {
          pending.failedThrough = failed;
        }
      } else if (through != null &&
          pending.failedThrough != null &&
          through >= pending.failedThrough!) {
        pending.failedThrough = null;
      }
      if (success && resolved) {
        for (final id in identities.keys) {
          pending.unresolved.remove(id);
        }
      }
      if (pending.count == 0 &&
          pending.failedThrough == null &&
          pending.unresolved.isEmpty) {
        _pending.remove(key);
      }
    });
  }

  BigInt checkpointLimit(MessageHistoryScope scope, BigInt proposed) {
    final pending = _pending[(scope.origin, scope.principal, scope.server)];
    return pending != null && proposed >= pending.lower
        ? pending.lower - BigInt.one
        : proposed;
  }

  bool hasPending(MessageHistoryScope scope) =>
      _pending.containsKey((scope.origin, scope.principal, scope.server));
  void confirmReplay(MessageHistoryScope scope, BigInt? through) {
    final key = (scope.origin, scope.principal, scope.server),
        pending = _pending[(scope.origin, scope.principal, scope.server)];
    if (pending == null ||
        through == null ||
        pending.failedThrough == null ||
        through < pending.failedThrough!) {
      return;
    }
    pending.failedThrough = null;
    if (pending.count == 0 && pending.unresolved.isEmpty) _pending.remove(key);
  }

  void clearServer(String origin, String principal, String server) {
    _cancelEdits(
      (batch) =>
          batch.scope.origin == origin &&
          batch.scope.principal == principal &&
          batch.scope.server == server,
    );
    _pending.remove((origin, principal, server));
    _rows.removeWhere(
      (key, _) => key.$1 == origin && key.$2 == principal && key.$3 == server,
    );
  }

  void revokeScopes(
    String origin,
    String principal,
    String server,
    Set<String> channels,
  ) {
    _cancelEdits(
      (batch) =>
          batch.scope.origin == origin &&
          batch.scope.principal == principal &&
          batch.scope.server == server &&
          channels.contains(batch.row['channelId']),
    );
    final key = (origin, principal, server),
        pending = _pending[(origin, principal, server)];
    pending?.unresolved.removeWhere((id, _) => channels.contains(id.$1));
    _rows.removeWhere(
      (key, _) =>
          key.$1 == origin &&
          key.$2 == principal &&
          key.$3 == server &&
          channels.contains(key.$4),
    );
    if (pending != null &&
        pending.count == 0 &&
        pending.failedThrough == null &&
        pending.unresolved.isEmpty) {
      _pending.remove(key);
    }
  }

  void clearAccount(String origin, String principal) {
    _cancelEdits(
      (batch) =>
          batch.scope.origin == origin && batch.scope.principal == principal,
    );
    _pending.removeWhere((key, _) => key.$1 == origin && key.$2 == principal);
    _rows.removeWhere((key, _) => key.$1 == origin && key.$2 == principal);
  }

  Future<T> run<T>(Future<T> Function() action) {
    // A new message or replay is an ordering barrier between edit batches.
    _edits.clear();
    return _append(action);
  }

  Future<void> coalesceUpdate(
    Object owner,
    MessageHistoryScope scope,
    Object key,
    Map<String, dynamic> row,
    Future<int> Function() reserve,
    Future<void> Function(Map<String, dynamic>, int) apply,
  ) {
    if (_closed) return Future<void>.value();
    final existing = _edits[key];
    if (existing != null) {
      existing.row = mergeMessageProjection(existing.row, row);
      existing.apply = apply;
      return existing.done;
    }
    final revision = reserve();
    revision.ignore();
    final batch = _HistoryEditBatch(owner, scope, Map.of(row), revision, apply);
    _edits[key] = batch;
    _waitingEdits.add(batch);
    _zone.run(
      () => batch.timer.start(const Duration(milliseconds: 60), () {
        if (!batch.ready.isCompleted) batch.ready.complete();
      }),
    );
    return batch.done = _append(() async {
      // One fixed positive deadline; continuous input cannot postpone it.
      // This waits outside the database queue, so local reads stay available.
      await batch.ready.future;
      if (identical(_edits[key], batch)) _edits.remove(key);
      try {
        if (!batch.retired) await batch.apply(batch.row, await batch.revision);
      } finally {
        _waitingEdits.remove(batch);
      }
    });
  }

  Map<String, dynamic>? pendingUpdate(MessageHistoryScope scope, String id) {
    Map<String, dynamic>? patch;
    for (final batch in _waitingEdits) {
      if (!batch.retired &&
          batch.scope.origin == scope.origin &&
          batch.scope.principal == scope.principal &&
          batch.scope.server == scope.server &&
          batch.row['channelId'] == scope.channel &&
          batch.row['id'] == id) {
        patch = mergeMessageProjection(patch, batch.row);
      }
    }
    return patch;
  }

  void _cancelEdits(bool Function(_HistoryEditBatch) matches) {
    for (final batch in _waitingEdits.where(matches).toList()) {
      batch.retired = true;
      batch.timer.cancel();
      if (!batch.ready.isCompleted) batch.ready.complete();
    }
    _edits.removeWhere((_, batch) => matches(batch));
  }

  void cancelUpdates(Object owner) =>
      _cancelEdits((batch) => identical(batch.owner, owner));

  void close() {
    _closed = true;
    _cancelEdits((_) => true);
    _pending.clear();
    _rows.clear();
  }

  Future<T> _append<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> get settled => _tail;
}

class _HistoryEditBatch {
  _HistoryEditBatch(
    this.owner,
    this.scope,
    this.row,
    this.revision,
    this.apply,
  );
  final Object owner;
  final MessageHistoryScope scope;
  final timer = RaftIdleTimer(yieldToAnimation: false);
  final ready = Completer<void>();
  bool retired = false;
  Map<String, dynamic> row;
  final Future<int> revision;
  Future<void> Function(Map<String, dynamic>, int) apply;
  late Future<void> done;
}

class HistoryRowReceipt {
  HistoryRowReceipt._(this.current, this.finish);
  final bool Function() current;
  final void Function() finish;
}

class _HistoryPending {
  _HistoryPending(this.lower);
  BigInt lower;
  BigInt? failedThrough;
  final unresolved = <(String, String), BigInt>{};
  int count = 0;
}

class HistoryReceipt {
  HistoryReceipt._(this._complete);
  final void Function(bool, BigInt?, bool, bool) _complete;
  bool _finished = false;
  void finish(
    bool success, {
    BigInt? replayedThrough,
    bool unresolved = false,
    bool resolved = false,
  }) {
    if (_finished) return;
    _finished = true;
    _complete(success, replayedThrough, unresolved, resolved);
  }
}
