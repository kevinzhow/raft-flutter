import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'control_typography.dart';
import 'localization.dart';

import 'theme.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'inline_badge_editor.dart';
import 'recipe_surface.dart';
import 'mounted_task_chip.dart';
import 'task_status_badge.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'tokens/tokens.dart';
import '../recipes.dart';

/// The board lanes of a pre-v2 task list (Web v1.21.23 STATUS_ORDER).
const raftTaskStatuses = ['todo', 'in_progress', 'in_review', 'done', 'closed'];

/// Every status a task can have (shared TASK_STATUSES, Web v1.24): task v2
/// adds `backlog` ("not now"), which a pre-v2 list never offers but must
/// still show when a task is in it.
const raftTaskStatusVocabulary = ['backlog', ...raftTaskStatuses];

/// The statuses a new task can start in (shared TASK_CREATE_STATUSES).
const raftTaskCreateStatuses = ['backlog', 'todo', 'in_progress'];
const raftTaskTransitions = <String, List<String>>{
  'todo': ['in_progress', 'closed'],
  'in_progress': ['in_review', 'done', 'closed'],
  'in_review': ['done', 'in_progress', 'closed'],
  'done': ['todo', 'in_progress', 'in_review', 'closed'],
  'closed': ['todo', 'in_progress'],
};
String raftTaskStatusLabel(String status) => switch (status) {
  'backlog' => 'Backlog',
  'todo' => 'Todo',
  'in_progress' => 'In progress',
  'in_review' => 'In review',
  'done' => 'Done',
  'closed' => 'Closed',
  _ => status,
};

/// Hit target of the status badge: the chip's own height, or the touch target
/// in touch density.
@immutable
class RaftTaskBadgeRecipe {
  const RaftTaskBadgeRecipe(this.tokens);
  final RaftTokens tokens;
  double get height =>
      RaftMessageTaskChipRecipe(tokens, RaftMessageTaskStatus.todo).chipHeight;
  BoxConstraints target(RaftDensity density) => BoxConstraints(
    minWidth: density == RaftDensity.touch ? RaftMetrics.touchTarget : 0,
    minHeight: density == RaftDensity.touch ? RaftMetrics.touchTarget : height,
  );
}

/// Web `StatusBadge` (a raft-ui `TaskStatusBadge`): the status icon and label on
/// the `task-status-*` tokens, the same chip a message row shows.
class RaftTaskStatus extends StatelessWidget {
  const RaftTaskStatus({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => RaftTaskStatusBadge(
    status: raftTaskStatusOf(status),
    label: raftText(context, raftTaskStatusLabel(status)),
  );
}

/// TaskCard's status control: InlineBadgeEditor with the task status options
/// (`dropdownMinWidth="min-w-[140px]"`).
class RaftTaskStatusEditor extends StatelessWidget {
  const RaftTaskStatusEditor({
    super.key,
    required this.status,
    required this.options,
    required this.onSelect,
    this.open,
    this.onOpenChanged,
    this.alignRight = true,
  });
  final String status;
  final List<String> options;
  final ValueChanged<String> onSelect;
  final bool? open;
  final ValueChanged<bool>? onOpenChanged;
  final bool alignRight;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final editor = RaftInlineBadgeEditor(
      label: raftText(context, raftTaskStatusLabel(status)),
      // The badge reads its status; a "Task status" tooltip adds nothing.
      selectedId: status,
      options: [
        for (final s in options)
          RaftInlineBadgeOption(
            id: s,
            label: raftText(
              context,
              status == 'closed' && s == 'todo'
                  ? 'Reopen to Todo'
                  : raftTaskStatusLabel(s),
            ),
          ),
      ],
      onSelect: onSelect,
      taskStatus: raftTaskStatusOf(status),
      open: open,
      onOpenChanged: onOpenChanged,
      alignRight: alignRight,
    );
    final target = RaftTaskBadgeRecipe(t).target(RaftDensityScope.of(context));
    return RaftTouchTargetExpander(
      minSize: Size(target.minWidth, target.minHeight),
      child: editor,
    );
  }
}

/// raft-ui TaskCard (taskCard recipe) as composed by the product TaskCard
/// (packages/web/src/components/task/TaskCard.tsx): meta row, title,
/// description, then `mt-2 flex items-center gap-2` with the status editor at
/// the start (v1.21.23; its menu opens left-aligned).
class RaftTaskCard extends StatelessWidget {
  const RaftTaskCard({
    super.key,
    required this.title,
    required this.number,
    required this.status,
    this.channel = '',
    this.description = '',
    this.assignee,
    this.legacy = false,
    this.onTap,
    this.onStatus,
    this.statusOptions = const [],
  });
  final String title, number, status, channel, description;

  /// A pre-thread task: TaskCardLegacy badge after the number.
  final bool legacy;
  final String? assignee;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatus;
  final List<String> statusOptions;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final r = RaftTaskCardRecipe.resolve(
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    );
    TextStyle text(RaftSlotStyle slot, {double? line}) {
      final base = raftCssText
          .merge(DefaultTextStyle.of(context).style)
          .merge(slot.textStyle(rt));
      final size = base.fontSize ?? 16;
      return base.copyWith(
        fontFamily: base.fontFamily ?? t.bodyFont,
        fontFamilyFallback: base.fontFamilyFallback ?? const ['sans-serif'],
        fontSize: size,
        // Unset line-height inherits the document `line-height: 1.5`.
        height: base.height ?? line ?? 1.5,
        color: base.color ?? t.strong,
      );
    }

    final document = raftCssText
        .merge(DefaultTextStyle.of(context).style)
        .copyWith(fontSize: 16, height: 1.5);
    final plain = t.option('listGroup.frame', or: 'framed') == 'plain';
    final editable = onStatus != null && statusOptions.isNotEmpty;
    return Semantics(
      button: onTap != null,
      label: 'Open task #$number: $title',
      onTap: onTap,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        padding: r.root.padding,
        // `border-[0.5px]` resolves to the used 1px border box.
        decoration: plain
            ? BoxDecoration(
                color: t.ui.layerCard,
                border: Border.all(color: t.ui.lineHairline),
                borderRadius: BorderRadius.circular(
                  t.size('radius.container', fallback: 10),
                ),
              )
            : r.root.withCssUsedBorderWidths().decoration(rt),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftInlineLineBox(
              style: document,
              // Web TaskCard's open button (`inline-block w-full rounded-control
              // focus-visible:shadow-focus`): a Tab stop that Enter or Space
              // opens. The card-level Semantics above exposes the open action.
              child: _TaskPressable(
                onPressed: onTap,
                radius: BorderRadius.circular(
                  t.size('radius.control', fallback: 8),
                ),
                builder: (_) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: plain
                          ? const EdgeInsets.only(bottom: 8)
                          : r.meta.margin,
                      child: _TaskMetaBaseline(
                        child: Row(
                          spacing: r.meta.columnGap ?? 8,
                          children: [
                            if (channel.isNotEmpty)
                              Flexible(
                                child: RaftCssText(
                                  '#$channel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: plain
                                      ? t.scale(
                                          RaftTypeScale.monoMeta,
                                          mono: true,
                                          color: t.ui.foregroundHint,
                                        )
                                      : text(r.channel),
                                ),
                              ),
                            RaftCssText(
                              '#$number',
                              style: plain
                                  ? t.scale(
                                      RaftTypeScale.monoMeta,
                                      mono: true,
                                      color: t.ui.foregroundHint,
                                    )
                                  : text(r.number),
                            ),
                            if (legacy)
                              RaftCssText(
                                raftText(context, 'Legacy'),
                                style: text(r.legacy),
                              ),
                          ],
                        ),
                      ),
                    ),
                    RaftCssText(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: plain
                          ? t.scale(RaftTypeScale.body, weight: FontWeight.w600)
                          : text(r.title),
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: r.description.margin,
                        child: RaftCssText(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: plain
                              ? t.scale(
                                  RaftTypeScale.callout,
                                  color: t.ui.foregroundMuted,
                                )
                              : text(r.description),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8), // mt-2
              child: Align(
                alignment: Alignment.centerLeft,
                // The badge is inline content of a block wrapper: it sits on
                // the line box of the inherited document text (16px / 1.5).
                child: RaftInlineLineBox(
                  style: document,
                  child: editable
                      ? RaftTaskStatusEditor(
                          status: status,
                          options: statusOptions,
                          onSelect: onStatus!,
                          alignRight: false,
                        )
                      : RaftTaskStatus(status: status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TaskCardMeta is an `items-center` flex row. CSS takes its first item's
// baseline; RenderFlex instead takes the smallest baseline among its items.
// The channel's 16px line and number's 16.5px line expose that difference.
class _TaskMetaBaseline extends SingleChildRenderObjectWidget {
  const _TaskMetaBaseline({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTaskMetaBaseline();
}

class _RenderTaskMetaBaseline extends RenderProxyBox {
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final row = child as RenderFlex;
    final first = row.firstChild;
    if (first == null) return null;
    final distance = first.getDistanceToActualBaseline(baseline);
    final offset = (first.parentData! as FlexParentData).offset.dy;
    return distance == null ? null : offset + distance;
  }
}

/// raft-ui TaskSection (taskListSection recipe) as TasksPanel's list view
/// composes it (packages/web/src/components/task/TasksPanel.tsx TaskSection):
/// trigger row with TaskSectionBadge + TaskSectionCount, then the cards
/// (`space-y-2.5`, VirtualizedTaskStack gap 10). TaskSectionChevron is
/// rendered without children by the product, so no glyph is drawn.
class RaftTaskSection extends StatelessWidget {
  const RaftTaskSection({
    super.key,
    required this.status,
    required this.count,
    required this.children,
    this.collapsed = false,
    this.onToggle,
    this.triggerKey,
    this.emptyLabel,
  });
  final String status;
  final int count;
  final List<Widget> children;
  final bool collapsed;
  final VoidCallback? onToggle;
  final Key? triggerKey;
  final String? emptyLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final states = RaftRecipeStates({if (t.dark) RaftRecipeStates.dark});
    final r = RaftTaskListSectionRecipe.resolve(states: states, tokens: rt);
    final trigger = _taskSectionTrigger(
      context,
      r,
      rt,
      status: status,
      count: count,
      collapsed: collapsed,
      onToggle: onToggle,
      triggerKey: triggerKey,
    );
    // The section fill is translucent. CSS shadows paint outside its box;
    // BoxDecoration would darken the fill by painting the shadow underneath it.
    return RaftRecipeBox(
      style: r.root,
      tokens: rt,
      decorationOverride: (decoration) =>
          t.option('listGroup.frame', or: 'framed') == 'plain'
          ? const BoxDecoration()
          : decoration.copyWith(color: t.components.taskSectionFill),
      padding: t.option('listGroup.frame', or: 'framed') == 'plain'
          ? EdgeInsets.zero
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 10, // className space-y-2.5
        children: [
          trigger,
          if (!collapsed)
            children.isEmpty
                ? RaftTaskLaneEmpty(
                    label: emptyLabel ?? '',
                    // TaskSectionEmpty `border-2 border-dashed
                    // border-line-muted px-3 py-5 text-sm
                    // text-foreground-muted`.
                    fill: r.empty.backgroundColor?.resolve(rt),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: children,
                  ),
        ],
      ),
    );
  }
}

/// A task status section whose rows are built only near the viewport.
/// Uses the same header, padding, fill and CSS shadow as [RaftTaskSection].
class RaftSliverTaskSection extends StatelessWidget {
  const RaftSliverTaskSection({
    super.key,
    required this.status,
    required this.count,
    required this.itemBuilder,
    this.collapsed = false,
    this.onToggle,
    this.triggerKey,
    this.emptyLabel,
    this.findChildIndexCallback,
    this.footer,
  });
  final String status;
  final int count;
  final IndexedWidgetBuilder itemBuilder;

  /// Below the rows inside the open panel, with no gap (TaskSection's
  /// per-lane "Load more" button follows `TaskSectionItems` directly).
  final Widget? footer;
  final bool collapsed;
  final VoidCallback? onToggle;
  final Key? triggerKey;
  final String? emptyLabel;
  final ChildIndexGetter? findChildIndexCallback;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        rt = RaftRecipeTokens(RaftTokens.of(context));
    final r = RaftTaskListSectionRecipe.resolve(
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    );
    final plain = t.option('listGroup.frame', or: 'framed') == 'plain';
    final current = DefaultTextStyle.of(context).style.color;
    final shadows = r.root.cssShadows(rt, currentColor: current);
    return DecoratedSliver(
      decoration: RaftCssBoxDecoration(
        color: plain ? null : t.components.taskSectionFill,
        border: plain ? null : r.root.border(rt, currentColor: current),
        borderRadius: plain ? null : r.root.borderRadius,
        boxShadow: [
          if (!plain)
            for (final layer in shadows.reversed)
              if (!layer.inset)
                BoxShadow(
                  color: layer.color,
                  offset: layer.offset,
                  blurRadius: raftCssBlurRadius(layer.blur),
                  spreadRadius: layer.spread,
                ),
        ],
      ),
      sliver: SliverPadding(
        padding: plain ? EdgeInsets.zero : r.root.padding,
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: _taskSectionTrigger(
                context,
                r,
                rt,
                status: status,
                count: count,
                collapsed: collapsed,
                onToggle: onToggle,
                triggerKey: triggerKey,
              ),
            ),
            if (!collapsed && count == 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _taskSectionEmpty(context, r, rt, emptyLabel),
                ),
              ),
            if (!collapsed && count > 0)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final child = itemBuilder(context, index);
                    return Padding(
                      key: child.key,
                      padding: const EdgeInsets.only(top: 10),
                      child: child,
                    );
                  },
                  childCount: count,
                  findChildIndexCallback: findChildIndexCallback,
                ),
              ),
            if (!collapsed && footer != null) SliverToBoxAdapter(child: footer),
          ],
        ),
      ),
    );
  }
}

Widget _taskSectionTrigger(
  BuildContext context,
  RaftTaskListSectionRecipeStyle r,
  RaftRecipeTokens rt, {
  required String status,
  required int count,
  required bool collapsed,
  VoidCallback? onToggle,
  Key? triggerKey,
}) {
  final t = RaftTokens.of(context);
  final label = raftText(context, raftTaskStatusLabel(status));
  final plain = t.option('listGroup.frame', or: 'framed') == 'plain';
  // raft-ui 0.95.3 taskListSection with a mouse from 768px
  // (`md:pointer-fine:min-h-control`): a 34px trigger, 32px by touch; the
  // count is `font-mono text-mono-meta text-foreground-hint`.
  final raft = plain
      ? RaftTaskListSectionRecipe.resolve(
          states: t.recipeStates(responsive: true),
          tokens: rt,
        )
      : r;
  return Semantics(
    button: onToggle != null,
    expanded: !collapsed,
    label:
        '${collapsed ? raftText(context, 'Show') : raftText(context, 'Hide')} $label',
    excludeSemantics: true,
    onTap: onToggle,
    child: _TaskPressable(
      key: triggerKey,
      onPressed: onToggle,
      radius: raft.trigger.borderRadius,
      builder: (_) => Container(
        constraints: plain
            ? BoxConstraints(minHeight: raft.trigger.minHeight ?? 32)
            : null,
        padding: plain
            ? const EdgeInsets.symmetric(horizontal: 8)
            : r.trigger.padding,
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: r.heading.columnGap ?? 8,
              children: [
                RaftTaskSectionBadge(status: status, label: label),
                Text(
                  '$count',
                  style: plain
                      ? raft.count
                            .textStyle(rt)
                            .copyWith(
                              fontFamily: t.monoFont,
                              fontFamilyFallback: const ['monospace'],
                            )
                      // TaskSectionCount + `text-xs font-mono
                      // text-foreground-muted` (frozen looks).
                      : r.count
                            .textStyle(rt)
                            .copyWith(
                              fontFamily: t.monoFont,
                              fontSize: 12,
                              height: 16 / 12,
                              color: t.colors['foreground-muted'],
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _taskSectionEmpty(
  BuildContext context,
  RaftTaskListSectionRecipeStyle r,
  RaftRecipeTokens rt,
  String? label,
) => RaftTokens.of(context).option('listGroup.frame', or: 'framed') == 'plain'
    ? RaftTaskLaneEmpty(label: label ?? '')
    : Container(
        padding: r.empty.padding,
        decoration: BoxDecoration(
          color: r.empty.backgroundColor?.resolve(rt),
          borderRadius: r.empty.borderRadius,
          border: Border.all(
            color:
                r.empty.borderColor?.resolve(rt) ??
                RaftTokens.of(context).colors['line-muted']!,
            width: r.empty.borderWidth.top,
          ),
        ),
        child: Text(
          label ?? '',
          style: r.empty
              .textStyle(rt)
              .copyWith(fontFamily: RaftTokens.of(context).bodyFont),
        ),
      );

/// TaskSectionBadge: TaskStatusIcon + label; brutal adds the taskStatus
/// status background.
class RaftTaskSectionBadge extends StatelessWidget {
  const RaftTaskSectionBadge({
    super.key,
    required this.status,
    required this.label,
    this.board = false,
  });
  final String status, label;

  /// `TaskBoardColumnBadge` (taskBoardColumn recipe) instead of
  /// `TaskSectionBadge`.
  final bool board;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    if (t.option('listGroup.frame', or: 'framed') == 'plain') {
      // raft-ui 0.95.3: `font-sans text-footnote font-bold`, the board
      // column's label in `foreground-muted`, the list section's in
      // `foreground-hint`; the status pixel in front.
      final ink = board
          ? RaftTaskBoardColumnRecipe.resolve(tokens: rt).badge
                .textStyle(rt)
                .color
          : RaftTaskListSectionRecipe.resolve(tokens: rt).badge
                .textStyle(rt)
                .color;
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          RaftMessageTaskStatusIcon(
            status: raftTaskStatusOf(status),
            color: t.ui.foregroundHint,
          ),
          RaftCssText(
            label,
            style: t.scale(
              RaftTypeScale.footnote,
              weight: FontWeight.w700,
              color: ink ?? t.ui.foregroundHint,
            ),
            controlLabel: true,
          ),
        ],
      );
    }
    final badge = board
        ? RaftTaskBoardColumnRecipe.resolve(tokens: rt).badge
        : RaftTaskListSectionRecipe.resolve(tokens: rt).badge;

    final base = badge.textStyle(rt);
    final size = base.fontSize ?? 10;
    final fg = base.color ?? t.strong;
    final iconColor = switch (status) {
      'in_progress' => t.semantic.taskStatusInProgressStrong,
      'in_review' => t.semantic.taskStatusInReviewStrong,
      'done' => t.semantic.taskStatusDoneStrong,
      'closed' => t.semantic.taskStatusClosedStrong,
      _ => t.semantic.taskStatusTodoStrong,
    };
    return Container(
      padding: badge.padding,
      decoration: BoxDecoration(color: null, border: badge.border(rt)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: badge.columnGap ?? 4,
        children: [
          RaftMessageTaskStatusIcon(
            status: raftTaskStatusOf(status),
            color: iconColor,
            size: badge.target('& svg')?.width ?? 10,
          ),
          Text(
            label,
            style: RaftControlTypography.of(
              context,
              base.copyWith(
                fontFamily: base.fontFamily ?? t.headingFont,
                fontSize: size,
                // Unset line-height inherits the trigger button's 1.5.
                height: base.height ?? 1.5,
                color: fg,
                letterSpacing: base.letterSpacing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Web `TaskBoardColumn` (taskBoardColumn recipe): a column whose trigger row
/// shows the status badge, the count and the open/closed chevron (the whole
/// row toggles the column), then the [body]. [dropActive] is the allowed drop
/// state of a card over the column; [dropBlockedLabel] the blocked one (with
/// the reason an empty column shows in place of "No … tasks").
class RaftTaskBoardColumn extends StatelessWidget {
  const RaftTaskBoardColumn({
    super.key,
    required this.status,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    required this.body,
    this.triggerKey,
    this.dropActive = false,
    this.dropBlockedLabel,
  });
  final String status, count;
  final bool collapsed, dropActive;
  final VoidCallback onToggle;
  final Widget body;
  final Key? triggerKey;

  /// A dragged card can't be dropped here (`data-drop-state=blocked`): why,
  /// as `TaskBoardColumnEmptyBlocked` says it in an empty column.
  final String? dropBlockedLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final flat = t.option('taskBoard.column', or: 'flat') == 'flat';
    // Raft: raft-ui 0.95.3 with the window and the input (34px trigger with a
    // mouse from 768px); the frozen looks keep their base states.
    final r = RaftTaskBoardColumnRecipe.resolve(
      states: flat ? t.recipeStates(responsive: true) : t.recipeStates(),
      tokens: rt,
    );
    final label = raftText(context, raftTaskStatusLabel(status));
    final countText = Text(
      count,
      style: flat
          // TaskBoardColumnCount: `font-mono text-mono-meta text-foreground-hint`.
          ? r.count
                .textStyle(rt)
                .copyWith(
                  fontFamily: t.monoFont,
                  fontFamilyFallback: const ['monospace'],
                )
          : r.count
                .textStyle(rt)
                .copyWith(
                  fontFamily: t.monoFont,
                  fontSize: 12,
                  height: 16 / 12,
                  color: t.colors['foreground-muted'],
                ),
    );
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: r.heading.columnGap ?? 8,
      children: [
        RaftTaskSectionBadge(status: status, label: label, board: true),
        countText,
      ],
    );
    final trigger = Semantics(
      button: true,
      expanded: !collapsed,
      label:
          '${collapsed ? raftText(context, 'Show') : raftText(context, 'Hide')} $label',
      excludeSemantics: true,
      onTap: onToggle,
      child: _TaskPressable(
        key: triggerKey,
        onPressed: onToggle,
        radius: r.trigger.borderRadius,
        builder: (hovered) => flat
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: r.trigger.minHeight ?? 32,
                ),
                // `flex justify-between gap-2`: heading, then the chevron.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: r.trigger.columnGap ?? 8,
                  children: [
                    Flexible(child: heading),
                    _TaskColumnChevron(
                      open: !collapsed,
                      size: r.chevron.target('& svg')?.width ?? 14,
                      // `text-foreground-hint group-hover:text-foreground`.
                      color: hovered
                          ? t.ui.foreground
                          : r.chevron.textStyle(rt).color ??
                                t.ui.foregroundHint,
                    ),
                  ],
                ),
              )
            : Padding(padding: r.trigger.padding, child: heading),
      ),
    );
    // raft-ui 0.95.3 taskBoardColumn: a flat 232px lane (no border, fill or
    // padding; "the column itself never changes fill"), `mb-2` under the
    // trigger while open. A collapsed column a card may drop on shows
    // `outline: 1.5px dashed line-strong; outline-offset: 4px`. The frozen
    // looks keep the bordered 320px lane card (taskBoard.column).
    if (flat) {
      final radius = r.root.borderRadius?.topLeft.x ?? 0;
      final column = SizedBox(
        width: r.root.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            trigger,
            if (!collapsed) ...[
              const SizedBox(height: 8),
              Flexible(
                child: _TaskDropScope(
                  allowed: dropActive,
                  blockedLabel: dropActive ? null : dropBlockedLabel,
                  child: body,
                ),
              ),
            ],
          ],
        ),
      );
      if (!(collapsed && dropActive)) return column;
      final outline = RaftTaskBoardColumnRecipe.resolve(
        states: t.recipeStates(
          responsive: true,
          extra: const ['data-drop-collapsed=true', 'data-drop-state=allowed'],
        ),
        tokens: rt,
      ).root;
      return CustomPaint(
        foregroundPainter: _LaneEmptyPainter(
          null,
          outline.outlineColor?.resolve(rt) ?? t.ui.lineStrong,
          outline.outlineWidth ?? 0,
          radius,
          outset: outline.outlineOffset ?? 0,
        ),
        child: column,
      );
    }
    return RaftRecipeBox(
      style: r.root,
      tokens: rt,
      // TasksPanel className: `border border-line-muted bg-fill-muted/30`
      // (brutal `border-2 border-black/20 bg-white/30`), drop-allowed
      // `border-line-strong bg-primary-soft` (brutal black border).
      decorationOverride: (d) => d.copyWith(
        color: dropActive
            ? t.colors['primary-soft']
            : t.colors['fill-muted']!.withValues(alpha: .3),
        border: Border.all(
          color: dropActive
              ? (t.colors['line-strong']!)
              : t.colors['line-muted']!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          trigger,
          if (!collapsed) ...[
            const SizedBox(height: 12),
            Flexible(child: body),
          ],
        ],
      ),
    );
  }
}

/// TaskBoardColumnChevron: `ChevronDown`, `-rotate-90` while the column is
/// collapsed and `rotate-0` open, in 150ms (none with reduced motion).
class _TaskColumnChevron extends StatelessWidget {
  const _TaskColumnChevron({
    required this.open,
    required this.size,
    required this.color,
  });
  final bool open;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0 : -.25,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150),
    curve: const Cubic(.4, 0, .2, 1),
    child: RaftIcon(RaftGlyph.chevronDown, size: size, color: color),
  );
}

/// The drop state of the board column around a lane's empty box
/// (`data-drop-state` on the TaskDropZone the column renders as).
class _TaskDropScope extends InheritedWidget {
  const _TaskDropScope({
    required this.allowed,
    required this.blockedLabel,
    required super.child,
  });
  final bool allowed;
  final String? blockedLabel;
  static _TaskDropScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TaskDropScope>();
  @override
  bool updateShouldNotify(_TaskDropScope old) =>
      old.allowed != allowed || old.blockedLabel != blockedLabel;
}

/// A Web `<button>` without a fill of its own (a column or section trigger,
/// the card's open area): a Tab stop that Enter or Space activates, the
/// `focus-visible:shadow-focus` ring at [radius] for keyboard focus only, and
/// whether a mouse is over it. Its semantics stay with the caller.
class _TaskPressable extends StatefulWidget {
  const _TaskPressable({
    super.key,
    required this.onPressed,
    required this.radius,
    required this.builder,
  });
  final VoidCallback? onPressed;
  final BorderRadius? radius;
  final Widget Function(bool hovered) builder;
  @override
  State<_TaskPressable> createState() => _TaskPressableState();
}

class _TaskPressableState extends State<_TaskPressable> {
  bool focused = false, hovered = false;
  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    return FocusableActionDetector(
      enabled: onPressed != null,
      includeFocusSemantics: false,
      mouseCursor: onPressed == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onShowFocusHighlight: (value) => setState(() => focused = value),
      onShowHoverHighlight: (value) => setState(() => hovered = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => onPressed?.call(),
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            boxShadow: focused && onPressed != null
                ? RaftTokens.of(context).focusShadows
                : null,
          ),
          child: widget.builder(hovered && onPressed != null),
        ),
      ),
    );
  }
}

/// `TaskSectionEmpty` / `TaskBoardColumnEmpty`: the dashed "No {status}
/// tasks." box of an empty lane. Raft (raft-ui 0.95.3): `flex min-h-16
/// items-center justify-center px-3 py-3 rounded-container border
/// border-dashed border-line-seam text-center text-footnote
/// text-foreground-hint`; on the board it is hidden while a card may drop on
/// the column and says why while it can't (`text-foreground-muted`).
class RaftTaskLaneEmpty extends StatelessWidget {
  const RaftTaskLaneEmpty({
    super.key,
    required this.label,
    this.board = false,
    this.fill,
  });
  final String label;

  /// Board column (`border border-dashed theme-brutal:border-2`, Elegant
  /// `layer-panel` fill) instead of the list section box.
  final bool board;

  /// List section fill (the recipe's `fill-muted`) of the frozen looks;
  /// unused on the board and in the Raft look.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option(
          board ? 'taskBoard.column' : 'listGroup.frame',
          or: board ? 'flat' : 'framed',
        ) ==
        (board ? 'flat' : 'plain')) {
      final drop = board ? _TaskDropScope.of(context) : null;
      if (drop?.allowed ?? false) return const SizedBox.shrink();
      final blocked = drop?.blockedLabel;
      final rt = RaftRecipeTokens(t);
      final states = t.recipeStates(responsive: true);
      final e = board
          ? RaftTaskBoardColumnRecipe.resolve(states: states, tokens: rt).empty
          : RaftTaskListSectionRecipe.resolve(states: states, tokens: rt).empty;
      return ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: double.infinity,
          minHeight: e.minHeight ?? 0,
        ),
        child: CustomPaint(
          painter: _LaneEmptyPainter(
            null,
            e.borderColor?.resolve(rt) ?? t.ui.lineSeam,
            e.borderWidth.top,
            e.borderRadius?.topLeft.x ?? 0,
          ),
          child: Padding(
            padding: e.padding,
            // `flex items-center justify-center`: the box is its text's
            // height (at least min-h-16), the text centred in it.
            child: Align(
              heightFactor: 1,
              child: RaftCssText(
                blocked ?? label,
                textAlign: TextAlign.center,
                style: t.scale(
                  RaftTypeScale.footnote,
                  color: blocked != null
                      ? t.ui.foregroundMuted
                      : t.ui.foregroundHint,
                ),
              ),
            ),
          ),
        ),
      );
    }
    // Board: border 1 (Brutal 2) line-muted (black/20); list: border-2
    // line-muted (black/30).
    final borderWidth = board ? (1.0) : 2.0;
    final borderColor = t.colors['line-muted']!;
    final radius = 8.0;
    final fillColor = board ? (t.colors['layer-panel']) : fill;
    return SizedBox(
      width: double.infinity,
      child: CustomPaint(
        painter: _LaneEmptyPainter(fillColor, borderColor, borderWidth, radius),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12 + borderWidth,
            vertical: 20 + borderWidth,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: t.headingFont,
              fontFamilyFallback: t.fontFallback,
              fontSize: 14,
              height: 20 / 14,
              leadingDistribution: TextLeadingDistribution.even,
              color: t.colors['foreground-muted'],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed rounded border the way Chromium draws one: dashes 3x the border
/// width, the gaps spread evenly over the path. With [outset] it is a CSS
/// `outline` that far outside the box (`outline-offset`), its radius grown
/// by the same amount.
class _LaneEmptyPainter extends CustomPainter {
  const _LaneEmptyPainter(
    this.fill,
    this.color,
    this.width,
    this.radius, {
    this.outset = 0,
  });
  final Color? fill, color;
  final double width, radius, outset;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = outset > 0 ? outset + width : 0.0;
    final outer = RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(grow),
      Radius.circular(radius + grow),
    );
    if (fill != null) canvas.drawRRect(outer, Paint()..color = fill!);
    final path = Path()..addRRect(outer.deflate(width / 2));
    final paint = Paint()
      ..color = color!
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final dash = width * 3;
    for (final metric in path.computeMetrics()) {
      final count = ((metric.length + dash) / (dash * 2)).floor().clamp(
        1,
        10000,
      );
      final gap = count > 1 ? (metric.length - count * dash) / count : 0.0;
      for (var i = 0; i < count; i++) {
        final start = i * (dash + gap);
        canvas.drawPath(metric.extractPath(start, start + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LaneEmptyPainter old) =>
      old.fill != fill ||
      old.color != color ||
      old.width != width ||
      old.radius != radius ||
      old.outset != outset;
}

/// TasksPanel lane paging button: `<Button size="sm" variant="outline"
/// className="box-border h-8 min-h-8 w-full gap-1 py-0 text-xs">`, labelled
/// `task.panel.loadMore` ("Load more") or `common.loading` ("Loading more…").
class RaftTaskLoadMoreButton extends StatelessWidget {
  const RaftTaskLoadMoreButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RaftControl(
      variant: RaftControlVariant.outline,
      visualHeight: 32,
      visualWidth: constraints.maxWidth,
      minimumTargetSize: 32,
      onPressed: loading ? null : onPressed,
      child: Center(
        child: Text(
          raftText(context, loading ? 'Loading more…' : 'Load more'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, height: 16 / 12),
        ),
      ),
    ),
  );
}
