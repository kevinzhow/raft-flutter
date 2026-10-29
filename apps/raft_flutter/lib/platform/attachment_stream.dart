import 'package:raft_client/raft_client.dart'
    show RequestPriority, ServerRateLimits;

import '../data/workspace_controller.dart';
import 'attachment_files.dart';
import 'attachment_http.dart';
import 'attachment_player.dart';
import 'video_cache.dart' show VideoCacheAccount;

/// The session-cache key of an attachment's media: one player per attachment
/// version, shared by its inline card and its viewer.
String attachmentMediaKey(Map<String, dynamic> metadata) =>
    '${metadata['id']}|${metadata['contentVersion'] ?? metadata['contentHash'] ?? metadata['updatedAt'] ?? ''}';

/// The streamed source of attachment [id]: its signed `disposition=inline`
/// URL, opened by the player itself (progressive range reads), with a way to
/// sign it again once when the signature has expired.
///
/// Rate limit: when the URL is served by the Raft server itself (a path under
/// `/api/attachments`) every request of the player counts against the user's
/// 120 per minute attachment limit, but the player's requests do not pass
/// through the app's [AttachmentHttp.governor]. The first request is
/// admitted here (paced, or refused after `maxWait`), which covers the usual
/// one to three requests of a progressive MP4 and keeps the rest of the
/// governor's 25 % headroom for seeks. A presigned storage URL on another host
/// is not counted by the server at all.
Future<AttachmentSource> attachmentStreamSource(
  WorkspaceController controller,
  String id, {
  String? channelId,
  Duration start = Duration.zero,
}) async {
  Future<Uri> sign({bool refresh = false}) async {
    final url = await controller.attachmentMedia.url(
      id,
      channelId: channelId,
      coalesce: !refresh,
      refresh: refresh,
    );
    final uri = AttachmentFiles.attachmentUri(url);
    await _admit(uri);
    return uri;
  }

  final uri = await sign();
  return AttachmentSource.network(
    uri,
    start: start,
    cacheKey: id,
    cacheAccount: _account(controller),
    refresh: () {
      controller.attachmentMedia.invalidateUrl(id);
      return sign(refresh: true);
    },
  );
}

/// Whose cache a video of [controller]'s session goes into; null (no cache)
/// when the session does not name its user.
VideoCacheAccount? _account(WorkspaceController controller) {
  final principal = controller.client.user?.id;
  if (principal == null || principal.isEmpty) return null;
  return VideoCacheAccount(controller.client.origin, principal);
}

/// Admits one request to [uri] when the Raft server counts it.
Future<void> _admit(Uri uri) async {
  if (!uri.path.startsWith('/api/')) return;
  final limits = ServerRateLimits.forRequest('GET', uri.path.substring(4));
  if (limits.isEmpty) return;
  // A bucket closed for longer than a foreground wait throws
  // RateLimitedException: the open fails ("Download to view") instead of
  // sending a request the server would refuse.
  await AttachmentHttp.governor.acquire(limits, RequestPriority.foreground);
}
