import 'history_gaps.dart';

/// Metadata from a complete, accepted page; never retains an HTTP body.
class HistoryRangeProof {
  const HistoryRangeProof(
    this.lower,
    this.upper, {
    this.firstId,
    this.limited = false,
  });
  final BigInt lower, upper;
  final String? firstId;
  final bool limited;

  factory HistoryRangeProof.page(Map<String, dynamic> page, BigInt? before) {
    final rows = (page['messages'] as List).cast<Map>();
    final ordered = [...rows]
      ..sort(
        (a, b) =>
            BigInt.parse('${a['seq']}').compareTo(BigInt.parse('${b['seq']}')),
      );
    return HistoryRangeProof(
      ordered.length < 50
          ? BigInt.zero
          : BigInt.parse('${ordered.first['seq']}'),
      before != null
          ? before - BigInt.one
          : ordered.isEmpty
          ? BigInt.zero
          : BigInt.parse('${ordered.last['seq']}'),
      firstId: ordered.isEmpty ? null : ordered.first['id'] as String,
      limited: page['historyLimited'] == true,
    );
  }
}

/// One reconnect/online-window generation. Completed coverage and in-flight
/// acceptance share a lifetime, so a transport completion alone proves nothing.
class HistoryRangeReads {
  static final _owners = Expando<HistoryRangeReads>();
  static HistoryRangeReads of(Object owner) =>
      _owners[owner] ??= HistoryRangeReads();
  static int _next = 0;
  final int _id = ++_next;
  final _scopes = <Object, HistoryRangeRead>{};
  Object? _context;
  int _generation = 0;
  int get generation => _generation;

  void restart() {
    _generation++;
    _scopes.clear();
  }

  void bind(Object context) {
    if (_context == context) return;
    _context = context;
    restart();
  }

  HistoryRangeRead scope(Object context, Object key) {
    bind(context);
    final epoch = generation;
    return _scopes.putIfAbsent(
      key,
      () => HistoryRangeRead._((_id, epoch), () => generation == epoch),
    );
  }
}

class HistoryRangeRead {
  HistoryRangeRead._(this.token, this._current);
  final Object token;
  final bool Function() _current;
  bool get current => _current();
  final _flights = <BigInt?, Future<HistoryRangeProof?>>{};
  final _coverage = <HistoryRangeProof>[];
  HistoryRangeProof? _tail;

  HistoryRangeProof? _covered(BigInt? before) {
    if (before == null) return _tail;
    for (final proof in _coverage) {
      if (proof.lower < before && proof.upper >= before - BigInt.one) {
        return proof;
      }
    }
    return null;
  }

  Future<HistoryRangeProof?> read(
    BigInt? before,
    Future<HistoryRangeProof?> Function() accept,
  ) {
    if (!current) return Future.value(null);
    final covered = _covered(before);
    if (covered != null) return Future.value(covered);
    final held = _flights[before];
    if (held != null) return held;
    late final Future<HistoryRangeProof?> result;
    result = Future<HistoryRangeProof?>.sync(accept)
        .then((proof) {
          if (!current) return null;
          if (proof != null && !proof.limited) {
            if (before == null) _tail = proof;
            _add(proof);
          }
          return proof;
        })
        .whenComplete(() {
          if (identical(_flights[before], result)) _flights.remove(before);
        });
    _flights[before] = result;
    return result;
  }

  void _add(HistoryRangeProof proof) {
    if (proof.lower > proof.upper) return;
    _coverage.add(proof);
    _coverage.sort((a, b) => a.lower.compareTo(b.lower));
    final merged = <HistoryRangeProof>[];
    for (final span in _coverage) {
      if (merged.isEmpty || merged.last.upper + BigInt.one < span.lower) {
        merged.add(span);
      } else {
        final previous = merged.removeLast();
        merged.add(
          HistoryRangeProof(
            previous.lower,
            previous.upper > span.upper ? previous.upper : span.upper,
            firstId: previous.firstId,
          ),
        );
      }
    }
    _coverage
      ..clear()
      ..addAll(merged);
  }

  List<HistoryGap> remaining(List<HistoryGap> gaps) {
    if (!current) return gaps;
    final result = <HistoryGap>[];
    for (final gap in gaps) {
      var intervals = [
        ((gap.older ?? BigInt.zero) + BigInt.one, gap.before - BigInt.one),
      ];
      for (final proof in _coverage) {
        intervals = [
          for (final span in intervals)
            if (proof.upper < span.$1 || proof.lower > span.$2)
              span
            else ...[
              if (span.$1 < proof.lower) (span.$1, proof.lower - BigInt.one),
              if (span.$2 > proof.upper) (proof.upper + BigInt.one, span.$2),
            ],
        ];
      }
      for (final span in intervals) {
        final before = span.$2 + BigInt.one;
        final id = before == gap.before
            ? gap.newerId
            : _coverage
                  .where((proof) => proof.lower == before)
                  .firstOrNull
                  ?.firstId;
        if (id != null) {
          result.add(HistoryGap(id, before, older: span.$1 - BigInt.one));
        }
      }
    }
    return result;
  }
}
