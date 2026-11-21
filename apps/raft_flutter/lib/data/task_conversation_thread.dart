// Task v2 conversations in the thread machinery (Web threadStore
// `openTaskConversation` / `ensureTaskModalThreadChannel`), and the focused
// reply read the thread open shares with them.
import 'package:raft_client/raft_client.dart';

import 'message_history.dart';
import 'message_history_pages.dart';
import 'message_window_snapshot.dart';
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

/// The page around a focused reply. A hidden target starts the visible
/// window immediately after the cutoff. A plain 404 falls back to latest.
Future<Map<String, dynamic>?> focusedThreadReplyPage(
  WorkspaceMessages m,
  MessageWindowRequest request,
  String focusedMessageId,
) async {
  try {
    return await MessageHistoryPages.context(
      m,
      request,
      m.state.threadChannelId!,
      focusedMessageId,
      thread: true,
    );
  } on RaftApiException catch (e) {
    if (e.status != 404) rethrow;
    if (!request.current) return null;
    m.state.highlightedMessageId = null;
    if (HiddenTarget.fromError(e)
        case HiddenTarget(target: final target, sequence: final sequence?)
        when target.id == focusedMessageId) {
      const limit = 50;
      final channelId = m.state.threadChannelId!;
      final page = await MessageHistoryPages.read(
        m,
        request,
        channelId,
        thread: true,
        after: sequence,
        limit: limit,
        localFirst: false,
      );
      if (!request.current) return null;
      final wire = page is MessageHistoryPage ? page.remotePage ?? page : page;
      final rows = acceptedWindowRows(wire['messages'], channelId);
      return page
        ..['historyLimited'] = true
        ..['hasOlder'] = false
        ..['hasNewer'] = rows.length >= limit;
    }
    return null;
  }
}
