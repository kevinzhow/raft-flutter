import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// High-frequency presence events (agent heartbeats, last-seen, machine status
/// repeats) must not rebuild the workspace, the sidebar or chat rows that do
/// not display the affected agent.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  String bobName = 'BOB';
  final channelRows = [
    RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
  ];
  final dmRows = [
    RaftChannel({
      'id': 'd-bob',
      'type': 'dm',
      'name': 'bob',
      'peerType': 'agent',
      'peerId': 'bob',
      'peerName': 'bob',
      'joined': true,
    }),
  ];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? dmRows : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {'messages': messages, 'threadSummariesByParentMessageId': {}};

  static Map<String, dynamic> agent(String id, [String? displayName]) => {
    'id': id,
    'name': id,
    'displayName': displayName ?? id.toUpperCase(),
    'status': 'active',
    'runtime': 'codex',
    'model': 'gpt-5-codex',
    'machineId': 'm1',
    'lastSeenAt': '2026-10-08T00:00:00Z',
  };

  static final messages = [
    for (var i = 1; i <= 6; i++)
      {
        'id': 'm$i',
        'channelId': 'c',
        'serverId': 's',
        'seq': '$i',
        'content': 'Message $i',
        'senderId': i == 6 ? 'cindy' : 'other',
        'senderType': i == 6 ? 'agent' : 'user',
        'senderName': i == 6 ? 'cindy' : 'other',
        'createdAt': '2026-10-08T00:0$i:00Z',
      },
  ];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/agents') return [agent('cindy'), agent('bob', bobName)];
    if (path == '/servers/s/members') {
      return [
        {'userId': 'alice', 'name': 'alice', 'role': 'owner'},
        {'userId': 'other', 'name': 'other', 'role': 'member'},
      ];
    }
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {'id': 'm1', 'name': 'box', 'status': 'online', 'statusVersion': 1},
        ],
      };
    }
    if (path == '/channels/unread') return {'channels': <String, int>{}};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '6', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

/// Element rebuilds observed through the framework's rebuild hook.
class _Rebuilds {
  /// [workspace] counts shell rebuilds (the sidebar list under the shell's
  /// builder); [sidebar] counts sidebar rows.
  int total = 0, workspace = 0, chat = 0, sidebar = 0;
  final rows = <String, int>{}, avatars = <String, int>{};
  void start() {
    widgets.debugOnRebuildDirtyWidget = (element, builtOnce) {
      total++;
      final widget = element.widget;
      final key = widget.key;
      if (key == const Key('workspace-sidebar')) workspace++;
      if (widget is RaftChatView) chat++;
      if (widget is RaftMessageTile && key is ValueKey<String>) {
        rows[key.value] = (rows[key.value] ?? 0) + 1;
      }
      if (widget is RaftAvatar &&
          key is ValueKey<String> &&
          key.value.startsWith('message-avatar-')) {
        final id = key.value.split('-')[2];
        avatars[id] = (avatars[id] ?? 0) + 1;
      }
      if (widget is RaftNavItem &&
          key is ValueKey<String> &&
          key.value.startsWith('sidebar-')) {
        sidebar++;
      }
    };
  }

  void stop() => widgets.debugOnRebuildDirtyWidget = null;
}

void main() {
  testWidgets(
    'agent heartbeats, last-seen and machine status repeats do not rebuild the shell, sidebar or unrelated rows',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final client = _Client()..selectServer('s');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..channels = client.channelRows
        ..dms = client.dmRows
        ..channel = client.channelRows.single
        ..section = 'chat'
        ..channelLoading = false
        ..loading = false;
      w.ledger.switchServer('s');
      w.ledger.ingest(
        _Client.messages,
        expectedGeneration: w.ledger.generation,
      );
      w.visibleIds['c'] = {for (final m in _Client.messages) '${m['id']}'};
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      unawaited(w.entityDirectory.preload());
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('message-m1')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-m6')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sidebar-channel-d-bob')),
        findsOneWidget,
      );
      expect(w.entityDirectory.agent('cindy'), isNotNull);

      // The first working signal shows the live activity bar (a real layout
      // change); the burst below only refreshes it.
      for (final id in ['cindy', 'bob']) {
        client.stream.add(
          RaftEvent('agent:activity', {
            'agentId': id,
            'serverId': 's',
            'activity': 'working',
            'detail': 'start',
          }),
        );
      }
      await t.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const Key('live-agent-activity-bar')), findsOneWidget);

      final counts = _Rebuilds()..start();
      addTearDown(counts.stop);
      var seen = DateTime.utc(2026, 10, 8, 1);
      for (var i = 0; i < 20; i++) {
        seen = seen.add(const Duration(seconds: 5));
        for (final id in ['cindy', 'bob']) {
          client.stream.add(
            RaftEvent('agent:activity', {
              'agentId': id,
              'serverId': 's',
              'activity': i.isEven ? 'working' : 'thinking',
              'detail': 'step $i',
              'isHeartbeat': i > 0,
            }),
          );
          client.stream.add(
            RaftEvent('agent:seen', {
              'agentId': id,
              'lastSeenAt': seen.toIso8601String(),
            }),
          );
        }
        // A repeated machine status (same status and version) is a no-op.
        client.stream.add(
          const RaftEvent('machine:status', {
            'machineId': 'm1',
            'status': 'online',
            'statusVersion': 1,
          }),
        );
        await t.pump(const Duration(milliseconds: 16));
      }
      counts.stop();
      // ignore: avoid_print
      print(
        'presence burst rebuilds: total=${counts.total} '
        'workspace=${counts.workspace} chat=${counts.chat} '
        'sidebar=${counts.sidebar} rows=${counts.rows} '
        'avatars=${counts.avatars}',
      );
      expect(counts.workspace, 0);
      expect(counts.chat, 0);
      expect(counts.sidebar, 0);
      for (final id in ['m1', 'm2', 'm3', 'm4', 'm5', 'm6']) {
        expect(counts.rows['message-$id'] ?? 0, 0, reason: id);
      }
      // Only the avatar showing cindy follows her presence.
      for (final id in ['m1', 'm2', 'm3', 'm4', 'm5']) {
        expect(counts.avatars[id] ?? 0, 0, reason: id);
      }
      expect(counts.avatars['m6'], greaterThan(0));

      // A real identity change still reaches the sidebar in place.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-channel-d-bob')),
          matching: find.text('BOB'),
        ),
        findsOneWidget,
      );
      client.bobName = 'Robert';
      client.stream.add(const RaftEvent('agent:updated', {'agentId': 'bob'}));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-channel-d-bob')),
          matching: find.text('Robert'),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
