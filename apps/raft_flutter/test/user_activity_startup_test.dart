import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/user_activity.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart';

/// Session restore stays pending so the first frame is only startup.
class _PendingSessionStore extends MemorySessionStore {
  final pending = Completer<Session?>();
  @override
  Future<Session?> read(String origin) => pending.future;
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }

  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];

  static Map<String, dynamic> message(String id, int seq) => {
    'id': id,
    'channelId': 'c',
    'serverId': 's',
    'seq': '$seq',
    'content': 'Public fixture $id',
    'senderId': 'other',
    'senderType': 'user',
    'createdAt': '2026-10-17T00:00:00Z',
  };

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
  Future<List<RaftChannel>> channels({bool dm = false}) async => dm
      ? []
      : [
          RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
        ];
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {
    'messages': [message('m', 1)],
    'threadSummariesByParentMessageId': {},
  };
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/unread') {
      return {
        'channels': {'c': 0},
      };
    }
    if (path == '/messages/sync') return <Map<String, dynamic>>[];
    if (path == '/channels/c') {
      return {'id': 'c', 'serverId': 's', 'name': 'design', 'joined': true};
    }
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
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      return {'maxReadSeq': int.parse('${data['seq']}'), 'readStateVersion': 1};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }

  int get reads => calls.where((c) => c == 'POST:/channels/c/read').length;
}

void main() {
  testWidgets(
    'a click or key before the first activity query reads a bottom arrival',
    (tester) async {
      final now = DateTime.utc(2026, 10, 17, 1);
      RaftUserActivity.clock = () => now;
      addTearDown(() {
        RaftUserActivity.clock = DateTime.now;
        RaftUserActivity.forget();
      });
      SharedPreferences.setMockInitialValues({});
      final sessions = _PendingSessionStore();
      final f = RootFixture(sessionStore: sessions);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        if (!sessions.pending.isCompleted) sessions.pending.complete(null);
      });
      await tester.pumpWidget(
        RaftApp(
          services: const AppServices.updatesDisabledForTestOrPreview(),
          sessionStore: sessions,
          nativeContent: f.content,
          nativeSharing: NativeSharing(supported: false),
          openWorkspaceCache: () async => f.cache,
          createClient: (origin, store, kind) =>
              f.client = RootClient(origin, store, kind, f.adapter),
        ),
      );

      tester.binding.handlePointerEvent(
        const PointerDownEvent(pointer: 1, position: Offset(20, 20)),
      );
      expect(
        RaftUserActivity.recent,
        isTrue,
        reason: 'a click before the first query counts as active',
      );
      RaftUserActivity.forget();
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        ),
      );
      expect(
        RaftUserActivity.recent,
        isTrue,
        reason: 'a key before the next query counts as active',
      );

      final c = _Client();
      final w = WorkspaceController(c);
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      // Widget tests freeze time. The workspace cache uses real I/O.
      await tester.runAsync(() async {
        await w.bootstrap();
        w.setForeground(true);
        await w.selectChannel(w.channels.single);
        final before = c.reads;
        c.stream.add(RaftEvent('message:new', _Client.message('live', 2)));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(c.reads, before + 1);
        expect(w.conversationReads.unread['c'] ?? 0, 0);
      });
    },
  );
}
