import 'package:flutter/widgets.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import 'create_joint_channel_dialog.dart';

/// `GET /announcements/images/:id`: public, served without credentials.
String announcementImageUrl(String origin, String assetId) =>
    Uri.parse(origin)
        .resolve('/api/announcements/images/${Uri.encodeComponent(assetId)}')
        .toString();

/// The Web CTA `navigate(href)` for an internal href (`/...` or `?...`).
///
/// * `?dialog=create-joint-channel` is the feature-owned link intent of
///   `JointChannelLinkIntent`: it opens the Create joint channel dialog when
///   this server may federate channels.
/// * A path inside the current server (`/s/<slug>/...`) navigates there.
/// * Any other path belongs to a Web route the app does not host (another
///   server, `/servers`, ...): it opens in the browser on the Web origin.
/// * Any other query only changes the Web URL: nothing to do here.
void openAnnouncementInternalLink(
  BuildContext context,
  WorkspaceController w,
  String href, {
  required void Function(String href) openExternal,
}) {
  final uri = Uri.tryParse(href);
  if (uri == null) return;
  if (href.startsWith('?')) {
    if (uri.queryParameters['dialog'] == 'create-joint-channel') {
      CreateJointChannelDialog.show(context, controller: w);
    }
    return;
  }
  final slug = w.server?.string('slug');
  final segments = uri.pathSegments;
  if (slug != null &&
      slug.isNotEmpty &&
      segments.length >= 2 &&
      segments[0] == 's' &&
      segments[1] == slug) {
    try {
      w.navigation.navigate(RaftLocation.fromUri(uri));
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      w.notifyListeners();
      return;
    } on ArgumentError {
      // Not a route the app knows: the browser opens it.
    }
  }
  openExternal(
    ContentLinks.originFor(w.client.origin).resolveUri(uri).toString(),
  );
}
