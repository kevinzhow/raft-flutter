import 'dart:async';

import 'package:raft_ui/raft_ui.dart'
    show
        RaftbenchChannelSummary,
        RaftbenchEvidenceMessage,
        RaftbenchOverviewSnapshot,
        raftbenchOverviewChannelLimit;

import 'raftbench_hosted_controller.dart' show RaftbenchRequest;

/// Explicit foreground message reads for the legacy phrase scan (Web
/// `raftbench/liveMessages.ts`): the normal human message API, so the server's
/// channel ACL applies, capped by the caller, four requests in flight. A
/// denied channel contributes no message and no signal count.
const raftbenchMessageWindowLimit = 200;

class RaftbenchMessageSnapshot {
  const RaftbenchMessageSnapshot({
    required this.messages,
    required this.fetchedAt,
    required this.historyLimited,
    required this.mayHaveOlder,
  });
  final List<RaftbenchEvidenceMessage> messages;
  final DateTime fetchedAt;
  final bool historyLimited, mayHaveOlder;
}

RaftbenchEvidenceMessage? _evidence(Object? value, String channelId) {
  if (value is! Map) return null;
  final id = value['id'],
      channel = value['channelId'],
      sender = value['senderId'];
  final content = value['content'], createdAt = value['createdAt'];
  final type = value['senderType'], name = value['senderName'];
  final kind = value['messageType'];
  if (id is! String ||
      id.isEmpty ||
      channel is! String ||
      channel != channelId ||
      sender is! String ||
      content is! String ||
      createdAt is! String ||
      DateTime.tryParse(createdAt) == null ||
      !(type == 'user' || type == 'agent' || type == 'external_projection') ||
      !(name == null || name is String) ||
      !(kind == null || kind == 'chat' || kind == 'system')) {
    return null;
  }
  // Only the minimal evidence fields are kept: no attachments, forwarded
  // bundles, mentions or receiver-private metadata.
  return RaftbenchEvidenceMessage(
    id: id,
    channelId: channelId,
    senderType: type as String,
    senderId: sender,
    senderName: name as String?,
    messageType: kind as String?,
    content: content,
    createdAt: createdAt,
  );
}

Future<RaftbenchMessageSnapshot> loadRaftbenchMessageSnapshot(
  RaftbenchRequest request,
  String channelId, {
  DateTime Function()? now,
}) async {
  final data = await request(
    'GET',
    '/messages/channel/${Uri.encodeComponent(channelId)}',
    query: {'limit': raftbenchMessageWindowLimit},
  );
  if (data is! Map || data['messages'] is! List) {
    throw const FormatException('Invalid message response');
  }
  final messages = <RaftbenchEvidenceMessage>[];
  final ids = <String>{};
  for (final row in data['messages'] as List) {
    final message = _evidence(row, channelId);
    if (message == null || !ids.add(message.id)) {
      throw const FormatException('Invalid message row');
    }
    messages.add(message);
  }
  return RaftbenchMessageSnapshot(
    messages: messages,
    fetchedAt: (now ?? DateTime.now)(),
    historyLimited: data['historyLimited'] == true,
    mayHaveOlder: messages.length >= raftbenchMessageWindowLimit,
  );
}

/// Read 1..20 channels. [isCurrent] fences the whole read: once it is false
/// the result is abandoned with [StateError].
Future<RaftbenchOverviewSnapshot> loadRaftbenchChannelSnapshots(
  RaftbenchRequest request,
  Iterable<String> channelIds, {
  bool Function()? isCurrent,
  DateTime Function()? now,
}) async {
  final targets = channelIds.toSet().toList();
  if (targets.isEmpty || targets.length > raftbenchOverviewChannelLimit) {
    throw const FormatException('Expected 1–20 selected channels');
  }
  final accepted = <(String, RaftbenchMessageSnapshot)>[];
  final unavailable = <String>[];
  var next = 0;
  void fence() {
    if (isCurrent != null && !isCurrent()) throw StateError('Stale read');
  }

  Future<void> worker() async {
    while (next < targets.length) {
      fence();
      final channelId = targets[next++];
      try {
        accepted.add((
          channelId,
          await loadRaftbenchMessageSnapshot(request, channelId, now: now),
        ));
      } catch (_) {
        fence();
        unavailable.add(channelId);
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < (targets.length < 4 ? targets.length : 4); i++)
      worker(),
  ]);
  fence();
  if (accepted.isEmpty) throw StateError('No channel could be read');
  accepted.sort((a, b) => a.$1.compareTo(b.$1));
  return RaftbenchOverviewSnapshot(
    messages: [for (final (_, s) in accepted) ...s.messages],
    fetchedAt: (now ?? DateTime.now)(),
    historyLimited: accepted.any((r) => r.$2.historyLimited),
    mayHaveOlder: accepted.any((r) => r.$2.mayHaveOlder),
    channels: [
      for (final (id, s) in accepted)
        RaftbenchChannelSummary(id, s.messages.length),
    ],
    unavailableChannelIds: unavailable..sort(),
    requestedChannels: targets.length,
  );
}
