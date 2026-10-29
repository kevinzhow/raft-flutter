import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import 'workspace_message_host.dart';

final _pendingTaskBuckets = Expando<Map<String, Future<dynamic>>>();

/// Source taskStore.loadTasks440–467 coalesces mounted consumers of the same
/// parent-channel bucket. This shares only a currently pending HTTP request;
/// each consumer still owns its acceptance and authority checks.
Future<dynamic> readSourceTaskBucket(
  WorkspaceMessageHost host,
  String channelId, {
  RaftChannel? parentMetadata,
}) {
  final w = host.messageDomain;
  if (parentMetadata != null && parentMetadata.id != channelId) {
    throw ArgumentError('Task bucket metadata must match the parent channel');
  }
  final channel =
      parentMetadata ??
      [
        ...w.channels.channels,
        ...w.channels.dms,
      ].where((c) => c.id == channelId).firstOrNull;
  final key = jsonEncode([
    w.transport.client.origin,
    w.transport.client.generation,
    w.transport.client.user?.id,
    w.transport.client.serverId,
    w.context.server?.id,
    w.context.server?.string('role'),
    channelId,
    channel?.joined,
    channel?.archived,
    channel?.json['channelCapabilities'],
  ]);
  final RaftClient client = w.transport.client;
  final pending = _pendingTaskBuckets[client] ??= {};
  if (pending[key] case final request?) return request;
  late final Future<dynamic> request;
  request = w.transport
      .query('/tasks/channel/${Uri.encodeComponent(channelId)}')
      .whenComplete(() {
        if (identical(pending[key], request)) pending.remove(key);
      });
  pending[key] = request;
  return request;
}
