// Source: packages/web/src/store/inboxCountedIds.ts at v1.24.0-source.1
import 'package:raft_sync/raft_sync.dart' show canonicalUint64;

import 'resource_row_reconcile.dart';

/// The live messages each Activity row was patched with since its last served
/// answer, so a message that comes late (an older seq than the row, after a
/// newer one) is counted once and a repeat of it never again.
///
/// Per row (keyed by its scope: channel, DM, thread or task conversation id):
/// the highest seq a served answer had for it, and the ids (with seqs) of the
/// live messages applied since. A served answer drops only the ids it covers.
/// Bounded: past [perRow] ids on a row or [total] in all, an id is not kept,
/// the row stops counting late messages until an answer covers it, and the
/// caller asks for a re-read instead.
class InboxCountedIds {
  static const perRow = 64;
  static const total = 1024;

  final _rows = <String, _CountedRow>{};
  int _total = 0;

  void _forget(String scope) {
    final row = _rows.remove(scope);
    if (row != null) _total -= row.ids.length;
  }

  /// An accepted answer (any page). [reset]: the list's first window, which
  /// replaces it, so a row it does not list is forgotten.
  void noteServed(Iterable<Map> items, {required bool reset}) {
    final served = <String, BigInt?>{};
    for (final item in items) {
      if (activityScopeId(item) case final scope?) {
        served[scope] = canonicalUint64(item['latestActivitySeq']);
      }
    }
    if (reset) {
      for (final scope in _rows.keys.toList()) {
        if (!served.containsKey(scope)) _forget(scope);
      }
    }
    for (final MapEntry(key: scope, value: seq) in served.entries) {
      final row = _rows[scope] ??= _CountedRow();
      // Never backwards: an answer behind an earlier one (the view's lag) does
      // not reopen what that one covered.
      if (seq != null && (row.servedSeq == null || seq > row.servedSeq!)) {
        row.servedSeq = seq;
      }
      final covered = row.servedSeq;
      if (covered == null) continue;
      row.ids.removeWhere((_, idSeq) {
        final drop = idSeq <= covered;
        if (drop) _total -= 1;
        return drop;
      });
      if (row.blindTo != null && covered >= row.blindTo!) row.blindTo = null;
    }
  }

  /// Was this live message already applied to its row since the row's last
  /// served answer?
  bool isCounted(String scope, String messageId) =>
      _rows[scope]?.ids.containsKey(messageId) ?? false;

  /// A message at or below its row's seq: is it one the row has not counted
  /// yet? Newer than the last served answer, not applied since, and the row
  /// still keeps every id it applied.
  bool isLateUncounted(String scope, String messageId, BigInt seq) {
    final row = _rows[scope];
    if (row == null ||
        row.servedSeq == null ||
        row.blindTo != null ||
        row.ids.containsKey(messageId)) {
      return false;
    }
    return seq > row.servedSeq!;
  }

  /// A live message applied to its row. False when it could not be kept (the
  /// row or all rows are at the cap): the caller asks for a re-read.
  bool noteCounted(String scope, String messageId, BigInt seq) {
    final row = _rows[scope] ??= _CountedRow();
    if (row.ids.containsKey(messageId)) return true;
    if (row.ids.length >= perRow || _total >= total) {
      if (row.blindTo == null || seq > row.blindTo!) row.blindTo = seq;
      return false;
    }
    row.ids[messageId] = seq;
    _total += 1;
    return true;
  }

  void reset() {
    _rows.clear();
    _total = 0;
  }

  int sizeOf(String scope) => _rows[scope]?.ids.length ?? 0;
}

class _CountedRow {
  /// The highest seq a served answer had for the row; null: none seen.
  BigInt? servedSeq;
  final ids = <String, BigInt>{};

  /// A live message past the cap was not kept: no late counting until an
  /// answer reaches this seq.
  BigInt? blindTo;
}
