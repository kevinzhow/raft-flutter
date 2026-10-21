// Web `memberServerBadgeLabels` (utils/channelLocalMembership.ts), pure so the
// roster rows and the human profile share one rule.
library;

/// Server badge labels for a roster member as seen from [viewerServerId]:
/// empty when the member is purely local (every server is the viewer's);
/// otherwise every server the member participates through, the viewer's own
/// included. Falls back to the single `serverId` / `serverName` /
/// `serverSlug` when `servers` is absent (older servers, agents).
List<String> memberServerBadgeLabels(Map member, String? viewerServerId) {
  if (viewerServerId == null || viewerServerId.isEmpty) return const [];
  final listed = member['servers'];
  final servers = <({String id, String? name, String? slug})>[
    if (listed is List && listed.isNotEmpty)
      for (final server in listed.whereType<Map>())
        (
          id: '${server['id'] ?? ''}',
          name: server['name'] as String?,
          slug: server['slug'] as String?,
        )
    else if (member['serverId'] case final String id when id.isNotEmpty)
      (
        id: id,
        name: member['serverName'] as String?,
        slug: member['serverSlug'] as String?,
      ),
  ];
  if (servers.every((server) => server.id == viewerServerId)) return const [];
  String label(({String id, String? name, String? slug}) server) {
    final name = server.name;
    return name != null && name.isNotEmpty ? name : server.slug ?? '';
  }

  return [
    for (final server in servers)
      if (label(server).isNotEmpty) label(server),
  ];
}
