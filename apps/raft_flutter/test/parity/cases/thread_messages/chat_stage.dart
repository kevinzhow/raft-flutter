// Mounts the real RaftChatView (apps/raft_flutter/lib/features/chat_view.dart)
// over a canned, in-memory RaftClient so message rows go through the exact
// product adapter path (MessagePresentation body, scoped avatar, agent model
// label, MessageTaskProjection chip, reactions, thread summary, selection,
// long-press actions). Pattern copied from
// integration_test/native_primary_routes_test.dart (`_PublicClient`).
//
// For element-crop cases the stage then measures the mounted RaftMessageRow
// and shows only that row's rect through a ClipRect window positioned where
// React's `[data-visual-case]` element sits, so the official diff compares
// MessageItem against RaftMessageRow box-for-box.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../parity_harness.dart';

typedef ParityRoute = dynamic Function(Map<String, dynamic>? query);

/// RaftClient whose HTTP surface is a canned route table (no network, no
/// auth). Unknown GETs answer the same neutral defaults the prior mounted
/// fixture used; unknown POSTs answer `{}`.
class ParityRaftClient extends RaftClient {
  ParityRaftClient(this.routes, {required Map<String, dynamic> user})
    : super(
        origin: 'https://parity-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    this.user = RaftRecord(user);
    selectServer('visual-server');
  }
  final Map<String, ParityRoute> routes;
  final requests = <String>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void joinChannel(String channelId) {}
  @override
  void connect() {}

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
    final route = routes['$method $path'];
    if (route != null) return route(query);
    if (method != 'GET') {
      if (path.endsWith('/read')) {
        return {'maxReadSeq': '3', 'readStateVersion': '1'};
      }
      return <String, dynamic>{};
    }
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
    if (path == '/channels/unread') return {'channels': {}};
    if (path.startsWith('/tasks/channel/')) return {'tasks': []};
    return [];
  }
}

/// Seeded fixture identities, mirroring VisualTestingCases.tsx
/// `visualUser` / `visualAgents` / `visualMembers` / store channels, all read
/// from shared/fixtureData.json.
class ParityIdentities {
  ParityIdentities(ParityContext ctx) : fx = ctx.fixtureData;
  final Map<String, dynamic> fx;
  Map<String, dynamic> get owner => Map.from(fx['humans']['owner']);
  Map<String, dynamic> get designer => Map.from(fx['humans']['designer']);
  Map<String, dynamic> get cindy => Map.from(fx['agents']['cindy']);
  Map<String, dynamic> get productUx => Map.from(fx['agents']['productUx']);
  String get serverId => fx['server']['id'] as String;
  String get createdAt => fx['times']['entityCreatedAtIso'] as String;
  String get memberJoinedAt => fx['times']['memberJoinedAtIso'] as String;

  Map<String, dynamic> get user => {
    'id': owner['id'],
    'email': owner['email'],
    'gravatarHash': '',
    'name': owner['name'],
    'displayName': owner['displayName'],
    'description': null,
    'avatarUrl': null,
    'emailVerified': true,
    'preferredTimezone': owner['timezone'],
    'preferredTimeFormat': owner['timeFormat'],
    'preferredMessageBodyFontSize': null,
  };

  Map<String, dynamic> get server => {
    'id': serverId,
    'name': fx['server']['name'],
    'avatarUrl': null,
    'slug': fx['server']['slug'],
    'ownerId': owner['id'],
    'onboardingAgentId': null,
    'hideHumansFromMembers': false,
    'plan': 'free',
    'planDowngradedAt': null,
    'role': 'owner',
    'createdAt': createdAt,
  };

  Map<String, dynamic> _agent(Map<String, dynamic> a, String session) => {
    'id': a['id'],
    'serverId': serverId,
    'name': a['name'],
    'displayName': a['displayName'],
    'avatarUrl': a['avatar'],
    'description': a['description'],
    'status': 'active',
    'serverRole': 'member',
    // React visualAgents gives both agents fxCindy.model.
    'model': cindy['model'],
    'runtime': 'codex',
    'reasoningEffort': 'medium',
    'executionMode': 'byoc',
    'envVars': {},
    'machineId': fx['machines']['primary']['id'],
    'sessionId': session,
    'runtimeProfile': null,
    'creatorType': 'user',
    'creatorId': owner['id'],
    'createdAgents': [],
    'deletedAt': null,
    'createdAt': createdAt,
    'activity': a['activity'],
    'activityDetail': a['activityDetail'],
    'detailKind': 'other',
  };

  List<Map<String, dynamic>> get agents => [
    _agent(cindy, 'session-cindy'),
    _agent(productUx, 'session-product-ux'),
  ];

  List<Map<String, dynamic>> get members => [
    for (final h in [owner, designer])
      {
        'userId': h['id'],
        'serverId': serverId,
        'email': h['email'],
        'gravatarHash': '',
        'name': h['name'],
        'displayName': h['displayName'],
        'description': h['description'],
        'avatarUrl': null,
        'role': h['role'],
        'joinedAt': memberJoinedAt,
      },
  ];

  Map<String, dynamic> channel(String key) {
    final c = Map<String, dynamic>.from(fx['channels'][key]);
    return {
      'id': c['id'],
      'serverId': serverId,
      'name': c['name'],
      'description': c['description'],
      'type': c['type'],
      'createdAt': createdAt,
      'joined': true,
    };
  }

  Map<String, dynamic> extraChannel(String id, String name, String desc) => {
    'id': id,
    'serverId': serverId,
    'name': name,
    'description': desc,
    'type': 'channel',
    'createdAt': '2026-06-18T00:00:00.000Z',
    'joined': true,
  };
}

/// One case's mounted chat: workspace + canned routes + crop geometry.
class ChatStage {
  ChatStage(
    this.ctx, {
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> extraChannels = const [],
    Map<String, dynamic> threadSummaries = const {},
    List<Map<String, dynamic>> tasks = const [],
    this.channelId = 'channel-design',
    this.rowWidth,
    this.rowOrigin = Offset.zero,
    this.rowIndex = 0,
    this.targetRow = true,
  }) : ids = ParityIdentities(ctx) {
    var seq = 0;
    final rows = [
      for (final m in messages)
        {
          'messageType': 'chat',
          'serverId': ids.serverId,
          'seq': ++seq,
          ...m,
          if (threadSummaries.containsKey(m['id']))
            'threadChannelId': threadSummaries[m['id']]['threadChannelId'],
        },
    ];
    final channels = [
      ids.channel('design'),
      ids.channel('androidArtifacts'),
      ...extraChannels,
    ];
    client = ParityRaftClient({
      'GET /messages/channel/$channelId': (_) => {
        'messages': rows,
        'historyLimited': false,
        'threadSummariesByParentMessageId': threadSummaries,
      },
      'GET /agents': (_) => ids.agents,
      'GET /servers/${ids.serverId}/members': (_) => ids.members,
      'GET /tasks/channel/$channelId': (_) => {'tasks': tasks},
      for (final c in channels) 'GET /channels/${c['id']}': (_) => c,
    }, user: ids.user);
    w = WorkspaceController(client)
      ..server = RaftRecord(ids.server)
      ..channels = channels.map(RaftChannel.new).toList();
    w.ledger.switchServer(ids.serverId);
    unawaited(
      w.selectChannel(
        w.channels.firstWhere((c) => c.id == channelId),
        autoRead: false,
      ),
    );
  }

  final ParityContext ctx;
  final ParityIdentities ids;
  final String channelId;

  /// React element width for element crops (MessageItem box width); null for
  /// `body` viewport captures.
  final double? rowWidth;
  final Offset rowOrigin;
  final int rowIndex;

  /// False for `body` captures that still frame one row like React (menus).
  final bool targetRow;
  late final ParityRaftClient client;
  late final WorkspaceController w;
  final chatKey = GlobalKey(debugLabel: 'parity-chat');

  /// Chat width / translation / visible row window, updated by [alignRow].
  late final geometry = ValueNotifier<(double, Offset, Size?)>(
    (rowWidth ?? 390, Offset.zero, null),
  );

  Widget build() {
    // The app hosts RaftChatView inside a Scaffold (Material ancestor for the
    // composer TextField, ScaffoldMessenger, bottom sheets).
    final chat = RaftChatView(key: chatKey, controller: w);
    if (rowWidth == null) return Scaffold(body: chat);
    return Scaffold(body: ValueListenableBuilder(
      valueListenable: geometry,
      builder: (context, g, _) {
        final (chatWidth, shift, window) = g;
        // Tall enough that the row lays out unconstrained by the composer.
        const chatHeight = 1800.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: rowOrigin.dx,
              top: rowOrigin.dy,
              child: (targetRow ? ctx.target : (Widget w) => w)(
                ClipRect(
                  child: SizedBox(
                    width: window?.width ?? chatWidth,
                    height: window?.height ?? 844,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: chatWidth,
                      maxWidth: chatWidth,
                      minHeight: chatHeight,
                      maxHeight: chatHeight,
                      child: Transform.translate(offset: shift, child: chat),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ));
  }

  /// Pumps until the canned channel window, agent/member directory and task
  /// projection have landed in the mounted rows.
  Future<void> settle(WidgetTester t, {int rows = 1}) async {
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 50));
      if (find.byType(RaftMessageRow).evaluate().length >= rows &&
          !w.channelLoading) {
        break;
      }
    }
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Rect _rowRect(WidgetTester t) {
    final row = find.byType(RaftMessageRow).at(rowIndex);
    final chat = t.getTopLeft(find.byKey(chatKey));
    final rect = t.getRect(row);
    return rect.shift(-chat);
  }

  /// Sizes the chat so the RaftMessageRow is exactly [rowWidth] wide, then
  /// windows the capture target onto that row's rect.
  Future<void> alignRow(WidgetTester t) async {
    await settle(t);
    var (chatWidth, _, _) = geometry.value;
    for (var i = 0; i < 3; i++) {
      final rect = _rowRect(t);
      final delta = rowWidth! - rect.width;
      if (delta.abs() < .01) break;
      chatWidth += delta;
      geometry.value = (chatWidth, Offset.zero, null);
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50));
    }
    // Translation is applied inside the window, so measure untranslated.
    final rect = _rowRect(t);
    geometry.value = (chatWidth, -rect.topLeft, rect.size);
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
  }
}

final _stages = Expando<ChatStage>('parity-chat-stage');

/// One stage per ParityContext even if the harness rebuilds the builder.
ChatStage stageFor(ParityContext ctx, ChatStage Function() create) =>
    _stages[ctx] ??= create();
