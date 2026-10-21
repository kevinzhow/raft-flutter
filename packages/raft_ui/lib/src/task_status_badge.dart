import 'package:flutter/material.dart';

import 'icons.dart';
import 'mounted_task_chip.dart';
import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';

/// The app's task-status id (`in_progress`) as the closed raft-ui status set.
/// Unknown values fall back to todo, as the previous pill did; callers that
/// must not invent a state check `raftTaskStatuses` first.
RaftMessageTaskStatus raftTaskStatusOf(String status) => switch (status) {
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
  });
  final RaftMessageTaskStatus status;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final recipe = RaftMessageTaskChipRecipe(tokens, status);
    // TaskChip sets no font family: the label takes the surrounding document
    // face (a status pill in a heading-font panel stays in that face).
    final inherited = DefaultTextStyle.of(context).style;
    final style = recipe.textStyle.copyWith(
      fontFamily: inherited.fontFamily,
      fontFamilyFallback: inherited.fontFamilyFallback,
    );
    return Container(
      // The chip height is a minimum: a taller line box (Android Chinese
      // control profile, larger text) grows the pill instead of clipping.
      constraints: BoxConstraints(minHeight: recipe.chipHeight),
      padding: recipe.padding,
      decoration: BoxDecoration(
        color: recipe.background,
        borderRadius: recipe.radius,
        border: Border.fromBorderSide(recipe.side()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: recipe.gap,
        children: [
          RaftMessageTaskStatusIcon(
            status: status,
            color: recipe.iconForeground,
          ),
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
  }
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
