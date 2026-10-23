import 'package:raft_client/raft_client.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';

/// Web `genericAppDocumentTitle`: the title outside a workspace.
const appWindowTitle = 'Raft';

/// Web `getServerRouteDocumentTitle` (browserDocumentTitle.ts): `#channel |
/// Workspace | Raft`, `#channel - Thread | Workspace | Raft` while a thread is
/// open, `Workspace | Raft` on every other page. The workspace label is its
/// name, or its slug when the name is blank.
String serverRouteWindowTitle({
  required String serverName,
  required String serverSlug,
  String? channelLabel,
  String? threadChannelLabel,
}) {
  String? segment(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  final server = segment(serverName) ?? serverSlug;
  final thread = segment(threadChannelLabel);
  if (thread != null) return '$thread - Thread | $server | $appWindowTitle';
  final channel = segment(channelLabel);
  if (channel != null) return '$channel | $server | $appWindowTitle';
  return '$server | $appWindowTitle';
}

/// Web `documentTitleChannelLabel`: `@peer` for a DM, `#name` for a channel;
/// null when the conversation is unknown or has no readable name.
String? windowTitleChannelLabel(RaftChannel? channel) {
  if (channel == null) return null;
  final label = channel.type == 'dm'
      ? channel.firstNonEmpty(const ['peerDisplayName', 'peerName', 'name'])
      : channel.string('name');
  final text = label.trim();
  if (text.isEmpty) return null;
  return channel.type == 'dm' ? '@$text' : '#$text';
}

/// The window title for the workspace's accepted location, as the Web
/// ServerResolver computes it from the route, the open thread and the channel
/// lists. [appWindowTitle] while no workspace is open.
String workspaceWindowTitle(WorkspaceController? w) {
  final server = w?.server;
  final slug = server?.string('slug') ?? '';
  if (w == null || server == null || slug.isEmpty) return appWindowTitle;
  final location = w.location;
  final conversations = [...w.channels, ...w.dms];
  String? label(String? id) {
    if (id == null) return null;
    final channel = conversations.where((c) => c.id == id).firstOrNull;
    return windowTitleChannelLabel(channel);
  }

  final inConversation = {
    RaftRoute.channel,
    RaftRoute.dm,
  }.contains(location.route);
  return serverRouteWindowTitle(
    serverName: server.string('name'),
    serverSlug: slug,
    channelLabel: inConversation ? label(location.entityId) : null,
    threadChannelLabel: label(location.thread?.channelId),
  );
}
