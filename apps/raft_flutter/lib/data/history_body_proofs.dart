import 'history_memory.dart' show HistoryBodyProof;
import 'workspace_cache_codec.dart';

typedef InspectHistoryBodies = Future<List<HistoryBodyProof>> Function(
  Map<String, List<Map<String, dynamic>>> versions,
  Map<String, String> stored,
);

/// Reuses proofs for immutable body identities and the freshly read disk value.
/// Weak keys/references must not keep evicted versions alive. Disk values are
/// still read under the storage permission fence on every call.
class HistoryBodyProofs {
  HistoryBodyProofs({this.inspect = inspectHistoryBodies});
  final InspectHistoryBodies inspect;
  var _cache = Expando<_BodyProof>('history body proofs');

  Future<List<HistoryBodyProof>> call(
    Map<String, List<Map<String, dynamic>>> versions,
    Map<String, String> stored,
  ) async {
    final cache = _cache;
    final result = <String, HistoryBodyProof>{};
    final pending = <String, List<Map<String, dynamic>>>{};
    final payloads = <String, String>{};
    final ids = versions.keys.toList();
    for (final entry in versions.entries) {
      final rows = entry.value;
      final cached = cache[rows.first];
      if (cached != null &&
          cached.matches(entry.key, rows, stored[entry.key])) {
        result[entry.key] = cached.proof;
      } else {
        // Freeze the identities and disk values before the asynchronous worker.
        pending[entry.key] = List.of(rows);
        if (stored[entry.key] case final payload?) {
          payloads[entry.key] = payload;
        }
      }
    }
    if (pending.isNotEmpty) {
      for (final proof in await inspect(pending, payloads)) {
        final rows = pending[proof.id]!;
        cache[rows.first] = _BodyProof(rows, payloads[proof.id], proof);
        result[proof.id] = proof;
      }
    }
    return [for (final id in ids) result[id]!];
  }

  void clear() => _cache = Expando<_BodyProof>('history body proofs');
}

class _BodyProof {
  _BodyProof(List<Map<String, dynamic>> rows, this.payload, this.proof)
    : versions = [for (final row in rows) WeakReference(row)];
  final List<WeakReference<Map<String, dynamic>>> versions;
  final String? payload;
  final HistoryBodyProof proof;

  bool matches(String id, List<Map<String, dynamic>> rows, String? stored) =>
      id == proof.id &&
      payload == stored &&
      versions.length == rows.length &&
      Iterable<int>.generate(rows.length)
          .every((i) => identical(versions[i].target, rows[i]));
}
