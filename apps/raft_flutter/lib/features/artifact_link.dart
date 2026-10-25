/// Links to Raft artifacts (`https://raft-artifacts.com/p/<server>/<name>`).
///
/// A private artifact answers "Sign in required" and offers "Login with Raft".
/// That sign-in needs a Raft session, which the system browser of a phone does
/// not have and the app does. These links therefore open inside the app (see
/// `artifact_viewer.dart`) instead of in the browser.
class ArtifactLinks {
  const ArtifactLinks._();

  /// The artifact host Raft serves shared artifacts from.
  static const defaultOrigin = 'https://raft-artifacts.com';

  /// Extra origins, comma separated, that open like artifact links. Empty in
  /// release builds; a local test stack adds the fake artifact page it serves.
  static const extraOriginsDefine = String.fromEnvironment(
    'RAFT_ARTIFACT_ORIGINS',
  );

  /// The origins whose links open in the app.
  static List<Uri> origins([String extra = extraOriginsDefine]) => [
    Uri.parse(defaultOrigin),
    for (final value in extra.split(','))
      if (Uri.tryParse(value.trim()) case final Uri origin?
          when origin.hasScheme && origin.host.isNotEmpty)
        origin,
  ];

  /// True for an http(s) link to one of [origins] (any path, query or hash).
  static bool matches(Uri uri, {List<Uri>? origins}) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return false;
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
    for (final origin in origins ?? ArtifactLinks.origins()) {
      if (origin.scheme.toLowerCase() == scheme &&
          origin.host.toLowerCase() == uri.host.toLowerCase() &&
          _port(origin) == _port(uri)) {
        return true;
      }
    }
    return false;
  }

  static int _port(Uri uri) => uri.hasPort
      ? uri.port
      : uri.scheme.toLowerCase() == 'https'
      ? 443
      : 80;
}
