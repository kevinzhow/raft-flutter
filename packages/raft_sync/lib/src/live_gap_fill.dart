// Holes behind live rows of the open channel (Web store/liveGapFill.ts at
// v1.24.0-source.1).
//
// Message seqs are server-global, so nearly every live row "jumps" past the
// channel's newest seq. The row is shown at once; the hole before it
// (`holeFrom`, the window tail when it arrived) is filled by a background
// GET /messages/sync and stays unconfirmed until a read from at most
// `holeFrom`, started after the row arrived, answers. A row that lands while
// that read is in flight gets a read of its own after it; a failed read is
// retried after 1, 2, 4, 8 and 16 s, after which the heartbeat, a resume or a
// reconnect re-reads the scope.
import 'dart:async';

enum GapReadOutcome { read, failed, abandoned }

class _Pending {
  _Pending(this.messageId, this.holeFrom, this.epoch);
  final String messageId;
  final BigInt holeFrom;
  final int epoch;
}

/// One read of a scope; [rerunSince] is set when another was asked meanwhile.
class GapRead {
  GapRead._(this.generation, this.startEpoch);
  final int generation, startEpoch;
  BigInt? rerunSince;
}

class LiveGapFill {
  LiveGapFill({Timer Function(Duration, void Function())? timer})
    : _timer = timer ?? Timer.new;

  static final _owners = Expando<LiveGapFill>('live gap fill');

  /// The fill of [owner] (the receiver's message ledger); lives as long as it.
  static LiveGapFill of(Object owner) => _owners[owner] ??= LiveGapFill();

  static const retryBase = Duration(seconds: 1);
  static const maxRetries = 5;

  final Timer Function(Duration, void Function()) _timer;

  /// How a scheduled fill reads (`syncGap` of the visible scopes).
  void Function(String channelId)? reader;

  final _pending = <String, List<_Pending>>{};
  final _inFlight = <String, GapRead>{};
  final _timers = <String, Timer>{};
  final _failures = <String, int>{};
  int _epoch = 0;

  /// Bumped by a full reset (server switch, sign-out): a read started before
  /// it reruns, retries and fills nothing.
  int _generation = 0;

  /// A live row shown across a seq jump from [holeFrom]: fill the hole.
  void remember(String channelId, String messageId, BigInt holeFrom) {
    final pending = _pending.putIfAbsent(channelId, () => []);
    if (pending.any((entry) => entry.messageId == messageId)) return;
    pending.add(_Pending(messageId, holeFrom, ++_epoch));
    _schedule(channelId, Duration.zero);
  }

  /// The seq a read of [channelId] must start from to fill every hole still
  /// unconfirmed there, or null.
  BigInt? owedSince(String channelId) {
    final pending = _pending[channelId];
    if (pending == null || pending.isEmpty) return null;
    return pending
        .map((entry) => entry.holeFrom)
        .reduce((a, b) => a < b ? a : b);
  }

  /// Live rows of [channelId] whose hole is not confirmed (the heartbeat
  /// re-reads it whatever its seq says).
  bool owes(String channelId) => _pending[channelId]?.isNotEmpty ?? false;

  /// A read asked for from [since] while one is in flight runs after it
  /// (from the lowest seq asked) and this returns true.
  bool joinInFlight(String channelId, BigInt since) {
    final read = _inFlight[channelId];
    if (read == null) return false;
    final rerun = read.rerunSince;
    read.rerunSince = rerun == null || since < rerun ? since : rerun;
    return true;
  }

  /// Start a read of [channelId]; pending rows that arrived before it are
  /// the ones it covers.
  GapRead start(String channelId) =>
      _inFlight[channelId] = GapRead._(_generation, _epoch);

  /// A read from [since] answered: every row it returned, and every pending
  /// row it covers (arrived before it started, hole at or after [since]), is
  /// settled. Returns how many remain.
  int settle(String channelId, BigInt since, GapRead read, Set<String> ids) {
    final pending = _pending[channelId];
    if (pending == null || read.generation != _generation) return 0;
    pending.removeWhere(
      (entry) =>
          ids.contains(entry.messageId) ||
          entry.epoch <= read.startEpoch && entry.holeFrom >= since,
    );
    if (pending.isEmpty) _pending.remove(channelId);
    return pending.length;
  }

  /// The read finished: rerun what was asked meanwhile, retry a failed fill
  /// with backoff, or fill a row that landed during it. [rerun] reads again
  /// from the seq given.
  void finish(
    String channelId,
    GapRead read,
    GapReadOutcome outcome,
    void Function(BigInt since) rerun,
  ) {
    if (identical(_inFlight[channelId], read)) _inFlight.remove(channelId);
    if (read.generation != _generation) return;
    if (outcome == GapReadOutcome.read) _failures.remove(channelId);
    final owed = owedSince(channelId);
    final asked = read.rerunSince;
    if (asked != null) {
      rerun(owed == null || asked < owed ? asked : owed);
    } else if (outcome == GapReadOutcome.failed) {
      _retry(channelId);
    } else if (outcome == GapReadOutcome.read && owed != null) {
      _schedule(channelId, Duration.zero);
    }
  }

  /// A window (re)load or a reset: forget the channel's (or every) hole.
  void clear([String? channelId]) {
    for (final key in _timers.keys.toList()) {
      if (channelId != null && key != channelId) continue;
      _timers.remove(key)!.cancel();
    }
    if (channelId != null) {
      _failures.remove(channelId);
      _pending.remove(channelId);
      return;
    }
    _failures.clear();
    _pending.clear();
    _inFlight.clear();
    _generation++;
  }

  void _schedule(String channelId, Duration delay) {
    if (_timers.containsKey(channelId)) return;
    _timers[channelId] = _timer(delay, () {
      _timers.remove(channelId);
      // A read in flight settles what it covers and asks again for the rest.
      if (_inFlight.containsKey(channelId)) return;
      if (owes(channelId)) reader?.call(channelId);
    });
  }

  void _retry(String channelId) {
    if (!owes(channelId)) return;
    final failures = (_failures[channelId] ?? 0) + 1;
    _failures[channelId] = failures;
    // Past the cap the hole stays known: the heartbeat re-reads it.
    if (failures > maxRetries) return;
    _schedule(channelId, retryBase * (1 << (failures - 1)));
  }
}
