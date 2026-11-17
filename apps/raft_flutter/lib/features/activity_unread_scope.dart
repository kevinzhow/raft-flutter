import '../data/activity_unread_snapshot.dart';
import '../data/workspace_controller.dart';

/// The Unread snapshot and the Activity visit of one workspace (Web keeps them
/// as module state): the list remounts when the preview opens or closes, so
/// neither can belong to the list's State.
class ActivityUnreadScope {
  ActivityUnreadScope._();
  static final _owners = Expando<ActivityUnreadScope>();
  static ActivityUnreadScope of(WorkspaceController w) =>
      _owners[w] ??= ActivityUnreadScope._();

  final snapshots = ActivityUnreadSnapshotStore();
  final visit = ActivityVisit();
}
