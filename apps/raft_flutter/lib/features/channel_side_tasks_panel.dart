// The body of a channel's Tasks card, beside the conversation (task v2, Web
// v1.24 components/task/ChannelTasksPanel.tsx): the All / For me filter with
// the number of active tasks, then the tasks in status lanes (the work that is
// moving first) as one-line rows with their assignee. A row opens the task in
// its own dialog; the card's head owns the title, "+ New task" and Close.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'composer_task_mode.dart';

import '../data/message_task_cache.dart';
import '../data/workspace_controller.dart';
import 'create_task_dialog.dart';
import 'message_task_actions.dart' show TaskV2ConversationsFlag;
import 'channel_side_store.dart' show ChannelTasksFilter;
import 'message_task_list.dart' show messageTaskChipRow;

/// Work that is moving first (In Progress, In Review), then what waits (Todo,
/// Backlog), then what is over. Web STATUS_ORDER.
const channelTasksStatusOrder = [
  'in_progress',
  'in_review',
  'todo',
  'backlog',
  'done',
  'closed',
];

/// The statuses the filter counts (Web ACTIVE_STATUSES).
const channelTasksActiveStatuses = {'todo', 'in_progress', 'in_review'};

/// Backlog, Done and Closed start folded (Web INITIALLY_COLLAPSED).
const channelTasksInitiallyFolded = {'backlog', 'done', 'closed'};

/// Web `isTaskOnViewer`: claimed by the reader as a person (an agent that
/// happens to share the id is not them).
bool channelTaskIsOnViewer(Map<String, dynamic> task, String? viewerId) =>
    viewerId != null &&
    viewerId.isNotEmpty &&
    task['claimedByType'] == 'user' &&
    task['claimedById'] == viewerId;

/// "+ New task" (Web ChannelTasksPanel `openCreate`): with task v2, not
/// [covering] the conversation and a composer of the channel mounted, "As
/// task" turns on there; otherwise the New task dialog opens. No request is
/// made here: the dialog's own submit creates the task, and the task event
/// puts it in the card.
void openChannelTaskCreate(
  BuildContext context, {
  required WorkspaceController controller,
  required String channelId,
  required bool covering,
}) {
  final taskV2 = TaskV2ConversationsFlag.of(controller).enabled;
  if (taskV2 && !covering && ComposerTaskModeTargets.request(channelId)) {
    return;
  }
  unawaited(
    CreateTaskDialog.show(
      context,
      controller: controller,
      channelId: channelId,
    ),
  );
}

/// The Tasks card's body. The tasks are the channel's task bucket the chat
/// already loads (MessageTaskCache, Web `selectChannelTaskBucket`), kept live
/// by task events; the panel reads it and, when nobody has yet, starts the one
/// read of it ([MessageTaskCache.warm]: a fresh or in-flight bucket is not
/// requested again).
class ChannelSideTasksPanel extends StatefulWidget {
  const ChannelSideTasksPanel({
    super.key,
    required this.controller,
    required this.channelId,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenTask,
    required this.covering,
  });
  final WorkspaceController controller;
  final String channelId;
  final ChannelTasksFilter filter;
  final ValueChanged<ChannelTasksFilter> onFilterChanged;

  /// Opens the task in its dialog (Web `useOpenTask`).
  final void Function(Map<String, dynamic> task) onOpenTask;

  /// The card covers the conversation (a phone): "+" cannot reach a composer.
  final bool covering;

  @override
  State<ChannelSideTasksPanel> createState() => _ChannelSideTasksPanelState();
}

class _ChannelSideTasksPanelState extends State<ChannelSideTasksPanel> {
  WorkspaceController get w => widget.controller;
  late final MessageTaskCache cache = MessageTaskCache.of(w.client);
  late final Listenable changes = Listenable.merge([cache, w]);

  /// Lanes the person folded or unfolded; the others keep their initial fold.
  final folded = {...channelTasksInitiallyFolded};

  @override
  void initState() {
    super.initState();
    unawaited(cache.warm(w, widget.channelId));
  }

  @override
  void didUpdateWidget(ChannelSideTasksPanel old) {
    super.didUpdateWidget(old);
    if (old.channelId != widget.channelId) {
      unawaited(cache.warm(w, widget.channelId));
    }
  }

  void toggle(String status) => setState(() {
    if (!folded.remove(status)) folded.add(status);
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: changes,
    builder: (context, _) {
      final bucket = cache.tasks(w, widget.channelId);
      final all = [...?bucket?.values];
      final viewer = w.client.user?.id;
      final mine = [
        for (final task in all)
          if (channelTaskIsOnViewer(task, viewer)) task,
      ];
      bool active(Map<String, dynamic> task) =>
          channelTasksActiveStatuses.contains(task['status']);
      final activeAll = all.where(active).length;
      final activeMine = mine.where(active).length;
      final visible = widget.filter == ChannelTasksFilter.mine ? mine : all;
      final groups = <({String status, List<Map<String, dynamic>> tasks})>[
        for (final status in channelTasksStatusOrder)
          (
            status: status,
            tasks:
                [
                  for (final task in visible)
                    if (task['status'] == status) task,
                ]..sort(
                  (a, b) => (b['taskNumber'] as int).compareTo(
                    a['taskNumber'] as int,
                  ),
                ),
          ),
      ].where((group) => group.tasks.isNotEmpty).toList();
      final mineFilter = widget.filter == ChannelTasksFilter.mine;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            filter: widget.filter,
            activeAll: activeAll,
            activeMine: activeMine,
            onChanged: widget.onFilterChanged,
          ),
          Expanded(
            child: visible.isEmpty && bucket != null
                ? Center(
                    child: SingleChildScrollView(
                      child: RaftEmptyState(
                        glyph: RaftGlyph.listTodo,
                        title: raftText(
                          context,
                          mineFilter
                              ? 'Nothing is waiting on you'
                              : 'No tasks yet',
                        ),
                        detail: raftText(
                          context,
                          mineFilter
                              ? 'Tasks assigned to you in this channel show up here.'
                              : 'Tasks that people and agents create in this channel show up here.',
                        ),
                      ),
                    ),
                  )
                : ListView(
                    primary: false,
                    padding: raftScrollPadding(
                      context,
                      const EdgeInsets.only(bottom: 16),
                    ),
                    children: [
                      for (var i = 0; i < groups.length; i++)
                        _Lane(
                          key: ValueKey(
                            'channel-tasks-lane-${groups[i].status}',
                          ),
                          status: groups[i].status,
                          first: i == 0,
                          folded: folded.contains(groups[i].status),
                          onToggle: () => toggle(groups[i].status),
                          tasks: groups[i].tasks,
                          rows: [
                            for (final task in groups[i].tasks)
                              messageTaskChipRow(w, task),
                          ],
                          onOpen: widget.onOpenTask,
                        ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

/// Web `TasksPanelToolbar` with its one segmented control: 20px in (16 on a
/// phone), 12px above and below by touch; with a mouse the tasks start 8px
/// under it (the first lane heading supplies them).
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.activeAll,
    required this.activeMine,
    required this.onChanged,
  });
  final ChannelTasksFilter filter;
  final int activeAll, activeMine;
  final ValueChanged<ChannelTasksFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final inset = RaftTaskCardList.insetOf(context);
    final touch = RaftInteraction.of(context).touch;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 12, inset, touch ? 12 : 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: RaftSegmentedControl<ChannelTasksFilter>(
          value: filter,
          label: raftText(
            context,
            'Show all tasks or only tasks assigned to you',
          ),
          onChanged: onChanged,
          items: [
            RaftSegmentedOption(
              value: ChannelTasksFilter.all,
              label: 'All',
              count: activeAll > 0 ? '$activeAll' : null,
              itemKey: const ValueKey('channel-tasks-filter-all'),
            ),
            RaftSegmentedOption(
              value: ChannelTasksFilter.mine,
              label: 'For me',
              count: activeMine > 0 ? '$activeMine' : null,
              itemKey: const ValueKey('channel-tasks-filter-mine'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web `CompactStatusGroup`: the heading (the status's mark, its name, how
/// many, a chevron) over the rows, unless folded. The heading is a label over
/// its rows, not a row: hover darkens its words and lays no fill.
class _Lane extends StatelessWidget {
  const _Lane({
    super.key,
    required this.status,
    required this.first,
    required this.folded,
    required this.onToggle,
    required this.tasks,
    required this.rows,
    required this.onOpen,
  });
  final String status;
  final bool first;
  final bool folded;
  final VoidCallback onToggle;

  /// The lane's tasks, and the same as rows (by index).
  final List<Map<String, dynamic>> tasks;
  final List<RaftTaskChipRow> rows;
  final void Function(Map<String, dynamic> task) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final inset = RaftTaskCardList.insetOf(context);
    final fine = !RaftInteraction.of(context).touch;
    final label = raftText(context, raftTaskStatusLabel(status));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftInteractive(
          key: ValueKey('channel-tasks-group-$status'),
          onPressed: onToggle,
          semanticLabel: raftFormat(
            context,
            folded ? 'Show {status}' : 'Hide {status}',
            {'status': label},
          ),
          checked: null,
          builder: (context, state) {
            final ink = state.hovered ? t.ui.foreground : t.ui.foregroundMuted;
            return ExcludeSemantics(
              child: ConstrainedBox(
                // A 40px box, the words 6px above its bottom: 16px of room
                // above them; with a mouse the first heading is 7px under the
                // filter. A minimum, so larger text grows it.
                constraints: BoxConstraints(minHeight: first && fine ? 0 : 40),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    first && fine ? 8 : 16,
                    inset,
                    6,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        RaftMessageTaskStatusIcon(
                          status: raftTaskStatusOf(status),
                          color: RaftMessageTaskChipRecipe(
                            t,
                            raftTaskStatusOf(status),
                          ).iconForeground,
                          size: 10,
                        ),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.scale(RaftTypeScale.footnote, color: ink),
                          ),
                        ),
                        Text(
                          '${tasks.length}',
                          style: t.scale(
                            RaftTypeScale.monoMeta,
                            mono: true,
                            color: t.ui.foregroundHint,
                          ),
                        ),
                        RaftIcon(
                          folded
                              ? RaftGlyph.chevronRight
                              : RaftGlyph.chevronDown,
                          size: 14,
                          color: state.hovered
                              ? t.ui.foreground
                              : t.ui.foregroundHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (!folded)
          RaftTaskCardList(
            tasks: rows,
            onOpen: (row) {
              final task = tasks.where((task) => task['id'] == row.id);
              if (task.isNotEmpty) onOpen(task.first);
            },
          ),
      ],
    );
  }
}
