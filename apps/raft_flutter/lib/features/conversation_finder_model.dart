import 'package:raft_client/raft_client.dart';

import 'search_ranking.dart';

/// Web `ConversationMatch` (conversationFinderModel.ts): one row of the sidebar
/// "Find a conversation…" box. A DM and a person or agent are told apart by
/// [kind]; [id] is the channel, DM, agent or user it opens.
class ConversationMatch {
  const ConversationMatch({
    required this.kind,
    required this.id,
    required this.label,
    this.sublabel,
    this.private = false,
    this.peerIsAgent = false,
    this.avatar = const {},
  });

  /// `channel`, `dm`, `agent` or `human`.
  final String kind, id, label;
  final String? sublabel;
  final bool private, peerIsAgent;

  /// The row's own avatar facts (`avatarUrl`, `gravatarHash`) for the sidebar
  /// list avatar, from the DM peer, agent or member.
  final Map<String, dynamic> avatar;
  String get key => '$kind:$id';
  bool get isAgent => kind == 'agent' || kind == 'dm' && peerIsAgent;
}

const finderMaxRendered = 20;

String _text(Map<String, dynamic> row, String key) => '${row[key] ?? ''}';

/// Web `buildFinderResults`: channels (not DMs or threads), DMs, agents and
/// people flattened into one list. People and agents that already have a DM
/// are represented by that DM (dedup by peer id) so each conversation appears
/// once, and the current user is never listed (no self-DM).
List<ConversationMatch> buildFinderResults({
  required Iterable<RaftChannel> channels,
  required Iterable<RaftChannel> dms,
  required Iterable<Map<String, dynamic>> agents,
  required Iterable<Map<String, dynamic>> members,
  required String? currentUserId,
  required String agentTag,
}) {
  final dmPeers = {
    for (final dm in dms)
      if (_text(dm.json, 'peerId').isNotEmpty) _text(dm.json, 'peerId'),
  };
  final results = <ConversationMatch>[];
  for (final channel in channels) {
    if (channel.type == 'dm' || channel.type == 'thread') continue;
    final description = channel.description.trim();
    results.add(
      ConversationMatch(
        kind: 'channel',
        id: channel.id,
        label: channel.string('name'),
        sublabel: description.isEmpty ? null : description,
        private: channel.type == 'private',
      ),
    );
  }
  for (final dm in dms) {
    final agent = dm.string('peerType') == 'agent';
    results.add(
      ConversationMatch(
        kind: 'dm',
        id: dm.id,
        // Web `sidebarDmLabel`: peerDisplayName || peerName || name.
        label: dm.firstNonEmpty(const ['peerDisplayName', 'peerName', 'name']),
        sublabel: agent ? agentTag : null,
        peerIsAgent: agent,
        avatar: {
          'avatarUrl': dm.json['peerAvatarUrl'],
          'gravatarHash': dm.json['peerGravatarHash'],
        },
      ),
    );
  }
  for (final agent in agents) {
    final id = _text(agent, 'id');
    if (id.isEmpty || dmPeers.contains(id)) continue;
    final display = _text(agent, 'displayName');
    results.add(
      ConversationMatch(
        kind: 'agent',
        id: id,
        label: display.isEmpty ? _text(agent, 'name') : display,
        sublabel: agentTag,
        avatar: {'avatarUrl': agent['avatarUrl']},
      ),
    );
  }
  for (final member in members) {
    final id = _text(member, 'userId');
    if (id.isEmpty || id == currentUserId || dmPeers.contains(id)) continue;
    final display = _text(member, 'displayName'), name = _text(member, 'name');
    results.add(
      ConversationMatch(
        kind: 'human',
        id: id,
        label: display.isEmpty ? name : display,
        sublabel: name.isNotEmpty && display.isNotEmpty ? '@$name' : null,
        avatar: {
          'avatarUrl': member['avatarUrl'],
          'gravatarHash': member['gravatarHash'],
        },
      ),
    );
  }
  return results;
}

/// Web `finderSearchEntries`: the name is the primary field, the sublabel the
/// secondary one.
List<SearchRankEntry<ConversationMatch>> finderSearchEntries(
  List<ConversationMatch> results,
) => [
  for (final result in results)
    SearchRankEntry(result, [
      (text: result.label, priority: 0),
      (text: result.sublabel ?? '', priority: 2),
    ]),
];

/// Web `rankFinderResults`: ranked like composer suggestions, capped at
/// [finderMaxRendered]; an empty query lists nothing.
List<ConversationMatch> rankFinderResults(
  String query,
  List<SearchRankEntry<ConversationMatch>> entries,
) {
  if (query.trim().isEmpty) return const [];
  final ranked = rankSearchEntries(query, entries);
  return ranked.length > finderMaxRendered
      ? ranked.sublist(0, finderMaxRendered)
      : ranked;
}
