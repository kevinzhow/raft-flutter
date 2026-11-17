import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';

/// What a quoted message permalink resolved to. A null [target] means the
/// server answered but the message is not readable (deleted, no access).
typedef QuotedPermalinkResult = ({RaftMessage? target, bool archived});

/// Resolved quoted permalinks of one workspace, so a row that mounts again
/// (scroll, channel switch) shows its card in the first frame. Web
/// QuotedMessagePermalinkPreview fetches on every mount; this keeps the
/// result and refreshes it in the background at most once per
/// [refreshAfter] per link. Emptied when the account or server changes.
class QuotedPermalinkCache {
  QuotedPermalinkCache._(this.w);

  static const capacity = 300;
  static const refreshAfter = Duration(minutes: 1);

  static final _caches = Expando<QuotedPermalinkCache>('quoted permalinks');
  static QuotedPermalinkCache of(WorkspaceController w) {
    final source = w.presentationSource ?? w;
    return _caches[source] ??= QuotedPermalinkCache._(source);
  }

  final WorkspaceController w;
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  /// Insertion order is recency: a read moves its entry to the end.
  final _entries =
      <String, ({QuotedPermalinkResult result, DateTime fetchedAt})>{};
  final _pending = <String, Future<QuotedPermalinkResult?>>{};
  String? _scope;

  String get _current =>
      '${w.client.origin}|${w.client.generation}|${w.client.user?.id}|'
      '${w.client.serverId}';

  String _key(RaftPermalink link) =>
      '${link.serverSlug}|${link.channelId}|${link.messageId}|'
      '${link.threadParentMessageId ?? ''}';

  void _enterScope() {
    if (_scope == _current) return;
    _scope = _current;
    _entries.clear();
    _pending.clear();
  }

  /// The last result for [link], or null when it never loaded here.
  QuotedPermalinkResult? peek(RaftPermalink link) {
    _enterScope();
    final key = _key(link);
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    return entry.result;
  }

  /// The result for [link]: the cached one while it is fresh, otherwise one
  /// request (shared by concurrent callers). Throws when the request fails
  /// and nothing is cached; returns null when the scope changed meanwhile.
  Future<QuotedPermalinkResult?> load(RaftPermalink link) {
    _enterScope();
    final key = _key(link);
    final cached = _entries[key];
    if (cached != null && now().difference(cached.fetchedAt) < refreshAfter) {
      return Future.value(cached.result);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    late final Future<QuotedPermalinkResult?> request;
    request = _fetch(link, key, _scope!).whenComplete(() {
      if (identical(_pending[key], request)) _pending.remove(key);
    });
    return _pending[key] = request;
  }

  Future<QuotedPermalinkResult?> _fetch(
    RaftPermalink link,
    String key,
    String scope,
  ) async {
    final QuotedPermalinkResult result;
    try {
      final data = await w.client.get(
        '/messages/context/${link.messageId}',
        query: {'channelId': link.channelId},
      );
      final rows = (data is Map ? data['messages'] as List? : null) ?? const [];
      final id =
          (data is Map ? data['targetMessageId'] : null) ?? link.messageId;
      final row = rows.whereType<Map>().where((m) => m['id'] == id).firstOrNull;
      result = (
        target: row == null
            ? null
            : RaftMessage(Map<String, dynamic>.from(row)),
        archived: data is Map && data['channelArchived'] == true,
      );
    } catch (_) {
      if (scope != _current) return null;
      // A failed refresh keeps the last answer.
      final cached = _entries[key];
      if (cached == null) rethrow;
      return cached.result;
    }
    if (scope != _current) return null;
    _entries.remove(key);
    _entries[key] = (result: result, fetchedAt: now());
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return result;
  }
}
