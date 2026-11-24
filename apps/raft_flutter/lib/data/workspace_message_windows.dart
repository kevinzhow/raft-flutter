import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'conversation_window.dart';
export 'conversation_window.dart' show MessageWindowAuthority;
import 'thread_window_snapshot.dart';
import 'message_window_snapshot.dart';
import 'workspace_sends.dart';
import 'reading_positions.dart';
export 'reading_positions.dart' show ReadingAnchor;

/// Explicit synchronous event/local write. Delayed responses use an issued ticket.
const liveWindowWrite = MessageWindowRequest._(null, null);

/// Accepted message windows for one workspace receiver. Transport, session
/// authorization and read-receipt execution remain with the caller.
class WorkspaceMessageWindows {
  WorkspaceMessageWindows({
    required this.authority,
    required this.presentation,
    required this.layout,
    required this.sends,
    required this.notRevoked,
    Object Function()? authorityStamp,
  }) {
    initWindowTracking(_windows, authorityStamp);
  }
  final MessageWindowAuthority? Function(ConversationWindowScope) authority;
  final ConversationWindowSnapshot Function(bool thread) presentation;
  final (bool, bool) Function(ConversationWindowScope) layout;
  final WorkspaceSends sends;
  final bool Function(String) notRevoked;
  final _windows = <ConversationWindowScope, _ProjectedConversationWindow>{};
  bool _disposed = false;

  /// Session authorization stays a read port. The owner captures its own
  /// ledger and window epochs and checks both again at every write boundary.
  MessageWindowRequest request({
    bool? thread,
    required bool Function() allowed,
  }) {
    final generation = ledger.generation;
    int? epoch() => thread == null
        ? null
        : thread
        ? threadGeneration
        : channelGeneration;
    final selected = epoch();
    return MessageWindowRequest._(
      this,
      () => generation == ledger.generation && selected == epoch() && allowed(),
    );
  }

  bool _admits(MessageWindowRequest request) =>
      !_disposed && identical(request._owner, this) && request._allowed!();

  bool _writable(MessageWindowRequest request) =>
      !_disposed && (identical(request, liveWindowWrite) || _admits(request));

  /// Accept canonical row versions and their visible membership together.
  /// A rejected operation cannot change either side of the window.
  void acceptRows(
    MessageWindowRequest request,
    String id,
    Iterable<Map<String, dynamic>> rows, {
    Iterable<String>? visible,
    bool replace = false,
    bool authoritative = false,
  }) {
    if (!_writable(request)) return;
    final accepted = rows.toList();
    ledger.ingest(
      accepted,
      expectedGeneration: ledger.generation,
      complete: authoritative,
    );
    reveal(
      request,
      id,
      visible ?? accepted.map((r) => r['id'] as String),
      replace: replace,
    );
  }

  /// Applies a thread page only through this window owner's request ticket.
  ThreadPageBoundary acceptThreadPage(
    MessageWindowRequest request,
    String id,
    Map<String, dynamic> page, {
    required bool focused,
    required bool retainOlder,
    required bool retainedHasMore,
  }) => applyThreadPageUpdate(
    id,
    page,
    _accepted,
    rows,
    focused: focused,
    retainOlder: retainOlder,
    retainedHasMore: retainedHasMore,
    accept: (rows, visible) {
      acceptRows(request, id, rows, visible: visible, replace: true);
      setDiskOnly(request, id, false);
    },
  );

  void _dirty(String id) => markWindowChannelDirty(_windows, id);

  void switchServer(String? id) {
    ledger.switchServer(id);
    visibleIds.clear();
    _accepted.clear();
    _diskOnly.clear();
    _threads.clear();
    _anchors.clear();
    markAllWindowsDirty(_windows);
  }

  void revokeChannel(String id) {
    ledger.revokeChannel(id);
    clearReadingAnchor(id);
    _dirty(id);
  }

  void reveal(
    MessageWindowRequest request,
    String id,
    Iterable<String> ids, {
    bool replace = false,
  }) {
    if (!_writable(request)) return;
    if (replace) {
      visibleIds[id] = ids.toSet();
    } else {
      visibleIds.putIfAbsent(id, () => {}).addAll(ids);
    }
    _dirty(id);
  }

  BigInt newestVisibleSequence(String id) =>
      cachedNewestVisibleSequence(ledger, visibleIds, id, presented);

  /// Retained canonical rows beyond the visible frontier fill a missed live
  /// event gap. The session decides when to revalidate it over the transport.
  bool fillWindowGap(String id, String liveId, {BigInt? newest}) =>
      fillWindowGapFromLedger(
        ledger,
        visibleIds,
        id,
        liveId,
        presented,
        newest: newest,
      );

  void hideWindow(String id) {
    visibleIds.remove(id);
    _dirty(id);
  }

  /// The session reducer feeds canonical events through MessageLedger's epoch
  /// checks. Window responses additionally admit membership here with a ticket.
  final ledger = MessageLedger();
  final visibleIds = <String, Set<String>>{};
  final _accepted = <String, AcceptedMessageWindow>{};
  final _threads = <String, CachedMessageThread>{};
  final _diskOnly = <String>{};
  final _anchors = ConversationReadingPositions();
  final _presentedRows = Expando<RaftMessage>('presented rows');
  final _requests = <Object, Future<String?>?>{};
  int channelGeneration = 0, threadGeneration = 0;

  Map<String, AcceptedMessageWindow> get accepted =>
      UnmodifiableMapView(_accepted);
  Map<String, CachedMessageThread> get threads => UnmodifiableMapView(_threads);
  ReadingAnchor? readingAnchor(String id) => _anchors.read(id);
  void clearReadingAnchor(String id) => _anchors.clear(id);
  Iterable<ConversationWindowSnapshot> get retainedSnapshots =>
      _windows.values.map((window) => window.snapshot);
  // Canonical row versions are replaced, never mutated. Each keeps one wrapper.
  RaftMessage presented(Map<String, dynamic> row) =>
      _presentedRows[row] ??= RaftMessage(row);

  void rememberWindow(
    MessageWindowRequest request,
    String id,
    String authority,
    bool more,
    String token, {
    required bool historyLimited,
    Iterable<Map<String, dynamic>>? rows,
    bool replace = false,
  }) {
    if (!_writable(request)) return;
    if (rows != null) acceptRows(request, id, rows, replace: replace);
    rememberAcceptedWindow(
      _accepted,
      id,
      authority,
      more,
      token,
      historyLimited,
    );
    _dirty(id);
  }

  void discardWindow(String id) {
    hideWindow(id);
    _accepted.remove(id);
    setDiskOnly(liveWindowWrite, id, false);
  }

  bool historyLimit(String? id) => _accepted[id]?.historyLimited == true;
  bool isContext(String id) => _accepted[id]?.contextNewer != null;
  bool contextHasNewer(String? id) => _accepted[id]?.contextNewer == true;
  bool setContextMode(MessageWindowRequest request, String id, bool? newer) {
    if (!_writable(request)) return false;
    final held = _accepted[id], prior = _accepted[id]?.contextNewer;
    if (held != null) {
      _accepted[id] = held.withContext(newer);
      _dirty(id);
    }
    return prior != null;
  }

  PendingMessageContext? _pendingContext;
  void beginContextVisit(PendingMessageContext visit) {
    if (_admits(visit.request)) _pendingContext = visit;
  }

  String? get pendingContextChannelId =>
      _pendingContext?.request.current == true
      ? _pendingContext!.channelId
      : null;
  bool get contextRetainsRows => _pendingContext?.retainRows ?? false;
  void finishContextVisit(MessageWindowRequest request) {
    if (identical(request, liveWindowWrite) ||
        identical(_pendingContext?.request, request)) {
      _pendingContext = null;
    }
  }

  /// Only an accepted in-memory tail under current session facts follows live
  /// rows. Disk-only and context windows are revalidated when opened.
  bool retainsLiveTail(String id) => retainsLiveTailWindow(
    id,
    _accepted[id],
    authority((channelId: id, parentMessageId: null)),
    visibleIds[id],
    isDiskOnly(id),
  );

  bool isDiskOnly(String? id) => _diskOnly.contains(id);
  void setDiskOnly(MessageWindowRequest request, String id, bool value) {
    if (_writable(request)) {
      value ? _diskOnly.add(id) : _diskOnly.remove(id);
      _dirty(id);
    }
  }

  CachedMessageThread? matchingThread(
    String channelId,
    String? parentId,
    String? token,
    String? authority,
  ) => matchCachedThread(
    _threads[parentId],
    channelId,
    token,
    authority,
    ledger.generation,
    notRevoked,
  );

  void cacheThread(
    MessageWindowRequest request,
    String parentId,
    CachedMessageThread value,
  ) {
    if (_writable(request)) {
      _threads[parentId] = value;
      _accepted.putIfAbsent(value.threadChannelId, value.toAcceptedWindow);
      _dirty(value.parentChannelId);
    }
  }

  void cacheThreadParent(
    MessageWindowRequest request,
    String parentId,
    RaftMessage? parent,
  ) {
    final held = _threads[parentId];
    if (_writable(request) && held != null) {
      _threads[parentId] = held.withParent(parent);
      _dirty(held.parentChannelId);
    }
  }

  void forgetThread(String id) {
    final held = _threads.remove(id);
    if (held != null) _dirty(held.parentChannelId);
  }

  void clearThreads() {
    _threads.clear();
    markAllWindowsDirty(_windows);
  }

  void invalidateParentThreads(String id) {
    _threads.removeWhere((_, thread) => thread.parentChannelId == id);
    _dirty(id);
  }

  void revokeThreads(String id) {
    _threads.removeWhere(
      (_, t) => t.parentChannelId == id || t.threadChannelId == id,
    );
    markAllWindowsDirty(_windows);
  }

  void saveReadingAnchor(String id, ReadingAnchor anchor) =>
      _anchors.save(id, anchor);
  ReadingAnchor? takeReadingAnchor(String id) => _anchors.take(id);

  bool beginTailRevalidation(String id) {
    final key = ('tail', id);
    if (_requests.containsKey(key)) return false;
    _requests[key] = null;
    return true;
  }

  void endTailRevalidation(String id) => _requests.remove(('tail', id));
  Future<String?> createThread(Future<String?> Function() create) =>
      runDedupedWindowRequest(_requests, ('thread', threadGeneration), create);

  ConversationWindow? channel(String? id) =>
      id == null ? null : _open((channelId: id, parentMessageId: null));
  ConversationWindow? thread(
    String? parentChannelId,
    String? parentMessageId,
  ) => parentChannelId == null || parentMessageId == null
      ? null
      : _open((channelId: parentChannelId, parentMessageId: parentMessageId));

  ConversationWindow? _open(ConversationWindowScope scope) {
    if (_disposed) return null;
    final token = authority(scope);
    if (token == null) return null;
    _retireIncompatible(scope, token);
    return holdWindow<_ProjectedConversationWindow>(
      _windows,
      scope,
      layout,
      (held) => held.retire(),
      () => _ProjectedConversationWindow(scope, token, _read(scope), this),
    );
  }

  /// Called after existing state mutations; only changed windows publish.
  void synchronize() {
    if (_disposed) return;
    final due = windowsDueForSync(
      ledger,
      _windows,
      _threads,
      layout: layout,
      pendingScopes: sends.pending.keys,
    );
    for (final window in due) {
      _retireIncompatible(window.scope, authority(window.scope));
      if (!window.snapshot.retired) window.refresh(_read(window.scope));
    }
  }

  void _retireIncompatible(ConversationWindowScope scope, Object? token) {
    if (_windows[scope]?.token != token) _windows.remove(scope)?.retire();
  }

  bool _current(ConversationWindowScope scope, Object token) =>
      !_disposed && authority(scope) == token;
  bool retainsContextRows(String? id) =>
      pendingContextChannelId != id || contextRetainsRows;
  List<RaftMessage> rows(String? id) => id == null || !retainsContextRows(id)
      ? []
      : readWindowRows(ledger, visibleIds, id, presented);
  bool containsVisible(String? id, String? messageId) =>
      id != null &&
      messageId != null &&
      (visibleIds[id]?.contains(messageId) ?? false) &&
      ledger.contains(id, messageId);

  List<RaftMessage> project(
    List<RaftMessage> rows,
    String? scope, {
    bool context = false,
  }) => context || scope == null
      ? rows
      : sends.project(rows, scope).map((row) => presented(row.json)).toList();

  ConversationWindowSnapshot _read(ConversationWindowScope scope) {
    if (layout(scope).$1) return presentation(scope.parentMessageId != null);
    final facts = authority(scope);
    final held = matchingThread(
      scope.channelId,
      scope.parentMessageId,
      facts?.$3,
      facts?.$4,
    );
    return buildCachedWindowSnapshot(
      scope,
      held,
      _accepted,
      rows,
      project,
      contextHasNewer,
      historyLimit,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    retireAllWindows(_windows);
  }
}

class _ProjectedConversationWindow extends ConversationWindow
    with ChangeNotifier {
  _ProjectedConversationWindow(
    this.scope,
    this.token,
    this._snapshot,
    this._owner,
  );
  @override
  final ConversationWindowScope scope;
  final Object token;
  ConversationWindowSnapshot _snapshot;
  final WorkspaceMessageWindows _owner;
  static final _empty = ConversationWindowSnapshot(retired: true);

  @override
  Listenable get changes => this;
  @override
  ConversationWindowSnapshot get snapshot =>
      _snapshot.retired || !_owner._current(scope, token) ? _empty : _snapshot;
  @override
  bool get visible => !snapshot.retired && _owner.layout(scope).$2;

  void refresh(ConversationWindowSnapshot next) {
    if (_snapshot.retired || _snapshot.samePresentation(next)) return;
    _snapshot = next;
    notifyListeners();
  }

  void retire({bool notify = true}) {
    if (_snapshot.retired) return;
    _snapshot = _empty;
    if (notify) notifyListeners();
    dispose();
  }
}

/// One immutable pending visit binds its receiver-issued request to its rows.
typedef PendingMessageContext = ({
  String channelId,
  MessageWindowRequest request,
  bool retainRows,
});

/// A window request cannot outlive its receiver, accepted ledger generation or
/// selected window epoch. Session/navigation permission facts are checked live.
class MessageWindowRequest {
  const MessageWindowRequest._(this._owner, this._allowed);

  final WorkspaceMessageWindows? _owner;
  final bool Function()? _allowed;
  bool get current => _owner?._admits(this) ?? identical(this, liveWindowWrite);
}
