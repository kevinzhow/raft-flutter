import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/human_login.dart';

/// The app's side of Login with Raft with the HTTP layer faked: records every
/// call, answers lookups per server and the authorization with [code].
class FakeHumanLoginApi implements HumanLoginApi {
  FakeHumanLoginApi({
    this.servers = const [
      HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme'),
    ],
    Uri? webOrigin,
    this.signedInAs = 'person@example.com',
    Map<String, Object?>? client,
    Map<String, Map<String, Object?>>? clients,
    this.authorizeResult,
    this.authorizeError,
  }) : webOrigin = webOrigin ?? Uri.parse('https://app.example.com'),
       clients = clients ?? {for (final s in servers) s.id: client ?? app()};

  @override
  final List<HumanLoginServer> servers;
  @override
  final Uri webOrigin;
  @override
  final String? signedInAs;

  /// Lookup answer per server id; a missing server answers 404.
  final Map<String, Map<String, Object?>> clients;
  Map<String, Object?>? authorizeResult;
  Object? authorizeError;

  final lookups = <({String serverId, Map<String, String> query})>[];
  final authorizations = <Map<String, Object?>>[];

  static Map<String, Object?> app({
    String name = 'Artifact Share',
    List<String>? disallowed,
    String? reason,
    bool installRequired = false,
    bool canInstall = false,
  }) => {
    'clientId': 'artifact-share',
    'appType': 'third_party_global',
    'name': name,
    'description': 'Shares private artifacts',
    'homepageUrl': 'https://example.com',
    'returnUrl': 'https://artifacts.example.com/auth/callback',
    'availability': installRequired ? 'install_required' : 'ready',
    if (installRequired)
      'installation': {'serverId': 'srv-1', 'canInstall': canInstall},
    if (disallowed != null)
      'scopeValidation': {
        'allowed': disallowed.isEmpty,
        'reason': reason,
        'disallowedScopes': disallowed,
      },
  };

  @override
  Future<dynamic> lookup(String serverId, Map<String, String> query) async {
    lookups.add((serverId: serverId, query: query));
    final client = clients[serverId];
    if (client == null) {
      throw RaftApiException.response(
        'OAuth client not found for server',
        status: 404,
        body: {'error': 'OAuth client not found for server'},
      );
    }
    return client;
  }

  @override
  Future<dynamic> authorize(Map<String, Object?> body) async {
    authorizations.add(body);
    final error = authorizeError;
    if (error != null) throw error;
    return authorizeResult ??
        {
          'code': 'issued-code-1',
          'returnUrl': body['returnUrl'],
          'scopes': body['scopes'],
        };
  }
}
