// raft-flutter parity EXTENSION suite builders (tool/parity-ext): list-style
// pages that had no case (Search page states, Activity, Saved, Tasks, desktop
// notification center, channel / section / computer dialogs). NOT official cases;
// ids are `components.list-pages.<key>.<theme>`, dispatched on props.extCase /
// props.extKind exactly like tool/parity-ext/host/ListPagesCases.tsx.
//
// Data: tool/parity-ext/fixtures/listpages.json (fixtures['ext:listpages']), the
// same file the React render host imports; its `routes` + the case's `routeSet`
// answer the API reads on both providers.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_account_usage.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/system_notification_projection.dart';
import 'package:raft_flutter/data/system_notification_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/add_computer_dialog.dart';
import 'package:raft_flutter/features/add_members_dialog.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ext_list_pages_keys.g.dart';
import 'ext_shell.dart' show extShellCases;
import 'home_tasks/fixture_workspace.dart';
import 'screens/screen_fixture.dart';

const _serverId = 'visual-server';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:listpages'] as Map<String, dynamic>;

/// `routes` overlaid with the case's `routeSet` (the React provider's rule).
Map<String, dynamic> _routes(ParityContext ctx) => {
  ...Map<String, dynamic>.from(_fx(ctx)['routes'] as Map),
  ...?(_fx(ctx)['routeSets'] as Map?)?[ctx.props['routeSet']] as Map?,
};

/// The official fixture workspace answering the listpages routes first.
class _ListWorkspace extends ParityFixtureWorkspace {
  _ListWorkspace(super.client, super.ctx);

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    final answer = _routes(ctx)['GET ${path.split('?').first}'];
    if (answer is Map && answer['\$pending'] == true) {
      return Completer<dynamic>().future;
    }
    if (answer is Map && answer['\$status'] != null) {
      final body = answer['\$body'];
      throw RaftApiException.response(
        'fixture error',
        status: answer['\$status'] as int,
        body: body is Map ? body : null,
      );
    }
    if (path == '/tasks/server' && answer is Map && answer['tasks'] is List) {
      final status = query?['status'];
      return {
        'tasks': [
          for (final t in answer['tasks'] as List)
            if (status == null || (t as Map)['status'] == status) t,
        ],
        'next_cursor': answer['next_cursor'],
      };
    }
    if (path == '/agents' && ctx.props['extKind'] == 'create-channel') {
      // primeCreateChannelStores' roster: Cindy + the inline Visual QA agent.
      final cindy = Map<String, dynamic>.from(ctx.fixtureData['agents']['cindy'] as Map);
      return [
        {
          'id': cindy['id'],
          'name': cindy['name'],
          'displayName': cindy['displayName'],
          'avatarUrl': cindy['avatar'],
          'description': cindy['description'],
          'deletedAt': null,
        },
        {
          'id': 'agent-qa',
          'name': 'Visual-QA',
          'displayName': 'Visual QA',
          'avatarUrl': 'pixel:eye',
          'description': 'Checks screenshots before release.',
          'deletedAt': null,
        },
      ];
    }
    return answer ?? super.query(path, query: query);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    final answer = _routes(ctx)['$method $path'];
    if (answer is Map && answer['\$pending'] == true) {
      return Completer<dynamic>().future;
    }
    if (answer is Map && answer['\$status'] != null) {
      final body = answer['\$body'];
      throw RaftApiException.response(
        body is Map && body['error'] != null
            ? '${body['error']}'
            : 'fixture error',
        status: answer['\$status'] as int,
        body: body is Map ? body : null,
      );
    }
    return answer ?? <String, dynamic>{};
  }
}

_ListWorkspace _workspace(ParityContext ctx, String section) {
  final fx = ctx.fixtureData;
  final wire = ScreenWire(fx);
  final client = ScreenFixtureClient(
    (method, path, query) {
      final answer = _routes(ctx)['$method $path'];
      if (answer is Map && answer['\$pending'] == true) {
        return ScreenFixtureClient.pending;
      }
      if (answer is Map && answer['\$status'] != null) {
        throw RaftApiException(
          'fixture error',
          status: answer['\$status'] as int,
        );
      }
      return answer ?? wire.common(method, path, query);
    },
    user: wire.me(),
    server: _serverId,
    origin: parityOrigin,
  );
  final channels = fx['channels'] as Map;
  return _ListWorkspace(client, ctx)
    ..server = RaftRecord(wire.server())
    ..channels = [
      for (final key in ['design', 'androidArtifacts'])
        RaftChannel({
          'id': channels[key]['id'],
          'serverId': _serverId,
          'name': channels[key]['name'],
          'description': channels[key]['description'],
          'type': 'channel',
          'joined': true,
          'createdAt': channels[key]['createdAtIso'],
          if (key == 'design' && ctx.props['channelCaps'] == true)
            'channelCapabilities': {
              'addChannelMembers': true,
              'removeChannelMembers': true,
            },
        }),
    ]
    ..section = section;
}

/// Search memory preloaded with the case's history tags (`searchHistory`,
/// `|`-separated), under the scope key ResourceView reads.
SearchMemoryStore _memory(ParityContext ctx, _ListWorkspace w) {
  final storage = ParityMemorySearchStorage();
  final history = (ctx.props['searchHistory'] as String?)?.split('|');
  if (history != null) {
    final scope = SearchMemoryScope(
      w.client.origin,
      _serverId,
      w.client.user!.id,
    );
    storage.values[scope.key] = jsonEncode({
      'version': 1,
      'history': history,
      'usage': <String, dynamic>{},
      'state': const SearchStateSnapshot().toJson(),
    });
  }
  return SearchMemoryStore(storage: storage, clock: () => parityNow(ctx));
}


// ------------------------------------------------------------ notification center (desktop rail bell)

class _NoticeStore extends SystemNotificationStore {
  _NoticeStore(this.notices) : super(get: (path, {query}) async => {});
  final List<SystemNotice> notices;
  @override
  List<SystemNotice> get entries => notices;
  @override
  Future<void> bind(SystemNotificationContext next) async => context = next;
  @override
  Future<void> refresh() async {}
}

Widget _notification(ParityContext ctx) {
  final w = _workspace(ctx, 'chat');
  final notices = [
    for (final n in _fx(ctx)['notifications'] as List)
      SystemNotice(
        id: (n as Map)['id'] as String,
        kind: n['kind'] == 'warning'
            ? SystemNoticeKind.warning
            : SystemNoticeKind.info,
        title: n['title'] as String,
        body: n['body'] as String,
        destination: SystemNoticeDestination.computers,
        fingerprint: 'fp-${n['id']}',
      ),
  ];
  return ctx.frame(
    width: 420,
    height: 800,
    padding: EdgeInsets.zero,
    child: Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Builder(
            builder: (context) => SizedBox(
              width: RaftTokens.of(context).brutal ? 64 : 56,
              height: 44,
              child: Center(
                child: SystemNotificationBell(
                  controller: w,
                  mobile: false,
                  onBilling: () {},
                  store: _NoticeStore(notices),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------ shell-derived dialogs

Widget _shell(ParityContext ctx) {
  final theme = switch (ctx.themeId) {
    'elegant-light' => 'elegant',
    'elegant-dark' => 'elegant-dark',
    _ => 'brutal',
  };
  final base = ctx.props['platform'] == 'desktop'
      ? 'components.shell.desktop.dialog.new-section'
      : 'components.shell.mobile.sidebar.default';
  return extShellCases['$base.$theme']!.build(ctx);
}

// ------------------------------------------------------------ create channel states

Widget _createChannel(ParityContext ctx) {
  final w = _workspace(ctx, 'chat');
  // The React host paints a white page under the Modal scrim in every theme.
  return Scaffold(
    backgroundColor: Colors.white,
    body: CreateChannelDialog(
      controller: w,
      prefilledName: ctx.props['name'] as String?,
      prefilledDescription: ctx.props['description'] as String?,
    ),
  );
}

// ------------------------------------------------------------ phone computers (computers fixture)

Map<String, dynamic> _cfx(ParityContext ctx) =>
    ctx.fixtures['ext:computers'] as Map<String, dynamic>;

List<Map<String, dynamic>> _machines(ParityContext ctx) {
  final fx = _cfx(ctx);
  final machines = Map<String, dynamic>.from(fx['machines'] as Map);
  final detail = ctx.props['machine'] == null
      ? null
      : machines[ctx.props['machine']] as Map?;
  return [
    for (final id in (fx['lists'][ctx.props['list'] ?? 'default'] as List))
      Map<String, dynamic>.from(
        detail != null && detail['id'] == id ? detail : machines[id] as Map,
      ),
  ];
}

WorkspaceController _cWorkspace(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  final fx = _cfx(ctx);
  final wire = ScreenWire(ctx.fixtureData);
  final routes = Map<String, dynamic>.from(fx['routes'] as Map);
  final loading = '${ctx.props['loading']}' == 'true';
  final failing = ctx.props['loadStatus'] == 'error';
  // `loadError` over a loaded list: the first read succeeds, the refresh fails.
  final refreshFails = ctx.props['loadError'] == 'true' && !failing;
  var machineReads = 0;
  final client = ScreenFixtureClient(
    (method, path, query) {
      if (method == 'GET' && path == '/servers/$_serverId/machines') {
        machineReads++;
        if (failing || (refreshFails && machineReads > 1)) {
          throw const RaftApiException('fixture error', status: 500);
        }
        return loading
            ? ScreenFixtureClient.pending
            : {
                'machines': _machines(ctx),
                'latestComputerVersion': fx['latestComputerVersion'],
                'latestComputerReleaseNotes': null,
              };
      }
      if (method == 'GET' && path == '/agents') {
        return [
          for (final a in fx['agents'] as List)
            {...Map<String, dynamic>.from(a as Map), 'serverId': _serverId},
        ];
      }
      final answer = routes['$method $path'];
      if (answer != null) return answer;
      return wire.common(method, path, query);
    },
    user: wire.me(),
    server: _serverId,
  );
  final w = WorkspaceController(client);
  final server = RaftRecord(wire.server());
  w
    ..servers = [server]
    ..server = server;
  w.messageDomain.ledger.switchServer(_serverId);
  final now = parityNow(ctx);
  w.agentTabCache.put(
    'runtime-account-usage',
    RuntimeAccountUsageClient(
      get: w.query,
      post: (path, body) => w.command('POST', path, data: body),
      now: () => now,
    ),
  );
  return w;
}

Widget _mComputers(ParityContext ctx) => ScreenWorkspaceHost(
  create: () => _cWorkspace(ctx),
  builder: (context, w) => ctx.frame(
    width: 390,
    height: 844,
    padding: EdgeInsets.zero,
    child: Material(
      type: MaterialType.transparency,
      // The Web body sits under the 62 / 56px PanelHeader; the page header
      // is the owner's native app bar, so only the body is compared.
      child: Padding(
        padding: EdgeInsets.only(top: RaftTokens.of(context).brutal ? 62 : 56),
        child: KeyedSubtree(
          key: const ValueKey('mobile-computers-body'),
          child: FleetView(
            controller: w,
            computers: true,
            attentionOnly: ctx.props['filter'] == 'attention',
            onOpenDetail: (_) {},
          ),
        ),
      ),
    ),
  ),
);

Widget _mDetail(ParityContext ctx) => ScreenWorkspaceHost(
  create: () {
    final w = _cWorkspace(ctx);
    w.entityDirectory.ensure([WorkspaceEntityKind.computers]);
    return w;
  },
  builder: (context, w) => ctx.frame(
    width: 390,
    height: ctx.height,
    padding: EdgeInsets.zero,
    child: Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: w.entityDirectory,
        builder: (context, _) {
          final id = (_cfx(ctx)['machines'][ctx.props['machine']] as Map)['id'];
          final machine = w.entityDirectory.computer(id as String);
          return machine == null
              ? const SizedBox.shrink()
              : ComputerDetailPanel(
                  controller: w,
                  machine: machine,
                  remoteUpgradeV2: false,
                  deployment: 'development',
                );
        },
      ),
    ),
  ),
);

Widget _mAdd(ParityContext ctx) => ScreenWorkspaceHost(
  create: () {
    final w = _cWorkspace(ctx);
    w.entityDirectory.ensure([WorkspaceEntityKind.computers]);
    return w;
  },
  builder: (context, w) => ctx.frame(
    width: 390,
    height: ctx.height,
    padding: EdgeInsets.zero,
    child: ColoredBox(
      color: Colors.white,
      child: Builder(
        builder: (context) {
          final t = RaftTokens.of(context);
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: t.brutal
                      ? Colors.black.withValues(alpha: .6)
                      : t.colors['layer-backdrop']!,
                ),
              ),
              AddComputerDialog(controller: w, deployment: 'development'),
            ],
          );
        },
      ),
    ),
  ),
);


// ------------------------------------------------------------ channel member dialogs

Widget _removeMember(ParityContext ctx) {
  final w = _workspace(ctx, 'chat');
  return Scaffold(
    backgroundColor: Colors.white,
    body: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ChannelMembersButton(
          controller: w,
          channel: w.channels.first,
        ),
      ),
    ),
  );
}

/// The Web AddMembersDialog on a blank page: the React host renders the
/// dialog alone, so the Flutter side shows the dialog over the same blank page.
Widget _addMembers(ParityContext ctx) {
  final w = _workspace(ctx, 'chat');
  final fx = ctx.fixtureData;
  return Scaffold(
    backgroundColor: Colors.white,
    body: AddMembersDialog(
      controller: w,
      channelId: w.channels.first.id,
      prefilledHumanIds: [fx['humans']['designer']['id'] as String],
      prefilledAgentIds: [fx['agents']['productUx']['id'] as String],
    ),
  );
}

/// The Web CreateJointChannelDialog on a blank page, over the same agent and
/// member lists the Joint channels page loads.
Widget _createJoint(ParityContext ctx) {
  final w = _workspace(ctx, 'chat');
  return Scaffold(
    backgroundColor: Colors.white,
    body: _JointDialogHost(controller: w),
  );
}

class _JointDialogHost extends StatefulWidget {
  const _JointDialogHost({required this.controller});
  final WorkspaceController controller;
  @override
  State<_JointDialogHost> createState() => _JointDialogHostState();
}

class _JointDialogHostState extends State<_JointDialogHost> {
  List<Map<String, dynamic>>? agents, users;
  @override
  void initState() {
    super.initState();
    final w = widget.controller;
    Future.wait([
      w.query('/agents'),
      w.query('/servers/${w.server!.id}/members'),
    ]).then((values) {
      if (!mounted) return;
      List<Map<String, dynamic>> rows(dynamic v) => [
        for (final row in (v as List? ?? const []).whereType<Map>())
          Map<String, dynamic>.from(row),
      ];
      setState(() {
        agents = [
          for (final a in rows(values[0]))
            if (a['deletedAt'] == null) a,
        ];
        users = [
          for (final u in rows(values[1]))
            if ((u['userId'] ?? u['id']) != w.client.user?.id) u,
        ];
      });
    });
  }

  @override
  Widget build(BuildContext context) => agents == null
      ? const SizedBox.shrink()
      : CreateJointChannelDialog(
          agents: agents!,
          users: users!,
          freePlan: true,
          origin: widget.controller.client.origin,
          onCreate: (_) async => <String, dynamic>{},
          onUnarchive: (_) async => <String, dynamic>{},
        );
}

Widget _panel(ParityContext ctx) {
  final panel = ctx.props['panel'] as String;
  final w = _workspace(ctx, panel);
  final width = (ctx.props['w'] as num? ?? 342).toDouble();
  final height = (ctx.props['h'] as num? ?? 620).toDouble();
  final now = parityNow(ctx);
  // Menus open at the pointer outside the panel: the React case screenshots
  // the whole viewport, so the Flutter side captures it too.
  final key = ctx.props['extCase'] as String;
  final viewportCapture =
      key.endsWith('-context-menu') || key.endsWith('-actions');
  final view = Scaffold(
    body: ResourceView(
      controller: w,
      section: panel,
      clock: () => now,
      onBack: () {},
      initialQuery: ctx.props['q'] as String?,
      searchMemory: _memory(ctx, w),
      restoreSearchState: false,
      onMessage: (_, _) async {},
    ),
  );
  return RaftDensityScope(
    density: ctx.props['platform'] == 'desktop' || panel == 'activity'
        ? RaftDensity.desktop
        : RaftDensity.touch,
    child: viewportCapture
        ? Align(
            alignment: Alignment.topLeft,
            child: ClipRect(
              child: SizedBox(width: width, height: height, child: view),
            ),
          )
        : ctx.frame(
            width: width,
            height: height,
            padding: EdgeInsets.zero,
            child: view,
          ),
  );
}

Future<void> _tap(WidgetTester t, Finder f, [int ms = 300, bool last = false]) async {
  await t.tap(last ? f.last : f.first);
  await t.pump(Duration(milliseconds: ms));
}

Future<void> _click(WidgetTester t, Finder f) async {
  await t.tapAt(t.getCenter(f.first), kind: PointerDeviceKind.mouse);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _rightClick(WidgetTester t, Finder f) async {
  await t.tapAt(
    t.getCenter(f.first),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await t.pump(const Duration(milliseconds: 300));
}

/// Per-case interactions (the Flutter counterpart of the manifest's React
/// `capture.interactions`).
Future<void> _interact(WidgetTester t, ParityContext ctx) async {
  await t.pump(const Duration(milliseconds: 50));
  final key = ctx.props['extCase'] as String;
  // The Web page waits 850ms for its debounced reads before every step.
  await t.pump(const Duration(milliseconds: 850));
  switch (key) {
    case 'search.desktop-channel-filter':
      await _tap(t, find.text('Channel'), 250);
    case final k when k.endsWith('-filter-unread'):
      await _tap(t, find.text('Unread'));
    case final k when k.endsWith('-filter-mentions'):
      await _tap(t, find.text('Mentions'));
    case final k when k.startsWith('activity.') && k.endsWith('-context-menu'):
      await _rightClick(t, find.byType(RaftConversationCard));
    case final k when k.startsWith('saved.') && k.endsWith('-actions'):
      await _rightClick(t, find.byKey(const ValueKey('saved-msg-saved-visual-1')));
    case 'tasks.desktop-list':
      await _tap(t, find.text('List'));
    case 'tasks.desktop-status-menu':
      await _tap(t, find.text('List'));
      await _tap(t, find.byType(RaftTaskStatusEditor));
    case final k when k.endsWith('-filtered'):
      await _tap(t, find.text('Assignee'));
      await _tap(
        t,
        find.byKey(const ValueKey('task-filter-Assignee-agent:agent-cindy')),
      );
    case final k when k.endsWith('-filtered-empty'):
      await _tap(t, find.text('Creator'));
      await _tap(
        t,
        find.byKey(
          const ValueKey('task-filter-Creator-agent:agent-product-ux'),
        ),
      );
    case final k when k.contains('-filter-assignee'):
      await _tap(t, find.text('Assignee'));
    case final k when k.contains('-filter-creator'):
      await _tap(t, find.text('Creator'));
    case final k when k.contains('-filter-channels'):
      await _tap(t, find.text('Channel'));
    case final k when k.endsWith('-remove-confirm'):
      await _click(t, find.byKey(const ValueKey('channel-members-open')));
      await t.pump(const Duration(milliseconds: 400));
      // ignore: avoid_print
      print('REMOVE-DEBUG ${find.byType(RaftIconButton).evaluate().map((e) => (e.widget as RaftIconButton).tooltip).toList()}');
      await _tap(
        t,
        find.byWidgetPredicate(
          (w) => w is RaftIconButton && w.tooltip == 'Remove Cindy',
        ),
        400,
      );
    case 'computers.phone-refresh-error':
      final fleet = t.widget<FleetView>(find.byType(FleetView));
      unawaited(
        fleet.controller.entityDirectory.refresh(
          WorkspaceEntityKind.computers,
          force: true,
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
    case 'notification.desktop-center':
      await _tap(t, find.byType(RaftMobileNotificationButton), 500);
    case final k when k.startsWith('create-channel.'):
      await _tap(t, find.text('Create Channel'), 600);
  }
  await t.pump(const Duration(milliseconds: 600));
}

ParityCase _case() => ParityCase(
  widgets: const ['raft_flutter:ResourceView'],
  notes: 'Extension suite (not official).',
  settle: const Duration(milliseconds: 850),
  build: (ctx) => switch (ctx.props['extKind']) {
    'panel' => _panel(ctx),
    'notification' => _notification(ctx),
    'shell' => _shell(ctx),
    'create-channel' => _createChannel(ctx),
    'remove-member' => _removeMember(ctx),
    'add-members' => _addMembers(ctx),
    'create-joint' => _createJoint(ctx),
    'm-computers' => _mComputers(ctx),
    'm-detail' => _mDetail(ctx),
    'm-add' => _mAdd(ctx),
    final kind => throw StateError('unknown list-pages kind $kind'),
  },
  interact: _interact,
);

/// Every extension list-pages case, keyed by id (3 themes each).
final Map<String, ParityCase> extListPageCases = {
  for (final key in extListPageKeys)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.list-pages.$key.$theme': _case(),
};
