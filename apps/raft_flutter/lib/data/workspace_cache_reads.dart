import 'package:raft_client/raft_client.dart';

import 'workspace_cache.dart';

/// Window reads may use committed data; preferences and drafts keep FIFO reads.
class WorkspaceCacheReads {
  static Future<dynamic> read(
    WorkspaceCache? cache,
    RaftClient client,
    Future<void> writes,
    String kind,
    String id, {
    String? server,
    required bool Function() active,
    required bool Function(String) visible,
    required Object Function(String) authority,
  }) async {
    if (cache == null || client.user == null) return null;
    final origin = client.origin,
        principal = client.user!.id,
        serverId = server ?? client.serverId ?? '';
    if (cache is! CommittedWorkspaceCache ||
        !const {'window', 'thread-window'}.contains(kind)) {
      await writes;
      return cache.read(origin, principal, serverId, kind, id);
    }
    final ticket = authority(id);
    bool current() => active() && visible(id) && ticket == authority(id);
    if (!current()) return null;
    final value = await (cache as CommittedWorkspaceCache).readCommittedWindow(
      origin,
      principal,
      serverId,
      kind,
      id,
    );
    // A cache purge can still be behind the controller's pending write. Fence
    // the UI's authority as well as the database's own purge generation.
    return current() &&
            (value is! Map ||
                [
                  value['channelId'],
                  value['parentChannelId'],
                ].whereType<String>().every(visible))
        ? value
        : null;
  }
}
