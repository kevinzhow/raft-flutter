import 'package:flutter/material.dart';

import 'composer_recipe.dart';
import 'icons.dart';
import 'theme.dart';

/// The composer's action row: attach buttons at the left, the task action and
/// Send at the right. One widget draws it for the inline composer and the
/// expanded editor, so both use the same insets, gaps and controls. A [hint]
/// is a quiet line of text before the task action (the expanded editor's key
/// reminder).
class RaftComposerActionRow extends StatelessWidget {
  const RaftComposerActionRow({
    super.key,
    required this.recipe,
    required this.onSend,
    this.submitEnabled = true,
    this.busy = false,
    this.enabled = true,
    this.onImagePick,
    this.onAttach,
    this.taskAction,
    this.submitTooltip,
    this.spinner = false,
    this.hint,
    this.inset,
  });
  final RaftComposerRecipe recipe;
  final VoidCallback onSend;
  final bool submitEnabled, busy, enabled, spinner;
  final VoidCallback? onImagePick, onAttach;
  final Widget? taskAction;
  final String? submitTooltip, hint;

  /// Replaces the recipe's own inset (and its paint offset). The expanded
  /// editor passes its card padding so the row lines up with the toolbar and
  /// the text; the inline composer leaves it null.
  final EdgeInsets? inset;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final left = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!recipe.compact && onImagePick != null)
          RaftComposerAction(
            glyph: RaftGlyph.imagePlus,
            tooltip: 'Attach Media',
            onPressed: busy || !enabled ? null : onImagePick,
          ),
        if (!recipe.compact && onImagePick != null && onAttach != null)
          SizedBox(width: recipe.actionGap),
        if (!recipe.compact && onAttach != null)
          RaftComposerAction(
            glyph: RaftGlyph.paperclip,
            tooltip: 'Attach File',
            onPressed: busy || !enabled ? null : onAttach,
          ),
      ],
    );
    final right = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hint != null) ...[
          Flexible(
            child: Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: recipe.suggestionMeta.copyWith(
                color: t.colors['foreground-placeholder'],
              ),
            ),
          ),
          SizedBox(width: recipe.metaGap),
        ],
        if (taskAction != null) ...[
          Flexible(
            child: KeyedSubtree(
              key: const ValueKey('composer-task-action-slot'),
              child: taskAction!,
            ),
          ),
          SizedBox(width: recipe.metaGap),
        ],
        RaftComposerAction(
          key: const ValueKey('composer-submit'),
          glyph: RaftGlyph.send,
          tooltip: submitTooltip ?? 'Send',
          submit: true,
          busy: busy,
          spinner: spinner,
          // Source MessageInput only prevents the pointer-down blur: an
          // unfocused composer stays unfocused after a Send tap (no keyboard
          // pop), a focused one keeps focus.
          onPressed: submitEnabled ? onSend : null,
        ),
      ],
    );
    return Transform.translate(
      offset: inset == null ? recipe.toolbarPaintOffset : Offset.zero,
      child: Padding(
        key: const ValueKey('composer-toolbar-slot'),
        padding: inset ?? recipe.toolbarInset,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            left,
            SizedBox(width: recipe.toolbarGap),
            Flexible(child: right),
          ],
        ),
      ),
    );
  }
}
