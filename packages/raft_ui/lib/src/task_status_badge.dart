import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'icons.dart';
import 'mounted_task_chip.dart';
import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';

/// The app's task-status id (`in_progress`) as the closed raft-ui status set.
/// Unknown values fall back to todo, as the previous pill did; callers that
/// must not invent a state check `raftTaskStatuses` first.
RaftMessageTaskStatus raftTaskStatusOf(String status) => switch (status) {
  'backlog' => RaftMessageTaskStatus.backlog,
  'in_progress' => RaftMessageTaskStatus.inProgress,
  'in_review' => RaftMessageTaskStatus.inReview,
  'done' => RaftMessageTaskStatus.done,
  'closed' => RaftMessageTaskStatus.closed,
  _ => RaftMessageTaskStatus.todo,
};

/// raft-ui `TaskStatusBadge`: Web's `StatusBadge` renders the same `TaskChip`
/// the message row uses, with the status icon in front of the caller's label.
/// Shape, size, border and colour all come from [RaftMessageTaskChipRecipe]
/// (`task-status-*` tokens: soft wash + strong ink + 35% border in elegant, the
/// solid pastel with black ink and a black border in brutal), so a status
/// cannot look different on different screens.
///
/// [trailing] is the extra content after the label (the editor's pencil).
class RaftTaskStatusBadge extends StatelessWidget {
  const RaftTaskStatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.trailing,
    this.labelHidden = false,
  });
  final RaftMessageTaskStatus status;
  final String label;
  final Widget? trailing;

  /// The label is the accessible name only (Web `sr-only` on the label, the
  /// Tasks page's narrow list): the badge shows its pixel and takes no gap.
  final bool labelHidden;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final recipe = RaftMessageTaskChipRecipe(tokens, status);
    // TaskChip sets no font family: the label takes the surrounding document
    // face (a status pill in a heading-font panel stays in that face).
    final inherited = DefaultTextStyle.of(context).style;
    final style = recipe.textStyle.copyWith(
      fontFamily: inherited.fontFamily,
      decoration: TextDecoration.none,
      fontFamilyFallback: inherited.fontFamilyFallback,
    );
    final border = Border.fromBorderSide(recipe.side());
    final icon = RaftMessageTaskStatusIcon(
      status: status,
      color: recipe.iconForeground,
    );
    final badge = Container(
      // The chip height is a minimum: a taller line box (Android Chinese
      // control profile, larger text) grows the pill instead of clipping.
      constraints: BoxConstraints(minHeight: recipe.chipHeight),
      padding: recipe.padding,
      decoration: BoxDecoration(
        color: recipe.background,
        borderRadius: recipe.radius,
        border: labelHidden ? null : border,
      ),
      // The compact badge's inset ring paints within the icon's padding.
      foregroundDecoration: labelHidden
          ? BoxDecoration(borderRadius: recipe.radius, border: border)
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: recipe.gap,
        children: [
          labelHidden ? _StatusIconBaseline(child: icon) : icon,
          if (!labelHidden)
            Flexible(
              child: RaftCssText(
                label,
                style: style,
                controlLabel: true,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ?trailing,
        ],
      ),
    );
    if (!labelHidden) return badge;
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(child: badge),
    );
  }
}

// A compact badge has no in-flow label. Its first flex item's baseline is
// synthesized at the bottom of the SVG.
class _StatusIconBaseline extends SingleChildRenderObjectWidget {
  const _StatusIconBaseline({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStatusIconBaseline();
}

class _RenderStatusIconBaseline extends RenderProxyBox {
  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) => size.height;

  @override
  double computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => getDryLayout(constraints).height;
}

/// The Pencil 10 at 40% opacity the InlineBadgeEditor puts after the label.
class RaftBadgeEditPencil extends StatelessWidget {
  const RaftBadgeEditPencil({super.key, required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: .4,
    child: RaftIcon(RaftGlyph.pencil, size: 10, color: color),
  );
}
