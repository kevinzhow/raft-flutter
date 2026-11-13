import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'channel_access_loss.dart';
import 'message_history_pages.dart';
import 'workspace_messages.dart';

/// Source messageStore `syncGap` (Web v1.24.0-source.1): one visible scope
/// reads `GET /messages/sync` from its window tail, or lower where a live
/// row shown across a seq jump still has its hole unconfirmed
/// ([LiveGapFill]), and merges what it returns into the held window.
abstract final class MessageGapSync {
  static Future<bool> run(
    WorkspaceMessages m,
    String id, {
    BigInt? since,
  }) async {
    // A channel this person was removed from: its sync is refused each time.
    if (ChannelAccessLoss.of(m.transport.client).isLost(id)) return true;
    final fill = LiveGapFill.of(m.ledger);
    final tail = m.messageWindows.newestVisibleSequence(id);
    final owed = fill.owedSince(id);
    var cursor = since ?? (owed != null && owed < tail ? owed : tail);
    if (cursor == BigInt.zero) return true;
    // One read per scope at a time: one asked for meanwhile runs after it.
    if (fill.joinInFlight(id, cursor)) return true;
    final read = fill.start(id), from = cursor, synced = <String>{};
    var outcome = GapReadOutcome.abandoned;
    final thread = id == m.state.threadChannelId;
    final owner = thread ? m.threadParentChannelId : id;
    final request = m.windowRequest(
      id,
      thread: thread,
      allowed: () => thread
          ? m.state.threadChannelId == id &&
                !m.messageWindows.contextHasNewer(id)
          : m.presentation.channel?.id == id && !m.state.hasNewer,
    );
    try {
      while (true) {
        final page = await MessageHistoryPages.read(
          m,
          request,
          id,
          thread: thread,
          after: cursor,
          limit: WorkspaceMessages.gapPageLimit,
          localFirst: false,
          remote: () async => {
            'messages': await m.transport.client.get(
              '/messages/sync',
              query: {
                'since_seq': '$cursor',
                'channel_id': id,
                'limit': WorkspaceMessages.gapPageLimit,
              },
            ),
          },
        );
        if (!request.current) return false;
        final listed = page['messages'] is List
            ? page['messages'] as List
            : const [];
        final rows = [
          for (final row in listed.whereType<Map>())
            if (row['channelId'] == id && row['id'] is String)
              Map<String, dynamic>.from(row),
        ];
        if (rows.isEmpty) break;
        final arrived = [
          for (final row in rows)
            if (!m.ledger.contains(id, row['id'] as String)) row,
        ];
        synced.addAll(rows.map((row) => row['id'] as String));
        m.messageWindows.acceptRows(request, id, rows);
        if (!await MessageHistoryPages.record(m, request, page)) return false;
        if (!request.current) return false;
        var next = cursor;
        for (final row in rows) {
          final seq = RaftMessage(row).seq;
          if (seq > next) next = seq;
        }
        if (m.channels.mayMarkRead(id) && !m.channels.scrolledAway.away(id)) {
          unawaited(m.entries.markRead(id));
        } else {
          arrived.forEach(m.channels.receiveUnread);
        }
        unawaited(m.saveWindow(id, thread: thread));
        m.context.changed();
        if (listed.length < WorkspaceMessages.gapPageLimit || next <= cursor) {
          break;
        }
        cursor = next;
      }
      fill.settle(id, from, read, synced);
      outcome = GapReadOutcome.read;
      return true;
    } on RaftApiException catch (e) {
      outcome = GapReadOutcome.failed;
      ChannelAccessLoss.of(m.transport.client).noteReadError(id, e);
      // Lost access is decided by the channel read and its revocation path.
      if (request.current &&
          owner != null &&
          (e.status == 403 || e.status == 404)) {
        unawaited(m.entries.refreshChannel(owner));
      }
      return false;
    } catch (_) {
      outcome = GapReadOutcome.failed;
      return false;
    } finally {
      // A read for a channel that is no longer on screen fills nothing: its
      // window is read again when it opens.
      if (outcome == GapReadOutcome.abandoned && !request.current) {
        fill.clear(id);
      }
      fill.finish(
        id,
        read,
        outcome,
        (since) => unawaited(run(m, id, since: since)),
      );
    }
  }
}
