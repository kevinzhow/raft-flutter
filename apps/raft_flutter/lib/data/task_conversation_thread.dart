// Task v2 conversations in the thread machinery (Web threadStore
// `openTaskConversation` / `ensureTaskModalThreadChannel`).
import 'package:raft_client/raft_client.dart';

import 'workspace_message_windows.dart' show MessageWindowRequest;
import 'thread_rooms.dart';
import 'workspace_messages.dart';

/// The thread-window key of a task's own conversation: it has no parent
/// message (Web AuthenticatedThreadPanel `conversationKey`).
String taskConversationKey(String taskId) => 'task:$taskId';

Future<void> authorizeTaskConversation(
  RaftClient client, {
  required String conversationId,
  required String serverId,
  required String taskId,
  required String parentChannelId,
  required bool Function() current,
  Map? channelDetail,
}) async {
  final detail =
      channelDetail ??
      await RaftClient.runFresh<Future<dynamic>>(
        () => client.get('/channels/${Uri.encodeComponent(conversationId)}'),
      );
  if (!current() ||
      detail is! Map ||
      detail['id'] != conversationId ||
      detail['serverId'] != serverId ||
      detail['type'] != 'task' ||
      detail['taskId'] != taskId ||
      detail['parentChannelId'] != parentChannelId) {
    throw const RaftApiException('Unavailable task conversation.');
  }
}

/// A task conversation has no parent to resolve. One that does not exist yet
/// (created lazily, like a thread before its first reply) opens empty with
/// its composer ready: there is nothing to look up either.
bool taskConversationOpened(
  WorkspaceMessages m,
  MessageWindowRequest request, {
  required bool seed,
}) {
  m.state.threadParent = null;
  m.state.threadParentLoading = false;
  final id = m.state.threadChannelId;
  if (id == null) {
    m.state.threadLoading = false;
    m.state.threadResolutionLoading = false;
    return false;
  }
  if (!seed || !request.current) return false;
  final retained = m.transport.client.peekGet(
    '/messages/channel/$id',
    query: {'limit': 50},
  );
  if (retained is! Map<String, dynamic> || retained['messages'] is! List) {
    return false;
  }
  final boundary = m.messageWindows.acceptThreadPage(
    request,
    id,
    retained,
    focused: false,
    retainOlder: false,
    retainedHasMore: false,
  );
  m.state.threadHasMore = boundary.more;
  m.state.threadHistoryLimited = boundary.limited;
  m.state.threadLoading = false;
  return true;
}

/// The open thread's channel, created on the first durable send: a task's
/// own conversation through its task, else `POST /channels/:id/threads`.
Future<String?> createThreadChannel(WorkspaceMessages m) async {
  final taskId = m.threadIdentity?.taskId;
  if (taskId != null) return createTaskConversation(m, taskId);
  final parentId = m.threadParentMessageId,
      parentChannelId = m.threadParentChannelId;
  if (parentId == null || parentChannelId == null) return null;
  final request = m.windowRequest(
    parentChannelId,
    thread: true,
    checkNavigation: true,
    allowed: () =>
        parentId == m.threadParentMessageId &&
        parentChannelId == m.threadParentChannelId,
  );
  final value = await m.transport.client.post(
    '/channels/$parentChannelId/threads',
    data: {'parentMessageId': parentId},
  );
  if (!request.current) {
    throw const RaftApiException('The thread changed. Try again.');
  }
  m.state.threadChannelId = value['threadChannelId'];
  ThreadRooms.join(m);
  m.context.changed();
  return m.state.threadChannelId;
}

/// The first durable send (or Follow) of a task without a conversation
/// creates it: `POST /tasks/:id/conversation` answers this server's LOCAL
/// conversation, which the open window binds.
Future<String?> createTaskConversation(
  WorkspaceMessages m,
  String taskId,
) async {
  final identity = m.threadIdentity;
  final value = await m.transport.client.post(
    '/tasks/${Uri.encodeComponent(taskId)}/conversation',
  );
  final id = value is Map ? value['conversationChannelId'] : null;
  if (id is! String || id.isEmpty) {
    throw const RaftApiException(
      'Task conversation creation did not return a channel id',
    );
  }
  if (m.threadIdentity?.taskId != taskId || m.threadIdentity != identity) {
    throw const RaftApiException('The task changed. Try again.');
  }
  m.state.threadChannelId = id;
  ThreadRooms.join(m);
  m.context.changed();
  return id;
}
