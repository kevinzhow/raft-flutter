import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import 'workspace_controller.dart';

final _pendingTaskBuckets = Expando<Map<String, Future<dynamic>>>();

/// Source taskStore.loadTasks440–467 coalesces mounted consumers of the same
/// parent-channel bucket. This shares only a currently pending HTTP request;
/// each consumer still owns its acceptance and authority checks.
Future<dynamic> readSourceTaskBucket(WorkspaceController w, String channelId) {
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == channelId).firstOrNull;
  final key = jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.client.serverId,
    w.server?.id,
    w.server?.string('role'),
    channelId,
    channel?.joined,
    channel?.archived,
    channel?.json['channelCapabilities'],
  ]);
  final RaftClient client = w.client;
  final pending = _pendingTaskBuckets[client] ??= {};
  if (pending[key] case final request?) return request;
  late final Future<dynamic> request;
  request = w
      .query('/tasks/channel/${Uri.encodeComponent(channelId)}')
      .whenComplete(() {
        if (identical(pending[key], request)) pending.remove(key);
      });
  pending[key] = request;
  return request;
}
