/// This deployment's client config (`GET /api/public/client-config`, server
/// v1.24): deploy facts every client needs, the same answer for everyone (no
/// credentials read, nothing per person or per server).
///
/// Source: packages/web/src/store/{clientConfig,raftAppHosts,
/// artifactsEmbedOrigin,privacyMode}.ts and
/// packages/server/src/routes/publicClientConfig.ts at v1.24.0-source.1.
/// Each field is checked the way Web's store for it checks it; a failed read
/// or an older server (404) is [RaftClientConfig.fallback]: no hosts, no
/// embed origin, privacy mode off.
class RaftClientConfig {
  const RaftClientConfig({
    this.appHosts,
    this.privacyMode = false,
    this.artifactsEmbedOrigin,
  });

  static const fallback = RaftClientConfig();

  /// Web `CLIENT_CONFIG_TIMEOUT_MS`: past it the read counts as failed.
  static const timeout = Duration(seconds: 10);

  /// Raft's own app hosts (hostnames only, deduped, in the server's order);
  /// null when the server sent none, so readers keep what they knew.
  final List<String>? appHosts;

  /// RAFT_PRIVACY_MODE: the deployment wants no telemetry. Missing is off.
  final bool privacyMode;

  /// Where a public Artifact's embed page is served (`<origin>/pt_<uuid>`);
  /// null: embeds are off on this deployment.
  final String? artifactsEmbedOrigin;

  factory RaftClientConfig.fromJson(Object? body) {
    if (body is! Map) return fallback;
    final hosts = <String>[];
    if (body['appHosts'] case final List values) {
      for (final value in values) {
        final host = raftHostnameOf(value);
        if (host != null && !hosts.contains(host)) hosts.add(host);
      }
    }
    return RaftClientConfig(
      appHosts: hosts.isEmpty ? null : List.unmodifiable(hosts),
      privacyMode: body['privacyMode'] == true,
      artifactsEmbedOrigin: raftEmbedOriginOf(body['artifactsEmbedOrigin']),
    );
  }
}

/// A hostname exactly as a URL's host spells it (lowercase, no port, path or
/// scheme), else null. Web raftAppHosts.ts `hostnameOf`.
String? raftHostnameOf(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final uri = Uri.tryParse('https://$value/');
  return uri != null && uri.host == value && !uri.hasPort ? value : null;
}

/// An embed origin as `URL.origin` spells it, else null: https, or http on
/// `localhost` / `*.localhost`, with no credentials, path, query or fragment.
/// Web artifactsEmbedOrigin.ts `embedOriginOf`.
String? raftEmbedOriginOf(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;
  final local = uri.host == 'localhost' || uri.host.endsWith('.localhost');
  if (!(uri.scheme == 'https' || uri.scheme == 'http' && local)) return null;
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) return null;
  final origin = uri.origin;
  return value == origin || value == '$origin/' ? origin : null;
}
