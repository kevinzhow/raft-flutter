import 'dart:async';

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
    this.installError,
    this.installGate,
    this.lookupGate,
  }) : webOrigin = webOrigin ?? Uri.parse('https://app.example.com'),
       clients = clients ?? {for (final s in servers) s.id: client ?? app()};

  @override
  final List<HumanLoginServer> servers;
  @override
  final Uri webOrigin;
  @override
  List<Uri> get loginWebOrigins => [webOrigin];
  @override
  final String? signedInAs;

  /// Lookup answer per server id; a missing server answers 404.
  final Map<String, Map<String, Object?>> clients;
  Map<String, Object?>? authorizeResult;
  Object? authorizeError;

  /// What the install throws, if it fails.
  Object? installError;

  /// When set, the install and the authorization wait for it (to look at the
  /// sheet while they are under way).
  Completer<void>? installGate;

  /// When set, lookups wait for it (to look at the sheet while it loads).
  Completer<void>? lookupGate;

  final lookups = <({String serverId, Map<String, String> query})>[];
  final authorizations = <Map<String, Object?>>[];
  final installs = <({String serverId, String appId})>[];

  /// Every call in the order it was made: `lookup:<server>`,
  /// `install:<server>` and `authorize:<server>`.
  final calls = <String>[];

  static Map<String, Object?> app({
    String name = 'Artifact Share',
    List<String>? disallowed,
    String? reason,
    bool installRequired = false,
    bool canInstall = false,
    bool marketplace = false,
    String? setupUrl,
    String? setupDescription,
  }) => {
    'clientId': 'artifact-share',
    'appType': 'third_party_global',
    'name': name,
    'description': 'Shares private artifacts',
    'homepageUrl': 'https://example.com',
    'returnUrl': 'https://artifacts.example.com/auth/callback',
    if (installRequired || marketplace) 'id': 'app-record-1',
    if (installRequired || marketplace) 'marketplace': true,
    'setupUrl': ?setupUrl,
    'setupDescription': ?setupDescription,
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
    calls.add('lookup:$serverId');
    await lookupGate?.future;
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
    calls.add('authorize:${body['serverId']}');
    final error = authorizeError;
    if (error != null) throw error;
    return authorizeResult ??
        {
          'code': 'issued-code-1',
          'returnUrl': body['returnUrl'],
          'scopes': body['scopes'],
        };
  }

  @override
  Future<dynamic> installMarketplaceApp(String serverId, String appId) async {
    installs.add((serverId: serverId, appId: appId));
    calls.add('install:$serverId');
    await installGate?.future;
    final error = installError;
    if (error != null) throw error;
    return {'id': 'install-1'};
  }
}
