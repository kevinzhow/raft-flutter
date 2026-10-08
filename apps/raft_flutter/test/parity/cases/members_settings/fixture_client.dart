// In-memory RaftClient for the members/settings parity builders. Same shape
// as integration_test/native_primary_routes_test.dart `_PublicClient`: the
// product widgets talk to a real WorkspaceController whose HTTP transport is
// replaced by the official visual fixture (shared/fixtureData.json) plus the
// endpoint mocks packages/visual-testing/tests/react-provider.spec.ts serves.
import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

import '../../parity_harness.dart';

/// `'METHOD /path'` → JSON value, or a function of the request data.
typedef MsRoutes = Map<String, Object? Function(dynamic data)>;

class MsFixtureClient extends RaftClient {
  MsFixtureClient(this.routes, Map<String, dynamic> user)
    : super(
        origin: 'https://visual-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    this.user = RaftRecord(user);
    selectServer('visual-server');
  }

  final MsRoutes routes;
  final requests = <String>[];

  @override
  void connect() {}
  @override
  void joinChannel(String id) {}

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    final key = '$method $path';
    requests.add(key);
    final route = routes[key];
    if (route != null) {
      final value = route(data);
      if (value is RaftApiException) throw value;
      return value;
    }
    if (method == 'GET') {
      if (path.endsWith('/setup-projection')) {
        return {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
      }
      if (path.endsWith('/sidebar-order')) {
        return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
      }
      if (path.endsWith('/saved/count')) return {'count': 0};
      if (path.endsWith('/message-display-settings')) {
        return {'collapseLongMessages': false, 'prefsVersion': 0};
      }
      if (path.endsWith('/notification-settings')) {
        return {'activityMuted': false, 'muteFromSeq': null, 'prefsVersion': 0};
      }
      if (path == '/channels/threads/followers' ||
          path == '/channels/threads/followed') {
        return {'threads': []};
      }
    }
    // No backend behind the React render host either: unmocked endpoints
    // fail rather than inventing data.
    throw RaftApiException('Not found: $key', status: 404);
  }
}

/// Fixture → wire DTOs (same field mapping react-provider.spec.ts uses).
class MsFixture {
  MsFixture(this.ctx);
  final ParityContext ctx;
  Map<String, dynamic> get fx => ctx.fixtureData;
  Map<String, dynamic> get owner =>
      Map<String, dynamic>.from(fx['humans']['owner'] as Map);
  Map<String, dynamic> get times => Map<String, dynamic>.from(fx['times']);

  Map<String, dynamic> get user => {
    'id': owner['id'],
    'email': owner['email'],
    'gravatarHash': '',
    'name': owner['name'],
    'displayName': owner['displayName'],
    'description': null,
    'avatarUrl': null,
    'emailVerified': owner['emailVerified'] == true,
    'preferredTimezone': owner['timezone'],
    'preferredTimeFormat': owner['timeFormat'],
  };

  Map<String, dynamic> get server {
    final s = Map<String, dynamic>.from(fx['server'] as Map);
    return {
      'id': s['id'],
      'name': s['name'],
      'avatarUrl': null,
      'slug': s['slug'],
      'ownerId': owner['id'],
      'onboardingAgentId': null,
      'hideHumansFromMembers': false,
      'plan': s['plan'],
      'planDowngradedAt': null,
      'role': owner['role'],
      'createdAt': times['entityCreatedAtIso'],
    };
  }

  Map<String, dynamic> machine(String key) {
    final m = Map<String, dynamic>.from(fx['machines'][key] as Map);
    return {
      'id': m['id'],
      'name': m['name'],
      'status': m['status'],
      'statusVersion': m['statusVersion'],
      'apiKeyPrefix': m['apiKeyPrefix'],
      'runtimes': m['runtimes'],
      'hostname': m['hostname'],
      'os': m['os'],
      'daemonVersion': m['daemonVersion'],
      'isComputer': m['isComputer'],
      'computerVersion': m['computerVersion'],
      'lastHeartbeat': m['lastHeartbeatIso'],
      'createdAt': m['createdAtIso'],
    };
  }

  /// react-provider.spec.ts serves these machines in this order.
  List<Map<String, dynamic>> get machines => [
    machine('primary'),
    machine('studio'),
    machine('daemonOnly'),
    machine('longName'),
  ];

  String? machineIdFor(Map agent) {
    final key = agent['machineKey'];
    if (key == null) return null;
    if (key == 'missing') return 'computer-missing';
    return fx['machines'][key]['id'] as String;
  }

  /// `fxAgentDetailAgents` of react-provider.spec.ts, as `/api/agents` rows.
  static const agentDetailKeys = [
    'productUx',
    'computerOffline',
    'computerMissing',
    'noComputer',
    'longMachine',
    'daemonOnly',
    'noMembership',
  ];

  Map<String, dynamic> agent(String key) {
    final a = Map<String, dynamic>.from(fx['agents'][key] as Map);
    return {
      'id': a['id'],
      'serverId': fx['server']['id'],
      'name': a['name'],
      'displayName': a['displayName'],
      'avatarUrl': a['avatar'],
      'description': a['description'],
      'status': a['status'],
      'serverRole': a['serverRole'],
      'model': a['model'],
      'runtime': a['runtime'],
      'reasoningEffort': a['reasoningEffort'],
      'executionMode': a['executionMode'],
      'envVars': {'RAFT_PROFILE': 'product-ux', 'SLOCK_VISUAL_PROVIDER': 'react'},
      'machineId': machineIdFor(a),
      'sessionId': a['sessionId'],
      'runtimeProfile': null,
      'creatorType': 'user',
      'creatorId': owner['id'],
      'creator': {
        'type': 'human',
        'id': owner['id'],
        'name': owner['name'],
        'displayName': owner['displayName'],
        'avatarUrl': null,
        'gravatarHash': '',
      },
      'createdAgents': [
        for (final c in (a['createdAgents'] as List? ?? []))
          {
            'id': c['id'],
            'name': c['name'],
            'displayName': c['displayName'],
            'avatarUrl': null,
            'runtime': c['runtime'],
            'status': c['status'],
          },
      ],
      'deletedAt': null,
      'createdAt': times['entityCreatedAtIso'],
      'activity': a['activity'],
      'activityDetail': a['activityDetail'],
    };
  }

  List<Map<String, dynamic>> get agents => [
    for (final key in agentDetailKeys) agent(key),
  ];

  Map<String, dynamic> member(String key) {
    final h = Map<String, dynamic>.from(fx['humans'][key] as Map);
    return {
      'userId': h['memberId'] ?? h['id'],
      'serverId': fx['server']['id'],
      'email': h['email'],
      'gravatarHash': '',
      'name': h['name'],
      'displayName': h['displayName'],
      'description': h['description'],
      'avatarUrl': null,
      'role': h['role'],
      'joinedAt': times['memberJoinedAtIso'],
      'membershipStatus': 'active',
    };
  }

  List<Map<String, dynamic>> get members => [
    member('owner'),
    member('designer'),
    member('jiacheng'),
  ];

  Map<String, dynamic> channel(String key) {
    final c = Map<String, dynamic>.from(fx['channels'][key] as Map);
    return {
      'id': c['id'],
      'serverId': fx['server']['id'],
      'name': c['name'],
      'description': c['description'],
      'type': c['type'],
      'memberCount': c['memberCount'],
      'joined': true,
      'archived': false,
      'createdAt': c['createdAtIso'],
    };
  }

  /// A WorkspaceController bound to the fixture owner and server.
  (WorkspaceController, MsFixtureClient) workspace(
    MsRoutes routes, {
    List<String> channels = const ['design'],
  }) {
    final client = MsFixtureClient(routes, user);
    final w = WorkspaceController(client)
      ..server = RaftRecord(server)
      ..servers = [RaftRecord(server)]
      ..channels = [for (final c in channels) RaftChannel(channel(c))];
    w.ledger.switchServer('visual-server');
    return (w, client);
  }
}
