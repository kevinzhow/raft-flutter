import '../data/workspace_controller.dart';

/// Web ThreadsInbox `markAllRead({after: activityReadTogglesSettled()})`: Mark
/// all read goes out only once every queued Mark as Read / Mark as Unread
/// write of a row has settled, so the global read cannot overtake (and undo)
/// a row's own unread. Only this path waits; a single row's read does not.
Future<void> activityMarkAllRead(
  WorkspaceController w,
  Future<void> Function() send,
) async {
  await w.conversationReads.readTogglesSettled();
  await send();
}
