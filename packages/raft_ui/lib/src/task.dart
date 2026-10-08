import 'package:flutter/material.dart';

import 'localization.dart';

import 'theme.dart';
import 'icons.dart';
import 'design_primitives.dart';

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
    return Semantics(
      button: onTap != null,
      label: 'Open task #$number: $title',
      onTap: onTap,
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: RaftShapes.panel(t),
          border: Border.all(
            color: t.dark ? Colors.transparent : t.line,
            width: t.brutal ? 2 : .5,
          ),
          boxShadow: t.brutal ? t.shadows : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: RaftShapes.panel(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (channel.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            '#$channel',
                            overflow: TextOverflow.ellipsis,
                            style: RaftTypography.body(
                              t,
                              size: 12,
                              line: 16,
                              weight: t.brutal
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: t.brutal
                                  ? t.strong.withValues(alpha: .6)
                                  : t.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        '#$number',
                        style: t.brutal
                            ? RaftTypography.mono(
                                t,
                                size: 11,
                                line: 16,
                                color: t.strong.withValues(alpha: .35),
                              )
                            : RaftTypography.body(
                                t,
                                size: 11,
                                line: 14,
                                weight: FontWeight.w500,
                                color: t.colors['foreground-placeholder'],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: RaftTypography.body(
                      t,
                      size: 14,
                      line: 20,
                      weight: t.brutal ? FontWeight.w700 : FontWeight.w500,
                      color: t.brutal ? t.strong : t.ink,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: RaftTypography.body(
                          t,
                          size: t.brutal ? 12 : 13,
                          line: t.brutal ? 16 : 18,
                          color: t.brutal
                              ? t.strong.withValues(alpha: .7)
                              : t.muted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: onStatus != null && statusOptions.isNotEmpty
                        ? PopupMenuButton<String>(
                            tooltip: raftText(context, 'Task status'),
                            onSelected: onStatus,
                            itemBuilder: (_) => [
                              for (final s in statusOptions)
                                PopupMenuItem(
                                  value: s,
                                  child: RaftTaskStatus(status: s),
                                ),
                            ],
                            child: ConstrainedBox(
                              constraints: RaftTaskBadgeRecipe(t)
                                  .target(RaftDensityScope.of(context)),
                              child: Align(
                                widthFactor: 1,
                                heightFactor: 1,
                                child: RaftTaskStatus(status: status),
                              ),
                            ),
                          )
                        : RaftTaskStatus(status: status),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
