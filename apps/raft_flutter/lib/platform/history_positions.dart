import 'package:drift/drift.dart';

import '../data/message_history.dart';
import '../data/reading_positions.dart';
import 'message_history.dart' show HistoryOperationOrder;

/// Reading metadata shares the message store's ordering and live authority.
class SqliteHistoryPositions {
  SqliteHistoryPositions(
    this.db,
    this.order, {
    required this.ready,
    required this.allowed,
    required this.readLegacy,
    required this.writeLegacy,
  });
  final GeneratedDatabase db;
  final HistoryOperationOrder order;
  final Future<void> Function() ready;
  final Future<bool> Function(MessageHistoryScope) allowed;
  final Future<dynamic> Function(String, String, String, String, String)
  readLegacy;
  final Future<void> Function(String, String, String, String, String, dynamic)
  writeLegacy;
  Future<void> _writes = Future<void>.value();
  int _revision = 0, _pending = 0;
  Future<void> get settled =>
      _writes.then<void>((_) {}, onError: (Object _) {});

  /// Capture before a snapshot starts. Both enqueue and completion invalidate
  /// the proof, including a save that was pending throughout the snapshot.
  bool Function() unchangedGuard() {
    final revision = _revision, idle = _pending == 0;
    return () => idle && _pending == 0 && revision == _revision;
  }

  Future<SavedReadingPosition?> read(MessageHistoryScope scope) =>
      order(() async {
        await ready();
        if (!await allowed(scope)) return null;
        final raw = await readLegacy(
          scope.origin,
          scope.principal,
          scope.server,
          'history-anchor',
          scope.channel,
        );
        if (raw is! Map ||
            raw['version'] != 1 ||
            raw['authority'] != scope.authority ||
            raw['messageId'] is! String ||
            raw['top'] is! num) {
          return null;
        }
        final sequence = BigInt.tryParse('${raw['sequence']}'),
            top = (raw['top'] as num).toDouble();
        if (sequence == null ||
            sequence <= BigInt.zero ||
            sequence > historyMaxSequence ||
            !top.isFinite) {
          return null;
        }
        return SavedReadingPosition(raw['messageId'] as String, sequence, top);
      });

  Future<void> save(MessageHistoryScope scope, SavedReadingPosition? position) {
    _revision++;
    _pending++;
    return _writes = order(() => _save(scope, position)).whenComplete(() {
      _revision++;
      _pending--;
    });
  }

  Future<void> _save(
    MessageHistoryScope scope,
    SavedReadingPosition? position,
  ) async {
    await ready();
    if (position == null) {
      await db.customStatement(
        "DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind='history-anchor' AND id=?",
        scope.key,
      );
      return;
    }
    if (!await allowed(scope) ||
        !position.top.isFinite ||
        position.sequence <= BigInt.zero ||
        position.sequence > historyMaxSequence) {
      return;
    }
    final rows = await db
        .customSelect(
          'SELECT seq_key,tombstone FROM raft_history_rows '
          'WHERE origin=? AND principal=? AND server=? AND channel=? AND message_id=?',
          variables: [
            for (final value in [...scope.key, position.messageId])
              Variable(value),
          ],
        )
        .get();
    if (rows.isEmpty ||
        rows.single.read<int>('tombstone') != 0 ||
        BigInt.parse(rows.single.read<String>('seq_key')) !=
            position.sequence) {
      return;
    }
    await writeLegacy(
      scope.origin,
      scope.principal,
      scope.server,
      'history-anchor',
      scope.channel,
      {
        'version': 1,
        'authority': scope.authority,
        'parentChannelId': scope.parentChannel,
        'messageId': position.messageId,
        'sequence': '${position.sequence}',
        'top': position.top,
      },
    );
  }
}
