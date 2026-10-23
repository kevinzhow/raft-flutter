import 'package:raft_client/raft_client.dart' show RaftChannel;

/// Web `handleOpenForwardedSource`: where the source label of a forwarded
/// bundle goes, as the `raft-ref:` link the message body already opens
/// (`message` jumps to the message, `thread` resolves the canonical thread
/// target first). Null when the source is not a channel this server lists (a
/// DM never is, and a forwarded copy keeps no other way in).
String? forwardedSourceHref(
  Iterable<RaftChannel> channels,
  Map<String, dynamic> item,
) {
  final messageId = item['sourceMessageId'];
  final target = item['sourceTargetSnapshot'];
  if (messageId is! String || target is! Map) return null;
  final thread = target['type'] == 'thread';
  final channelId = thread ? item['parentChannelId'] : item['sourceTargetId'];
  if (channelId is! String) return null;
  final channel = channels.where((c) => c.id == channelId).firstOrNull;
  if (channel == null || channel.type == 'dm') return null;
  return Uri(
    scheme: 'raft-ref',
    host: thread ? 'thread' : 'message',
    pathSegments: [channelId, messageId],
  ).toString();
}

/// Web `forwardedBundleBodyContent`: the forwarding note a person typed, or
/// empty when the message holds only the text the server writes ("Forwarded 2
/// messages") or nothing.
String forwardedNote(Object? metadata, String content) {
  final items = metadata is Map ? metadata['forwardedItems'] : null;
  final count = items is List ? items.length : 0;
  final generated = 'Forwarded $count message${count == 1 ? '' : 's'}';
  return content.trim() == generated
      ? ''
      : content.trim().isEmpty
      ? ''
      : content;
}
