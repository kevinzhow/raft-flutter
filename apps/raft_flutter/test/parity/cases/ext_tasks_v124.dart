import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_services_fixture.dart';
import '../parity_harness.dart';
import 'fixture_when.dart';
import 'thread_composer/fake_workspace.dart';

class _TasksClient extends ParityFakeClient {
  _TasksClient({required super.user, required super.routes});

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
    final answer = resolveFixtureWhen(routes['$method $path'], query);
    if (answer != null) {
      requests.add('$method $path');
      return answer;
    }
    return super.request(method, path, data: data, query: query);
  }
}

Widget _build(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  final fixture = ctx.fixtures['ext:tasks-v124'] as Map;
  final base = ParityThreadFixture(ctx.fixtureData);
  final previousClock = sourceTimeNow;
  final clock = DateTime.fromMillisecondsSinceEpoch(
    ctx.fixtureData['locale']['nowEpochMillis'] as int,
    isUtc: true,
  );
  sourceTimeNow = () => clock;
  ctx.onDispose(() => sourceTimeNow = previousClock);
  final routes = Map<String, dynamic>.from(fixture['routes'] as Map);
  routes['GET /servers/visual-server/members'] = base.serverMembers;
  final client = _TasksClient(user: base.authUser, routes: routes);
  final workspace = WorkspaceController(client)
    ..server = RaftRecord(base.serverRecord)
    ..section = 'tasks'
    ..channels = [
      RaftChannel(Map<String, dynamic>.from(fixture['channel'] as Map)),
    ]
    ..dms = const [];
  workspace.messageDomain.ledger.switchServer('visual-server');
  TaskV2ConversationsFlag.of(workspace).markEnabled();
  final tasks = TasksPageStore.of(workspace);
  ctx.onDispose(() {
    tasks.dispose();
    workspace.dispose();
  });
  return withAppServices(
    WorkspaceView(
      controller: workspace,
      appearance: RaftAppearance(
        mode: ctx.dark ? ThemeMode.dark : ThemeMode.light,
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

Future<void> _checkState(WidgetTester tester, ParityContext ctx) async {
  await tester.pump(const Duration(milliseconds: 500));
  final state = ctx.props['state'];
  final open =
      state == 'detail-open' ||
      state == 'detail-switch' ||
      state == 'detail-focus';
  final title = find.byKey(const ValueKey('task-modal-title')).hitTestable();
  expect(title, open ? findsOneWidget : findsNothing);
  final surface = open
      ? title
      : find.byKey(const ValueKey('tasks-page-toolbar'));
  final tokens = RaftTokens.of(tester.element(surface));
  expect(
    tokens.colors['layer-canvas']!.computeLuminance(),
    ctx.id.endsWith('.elegant-dark') ? lessThan(.1) : greaterThan(.9),
  );
  if (open) {
    expect(
      tester.widget<Text>(title).data,
      state == 'detail-switch'
          ? startsWith('Investigate sidebar flicker')
          : 'Check the task detail layout',
    );
    expect(
      find.byKey(const ValueKey('task-conversation-empty')),
      findsOneWidget,
    );
    expect(find.text('No replies yet'), findsNothing);
  } else {
    expect(
      find.byKey(const ValueKey('tasks-page-all-list')),
      state == 'list-all' ? findsOneWidget : findsNothing,
    );
    if (ctx.props['platform'] == 'desktop') {
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tasks-page-tab-all')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('2d ago'), findsWidgets);
    expect(
      find.byKey(const ValueKey('tasks-page-toolbar')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .byKey(
            ValueKey(
              state == 'list-all'
                  ? 'tasks-page-row-open-visual-task-15'
                  : 'tasks-page-row-open-visual-task-16',
            ),
          )
          .hitTestable(),
      findsOneWidget,
    );
    final agentRow = find.byKey(
      ValueKey(
        state == 'list-all'
            ? 'tasks-page-row-open-visual-task-15'
            : 'tasks-page-row-open-visual-task-1',
      ),
    );
    expect(
      find.descendant(
        of: agentRow,
        matching: find.byWidgetPredicate(
          (widget) => widget is RaftPixelAvatar && widget.avatarKey == 'robot',
        ),
      ),
      findsOneWidget,
    );
  }
}

final _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:TasksPage',
    'raft_flutter:SourceTaskSurface',
    'raft_ui:RaftTaskPageList',
    'raft_ui:RaftTaskSurface',
  ],
  build: _build,
  interact: _checkState,
);

final Map<String, ParityCase> extTasksV124Cases = {
  for (final (platform, states) in [
    (
      'desktop',
      [
        'list-mine',
        'list-all',
        'detail-open',
        'detail-switch',
        'detail-close',
        'detail-focus',
      ],
    ),
    ('phone', ['list-mine', 'list-all', 'detail-open', 'detail-close']),
  ])
    for (final state in states)
      for (final theme in ['brutal', 'elegant-dark'])
        'components.pages.tasks-v124.$platform.$state.$theme': _case,
};
