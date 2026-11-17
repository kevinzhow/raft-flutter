// The bar over the Tasks page while tasks are selected (the generic selection
// bar): "N selected", Status (set a status), Assignee (assign to someone, or
// clear; with the capability), Follow, Delete (where a selected task is the
// viewer's to delete), More, then x. What doesn't fit gives way (Follow and
// Delete into More, then the labels, then the menus into More). Each action
// calls the per-task API for every selected task the viewer may change that
// way (canApplyBatchAction), skips the rest, then says in a toast what it did
// and how many it skipped; what the server refused stays selected. Delete
// asks first and says there what the server refused.
//
// Source: Web v1.24 components/task/tasksPage/TasksSelectionBar.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import 'tasks_batch.dart';
import 'tasks_page_model.dart';
import 'tasks_page_rows.dart';
import 'tasks_page_toolbar.dart' show TaskIdentityOption, taskIdentityOptions;
import '../sender_avatar_projection.dart';

/// Runs an action on the selected tasks, one batch at a time; null when one
/// runs already or nothing is selected.
typedef RunTasksBatch = Future<BatchOutcome?> Function(BatchAction action);

class TasksSelectionBar extends StatefulWidget {
  const TasksSelectionBar({
    super.key,
    required this.controller,
    required this.tasks,
    required this.runBatch,
    required this.onClear,
    required this.onGone,
  });

  final WorkspaceController controller;

  /// The selected tasks still in the page's lists.
  final List<Map<String, dynamic>> tasks;
  final RunTasksBatch runBatch;
  final VoidCallback onClear;

  /// The bar went (Esc, x, an action done) while focus was in it, or lost:
  /// focus goes back to the list.
  final VoidCallback onGone;

  @override
  State<TasksSelectionBar> createState() => _TasksSelectionBarState();
}

class _TasksSelectionBarState extends State<TasksSelectionBar> {
  final _scope = FocusNode(
    debugLabel: 'tasks selection bar',
    canRequestFocus: false,
    skipTraversal: true,
  );
  bool _busy = false;
  bool _confirming = false;

  @override
  void dispose() {
    // Before the bar leaves the page: focus in it (or in its delete
    // confirmation, or lost to the page's body) goes back to the list.
    final primary = FocusManager.instance.primaryFocus;
    if (_scope.hasFocus ||
        _confirming ||
        primary == null ||
        primary == FocusManager.instance.rootScope) {
      widget.onGone();
    }
    _scope.dispose();
    super.dispose();
  }

  void _toast(String text, {required bool error}) {
    if (!mounted) return;
    showRaftToast(
      context,
      text,
      tone: error ? RaftToastRecipeTone.error : RaftToastRecipeTone.info,
    );
  }

  Future<void> _run(
    BatchAction action,
    String Function(BatchOutcome outcome) describe,
  ) async {
    setState(() => _busy = true);
    try {
      final outcome = await widget.runBatch(action);
      if (outcome == null || !mounted) return;
      _toast(describe(outcome), error: outcome.done == 0);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setStatus(String status) {
    final label = raftText(context, raftTaskStatusLabel(status));
    unawaited(
      _run(
        BatchStatus(status),
        (o) =>
            tasksPlural(
              context,
              o.done,
              'Moved {count} task to {status}',
              'Moved {count} tasks to {status}',
              {'status': label},
            ) +
            tasksSkipped(context, o.skipped),
      ),
    );
  }

  void _assign(TaskAssigneeRef? assignee, String name) {
    unawaited(
      _run(
        BatchAssignee(assignee),
        (o) =>
            (assignee == null
                ? tasksPlural(
                    context,
                    o.done,
                    'Cleared the assignee of {count} task',
                    'Cleared the assignee of {count} tasks',
                  )
                : tasksPlural(
                    context,
                    o.done,
                    'Assigned {count} task to {name}',
                    'Assigned {count} tasks to {name}',
                    {'name': name},
                  )) +
            tasksSkipped(context, o.skipped),
      ),
    );
  }

  void _follow() => unawaited(
    _run(
      const BatchFollow(),
      (o) =>
          tasksPlural(
            context,
            o.done,
            'Following {count} task',
            'Following {count} tasks',
          ) +
          tasksSkipped(context, o.skipped),
    ),
  );

  /// Delete waits in its confirmation (the red button busy) and closes it once
  /// every task it may delete is gone. What the server refused stays selected
  /// and is said in the dialog, to try again.
  Future<String?> _delete(BuildContext dialog) async {
    setState(() => _busy = true);
    try {
      final outcome = await widget.runBatch(const BatchDelete());
      if (outcome == null || !mounted || !dialog.mounted) return null;
      if (outcome.failedIds.isNotEmpty) {
        return tasksPlural(
          context,
          outcome.failedIds.length,
          "{count} task wasn't deleted. Try again.",
          "{count} tasks weren't deleted. Try again.",
        );
      }
      Navigator.of(dialog).pop();
      _toast(
        tasksPlural(
              context,
              outcome.done,
              'Deleted {count} task',
              'Deleted {count} tasks',
            ) +
            tasksSkipped(context, outcome.skipped),
        error: false,
      );
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askDelete() async {
    final count = widget.tasks.length;
    setState(() => _confirming = true);
    try {
      await showRaftDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => RaftTaskDeleteConfirmDialog(
          taskNumber: 0,
          count: count,
          title: tasksPlural(
            context,
            count,
            'Delete {count} task?',
            'Delete {count} tasks?',
          ),
          confirmLabel: tasksPlural(
            context,
            count,
            'Delete {count} task',
            'Delete {count} tasks',
          ),
          onCancel: () => Navigator.of(dialog).pop(),
          onConfirm: () => _delete(dialog),
        ),
      );
    } finally {
      _confirming = false;
    }
  }

  Widget _assigneePicker(BuildContext context, VoidCallback close) =>
      _AssigneePicker(
        controller: widget.controller,
        onPick: (assignee, name) {
          close();
          _assign(assignee, name);
        },
      );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final w = widget.controller;
    final viewer = BatchViewer.of(w);
    final canDelete = widget.tasks.any(
      (task) => canApplyBatchAction(const BatchDelete(), task, viewer),
    );
    final statusEntries = [
      for (final status in boardStatuses)
        RaftMenuEntry(
          label: raftText(context, raftTaskStatusLabel(status)),
          leading: RaftMessageTaskStatusIcon(
            status: raftTaskStatusOf(status),
            color: t.ui.foreground,
          ),
          onPressed: _busy ? null : () => _setStatus(status),
        ),
    ];
    final people = taskIdentityOptions(w);
    final me = w.client.user?.id;
    final assignMoreEntries = [
      if (me != null)
        RaftMenuEntry(
          label: raftText(context, 'Me'),
          onPressed: _busy
              ? null
              : () => _assign(
                  TaskAssigneeRef('user', me),
                  raftText(context, 'you'),
                ),
        ),
      RaftMenuEntry(
        label: raftTextZh(context, 'Unassigned', '未分配'),
        onPressed: _busy
            ? null
            : () => _assign(null, raftTextZh(context, 'Unassigned', '未分配')),
      ),
      for (final person in people)
        if (person.id != me || person.type != 'user')
          RaftMenuEntry(
            label: person.label,
            onPressed: _busy
                ? null
                : () => _assign(
                    TaskAssigneeRef(person.type, person.id),
                    person.label,
                  ),
          ),
    ];
    final bar = RaftSelectionBar(
      count: widget.tasks.length,
      semanticLabel: raftText(context, 'Selected tasks'),
      clearLabel: raftText(context, 'Clear selection (Esc)'),
      moreLabel: raftText(context, 'More'),
      onClear: widget.onClear,
      actions: [
        RaftSelectionBarAction(
          id: 'status',
          label: raftText(context, 'Status'),
          glyph: RaftGlyph.circleDot,
          enabled: !_busy,
          menuEntries: statusEntries,
        ),
        if (viewer.canAssign)
          RaftSelectionBarAction(
            id: 'assignee',
            label: raftText(context, 'Assignee'),
            glyph: RaftGlyph.user,
            enabled: !_busy,
            popover: _assigneePicker,
            moreEntries: assignMoreEntries,
          ),
        RaftSelectionBarAction(
          id: 'follow',
          label: raftText(context, 'Follow'),
          glyph: RaftGlyph.followThread,
          secondary: true,
          enabled: !_busy,
          onPressed: _follow,
        ),
        if (canDelete)
          RaftSelectionBarAction(
            id: 'delete',
            label: raftText(context, 'Delete'),
            glyph: RaftGlyph.trash2,
            secondary: true,
            enabled: !_busy,
            onPressed: () => unawaited(_askDelete()),
          ),
      ],
    );
    return Focus(
      focusNode: _scope,
      child: KeyedSubtree(
        key: const ValueKey('tasks-page-selection-bar'),
        child: bar,
      ),
    );
  }
}

/// The searchable assignee picker (Web SelectionPopover over the identity
/// options): me, nobody, then everyone the filters list, filtered by what is
/// typed. A fresh one each time it opens.
class _AssigneePicker extends StatefulWidget {
  const _AssigneePicker({required this.controller, required this.onPick});
  final WorkspaceController controller;
  final void Function(TaskAssigneeRef? assignee, String name) onPick;

  @override
  State<_AssigneePicker> createState() => _AssigneePickerState();
}

class _AssigneePickerState extends State<_AssigneePicker> {
  final _search = TextEditingController();
  String _needle = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.controller;
    final me = w.client.user?.id;
    final needle = _needle;
    final people = [
      for (final option in taskIdentityOptions(w))
        if (!(option.type == 'user' && option.id == me) &&
            (needle.isEmpty ||
                option.label.toLowerCase().contains(needle) ||
                option.handle.toLowerCase().contains(needle)))
          option,
    ];
    final youLabel = raftText(context, 'Me');
    final noneLabel = raftTextZh(context, 'Unassigned', '未分配');
    final avatars = projectTaskFilterAvatars(
      origin: w.client.origin,
      identityKeys: [for (final p in people) p.key],
      agents: w.services.entityDirectory.authorAgents,
      members: w.services.entityDirectory.authorMembers,
      currentUser: w.client.user?.json,
    );
    Widget avatar(TaskIdentityOption option) {
      final projection = avatars[option.key];
      final agent = option.type == 'agent';
      if (projection == null) {
        return RaftSelectionPopoverAvatarSlot(name: option.label, agent: agent);
      }
      return RaftAvatar(
        name: option.label,
        kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
        mountedContext: RaftMountedAvatarContext.compactList,
        content: RaftAvatarContent(
          name: option.label,
          kind: agent
              ? RaftAvatarContentKind.agent
              : RaftAvatarContentKind.human,
          uploadedUrl: projection.uploadedUrl,
          pixelKey: projection.pixelKey,
        ),
      );
    }

    return RaftSelectionPopover(
      key: const ValueKey('tasks-batch-assignee-popover'),
      width: 256,
      title: raftText(context, 'Assign to'),
      searchController: _search,
      searchPlaceholder: raftText(context, 'Search…'),
      emptyLabel: raftText(context, 'No results'),
      onSearchChanged: (value) =>
          setState(() => _needle = value.trim().toLowerCase()),
      options: [
        if (me != null &&
            (needle.isEmpty || youLabel.toLowerCase().contains(needle)))
          RaftSelectionOption(
            rowKey: const ValueKey('tasks-batch-assignee-me'),
            label: youLabel,
            checked: false,
            italic: true,
            reserveLeadingSlot: true,
            onTap: () => widget.onPick(
              TaskAssigneeRef('user', me),
              raftText(context, 'you'),
            ),
          ),
        if (needle.isEmpty || noneLabel.toLowerCase().contains(needle))
          RaftSelectionOption(
            rowKey: const ValueKey('tasks-batch-assignee-none'),
            label: noneLabel,
            checked: false,
            italic: true,
            reserveLeadingSlot: true,
            onTap: () => widget.onPick(null, noneLabel),
          ),
        for (final option in people)
          RaftSelectionOption(
            rowKey: ValueKey('tasks-batch-assignee-${option.key}'),
            label: option.label,
            checked: false,
            reserveLeadingSlot: true,
            leading: avatar(option),
            onTap: () => widget.onPick(
              TaskAssigneeRef(option.type, option.id),
              option.label,
            ),
          ),
      ],
    );
  }
}
