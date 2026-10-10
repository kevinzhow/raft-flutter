// Fixture transport + wire payloads for the `screens.*` real-screen parity
// cases. The fake client answers the same API routes the React provider
// mocks in packages/visual-testing/tests/react-provider.spec.ts (quietApi),
// built from the shared fixtureData.json, so the real Flutter screens load
// the same data the React route renders. Pattern copied from
// integration_test/native_primary_routes_test.dart (`_PublicClient`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

/// Answers one request. Return [ScreenFixtureClient.pending] to keep the
/// request in flight forever (React's delayed `route.fulfill`).
typedef ScreenRoute = Object? Function(
  String method,
  String path,
  Map<String, dynamic>? query,
);

class ScreenFixtureClient extends RaftClient {
  /// [origin] matters to code that inspects the client origin before a
  /// request (AuthView's Android local-network check resolves non-loopback
  /// hosts with real DNS, which never completes under the test clock).
  ScreenFixtureClient(
    this.route, {
    Map<String, dynamic>? user,
    String? server,
    super.origin = 'https://parity-fixture.invalid',
  }) : super(sessionStore: MemorySessionStore()) {
    if (user != null) this.user = RaftRecord(user);
    if (server != null) selectServer(server);
  }

  /// Sentinel: the request never completes (no timer, so no pending-timer
  /// failure when the test ends).
  static const Object pending = _Pending();

  final ScreenRoute route;
  final requests = <String>[];
  final _stream = StreamController<RaftEvent>.broadcast(sync: true);

  /// Pushes a socket event, like the realtime server would.
  void emit(RaftEvent event) => _stream.add(event);
  @override
  Stream<RaftEvent> get events => _stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String channelId) {}
  @override
  Future<void> dispose() async {
    await _stream.close();
  }

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
  }) {
    requests.add('$method $path');
    final answer = route(method, path, query);
    if (identical(answer, pending)) return Completer<dynamic>().future;
    return Future<dynamic>.value(answer);
  }
}

class _Pending {
  const _Pending();
}

/// Wire payloads mirroring react-provider.spec.ts quietApi.
class ScreenWire {
  ScreenWire(this.fx);
  final Map<String, dynamic> fx;

  Map<String, dynamic> get _owner => fx['humans']['owner'];
  Map<String, dynamic> get _server => fx['server'];
  Map<String, dynamic> get _times => fx['times'];

  /// GET /auth/me
  Map<String, dynamic> me() => {
    'id': _owner['id'],
    'email': _owner['email'],
    'gravatarHash': '',
    'name': _owner['name'],
    'displayName': _owner['displayName'],
    'description': null,
    'avatarUrl': null,
    'emailVerified': _owner['emailVerified'],
    'preferredLanguage': null,
    'preferredTimezone': _owner['timezone'],
    'autoTranslationEnabled': false,
    'preferredTranslationDisplay': 'translated',
    'preferredTimeFormat': _owner['timeFormat'],
    'preferredMessageBodyFontSize': null,
  };

  /// One row of GET /servers.
  Map<String, dynamic> server() => {
    'id': _server['id'],
    'name': _server['name'],
    'slug': _server['slug'],
    'ownerId': _owner['id'],
    'onboardingAgentId': null,
    'hideHumansFromMembers': false,
    'plan': _server['plan'],
    'planDowngradedAt': null,
    'role': 'owner',
    'createdAt': _times['entityCreatedAtIso'],
  };

  String? machineIdFor(Map<String, dynamic> agent) {
    final key = agent['machineKey'];
    if (key == null) return null;
    if (key == 'missing') return 'computer-missing';
    return fx['machines'][key]['id'] as String;
  }

  /// One agent row exactly as the React /api/agents mock serialises it.
  Map<String, dynamic> agent(String key) {
    final a = Map<String, dynamic>.from(fx['agents'][key] as Map);
    return {
      'id': a['id'],
      'serverId': _server['id'],
      'name': a['name'],
      'displayName': a['displayName'],
      'avatarUrl': a['avatar'],
      'description': a['description'],
      'status': a['status'],
      // noMembership omits serverRole on the wire.
      if (a['serverRole'] != null) 'serverRole': a['serverRole'],
      'model': a['model'],
      'runtime': a['runtime'],
      'reasoningEffort': a['reasoningEffort'],
      'executionMode': a['executionMode'],
      'envVars': {
        'RAFT_PROFILE': 'product-ux',
        'SLOCK_VISUAL_PROVIDER': 'react',
      },
      'machineId': machineIdFor(a),
      'sessionId': a['sessionId'],
      'runtimeProfile': null,
      'creatorType': 'user',
      'creatorId': _owner['id'],
      'creator': {
        'type': 'human',
        'id': _owner['id'],
        'name': _owner['name'],
        'displayName': _owner['displayName'],
        'avatarUrl': null,
        'gravatarHash': '',
      },
      'createdAgents': [
        for (final c in (a['createdAgents'] as List? ?? const []))
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
      'createdAt': _times['entityCreatedAtIso'],
      'activity': a['activity'],
      'activityDetail': a['activityDetail'],
    };
  }

  static const agentDetailKeys = [
    'productUx',
    'computerOffline',
    'computerMissing',
    'noComputer',
    'longMachine',
    'daemonOnly',
    'noMembership',
  ];

  /// GET /servers/visual-server/machines
  List<Map<String, dynamic>> machines() => [
    for (final key in ['primary', 'studio', 'daemonOnly', 'longName'])
      {
        for (final field in [
          'id',
          'name',
          'status',
          'statusVersion',
          'apiKeyPrefix',
          'runtimes',
          'hostname',
          'os',
          'daemonVersion',
          'isComputer',
          'computerVersion',
        ])
          field: fx['machines'][key][field],
        'lastHeartbeat': fx['machines'][key]['lastHeartbeatIso'],
        'createdAt': fx['machines'][key]['createdAtIso'],
      },
  ];

  /// GET /servers/visual-server/members/visual-human-1/profile
  Map<String, dynamic> ownerProfile() => {
    'userId': _owner['memberId'],
    'serverId': _server['id'],
    'email': _owner['email'],
    'gravatarHash': '',
    'name': _owner['name'],
    'displayName': _owner['displayName'],
    'description': _owner['description'],
    'avatarUrl': null,
    'role': _owner['role'],
    'joinedAt': _times['memberJoinedAtIso'],
    'membershipStatus': 'active',
    'createdAgents': [],
  };

  /// GET `/agents/<id>/activity-log`
  static const activityLog = [
    {
      'timestamp': 1781872080000,
      'entry': {
        'kind': 'status',
        'activity': 'working',
        'detail': 'Capturing deterministic Activity tab state',
      },
    },
    {
      'timestamp': 1781872140000,
      'entry': {
        'kind': 'thinking',
        'text': 'Comparing React and Android Members Activity screenshots before publishing.',
      },
    },
    {
      'timestamp': 1781872200000,
      'entry': {
        'kind': 'tool_start',
        'toolName': 'shell',
        'toolInput': 'pnpm --filter @botiverse/raft-visual-testing exec slock-visual diff --case screens.members.agent-detail.activity',
      },
    },
    {
      'timestamp': 1781872260000,
      'entry': {
        'kind': 'slock_action',
        'title': 'Posted status update',
        'text': 'Reported capture progress in #product:d4870bc3 and kept #225 in review.',
      },
    },
  ];

  /// GET `/agents/<id>/workspace-files` (root listing)
  static const workspaceRoot = {
    'files': [
      {
        'name': 'MEMORY.md',
        'path': 'MEMORY.md',
        'isDirectory': false,
        'size': 86,
        'modifiedAt': '2026-06-19T12:28:00.000Z',
      },
      {
        'name': 'notes',
        'path': 'notes',
        'isDirectory': true,
        'modifiedAt': '2026-06-19T12:28:00.000Z',
      },
    ],
  };

  /// Shared answers for the mounted workspace shell (sidebar, settings).
  Object? common(String method, String path, Map<String, dynamic>? query) {
    final sid = _server['id'];
    if (path == '/auth/me') return me();
    if (path == '/servers') return [server()];
    if (path == '/servers/$sid') return server();
    if (path == '/servers/$sid/machines') return machines();
    if (path == '/agents') {
      return [for (final k in agentDetailKeys) agent(k)];
    }
    for (final k in agentDetailKeys) {
      final a = agent(k);
      if (path == '/agents/${a['id']}') return a;
      if (path == '/agents/${a['id']}/activity-log') return activityLog;
      if (path == '/agents/${a['id']}/workspace-files') {
        final dir = query?['dirPath'];
        return dir is String && dir.isNotEmpty
            ? {
                'files': [
                  {
                    'name': 'visual-parity.md',
                    'path': 'notes/visual-parity.md',
                    'isDirectory': false,
                    'size': 1240,
                    'modifiedAt': '2026-06-19T12:28:00.000Z',
                  },
                ],
              }
            : workspaceRoot;
      }
    }
    // react-provider.spec.ts `/api/reminders`.
    if (path == '/reminders') {
      return {
        'reminders': [
          {
            'reminderId': 'reminder-product-ux-memory',
            'ownerAgentId': 'agent-product-ux',
            'title': 'Roll 1-6; if 3, tidy Product-UX memory/files',
            'fireAt': '2026-06-19T18:30:00.000Z',
            'status': 'scheduled',
            'recurrenceDescription': 'daily',
          },
        ],
      };
    }
    if (path == '/servers/$sid/members/${_owner['memberId']}/profile') {
      return ownerProfile();
    }
    if (path == '/servers/$sid/sidebar-order') {
      return {
        'channelOrder': [],
        'agentOrder': ['agent-product-ux'],
        'dmOrder': [],
        'channelSortMode': 'manual',
        'jointChannelSortMode': 'manual',
        'dmSortMode': 'recent',
        'pinnedSortMode': 'manual',
        'pinnedChannelIds': [],
        'pinnedAgentIds': ['agent-product-ux'],
        'pinnedOrder': ['agent-product-ux'],
        'hiddenDmIds': [],
        'channelPanelTabOrder': [],
        'agentPanelTabOrder': [
          'profile',
          'permissions',
          'dms',
          'reminders',
          'workspace',
          'integrations',
          'activity',
        ],
      };
    }
    if (path == '/servers/$sid/notification-settings') {
      return {'serverPushMuted': false};
    }
    if (path == '/servers/$sid/invites') {
      return [
        {
          'id': 'invite-visual-designer',
          'invitedEmail': fx['humans']['designer']['email'],
          'invitedByUserId': _owner['id'],
          'status': 'pending',
          'expiresAt': '2026-07-18T00:00:00.000Z',
          'createdAt': _times['entityCreatedAtIso'],
        },
        {
          'id': 'invite-visual-qa',
          'invitedEmail': 'qa@slock.ai',
          'invitedByUserId': fx['agents']['cindy']['id'],
          'status': 'pending',
          'expiresAt': '2026-07-19T12:24:00.000Z',
          'createdAt': _times['recentActivityAtIso'],
        },
      ];
    }
    if (path == '/servers/$sid/join-links') {
      return [
        {
          'id': 'join-link-visual',
          'token': 'design',
          'createdAt': _times['entityCreatedAtIso'],
          'expiresAt': _times['recentActivityAtIso'],
          'maxUses': 25,
          'useCount': 8,
          'revokedAt': null,
        },
      ];
    }
    if (path == '/channels' || path == '/channels/dm') return [];
    if (path == '/channels/unread') return {};
    if (path == '/channels/saved/count') return {'count': 0};
    if (path == '/channels/threads/followers' ||
        path == '/channels/threads/followed') {
      return {'threads': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/message-display-settings')) {
      return {'collapseLongMessages': false, 'prefsVersion': 0};
    }
    if (RegExp(r'^/integrations/agents/[^/]+/events$').hasMatch(path)) {
      return {'events': [], 'nextCursor': null};
    }
    if (path.startsWith('/integrations/agents/')) return [];
    if (path == '/announcements/active') return {'announcements': []};
    // React's catch-all fulfill.
    return {'agents': [], 'humans': [], 'results': []};
  }
}

/// Owns a fixture client + WorkspaceController for one capture and disposes
/// both with the widget tree.
class ScreenWorkspaceHost extends StatefulWidget {
  const ScreenWorkspaceHost({
    super.key,
    required this.create,
    required this.builder,
  });
  final WorkspaceController Function() create;
  final Widget Function(BuildContext context, WorkspaceController w) builder;
  @override
  State<ScreenWorkspaceHost> createState() => _ScreenWorkspaceHostState();
}

class _ScreenWorkspaceHostState extends State<ScreenWorkspaceHost> {
  late final WorkspaceController w = widget.create();
  @override
  void dispose() {
    w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, w);
}

/// A nested navigator holding the real `MaterialPageRoute` stack the app
/// builds by `Navigator.push` (e.g. agents → FleetDetail → pushed page).
/// Initial routes are added without a transition, i.e. a settled push.
class ScreenRouteStack extends StatelessWidget {
  const ScreenRouteStack({super.key, required this.pages});
  final List<WidgetBuilder> pages;
  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateInitialRoutes: (navigator, _) => [
      for (final page in pages) MaterialPageRoute<void>(builder: page),
    ],
  );
}

/// Owns a bare fixture client (signed-in account gates before a workspace
/// exists) and disposes it with the widget tree.
class ScreenClientHost extends StatefulWidget {
  const ScreenClientHost({
    super.key,
    required this.create,
    required this.builder,
  });
  final ScreenFixtureClient Function() create;
  final Widget Function(BuildContext context, ScreenFixtureClient client)
  builder;
  @override
  State<ScreenClientHost> createState() => _ScreenClientHostState();
}

class _ScreenClientHostState extends State<ScreenClientHost> {
  late final ScreenFixtureClient client = widget.create();
  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, client);
}
