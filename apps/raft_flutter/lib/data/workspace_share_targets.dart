import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'workspace_entity_directory.dart';

class IncomingShareTarget {
  const IncomingShareTarget(
    this.label, {
    this.channel,
    this.userId,
    this.agentId,
  });
  final String label;
  final RaftChannel? channel;
  final String? userId, agentId;
  bool get requiresJoin => channel != null && !channel!.joined;
  String get key => channel?.id ?? 'user:$userId:agent:$agentId';
}

bool acceptsSharedDraft(RaftChannel channel) =>
    channel.joined &&
    !channel.archived &&
    channel.type != 'thread' &&
    channel.json['readOnly'] != true;

/// Pure projection of one server's channel rows and peer directories into the
/// destinations a share can be added to. Shared by the device-cached seed and
/// the network read, so a cached row and its fresh replacement have one shape.
List<IncomingShareTarget> shareTargetsFor({
  required RaftRecord server,
  required List<RaftChannel> channels,
  List<Map> agents = const [],
  List<Map> members = const [],
  String? selfId,
}) {
  final targets = <IncomingShareTarget>[
    for (final c in channels.where(
      (c) =>
          acceptsSharedDraft(c) ||
          !c.joined &&
              !c.archived &&
              c.type == 'channel' &&
              c.json['readOnly'] != true &&
              raftCan(server.string('role'), 'joinPublicChannels'),
    ))
      IncomingShareTarget(
        c.type == 'dm'
            ? '@${c.json['peerDisplayName'] ?? c.json['peerName'] ?? c.name}'
            : '#${c.name}',
        channel: c,
      ),
  ];
  void peers(List<Map> rows, bool agent) {
    for (final row in rows) {
      final id = agent ? row['id'] : row['userId'] ?? row['id'];
      final person = row['user'] is Map ? row['user'] as Map : row;
      final name =
          person['displayName'] ?? person['name'] ?? person['username'];
      if (id is! String || name is! String || id == selfId) continue;
      if (channels.any(
        (c) =>
            c.type == 'dm' &&
            (c.json[agent ? 'agentId' : 'peerUserId'] == id ||
                c.json['peerId'] == id),
      )) {
        continue;
      }
      targets.add(
        IncomingShareTarget(
          '@$name',
          agentId: agent ? id : null,
          userId: agent ? null : id,
        ),
      );
    }
  }

  if (raftCan(server.string('role'), 'viewAgents')) peers(agents, true);
  if (raftCan(server.string('role'), 'viewMembers')) peers(members, false);
  final unique = {for (final target in targets) target.key: target}.values
      .toList();
  unique.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return unique;
}

/// Server directory reads do not select that server or create conversations.
/// Every read starts at once: the cost is one round trip, not four.
Future<List<IncomingShareTarget>> incomingShareTargets(
  RaftClient client,
  RaftRecord server,
) async {
  final role = server.string('role');
  Future<List<Map>> peers(String path) async {
    try {
      final result = await client.getForServer(server.id, path);
      final rows = result is List
          ? result
          : result is Map
          ? result['members']
          : null;
      return rows is List ? rows.whereType<Map>().toList() : const [];
    } on RaftApiException {
      // An unavailable peer directory does not hide joined conversations.
      return const [];
    }
  }

  final results = await Future.wait<dynamic>([
    client.getForServer(server.id, '/channels'),
    client.getForServer(server.id, '/channels/dm'),
    if (raftCan(role, 'viewAgents')) peers('/agents') else Future.value(null),
    if (raftCan(role, 'viewMembers'))
      peers('/servers/${server.id}/members')
    else
      Future.value(null),
  ]);
  return shareTargetsFor(
    server: server,
    channels: [
      for (final result in results.take(2))
        if (result is List)
          for (final row in result.whereType<Map>())
            RaftChannel(Map<String, dynamic>.from(row)),
    ],
    agents: results[2] is List<Map> ? results[2] as List<Map> : const [],
    members: results[3] is List<Map> ? results[3] as List<Map> : const [],
    selfId: client.user?.id,
  );
}

/// Live, read-only bindings for the device-cached share destination seed.
/// This neither selects a server nor creates a conversation.
class WorkspaceShareTargets {
  const WorkspaceShareTargets({
    required this._selectedServer,
    required this._channels,
    required this._dms,
    required this._peerRows,
    required this._selfId,
    required this._cachedChannelDirectory,
  });

  final RaftRecord? Function() _selectedServer;
  final List<RaftChannel> Function() _channels;
  final List<RaftChannel> Function() _dms;
  final List<Map> Function(WorkspaceEntityKind) _peerRows;
  final String? Function() _selfId;
  final Future<List<RaftChannel>?> Function(String) _cachedChannelDirectory;

  /// The seed is display only. The picker and hand-off still revalidate it.
  /// Keep selfId live after the asynchronous disk read, as in the old helper.
  FutureOr<List<IncomingShareTarget>?> cached(RaftRecord server) {
    if (server.id == _selectedServer()?.id) {
      final channels = [..._channels(), ..._dms()];
      if (channels.isEmpty) return null;
      return shareTargetsFor(
        server: server,
        channels: channels,
        agents: _peerRows(WorkspaceEntityKind.agents),
        members: _peerRows(WorkspaceEntityKind.members),
        selfId: _selfId(),
      );
    }
    return _cachedChannelDirectory(server.id).then(
      (channels) => channels == null || channels.isEmpty
          ? null
          : shareTargetsFor(
              server: server,
              channels: channels,
              selfId: _selfId(),
            ),
    );
  }
}
