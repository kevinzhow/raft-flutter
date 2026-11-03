import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services_fixture.dart';

enum FooterState { join, guest, archived, jointLocked }

class FooterInsetClient extends RaftClient {
  FooterInsetClient(this.state)
    : super(
        origin: 'https://footer-inset.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }

  final FooterState state;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  var joined = false;
  var joinRequests = 0;

  RaftChannel get row => RaftChannel({
    'id': 'c',
    'serverId': 's',
    'name': 'design',
    'type': state == FooterState.jointLocked ? 'joint' : 'channel',
    'joined': state != FooterState.join || joined,
    if (state == FooterState.archived) 'archivedAt': '2026-10-01T00:00:00Z',
    if (state == FooterState.jointLocked) 'jointBillingLocked': true,
  });

  Map<String, dynamic> message(String id, String channel) => {
    'id': id,
    'serverId': 's',
    'channelId': channel,
    'seq': '1',
    'senderId': 'alice',
    'senderName': 'Alice',
    'senderType': 'user',
    'content': 'Public footer fixture',
    'createdAt': '2026-10-01T00:00:00Z',
  };

  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? [] : [row];
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {
    'messages': [message(id == 'c' ? 'parent' : 'reply', id)],
    'hasMore': false,
    'hasNewer': false,
  };

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/c') return row.json;
    if (path == '/channels/threads/followed') return {'threads': []};
    if (path == '/channels/inbox') return {'items': []};
    if (path == '/channels/unread') return {'channels': {}};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/machines')) return {'machines': []};
    if (path.startsWith('/messages/context/')) {
      return {
        'messages': [message('parent', 'c')],
      };
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path == '/channels/c/join') {
      ++joinRequests;
      joined = true;
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '1', 'readStateVersion': '1'};
    }
    return {};
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
  }) => method == 'POST' ? post(path, data: data) : get(path, query: query);
}

class FooterInsetFixture {
  FooterInsetFixture(this.client, this.workspace);
  final FooterInsetClient client;
  final WorkspaceController workspace;

  static Future<FooterInsetFixture> mount(
    WidgetTester t, {
    required Size size,
    required TargetPlatform platform,
    required double inset,
    required String pack,
    required bool dark,
    FooterState state = FooterState.join,
    bool thread = false,
    bool workspace = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.reset();
    t.view
      ..devicePixelRatio = 1
      ..physicalSize = size
      ..padding = FakeViewPadding(bottom: inset)
      ..viewPadding = FakeViewPadding(bottom: inset);
    addTearDown(t.view.reset);
    addTearDown(DevicePreferences.reset);
    final client = FooterInsetClient(state);
    final w = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 's',
        'name': 'Fixture',
        'role': state == FooterState.guest ? 'guest' : 'member',
      })
      ..channels = [client.row]
      ..channel = client.row
      ..loading = false
      ..section = 'chat';
    w.messageDomain.ledger.switchServer('s');
    final rows = [client.message('parent', 'c')];
    w.messageDomain.ledger.ingest(
      rows,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c'] = {'parent'};
    if (thread) {
      w.messageDomain.state.threadParent = RaftMessage(rows.single);
      w.threadChannelId = 'thread-c';
      w.messageDomain.ledger.ingest([
        client.message('reply', 'thread-c'),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['thread-c'] = {'reply'};
    }
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(Duration.zero);
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(
          pack: packForThemeId(pack),
          dark: dark,
        ).copyWith(platform: platform),
        home: thread || !workspace
            ? Scaffold(
                body: thread
                    ? RaftConversationSurface(
                        role: RaftConversationSurfaceRole.threadTimeline,
                        child: RaftChatView(controller: w, thread: true),
                      )
                    : RaftChatView(controller: w),
              )
            : withAppServices(
                WorkspaceView(
                  controller: w,
                  appearance: RaftAppearance(
                    mode: dark ? ThemeMode.dark : ThemeMode.light,
                  ),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                ),
              ),
      ),
    );
    await t.pumpAndSettle();
    return FooterInsetFixture(client, w);
  }
}
