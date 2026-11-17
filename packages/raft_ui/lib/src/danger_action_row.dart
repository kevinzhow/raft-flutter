// Web features/settings/shared/DangerActionRow.tsx: a danger zone action as a
// settings row in a ListRowGroup of its own (title, consequence, and the
// button at the row's end, under the text where the row is under 32rem wide).
import 'package:flutter/material.dart';

import 'icons.dart';
import 'raft/list_row.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'settings_controls.dart' show RaftSettingsRecipeButton;
import 'space.dart';
import 'theme.dart';

/// `DangerActionRow`. [warning] is Leave Server's tone; the default `danger`
/// (red) is for what can't be undone, such as Delete Server.
class RaftDangerActionRow extends StatelessWidget {
  const RaftDangerActionRow({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.actionGlyph,
    this.warning = false,
    this.actionKey,
  });
  final String title, description, actionLabel;
  final VoidCallback onAction;

  /// `actionIcon` (`<Trash2 size={14} />`).
  final RaftGlyph? actionGlyph;
  final bool warning;
  final Key? actionKey;

  /// `@max-lg`: the container's own 32rem.
  static const wrapBelow = 512.0;

  @override
  Widget build(BuildContext context) {
    final button = RaftSettingsRecipeButton(
      key: actionKey,
      label: actionLabel,
      glyph: actionGlyph,
      glyphSize: actionGlyph == null ? null : 14,
      variant: warning
          ? RaftButtonRecipeVariant.warning
          : RaftButtonRecipeVariant.danger,
      size: RaftButtonRecipeSize.md,
      onPressed: onAction,
    );
    final body = RaftListRowBody(
      children: [
        RaftListRowTitle(title),
        RaftListRowDescription(description, wrap: true),
      ],
    );
    return RaftListRowGroup(
      children: [
        RaftListRow(
          variant: RaftListRowVariant.plain,
          interactive: false,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth < wrapBelow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: RaftSpace.x3,
                        children: [body, button],
                      )
                    : Row(
                        spacing: RaftSpace.x3,
                        children: [
                          Expanded(child: body),
                          button,
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
