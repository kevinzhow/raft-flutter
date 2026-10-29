import 'dart:async';

import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';

/// Web TaskModalBar "View in thread" is offered for a task that has a thread
/// of its own: not a legacy task, and not a task whose message is itself a
/// thread reply (`!hostTask.isLegacy && hostTask.channelType !== "thread"`).
bool taskHasThreadToView(WorkspaceController w, Map<String, dynamic> task) {
  final channelId = task['channelId'], messageId = task['messageId'];
  if (task['isLegacy'] == true ||
      channelId is! String ||
      channelId.isEmpty ||
      messageId is! String ||
      messageId.isEmpty) {
    return false;
  }
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == channelId).firstOrNull;
  return (task['channelType'] ?? channel?.type) != 'thread';
}

/// Web `viewInThread`: leave the task surface for the ordinary side thread of
/// the same message, i.e. land on the message in its conversation and open its
/// replies, never re-opening the task modal. Published like a thread link
/// (ContentCoordinator): the complete destination once, then the parent
/// channel and the reply window load independently.
///
/// [closeTask] removes the task from the location first on a wide window (Web
/// closes the modal, then pushes the message); a compact window replaces the
/// task page's own entry so Back returns to the list the task came from.
Future<void> viewTaskInThread(
  WorkspaceController w,
  Map<String, dynamic> task, {
  required bool compact,
  required void Function() closeTask,
}) async {
  if (!taskHasThreadToView(w, task)) return;
  final channelId = task['channelId'] as String;
  final messageId = task['messageId'] as String;
  final threadChannelId = task['threadChannelId'];
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == channelId).firstOrNull;
  if (channel == null || !w.can('viewChannel', resource: channel)) return;
  if (!compact) closeTask();
  w.navigation.navigate(
    RaftLocation.at(
      serverSlug: w.location.serverSlug,
      route: channel.type == 'dm' ? RaftRoute.dm : RaftRoute.channel,
      entityId: channelId,
      query: {'thread': '$channelId:$messageId', 'msg': messageId},
    ),
    kind: compact ? RaftNavigationKind.replace : RaftNavigationKind.push,
  );
  w.channel = channel;
  await Future.wait([
    w.openThreadIdentity(
      parentChannelId: channelId,
      parentMessageId: messageId,
      initialThreadChannelId: threadChannelId is String
          ? threadChannelId
          : null,
      navigate: false,
    ),
    w.selectChannel(channel, navigate: false, preserveThread: true),
  ]);
}
