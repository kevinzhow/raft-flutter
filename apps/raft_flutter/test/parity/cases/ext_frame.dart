// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the app FRAME
// (level L1), at phone / tablet / desktop widths. NOT official cases; ids are
// `components.frame.<platform>.<key>.<theme>`, dispatched on props like
// tool/parity-ext/host/FrameCases.tsx (the real Web MainLayout).
//
// The REAL WorkspaceView is mounted at the case viewport with the shared shell
// workspace (fixtures['ext:shell'], preset from props) plus, for the channel
// scene, the message routes of fixtures['ext:screens']. Whole-window cases
// capture the viewport; part cases (top bar, rail, sidebar, tab bar) capture a
// keyed rectangle (`frame-crop`, props cx / cy / cw / ch) over the same pixels
// as the React marker.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    show addTearDown, expect, find, findsNothing, findsOneWidget, isTrue;
import 'package:raft_client/raft_client.dart' show Session;
import 'package:raft_flutter/app_root.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_global_server_selector_test.dart'
    show RootClient, RootFixture;
import '../parity_harness.dart';
import 'ext_frame_keys.g.dart';
import 'ext_settings.dart' show extSettingsCases;
import 'ext_shell.dart' show shellWorkspace;
import 'screens/screen_fixture.dart' show ScreenWire;
import 'thread_messages/chat_stage.dart' show ParityIdentities;
import 'thread_composer/fake_workspace.dart' show ParityFakeClient;
import '../../support/app_services_fixture.dart';

Map<String, dynamic> _screenScene(ParityContext ctx, String name) =>
    Map<String, dynamic>.from(
      ((ctx.fixtures['ext:screens'] as Map)['scenes'] as Map)[name] as Map,
    );

String? _selected(ParityContext ctx) {
  if (ctx.props['scene'] != 'channel') return null;
  final scenes = (ctx.fixtures['ext:screens'] as Map)['scenes'] as Map;
  return (scenes['channel'] as Map)['selected'] as String?;
}

const _tabBarPrefix = 'components.frame.phone.tabbar-';

bool _isTabBarPopover(ParityContext ctx) =>
    ctx.id.startsWith('${_tabBarPrefix}popover-');

Map<String, dynamic> _tabBarRoutes(ParityContext ctx) {
  if (!ctx.id.startsWith(_tabBarPrefix)) return const {};
  final fixture = ctx.fixtures['ext:mobile-tabbar'] as Map;
  return {
    ...Map<String, dynamic>.from(fixture['routes'] as Map),
    ...Map<String, dynamic>.from(
      (fixture['routeSets'] as Map)[ctx.props['routeSet']] as Map,
    ),
  };
}

WorkspaceController _workspace(ParityContext ctx) {
  // The React provider pins its clock to the fixture instant.
  final now = DateTime.fromMillisecondsSinceEpoch(
    (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
  );
  sourceTimeNow = () => now;
  addTearDown(() => sourceTimeNow = DateTime.now);
  final selected = _selected(ctx);
  final ids = ParityIdentities(ctx);
  final scenes = (ctx.fixtures['ext:screens'] as Map)['scenes'] as Map;
  final frame = ctx.fixtures['ext:frame'] as Map;
  return shellWorkspace(
    ctx,
    selected: selected,
    routes: {
      'GET /agents': ids.agents,
      'GET /servers/visual-server/members': ids.members,
      if (ctx.props['routeSet'] == 'fr-bell')
        ...Map<String, dynamic>.from(
          (frame['routeSets'] as Map)['fr-bell'] as Map,
        ),
      if (selected != null)
        'GET /tasks/channel/$selected': {'tasks': <dynamic>[]},
      if (selected != null)
        ...Map<String, dynamic>.from(
          (scenes['channel'] as Map)['routes'] as Map,
        ),
      // The Activity page's inbox rows (the control-state cases).
      if (ctx.props['scene'] == 'activity')
        ...Map<String, dynamic>.from(
          _screenScene(ctx, 'activity')['routes'] as Map,
        ),
      ..._tabBarRoutes(ctx),
    },
  );
}

class _Host extends StatefulWidget {
  const _Host({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final WorkspaceController w = _workspace(widget.ctx);
  // The Web browser default (hide-empty off), like the shell cases.
  final presentation = PersonalPresentationStore();

  @override
  void dispose() {
    w.dispose();
    presentation.dispose();
    unawaited((w.client as ParityFakeClient).stream.close());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (widget.ctx.id.startsWith(_tabBarPrefix)) {
      final client = w.client as ParityFakeClient;
      final user = client.user!.json;
      client.routes['GET /auth/me'] = user;
      await client.sessionStore.write(
        client.origin,
        Session(accessToken: 'visual-fixture', refreshToken: 'visual-fixture'),
      );
      if (!mounted || !await client.restore() || !mounted) return;
      // Use the same inbox read as a signed-in workspace. The tab reads its
      // accepted unread count, and the Activity page can reuse that window.
      await w.services.activityUnread.refresh();
      return;
    }
    if (widget.ctx.props['scene'] == 'activity') {
      w.setSection('activity');
      return;
    }
    final id = _selected(widget.ctx);
    if (id == null) return;
    final channel = [...w.channels, ...w.dms].firstWhere((c) => c.id == id);
    if (widget.ctx.props['sidePanels'] == true) {
      TaskV2ConversationsFlag.of(w).markEnabled();
    }
    await w.selectChannel(channel);
    if (mounted && widget.ctx.props['sidePanels'] == true) {
      // The fixture owns this session. Retire its cached Files notifier with
      // the test instead of leaving it to app-lifetime cache eviction.
      w.services.disposeWithSession(w.channelFilesStore(id).dispose);
    }
  }

  @override
  Widget build(BuildContext context) => withAppServices(
    WorkspaceView(
      controller: w,
      presentation: presentation,
      appearance: RaftAppearance(
        mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

/// Popover captures need the real AppRoot chooser callback and its initial
/// server-scoped machine load. The other frame cases keep their existing host.
class _TabBarPopoverHost extends StatefulWidget {
  const _TabBarPopoverHost({required this.ctx});
  final ParityContext ctx;

  @override
  State<_TabBarPopoverHost> createState() => _TabBarPopoverHostState();
}

class _TabBarPopoverHostState extends State<_TabBarPopoverHost> {
  final fixture = RootFixture();
  static const origin = 'https://parity-fixture.invalid';

  @override
  void initState() {
    super.initState();
    final ctx = widget.ctx;
    final wire = ScreenWire(ctx.fixtureData);
    final ids = ParityIdentities(ctx);
    final shell = ctx.fixtures['ext:shell'] as Map<String, dynamic>;
    SharedPreferences.setMockInitialValues({
      'raft.origin': origin,
      'raft.mode': ctx.dark ? 'dark' : 'light',
    });
    addTearDown(DevicePreferences.reset);
    final now = (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt();
    sourceTimeNow = () => DateTime.fromMillisecondsSinceEpoch(now);
    addTearDown(() => sourceTimeNow = DateTime.now);
    unawaited(
      fixture.sessions.write(
        origin,
        Session(accessToken: 'visual-fixture', refreshToken: 'visual-fixture'),
      ),
    );
    final routes = <String, Object?>{
      ..._tabBarRoutes(ctx),
      'GET /auth/me': wire.me(),
      'GET /servers': [
        for (final server in (shell['servers'] as List).cast<Map>())
          {...ids.server, ...server},
      ],
      'GET /agents': ids.agents,
      'GET /servers/${ids.serverId}/members': ids.members,
      'GET /servers/${ids.serverId}/machines': wire.machines(),
      'GET /servers/${ids.serverId}/setup-projection': {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      },
      'GET /channels/public': <Object>[],
      'GET /channels/saved': ctx.fixtures['savedMessagesFixture'],
    };
    // The lighter frame host presets these counts in memory. AppRoot restores
    // the same unread snapshot through the client, which requires a frontier
    // marker. The shared fixture has no accepted frontiers.
    final unread = (routes['GET /channels/unread'] as Map)['channels'] as Map;
    routes['GET /channels/unread'] = {
      'channels': {
        for (final entry in unread.entries)
          entry.key: {
            ...entry.value as Map,
            'readState': {'kind': 'absent'},
          },
      },
    };
    for (final entry in routes.entries) {
      fixture.adapter.routes[entry.key] = (_) => entry.value;
    }
  }

  @override
  Widget build(BuildContext context) => RaftApp(
    services: AppServices.updatesDisabledForTestOrPreview(
      localNetwork: fixture.network,
    ),
    sessionStore: fixture.sessions,
    initialLocation: Uri(
      path: '/s/${widget.ctx.fixtureData['server']['slug']}',
    ),
    nativeContent: fixture.content,
    nativeSharing: NativeSharing(supported: false),
    openWorkspaceCache: () async => fixture.cache,
    createClient: (origin, store, kind) =>
        fixture.client = RootClient(origin, store, kind, fixture.adapter),
  );
}

Widget _build(ParityContext ctx) {
  final p = ctx.props;
  final crop = p['cw'] == null
      ? null
      : Rect.fromLTWH(
          (p['cx'] as num).toDouble(),
          (p['cy'] as num).toDouble(),
          (p['cw'] as num).toDouble(),
          (p['ch'] as num).toDouble(),
        );
  return Stack(
    children: [
      Positioned.fill(
        child: _isTabBarPopover(ctx)
            ? _TabBarPopoverHost(ctx: ctx)
            : _Host(ctx: ctx),
      ),
      if (crop != null)
        Positioned.fromRect(
          rect: crop,
          child: const IgnorePointer(
            child: SizedBox.expand(key: ValueKey('frame-crop')),
          ),
        ),
    ],
  );
}

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_ui:RaftWorkspaceRail',
    'raft_ui:RaftNavItem',
    'raft_ui:RaftChatSidebarGroup',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, app frame.',
  settle: const Duration(milliseconds: 1200),
  build: _build,
  interact: (t, ctx) async {
    if (ctx.id.startsWith(_tabBarPrefix)) {
      final scenario = (ctx.props['extCase'] as String).split('tabbar-').last;
      final popup = scenario.startsWith('popover-');
      final selected = popup
          ? 'chat'
          : scenario == 'artifacts-return'
          ? 'tasks'
          : switch (scenario.split('-').last) {
              'home' => 'chat',
              final tab => tab,
            };
      final bar = find.byKey(const Key('workspace-mobile-navigation'));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.widget<RaftMobileNav>(bar).selectedId, selected);
      expect(
        find.byKey(const Key('mobile-server-tab-popover')),
        popup ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('mobile-server-tab-artifacts')).hitTestable(),
        scenario == 'popover-on' ? findsOneWidget : findsNothing,
      );
      if (popup) {
        final choose = find.byKey(
          const Key('mobile-server-tab-switch-or-create'),
        );
        expect(choose.hitTestable(), findsOneWidget);
        final row = t.widget<RaftMobileNavServerPopoverRow>(choose);
        expect(row.enabled && row.onPressed != null, isTrue);
        expect(
          find.byKey(const Key('computers-attention-dot')).hitTestable(),
          findsOneWidget,
        );
        final computers = t.widget<RaftMobileNavServerPopoverDestination>(
          find.byKey(const Key('mobile-server-tab-computers')),
        );
        expect(computers.attention, isTrue);
        expect(computers.onPressed != null, isTrue);
        final workspace = t
            .widget<WorkspaceView>(find.byType(WorkspaceView))
            .controller;
        final directory = workspace.services.entityDirectory;
        const kind = WorkspaceEntityKind.computers;
        expect(directory.state(kind).loaded, isTrue);
        final states = {
          for (final row in directory.rows(kind)) row['id']: row['status'],
        };
        expect(states, {
          for (final row in ScreenWire(ctx.fixtureData).machines())
            row['id']: row['status'],
        });
        final list = t.widget<RaftMobileNavServerPopoverList>(
          find.byType(RaftMobileNavServerPopoverList),
        );
        final serverIds = [for (final server in workspace.servers) server.id];
        final visibleServerIds = [
          for (final id in serverIds)
            if (find
                .byKey(Key('mobile-server-tab-server-$id'))
                .hitTestable()
                .evaluate()
                .isNotEmpty)
              id,
        ];
        expect(list.children.length, serverIds.length);
        expect(visibleServerIds, serverIds);
        ctx.captureEvidence
          ..['serverDirectoryIds'] = serverIds
          ..['serverRowCount'] = list.children.length
          ..['visibleServerRowIds'] = visibleServerIds
          ..['switchOrCreateEnabled'] = row.enabled
          ..['computerAttention'] = computers.attention
          ..['loadedMachineStatuses'] = states;
      }
      if (scenario == 'artifacts-return') {
        final tab = find.byKey(const Key('mobile-tab-server'));
        expect(
          t.widget<RaftMobileNavServerTab>(tab).focusNode!.hasFocus,
          isTrue,
        );
      }
      return;
    }
    if ((ctx.props['extCase'] as String?)?.endsWith('.bell-open') == true) {
      expect(find.byType(RaftNotificationCenter), findsOneWidget);
      expect(
        t
            .widget<RaftMobileNotificationButton>(
              find.byType(RaftMobileNotificationButton),
            )
            .semanticLabel,
        'Notification Center',
      );
    }
    if (ctx.props['extCase'] == 'desktop.tasks-expanded-header') {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RaftInteractive &&
              widget.semanticLabel == 'Restore' &&
              widget.toggled == true,
        ),
        findsOneWidget,
      );
    }
    if (ctx.props['state'] != 'focus') return;
    final key = const {
      'topbar-search': 'topbar-search',
      'topbar-bell': 'topbar-notifications',
      'topbar-workspace': 'topbar-workspace',
    }[ctx.props['control']];
    if (key == null) return;
    final target = t.element(find.byKey(ValueKey<String>(key)));
    final focused = FocusManager.instance.primaryFocus?.context;
    var owned = identical(focused, target);
    focused?.visitAncestorElements((element) {
      if (identical(element, target)) {
        owned = true;
        return false;
      }
      return true;
    });
    expect(owned, isTrue, reason: 'Keyboard focus must belong to $key');
    final detectors = find
        .descendant(
          of: find.byKey(ValueKey<String>(key)),
          matching: find.byType(FocusableActionDetector),
          matchRoot: true,
        )
        .evaluate()
        .map((element) => element.widget as FocusableActionDetector);
    expect(
      detectors.any((detector) => detector.focusNode?.hasPrimaryFocus ?? false),
      isTrue,
      reason: 'The interactive button must have primary focus: $key',
    );
  },
);

const _keys = [
  'phone.home',
  'phone.tabbar',
  'tablet.home',
  'tablet.channel',
  'tablet.topbar',
  'desktop.home',
  'desktop.channel',
  'desktop.topbar',
  'desktop.rail',
  'desktop.sidebar',
  'phone.bell-open',
  'desktop.bell-open',
  'desktop.tasks-header',
  'desktop.files-folded-header',
  'desktop.tasks-expanded-header',
];

/// Every extension frame case, keyed by id (3 themes each).
final Map<String, ParityCase> extFrameCases = {
  for (final key in _keys)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.frame.$key.$theme': _case,
  for (final theme in const ['brutal', 'elegant-dark']) ...{
    for (final tab in const ['home', 'activity', 'tasks', 'search']) ...{
      '${_tabBarPrefix}bar-$tab.$theme': _case,
      '${_tabBarPrefix}header-$tab.$theme': _case,
    },
    '${_tabBarPrefix}popover-on.$theme': _case,
    '${_tabBarPrefix}popover-off.$theme': _case,
    '${_tabBarPrefix}artifacts-return.$theme': _case,
  },
  // Control-state cases (tool/parity-ext/build-states-cases.py): the same window, the interactions come from the case.
  for (final key in extStatesKeys)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.states.$key.$theme': _case,
};

/// Control-state cases of settings pages: clones of an existing ext-settings case (same host and Flutter builder,
/// new id and interactions; tool/parity-ext/build-states-cases.py SETTINGS_CONTROLS).
final Map<String, ParityCase> extStatesSettingsCases = {
  for (final (id, base) in extStatesSettingsAliases)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      if (extSettingsCases['$base.$theme'] != null)
        '$id.$theme': extSettingsCases['$base.$theme']!,
};
