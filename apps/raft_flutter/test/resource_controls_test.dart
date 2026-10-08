import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final mutations = <({String path, dynamic data})>[];
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
    mutations.add((path: path, data: data));
    return {};
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final calls = <({String path, Map<String, dynamic>? query})>[];
  Completer<dynamic>? people;
  List<Map<String, dynamic>> activity = [];
  List<Map<String, dynamic>> tasks = [];
  bool missingTaskSurface = false;
  bool denyTaskHistory = false;
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    calls.add((path: path, query: query));
    if (path.endsWith('/members')) {
      return people?.future ??
          [
            {'userId': 'bob', 'displayName': 'Bob'},
          ];
    }
    if (path == '/agents') {
      return [
        {'id': 'agent', 'displayName': 'Writer'},
      ];
    }
    if (path == '/messages/search') {
      return {
        'results': [
          {'id': 'm', 'channelId': 'c', 'content': 'Authorized match'},
        ],
        'hasMore': false,
      };
    }
    if (path == '/channels/saved') return {'saved': [], 'hasMore': false};
    if (path == '/tasks/server') {
      return {
        'tasks': tasks
            .where(
              (row) =>
                  query?['status'] == null || row['status'] == query?['status'],
            )
            .toList(),
        'next_cursor': null,
      };
    }
    if (path.startsWith('/tasks/channel/')) {
      if (missingTaskSurface) {
        throw const RaftApiException('Channel not found', status: 404);
      }
      return {'task': tasks.first};
    }
    if (path.endsWith('/history')) {
      if (denyTaskHistory) {
        throw const RaftApiException('Task not found', status: 404);
      }
      return {'events': []};
    }
    return {'items': activity, 'hasMore': false};
  }
}

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    c.selectServer('s');
    w = _Workspace(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'c', 'name': 'General', 'joined': true}),
      ];
  });
  tearDown(() async {
    w.dispose();
    await c.dispose();
  });
  Future<void> mount(WidgetTester t, String section) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: RaftDensityScope(
          density: RaftDensity.touch,
          child: Scaffold(
            body: ResourceView(
              controller: w,
              section: section,
              onMessage: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    // SavedPanel has no filter controls; Activity keeps its filter toggle.
    if (section == 'activity') {
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
    }
  }

  testWidgets(
    'task assignee picker searches and selects self then unassigned',
    (t) async {
      await mount(t, 'tasks');
      await t.tap(find.byTooltip('Filter tasks by assignee'));
      await t.pumpAndSettle();
      final dialog = find.byType(RaftMenuPanel);
      final search = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      await t.enterText(search, 'Assigned to me');
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(RaftMenuItem, 'Assigned to me'));
      await t.pumpAndSettle();
      await t.enterText(search, 'Unassigned');
      await t.pumpAndSettle();
      expect(find.widgetWithText(RaftMenuItem, 'Unassigned'), findsOneWidget);
      await t.tap(find.widgetWithText(RaftMenuItem, 'Unassigned'));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      final dynamic state = t.state(find.byType(ResourceView));
      expect(state.taskAdvanced.assignees, {'user:alice', 'unassigned'});
    },
  );

  testWidgets('disposing the resource closes its owned task picker', (t) async {
    final view = ValueNotifier(true);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: view,
            builder: (_, mounted, _) => mounted
                ? ResourceView(
                    controller: w,
                    section: 'tasks',
                    onMessage: (_, _) async {},
                  )
                : const Text('Home'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filter tasks by assignee'));
    await t.pumpAndSettle();
    expect(find.byType(RaftMenuPanel), findsOneWidget);
    view.value = false;
    await t.pumpAndSettle();
    expect(find.byType(RaftMenuPanel), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    view.dispose();
  });

  Future<void> menu(WidgetTester t, String title, String value) async {
    await t.tap(find.byTooltip(title));
    await t.pumpAndSettle();
    await t.tap(find.text(value).last);
    await t.pumpAndSettle();
  }

  testWidgets('Search controls send source filters and allow an empty query', (
    t,
  ) async {
    await mount(t, 'search');
    expect(w.calls.where((r) => r.path == '/messages/search'), isEmpty);
    await menu(t, 'Filter by channel', '#General');
    expect(w.calls.last.query!['q'], '');
    expect(w.calls.last.query!['channelId'], 'c');
    expect(find.text('Authorized match'), findsOneWidget);
    await menu(t, 'Filter by sender', 'Bob · Human');
    expect(w.calls.last.query!['senderId'], 'bob');
    expect(w.calls.last.query!.containsKey('senderType'), false);
    await t.tap(find.byTooltip('Search scope'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(RaftMenuItem, 'Mentions me'));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(w.calls.last.query!['mentionTarget'], 'self');
    await menu(t, 'Search date range', 'Today');
    expect(w.calls.last.query!['after'], isA<String>());
    await t.enterText(find.byType(TextField), 'hello');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    await menu(t, 'Sort search results', 'Recent');
    expect(w.calls.last.query!['sort'], 'recent');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'revoked private sender popup closes and retained selection cannot query',
    (t) async {
      await mount(t, 'search');
      final button = t.widget<TaskSelectionFilter>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TaskSelectionFilter &&
              widget.tooltip == 'Filter by sender',
        ),
      );
      await t.tap(find.byTooltip('Filter by sender'));
      await t.pumpAndSettle();
      expect(find.text('Bob · Human'), findsOneWidget);
      w.server = RaftRecord({'id': 's', 'role': 'guest'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.text('Bob · Human'), findsNothing);
      final requests = w.calls.length;
      button.onToggle('user:bob');
      await t.pumpAndSettle();
      expect(w.calls.length, requests);
    },
  );
  testWidgets('invalid storage frontier refreshes without a Done mutation', (
    t,
  ) async {
    w.activity = [
      {
        'kind': 'thread',
        'threadChannelId': 't',
        'parentMessageId': 'p',
        'parentChannelId': 'c',
        'parentChannelName': 'General',
        'doneFrontierSeq': null,
        'latestActivitySeq': '999',
      },
    ];
    await mount(t, 'activity');
    await t.tap(find.byTooltip('Mark conversation done'));
    await t.pumpAndSettle();
    expect(c.mutations, isEmpty);
    expect(
      find.text('Refresh Activity before marking this conversation done.'),
      findsOneWidget,
    );
  });
  testWidgets('narrow Search keeps long identity filters within the viewport', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    w.channels = [
      RaftChannel({
        'id': 'c',
        'name':
            'A very long accessible conversation name for the native filter menu',
        'joined': true,
      }),
    ];
    await mount(t, 'search');
    await menu(
      t,
      'Filter by channel',
      '#A very long accessible conversation name for the native filter menu',
    );
    expect(t.takeException(), isNull);
  });
  for (final special in [
    ('Done conversations', '/channels/inbox/done'),
    ('Unfollowed threads', '/channels/inbox/unfollowed'),
  ]) {
    testWidgets('Activity ${special.$1} returns to All with one click', (
      t,
    ) async {
      await mount(t, 'activity');
      await menu(t, 'Activity actions', special.$1);
      expect(w.calls.last.path, special.$2);
      await t.tap(
        find.descendant(
          of: find.byType(RaftSegmentedControl<String>),
          matching: find.text('All'),
        ),
      );
      await t.pumpAndSettle();
      expect(w.calls.last.path, '/channels/inbox');
      expect(w.calls.last.query!['filter'], 'all');
      final count = w.calls.length;
      // Empty-selection support must not let the current All selection crash.
      await t.tap(
        find.descendant(
          of: find.byType(RaftSegmentedControl<String>),
          matching: find.text('All'),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(w.calls.length, count);
      expect(
        t
            .widget<RaftSegmentedControl<String>>(
              find.byType(RaftSegmentedControl<String>),
            )
            .value,
        'all',
      );
    });
  }

  testWidgets(
    'Activity thread actions use thread-specific storage and parent contracts',
    (t) async {
      w.activity = [
        {
          'kind': 'thread',
          'threadChannelId': 't',
          'parentMessageId': 'p',
          'parentChannelId': 'c',
          'parentChannelName': 'General',
          'latestActivityPreview': 'Thread body',
          'doneFrontierSeq': '12',
          'latestActivitySeq': '999',
          'isFollowing': false,
        },
      ];
      await mount(t, 'activity');
      // Follow lives in the row context menu (ThreadsInbox).
      await t.longPress(find.text('Thread body'));
      await t.pumpAndSettle();
      await t.tap(find.text('Follow'));
      await t.pumpAndSettle();
      expect(c.mutations.last.path, '/channels/threads/follow');
      expect(c.mutations.last.data, {'parentMessageId': 'p'});
      await t.tap(find.byTooltip('Mark conversation done'));
      await t.pumpAndSettle();
      expect(c.mutations.last.path, '/channels/threads/done');
      expect(c.mutations.last.data, {
        'threadChannelId': 't',
        'throughActivitySeq': '12',
        'frontierSpace': 'storage',
      });
    },
  );
  testWidgets('late people lookup cannot repopulate a revoked sender menu', (
    t,
  ) async {
    w.people = Completer<dynamic>();
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'search',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await t.pump();
    w.server = RaftRecord({'id': 's', 'role': 'guest'});
    w.notifyListeners();
    await t.pumpAndSettle();
    w.people!.complete([
      {'userId': 'bob', 'displayName': 'Private old Bob'},
    ]);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filter by sender'));
    await t.pumpAndSettle();
    expect(find.textContaining('Private old Bob'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Activity channel grouping and query filters do not invent API grouping params',
    (t) async {
      w.activity = [
        {
          'kind': 'channel',
          'channelId': 'c',
          'channelName': 'General',
          'lastMessagePreview': 'Activity body',
        },
      ];
      await mount(t, 'activity');
      await t.tap(find.text('Group by channel'));
      await t.pumpAndSettle();
      expect(find.text('General · 1'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'body');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(w.calls.last.query!['q'], 'body');
      expect(w.calls.last.query!.containsKey('groupBy'), false);
    },
  );
  testWidgets(
    'Task filters search names and combine typed multi-selection with Unassigned',
    (t) async {
      w.tasks = [
        {
          'id': 'one',
          'taskNumber': 1,
          'title': 'Human unassigned',
          'channelId': 'c',
          'status': 'todo',
          'createdByType': 'user',
          'createdById': 'bob',
          'createdByName': 'Bob',
        },
        {
          'id': 'two',
          'taskNumber': 2,
          'title': 'Agent same ID',
          'channelId': 'c',
          'status': 'todo',
          'createdByType': 'agent',
          'createdById': 'bob',
          'createdByName': 'Robot Bob',
          'claimedByType': 'agent',
          'claimedById': 'agent',
          'claimedByName': 'Writer',
        },
        {
          'id': 'three',
          'taskNumber': 3,
          'title': 'Human assigned',
          'channelId': 'c',
          'status': 'todo',
          'createdByType': 'user',
          'createdById': 'bob',
          'createdByName': 'Bob',
          'claimedByType': 'user',
          'claimedById': 'alice',
          'claimedByName': 'Alice',
        },
      ];
      await mount(t, 'tasks');
      await t.tap(find.byTooltip('Filter tasks by creator'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'bob');
      await t.pumpAndSettle();
      expect(find.widgetWithText(RaftMenuItem, 'Writer'), findsNothing);
      await t.tap(find.widgetWithText(RaftMenuItem, 'Bob'));
      await t.tap(find.widgetWithText(RaftMenuItem, 'Robot Bob'));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Human unassigned'), findsOneWidget);
      expect(find.text('Agent same ID'), findsOneWidget);
      await t.tap(find.byTooltip('Filter tasks by assignee'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(RaftMenuItem, 'Unassigned'));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Human unassigned'), findsOneWidget);
      expect(find.text('Agent same ID'), findsNothing);
      expect(find.text('Human assigned'), findsNothing);
      final req = w.calls.where((r) => r.path == '/tasks/server').last.query!;
      expect(req.containsKey('assignee'), false);
      expect(req.containsKey('creator'), false);
    },
  );

  testWidgets(
    'Fresh accessible task missing local parent offers only terminal cleanup',
    (t) async {
      w.missingTaskSurface = true;
      w.tasks = [
        {
          'id': 'orphan',
          'taskNumber': 7,
          'title': 'Old work',
          'channelId': 'gone',
          'status': 'todo',
          'createdByType': 'user',
          'createdById': 'alice',
        },
      ];
      await mount(t, 'tasks');
      await t.tap(find.text('Old work'));
      await t.pumpAndSettle();
      expect(find.text('Assign'), findsNothing);
      expect(find.text('Claim'), findsNothing);
      expect(find.text('Mark done'), findsOneWidget);
      expect(find.text('Close task'), findsOneWidget);
      await t.tap(find.text('Mark done'));
      await t.pumpAndSettle();
      expect(
        w.calls.any((r) => r.path == '/tasks/channel/gone/number/7'),
        true,
      );
      expect(w.calls.any((r) => r.path == '/tasks/orphan/history'), true);
      expect(c.mutations.single.path, '/tasks/orphan/status');
      expect(c.mutations.single.data, {'status': 'done'});
    },
  );
  testWidgets(
    'retired anchored task selections cannot affect the current workspace',
    (t) async {
      await mount(t, 'tasks');
      await t.tap(find.byTooltip('Filter tasks by creator'));
      await t.pumpAndSettle();
      final select = t
          .widget<RaftMenuItem>(find.widgetWithText(RaftMenuItem, 'Bob'))
          .onPressed!;
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      select();
      await t.pumpAndSettle();
      final dynamic state = t.state(find.byType(ResourceView));
      expect(state.taskAdvanced.creators, isEmpty);
      expect(find.byType(ResourceView), findsOneWidget);
      expect(find.byType(RaftMenuPanel), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'missing task surface never permits cleanup when fresh history is inaccessible',
    (t) async {
      w.missingTaskSurface = true;
      w.denyTaskHistory = true;
      w.tasks = [
        {
          'id': 'missing',
          'taskNumber': 9,
          'title': 'Previously accepted',
          'channelId': 'gone',
          'status': 'todo',
          'createdByType': 'user',
          'createdById': 'alice',
        },
      ];
      await mount(t, 'tasks');
      await t.tap(find.text('Previously accepted'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Mark done'), findsNothing);
      expect(find.text('Close task'), findsNothing);
      expect(c.mutations, isEmpty);
    },
  );
}
