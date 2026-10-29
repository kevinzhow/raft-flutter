import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'conversation_window.dart';
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
  });
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
    ledger.ingest(accepted, expectedGeneration: ledger.generation,
      complete: authoritative);
    reveal(
      request,
      id,
      visible ?? accepted.map((row) => row['id'] as String),
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
  }) {
    final next = reconcileThreadPage(
      page,
      id,
      retained: retainOlder ? rows(id).map((m) => m.json) : const [],
      retainedHasMore: _accepted[id]?.hasMore ?? retainedHasMore,
      focused: focused,
    );
    acceptRows(request, id, next.rows, visible: next.visible, replace: true);
    setDiskOnly(request, id, false);
    return (more: next.more, limited: next.limited);
  }

  void switchServer(String? id) {
    ledger.switchServer(id);
    visibleIds.clear();
    _accepted.clear();
    _diskOnly.clear();
    _threads.clear();
    _anchors.clear();
  }

  void revokeChannel(String id) {
    ledger.revokeChannel(id);
    clearReadingAnchor(id);
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
  }

  BigInt newestVisibleSequence(String id) =>
      (visibleIds[id] ?? const <String>{})
          .map((key) => ledger.message(id, key))
          .nonNulls
          .map((row) => presented(row).seq)
          .fold(BigInt.zero, (latest, seq) => seq > latest ? seq : latest);

  /// Retained canonical rows beyond the visible frontier fill a missed live
  /// event gap. The session decides when to revalidate it over the transport.
  bool fillWindowGap(String id, String liveId) {
    final visible = visibleIds[id];
    if (visible == null || visible.isEmpty) return false;
    final newest = newestVisibleSequence(id);
    if (newest == BigInt.zero) return false;
    var gap = false;
    for (final row in ledger.messages(id)) {
      final seq = BigInt.tryParse('${row['seq']}');
      if (seq != null &&
          seq > newest &&
          row['id'] != liveId &&
          !visible.contains(row['id'])) {
        visible.add(row['id'] as String);
        gap = true;
      }
    }
    return gap;
  }

  void hideWindow(String id) => visibleIds.remove(id);

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
    _accepted[id] = AcceptedMessageWindow(
      authority,
      more,
      token,
      historyLimited,
      _accepted[id]?.contextNewer,
    );
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
    if (held != null) _accepted[id] = held.withContext(newer);
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
  bool retainsLiveTail(String id) {
    final held = _accepted[id];
    final facts = authority((channelId: id, parentMessageId: null));
    return held != null &&
        !isContext(id) &&
        !isDiskOnly(id) &&
        (visibleIds[id]?.isNotEmpty ?? false) &&
        held.matches(facts?.$4, facts?.$3);
  }

  bool isDiskOnly(String? id) => _diskOnly.contains(id);
  void setDiskOnly(MessageWindowRequest request, String id, bool value) {
    if (_writable(request)) value ? _diskOnly.add(id) : _diskOnly.remove(id);
  }

  CachedMessageThread? matchingThread(
    String channelId,
    String? parentId,
    String? token,
    String? authority,
  ) {
    final held = _threads[parentId];
    return held != null &&
            held.matches(channelId, token, authority, ledger.generation) &&
            notRevoked(held.threadChannelId)
        ? held
        : null;
  }

  void cacheThread(
    MessageWindowRequest request,
    String parentId,
    CachedMessageThread value,
  ) {
    if (_writable(request)) {
      _threads[parentId] = value;
      _accepted.putIfAbsent(value.threadChannelId, () => AcceptedMessageWindow(
        value.authority ?? '', value.hasMore, value.token,
        value.historyLimited, value.contextWindow ? true : null));
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
    }
  }

  void forgetThread(String id) => _threads.remove(id);
  void clearThreads() => _threads.clear();
  void invalidateParentThreads(String id) =>
      _threads.removeWhere((_, thread) => thread.parentChannelId == id);
  void revokeThreads(String id) => _threads.removeWhere(
    (_, thread) => thread.parentChannelId == id || thread.threadChannelId == id,
  );

  void saveReadingAnchor(String id, ReadingAnchor anchor) => _anchors.save(id, anchor);
  ReadingAnchor? takeReadingAnchor(String id) => _anchors.take(id);

  bool beginTailRevalidation(String id) {
    final key = ('tail', id);
    if (_requests.containsKey(key)) return false;
    _requests[key] = null;
    return true;
  }

  void endTailRevalidation(String id) => _requests.remove(('tail', id));
  Future<String?> createThread(Future<String?> Function() create) async {
    final key = ('thread', threadGeneration);
    final held = _requests[key];
    if (held != null) return held;
    final request = _requests[key] = create();
    try {
      return await request;
    } finally {
      if (identical(_requests[key], request)) _requests.remove(key);
    }
  }

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
    return holdWindow<_ProjectedConversationWindow>(_windows, scope, layout,
        (held) => held.retire(), () => _ProjectedConversationWindow(
          scope, token, _read(scope), this));
  }

  /// Called after existing state mutations; only changed windows publish.
  void synchronize() {
    if (_disposed) return;
    for (final window in dueWindows(ledger, _windows, _threads)) {
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
      : ledger
            .messages(id)
            .where((row) => visibleIds[id]?.contains(row['id']) ?? false)
            .map(presented)
            .toList();
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
    final main = scope.parentMessageId == null;
    // The active presentation already reads rows and pending sends from this
    // owner. Reuse that complete snapshot instead of copying its fields again.
    if (layout(scope).$1) return presentation(!main);
    final facts = authority(scope);
    final held = matchingThread(
      scope.channelId,
      scope.parentMessageId,
      facts?.$3,
      facts?.$4,
    );
    final id = main ? scope.channelId : held?.threadChannelId;
    final acceptedRows = rows(id);
    final newer = contextHasNewer(id);
    return ConversationWindowSnapshot(
      channelId: id,
      rows: acceptedRows,
      timeline: project(
        acceptedRows,
        main ? scope.channelId : 'thread:${scope.parentMessageId}',
        context: newer,
      ),
      parent: main ? null : held?.parent,
      hasMore: main ? _accepted[id]?.hasMore == true : held?.hasMore == true,
      hasNewer: newer,
      historyLimited: main ? historyLimit(id) : held?.historyLimited == true,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final window in _windows.values) {
      window.retire(notify: false);
    }
    _windows.clear();
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

/// Existing session/navigation, canonical generation, reply token, resource
/// permission and server permission facts. No Controller is retained here.
typedef MessageWindowAuthority = (String, int, String, String, String);
