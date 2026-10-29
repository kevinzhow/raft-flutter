// A newly joined agent must show an avatar (never an empty frame) in the
// channel member view and the thread follower view, and both must follow the
// workspace directory and the realtime member events without a restart.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/thread_agent_followers_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'thread_agent_followers_test.dart' show follower, settle;

class _EventClient extends RaftClient {
  _EventClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }

  final incoming = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => incoming.stream;
}

Map<String, dynamic> _agent(String id, String name, String? avatarUrl) => {
  'id': id,
  'name': name,
  'displayName': name,
  'status': 'active',
  'runtime': 'claude',
  'model': 'm',
  'avatarUrl': avatarUrl,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late MessageAdapter api;
  late _EventClient client;
  late WorkspaceController w;
  late List<Map<String, dynamic>> roster;
  late List<Map<String, dynamic>> directory;

  Future<void> setup(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    api = MessageAdapter();
    client = _EventClient(api);
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
    w.channels = [w.channel!];
    roster = [];
    directory = [];
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': <dynamic>[],
      'agents': roster,
    };
    api.routes['GET /agents'] = (_) => directory;
    api.routes['GET /servers/s1/members'] = (_) => <dynamic>[];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
      await client.incoming.close();
    });
    await t.runAsync(
      () => w.services.entityDirectory.refresh(WorkspaceEntityKind.agents),
    );
  }

  Future<void> mountMembers(WidgetTester t, {required bool page}) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ChannelMembers(controller: w, channel: w.channel!, page: page),
        ),
      ),
    );
    await settle(t);
  }

  // The only agent avatar mounted by the view under test.
  Finder agentAvatar([String? pixelKey]) => find.byWidgetPredicate(
    (widget) =>
        widget is RaftAvatarContent &&
        widget.kind == RaftAvatarContentKind.agent &&
        (pixelKey == null || widget.pixelKey == pixelKey),
  );

  // Phone page (Android) and the modal both mount the same member rows.
  for (final page in [true, false]) {
    group(page ? 'members page' : 'members modal', () {
      testWidgets('an agent with no avatar shows the default avatar, not an '
          'empty frame', (t) async {
        await setup(t);
        roster = [_agent('a-new', 'Deep', null)];
        directory = [_agent('a-new', 'Deep', null)];
        await mountMembers(t, page: page);
        expect(find.text('Deep'), findsOneWidget);
        expect(agentAvatar(), findsOneWidget);
      });

      testWidgets('a roster snapshot older than the directory takes the '
          'directory avatar, and follows agent:updated', (t) async {
        await setup(t);
        roster = [_agent('a-new', 'Deep', null)];
        directory = [_agent('a-new', 'Deep', 'pixel:cat')];
        await t.runAsync(
          () => w.services.entityDirectory.refresh(
            WorkspaceEntityKind.agents,
            force: true,
          ),
        );
        await mountMembers(t, page: page);
        expect(agentAvatar('cat'), findsOneWidget);

        directory = [_agent('a-new', 'Deep', 'pixel:ghost')];
        client.incoming.add(RaftEvent('agent:updated', {'agentId': 'a-new'}));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)),
        );
        await settle(t);
        expect(agentAvatar('ghost'), findsOneWidget);
      });

      testWidgets('an agent that joins while the view is open appears with '
          'its avatar on channel:members-updated', (t) async {
        await setup(t);
        roster = [];
        await mountMembers(t, page: page);
        expect(find.text('Deep'), findsNothing);

        roster = [_agent('a-new', 'Deep', 'pixel:cat')];
        client.incoming.add(
          RaftEvent('channel:members-updated', {'channelId': 'c1'}),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)),
        );
        await settle(t);
        expect(find.text('Deep'), findsOneWidget);
        expect(agentAvatar('cat'), findsOneWidget);
      });
    });
  }

  group('thread followers', () {
    Future<void> mountFollowers(WidgetTester t) async {
      api.routes['GET /channels/threads/followers'] = (_) => {
        'threads': [
          {
            'threadChannelId': 't1',
            'canManage': true,
            'agents': [
              {...follower('a-new', 'Deep'), 'avatarUrl': null},
            ],
          },
        ],
      };
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: ThreadAgentFollowersView(
                controller: w,
                threadChannelId: 't1',
              ),
            ),
          ),
        ),
      );
      await settle(t);
      await t.tap(find.byKey(const Key('thread-followers-header-trigger')));
      await t.pumpAndSettle();
    }

    testWidgets('a follower with no avatar shows the default avatar and then '
        'the directory avatar once the directory has the agent', (t) async {
      await setup(t);
      await mountFollowers(t);
      expect(find.text('Deep'), findsWidgets);
      expect(agentAvatar(), findsWidgets);

      directory = [_agent('a-new', 'Deep', 'pixel:cat')];
      client.incoming.add(
        RaftEvent('agent:created', {'agent': directory.first}),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await settle(t);
      expect(agentAvatar('cat'), findsWidgets);
    });
  });
}
