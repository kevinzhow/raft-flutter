// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the Tasks
// board page and the task detail modal. NOT official cases; ids are
// `components.taskspage.<platform>.<state>.<theme>` and
// `components.taskdetail.<platform>.<state>.<theme>`, dispatched on props like
// tool/parity-ext/host/TaskDetailCases.tsx.
//
// The REAL WorkspaceView is mounted at the case viewport (section `tasks`),
// like the React host mounts the real MainLayout on `/s/<slug>/tasks`. A
// detail case opens the task through the controller's task route
// (`navigateTask(?task=<channel>:<message>)`), the state the board card tap
// leaves. Captures:
//   * taskspage desktop: the Tasks column right of the rail (React
//     `[data-testid="thread-main-column"]`); mobile: the whole page.
//   * taskdetail: the whole viewport (scrim + modal / mobile-modal overlay).
//
// Data: tool/parity-ext/fixtures/taskdetail.json (fixtures['ext:taskdetail'])
// is served by a fixture client with the same `routes` + the case's route set
// Web answers through page.route; `GET /tasks/server` honours `status` like the
// server (one summary page per lane).
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';
import '../../support/app_services_fixture.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:taskdetail'] as Map<String, dynamic>;

Map<String, dynamic>? _detail(ParityContext ctx) {
  final key = ctx.props['detail'] as String?;
  return key == null
      ? null
      : Map<String, dynamic>.from(
          (_fx(ctx)['details'] as Map)[key] as Map,
        );
}

/// `ParityFakeClient` + the server's per-status summary pages.
class _TaskClient extends ParityFakeClient {
  _TaskClient({required super.user, required super.routes, required this.board});

  final List<dynamic> board;

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
    if (method == 'GET' && path == '/tasks/server') {
      requests.add('$method $path');
      final status = query?['status'];
      return {
        'tasks': [
          for (final t in board)
            if (status == null || (t as Map)['status'] == status) t,
        ],
        'next_cursor': null,
      };
    }
    return super.request(
      method,
      path,
      data: data,
      query: query,
      authorized: authorized,
      retried: retried,
      cancellation: cancellation,
      onSendProgress: onSendProgress,
      headers: headers,
      acceptServerExit: acceptServerExit,
      receiveTimeout: receiveTimeout,
    );
  }
}

WorkspaceController _workspace(ParityContext ctx, {List<dynamic>? board}) {
  SharedPreferences.setMockInitialValues({});
  final fx = _fx(ctx);
  final base = ParityThreadFixture(ctx.fixtureData);
  final designer = base.human('designer');
  final detail = _detail(ctx);
  final routes = <String, dynamic>{
    ...Map<String, dynamic>.from(fx['routes'] as Map),
    ...?(detail == null
        ? null
        : Map<String, dynamic>.from(
            (fx['routeSets'] as Map)['td-${ctx.props['detail']}'] as Map,
          )),
    if (detail != null)
      'GET /tasks/channel/${detail['task']['channelId']}/number/${detail['task']['taskNumber']}':
          {'task': detail['task']},
    'GET /servers/visual-server/members': [
      ...base.serverMembers,
      // The creator of the fixture tasks (Web resolves it from the channel's
      // `humans`, fixture `GET /channels/*/members`).
      {
        'id': 'visual-user',
        'userId': 'visual-user',
        'serverId': 'visual-server',
        'name': 'artin',
        'displayName': 'artin',
        'description': 'Owner',
        'avatarUrl': null,
        'email': 'artin@example.test',
        'role': 'owner',
      },
      {
        'id': designer['id'],
        'userId': designer['id'],
        'serverId': 'visual-server',
        'name': designer['name'],
        'displayName': designer['displayName'],
        'description': designer['description'],
        'avatarUrl': null,
        'email': designer['email'],
        'role': designer['role'],
      },
    ],
  };
  final client = _TaskClient(
    user: base.authUser,
    routes: routes,
    board: board ?? List<dynamic>.from(fx['board'] as List),
  );
  final w = WorkspaceController(client)
    ..server = RaftRecord(base.serverRecord)
    ..channels = [
      for (final c in fx['channels'] as List)
        RaftChannel(Map<String, dynamic>.from(c as Map)),
    ]
    ..dms = const []
    ..section = 'tasks';
  w.messageDomain.ledger.switchServer('visual-server');
  if (detail != null) {
    final task = detail['task'] as Map;
    w.navigation.navigateTask(
      w.location.withQuery({'task': '${task['channelId']}:${task['messageId']}'}),
      kind: RaftNavigationKind.replace,
    );
  }
  return w;
}

class _Host extends StatefulWidget {
  const _Host({required this.ctx, this.board});
  final ParityContext ctx;
  final List<dynamic>? board;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final WorkspaceController w = _workspace(widget.ctx, board: widget.board);

  @override
  Widget build(BuildContext context) => withAppServices(
    WorkspaceView(
      controller: w,
      appearance: RaftAppearance(
        mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
        light: widget.ctx.family,
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

/// The Tasks column the React host crops on desktop: the viewport right of the
/// left rail (brutal 64, elegant 56).
Rect? _window(ParityContext ctx) {
  final page =
      ctx.props['extKind'] == 'taskspage' ||
      ctx.props['surface'] == 'tasks-board';
  if (!page || ctx.props['platform'] == 'mobile') {
    return null;
  }
  final rail = ctx.family == RaftFamily.brutal ? 64.0 : 56.0;
  return Rect.fromLTWH(rail, 0, ctx.width - rail, ctx.height);
}

/// The Tasks page (real WorkspaceView, section tasks) on [board] instead of
/// the fixture's board; [window] crops it like the taskspage cases. Shared with
/// the WP6 cases (ext_wp6.dart).
Widget extTaskPageBuild(ParityContext ctx, {List<dynamic>? board}) =>
    _build(ctx, board: board);

/// The fixture workspace of the task cases (channels, members, routes).
WorkspaceController extTaskWorkspace(ParityContext ctx) => _workspace(ctx);

Widget _build(ParityContext ctx, {List<dynamic>? board}) {
  final window = _window(ctx);
  if (window == null) return _Host(ctx: ctx, board: board);
  return Align(
    alignment: Alignment.topLeft,
    child: ctx.target(
      SizedBox.fromSize(
        size: window.size,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: ctx.width,
            maxWidth: ctx.width,
            minHeight: ctx.height,
            maxHeight: ctx.height,
            child: Transform.translate(
              offset: -window.topLeft,
              child: _Host(ctx: ctx, board: board),
            ),
          ),
        ),
      ),
    ),
  );
}

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:ResourceView',
    'raft_flutter:SourceTaskSurface',
    'raft_ui:RaftTaskSection',
  ],
  notes:
      'Extension suite (not official). Real WorkspaceView on the tasks section; '
      'detail cases open the task route.',
  settle: const Duration(milliseconds: 1500),
  build: _build,
);

const _pageStates = ['board', 'expanded'];
const _detailStates = [
  'empty',
  'replies',
  'replies-short',
  'history-open',
  'status-todo',
  'status-in-progress',
  'status-in-review',
  'status-done',
  'status-closed',
  'unassigned',
  'assigned',
  'long-title',
  'description',
];

/// Every extension Tasks page / task detail case, keyed by id (3 themes each).
final Map<String, ParityCase> extTaskDetailCases = {
  for (final platform in const ['desktop', 'mobile'])
    for (final theme in const ['brutal', 'elegant', 'elegant-dark']) ...{
      for (final state in _pageStates)
        // Mobile has no `expanded` case (see build-task-detail.py).
        if (platform == 'desktop' || state != 'expanded')
          'components.taskspage.$platform.$state.$theme': _case,
      for (final state in _detailStates)
        'components.taskdetail.$platform.$state.$theme': _case,
    },
};
