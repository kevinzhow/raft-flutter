import 'package:raft_sync/raft_sync.dart';

/// The catch-up horizon of server v1.24 (Web messageStore `syncHorizon`,
/// server services/syncHorizon.ts): the opaque `horizon` a
/// `sync:resume:response` carries. The next round's first `sync:resume`
/// sends it back as `sinceHorizon`, so messages that committed late behind
/// the last catch-up (seq at or below `lastSeq`) are delivered too. Held per
/// receiver ledger and forgotten when its generation changes (server switch,
/// sign-out); an older server sends none and resumes as before.
abstract final class SyncHorizon {
  static final _held = Expando<(int, String)>('sync horizon');

  /// The horizon to send with [ledger]'s next resume round, or null.
  static String? of(MessageLedger ledger) {
    final held = _held[ledger];
    return held != null && held.$1 == ledger.generation ? held.$2 : null;
  }

  static void accept(MessageLedger ledger, Object? horizon) {
    if (horizon is String && horizon.isNotEmpty) {
      _held[ledger] = (ledger.generation, horizon);
    }
  }
}
