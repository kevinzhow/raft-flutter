import 'content_links.dart';
import 'content_target.dart';

/// Native HTTPS entry points. A build can opt out with RAFT_APP_LINKS=false; domain
/// association and the installed app's signing identity remain OS prerequisites.
/// Explicit raft: links remain available without HTTPS association.
abstract final class RaftAppLinks {
  static const enabled = bool.fromEnvironment(
    'RAFT_APP_LINKS',
    defaultValue: true,
  );

  /// The hosts the association files are served from: the production web app
  /// and the legacy production host the same Web build served (staging never
  /// claims links).
  static const hostnames = {'app.raft.build', 'app.slock.ai'};

  /// Official frontend origins, plus an explicit frontend bound to this build's
  /// API. This permits a self-hosted build, not an arbitrary incoming host.
  static Set<String> origins({String? frontend, String? api}) {
    final result = {for (final host in hostnames) 'https://$host'};
    final configured =
        frontend ?? const String.fromEnvironment('RAFT_FRONTEND_ORIGIN');
    final coordinator =
        api ??
        const String.fromEnvironment(
          'RAFT_ORIGIN',
          defaultValue: 'https://api.raft.build',
        );
    final bound = Uri.tryParse(coordinator);
    if (bound == null ||
        !bound.hasAuthority ||
        bound.host.isEmpty ||
        !const {'http', 'https'}.contains(bound.scheme) ||
        bound.userInfo.isNotEmpty ||
        bound.hasQuery ||
        bound.hasFragment ||
        bound.path.isNotEmpty && bound.path != '/') {
      return result;
    }
    final origin = ContentLinks.originFor(
      coordinator,
      frontend: configured,
      api: coordinator,
    );
    if (origin.scheme == 'https' && !origin.hasPort) result.add(origin.origin);
    return result;
  }

  /// Validate before retaining a URL during account restoration. The active
  /// coordinator still validates origin, token, membership and visible context.
  static bool accepts(Uri uri, {bool? on, String? frontend, String? api}) {
    if (!(on ?? enabled)) return false;
    if (uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.toString().length > 2048 ||
        !origins(frontend: frontend, api: api).contains(uri.origin)) {
      return false;
    }
    return ContentTarget.parse(uri, origin: Uri.parse(uri.origin)) != null ||
        _invitePath(uri, 'join') ||
        _invitePath(uri, 'integration-invites');
  }

  static bool _invitePath(Uri uri, String path) =>
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == path &&
      RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(uri.pathSegments.last);

  /// Called after either the native v1 origin or HTTPS allowlist was checked.
  static bool isPrivateInvite(Uri uri) =>
      _invitePath(uri, 'integration-invites');
}
