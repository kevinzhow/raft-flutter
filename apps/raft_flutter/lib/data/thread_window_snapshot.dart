import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'conversation_window.dart';
import 'message_window_snapshot.dart';

/// Accepted paging facts returned to the presentation adapter.
typedef ThreadPageBoundary = ({bool more, bool limited});

/// Cached identity and boundary facts are immutable; only this owner updates
/// independently resolved parent metadata through its admission boundary.
class CachedMessageThread {
  CachedMessageThread(
    this.parentChannelId,
    this.threadChannelId,
    this.token,
    this.authority,
    this.generation,
    this.hasMore,
    this.historyLimited,
    this.parent, {
    this.contextWindow = false,
  });
  final bool contextWindow;
  final String parentChannelId, threadChannelId, token;
  final String? authority;
  final int generation;
  final bool hasMore, historyLimited;
  final RaftMessage? parent;

  bool matches(
    String channel,
    String? replyToken,
    String? resourceAuthority,
    int epoch,
  ) =>
      parentChannelId == channel &&
      token == replyToken &&
      authority == resourceAuthority &&
      generation == epoch;

  CachedMessageThread withParent(RaftMessage? value) => CachedMessageThread(
    parentChannelId,
    threadChannelId,
    token,
    authority,
    generation,
    hasMore,
    historyLimited,
    value,
    contextWindow: contextWindow,
  );

  CachedMessageThread withBoundary({required bool more, required bool context}) =>
    CachedMessageThread(parentChannelId, threadChannelId, token, authority,
      generation, more, historyLimited, parent, contextWindow: context);
}

/// Tail refreshes retain only history before the refreshed page. A focused
/// context or an explicit access limit has its own authoritative membership.
({
  List<Map<String, dynamic>> rows,
  Set<String> visible,
  bool more,
  bool limited,
})
reconcileThreadPage(
  Map<String, dynamic> page,
  String id, {
  required Iterable<Map<String, dynamic>> retained,
  required bool retainedHasMore,
  required bool focused,
}) {
  final fresh = acceptedWindowRows(page['messages'], id);
  final limited = page['historyLimited'] == true;
  final visible = focused || limited
      ? fresh.map((row) => row['id'] as String).toSet()
      : reconcileTailWindow(retained, fresh);
  return (
    rows: fresh,
    visible: visible,
    more: focused
        ? page['hasOlder'] == true
        : !limited &&
              (visible.length > fresh.length
                  ? retainedHasMore
                  : fresh.length >= 50),
    limited: limited,
  );
}

/// Resident conversation windows.
///
/// The read regression keeps 51 windows open, so the cap sits one step above
/// that. An app left on a busy server otherwise keeps every channel it has
/// opened; a Mac profile of that path climbed from 9 windows to 176.
const cachedConversationWindowLimit = 64;

final _appliedRevision = Expando<int>('conversation window revision');

/// Windows a ledger notification must refresh.
///
/// A message refreshes its channel and the parent of a thread that received
/// it. A cleared channel, a permission notification, or a gap in the change
/// record refreshes every open window. The applied revision is registered
/// with the ledger, so an attachment read cannot drop unseen changes. That
/// registration does not itself discard the record.
List<T> dueWindows<T extends ConversationWindow>(
  MessageLedger ledger,
  Map<ConversationWindowScope, T> windows,
  Map<String, CachedMessageThread> threads,
) {
  final open = windows.values.toList();
  final since = _appliedRevision[windows];
  final revision = ledger.revision;
  final changes = since == null ? null : ledger.changesAfter(since);
  _appliedRevision[windows] = revision;
  ledger.noteChangesRead(windows, revision);
  if (changes == null ||
      changes.isEmpty ||
      changes.last.revision != revision ||
      changes.any((change) => change.messageId == null)) {
    return open;
  }
  final channels = <String>{for (final change in changes) change.channelId};
  for (final thread in threads.values) {
    if (channels.contains(thread.threadChannelId)) {
      channels.add(thread.parentChannelId);
    }
  }
  return [
    for (final window in open)
      if (channels.contains(window.scope.channelId)) window,
  ];
}

/// Keeps [scope] newest and drops the oldest inactive projections past the cap.
///
/// Dropped windows are retired. Their ledger rows stay, so opening the same
/// scope again reads those rows back. The window on screen is not dropped.
T holdWindow<T extends ConversationWindow>(
  Map<ConversationWindowScope, T> windows,
  ConversationWindowScope scope,
  (bool, bool) Function(ConversationWindowScope) layout,
  void Function(T window) retire,
  T Function() create,
) {
  final window = windows.remove(scope) ?? create();
  windows[scope] = window;
  for (final old in _lruDrop(windows, layout)) {
    final dropped = windows.remove(old);
    if (dropped != null) retire(dropped);
  }
  return window;
}

List<ConversationWindowScope> _lruDrop<T extends ConversationWindow>(
  Map<ConversationWindowScope, T> windows,
  (bool, bool) Function(ConversationWindowScope) layout,
) {
  final extra = windows.length - cachedConversationWindowLimit;
  if (extra <= 0) return const [];
  final drop = <ConversationWindowScope>[];
  for (final scope in windows.keys) {
    if (drop.length == extra) break;
    if (layout(scope).$1) continue;
    drop.add(scope);
  }
  return drop;
}
