// Web useCreateTaskChannel (createTaskForm.ts): the channel a create from the
// Tasks page goes in. Options are the account's own live, postable channels
// by name; the pick starts at the default only when it is one of them.
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';

List<({String id, String label})> createTaskChannelOptions(
  WorkspaceController w,
) {
  final channels = [
    for (final c in w.channels)
      if (const {'channel', 'private', 'joint'}.contains(c.type) &&
          raftCanWriteTaskChannel(w.server?.string('role'), c))
        c,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [for (final c in channels) (id: c.id, label: '#${c.name}')];
}

String? createTaskInitialChannel(WorkspaceController w, String? preferred) =>
    createTaskChannelOptions(w).any((o) => o.id == preferred)
    ? preferred
    : null;
