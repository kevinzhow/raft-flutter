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
    show addTearDown, expect, find, isTrue;
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ext_frame_keys.g.dart';
import 'ext_settings.dart' show extSettingsCases;
import 'ext_shell.dart' show shellWorkspace;
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
  return shellWorkspace(
    ctx,
    selected: selected,
    routes: {
      'GET /agents': ids.agents,
      'GET /servers/visual-server/members': ids.members,
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
    if (widget.ctx.props['scene'] == 'activity') {
      w.setSection('activity');
      return;
    }
    final id = _selected(widget.ctx);
    if (id == null) return;
    final channel = [...w.channels, ...w.dms].firstWhere((c) => c.id == id);
    await w.selectChannel(channel);
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
      Positioned.fill(child: _Host(ctx: ctx)),
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
];

/// Every extension frame case, keyed by id (3 themes each).
final Map<String, ParityCase> extFrameCases = {
  for (final key in _keys)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.frame.$key.$theme': _case,
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
