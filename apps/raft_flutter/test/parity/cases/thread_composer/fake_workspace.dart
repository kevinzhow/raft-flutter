// Test-only data seam for the thread_composer parity group: a RaftClient that
// answers the same API routes the official React provider mocks
// (raft-source packages/visual-testing/tests/react-provider.spec.ts) from the
// shared fixtureData.json, so the real WorkspaceController / ComposerDirectory /
// SourceChannelFilesStore data paths run unchanged. Pattern copied from
// apps/raft_flutter/integration_test/native_primary_routes_test.dart.
import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class ParityFakeClient extends RaftClient {
  ParityFakeClient({required Map<String, dynamic> user, required this.routes})
    : super(
        origin: 'https://parity-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    this.user = RaftRecord(user);
    selectServer('visual-server');
  }

  /// `'<METHOD> <path>'` → JSON answer.
  final Map<String, dynamic> routes;
  final requests = <String>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);

  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void joinChannel(String id) {}
  @override
  void connect() {}

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    requests.add('PAGE /messages/channel/$id');
    final answer = routes['GET /messages/channel/$id'];
    return answer is Map
        ? Map<String, dynamic>.from(answer)
        : {'messages': <dynamic>[], 'hasMore': false};
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
  }) async {
    requests.add('$method $path');
    final answer = routes['$method $path'];
    if (answer != null) return answer;
    if (method != 'GET') return <String, dynamic>{};
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
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
    return <dynamic>[];
  }
}

/// Fixture projections of the React provider's API mocks.
class ParityThreadFixture {
  ParityThreadFixture(this.fx);
  final Map<String, dynamic> fx;

  Map<String, dynamic> get _humans => Map<String, dynamic>.from(fx['humans']);
  Map<String, dynamic> get _agents => Map<String, dynamic>.from(fx['agents']);
  Map<String, dynamic> human(String key) =>
      Map<String, dynamic>.from(_humans[key]);
  Map<String, dynamic> agent(String key) =>
      Map<String, dynamic>.from(_agents[key]);
  Map<String, dynamic> get channels =>
      Map<String, dynamic>.from(fx['channels']);
  Map<String, dynamic> get server => Map<String, dynamic>.from(fx['server']);
  Map<String, dynamic> get times => Map<String, dynamic>.from(fx['times']);
  Map<String, dynamic> get files => Map<String, dynamic>.from(fx['files']);
  Map<String, dynamic> get messages =>
      Map<String, dynamic>.from(fx['messages']);
  String get composerChannelId =>
      (channels['composerHost'] as Map)['id'] as String;

  /// useAuthStore user seeded by primeVisualStores (fxOwner).
  Map<String, dynamic> get authUser {
    final o = human('owner');
    return {
      'id': o['id'],
      'email': o['email'],
      'name': o['name'],
      'displayName': o['displayName'],
      'timezone': o['timezone'],
      'preferredTimeFormat': o['timeFormat'],
      'emailVerified': true,
    };
  }

  /// useServerStore.current (role owner).
  Map<String, dynamic> get serverRecord => {
    'id': server['id'],
    'name': server['name'],
    'slug': server['slug'],
    'plan': server['plan'],
    'role': 'owner',
  };

  Map<String, dynamic> _agentWire(Map<String, dynamic> a) => {
    'id': a['id'],
    'serverId': server['id'],
    'name': a['name'],
    'displayName': a['displayName'],
    'avatarUrl': a['avatar'],
    'description': a['description'],
    'status': a['status'],
    'activity': a['activity'],
    'activityDetail': a['activityDetail'],
    'deletedAt': null,
  };

  Map<String, dynamic> _ownerMember() {
    final o = human('owner');
    return {
      'id': o['memberId'],
      'userId': o['memberId'],
      'serverId': server['id'],
      'name': o['name'],
      'displayName': o['displayName'],
      'description': o['description'],
      'avatarUrl': null,
      'email': o['email'],
      'role': o['role'],
    };
  }

  /// `/channels/<composerHost>/members` mock: Cindy + owner member.
  Map<String, dynamic> get channelMembers => {
    'agents': [_agentWire(agent('cindy'))],
    'humans': [_ownerMember()],
  };

  /// MessageInput consumes primeVisualStores' owner-only member catalog,
  /// not the unrelated agent-detail HTTP stub's owner + designer list.
  List<dynamic> get serverMembers => [_ownerMember()];

  /// primeVisualStores' exact composer catalog. The general /agents stub is
  /// for agent-detail cases and supplies a different set of test agents.
  List<dynamic> get serverAgents => [
    for (final key in const ['cindy', 'productUx', 'androidDev4'])
      if (_agents[key] is Map)
        {
          ..._agentWire(agent(key)),
          if (key == 'androidDev4') 'avatarUrl': agent('cindy')['avatar'],
        },
  ];

  /// useChannelStore.channels seeded by primeVisualStores.
  List<Map<String, dynamic>> get composerChannels => [
    {
      'id': composerChannelId,
      'serverId': server['id'],
      'name': (channels['design'] as Map)['name'],
      'description': (channels['design'] as Map)['description'],
      'type': 'channel',
      'joined': true,
    },
    {
      'id': 'channel-product',
      'serverId': server['id'],
      'name': 'product',
      'description': 'Release tracking and acceptance',
      'type': 'channel',
      'joined': true,
    },
    {
      'id': 'channel-android-artifacts',
      'serverId': server['id'],
      'name': (channels['androidArtifacts'] as Map)['name'],
      'description': (channels['androidArtifacts'] as Map)['description'],
      'type': 'channel',
      'joined': true,
    },
  ];

  static const _thumbnailSvg =
      'data:image/svg+xml;utf8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%20128%20128%22%3E%3Crect%20width%3D%22128%22%20height%3D%22128%22%20fill%3D%22%23FDE047%22%2F%3E%3Ccircle%20cx%3D%2288%22%20cy%3D%2240%22%20r%3D%2220%22%20fill%3D%22%23F472B6%22%2F%3E%3Cpath%20d%3D%22M16%20104L48%2068l22%2024%2018-16%2024%2028H16z%22%20fill%3D%22%23000000%22%2F%3E%3C%2Fsvg%3E';

  /// `/channels/visual-thread-composer/files` mock.
  Map<String, dynamic> get channelFiles {
    final o = human('owner'),
        cindy = agent('cindy'),
        dev = agent('androidDev4');
    final image = Map<String, dynamic>.from(files['image']),
        pdf = Map<String, dynamic>.from(files['pdf']),
        zip = Map<String, dynamic>.from(files['zip']);
    Map<String, dynamic> source(String type, [String? parent, String? short]) =>
        {
          'type': type,
          'channelId': composerChannelId,
          'parentMessageId': parent,
          'parentMessageShortId': short,
        };
    return {
      'files': [
        {
          'id': 'visual-file-image',
          'messageId': 'msg-files-image',
          'channelId': composerChannelId,
          'filename': image['filename'],
          'mimeType': image['mimeType'],
          'sizeBytes': image['sizeBytes'],
          'width': 128,
          'height': 128,
          'thumbnailUrl': _thumbnailSvg,
          'createdAt': times['fileImageAtIso'],
          'uploader': {
            'type': 'user',
            'id': o['id'],
            'name': o['name'],
            'displayName': o['displayName'],
          },
          'source': source('channel'),
        },
        {
          'id': 'visual-file-pdf',
          'messageId': 'msg-files-pdf',
          'channelId': composerChannelId,
          'filename': pdf['filename'],
          'mimeType': pdf['mimeType'],
          'sizeBytes': pdf['sizeBytes'],
          'createdAt': times['filePdfAtIso'],
          'uploader': {
            'type': 'agent',
            'id': cindy['id'],
            'name': cindy['name'],
            'displayName': cindy['displayName'],
          },
          'source': source('thread', 'parent-files', 'f8e569cb'),
        },
        {
          'id': 'visual-file-zip',
          'messageId': 'msg-files-zip',
          'channelId': composerChannelId,
          'filename': zip['filename'],
          'mimeType': zip['mimeType'],
          'sizeBytes': zip['sizeBytes'],
          'createdAt': times['fileZipAtIso'],
          'uploader': {
            'type': 'agent',
            'id': dev['id'],
            'name': dev['name'],
            'displayName': dev['displayName'],
          },
          'source': source('channel'),
        },
      ],
      'nextCursor': 'next-files-page',
    };
  }

  /// VisualTestingCases.tsx primeComposerStores `sendMessage` mock for
  /// pendingMentionActionsAfterSend, as a /v2/messages receipt.
  Map<String, dynamic> get pendingMentionSendReceipt => {
    'message': {
      'id': 'visual-pending-mention-message',
      'channelId': composerChannelId,
      'seq': '1',
      'messageType': 'chat',
      'senderType': 'user',
      'senderId': authUser['id'],
      'content': '@Android-Developer-4 please review the visual diff',
      'createdAt': fx['times']['entityCreatedAtIso'],
    },
    'unresolvedMentionHandles': [],
    'pendingMentionActions': [
      {
        'resolutionId': 'visual-pending-mention-resolution',
        'messageId': 'visual-pending-mention-message',
        'targetType': 'agent',
        'targetHandle': fx['agents']['androidDev4']['name'],
        'targetAvatarUrl': fx['agents']['cindy']['avatar'],
        'reason': 'target_not_in_channel',
        'availableActions': ['add', 'notify'],
        'expiresAt': null,
      },
    ],
  };

  /// Controller scoped to the composer host channel (#design), like the React
  /// render host's useMessageStore.currentChannelId.
  WorkspaceController composerWorkspace({
    Map<String, dynamic> extraRoutes = const {},
  }) {
    final client = ParityFakeClient(
      user: authUser,
      routes: {
        ...extraRoutes,
        'GET /channels/$composerChannelId/members': channelMembers,
        'GET /servers/${server['id']}/members': serverMembers,
        'GET /agents': serverAgents,
        'GET /channels/$composerChannelId/files': channelFiles,
      },
    );
    final channels = composerChannels.map(RaftChannel.new).toList();
    return WorkspaceController(client)
      ..server = RaftRecord(serverRecord)
      ..channels = channels
      ..channel = channels.first;
  }

  /// primeNavigationVisualStores: channel-home (首页专修) + channel-product,
  /// current channel channel-home, no messages.
  WorkspaceController navigationWorkspace() {
    final client = ParityFakeClient(user: authUser, routes: const {});
    final channels = [
      {
        'id': 'channel-home',
        'serverId': server['id'],
        'name': '首页专修',
        'description': 'Home shell, server badge, and bottom dock polish',
        'type': 'channel',
        'joined': true,
      },
      {
        'id': 'channel-product',
        'serverId': server['id'],
        'name': 'product',
        'description': 'Visual testing release gates',
        'type': 'channel',
        'joined': true,
      },
    ].map(RaftChannel.new).toList();
    return WorkspaceController(client)
      ..server = RaftRecord(serverRecord)
      ..channels = channels;
  }
}
