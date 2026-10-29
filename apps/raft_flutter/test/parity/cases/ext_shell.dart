// raft-flutter parity EXTENSION suite builders (tool/parity-ext): shell &
// navigation surfaces the official case set does not cover - the desktop rail
// and sidebar in their states, sidebar menus and dialogs, the server switcher
// and the shared UI primitives (confirm dialog, sheets, toast, banner, empty
// state). NOT official cases; ids are `components.shell.<platform>.<surface>.<theme>`,
// dispatched on props like tool/parity-ext/host/ShellCases.tsx.
//
// The REAL WorkspaceView is mounted at the case viewport with the shared
// fixture (tool/parity-ext/fixtures/shell.json, fixtures['ext:shell']); the
// capture region is a keyed overlay over the same rectangle the React host
// crops (`capture.androidKey`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    show expect, find, findsOneWidget, isFalse, isTrue;
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';
import '../../support/app_services_fixture.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:shell'] as Map<String, dynamic>;

Map<String, dynamic> _preset(ParityContext ctx) {
  final presets = Map<String, dynamic>.from(_fx(ctx)['presets'] as Map);
  return Map<String, dynamic>.from(
    presets[ctx.props['preset'] ?? 'default'] as Map,
  );
}

WorkspaceController _workspace(ParityContext ctx) => shellWorkspace(
  ctx,
  routes: ctx.props['extKind'] == 'framework'
      ? Map<String, dynamic>.from(
          (ctx.fixtures['ext:framework'] as Map)['routes'] as Map,
        )
      : const {},
);

/// The shell workspace (preset `ctx.props['preset']`) of the shell cases; the
/// composed-screen cases (ext_screens.dart) add their message / inbox
/// [routes] and read [selected] conversation (no unread on it).
WorkspaceController shellWorkspace(
  ParityContext ctx, {
  Map<String, dynamic> routes = const {},
  String? selected,
}) {
  SharedPreferences.setMockInitialValues({});
  final fx = _fx(ctx);
  final preset = _preset(ctx);
  final base = ParityThreadFixture(ctx.fixtureData);
  final cindy = base.agent('cindy');
  final productUx = base.agent('productUx');
  final designer = base.human('designer');
  Map activityWire(Map a) {
    if (ctx.props['extKind'] != 'framework') return a;
    final frames =
        (ctx.fixtures['ext:framework'] as Map)['agentActivities'] as Map;
    final live = frames[a['id']];
    return live is Map ? live : a;
  }

  Map<String, dynamic> agentWire(Map<String, dynamic> a) => {
    'id': a['id'],
    'serverId': 'visual-server',
    'name': a['name'],
    'displayName': a['displayName'],
    'avatarUrl': a['avatar'],
    'description': a['description'],
    if (ctx.props['extKind'] == 'framework') ...{
      'runtime': a['runtime'],
      'external': a['external'],
    },
    'status': a['status'],
    // FrameworkCases primes these newer live frames over the shared snapshot.
    // Historical shell cases retain their original inputs.
    'activity': activityWire(a)['activity'],
    'activityDetail': activityWire(a)['activityDetail'],
    'deletedAt': null,
  };
  final order = <String, dynamic>{
    'pinned': preset['pinned'],
    'customSections': preset['customSections'],
    'sectionOrder': preset['sectionOrder'],
    'sectionPlacements': preset['placements'],
    'channelSortMode': (preset['sortModes'] as Map)['channels'] ?? 'manual',
    'jointChannelSortMode': (preset['sortModes'] as Map)['joint'] ?? 'manual',
    'dmSortMode': (preset['sortModes'] as Map)['dms'] ?? 'manual',
    'pinnedSortMode': (preset['sortModes'] as Map)['pinned'] ?? 'manual',
  };
  final client = ParityFakeClient(
    user: base.authUser,
    routes: {
      'GET /agents': [agentWire(cindy), agentWire(productUx)],
      'GET /servers/visual-server/sidebar-order': order,
      // The Saved row count (Web savedStore `total`, shared visual fixture).
      'GET /channels/saved': ctx.fixtures['savedMessagesFixture'],
      'GET /servers/unread-summary': [
        for (final e in (fx['serverUnread'] as Map).entries)
          {'serverId': e.key, ...Map<String, dynamic>.from(e.value as Map)},
      ],
      'GET /servers': [
        for (final server in fx['servers'] as List)
          {
            ...base.serverRecord,
            'id': (server as Map)['id'],
            'name': server['name'],
            'slug': server['slug'],
          },
      ],
      'GET /servers/visual-server/members': [
        ...base.serverMembers,
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
      ...routes,
    },
  );
  final all = {
    for (final c in [...fx['channels'] as List, ...fx['dms'] as List])
      (c as Map)['id'] as String: Map<String, dynamic>.from(c),
  };
  RaftChannel channel(String id) => RaftChannel(all[id]!);
  final w = WorkspaceController(client)
    ..server = RaftRecord(base.serverRecord)
    ..channels = [
      for (final id in [
        ...preset['channels'] as List,
        ...preset['joint'] as List,
      ])
        channel(id as String),
    ]
    ..dms = [for (final id in preset['dms'] as List) channel(id as String)]
    ..servers = [
      for (final server in fx['servers'] as List)
        RaftRecord({
          ...base.serverRecord,
          'id': (server as Map)['id'],
          'name': server['name'],
          'slug': server['slug'],
        }),
    ]
    ..sidebarOrder = order
    ..loading = preset['loading'] == true
    ..conversationReads.unread = {
      for (final e in (preset['unread'] as Map).entries)
        if (e.key != selected) e.key as String: e.value as int,
    }
    ..conversationReads.mentions = {
      for (final id in preset['mentions'] as List)
        if (id != selected) id as String,
    };
  for (final e in (preset['drafts'] as Map).entries) {
    w.drafts['${e.key}'] = '${e.value}';
  }
  w.messageDomain.ledger.switchServer('visual-server');
  return w;
}

class _Host extends StatefulWidget {
  const _Host({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Host> createState() => _HostState();
}

/// Mount the workspace without the historical shell fixture's crop or mask.
Widget shellWorkspaceView(ParityContext ctx) => _Host(ctx: ctx);

class _HostState extends State<_Host> {
  late final WorkspaceController w = _workspace(widget.ctx);
  // Hide-empty defaults off in the browser and native clients.
  final presentation = PersonalPresentationStore();

  @override
  void dispose() {
    w.dispose();
    presentation.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (widget.ctx.props['route'] == 'activity') {
      w.setSection('activity');
      return;
    }
    final id = _preset(widget.ctx)['selected'] as String?;
    if (id == null) return;
    final channel = [...w.channels, ...w.dms].firstWhere((c) => c.id == id);
    await w.selectChannel(channel);
  }

  @override
  Widget build(BuildContext context) => withAppServices(
    WorkspaceHostScope(
      browser: widget.ctx.props['shell'] == 'browser',
      child: WorkspaceView(
        controller: w,
        presentation: presentation,
        appearance: RaftAppearance(
          mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
        ),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
}

/// The rail + sidebar rectangle of the desktop shell (rail 64 / 56, sidebar 240).
double _railSidebarWidth(ParityContext ctx) => (56) + 240;

Rect _railSidebar(ParityContext ctx) => Rect.fromLTWH(
  0,
  0,
  _railSidebarWidth(ctx) + ((ctx.props['extra'] as num?) ?? 0).toDouble(),
  ctx.height,
);

Widget _desktop(ParityContext ctx) {
  final activity = ctx.props['route'] == 'activity';
  // The Activity frame crops the rail plus the 560px master column.
  final region = activity
      ? Rect.fromLTWH(0, 0, (56) + 560, ctx.height)
      : _railSidebar(ctx);
  return Stack(
    children: [
      Positioned.fill(child: _Host(ctx: ctx)),
      // The React host has no main panel: blank page right of the sidebar.
      Positioned(
        left: activity ? region.width : _railSidebarWidth(ctx),
        top: 0,
        right: 0,
        bottom: 0,
        // Dialog cases capture the whole viewport: under the Web Modal scrim sits
        // the document body (Brutal cream, Elegant `layer-canvas-muted`).
        child: Builder(
          builder: (context) {
            final t = RaftTokens.of(context);
            return ColoredBox(color: t.sidebar);
          },
        ),
      ),
      Positioned.fromRect(
        rect: region,
        child: IgnorePointer(
          child: SizedBox.expand(
            key: ValueKey(
              activity ? 'shell-activity-frame' : 'shell-rail-sidebar',
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _mobile(ParityContext ctx) {
  final activity = ctx.props['route'] == 'activity';
  return Stack(
    children: [
      Positioned.fill(child: _Host(ctx: ctx)),
      Positioned(
        left: 0,
        top: 0,
        width: ctx.width,
        height: activity ? 360 : ctx.height,
        child: IgnorePointer(
          child: SizedBox.expand(
            key: ValueKey(
              activity ? 'shell-activity-frame' : 'shell-mobile-home',
            ),
          ),
        ),
      ),
    ],
  );
}

/// The mobile Home / desktop rail cases, shared with ext_row_menus.dart.
ParityCase get extShellMobileCase => _mobileCase;
ParityCase get extShellDesktopCase => _desktopCase;

final ParityCase _mobileCase = ParityCase(
  widgets: const ['raft_flutter:WorkspaceView', 'raft_ui:RaftNavItem'],
  notes: 'Extension suite (not official). Real WorkspaceView, mobile Home.',
  settle: const Duration(milliseconds: 900),
  build: _mobile,
);

final ParityCase _desktopCase = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_ui:RaftWorkspaceRail',
    'raft_ui:RaftNavItem',
    'raft_ui:RaftChatSidebarGroup',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, rail + sidebar.',
  settle: const Duration(milliseconds: 900),
  build: _desktop,
);

// Open the product Help menu through rail-help, then crop its own keyed
// surface. Do not apply the historical shell fixture's blank main-panel mask
// or substitute a component board for this real WorkspaceView entry.
final ParityCase _helpPopupCase = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_ui:RaftWorkspaceHelpMenu',
    'raft_ui:RaftDropdownMenu',
    'raft_ui:RaftMenuPanel',
    'raft_ui:RaftMenuItem',
  ],
  notes:
      'Extension suite (not official). Real WorkspaceView Help popup bounds; '
      'historical whole-shell cases retain their own results.',
  settle: const Duration(milliseconds: 900),
  build: shellWorkspaceView,
  interact: (tester, ctx) async {
    final popup = find.byKey(const ValueKey('workspace-help-popup'));
    expect(popup, findsOneWidget);
    final documentation = find.descendant(
      of: popup,
      matching: find.widgetWithText(RaftMenuItem, 'Raft Documentation'),
    );
    expect(documentation, findsOneWidget);
    if (ctx.props['helpPopupState'] != 'focus') return;
    final detectors = find
        .descendant(
          of: documentation,
          matching: find.byType(FocusableActionDetector),
          matchRoot: true,
        )
        .evaluate()
        .map((element) => element.widget as FocusableActionDetector);
    expect(
      detectors.any((detector) => detector.focusNode?.hasPrimaryFocus ?? false),
      isTrue,
      reason: 'The actual Help documentation row must own keyboard focus.',
    );
  },
);

// Current Raft: the actual WorkspaceView sort action, complete popup bounds.
final ParityCase _sidebarSortPopupCase = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:showSidebarSortMenu',
    'raft_ui:RaftSelectionPopover',
  ],
  notes:
      'Extension suite (not official). Real WorkspaceView Channels sort popup. '
      'Historical whole-sidebar cases and their results remain separate.',
  settle: const Duration(milliseconds: 900),
  build: shellWorkspaceView,
  interact: (tester, ctx) async {
    final popup = find.byKey(const ValueKey('sidebar-sort-popover'));
    expect(popup, findsOneWidget);
    final selection = tester.widget<RaftSelectionPopover>(popup);
    expect(selection.showHeader, isFalse);
    expect(selection.options.map((option) => option.label), [
      'Manual',
      'Recent',
      'A-Z',
    ]);
    expect(
      selection.options
          .where((option) => option.checked)
          .map((option) => option.label),
      ['Manual'],
    );
    if (ctx.props['sortPopupState'] != 'focus') return;
    final focusedRow = find.byKey(const ValueKey('sidebar-sort-recent'));
    expect(focusedRow, findsOneWidget);
    expect(
      find
          .descendant(
            of: focusedRow,
            matching: find.byType(FocusableActionDetector),
            matchRoot: true,
          )
          .evaluate()
          .map((element) => element.widget as FocusableActionDetector)
          .any((detector) => detector.focusNode?.hasPrimaryFocus ?? false),
      isTrue,
      reason: 'The actual Recent option must own keyboard focus.',
    );
  },
);

const _desktopSurfaces = [
  'sidebar.default',
  'sidebar.empty',
  'sidebar.loading',
  'sidebar.custom',
  'sidebar.sorted',
  'sidebar.collapsed',
  'sidebar.row-hover',
  'sidebar.sort-menu',
  'menu.channel',
  'menu.channel-muted',
  'menu.dm',
  'menu.agent-dm',
  'menu.section',
  'menu.section-custom',
  'menu.surface',
  'menu.move-to-section',
  'dialog.new-section',
  'dialog.edit-section',
  'dialog.delete-section',
  'dialog.archive-channel',
  'rail.help-menu',
  'server.menu',
];

Map<String, dynamic> _prim(ParityContext ctx) =>
    Map<String, dynamic>.from(_fx(ctx)['primitives'] as Map);

RaftGlyph _glyph(String name) => switch (name) {
  'search' => RaftGlyph.search,
  _ => RaftGlyph.inbox,
};

Widget _confirm(ParityContext ctx) {
  final variant = '${ctx.props['surface']}'.split('.').last;
  final c = Map<String, dynamic>.from(
    (_prim(ctx)['confirms'] as Map)[variant] as Map,
  );
  return RaftConfirmDialog(
    surfaceKey: const ValueKey('shell-dialog'),
    title: c['title'] as String,
    message: c['message'] as String,
    confirmLabel: c['confirmLabel'] as String,
    showCancel: c['hideCancel'] != true,
    confirmVariant: switch (c['variant']) {
      'warning' => RaftButtonRecipeVariant.warning,
      'primary' => RaftButtonRecipeVariant.primary,
      _ => RaftButtonRecipeVariant.danger,
    },
  );
}

Widget _banners(ParityContext ctx) {
  final mobile = ctx.props['platform'] == 'mobile';
  final rows = [
    for (final b in _prim(ctx)['banners'] as List)
      Map<String, dynamic>.from(b as Map),
  ];
  return Align(
    alignment: Alignment.topLeft,
    child: Container(
      key: const ValueKey('shell-banners'),
      width: mobile ? 390 : 480,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, b) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            RaftBanner(
              status: switch (b['intent']) {
                'destructive' => RaftBannerRecipeStatus.destructive,
                'info' => RaftBannerRecipeStatus.info,
                'success' => RaftBannerRecipeStatus.success,
                _ => RaftBannerRecipeStatus.warning,
              },
              size: switch (b['density']) {
                'sm' => RaftBannerRecipeSize.sm,
                'lg' => RaftBannerRecipeSize.lg,
                _ => RaftBannerRecipeSize.md,
              },
              title: b['title'] as String?,
              description: b['text'] as String,
              glyph: b['icon'] == true
                  ? switch (b['intent']) {
                      'destructive' => RaftGlyph.alertTriangle,
                      'info' => RaftGlyph.info,
                      'success' => RaftGlyph.checkCircle2,
                      _ => RaftGlyph.circleAlert,
                    }
                  : null,
              action: b['action'] == null
                  ? null
                  : RaftUnderlinedText(
                      b['action'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _empty(ParityContext ctx) {
  final variant = '${ctx.props['surface']}'.split('.').last;
  final e = Map<String, dynamic>.from(
    (_prim(ctx)['empties'] as Map)[variant] as Map,
  );
  final mobile = ctx.props['platform'] == 'mobile';
  return Align(
    alignment: Alignment.topLeft,
    child: Container(
      key: const ValueKey('shell-empty'),
      width: mobile ? 390 : 480,
      height: 320,
      color: Colors.white,
      child: RaftEmptyState(
        glyph: _glyph(e['icon'] as String),
        title: e['title'] as String,
        detail: (e['description'] as String?) ?? '',
        action: e['action'] == null
            ? null
            : RaftRecipeButton(
                label: e['action'] as String,
                variant: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.sm,
                onPressed: () {},
              ),
      ),
    ),
  );
}

Widget _bottomSheet(ParityContext ctx) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: KeyedSubtree(
      key: const ValueKey('shell-bottom-sheet'),
      child: RaftBottomSheet(
        contentPadding: const EdgeInsets.all(16),
        child: Builder(
          builder: (context) {
            final t = RaftTokens.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add to home screen',
                  style: RaftTypography.heading(
                    t,
                    size: 16,
                    line: 24,
                    weight: FontWeight.w700,
                  ).copyWith(color: t.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Install Raft for faster access and notifications.',
                  style: RaftTypography.heading(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w400,
                  ).copyWith(color: t.muted),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    RaftRecipeButton(
                      label: 'Not now',
                      variant: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    RaftRecipeButton(
                      label: 'Install',
                      variant: RaftButtonRecipeVariant.default_,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

Widget _toast(ParityContext ctx) {
  final variant = '${ctx.props['surface']}'.split('.').last;
  final t = Map<String, dynamic>.from(
    (_prim(ctx)['toasts'] as Map)[variant] as Map,
  );
  return Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: KeyedSubtree(
        key: const ValueKey('shell-toast'),
        child: RaftToast(
          title: t['title'] as String,
          description: t['description'] as String?,
          icon: t['plain'] != true,
          onClose: t['plain'] == true ? null : () {},
          tone: switch (t['kind']) {
            'error' => RaftToastRecipeTone.error,
            'info' => RaftToastRecipeTone.info,
            'warning' => RaftToastRecipeTone.warning,
            _ => RaftToastRecipeTone.success,
          },
        ),
      ),
    ),
  );
}

ParityCase _primitive(Widget Function(ParityContext) build, String widget) =>
    ParityCase(
      widgets: [widget],
      notes: 'Extension suite (not official). Shared UI primitive.',
      build: (ctx) => Material(
        type: MaterialType.transparency,
        child: SizedBox.expand(child: build(ctx)),
      ),
    );

/// Historical shell cases keep 3 themes; Help popup bounds add current Raft
/// light/dark without changing those historical entries.
final Map<String, ParityCase> extShellCases = {
  for (final state in const ['default', 'hover', 'focus'])
    for (final theme in const ['raft', 'raft-dark'])
      'components.shell.desktop.sidebar.sort-popup.$state.$theme':
          _sidebarSortPopupCase,
  for (final state in const ['default', 'hover', 'focus'])
    for (final density in const ['', 'compact-'])
      for (final theme in const ['raft', 'raft-dark'])
        'components.shell.desktop.rail.help-popup.$density$state.$theme':
            _helpPopupCase,
  for (final surface in [..._desktopSurfaces, 'activity.frame'])
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.shell.desktop.$surface.$theme': _desktopCase,
  for (final surface in const [
    'sidebar.default',
    'sidebar.collapsed',
    'menu.channel',
    'sidebar.sort-menu',
    'activity.frame',
  ])
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.shell.mobile.$surface.$theme': _mobileCase,
  for (final platform in const ['desktop', 'mobile']) ...{
    for (final variant in const ['danger', 'warning', 'ack'])
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.shell.$platform.confirm.$variant.$theme': _primitive(
          _confirm,
          'raft_ui:RaftConfirmDialog',
        ),
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.shell.$platform.banner.all.$theme': _primitive(
        _banners,
        'raft_ui:RaftBanner',
      ),
    for (final variant in const ['full', 'title'])
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.shell.$platform.empty.$variant.$theme': _primitive(
          _empty,
          'raft_ui:RaftEmptyState',
        ),
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.shell.$platform.bottomsheet.default.$theme': _primitive(
        _bottomSheet,
        'raft_ui:RaftBottomSheet',
      ),
    for (final variant in const ['success', 'error', 'info', 'plain'])
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.shell.$platform.toast.$variant.$theme': _primitive(
          _toast,
          'raft_ui:RaftToast',
        ),
  },
};
