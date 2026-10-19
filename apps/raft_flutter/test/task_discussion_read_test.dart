import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/user_activity.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/task_surface_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task discussion is a borrowed workspace. Web marks that thread read while
/// the task modal is on screen, and the main channel stays where it was.
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

  static Map<String, dynamic> message(
    String id,
    int seq, {
    String channelId = 'c1',
  }) => {
    'id': id,
    'channelId': channelId,
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
          RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
        ];
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('messages:$id');
    final rows = id == 'task-thread'
        ? [message('reply-1', 1, channelId: 'task-thread')]
        : [message('m', 1)];
    return {'messages': rows, 'threadSummariesByParentMessageId': {}};
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/channels/unread') return {'channels': <String, dynamic>{}};
    if (path == '/messages/sync') return <dynamic>[];
    if (path == '/messages/context/task-parent') {
      return {
        'messages': [message('task-parent', 1)],
      };
    }
    if (path == '/channels/c1') {
      return {'id': 'c1', 'serverId': 's', 'name': 'test', 'joined': true};
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/providers') return {'providers': []};
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
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

  int reads(String id) =>
      calls.where((call) => call == 'POST:/channels/$id/read').length;
}

final _task = <String, dynamic>{
  'id': 'task-1',
  'taskNumber': 8,
  'title': 'Scoped actual task',
  'channelId': 'c1',
  'messageId': 'task-parent',
  'threadChannelId': 'task-thread',
  'status': 'todo',
  'createdByType': 'user',
  'createdById': 'alice',
};

Future<
  ({_Client client, WorkspaceController parent, TaskSurfaceController surface})
>
openTaskDiscussion() async {
  final client = _Client();
  final parent = WorkspaceController(client);
  await parent.bootstrap();
  parent.setForeground(true);
  await parent.selectChannel(parent.channels.single);
  final surface = TaskSurfaceController(
    parent: parent,
    row: _task,
    valid: () => true,
  );
  surface.openDiscussion();
  final discussion = surface.discussion;
  expect(discussion, isNotNull, reason: 'the task discussion opened');
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (discussion!.threadChannelId == 'task-thread' &&
        !discussion.messageDomain.state.threadLoading) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(discussion!.threadChannelId, 'task-thread');
  expect(discussion.messageDomain.state.threadLoading, isFalse);
  expect(
    parent.location.thread,
    isNull,
    reason: 'discussion does not navigate',
  );
  return (client: client, parent: parent, surface: surface);
}

void showDiscussion(TaskSurfaceController surface) {
  final discussion = surface.discussion!;
  discussion.setConversationPresentation(
    surface.presentationOwner,
    main: false,
    thread: true,
  );
  discussion.setForeground(surface.parent.foreground);
}

Future<void> turn() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RaftUserActivity.clock = () => DateTime.utc(2026, 10, 17);
    RaftUserActivity.forget();
  });

  tearDown(() {
    RaftUserActivity.clock = DateTime.now;
    RaftUserActivity.forget();
  });

  test('a visible task discussion at the bottom reads a live reply and does not read the main channel', () async {
    final opened = await openTaskDiscussion();
    addTearDown(() async {
      opened.surface.dispose();
      opened.parent.dispose();
      await opened.client.stream.close();
    });
    showDiscussion(opened.surface);
    await turn();
    final discussion = opened.surface.discussion!;
    final threadReads = opened.client.reads('task-thread');
    final mainReads = opened.client.reads('c1');
    RaftUserActivity.mark();
    discussion.setTimelineAtBottom('task-thread', true);
    opened.client.stream.add(
      RaftEvent(
        'message:new',
        _Client.message('live', 2, channelId: 'task-thread'),
      ),
    );
    await turn();
    expect(
      opened.client.reads('task-thread'),
      threadReads + 1,
      reason: 'the visible discussion sends a thread read',
    );
    expect(
      opened.client.reads('c1'),
      mainReads,
      reason: 'the main channel is not marked read',
    );
    expect(opened.parent.location.thread, isNull);
  });

  test('an opened task discussion that is not on screen does not read a live reply', () async {
    final opened = await openTaskDiscussion();
    addTearDown(() async {
      opened.surface.dispose();
      opened.parent.dispose();
      await opened.client.stream.close();
    });
    final discussion = opened.surface.discussion!;
    await turn();
    final threadReads = opened.client.reads('task-thread');
    final mainReads = opened.client.reads('c1');
    RaftUserActivity.mark();
    discussion.setTimelineAtBottom('task-thread', true);
    opened.client.stream.add(
      RaftEvent(
        'message:new',
        _Client.message('hidden', 2, channelId: 'task-thread'),
      ),
    );
    await turn();
    expect(opened.client.reads('task-thread'), threadReads);
    expect(opened.client.reads('c1'), mainReads);
  });

  test('a visible task discussion scrolled above the bottom does not read a live reply', () async {
    final opened = await openTaskDiscussion();
    addTearDown(() async {
      opened.surface.dispose();
      opened.parent.dispose();
      await opened.client.stream.close();
    });
    showDiscussion(opened.surface);
    await turn();
    final discussion = opened.surface.discussion!;
    final threadReads = opened.client.reads('task-thread');
    final mainReads = opened.client.reads('c1');
    RaftUserActivity.mark();
    discussion.setTimelineAtBottom('task-thread', false);
    opened.client.stream.add(
      RaftEvent(
        'message:new',
        _Client.message('above', 2, channelId: 'task-thread'),
      ),
    );
    await turn();
    expect(opened.client.reads('task-thread'), threadReads);
    expect(opened.client.reads('c1'), mainReads);
  });
}
