import 'overlays/dialog.dart' show RaftDialog;

// Presentation of the Web CreateTaskDialog
// (packages/web/src/components/task/CreateTaskDialog.tsx): DialogCard with one
// title Input per row (a ghost icon button once there are several), an outline
// "Add Another" button and Cancel / Create Task(s). The app adapter owns the
// rows' controllers and the create command.
import 'dart:async';

import 'package:flutter/material.dart';

import 'form_presentation.dart';

import 'dialog_card.dart';
import 'icons.dart';
import 'error_presentation.dart';
import 'localization.dart';
import 'raft/button.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart' show RaftRecipeSet;
import 'theme.dart';

class RaftCreateTaskDialogView extends StatelessWidget {
  const RaftCreateTaskDialogView({
    super.key,
    required this.titles,
    required this.filledCount,
    required this.onClose,
    required this.onSubmit,
    required this.onAddRow,
    required this.onRemoveRow,
    this.error,
    this.submitting = false,
  });

  /// One controller per title row (at least one).
  final List<TextEditingController> titles;

  /// Rows with a non-blank title (the submit button's `count`).
  final int filledCount;
  final VoidCallback onClose, onAddRow;

  /// Creates the tasks (the adapter's request may be asynchronous).
  final FutureOr<void> Function() onSubmit;
  final ValueChanged<int> onRemoveRow;
  final String? error;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16); // form `space-y-4`
    final batch = titles.length > 1;
    final legacy = RaftTokens.of(context).recipeSet == RaftRecipeSet.legacy;
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    return RaftModalBackdrop(
      child: RaftDialog.card(
        key: const ValueKey('create-task-dialog'),
        title: batch ? 'Create Tasks' : 'Create Task',
        onClose: onClose,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[RaftErrorBanner(error!), gap],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < titles.length; i++)
                  Padding(
                    // The final row's margin and Add Another's margin combine
                    // into the 12px gap below; earlier Web rows use mb-2.
                    padding: EdgeInsets.only(
                      bottom: i == titles.length - 1 ? 0 : (legacy ? 4 : 8),
                    ),
                    child: Row(
                      spacing: 4, // gap-1
                      children: [
                        Expanded(
                          child: RaftDialogTextInput(
                            fieldKey: ValueKey('create-task-title-$i'),
                            controller: titles[i],
                            placeholder: raftFormat(context, 'Task {n}', {
                              'n': i + 1,
                            }),
                            autofocus: i == 0,
                            enabled: !submitting,
                          ),
                        ),
                        if (batch && legacy)
                          RaftRecipeButton(
                            key: ValueKey('create-task-remove-$i'),
                            variant: RaftButtonRecipeVariant.danger,
                            size: RaftButtonRecipeSize.sm,
                            glyph: RaftGlyph.trash2,
                            padding: const EdgeInsets.all(4), // p-1
                            tooltip: 'Remove',
                            onPressed: () => onRemoveRow(i),
                          ),
                        if (batch && !legacy)
                          RaftButton(
                            key: ValueKey('create-task-remove-$i'),
                            uiVariant: RaftButtonVariant.ghost,
                            uiSize: RaftButtonSize.iconSm,
                            glyph: RaftGlyph.trash2,
                            glyphSize: 16,
                            semanticLabel: 'Remove',
                            onPressed: () => onRemoveRow(i),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12), // mt-3
                Align(
                  alignment: Alignment.centerLeft,
                  child: legacy
                      ? RaftRecipeButton(
                          key: const ValueKey('create-task-add-row'),
                          label: 'Add Another',
                          glyph: RaftGlyph.plus,
                          variant: RaftButtonRecipeVariant.outline,
                          size: RaftButtonRecipeSize.sm,
                          // px-2 py-1 text-xs font-bold gap-1
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          textStep: RaftTextSteps.xs,
                          fontWeight: FontWeight.w700,
                          gap: 4,
                          onPressed: onAddRow,
                        )
                      : RaftButton(
                          key: const ValueKey('create-task-add-row'),
                          label: 'Add Another',
                          glyph: RaftGlyph.plus,
                          glyphSize: 16,
                          // Web passes a plain Lucide Plus, without the
                          // data-icon=inline-start selector marker.
                          iconInlineStart: false,
                          uiVariant: RaftButtonVariant.outline,
                          uiSize: RaftButtonSize.sm,
                          onPressed: onAddRow,
                        ),
                ),
              ],
            ),
          ],
        ),
        // Preserve the usual gap while allowing large labels to flow onto
        // another line when the available width is too small.
        footer: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: legacy ? 12 : 8,
          runSpacing: legacy ? 12 : 8,
          children: [
            RaftRecipeButton(
              key: const ValueKey('create-task-cancel'),
              label: 'Cancel',
              variant: legacy
                  ? RaftButtonRecipeVariant.outline
                  : RaftButtonRecipeVariant.ghost,
              size: legacy ? RaftButtonRecipeSize.sm : RaftButtonRecipeSize.lg,
              padding: legacy ? padding : null,
              textStep: legacy ? RaftTextSteps.sm : null,
              onPressed: raftExplicitClose(context, onClose),
            ),
            RaftRecipeButton(
              key: const ValueKey('create-task-submit'),
              label: submitting
                  ? 'Creating…'
                  : (batch ? filledCount : 1) == 1
                  ? 'Create Task'
                  : raftFormat(context, 'Create {count} Tasks', {
                      'count': filledCount,
                    }),
              variant: RaftButtonRecipeVariant.accent,
              size: legacy ? RaftButtonRecipeSize.sm : RaftButtonRecipeSize.lg,
              padding: legacy ? padding : null,
              textStep: legacy ? RaftTextSteps.sm : null,
              disabled: submitting,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
