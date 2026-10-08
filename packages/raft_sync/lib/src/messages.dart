/// Mounted Web messageSyncDomain.ts compatibility domain. Message sequence is
/// sparse per channel; the existing socket resume transport owns replay repair.
library;

import 'core.dart';
import 'read_state.dart';

class MessageSync {
  MessageSync() : core = _create();
  SyncCore core;
  static SyncCore _create() => SyncCore(
    domains: [
      SyncDomain(
        name: 'messages',
        density: SyncDensity.sparse,
        initialState: () => <String, Map<String, dynamic>>{},
        fold: (state, event, scope, seq) {
          final rows = Map<String, Map<String, dynamic>>.from(state as Map);
          final row = Map<String, dynamic>.from(event as Map);
          final previous = rows[row['id']];
          rows[row['id'] as String] = mergeMessageProjection(previous, row);
          return rows;
        },
        fromSnapshot: (snapshot) => snapshot.state,
      ),
    ],
  );

  /// Null means a duplicate/regression; a missing sequence keeps the legacy
  /// fallback, exactly as the mounted Web consumer does.
  Map<String, dynamic>? consumeNew(Map<String, dynamic> row) {
    final value = row['seq'];
    final seq = value is int && value > 0 && value <= maxSafeInteger
        ? BigInt.from(value)
        : canonicalUint64(value);
    final channel = row['channelId'], id = row['id'];
    if (seq == null ||
        seq == BigInt.zero ||
        channel is! String ||
        id is! String) {
      return Map<String, dynamic>.from(row);
    }
    final outcome = core.ingestFrame(
      'messages',
      SyncFrame(scopeId: channel, seq: seq, event: row),
    );
    if (outcome['kind'] == 'duplicate_dropped') return null;
    return Map<String, dynamic>.from(
      (core.state('messages', channel) as Map)[id],
    );
  }

  void revokeChannel(String channel) => core.revokeScope('messages', channel);
  void reset() => core = _create();
}

Map<String, dynamic> mergeMessageProjection(
  Map<String, dynamic>? previous,
  Map<String, dynamic> incoming,
) {
  final merged = <String, dynamic>{...?previous, ...incoming};
  // Canonical manifest's shared-null-preserve policy. Partial task updates
  // must not erase loaded text/author/attachments or the existing commentRef.
  if (previous?['commentRef'] != null && incoming['commentRef'] == null) {
    merged['commentRef'] = previous!['commentRef'];
  }
  return merged;
}
