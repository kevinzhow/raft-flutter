// Client of GET /api/sync/changes (Web store/syncChangesClient.ts at
// v1.24.0-source.1; contract shared/src/syncChanges.ts, shared with the
// mobile app). One session per server.
//
// A change is applied as "reload what it touches", coalesced per snapshot. A
// `conversation` change that carries its current state may be patched in
// place by the caller ([SyncChangesSession.applyConversation]); otherwise it
// reloads the inbox, unread and followed-thread lists. A `message` change
// replaces a held message by id.
//
// Order (contract): take the cursor first, then the snapshots, then pull from
// the cursor. Pull failures: a transient one (no answer, 5xx, 408, 429) keeps
// the cursor and pulls once more 30-60 s later; the second in a row on the
// same cursor, and every other failure, drops it ([SyncPullResult.dropped]:
// the caller reloads everything and takes a new cursor next time).
import 'dart:async';
import 'dart:math';

/// The snapshots the contract names (`SYNC_SNAPSHOT_ENDPOINTS`).
enum SyncListSnapshot {
  channels('channels'),
  channelMembers('channel_members'),
  serverMembers('server_members'),
  agents('agents'),
  inbox('inbox'),
  unread('unread'),
  followedThreads('followed_threads'),
  machines('machines'),
  sidebarOrder('sidebar_order'),
  serverOrder('server_order');

  const SyncListSnapshot(this.wire);
  final String wire;

  static SyncListSnapshot? fromWire(Object? name) {
    for (final value in values) {
      if (value.wire == name) return value;
    }
    return null;
  }
}

/// Why a whole list is read again (Web ListFetchReason, sent as
/// `X-Raft-Fetch-Reason` where the loader supports it).
abstract final class SyncFetchReason {
  static const reconnect = 'reconnect';
  static const syncReset = 'sync_reset';
  static const legacyNoFields = 'legacy_no_fields';
  static const unpatchable = 'sync_unpatchable';
}

const _rowEntitySnapshot = {
  'channel': SyncListSnapshot.channels,
  'channel_member': SyncListSnapshot.channelMembers,
  'server_member': SyncListSnapshot.serverMembers,
  'agent': SyncListSnapshot.agents,
  'machine': SyncListSnapshot.machines,
  'sidebar_order': SyncListSnapshot.sidebarOrder,
  'server_order': SyncListSnapshot.serverOrder,
};

const conversationSnapshots = [
  SyncListSnapshot.inbox,
  SyncListSnapshot.unread,
  SyncListSnapshot.followedThreads,
];

/// The viewer's current state of one conversation as a `conversation` change
/// carries it (Activity multi-device spec v3 §4.2).
class SyncConversationState {
  const SyncConversationState({this.read, this.done, this.follow});

  final ({int readSeq, int readStateVersion, bool markedUnread})? read;
  final ({bool done, String? doneFrontierSeq})? done;
  final ({bool followed, bool threadDone})? follow;

  /// Each page carries only the kinds that changed in it: the later part wins.
  SyncConversationState merge(SyncConversationState later) =>
      SyncConversationState(
        read: later.read ?? read,
        done: later.done ?? done,
        follow: later.follow ?? follow,
      );
}

bool _count(Object? value) => value is int && value >= 0;

/// The state a change carries, or null when it carries none this client can
/// use. A part that is present but malformed makes the whole change a reload.
SyncConversationState? readSyncConversationState(Map change) {
  ({int readSeq, int readStateVersion, bool markedUnread})? read;
  ({bool done, String? doneFrontierSeq})? done;
  ({bool followed, bool threadDone})? follow;
  if (change.containsKey('read')) {
    final value = change['read'];
    if (value is! Map ||
        !_count(value['readSeq']) ||
        !_count(value['readStateVersion'])) {
      return null;
    }
    read = (
      readSeq: value['readSeq'] as int,
      readStateVersion: value['readStateVersion'] as int,
      markedUnread: value['markedUnread'] == true,
    );
  }
  if (change.containsKey('done')) {
    final value = change['done'];
    if (value is! Map || value['done'] is! bool) return null;
    final frontier = value['doneFrontierSeq'];
    if (frontier != null &&
        (frontier is! String || !RegExp(r'^[0-9]+$').hasMatch(frontier))) {
      return null;
    }
    done = (done: value['done'] as bool, doneFrontierSeq: frontier as String?);
  }
  if (change.containsKey('follow')) {
    final value = change['follow'];
    if (value is! Map ||
        value['followed'] is! bool ||
        value['threadDone'] is! bool) {
      return null;
    }
    follow = (
      followed: value['followed'] as bool,
      threadDone: value['threadDone'] as bool,
    );
  }
  if (read == null && done == null && follow == null) return null;
  return SyncConversationState(read: read, done: done, follow: follow);
}

/// More channel upserts than this in one pull: read the channel lists instead.
const syncChannelRowRefreshLimit = 20;

/// Pages of one pull before giving up and taking every snapshot.
const syncMaxPages = 20;

/// Consecutive transient failures on one cursor before it is dropped.
const syncPullFailuresToDrop = 2;

/// After a kept pull, pull once more after min + random * spread (30-60 s).
const syncPullRetryMin = Duration(seconds: 30);
const syncPullRetrySpread = Duration(seconds: 30);

/// A hung request must not hold the loads waiting on it.
const syncChangesTimeout = Duration(seconds: 5);

/// What a page (or a whole pull) of changes asks the client to do.
class SyncChangesPlan {
  final snapshots = <SyncListSnapshot>{};

  /// Channel rows to re-read one by one (upserts).
  final channelIds = <String>{};

  /// Channels whose member roster changed.
  final memberChannelIds = <String>{};

  /// Conversations whose current state came with the change, newest per id.
  final conversations = <String, SyncConversationState>{};
  final reasons = <SyncListSnapshot, String>{};

  /// Channels the viewer gained or lost, the latest op per id.
  final channelScopes = <String, String>{};

  /// Messages changed in place (`message` upserts), newest per id.
  final messages = <String, Map<String, dynamic>>{};

  void addAll() {
    snapshots.addAll(SyncListSnapshot.values);
  }

  /// Snapshot names from the server: an unknown one means "every snapshot".
  void addNames(Object? names) {
    if (names is! List) return;
    for (final name in names) {
      final known = SyncListSnapshot.fromWire(name);
      if (known == null) {
        addAll();
      } else {
        snapshots.add(known);
      }
    }
  }
}

/// What a page of changes asks the client to reload. Pure.
SyncChangesPlan planSyncChanges(List changes, [SyncChangesPlan? into]) {
  final plan = into ?? SyncChangesPlan();
  for (final raw in changes) {
    if (raw is! Map) continue;
    final entity = raw['entity'], op = raw['op'], id = raw['id'];
    if (id is! String) continue;
    if (entity == 'conversation') {
      final state = op == 'stale' ? readSyncConversationState(raw) : null;
      if (state != null) {
        final previous = plan.conversations.remove(id);
        plan.conversations[id] = previous?.merge(state) ?? state;
        continue;
      }
      // No state, or an op this client doesn't know (= resnapshot): reload.
      for (final name in conversationSnapshots) {
        plan.snapshots.add(name);
        plan.reasons[name] = SyncFetchReason.legacyNoFields;
      }
      continue;
    }
    if (entity == 'scope') {
      plan.addNames(raw['snapshots']);
      if (raw['scopeKind'] == 'channel' && (op == 'added' || op == 'removed')) {
        plan.channelScopes.remove(id);
        plan.channelScopes[id] = op as String;
      }
      // Removed: drop what was held under it; reading the lists drops it.
      if (op != 'added') {
        if (raw['scopeKind'] == 'server') {
          plan.snapshots.add(SyncListSnapshot.serverOrder);
        } else {
          plan.snapshots.addAll(const [
            SyncListSnapshot.channels,
            SyncListSnapshot.inbox,
            SyncListSnapshot.unread,
          ]);
        }
      }
      continue;
    }
    if (entity == 'message') {
      // Upserts only, each the message list's row; a row that is not this
      // message's is dropped (the live update or the next read brings it).
      final row = op == 'upsert' ? raw['row'] : null;
      if (row is Map && row['id'] == id && row['channelId'] is String) {
        plan.messages.remove(id);
        plan.messages[id] = Map<String, dynamic>.from(row);
      }
      continue;
    }
    final snapshot = _rowEntitySnapshot[entity];
    // Unknown entity: skip (contract).
    if (snapshot == null) continue;
    // Known entity, unknown op: resnapshot that entity (contract).
    if (op != 'upsert' && op != 'delete') {
      plan.snapshots.add(snapshot);
      continue;
    }
    if (entity == 'channel') {
      if (op == 'upsert') {
        plan.channelIds.add(id);
      } else {
        plan.snapshots.add(SyncListSnapshot.channels);
      }
      continue;
    }
    if (entity == 'channel_member') {
      final channelId = id.split(':').first;
      if (channelId.isNotEmpty) {
        plan.memberChannelIds.add(channelId);
        // The channel row carries the member count.
        plan.channelIds.add(channelId);
      }
      continue;
    }
    plan.snapshots.add(snapshot);
  }
  if (plan.channelIds.length > syncChannelRowRefreshLimit) {
    plan.snapshots.add(SyncListSnapshot.channels);
    plan.channelIds.clear();
  }
  return plan;
}

/// Reload one snapshot. [settleInFlight] lets a load already in flight land
/// first; [load] gets the reason a whole list is read, when known.
class SyncSnapshotLoader {
  const SyncSnapshotLoader({required this.load, this.settleInFlight});
  final FutureOr<void> Function(String? reason) load;
  final Future<void> Function()? settleInFlight;
}

/// `since` null asks for the current cursor only. The answer is the decoded
/// JSON body; an error is classified by [SyncChangesSession.isTransient].
typedef SyncChangesFetch = Future<Object?> Function(String? since);

enum SyncPullResult { applied, kept, dropped }

/// Reloads per snapshot, one at a time each: a request while one runs marks
/// it dirty and it runs again after, so the last read starts after the last
/// change it has to reflect.
class _SnapshotRunner {
  _SnapshotRunner(this.loaders, this.disposed);
  final Map<SyncListSnapshot, SyncSnapshotLoader> loaders;
  final bool Function() disposed;
  final _running = <SyncListSnapshot, Future<void>>{};
  final _dirty = <SyncListSnapshot>{};
  final _reasons = <SyncListSnapshot, String?>{};

  Future<void> request(SyncListSnapshot name, [String? reason]) {
    _reasons[name] = reason;
    final current = _running[name];
    if (current != null) {
      _dirty.add(name);
      return current;
    }
    final run = () async {
      try {
        do {
          _dirty.remove(name);
          final loader = loaders[name];
          if (loader == null || disposed()) break;
          try {
            await loader.settleInFlight?.call();
            if (disposed()) break;
            await loader.load(_reasons[name]);
          } catch (_) {
            // The list keeps what it shows; the next change or reconnect
            // reads again.
          }
        } while (_dirty.contains(name));
      } finally {
        _running.remove(name);
      }
    }();
    _running[name] = run;
    return run;
  }
}

class SyncChangesSession {
  SyncChangesSession({
    required this.serverId,
    required this.fetch,
    required this.loaders,
    required this.refreshChannel,
    required this.notifyChannelMembers,
    required this.isTransient,
    this.applyConversation,
    this.applyMessage,
    this.deferReset,
    this.onCursorDropped,
    this.channelScopeChanged,
    Timer Function(Duration, void Function())? timer,
    Random? random,
  }) : _timer = timer ?? Timer.new,
       _random = random ?? Random() {
    _runner = _SnapshotRunner(loaders, () => _disposed);
  }

  final String serverId;
  final SyncChangesFetch fetch;
  final Map<SyncListSnapshot, SyncSnapshotLoader> loaders;
  final FutureOr<void> Function(String channelId) refreshChannel;
  final void Function(String channelId) notifyChannelMembers;

  /// No answer, 5xx, 408, 429 and the client's own timeout: the cursor may
  /// still be good. Everything else drops it.
  final bool Function(Object error) isTransient;

  /// Patch one conversation in place; false (or absent) reads the inbox,
  /// unread and followed-thread lists again.
  final bool Function(String channelId, SyncConversationState state)?
  applyConversation;

  /// Replace a held message by id with its current row.
  final void Function(Map<String, dynamic> row)? applyMessage;

  /// Run a reset's snapshots later (a reset can reach every client at once).
  final void Function(void Function() run, Set<SyncListSnapshot> snapshots)?
  deferReset;

  /// A pull ended without a cursor: read every list again.
  final void Function()? onCursorDropped;

  /// The viewer gained (`added`) or lost (`removed`) one channel.
  final void Function(String channelId, String op)? channelScopeChanged;

  final Timer Function(Duration, void Function()) _timer;
  final Random _random;
  late final _SnapshotRunner _runner;

  String? _cursor;
  int _failures = 0;
  Future<SyncPullResult>? _pulling;
  bool _pullAgain = false;
  Timer? _retry;
  bool _disposed = false;

  bool get hasCursor => _cursor != null;
  bool get disposed => _disposed;

  /// The delayed pull after a kept failure is pending.
  bool get retryPending => _retry != null;

  void dispose() {
    _disposed = true;
    _cancelRetry();
    _setCursor(null);
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
  }

  void _setCursor(String? cursor) {
    _cursor = cursor;
    _failures = 0;
  }

  /// Read every snapshot after the cursor, except [except].
  void resnapshotAll(String reason, {Set<SyncListSnapshot> except = const {}}) {
    if (_disposed) return;
    for (final name in SyncListSnapshot.values) {
      if (!except.contains(name)) unawaited(_runner.request(name, reason));
    }
  }

  /// Take a cursor (step 1). False when the server has none for us.
  Future<bool> start() async {
    try {
      final response = await fetch(null);
      final cursor = response is Map ? response['cursor'] : null;
      if (_disposed || cursor is! String) return false;
      _setCursor(cursor);
      return true;
    } catch (_) {
      _setCursor(null);
      return false;
    }
  }

  /// Pull everything since the cursor and apply it. A pull asked for while
  /// one runs joins it and, when it applied, pulls once more after it.
  Future<SyncPullResult> pull() {
    final pulling = _pulling;
    if (pulling != null) {
      _pullAgain = true;
      return pulling;
    }
    // Any pull replaces the delayed one: at most one is ever pending.
    _cancelRetry();
    final run = () async {
      try {
        SyncPullResult result;
        do {
          _pullAgain = false;
          result = await _pullOnce();
        } while (result == SyncPullResult.applied && _pullAgain && !_disposed);
        if (_disposed) return result;
        if (result == SyncPullResult.dropped) onCursorDropped?.call();
        // No loop: this cursor has one failure now, so the delayed pull
        // either succeeds or drops it.
        if (result == SyncPullResult.kept) {
          final delay =
              syncPullRetryMin + syncPullRetrySpread * _random.nextDouble();
          _retry = _timer(delay, () {
            _retry = null;
            unawaited(pull());
          });
        }
        return result;
      } finally {
        _pulling = null;
      }
    }();
    _pulling = run;
    return run;
  }

  Future<SyncPullResult> _pullOnce() async {
    var cursor = _cursor;
    if (cursor == null || _disposed) return SyncPullResult.dropped;
    final plan = SyncChangesPlan();
    var wasReset = false;
    try {
      var pages = 0;
      while (true) {
        final response = await fetch(cursor);
        if (_disposed) return SyncPullResult.dropped;
        final next = response is Map ? response['cursor'] : null;
        if (response is! Map || next is! String) {
          throw const FormatException('sync/changes: no cursor');
        }
        final reset = response['reset'];
        if (reset is Map) {
          plan.addNames(reset['snapshots']);
          for (final name in plan.snapshots) {
            plan.reasons[name] = SyncFetchReason.syncReset;
          }
          wasReset = true;
          plan.channelIds.clear();
          plan.memberChannelIds.clear();
          plan.conversations.clear();
          // Message rows gathered before the reset stay: no snapshot brings
          // them again.
          cursor = next;
          break;
        }
        final changes = response['changes'];
        planSyncChanges(changes is List ? changes : const [], plan);
        cursor = next;
        if (response['hasMore'] != true) break;
        pages += 1;
        if (pages >= syncMaxPages) {
          for (final name in SyncListSnapshot.values) {
            plan.snapshots.add(name);
            plan.reasons[name] = SyncFetchReason.syncReset;
          }
          break;
        }
      }
    } catch (error) {
      if (_disposed) return SyncPullResult.dropped;
      if (isTransient(error) && _failures + 1 < syncPullFailuresToDrop) {
        _failures += 1;
        return SyncPullResult.kept;
      }
      _setCursor(null);
      return SyncPullResult.dropped;
    }
    _setCursor(cursor);
    final defer = deferReset;
    if (wasReset && defer != null) {
      defer(() {
        if (!_disposed) _apply(plan);
      }, plan.snapshots);
    } else {
      _apply(plan);
    }
    return SyncPullResult.applied;
  }

  void _apply(SyncChangesPlan plan) {
    // Lists read again anyway carry every conversation's state.
    if (!conversationSnapshots.every(plan.snapshots.contains)) {
      for (final MapEntry(key: id, value: state)
          in plan.conversations.entries) {
        if (applyConversation?.call(id, state) ?? false) continue;
        for (final name in conversationSnapshots) {
          plan.snapshots.add(name);
          plan.reasons.putIfAbsent(name, () => SyncFetchReason.unpatchable);
        }
        break;
      }
    }
    for (final MapEntry(key: id, value: op) in plan.channelScopes.entries) {
      channelScopeChanged?.call(id, op);
    }
    for (final name in plan.snapshots) {
      unawaited(_runner.request(name, plan.reasons[name]));
    }
    for (final row in plan.messages.values) {
      applyMessage?.call(row);
    }
    if (!plan.snapshots.contains(SyncListSnapshot.channels)) {
      for (final id in plan.channelIds) {
        unawaited(Future.sync(() => refreshChannel(id)).catchError((_) {}));
      }
    }
    if (!plan.snapshots.contains(SyncListSnapshot.channelMembers)) {
      plan.memberChannelIds.forEach(notifyChannelMembers);
    }
  }
}
