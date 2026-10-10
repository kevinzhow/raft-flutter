import 'resource_search.dart';
import 'search_ranking.dart';

const quickSwitcherRecentRowLimit = 10;

/// Destinations of one workspace snapshot: channels, computers, agents and
/// people, built once and ranked per keystroke. Source: searchEntities.ts and
/// recentConversations.ts. The catalog is a pure projection of data the
/// workspace already holds, so the switcher paints results at its first frame.
class QuickSwitcherCatalog {
  QuickSwitcherCatalog({
    required List<Map<String, dynamic>> channels,
    required List<Map<String, dynamic>> dms,
    required List<Map<String, dynamic>> computers,
    required List<Map<String, dynamic>> agents,
    required List<Map<String, dynamic>> people,
    String? principal,
    Set<String> hiddenDmIds = const {},
  }) : hiddenDmIds = Set.unmodifiable(hiddenDmIds),
       entries = List.unmodifiable(
         searchEntityEntries(
           channels: channels,
           computers: computers,
           agents: agents,
           people: people,
           principal: principal,
         ),
       ),
       _dmByPeer = {
         for (final dm in dms)
           if (dm['id'] is String &&
               dm['peerId'] is String &&
               (dm['peerType'] == 'agent' || dm['peerType'] == 'user'))
             '${dm['peerType']}:${dm['peerId']}': dm['id'] as String,
       },
       _lastActivity = {
         for (final row in [...channels, ...dms])
           if (row['id'] is String &&
               DateTime.tryParse('${row['lastMessageAt'] ?? ''}') != null)
             row['id'] as String: DateTime.parse('${row['lastMessageAt']}'),
       };

  final List<SearchRankEntry<SearchEntity>> entries;
  final Set<String> hiddenDmIds;
  final Map<String, String> _dmByPeer;
  final Map<String, DateTime> _lastActivity;

  /// Ranked destinations for [query] (`#` channels only, `@` people only).
  List<SearchEntity> rank(String query) => rankSearchEntities(query, entries);

  /// The channel or DM a destination opens without a request, or null when a
  /// person or agent has no DM yet.
  String? conversationIdOf(SearchEntity entity) => switch (entity.kind) {
    'channel' => entity.id,
    'agent' => _dmByPeer['agent:${entity.id}'],
    'user' => _dmByPeer['user:${entity.id}'],
    _ => null,
  };

  /// Source `selectRecentConversationEntities`: the visit history first, then
  /// (when the history is short) the most recently active conversations, so the
  /// list is never empty on a live server. The conversation the switcher sits
  /// over is never listed.
  List<SearchEntity> recent({
    required List<String> visited,
    String? excludeChannelId,
    bool fillFromActivity = true,
    int limit = quickSwitcherRecentRowLimit,
  }) {
    final byConversation = <String, SearchEntity>{};
    for (final entry in entries) {
      final entity = entry.value;
      if (entity.kind == 'computer' ||
          entity.row['archivedAt'] != null ||
          entity.row['archived'] == true) {
        continue;
      }
      final id = conversationIdOf(entity);
      if (id == null || id == excludeChannelId) continue;
      if (entity.kind != 'channel' && hiddenDmIds.contains(id)) continue;
      byConversation.putIfAbsent(id, () => entity);
    }
    final picked = <SearchEntity>[], pickedIds = <String>{};
    for (final id in visited) {
      final entity = byConversation[id];
      if (entity == null || !pickedIds.add(id)) continue;
      picked.add(entity);
      if (picked.length >= limit) return picked;
    }
    if (!fillFromActivity) return picked;
    final fill =
        byConversation.entries
            .where(
              (e) => !pickedIds.contains(e.key) && _lastActivity[e.key] != null,
            )
            .toList()
          ..sort((a, b) {
            final recency = _lastActivity[b.key]!.compareTo(
              _lastActivity[a.key]!,
            );
            return recency != 0
                ? recency
                : a.value.title.toLowerCase().compareTo(
                    b.value.title.toLowerCase(),
                  );
          });
    for (final entry in fill) {
      picked.add(entry.value);
      if (picked.length >= limit) break;
    }
    return picked;
  }
}

/// Source `findExactDestination`: the query names a destination outright, by
/// its title or its handle, ignoring a leading `#` / `@`, case and whitespace
/// runs. Deliberately stricter than the ranking so Return never enters the
/// wrong conversation; it is searched over the whole ranked list.
SearchEntity? findExactDestination(
  String query,
  Iterable<SearchEntity> entities,
) {
  String normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  final wanted = normalize(query.replaceFirst(RegExp(r'^\s*[#@]'), ''));
  if (wanted.isEmpty) return null;
  for (final entity in entities) {
    if (normalize(entity.title) == wanted) return entity;
    final handle = _handleText(entity);
    if (handle != null &&
        normalize(handle.replaceFirst(RegExp(r'^\s*@'), '')) == wanted) {
      return entity;
    }
  }
  return null;
}

/// Subtitle that carries real data (a handle or description) rather than a
/// localized fallback label.
String? _handleText(SearchEntity entity) {
  final text = entity.subtitle;
  if (text.isEmpty) return null;
  return switch (entity.kind) {
    'agent' => text == 'Agent' ? null : text,
    'user' => text == 'Notes to yourself' ? null : text,
    _ => null,
  };
}
