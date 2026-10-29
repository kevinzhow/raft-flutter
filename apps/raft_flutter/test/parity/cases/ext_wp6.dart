// raft-flutter parity EXTENSION suite builders (tool/parity-ext): work package
// 6, task and settings leftovers. NOT official cases; ids are
// `components.wp6.<surface>.<state>.<theme>`, dispatched on props.surface like
// tool/parity-ext/host/Wp6Cases.tsx.
//
// Data: tool/parity-ext/fixtures/wp6.json (fixtures['ext:wp6']).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ext_settings.dart';
import 'ext_task_detail.dart';
import 'thread_composer/fake_workspace.dart' show ParityFakeClient;

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:wp6'] as Map<String, dynamic>;

// ----------------------------------------------------------------- tasks

Widget _tasksCreate(ParityContext ctx) {
  final w = extTaskWorkspace(ctx);
  ctx.onDispose(() {
    w.dispose();
    unawaited((w.client as ParityFakeClient).stream.close());
  });
  return Align(
    alignment: Alignment.topLeft,
    child: ctx.target(
      SizedBox(
        width: ctx.width,
        height: ctx.height,
        child: Material(
          type: MaterialType.transparency,
          child: CreateTaskDialog(controller: w, channelId: 'channel-design'),
        ),
      ),
    ),
  );
}

Widget _tasksFilter(ParityContext ctx) {
  final counts = Map<String, dynamic>.from(_fx(ctx)['filterCounts'] as Map);
  final value = ctx.props['state'] == 'selected' ? 'in_progress' : 'all';
  return Builder(
    builder: (context) {
      final t = RaftTokens.of(context);
      return Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: ctx.width,
          height: 200,
          child: Material(
            color: t.colors['layer-canvas-muted'],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: RaftTaskFilterControl(
                  key: const ValueKey('task-filter'),
                  value: value,
                  counts: {
                    for (final e in counts.entries)
                      e.key: (e.value as num).toInt(),
                  },
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _tasksBoard(ParityContext ctx) => extTaskPageBuild(
  ctx,
  board: List<dynamic>.from(
    (_fx(ctx)['boards'] as Map)[ctx.props['state']] as List,
  ),
);

final ParityCase _tasksCase = ParityCase(
  widgets: const [
    'raft_flutter:CreateTaskDialog',
    'raft_ui:RaftCreateTaskDialogView',
  ],
  notes: 'Extension suite (not official). WP6 tasks.',
  settle: const Duration(milliseconds: 1500),
  build: (ctx) => switch (ctx.props['surface']) {
    'tasks-create' => _tasksCreate(ctx),
    'tasks-filter' => _tasksFilter(ctx),
    _ => _tasksBoard(ctx),
  },
);

/// Every WP6 case, keyed by id (3 themes each), generated from the manifest
/// keys below.
const _taskKeys = [
  'tasks.create-dialog',
  'tasks.create-dialog-filled',
  'tasks.create-dialog-batch',
  'tasks.create-dialog-error',
  'tasks.create-dialog-mobile',
  'tasks.create-dialog-filled-mobile',
  'tasks.create-dialog-batch-mobile',
  'tasks.create-dialog-error-mobile',
  'tasks.filter',
  'tasks.filter-selected',
  'tasks.filter-mobile',
  'tasks.filter-selected-mobile',
  'tasks.empty-lanes',
  'tasks.empty-lanes-expanded',
  'tasks.empty-lanes-mobile',
];

final ParityCase _settingsCase = ParityCase(
  widgets: const ['raft_flutter:WorkspaceSettings'],
  notes: 'Extension suite (not official). WP6 settings.',
  settle: const Duration(milliseconds: 800),
  build: extSettingsPage,
);

const _settingsKeys = [
  'settings.language',
  'settings.language-off',
  'settings.language-manual',
  'settings.language-provider-missing',
  'settings.language-server-off',
  'settings.language-mobile',
  'settings.language-off-mobile',
  'settings.usage-data',
  'settings.usage-data-mobile',
  'settings.provider-edit',
  'settings.provider-edit-preset',
  'settings.provider-edit-error',
  'settings.provider-edit-mobile',
  'settings.provider-edit-preset-mobile',
  'settings.bridge-connect',
  'settings.bridge-oauth',
  'settings.bridge-channels',
  'settings.bridge-channels-pairs',
  'settings.bridge-preflight',
  'settings.bridge-enable',
  'settings.bridge-health',
  'settings.bridge-health-recovery',
  'settings.bridge-health-unverified',
  'settings.bridge-connect-mobile',
  'settings.bridge-channels-pairs-mobile',
  'settings.bridge-preflight-mobile',
  'settings.bridge-health-recovery-mobile',
  'settings.bridge-health-readonly',
  'settings.bridge-manage',
  'settings.bridge-disconnect',
  'settings.bridge-error',
  'settings.feedback-mobile',
  'settings.feedback-new-mobile',
  'settings.feedback-ticket-mobile',
];

final Map<String, ParityCase> extWp6Cases = {
  for (final theme in const ['brutal', 'elegant', 'elegant-dark']) ...{
    for (final key in _taskKeys) 'components.wp6.$key.$theme': _tasksCase,
    for (final key in _settingsKeys)
      'components.wp6.$key.$theme': _settingsCase,
  },
};
