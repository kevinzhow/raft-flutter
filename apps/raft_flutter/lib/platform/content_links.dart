/// The Web client's origin, for links a person opens in a browser (public
/// page, invite, message link, billing return, mobile download QR).
///
/// The API origin does not serve the Web client, so a link built from it opens
/// an API 404. Resolution order:
///  1. the build's `RAFT_FRONTEND_ORIGIN`, when valid and explicitly bound to
///     this API through `RAFT_ORIGIN` (the pinned desktop Web uses
///     VITE_FRONTEND_URL; an alias is bound to exactly one API);
///  2. the official pairing for a known official API origin (release builds
///     pass no frontend define, so this is what the shipped app uses);
///  3. the coordinator's own origin (self-hosted servers: the Web client is
///     assumed to be served next to the API unless the build says otherwise).
class ContentLinks {
  /// Official API origin -> the Web app origin that serves it. Mirrors the
  /// pinned Web's production runtime preset (`desktopRuntimeEnvironment.ts`:
  /// frontend https://app.raft.build, API https://api.raft.build); the
  /// api.slock.ai pair is the legacy production host the same Web build
  /// served (`LEGACY_PRODUCTION_SERVER_URL`, `app.slock.ai` in
  /// `defaultRaftPermalinkHostnames`). tool/release.py bakes the raft.build
  /// pair into release builds and tool/tests/test_release.py keeps it equal
  /// to this table.
  static const officialWebOrigins = <String, String>{
    'https://api.raft.build': 'https://app.raft.build',
    'https://api.slock.ai': 'https://app.slock.ai',
  };

  /// The official Web origin for [coordinator], or null for any other server.
  static Uri? officialWebOrigin(String coordinator) {
    final origin = Uri.tryParse(coordinator.trim());
    if (origin == null || !origin.hasScheme || origin.host.isEmpty) return null;
    final web = officialWebOrigins[origin.origin];
    return web == null ? null : Uri.parse(web);
  }

  /// Web origins that may hand Login with Raft to this app's session.
  ///
  /// Production artifacts still redirect through the legacy Web host before
  /// its redirect to the current one. Both belong to the official production
  /// service. A self-hosted coordinator or an explicitly different frontend
  /// keeps its own exact origin; official aliases do not inherit its session.
  static List<Uri> loginWebOriginsFor(String coordinator, Uri frontend) {
    final paired = officialWebOrigins[coordinator];
    if (paired == null ||
        frontend.userInfo.isNotEmpty ||
        frontend.origin != paired) {
      return [frontend];
    }
    return [for (final origin in officialWebOrigins.values) Uri.parse(origin)];
  }

  static Uri originFor(String coordinator, {String? frontend, String? api}) {
    final origin = Uri.parse(coordinator);
    final compiled =
        frontend ?? const String.fromEnvironment('RAFT_FRONTEND_ORIGIN');
    final boundApi =
        api ??
        const String.fromEnvironment(
          'RAFT_ORIGIN',
          defaultValue: 'https://api.raft.build',
        );
    return _explicit(origin, compiled, boundApi) ??
        officialWebOrigin(coordinator) ??
        origin;
  }

  static Uri? _explicit(Uri origin, String compiled, String boundApi) {
    if (compiled.isEmpty || Uri.tryParse(boundApi)?.origin != origin.origin) {
      return null;
    }
    final value = Uri.tryParse(compiled);
    if (value == null ||
        !['https', 'http'].contains(value.scheme) ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.query.isNotEmpty ||
        value.fragment.isNotEmpty ||
        value.path.isNotEmpty && value.path != '/' ||
        value.scheme == 'http' &&
            !['localhost', '127.0.0.1', '::1'].contains(value.host)) {
      return null;
    }
    return Uri.parse(value.origin);
  }

  static Uri messageUrl({
    required Uri origin,
    required String slug,
    required String channelId,
    required String messageId,
    String kind = 'channel',
    String? parentMessageId,
  }) => origin.replace(
    path: '/s/$slug/${kind == 'dm' ? 'dm' : 'channel'}/$channelId',
    queryParameters: {
      'msg': messageId,
      if (parentMessageId != null) 'thread': '$channelId:$parentMessageId',
    },
    fragment: null,
  );
}
