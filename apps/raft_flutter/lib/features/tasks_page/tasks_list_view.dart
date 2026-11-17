// The Tasks page as a list: 我的 in two sections (分配给你, 你发起的, each its
// title and total), 全部 as one list; rows read a page at a time as the end of
// a list scrolls into view.
//
// Source: Web v1.24 components/task/tasksPage/TasksListView.tsx and
// LoadMoreSentinel.tsx.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import 'tasks_page_model.dart';
import 'tasks_page_rows.dart';
import 'tasks_page_store.dart';
import 'tasks_selection.dart';

/// How far ahead of the end the next page is read.
const loadAheadMargin = 240.0;

/// The groups of lanes the list view shows, top to bottom: 我的's two
/// sections, or 全部's one list. Each group reads and merges as one list.
List<List<LaneSpec>> tasksListGroups(
  TasksPageTab tab,
  PageFilters filters,
  ServerTaskSort sort,
  String doneSince,
) => tab == TasksPageTab.all
    ? [
        [allListLane(filters, sort)],
      ]
    : [
        for (final section in MineSection.values)
          mineSectionLanes(section, filters, sort, doneSince),
      ];

/// The end of a group of the Tasks page: reaching it (scrolled into view,
/// within [loadAheadMargin]) reads the next page. It checks again after every
/// build, so a short page that leaves the end in view reads on; after a failed
/// read it waits for a press instead.
class LoadMoreSentinel extends StatefulWidget {
  const LoadMoreSentinel({
    super.key,
    required this.onLoadMore,
    required this.loading,
    required this.failed,
  });
  final VoidCallback onLoadMore;
  final bool loading, failed;

  @override
  State<LoadMoreSentinel> createState() => _LoadMoreSentinelState();
}

class _LoadMoreSentinelState extends State<LoadMoreSentinel> {
  ScrollPosition? _position;
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next == _position) return;
    _position?.removeListener(_checkAfterLayout);
    _position = next?..addListener(_checkAfterLayout);
  }

  @override
  void dispose() {
    _position?.removeListener(_checkAfterLayout);
    super.dispose();
  }

  /// Whether the end is within the margin of the viewport it scrolls in.
  bool get _near {
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    if (viewport is! RenderBox) return true;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top <= viewport.size.height + loadAheadMargin;
  }

  void _check() {
    if (!mounted || widget.loading || widget.failed) return;
    if (_near) widget.onLoadMore();
  }

  void _checkAfterLayout() {
    if (_checking) return;
    _checking = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checking = false;
      _check();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.failed) {
      return RaftButton(
        key: const ValueKey('tasks-page-more-retry'),
        uiVariant: RaftButtonVariant.outline,
        uiSize: RaftButtonSize.md,
        label: raftText(context, 'Try again'),
        expand: true,
        onPressed: widget.onLoadMore,
      );
    }
    if (!widget.loading) _checkAfterLayout();
    // The end marker takes no room of its own: it only has a place to check.
    return const SizedBox(
      key: ValueKey('tasks-page-more'),
      height: 0,
      width: double.infinity,
    );
  }
}

/// A loading list: the page's box of rows, each the size of a loaded row.
/// The title takes the title group's room; the trailing group (a time, the
/// status) sits at the right.
class TasksRowsSkeleton extends StatelessWidget {
  const TasksRowsSkeleton({super.key, required this.rows});
  final int rows;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final radius = t.size('radius.container', fallback: 10);
    final minHeight = t.desktop ? RaftDesktopMetrics.rowHeight : 44.0;
    return ExcludeSemantics(
      child: DecoratedBox(
        key: const ValueKey('tasks-page-rows-loading'),
        decoration: BoxDecoration(
          color: t.ui.layerCard,
          border: Border.all(color: t.ui.lineHairline),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: Column(
            children: [
              for (var i = 0; i < rows; i++)
                DecoratedBox(
                  key: ValueKey('tasks-page-row-loading-$i'),
                  decoration: BoxDecoration(
                    border: Border(
                      top: i > 0
                          ? BorderSide(color: t.ui.lineHairline)
                          : BorderSide.none,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        (t.desktop ? 8.0 : 12.0) + 20 + 8,
                        6,
                        12,
                        6,
                      ),
                      child: LayoutBuilder(
                        builder: (context, box) => Row(
                          children: [
                            RaftSkeleton(
                              variant: RaftSkeletonVariant.line,
                              width: box.maxWidth * 2 / 3 * .6,
                            ),
                            const Spacer(),
                            const RaftSkeleton(
                              variant: RaftSkeletonVariant.line,
                              width: 80,
                            ),
                            const SizedBox(width: 8),
                            const RaftSkeleton(
                              variant: RaftSkeletonVariant.block,
                              width: 20,
                              height: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 我的 section's heading: its title, then its total once known.
class TasksSectionHeading extends StatelessWidget {
  const TasksSectionHeading({
    super.key,
    required this.section,
    required this.total,
  });
  final MineSection section;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final title = raftText(
      context,
      section == MineSection.assigned ? 'Assigned' : 'Started by you',
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: 8,
          children: [
            Flexible(
              child: Text(
                title,
                style: t.scale(
                  RaftTypeScale.subhead,
                  weight: FontWeight.w700,
                  color: t.ui.foreground,
                ),
              ),
            ),
            if (total != null)
              Text(
                '$total',
                key: ValueKey('tasks-page-section-count-${section.name}'),
                style: t
                    .scale(
                      RaftTypeScale.monoMeta,
                      mono: true,
                      color: t.ui.foregroundHint,
                    )
                    .copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The list while the page's counts load: what the loaded list will be.
/// 我的, its two sections, each its heading (no total yet) over a few rows;
/// 全部, one box of rows.
class TasksListSkeleton extends StatelessWidget {
  const TasksListSkeleton({super.key, required this.tab});
  final TasksPageTab tab;

  @override
  Widget build(BuildContext context) {
    if (tab == TasksPageTab.all) return const TasksRowsSkeleton(rows: 6);
    return Column(
      key: const ValueKey('tasks-page-mine-loading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 36,
      children: [
        for (final section in MineSection.values)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TasksSectionHeading(section: section, total: null),
              const TasksRowsSkeleton(rows: 3),
            ],
          ),
      ],
    );
  }
}

/// The page as a list. 我的: two sections, 分配给你 (no assignee column, it
/// is always the reader) and 你发起的; 全部: one flat list of every task the
/// person can see.
class TasksListView extends StatelessWidget {
  const TasksListView({
    super.key,
    required this.controller,
    required this.store,
    required this.tab,
    required this.filters,
    required this.sort,
    required this.sections,
    required this.doneSince,
    required this.total,
    required this.countCurrent,
    required this.selection,
    required this.order,
    required this.currentTaskId,
    required this.onOpenTask,
  });

  final WorkspaceController controller;
  final TasksPageStore store;
  final TasksPageTab tab;
  final PageFilters filters;
  final ServerTaskSort sort;

  /// 我的: each section's server total.
  final Map<MineSection, int>? sections;

  /// 你发起的 keeps tasks done since this instant.
  final String doneSince;

  /// 全部: the list's server total.
  final int? total;

  /// The numbers are the server's for the live changes so far.
  final bool countCurrent;
  final TaskSelection selection;

  /// The ids on screen, top to bottom (a Shift-click's run).
  final List<String> Function() order;
  final String? currentTaskId;
  final void Function(Map<String, dynamic> task) onOpenTask;

  Widget _rows(List<LaneSpec> lanes, int? count, {required bool assignee}) =>
      TasksLaneRows(
        key: ValueKey(lanes.map((l) => l.key).join(',')),
        controller: controller,
        store: store,
        lanes: lanes,
        total: count,
        countCurrent: countCurrent,
        showAssignee: assignee,
        selection: selection,
        order: order,
        currentTaskId: currentTaskId,
        onOpenTask: onOpenTask,
      );

  @override
  Widget build(BuildContext context) {
    final groups = tasksListGroups(tab, filters, sort, doneSince);
    if (tab == TasksPageTab.all) {
      return Semantics(
        container: true,
        label: raftText(context, 'Every task'),
        child: KeyedSubtree(
          key: const ValueKey('tasks-page-all-list'),
          child: _rows(groups.first, total, assignee: true),
        ),
      );
    }
    return Column(
      key: const ValueKey('tasks-page-mine'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 36,
      children: [
        for (final (i, section) in MineSection.values.indexed)
          KeyedSubtree(
            key: ValueKey('tasks-page-section-${section.name}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TasksSectionHeading(
                  section: section,
                  total: sections?[section],
                ),
                _rows(
                  groups[i],
                  sections?[section],
                  assignee: section != MineSection.assigned,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The rows of one list (one lane, or several merged), read a page at a time:
/// the first when its end comes into view, the next as it scrolls on. Empty,
/// it says so in a word.
class TasksLaneRows extends StatefulWidget {
  const TasksLaneRows({
    super.key,
    required this.controller,
    required this.store,
    required this.lanes,
    required this.total,
    required this.countCurrent,
    required this.showAssignee,
    required this.selection,
    required this.order,
    required this.currentTaskId,
    required this.onOpenTask,
  });
  final WorkspaceController controller;
  final TasksPageStore store;
  final List<LaneSpec> lanes;
  final int? total;
  final bool countCurrent, showAssignee;
  final TaskSelection selection;
  final List<String> Function() order;
  final String? currentTaskId;
  final void Function(Map<String, dynamic> task) onOpenTask;

  @override
  State<TasksLaneRows> createState() => _TasksLaneRowsState();
}

class _TasksLaneRowsState extends State<TasksLaneRows> {
  bool _settling = false;

  /// Reads the lanes need to show the truth (Web useMergedTasksLanes's
  /// effect), after the build: the store notifies as it starts a read.
  void _settleSoon() {
    if (_settling) return;
    _settling = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _settling = false;
      if (!mounted) return;
      widget.store.settleLanes(
        widget.lanes,
        count: widget.countCurrent ? widget.total : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _settleSoon();
    final store = widget.store;
    final view = store.laneView(widget.lanes);
    final total = widget.total;
    if (view.tasks.isNotEmpty) {
      final selection = widget.selection;
      final rows = [
        for (final task in view.tasks)
          tasksPageChipRow(widget.controller, task),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          RaftTaskPageList(
            tasks: rows,
            wrapTitle: true,
            showChannel: true,
            showAssignee: widget.showAssignee,
            showUnassigned: true,
            unassignedLabel: raftTextZh(context, 'Unassigned', '未分配'),
            currentTaskId: widget.currentTaskId,
            onOpen: (row) {
              final task = store.knownById[row.id];
              if (task != null) widget.onOpenTask(task);
            },
            selection: RaftTaskRowSelection(
              selecting: selection.selecting,
              isSelected: selection.isSelected,
              onSelect: (row, {required range}) =>
                  selection.select(row.id, range: range, order: widget.order()),
            ),
          ),
          if (view.hasMore)
            LoadMoreSentinel(
              onLoadMore: () => store.loadMore(widget.lanes),
              loading: view.loading,
              failed: view.failed,
            ),
          if (view.loading) const TasksRowsSkeleton(rows: 2),
        ],
      );
    }
    if ((total == null || total > 0) && !view.loaded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (!view.failed) TasksRowsSkeleton(rows: math.min(total ?? 3, 3)),
          LoadMoreSentinel(
            onLoadMore: () => store.loadMore(widget.lanes),
            loading: view.loading,
            failed: view.failed,
          ),
        ],
      );
    }
    return RaftTaskLaneEmpty(
      key: const ValueKey('tasks-page-list-empty'),
      label: raftText(context, 'No tasks'),
    );
  }
}

/// The ids on screen, top to bottom: each group's merged rows, the first
/// place of a task winning.
List<String> tasksListOrder(TasksPageStore store, List<List<LaneSpec>> groups) {
  final seen = <String>{};
  return [
    for (final group in groups)
      for (final task in store.laneView(group).tasks)
        if (seen.add('${task['id']}')) '${task['id']}',
  ];
}
