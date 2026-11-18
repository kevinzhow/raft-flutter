import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/workspace_task_host.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show MessageAdapter;
import 'support/app_services_fixture.dart';
import 'task_content_slot_test.dart' show v2Task;
import 'task_surface_test.dart' show flush, taskRoutes;
import 'workspace_source_location_contract_test.dart' show pageFixture;

Map<String, dynamic> attachment(
  String id,
  String kind,
  String channel,
  String message, {
  String? parent,
  bool withTaskIdentity = true,
}) => {
  'id': id,
  'messageId': message,
  'channelId': channel,
  'filename': '$id.pdf',
  'mimeType': 'application/pdf',
  'sizeBytes': 42,
  'width': null,
  'height': null,
  'thumbnailUrl': null,
  'createdAt': '2026-05-11T10:06:00.000000Z',
  'uploader': {
    'type': 'user',
    'id': 'alice',
    'name': 'Alice',
    'displayName': 'Alice',
  },
  'source': {
    'type': kind,
    'channelId': channel,
    'parentMessageId': parent,
    'parentMessageShortId': parent,
    if (kind == 'task' && withTaskIdentity) ...{
      'taskId': 'task-1',
      'taskNumber': 8,
    },
  },
};

Future<(WorkspaceController, MessageAdapter)> mountFiles(WidgetTester t) async {
  t.view.physicalSize = const Size(1280, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final (w, api) = await pageFixture(t, section: 'chat');
  taskRoutes(api, v2Task);
  api.routes['GET /tasks/channel/c1'] = (_) => {
    'tasks': [v2Task],
    'nextCursor': null,
  };
  api.routes['GET /messages/context/attached-reply'] = (_) => {
    'messages': [row('attached-reply', 'task-conv', 2)],
    'hasMore': false,
    'hasNewer': false,
  };
  api.routes['GET /channels/c1/files'] = (_) => {
    'files': [
      attachment('direct-file', 'channel', 'c1', 'channel-message'),
      attachment('task-file', 'task', 'task-conv', 'attached-reply'),
      attachment(
        'thread-file',
        'thread',
        'thread-conv',
        'thread-reply',
        parent: 'msg-root',
      ),
    ],
    'nextCursor': null,
  };
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: withAppServices(
        Scaffold(
          body: ListenableBuilder(
            listenable: w,
            builder: (context, _) => WorkspaceTaskHost(
              controller: w,
              onTask: null,
              onViewBilling: null,
              childBuilder: (_, _) => ConversationPanel(controller: w),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(
    find.descendant(
      of: find.byKey(const Key('conversation-tabs')),
      matching: find.text('Files'),
    ),
  );
  await flush(t);
  await t.pumpAndSettle();
  return (w, api);
}

final taskFileJump = find.byKey(const ValueKey('channel-file-jump-task-file'));

void main() {
  leakDebt(const ['SourceChannelFilesStore']);

  testWidgets('Files shows all served sources and opens the exact task reply', (
    t,
  ) async {
    try {
      final (w, api) = await mountFiles(t);
      expect(find.text('direct-file.pdf'), findsOneWidget);
      expect(find.text('task-file.pdf'), findsOneWidget);
      expect(find.text('thread-file.pdf'), findsOneWidget);
      final windowRevision = w.navigation.revision;
      await t.tap(taskFileJump);
      await flush(t);
      await t.pumpAndSettle();

      expect(w.location.query('task'), 'c1:task:task-1');
      expect(w.location.chatTab, 'files');
      expect(w.navigation.revision, windowRevision);
      final context = api.calls
          .where((call) => call.path == '/messages/context/attached-reply')
          .single;
      expect(context.queryParameters['channelId'], 'task-conv');
      expect(find.text('Message attached-reply'), findsOneWidget);
      expect(
        api.calls.map((call) => call.path),
        isNot(contains('/channels/task-conv')),
      );
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  });

  test(
    'task attachment keeps its accepted identity across paging and refresh',
    () async {
      final task = attachment('task-file', 'task', 'task-conv', 'task-reply');
      final page = [
        task,
        attachment('direct-file', 'channel', 'c1', 'channel-message'),
      ];
      final queries = <Object?>[];
      final store = SourceChannelFilesStore(
        channelId: 'c1',
        authority: () => 'owner',
        get: (path, {query}) async {
          expect(path, '/channels/c1/files');
          final cursor = query?['cursor'];
          queries.add(cursor);
          return {
            'files': cursor == 'cursor+/='
                ? [
                    attachment(
                      'thread-file',
                      'thread',
                      'thread-conv',
                      'reply',
                      parent: 'msg-root',
                    ),
                  ]
                : page,
            'nextCursor': cursor == null ? 'cursor+/=' : null,
          };
        },
      );
      addTearDown(store.dispose);
      await store.load();
      expect(store.files.map((file) => file.id), ['task-file', 'direct-file']);
      final selected = store.files.first;
      await store.load(more: true);
      await store.load();
      expect(queries, [null, 'cursor+/=', null]);
      expect(store.files.map((file) => file.id), [
        'task-file',
        'direct-file',
        'thread-file',
      ]);
      expect(store.contains(selected), isTrue);
      expect(store.nextCursor, isNull);
    },
  );

  test(
    'unknown and malformed task sources fail the whole first page',
    () async {
      Map<String, dynamic>? invalid;
      final store = SourceChannelFilesStore(
        channelId: 'c1',
        authority: () => 'owner',
        get: (_, {query}) async => {
          'files': [
            attachment('direct-file', 'channel', 'c1', 'channel-message'),
            invalid,
          ],
          'nextCursor': null,
        },
      );
      addTearDown(store.dispose);
      for (final row in [
        attachment('unknown-file', 'unknown', 'another', 'reply'),
        attachment('aliased-task', 'task', 'c1', 'reply'),
        attachment(
          'task-without-id',
          'task',
          'task-conv',
          'reply',
          withTaskIdentity: false,
        ),
        attachment(
          'task-with-parent',
          'task',
          'task-conv',
          'reply',
          parent: 'msg-root',
        ),
      ]) {
        invalid = row;
        await store.load();
        expect(store.error, ChannelFilesFailure.malformed);
        expect(store.files, isEmpty);
      }
    },
  );
}
