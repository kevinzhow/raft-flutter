// Server badges of a joint-channel roster (RFC 075 phase 1), the Web
// `memberServerBadgeLabels` (utils/channelLocalMembership.ts) and the profile
// priming of `profileFallbackCache.ts`: a person who joined through both sides
// of a joint channel lists every server, the viewed server first.
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'member_server_badges.dart';

export 'member_server_badges.dart';

/// `jointServerLabels` of ChannelMembers: badges exist only in joint channels.
List<String> channelMemberServerLabels(
  Map<String, dynamic> member,
  RaftChannel channel,
) => channel.type == 'joint'
    ? memberServerBadgeLabels(member, channel.json['serverId'] as String?)
    : const [];

/// `primeHumanProfileFromChannelMember` keeps the roster row's `servers` for
/// the profile read, because the profile route is server scoped and does not
/// carry the joint list. Scoped to the workspace's entity directory, so a
/// server or account change drops it (Web `registerServerReset`).
final _primedServers = Expando<Map<String, List<Map<String, dynamic>>>>(
  'primed joint profile servers',
);

String _primedKey(String serverId, String userId) => '$serverId:$userId';

void primeHumanProfileServers(
  WorkspaceController w,
  String? serverId,
  String userId,
  Object? servers,
) {
  if (serverId == null || servers is! List || servers.isEmpty) return;
  final cache = _primedServers[w.services.entityDirectory] ??= {};
  cache[_primedKey(serverId, userId)] = [
    for (final server in servers.whereType<Map>())
      Map<String, dynamic>.from(server),
  ];
}

/// The profile row with the primed joint `servers` carried over when the
/// fetched profile has none (ProfilePanel's fallback merge).
Map<String, dynamic> withPrimedServers(
  WorkspaceController w,
  Map<String, dynamic> profile,
  String? serverId,
  String userId,
) {
  if (serverId == null || profile['servers'] != null) return profile;
  final primed =
      _primedServers[w.services.entityDirectory]?[_primedKey(serverId, userId)];
  return primed == null ? profile : {...profile, 'servers': primed};
}
