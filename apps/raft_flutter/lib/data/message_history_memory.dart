import 'history_memory.dart';
import 'message_history.dart';
import 'message_history_pages.dart';
import 'workspace_message_host.dart';
import 'workspace_message_windows.dart';

/// Adapter for existing body owners. The pool stores no message authority.
class MessageHistoryMemory {
  static void sample(
    WorkspaceMessageHost host,
    Object owner,
    void Function() capture,
  ) {
    final w = host.messageDomain;
    return MessageHistoryPages.storage(w.device.cache)?.memory
        .samplePosition(owner, capture);
  }

  static void cancelSample(WorkspaceMessageHost host, Object owner) {
    final w = host.messageDomain;
    return MessageHistoryPages.storage(w.device.cache)?.memory
        .cancelSample(owner);
  }

  static void attach(WorkspaceMessageHost host, MessageHistoryStorage storage) {
    final w = host.messageDomain;
    if (w.source != null) return;
    storage.memory.register(
      w.context.receiverKey,
      HistoryMemoryPort(
        changes: w.notifications.changes,
        selected: () => w.presentation.foreground
            ? {w.presentation.channel?.id, w.state.threadChannelId}.nonNulls
            : const [],
        stamp: () => (
          w.ledger.revision,
          w.transport.client.origin,
          w.transport.client.user?.id,
          w.transport.client.serverId,
          w.presentation.channel?.id,
          w.state.threadChannelId,
          w.presentation.foreground,
          w.state.loadingOlder,
          w.state.channelLoading,
          w.state.threadLoading,
          w.messageWindows.accepted[w.presentation.channel?.id],
          w.messageWindows.accepted[w.state.threadChannelId],
          w.device.writable,
          w.state.highlightedMessageId,
        ),
        capture: () => capture(w, storage),
      ),
    );
  }

  static Future<List<HistoryMemoryWindow>> capture(
    WorkspaceMessageHost host,
    MessageHistoryStorage storage,
  ) async {
    final w = host.messageDomain;
    final result = <HistoryMemoryWindow>[];
    final generation = w.ledger.generation,
        origin = w.transport.client.origin,
        principal = w.transport.client.user?.id,
        server = w.transport.client.serverId,
        seal = w.messageHistoryTicket(''),
        main = w.presentation.channel?.id,
        thread = w.state.threadChannelId;
    bool current() =>
        w.device.writable &&
        generation == w.ledger.generation &&
        origin == w.transport.client.origin &&
        principal == w.transport.client.user?.id &&
        server == w.transport.client.serverId &&
        seal == w.messageHistoryTicket('') &&
        main == w.presentation.channel?.id &&
        thread == w.state.threadChannelId;
    if (principal == null || server == null || !current()) return result;
    // Resolve retained window snapshots once, then index their rows once.
    // Re-reading every snapshot for every channel makes a long session's
    // maintenance quadratic and repeatedly rebuilds inactive projections.
    final snapshots = w.messageWindows.retainedSnapshots.toList();
    final retained = <String, List<Map<String, dynamic>>>{};
    void retain(Map<String, dynamic> row) {
      if (row['channelId'] case final String id) {
        retained.putIfAbsent(id, () => []).add(row);
      }
    }

    for (final snapshot in snapshots) {
      for (final row in snapshot.rows.followedBy(snapshot.timeline)) {
        retain(row.json);
      }
    }
    for (final held in w.messageWindows.threads.values) {
      if (held.parent case final parent?) retain(parent.json);
    }
    for (final id in {
      ...w.ledger.channelIds,
      for (final snapshot in snapshots) ...[
        ?snapshot.channelId,
        ?snapshot.parent?.channelId,
      ],
      for (final thread in w.messageWindows.threads.values)
        thread.parentChannelId,
      ...w.state.messageSync.channelIds,
    }) {
      if (!current()) break;
      if (!w.messageWindows.notRevoked(id)) continue;
      final heldThread = w.messageWindows.threads.values
          .where((held) => held.threadChannelId == id)
          .firstOrNull;
      var scope = MessageHistoryPages.scope(
        w,
        id,
        parent: id == thread
            ? w.threadParentChannelId
            : heldThread?.parentChannelId ?? id,
        parentMessage: id == thread ? w.threadParentMessageId : null,
      );
      if (scope == null) {
        final known = await storage.knownScope(origin, principal, server, id);
        if (!current()) return [];
        if (known != null) {
          scope = MessageHistoryPages.scope(
            w,
            id,
            parent: known.parentChannel,
            parentMessage: known.parentMessage,
          );
        }
      }
      if (scope == null || !current()) continue;
      final ticket = w.messageHistoryTicket(scope.parentChannel);
      final versions = _versions(w, id, retained: retained[id] ?? const []);
      if (versions.isEmpty) continue;
      final active = w.presentation.foreground && (id == main || id == thread);
      final anchor = w.messageWindows.readingAnchor(id);
      var anchorId = anchor == null
          ? null
          : versions.entries
                .where(
                  (entry) =>
                      w.messageKey(
                        w.messageWindows.presented(entry.value.first),
                      ) ==
                      anchor.messageKey,
                )
                .firstOrNull
                ?.key;
      final membership = w.messageWindows.accepted[id];
      final displayed = w.messageWindows.rows(id);
      // Restored contexts may coexist with a cached tail before a view reports
      // geometry. An absent/stale view anchor cannot select that hidden tail.
      if (active &&
          displayed.isNotEmpty &&
          displayed.length <= storage.memory.activeLimit &&
          !displayed.any((row) => row.id == anchorId)) {
        anchorId = displayed[displayed.length ~/ 2].id;
      }
      final highlighted = w.state.highlightedMessageId;
      final protected = <String>{
        ?highlighted,
        if (w.state.threadParent?.channelId == id) w.state.threadParent!.id,
        for (final sends in w.drafts.composer.sends.pending.values)
          for (final send in sends)
            if ((send.channelId ?? send.row.channelId) == id) send.row.id,
      };
      bool admitted() =>
          current() &&
          w.messageWindows.notRevoked(id) &&
          identical(anchor, w.messageWindows.readingAnchor(id)) &&
          identical(membership, w.messageWindows.accepted[id]) &&
          ticket == w.messageHistoryTicket(scope!.parentChannel);
      result.add(
        HistoryMemoryWindow(
          scope: scope,
          versions: versions,
          active: active,
          paused:
              active &&
              (w.state.loadingOlder ||
                  (id == main
                      ? w.state.channelLoading
                      : w.state.threadLoading)),
          anchor: anchorId,
          protectedIds: protected,
          current: admitted,
          release: (ids) {
            if (!admitted()) return {};
            final fresh = _versions(w, id);
            final released = ids
                .where(
                  (key) =>
                      fresh[key]?.every(
                        (row) =>
                            versions[key]?.any(
                              (held) => identical(held, row),
                            ) ==
                            true,
                      ) ==
                      true,
                )
                .toSet();
            if (released.isEmpty) return released;
            final boundary = _releaseBodies(w, id, released);
            w.state.messageSync.releaseBodies(id, released);
            if (id == main) {
              w.state.hasMore = w.state.hasMore || boundary.older;
              w.state.hasNewer = w.state.hasNewer || boundary.newer;
            }
            if (id == thread) {
              w.state.threadHasMore = w.state.threadHasMore || boundary.older;
            }
            w.context.changed();
            return released;
          },
        ),
      );
    }
    return result;
  }

  static Map<String, List<Map<String, dynamic>>> _versions(
    WorkspaceMessageHost host,
    String id, {
    Iterable<Map<String, dynamic>>? retained,
  }) {
    final w = host.messageDomain;
    final result = <String, List<Map<String, dynamic>>>{};
    void add(Map<String, dynamic> row) {
      final key = row['id'];
      if (row['channelId'] != id || key is! String) return;
      final copies = result.putIfAbsent(key, () => []);
      if (!copies.any((copy) => identical(copy, row))) copies.add(row);
    }

    for (final row in w.ledger.messages(id)) {
      add(row);
    }
    if (retained != null) {
      retained.forEach(add);
    } else {
      for (final snapshot in w.messageWindows.retainedSnapshots) {
        for (final row in snapshot.rows.followedBy(snapshot.timeline)) {
          add(row.json);
        }
      }
      for (final thread in w.messageWindows.threads.values) {
        if (thread.parent case final parent?) add(parent.json);
      }
    }
    for (final row in w.state.messageSync.messages(id)) {
      final copies = result.putIfAbsent(row['id'] as String, () => []);
      if (!copies.any((copy) => identical(copy, row))) copies.add(row);
    }
    return result;
  }

  static ({bool older, bool newer}) _releaseBodies(
    WorkspaceMessageHost host,
    String id,
    Set<String> ids,
  ) {
    final w = host.messageDomain;
    final owner = w.messageWindows, visible = w.messageWindows.rows(id);
    final kept = visible.where((row) => !ids.contains(row.id)).toList();
    final older = visible.any(
      (row) =>
          ids.contains(row.id) && (kept.isEmpty || row.seq < kept.first.seq),
    );
    final newer = visible.any(
      (row) =>
          ids.contains(row.id) && (kept.isEmpty || row.seq > kept.last.seq),
    );
    final accepted = owner.accepted[id];
    if (accepted != null) {
      owner.rememberWindow(
        liveWindowWrite,
        id,
        accepted.authority,
        older || accepted.hasMore,
        accepted.token,
        historyLimited: accepted.historyLimited,
      );
      owner.setContextMode(
        liveWindowWrite,
        id,
        newer ? true : accepted.contextNewer,
      );
    }
    w.ledger.releaseBodies(id, ids);
    owner.visibleIds[id]?.removeAll(ids);
    for (final entry in owner.threads.entries.toList()) {
      final held = entry.value;
      var next = held;
      if (held.parentChannelId == id && ids.contains(held.parent?.id)) {
        next = next.withParent(null);
      }
      if (held.threadChannelId == id && (older || newer)) {
        next = next.withBoundary(
          more: older || held.hasMore,
          context: newer || held.contextWindow,
        );
      }
      if (!identical(held, next)) {
        owner.cacheThread(liveWindowWrite, entry.key, next);
      }
    }
    return (older: older, newer: newer);
  }
}
