import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show mergeMessageProjection;

import 'history_capacity.dart';
import 'history_read_policy.dart';
import 'message_history.dart';
import 'message_history_pages.dart';
import 'workspace_message_host.dart';
import 'workspace_message_windows.dart';

/// Applies one complete authorized page before its coverage can be shared.
class MessageHistoryReconciliation {
  static Future<bool> read(
    WorkspaceMessageHost host,
    MessageWindowRequest request,
    MessageHistoryScope scope,
    Object ticket, {
    BigInt? before,
    BigInt? after,
    String? target,
    int limit = 50,
    required HistoryReadReason reason,
    Object? wireTicket,
    bool allowOnlineOnly = false,
    void Function(Map<String, dynamic>)? received,
    void Function(Object cause)? failed,
  }) async {
    final w = host.messageDomain;
    final db = MessageHistoryPages.storage(w.device.cache);
    if (db == null) return false;
    bool current() =>
        request.current &&
        w.device.writable &&
        !db.reads.closed &&
        ticket == w.messageHistoryTicket(scope.parentChannel) &&
        w.messageWindows.notRevoked(scope.channel) &&
        w.messageWindows.notRevoked(scope.parentChannel);
    if (!current()) return false;
    final initial = {
      for (final row in w.ledger.messages(scope.channel))
        row['id'] as String: row,
    };
    final shown = w.messageWindows.rows(scope.channel);
    final lower = shown.isEmpty ? null : shown.first.seq;
    final upper = shown.isEmpty ? null : shown.last.seq;
    try {
      final page = await MessageHistoryPages.load(
        cache: w.device.cache,
        scope: scope,
        current: current,
        held: () => w.ledger.messages(scope.channel),
        ticket: wireTicket ?? ticket,
        before: before,
        after: after,
        target: target,
        focused: target != null,
        limit: limit,
        localFirst: false,
        reason: reason,
        remote: () async => target == null
            ? w.transport.client.messagePage(
                scope.channel,
                before: before,
                after: after,
                limit: limit,
              )
            : Map<String, dynamic>.from(
                await w.transport.client.get(
                  '/messages/context/$target',
                  query: {'channelId': scope.channel},
                ),
              ),
      );
      if (!current() || page is! MessageHistoryPage) return false;
      var durable = true;
      try {
        await db.acceptPage(page);
      } on HistoryCapacityExceeded {
        if (!allowOnlineOnly) rethrow;
        // The complete authorized response can still repair this online
        // window. No range/checkpoint is fabricated in the rolled-back store.
        durable = false;
      }
      if (!current()) return false;
      received?.call(page.remotePage ?? page);
      w.mergeThreadSummaries(
        scope.channel,
        (page.remotePage ?? page)['threadSummariesByParentMessageId'],
      );
      final raw = (page.remotePage?['messages'] as List? ?? const []);
      final ids = {...initial.keys, for (final row in raw) row['id'] as String};
      final stored = durable
          ? await db.projections(scope, ids)
          : await _online(db, page, initial);
      ids.addAll(stored.keys);
      if (!current()) return false;
      final accepted = <Map<String, dynamic>>[];
      final limited = page['historyLimited'] == true;
      final allowed = {for (final row in raw) row['id'] as String};
      for (final id in ids) {
        final pending = db.receiver.pendingUpdate(scope, id);
        if (db.receiver.hasRow(scope, id) && pending == null ||
            !identical(initial[id], w.ledger.message(scope.channel, id))) {
          continue;
        }
        if (stored.containsKey(id) && stored[id] == null ||
            limited && !allowed.contains(id)) {
          w.ledger.remove(scope.channel, id);
          w.visibleIds[scope.channel]?.remove(id);
          continue;
        }
        final row = stored[id];
        if (row == null) continue;
        final seq = BigInt.parse('${row['seq']}');
        if (initial.containsKey(id) ||
            lower != null && upper != null && seq >= lower && seq <= upper) {
          accepted.add(
            pending == null ? row : mergeMessageProjection(row, pending),
          );
        }
      }
      w.messageWindows.acceptRows(
        request,
        scope.channel,
        accepted,
        authoritative: true,
        visible: accepted
            .where(
              (row) =>
                  w.visibleIds[scope.channel]?.contains(row['id']) == true ||
                  !initial.containsKey(row['id']) &&
                      lower != null &&
                      upper != null &&
                      BigInt.parse('${row['seq']}') >= lower &&
                      BigInt.parse('${row['seq']}') <= upper,
            )
            .map((row) => row['id'] as String),
      );
      w.state.messageSync.replaceBodies(scope.channel, accepted);
      final sequences = raw.map((row) => BigInt.parse('${row['seq']}')).toList()
        ..sort();
      final coversOldest =
          after == null &&
          (sequences.isEmpty || lower == null || sequences.first <= lower);
      final boundary = coversOldest && target == null
          ? await db.readPage(scope, before: before, limit: limit)
          : null;
      if (!current()) return false;
      final more = limited
          ? false
          : target != null && coversOldest
          ? page['hasOlder'] as bool?
          : boundary?.hasMore;
      if (w.state.threadChannelId == scope.channel) {
        w.state.threadHistoryLimited = limited;
        if (more != null) w.state.threadHasMore = more;
      } else if (w.presentation.channel?.id == scope.channel) {
        w.state.historyLimited = limited;
        if (more != null) w.state.hasMore = more;
      }
      w.context.changed();
      await w.saveHistoryWindow(
        scope.channel,
        thread: w.state.threadChannelId == scope.channel,
      );
      return current();
    } on RaftApiException catch (error) {
      if (!current()) return false;
      failed?.call(error);
      if (target != null && error.status == 404) {
        // A missing target is not proof that its entire channel is revoked.
        // A complete page around its saved seq can confirm the deletion.
        final held = initial[target],
            sequence = BigInt.tryParse('${initial[target]?['seq']}');
        if (held != null && sequence != null) {
          return read(
            w,
            request,
            scope,
            ticket,
            before: sequence + BigInt.one,
            reason: reason,
            wireTicket: wireTicket,
            allowOnlineOnly: allowOnlineOnly,
            failed: failed,
          );
        }
      } else if (error.status == 403 || error.status == 404) {
        w.rejectHistoryRead(scope.channel);
        await w.entries.flushCache();
      }
      db.reads.count(HistoryReadReason.failed);
      return false;
    } catch (error) {
      // A transient read failure leaves the accepted local range on screen.
      if (current()) {
        failed?.call(error);
        db.reads.count(HistoryReadReason.failed);
      }
      return false;
    }
  }

  static Future<Map<String, Map<String, dynamic>?>> _online(
    MessageHistoryStorage db,
    MessageHistoryPage page,
    Map<String, Map<String, dynamic>> initial,
  ) async {
    // Keep the original request revision: replaying an old response under a
    // newly sampled revision could overwrite a newer event or resurrect a row.
    final merged = await db.reconcilePage(
      page.scope,
      page,
      requestedRevision: page.revision,
      before: page.before,
      after: page.after,
      focused: page.focused,
    );
    final raw = page.remotePage!['messages'] as List;
    final seqs = raw.map((row) => BigInt.parse('${row['seq']}')).toList()
      ..sort();
    final lower = page.after != null
        ? page.after! + BigInt.one
        : raw.length < page.limit || seqs.isEmpty
        ? BigInt.zero
        : seqs.first;
    final upper = page.before != null
        ? page.before! - BigInt.one
        : page.focused
        ? (seqs.isEmpty ? BigInt.zero : seqs.last)
        : historyMaxSequence;
    return {
      for (final row in initial.values)
        if (BigInt.parse('${row['seq']}') >= lower &&
            BigInt.parse('${row['seq']}') <= upper)
          row['id'] as String: null,
      for (final row in merged['messages'] as List)
        row['id'] as String: Map<String, dynamic>.from(row as Map),
    };
  }
}
