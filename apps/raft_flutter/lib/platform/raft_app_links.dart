/// Raft https links opening the app: Android App Links, iOS Universal Links and
/// macOS associated domains (docs/deployment.md, "Raft https links open the
/// app"). **Off.** Opening an https link in the installed app needs the Raft
/// domain to host `/.well-known/assetlinks.json` and
/// `/.well-known/apple-app-site-association`, which are not part of this
/// repository, so no manifest filter and no entitlement is enabled and no https
/// link reaches the app. This is the app-side half, ready for the day they are:
/// which links the app takes, how they are told apart, and what is kept while
/// the account is still being restored.
///
/// The switch is compile-time (`--dart-define=RAFT_APP_LINKS=true`), so a
/// release cannot turn it on by configuration alone: the filters in
/// AndroidManifest.xml and the entitlements go in with it.
abstract final class RaftAppLinks {
  static const enabled = bool.fromEnvironment('RAFT_APP_LINKS');

  /// The hosts the association files are served from: the production web app
  /// and the legacy production host the same Web build served (staging never
  /// claims links).
  static const hostnames = {'app.raft.build', 'app.slock.ai'};

  /// Whether [uri] is a Raft https link this build takes: a message link
  /// (`/s/<slug>/channel|dm/<id>`, optionally `?msg=` and `?thread=`) or an
  /// invite (`/join/<token>`) on a Raft host. Nothing when the switch is off
  /// ([on] overrides it for tests); never another scheme, host, port or login
  /// in the URL. What a link may open is still decided by the account that
  /// receives it (`ContentTarget`, `InviteLink`).
  static bool accepts(Uri uri, {bool? on}) {
    if (!(on ?? enabled)) return false;
    if (uri.scheme != 'https' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        !hostnames.contains(uri.host)) {
      return false;
    }
    final p = uri.pathSegments;
    final message =
        p.length == 4 &&
        p[0] == 's' &&
        p[1].isNotEmpty &&
        (p[2] == 'channel' || p[2] == 'dm') &&
        p[3].isNotEmpty;
    final invite = p.length == 2 && p[0] == 'join' && p[1].isNotEmpty;
    return message || invite;
  }
}
