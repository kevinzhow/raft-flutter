import 'dart:convert';

import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// Whether [task] still belongs on the workspace Tasks board.
///
/// Source shouldIncludeInServerTasks. The page passes this to the session
/// window, so the window does not read the controller itself.
bool serverTaskBelongs(
  WorkspaceController controller,
  Map<String, dynamic> task,
) {
  if (!raftTaskStatuses.contains(task['status'])) return false;
  final type = task['channelType'];
  if (type is String && !const {'channel', 'private', 'joint'}.contains(type)) {
    return false;
  }
  final channel = [
    ...controller.channels,
    ...controller.dms,
  ].where((item) => item.id == task['channelId']).firstOrNull;
  return channel == null || controller.can('viewChannel', resource: channel);
}

/// Name of the channel [channelId], from the controller the page already holds.
String? serverTaskChannelName(
  WorkspaceController controller,
  Object? channelId,
) {
  if (channelId is! String) return null;
  return [
    ...controller.channels,
    ...controller.dms,
  ].where((item) => item.id == channelId).firstOrNull?.name;
}

/// Identity of the workspace Tasks page: section `tasks`, no channel.
String serverTaskIdentity(WorkspaceController controller) => jsonEncode([
  controller.client.origin,
  controller.client.generation,
  controller.client.user?.id,
  controller.client.serverId,
  controller.server?.id,
  controller.server?.string('role'),
  'tasks',
  null,
]);
