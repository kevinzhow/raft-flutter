import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import 'chat_navigation.dart';

Iterable<RaftTextReference> qualifiedTaskLinks(
  WorkspaceController workspace,
  String content,
) sync* {
  for (final task in raftQualifiedTaskReferences(content)) {
    final channel = task.dm
        ? resolveMessageDmReference(
            workspace.dms,
            task.conversation,
            requireUnique: false,
          )
        : resolveMessageChannelReference(workspace.channels, task.conversation);
    if (channel == null) continue;
    yield RaftTextReference(
      text: task.text,
      href: Uri(
        scheme: 'raft-ref',
        host: 'task',
        pathSegments: [channel.id, '${task.number}'],
      ).toString(),
    );
  }
}

RaftChannel? resolveMessageChannelReference(
  List<RaftChannel> channels,
  String name,
) => channels
    .where(
      (channel) =>
          {'channel', 'private', 'joint'}.contains(channel.type) &&
          channel.name.toLowerCase() == name.toLowerCase(),
    )
    .firstOrNull;

RaftChannel? resolveMessageDmReference(
  List<RaftChannel> channels,
  String peer, {
  bool requireUnique = true,
}) {
  final parts = peer.split('~');
  if (parts.length > 2) return null;
  final kind = switch (parts.lastOrNull) {
    'agent' when parts.length == 2 => 'agent',
    'human' when parts.length == 2 => 'user',
    _ => null,
  };
  if (parts.length == 2 && kind == null) return null;
  final matches = channels.where(
    (channel) =>
        (channel.string('peerName', channel.name) == parts.first ||
            (!requireUnique && channel.name == parts.first)) &&
        (kind == null || channel.string('peerType') == kind),
  );
  if (!requireUnique) return matches.firstOrNull;
  return matches.take(2).length == 1 ? matches.first : null;
}

Future<Map<String, dynamic>> readTaskReference(
  WorkspaceController workspace,
  String channelId,
  int number,
) async {
  final result = await workspace.query(
    '/tasks/channel/$channelId/number/$number',
  );
  return Map<String, dynamic>.from(result['task']);
}

void openQualifiedTaskSurface(
  WorkspaceController workspace,
  Map<String, dynamic> task,
  void Function(Map<String, dynamic>) openTask, {
  ChatNavigation? navigation,
}) {
  final profiles = navigation?.profiles ?? workspace;
  final host = navigation?.workspace ?? workspace;
  if (profiles.location.profile != null) profiles.closeProfile();
  if (task['isLegacy'] != true) {
    openTask(task);
    return;
  }
  final channelId = task['channelId'];
  if (channelId is! String) return;
  final channel = host.channelById(channelId);
  final slug = host.location.serverSlug;
  if (channel == null || slug.isEmpty) return;
  host.closeThread(navigate: false);
  host.navigation.navigate(
    RaftLocation.at(
      serverSlug: slug,
      route: channel.type == 'dm' ? RaftRoute.dm : RaftRoute.channel,
      entityId: channel.id,
      query: const {'chatTab': 'tasks'},
    ),
  );
  openTask(task);
  if (host.channel?.id != channelId) {
    unawaited(host.resolveConversationChannel(channelId));
  }
}
