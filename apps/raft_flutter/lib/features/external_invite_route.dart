import '../platform/content_links.dart';

enum ExternalInviteRoute {
  invitation('external-invite', 'Sign in to accept your invite to a channel'),
  approval('server-connect-requests', 'Sign in to review this request');

  const ExternalInviteRoute(this.segment, this.signInPurpose);

  final String segment, signInPurpose;

  static ({ExternalInviteRoute kind, String id})? parse(
    Uri uri,
    String origin,
  ) {
    if (uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.toString().length > 2048) {
      return null;
    }
    final native = uri.scheme == 'raft' && uri.host == 'v1' && !uri.hasPort;
    if ((uri.hasScheme || uri.hasAuthority) && !native) {
      if (!const {'http', 'https'}.contains(uri.scheme) ||
          !uri.hasAuthority ||
          !ContentLinks.loginWebOriginsFor(
            origin,
            ContentLinks.originFor(origin),
          ).any((allowed) => allowed.origin == uri.origin)) {
        return null;
      }
    }
    final segments = uri.pathSegments;
    if (segments.length != 2 ||
        !RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(segments.last)) {
      return null;
    }
    final kind = values
        .where((kind) => kind.segment == segments.first)
        .firstOrNull;
    return kind == null ? null : (kind: kind, id: segments.last);
  }
}
