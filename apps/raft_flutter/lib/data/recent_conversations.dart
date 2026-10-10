import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'search_memory.dart';

/// The conversations the user opened, most recent first. It feeds the Quick
/// Switcher (Cmd/Ctrl+K) empty state. Source: recentConversations.ts and
/// recentConversationStore.ts. Recency is the user's own visits, never message
/// activity. The record holds channel ids only (no names or messages) and is
/// scoped to API origin, workspace and account.
const recentConversationLimit = 20;

/// Most-recent-first, deduped, capped.
List<String> pushRecentConversation(
  List<String> ids,
  String channelId, {
  int limit = recentConversationLimit,
}) {
  if (channelId.isEmpty) return List.of(ids);
  return [
    channelId,
    ...ids.where((id) => id != channelId),
  ].take(limit).toList();
}

List<String> normalizeRecentConversationIds(
  dynamic raw, {
  int limit = recentConversationLimit,
}) {
  if (raw is! List) return const [];
  final seen = <String>{}, ids = <String>[];
  for (final value in raw) {
    if (value is! String || value.isEmpty || value.length > 200) continue;
    if (!seen.add(value)) continue;
    ids.add(value);
    if (ids.length >= limit) break;
  }
  return List.unmodifiable(ids);
}

class RecentConversationScope {
  const RecentConversationScope(this.origin, this.serverId, this.principalId);
  final String origin, serverId, principalId;
  String get key =>
      'raft:recent-conversations:${jsonEncode([origin, serverId, principalId])}';
  @override
  bool operator ==(Object other) =>
      other is RecentConversationScope && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

/// Device-local visit history. A preloaded device preference answers in the
/// same frame (so the Quick Switcher paints its recent list at the first
/// frame); otherwise it is read once. Storage failures never interfere with
/// navigation.
class RecentConversationStore extends ChangeNotifier {
  RecentConversationStore({SearchMemoryStorage? storage})
    : storage = storage ?? PreferencesSearchMemoryStorage();
  final SearchMemoryStorage storage;
  final Map<String, List<String>> _ids = {};
  final Map<String, int> _revisions = {};
  final Map<String, Future<void>> _writes = {};
  final Set<String> _loading = {};
  bool _closed = false;

  /// Visited channel ids, most recent first, for [scope].
  List<String> idsFor(RecentConversationScope? scope) {
    if (scope == null) return const [];
    final cached = _ids[scope.key];
    if (cached != null) return cached;
    final Object sync = storage;
    if (sync is SynchronousSearchMemoryStorage && sync.ready) {
      String? stored;
      try {
        stored = sync.readSync(scope.key);
      } catch (_) {
        /* local convenience */
      }
      return _ids[scope.key] = _decode(stored);
    }
    unawaited(_loadAsync(scope));
    return const [];
  }

  Future<void> _loadAsync(RecentConversationScope scope) async {
    if (!_loading.add(scope.key)) return;
    final before = _revisions[scope.key] ?? 0;
    String? stored;
    try {
      stored = await storage.read(scope.key);
    } catch (_) {
      /* local convenience */
    }
    _loading.remove(scope.key);
    if (_closed || (_revisions[scope.key] ?? 0) != before) return;
    _ids[scope.key] = _decode(stored);
    notifyListeners();
  }

  static List<String> _decode(String? stored) {
    try {
      final raw = stored == null ? null : jsonDecode(stored);
      return normalizeRecentConversationIds(
        raw is Map ? raw['channelIds'] : raw,
      );
    } catch (_) {
      return const [];
    }
  }

  /// Marks [channelId] as the most recently visited conversation.
  void recordVisit(RecentConversationScope? scope, String? channelId) {
    if (scope == null || channelId == null || channelId.isEmpty) return;
    final current = idsFor(scope);
    // Re-visiting the head is the common route re-render: no write, no notify.
    if (current.isNotEmpty && current.first == channelId) return;
    final next = List<String>.unmodifiable(
      pushRecentConversation(current, channelId),
    );
    _ids[scope.key] = next;
    _revisions[scope.key] = (_revisions[scope.key] ?? 0) + 1;
    final encoded = jsonEncode({'version': 1, 'channelIds': next});
    _writes[scope.key] = (_writes[scope.key] ?? Future.value()).then((_) async {
      try {
        await storage.write(scope.key, encoded);
      } catch (_) {
        /* keep in-memory state */
      }
    });
    notifyListeners();
  }

  Future<void> flush() => Future.wait(_writes.values).then((_) {});

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
