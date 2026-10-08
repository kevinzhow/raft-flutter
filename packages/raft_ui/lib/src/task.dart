import 'package:flutter/material.dart';

import 'localization.dart';

import 'theme.dart';
import 'icons.dart';
import 'design_primitives.dart';
import 'inline_badge_editor.dart';
import 'mounted_task_chip.dart';
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

/// Component scales from raft-ui Badge and the product InlineBadgeEditor.
/// Status colors remain semantic status roles, resolved by RaftTaskStatus.
@immutable
class RaftTaskBadgeRecipe {
  const RaftTaskBadgeRecipe(this.tokens);
  final RaftTokens tokens;
  double get height => 20;
  double get radius => tokens.brutal ? 0 : 999;
  EdgeInsets get inset =>
      EdgeInsets.symmetric(horizontal: tokens.brutal ? 6 : 10, vertical: 2);
  TextStyle label(Color foreground) => RaftTypography.body(
    tokens,
    size: tokens.brutal ? 10 : 11,
    line: 12,
    weight: tokens.brutal ? FontWeight.w700 : FontWeight.w500,
    color: foreground,
  ).copyWith(letterSpacing: tokens.brutal ? 0 : .22);
  BoxConstraints target(RaftDensity density) => BoxConstraints(
    minWidth: density == RaftDensity.touch ? RaftMetrics.touchTarget : 0,
    minHeight: density == RaftDensity.touch ? RaftMetrics.touchTarget : height,
  );
}

class RaftTaskStatus extends StatelessWidget {
  const RaftTaskStatus({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftTaskBadgeRecipe(t);
    final (semantic, brutal, icon) = switch (status) {
      'in_progress' => ('info', 'cyan', Icons.play_arrow_outlined),
      'in_review' => ('accent', 'lavender', Icons.visibility_outlined),
      'done' => ('success', 'lime', Icons.check_circle_outline),
      'closed' => ('muted', 'stone', Icons.block),
      _ => ('warning', 'orange', Icons.circle_outlined),
    };
    final bg =
        t.colors[t.brutal
            ? 'color-brutal-$brutal'
            : status == 'closed'
            ? 'fill-muted'
            : '$semantic-soft']!;
    final fg = t.brutal
        ? Colors.black
        : t.colors[status == 'closed'
              ? 'foreground-strong'
              : '$semantic-strong']!;
    return Container(
      height: recipe.height,
      padding: recipe.inset,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(recipe.radius),
        border: t.brutal ? Border.all(color: t.ink) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          ExcludeSemantics(child: RaftSymbol(icon, size: 10, color: fg)),
          Text(
            raftText(context, raftTaskStatusLabel(status)),
            style: recipe.label(fg),
          ),
        ],
      ),
    );
  }
}

/// Status chip background/foreground — getTaskStatusBadgeClassName
/// (packages/web/src/components/task/taskStatusUi.ts): soft semantic pair in
/// elegant, `bg-brutal-{tone} text-black` in brutal.
(Color, Color) raftTaskStatusBadgeColors(RaftTokens t, String status) {
  final (semantic, brutal) = switch (status) {
    'in_progress' => ('info', 'cyan'),
    'in_review' => ('accent', 'lavender'),
    'done' => ('success', 'lime'),
    'closed' => ('muted', 'stone'),
    _ => ('warning', 'orange'),
  };
  if (t.brutal) return (t.colors['color-brutal-$brutal']!, Colors.black);
  return status == 'closed'
      ? (t.colors['fill-muted']!, t.colors['foreground-strong']!)
      : (t.colors['$semantic-soft']!, t.colors['$semantic-strong']!);
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
    final (bg, fg) = raftTaskStatusBadgeColors(t, status);
    final editor = RaftInlineBadgeEditor(
      label: raftText(context, raftTaskStatusLabel(status)),
      tooltip: raftText(context, 'Task status'),
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
      background: bg,
      foreground: fg,
      open: open,
      onOpenChanged: onOpenChanged,
      alignRight: alignRight,
    );
    return ConstrainedBox(
      constraints: RaftTaskBadgeRecipe(
        t,
      ).target(RaftDensityScope.of(context)).copyWith(minHeight: 0),
      child: Align(widthFactor: 1, heightFactor: 1, child: editor),
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
      final base = slot.textStyle(rt);
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

    final editable = onStatus != null && statusOptions.isNotEmpty;
    return Semantics(
      button: onTap != null,
      label: 'Open task #$number: $title',
      onTap: onTap,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        padding: r.root.padding,
        decoration: r.root.decoration(rt),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: r.meta.margin,
                    child: Row(
                      spacing: r.meta.columnGap ?? 8,
                      children: [
                        if (channel.isNotEmpty)
                          Flexible(
                            child: Text(
                              '#$channel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text(r.channel),
                            ),
                          ),
                        Text('#$number', style: text(r.number)),
                      ],
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text(r.title),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: r.description.margin,
                      child: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text(r.description),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8), // mt-2
              child: Align(
                alignment: Alignment.centerRight,
                // The badge is inline content of a block wrapper: it sits on
                // the line box of the inherited document text (16px / 1.5).
                child: RaftInlineLineBox(
                  style: RaftTypography.body(t, size: 16, line: 24),
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

RaftMessageTaskStatus _iconStatus(String status) => switch (status) {
  'in_progress' => RaftMessageTaskStatus.inProgress,
  'in_review' => RaftMessageTaskStatus.inReview,
  'done' => RaftMessageTaskStatus.done,
  'closed' => RaftMessageTaskStatus.closed,
  _ => RaftMessageTaskStatus.todo,
};

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
    final label = raftText(context, raftTaskStatusLabel(status));
    final trigger = Semantics(
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
    return Container(
      padding: r.root.padding,
      decoration: r.root.decoration(rt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 10, // className space-y-2.5
        children: [
          trigger,
          if (!collapsed)
            children.isEmpty
                ? Container(
                    padding: r.empty.padding,
                    decoration: BoxDecoration(
                      color: r.empty.backgroundColor?.resolve(rt),
                      borderRadius: r.empty.borderRadius,
                      border: Border.all(
                        color:
                            r.empty.borderColor?.resolve(rt) ??
                            t.colors['line-muted']!,
                        width: r.empty.borderWidth.top,
                      ),
                    ),
                    child: Text(
                      emptyLabel ?? '',
                      style: r.empty
                          .textStyle(rt)
                          .copyWith(fontFamily: t.bodyFont),
                    ),
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

/// TaskSectionBadge: TaskStatusIcon + label; brutal adds the taskStatus
/// status background.
class RaftTaskSectionBadge extends StatelessWidget {
  const RaftTaskSectionBadge({
    super.key,
    required this.status,
    required this.label,
  });
  final String status, label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final theme = t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;
    final badge = RaftTaskListSectionRecipe.resolve(
      theme: theme,
      tokens: rt,
    ).badge;
    final statusStyle = RaftTaskStatusRecipe.resolve(
      theme: theme,
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
            'in_progress' => const Color(0xFFF0B800), // oklch(0.8 0.19 88.97)
            'in_review' => const Color(0xFFEE8A2E), // oklch(0.72 0.16 58)
            'done' => t.colors['success']!,
            'closed' => t.colors['inactive']!,
            _ => t.colors['foreground-placeholder']!,
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
            status: _iconStatus(status),
            color: iconColor,
            inverse: t.colors['foreground-inverse']!,
            size: badge.target('& svg')?.width ?? 10,
          ),
          Text(
            upper ? label.toUpperCase() : label,
            style: base.copyWith(
              fontFamily: base.fontFamily ?? t.headingFont,
              fontSize: size,
              // Unset line-height inherits the trigger button's 1.5.
              height: base.height ?? 1.5,
              color: fg,
              letterSpacing: upper ? 0 : base.letterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}
