import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'control_typography.dart';
import 'localization.dart';

import 'theme.dart';
import 'design_primitives.dart';
import 'inline_badge_editor.dart';
import 'recipe_surface.dart';
import 'mounted_task_chip.dart';
import 'task_status_badge.dart';
import 'panel_layout.dart' show RaftCssText;
import '../recipes.dart';

const raftTaskStatuses = ['todo', 'in_progress', 'in_review', 'done', 'closed'];
const raftTaskTransitions = <String, List<String>>{
  'todo': ['in_progress', 'closed'],
  'in_progress': ['in_review', 'done', 'closed'],
  'in_review': ['done', 'in_progress', 'closed'],
  'done': ['todo', 'in_progress', 'in_review', 'closed'],
  'closed': ['todo', 'in_progress'],
};
String raftTaskStatusLabel(String status) => switch (status) {
  'todo' => 'Todo',
  'in_progress' => 'In Progress',
  'in_review' => 'In Review',
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
/// (`uppercase={false}`, `dropdownMinWidth="min-w-[140px]"`).
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
/// description, then `mt-2 flex justify-end` with the status editor.
class RaftTaskCard extends StatelessWidget {
  const RaftTaskCard({
    super.key,
    required this.title,
    required this.number,
    required this.status,
    this.channel = '',
    this.description = '',
    this.assignee,
    this.onTap,
    this.onStatus,
    this.statusOptions = const [],
  });
  final String title, number, status, channel, description;
  final String? assignee;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatus;
  final List<String> statusOptions;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final r = RaftTaskCardRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
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
        decoration: r.root.withCssUsedBorderWidths().decoration(rt),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftInlineLineBox(
              style: document,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // The card-level Semantics above exposes the open action.
                excludeFromSemantics: true,
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: r.meta.margin,
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
                                  style: text(r.channel),
                                ),
                              ),
                            RaftCssText('#$number', style: text(r.number)),
                          ],
                        ),
                      ),
                    ),
                    RaftCssText(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: text(r.title),
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: r.description.margin,
                        child: RaftCssText(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text(r.description),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8), // mt-2
              child: Align(
                alignment: Alignment.centerRight,
                // The badge is inline content of a block wrapper: it sits on
                // the line box of the inherited document text (16px / 1.5).
                child: RaftInlineLineBox(
                  style: document,
                  child: editable
                      ? RaftTaskStatusEditor(
                          status: status,
                          options: statusOptions,
                          onSelect: onStatus!,
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

RaftTaskStatusRecipeStatus _recipeStatus(String status) => switch (status) {
  'in_progress' => RaftTaskStatusRecipeStatus.inProgress,
  'in_review' => RaftTaskStatusRecipeStatus.inReview,
  'done' => RaftTaskStatusRecipeStatus.done,
  'closed' => RaftTaskStatusRecipeStatus.closed,
  _ => RaftTaskStatusRecipeStatus.todo,
};

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
    final theme = t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;
    final states = RaftRecipeStates({if (t.dark) RaftRecipeStates.dark});
    final r = RaftTaskListSectionRecipe.resolve(
      theme: theme,
      states: states,
      tokens: rt,
    );
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
          decoration.copyWith(color: t.components.taskSectionFill),
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
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    );
    final current = DefaultTextStyle.of(context).style.color;
    final shadows = r.root.cssShadows(rt, currentColor: current);
    return DecoratedSliver(
      decoration: RaftCssBoxDecoration(
        color: t.components.taskSectionFill,
        border: r.root.border(rt, currentColor: current),
        borderRadius: r.root.borderRadius,
        boxShadow: [
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
        padding: r.root.padding,
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
  return Semantics(
    button: onToggle != null,
    expanded: !collapsed,
    label:
        '${collapsed ? raftText(context, 'Show') : raftText(context, 'Hide')} $label',
    excludeSemantics: true,
    onTap: onToggle,
    child: GestureDetector(
      key: triggerKey,
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: r.trigger.padding,
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: r.heading.columnGap ?? 8,
              children: [
                RaftTaskSectionBadge(status: status, label: label),
                Text(
                  '$count',
                  // TaskSectionCount + `text-xs font-mono
                  // text-foreground-muted`.
                  style: r.count
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
) => Container(
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
    final theme = t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;
    final badge = board
        ? RaftTaskBoardColumnRecipe.resolve(theme: theme, tokens: rt).badge
        : RaftTaskListSectionRecipe.resolve(theme: theme, tokens: rt).badge;
    final statusStyle = RaftTaskStatusRecipe.resolve(
      status: _recipeStatus(status),
      tokens: rt,
    ).base;
    final base = badge.textStyle(rt);
    final size = base.fontSize ?? 10;
    final fg = base.color ?? t.strong;
    final upper = badge.textTransform == 'uppercase';
    final iconColor = t.brutal
        ? (badge.target('& svg')?.color?.resolve(rt) ?? fg)
        : switch (status) {
            'in_progress' => t.semantic.taskStatusInProgressStrong,
            'in_review' => t.semantic.taskStatusInReviewStrong,
            'done' => t.semantic.taskStatusDoneStrong,
            'closed' => t.semantic.taskStatusClosedStrong,
            _ => t.semantic.taskStatusTodoStrong,
          };
    return Container(
      padding: badge.padding,
      decoration: BoxDecoration(
        color: t.brutal ? statusStyle.backgroundColor?.resolve(rt) : null,
        border: badge.border(rt),
      ),
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
            upper ? label.toUpperCase() : label,
            style: RaftControlTypography.of(
              context,
              base.copyWith(
                fontFamily: base.fontFamily ?? t.headingFont,
                fontSize: size,
                // Unset line-height inherits the trigger button's 1.5.
                height: base.height ?? 1.5,
                color: fg,
                letterSpacing: upper ? 0 : base.letterSpacing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Web `TaskBoardColumn` (taskBoardColumn recipe): a 320px column whose
/// trigger row shows the status badge and count (the whole row toggles the
/// column), then `mb-3` and the [body]. [dropActive] is the allowed drop
/// state (`border-line-strong bg-primary-soft shadow-raft-sm`).
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
  });
  final String status, count;
  final bool collapsed, dropActive;
  final VoidCallback onToggle;
  final Widget body;
  final Key? triggerKey;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final r = RaftTaskBoardColumnRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    );
    final label = raftText(context, raftTaskStatusLabel(status));
    final trigger = Semantics(
      button: true,
      expanded: !collapsed,
      label:
          '${collapsed ? raftText(context, 'Show') : raftText(context, 'Hide')} $label',
      excludeSemantics: true,
      onTap: onToggle,
      child: GestureDetector(
        key: triggerKey,
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Padding(
          padding: r.trigger.padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: r.heading.columnGap ?? 8,
            children: [
              RaftTaskSectionBadge(status: status, label: label, board: true),
              Text(
                count,
                style: r.count
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
        ),
      ),
    );
    return RaftRecipeBox(
      style: r.root,
      tokens: rt,
      // TasksPanel className: `border border-line-muted bg-fill-muted/30`
      // (brutal `border-2 border-black/20 bg-white/30`), drop-allowed
      // `border-line-strong bg-primary-soft` (brutal black border).
      decorationOverride: (d) => d.copyWith(
        color: dropActive
            ? t.colors['primary-soft']
            : t.brutal
            ? Colors.white.withValues(alpha: .3)
            : t.colors['fill-muted']!.withValues(alpha: .3),
        border: Border.all(
          color: dropActive
              ? (t.brutal ? Colors.black : t.colors['line-strong']!)
              : t.brutal
              ? Colors.black.withValues(alpha: .2)
              : t.colors['line-muted']!,
          width: t.brutal ? 2 : 1,
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

/// `TaskSectionEmpty` / `TaskBoardColumnEmpty`: the dashed "No {status}
/// tasks." box of an empty lane (`border-dashed px-3 py-5 text-sm
/// text-foreground-muted`).
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

  /// List section fill (the recipe's `fill-muted`); unused on the board.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // Board: border 1 (Brutal 2) line-muted (black/20); list: border-2
    // line-muted (black/30).
    final borderWidth = board ? (t.brutal ? 2.0 : 1.0) : 2.0;
    final borderColor = t.brutal
        ? Colors.black.withValues(alpha: board ? .2 : .3)
        : t.colors['line-muted']!;
    final radius = t.brutal ? 0.0 : 8.0;
    final fillColor = board
        ? (t.brutal ? null : t.colors['layer-panel'])
        : fill;
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

class _LaneEmptyPainter extends CustomPainter {
  const _LaneEmptyPainter(this.fill, this.color, this.width, this.radius);
  final Color? fill, color;
  final double width, radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    if (fill != null) canvas.drawRRect(outer, Paint()..color = fill!);
    // Chromium dashes: 3x the border width, gaps spread evenly over the path.
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
      old.radius != radius;
}

/// TasksPanel lane paging button: `<Button size="sm" variant="outline"
/// className="box-border h-8 min-h-8 w-full gap-1 py-0 text-xs">`, labelled
/// `task.panel.loadMore` ("Load more") or `common.loading` ("Loading…").
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
          raftText(context, loading ? 'Loading…' : 'Load more'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, height: 16 / 12),
        ),
      ),
    ),
  );
}
