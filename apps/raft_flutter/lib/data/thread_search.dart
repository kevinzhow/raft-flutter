import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

/// Real URI identity, independent of the asynchronously accepted parent record.
@immutable
class WorkspaceThreadIdentity {
  const WorkspaceThreadIdentity({
    required this.parentChannelId,
    required this.parentMessageId,
    this.focusedMessageId,
  });
  final String parentChannelId, parentMessageId;
  final String? focusedMessageId;
}

/// Thread presentation and context navigation needed by in-thread search.
abstract interface class ThreadSearchAuthority {
  RaftClient get client;
  String? get threadChannelId;
  WorkspaceThreadIdentity? get threadIdentity;
  RaftMessage? get presentedThreadParent;
  List<RaftMessage> get replies;
  bool get threadHasMore;
  Future<void> openThreadIdentity({
    required String parentChannelId,
    required String parentMessageId,
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
  });
}

/// Web ThreadPanel `THREAD_SEARCH_HYDRATION_DEBOUNCE_MS`.
const threadSearchHydrationDebounce = Duration(milliseconds: 250);

/// Web `normalizeThreadSearchQuery`.
String normalizeThreadSearchQuery(String query) => query.trim().toLowerCase();

/// Web `normalizeThreadSearchSelectionText`.
String normalizeThreadSearchSelectionText(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Web `buildThreadSearchMatches`: the ids of the messages whose
/// `senderName\ncontent` contains the query, in the given (display) order.
List<String> threadSearchMatches(Iterable<RaftMessage> messages, String query) {
  final needle = normalizeThreadSearchQuery(query);
  if (needle.isEmpty) return const [];
  return [
    for (final m in messages)
      if (m.id.isNotEmpty &&
          '${m.string('senderName')}\n${m.content}'.toLowerCase().contains(
            needle,
          ))
        m.id,
  ];
}

/// Web ThreadPanel's thread-search state (`threadSearchState`): the bar, the
/// query, the active match and the hydrated corpus of every reply, scoped to
/// one thread. The scrolling to the active match is the mounted timeline's.
class ThreadSearch extends ChangeNotifier {
  ThreadSearch(this.w);
  final ThreadSearchAuthority w;

  String? _threadId;
  bool _open = false;
  String _query = '';
  int _activeIndex = 0;
  String? _hydratedId, _loadingId;
  List<RaftMessage> _corpus = const [];
  Timer? _debounce;
  bool _disposed = false;

  /// Bumped on every open (and seed) so the field refocuses and selects.
  int focusRequest = 0;

  bool get _isCurrent => _threadId != null && _threadId == w.threadChannelId;

  /// The bar is shown for the current thread only.
  bool get isOpen => _isCurrent && _open;
  String get query => _isCurrent ? _query : '';
  bool get loading => _loadingId != null && _loadingId == w.threadChannelId;

  /// Web `threadSearchMessages`: parent first, then every reply (the hydrated
  /// corpus once complete, otherwise the loaded window).
  List<RaftMessage> get searchable {
    final parent = w.presentedThreadParent;
    final replies = _hydratedId != null && _hydratedId == w.threadChannelId
        ? _corpus
        : w.replies;
    return [?parent, ...replies];
  }

  List<String> get matches => threadSearchMatches(searchable, query);

  /// Clamped like Web `threadSearchActiveIndex`.
  int get activeIndex {
    final count = matches.length;
    if (count == 0) return 0;
    final raw = _isCurrent ? _activeIndex : 0;
    return raw < count ? raw : count - 1;
  }

  /// The message the bar points at (highlighted row + marked text).
  String? get activeMessageId {
    if (!isOpen) return null;
    final list = matches;
    return list.isEmpty ? null : list[activeIndex];
  }

  /// Web `thread-search-count`: "i/n", "0/0", the loading label, or empty.
  String countLabel(String loadingLabel) {
    if (normalizeThreadSearchQuery(query).isEmpty) return '';
    if (loading) return loadingLabel;
    final count = matches.length;
    return count > 0 ? '${activeIndex + 1}/$count' : '0/0';
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  /// Web `openThreadSearch`: reopens the same thread's query, or starts fresh
  /// (a [seed] replaces the query).
  void open([String? seed]) {
    final id = w.threadChannelId;
    if (id == null) return;
    final text = seed == null ? '' : normalizeThreadSearchSelectionText(seed);
    final same = _threadId == id;
    _threadId = id;
    _open = true;
    _query = text.isNotEmpty ? text : (same ? _query : '');
    _activeIndex = text.isNotEmpty ? 0 : (same ? _activeIndex : 0);
    focusRequest++;
    _scheduleHydration();
    _emit();
  }

  /// Web `closeThreadSearch`: the bar closes, the query is kept for a reopen.
  void close() {
    _open = false;
    _debounce?.cancel();
    _emit();
  }

  void setQuery(String value) {
    final id = w.threadChannelId;
    if (id == null) return;
    _threadId = id;
    _open = true;
    _query = value;
    _activeIndex = 0;
    _scheduleHydration();
    _emit();
  }

  /// Web `goToThreadSearchMatch`: wraps around.
  void step(int direction) {
    final count = matches.length;
    if (count == 0) return;
    _threadId = w.threadChannelId ?? _threadId;
    _activeIndex = (activeIndex + direction + count) % count;
    _emit();
  }

  void _scheduleHydration() {
    _debounce?.cancel();
    if (!isOpen || normalizeThreadSearchQuery(_query).isEmpty) return;
    _debounce = Timer(threadSearchHydrationDebounce, hydrate);
  }

  /// Web `ensureThreadSearchHydrated` / `loadThreadSearchCorpus`: pages the
  /// older (and, in a focused window, newer) replies in once per thread.
  Future<void> hydrate() async {
    final id = w.threadChannelId;
    if (_disposed || id == null || _hydratedId == id || _loadingId == id) {
      return;
    }
    _loadingId = id;
    _emit();
    try {
      final corpus = await _loadCorpus(id);
      if (!_disposed && w.threadChannelId == id && corpus != null) {
        _hydratedId = id;
        _corpus = corpus;
      }
    } catch (_) {
      // The loaded window stays searchable; a later query retries.
    } finally {
      if (_loadingId == id) _loadingId = null;
      _emit();
    }
  }

  Future<List<RaftMessage>?> _loadCorpus(String id) async {
    const limit = 100;
    var rows = _byDisplay([...w.replies]);
    var hasMore = w.threadHasMore;
    final focused = w.threadIdentity?.focusedMessageId != null;
    List<RaftMessage> page(Map<String, dynamic> data) => [
      for (final row in (data['messages'] as List? ?? const []))
        if (row is Map && row['channelId'] == id)
          RaftMessage(Map<String, dynamic>.from(row)),
    ];
    while (hasMore && rows.isNotEmpty) {
      final minSeq = rows.map((m) => m.seq).reduce((a, b) => a < b ? a : b);
      if (minSeq <= BigInt.zero) break;
      final older = page(
        await w.client.messagePage(id, limit: limit, before: minSeq),
      );
      if (_disposed || w.threadChannelId != id) return null;
      rows = _byDisplay(_merge(rows, older));
      hasMore = older.length >= limit;
      if (older.isEmpty) break;
    }
    var hasNewer = focused;
    while (hasNewer && rows.isNotEmpty) {
      final maxSeq = rows.map((m) => m.seq).reduce((a, b) => a > b ? a : b);
      if (maxSeq <= BigInt.zero) break;
      final newer = page(
        await w.client.messagePage(id, limit: limit, after: maxSeq),
      );
      if (_disposed || w.threadChannelId != id) return null;
      rows = _byDisplay(_merge(rows, newer));
      hasNewer = newer.length >= limit;
      if (newer.isEmpty) break;
    }
    return rows;
  }

  static List<RaftMessage> _merge(
    List<RaftMessage> current,
    List<RaftMessage> incoming,
  ) {
    final byId = {for (final m in current) m.id: m};
    for (final m in incoming) {
      byId.putIfAbsent(m.id, () => m);
    }
    return byId.values.toList();
  }

  static List<RaftMessage> _byDisplay(List<RaftMessage> rows) => rows
    ..sort((a, b) {
      final bySeq = a.seq.compareTo(b.seq);
      if (bySeq != 0) return bySeq;
      return (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0));
    });

  /// Web `ensureThreadSearchMatchVisible`: a match outside the loaded window
  /// is brought in through its context page (the reloaded window highlights
  /// and centers it). Returns true when the match was already loaded and the
  /// caller still has to scroll to it.
  Future<bool> ensureVisible(String messageId) async {
    final id = w.threadChannelId;
    final identity = w.threadIdentity;
    if (id == null || identity == null) return false;
    if (messageId == identity.parentMessageId) return true;
    if (w.replies.any((m) => m.id == messageId)) return true;
    await w.openThreadIdentity(
      parentChannelId: identity.parentChannelId,
      parentMessageId: identity.parentMessageId,
      focusedMessageId: messageId,
      initialThreadChannelId: id,
      navigate: false,
    );
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
