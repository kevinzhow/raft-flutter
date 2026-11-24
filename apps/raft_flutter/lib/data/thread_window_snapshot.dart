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

  CachedMessageThread withBoundary({
    required bool more,
    required bool context,
  }) => CachedMessageThread(
    parentChannelId,
    threadChannelId,
    token,
    authority,
    generation,
    more,
    historyLimited,
    parent,
    contextWindow: context,
  );

  AcceptedMessageWindow toAcceptedWindow() => AcceptedMessageWindow(
    authority ?? '',
    hasMore,
    token,
    historyLimited,
    contextWindow ? true : null,
  );
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
final _authorityStampFn = Expando<Object Function()>(
  'window authority stamp fn',
);
final _lastAuthorityStamp = Expando<Object>('last window authority stamp');
final _dirtyChannels = Expando<Set<String>>('dirty window channels');
final _dirtyAll = Expando<bool>('all windows dirty');
final _newestSeqCache = Expando<(int revision, int count, BigInt seq)>(
  'newest visible sequence cache',
);

void initWindowTracking(Object windows, Object Function()? stampFn) {
  if (stampFn != null) {
    _authorityStampFn[windows] = stampFn;
    _lastAuthorityStamp[windows] = stampFn();
  }
}

void markWindowChannelDirty(Object windows, String channelId) =>
    (_dirtyChannels[windows] ??= <String>{}).add(channelId);

void markAllWindowsDirty(Object windows) => _dirtyAll[windows] = true;

BigInt cachedNewestVisibleSequence(
  MessageLedger ledger,
  Map<String, Set<String>> visibleIds,
  String id,
  RaftMessage Function(Map<String, dynamic>) presented,
) {
  final visible = visibleIds[id];
  if (visible == null || visible.isEmpty) return BigInt.zero;
  final revision = ledger.revision;
  final cached = _newestSeqCache[visible];
  if (cached != null && cached.$1 == revision && cached.$2 == visible.length) {
    return cached.$3;
  }
  var latest = BigInt.zero;
  for (final key in visible) {
    final row = ledger.message(id, key);
    if (row != null) {
      final seq = presented(row).seq;
      if (seq > latest) latest = seq;
    }
  }
  _newestSeqCache[visible] = (revision, visible.length, latest);
  return latest;
}

bool fillWindowGapFromLedger(
  MessageLedger ledger,
  Map<String, Set<String>> visibleIds,
  String id,
  String liveId,
  RaftMessage Function(Map<String, dynamic>) presented, {
  BigInt? newest,
}) {
  final visible = visibleIds[id];
  if (visible == null || visible.isEmpty) return false;
  final frontier =
      newest ?? cachedNewestVisibleSequence(ledger, visibleIds, id, presented);
  if (frontier == BigInt.zero) return false;
  var gap = false;
  for (final row in ledger.messagesAfterSequence(id, frontier)) {
    final rowId = row['id'];
    if (rowId is String && rowId != liveId && !visible.contains(rowId)) {
      visible.add(rowId);
      gap = true;
    }
  }
  return gap;
}

/// Windows a ledger notification must refresh.
///
/// A message refreshes its channel and the parent of a thread that received
/// it. An unchanged ledger revision refreshes nothing. A cleared channel, a
/// permission notification, or a gap in the change record refreshes every open
/// window. The applied revision is registered with the ledger, so an
/// attachment read cannot drop unseen changes. That registration does not
/// itself discard the record.
List<T> dueWindows<T extends ConversationWindow>(
  MessageLedger ledger,
  Map<ConversationWindowScope, T> windows,
  Map<String, CachedMessageThread> threads,
) {
  final since = _appliedRevision[windows];
  final revision = ledger.revision;
  if (windows.isEmpty || (since != null && since == revision)) {
    _appliedRevision[windows] = revision;
    ledger.noteChangesRead(windows, revision);
    return const [];
  }
  final open = windows.values.toList();
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

/// Returns only the cached windows whose ledger, authority, selection, pending
/// sends, or local window state may have changed since the last synchronize.
List<T> windowsDueForSync<T extends ConversationWindow>(
  MessageLedger ledger,
  Map<ConversationWindowScope, T> windows,
  Map<String, CachedMessageThread> threads, {
  required (bool, bool) Function(ConversationWindowScope) layout,
  required Iterable<String> pendingScopes,
}) {
  final ledgerDue = dueWindows(ledger, windows, threads);
  final stamp = _authorityStampFn[windows]?.call();
  final stampChanged = stamp != null && stamp != _lastAuthorityStamp[windows];
  if (stamp != null) _lastAuthorityStamp[windows] = stamp;
  final allDirty = _dirtyAll[windows] == true;
  _dirtyAll[windows] = false;
  final dirty = _dirtyChannels[windows];
  if (windows.isEmpty) {
    dirty?.clear();
    return const [];
  }
  if (stampChanged || allDirty) {
    dirty?.clear();
    return windows.values.toList();
  }
  final pendingSet = pendingScopes.isEmpty ? null : pendingScopes.toSet();
  final due = <T>[];
  final seen = <ConversationWindowScope>{};
  for (final window in ledgerDue) {
    if (seen.add(window.scope)) due.add(window);
  }
  for (final window in windows.values) {
    final scope = window.scope;
    if (seen.contains(scope)) continue;
    final selected = layout(scope).$1;
    final dirtyChannel = dirty != null && dirty.contains(scope.channelId);
    final sendScope = scope.parentMessageId == null
        ? scope.channelId
        : 'thread:${scope.parentMessageId}';
    if (selected ||
        dirtyChannel ||
        (pendingSet != null && pendingSet.contains(sendScope))) {
      seen.add(scope);
      due.add(window);
    }
  }
  dirty?.clear();
  return due;
}

Future<String?> runDedupedWindowRequest(
  Map<Object, Future<String?>?> requests,
  Object key,
  Future<String?> Function() create,
) async {
  final held = requests[key];
  if (held != null) return held;
  final request = requests[key] = create();
  try {
    return await request;
  } finally {
    if (identical(requests[key], request)) requests.remove(key);
  }
}

List<RaftMessage> readWindowRows(
  MessageLedger ledger,
  Map<String, Set<String>> visibleIds,
  String id,
  RaftMessage Function(Map<String, dynamic>) presented,
) {
  final visible = visibleIds[id];
  if (visible == null || visible.isEmpty) return const [];
  return [
    for (final row in ledger.messages(id))
      if (visible.contains(row['id'])) presented(row),
  ];
}

ConversationWindowSnapshot buildCachedWindowSnapshot(
  ConversationWindowScope scope,
  CachedMessageThread? held,
  Map<String, AcceptedMessageWindow> accepted,
  List<RaftMessage> Function(String? id) rowsOf,
  List<RaftMessage> Function(
    List<RaftMessage> rows,
    String? scope, {
    bool context,
  })
  projectRows,
  bool Function(String? id) contextHasNewer,
  bool Function(String? id) historyLimit,
) {
  final main = scope.parentMessageId == null;
  final id = main ? scope.channelId : held?.threadChannelId;
  final acceptedRows = rowsOf(id);
  final newer = contextHasNewer(id);
  return ConversationWindowSnapshot(
    channelId: id,
    rows: acceptedRows,
    timeline: projectRows(
      acceptedRows,
      main ? scope.channelId : 'thread:${scope.parentMessageId}',
      context: newer,
    ),
    parent: main ? null : held?.parent,
    hasMore: main ? accepted[id]?.hasMore == true : held?.hasMore == true,
    hasNewer: newer,
    historyLimited: main ? historyLimit(id) : held?.historyLimited == true,
  );
}

ThreadPageBoundary applyThreadPageUpdate(
  String id,
  Map<String, dynamic> page,
  Map<String, AcceptedMessageWindow> accepted,
  List<RaftMessage> Function(String id) rowsOf, {
  required bool focused,
  required bool retainOlder,
  required bool retainedHasMore,
  required void Function(
    Iterable<Map<String, dynamic>> rows,
    Iterable<String> visible,
  )
  accept,
}) {
  final next = reconcileThreadPage(
    page,
    id,
    retained: retainOlder ? rowsOf(id).map((m) => m.json) : const [],
    retainedHasMore: accepted[id]?.hasMore ?? retainedHasMore,
    focused: focused,
  );
  accept(next.rows, next.visible);
  return (more: next.more, limited: next.limited);
}

void rememberAcceptedWindow(
  Map<String, AcceptedMessageWindow> accepted,
  String id,
  String authority,
  bool more,
  String token,
  bool historyLimited,
) {
  accepted[id] = AcceptedMessageWindow(
    authority,
    more,
    token,
    historyLimited,
    accepted[id]?.contextNewer,
  );
}

bool retainsLiveTailWindow(
  String id,
  AcceptedMessageWindow? held,
  MessageWindowAuthority? facts,
  Set<String>? visible,
  bool diskOnly,
) =>
    held != null &&
    held.contextNewer == null &&
    !diskOnly &&
    (visible?.isNotEmpty ?? false) &&
    held.matches(facts?.$4, facts?.$3);

CachedMessageThread? matchCachedThread(
  CachedMessageThread? held,
  String channelId,
  String? token,
  String? authority,
  int generation,
  bool Function(String) notRevoked,
) =>
    held != null &&
        held.matches(channelId, token, authority, generation) &&
        notRevoked(held.threadChannelId)
    ? held
    : null;

void retireAllWindows(Map<ConversationWindowScope, dynamic> windows) {
  for (final window in windows.values) {
    window.retire(notify: false);
  }
  windows.clear();
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
