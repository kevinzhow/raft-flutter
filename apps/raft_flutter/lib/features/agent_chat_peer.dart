import '../data/workspace_controller.dart';

/// Web `resolveDmPeerAvatar` (components/layout/dmPeerAvatar.ts): a DM peer's
/// avatar is read from the live agent directory once it knows the peer, a null
/// avatar included (null is the default avatar, not "unknown"). The listed DM's
/// `peerAvatarUrl` is a snapshot from when the tab loaded and only covers a peer
/// the directory does not know yet.
String? liveAgentDmPeerAvatarUrl(
  WorkspaceController w,
  Map<String, dynamic> dm,
) {
  final peerId = dm['peerId'];
  final live = peerId is String && peerId.isNotEmpty
      ? w.services.entityDirectory.agent(peerId)
      : null;
  final value = live == null ? dm['peerAvatarUrl'] : live['avatarUrl'];
  return value is String && value.isNotEmpty ? value : null;
}
