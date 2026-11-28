import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import 'joint_channel_link_intent.dart';

/// `GET /announcements/images/:id`: public, served without credentials.
String announcementImageUrl(String origin, String assetId) =>
    Uri.parse(origin)
        .resolve('/api/announcements/images/${Uri.encodeComponent(assetId)}')
        .toString();

String? announcementInAppPath(String origin, String href) {
  if (href.startsWith('?') || href.startsWith('#')) return href;
  final base = ContentLinks.originFor(origin);
  final parsed = Uri.tryParse(href);
  if (parsed == null) return null;
  final uri = base.resolveUri(parsed);
  if (!uri.hasAuthority || uri.origin != base.origin) return null;
  return '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}'
      '${uri.hasFragment ? '#${uri.fragment}' : ''}';
}

/// The Web CTA `navigate(href)` for an internal href (`/...` or `?...`).
///
/// * `?dialog=create-joint-channel` is the feature-owned link intent of
///   `JointChannelLinkIntent`.
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
  var uri = Uri.tryParse(href);
  if (uri == null) return;
  if (href.startsWith('?')) {
    if (isJointChannelLinkIntent(uri)) {
      unawaited(openJointChannelLinkIntent(context, w));
    }
    return;
  }
  final slug = w.server?.string('slug');
  if (href.startsWith('#')) {
    uri = w.location.uri.resolveUri(uri);
  } else if (slug != null &&
      !const {
        's',
        'servers',
        'download',
        'artifacts',
        'connections',
        'appsumo',
        'dev',
        'palette-audit',
        'login',
        'login-with-raft',
        'login-with-slock',
        'login-with-slock-human',
        'community',
        'integration-invites',
      }.contains(uri.pathSegments.firstOrNull)) {
    uri = uri.replace(pathSegments: ['', 's', slug, ...uri.pathSegments]);
  }
  final segments = uri.pathSegments;
  if (slug != null &&
      slug.isNotEmpty &&
      segments.length >= 2 &&
      segments[0] == 's' &&
      segments[1] == slug) {
    try {
      final location = RaftLocation.fromUri(uri);
      if (location.route != RaftRoute.unknown) {
        w.navigation.navigate(location);
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        w.notifyListeners();
        if (isJointChannelLinkIntent(uri)) {
          unawaited(openJointChannelLinkIntent(context, w));
        }
        return;
      }
    } on FormatException {
      // Not a route the app knows: the browser opens it.
    }
  }
  openExternal(
    ContentLinks.originFor(w.client.origin).resolveUri(uri).toString(),
  );
}
