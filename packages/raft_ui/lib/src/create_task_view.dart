import 'overlays/dialog.dart' show RaftDialog;

// Presentation of the Web CreateTaskDialog
// (packages/web/src/components/task/CreateTaskDialog.tsx): DialogCard with one
// title Input per row (a ghost icon button once there are several), an outline
// "Add another" button and Cancel / Create Task(s). The app adapter owns the
// rows' controllers and the create command.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_presentation.dart';

import 'dialog_card.dart';
import 'icons.dart';
import 'error_presentation.dart';
import 'localization.dart';
import 'raft/button.dart';
import 'raft/css_box.dart' show raftControlBorderPx;
import 'form_controls.dart' show RaftField, RaftTextarea;
import 'raft/ui_tokens.dart';
import 'select_field.dart';
import 'task.dart' show raftTaskStatusLabel;
import 'tokens/tokens.dart' show RaftRadius, RaftTypeScale;
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart' show RaftRecipeSet;
import 'space.dart';
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
    this.sourceSender,
    this.sourceText,
    this.status,
    this.onStatusChanged,
    this.channelField,
  });

  /// The Channel picker when the channel is not fixed (the Tasks page).
  final Widget? channelField;

  /// Task v2: the status the new tasks start in (Web CreateTaskStatusField);
  /// null hides the field (before task v2).
  final String? status;
  final ValueChanged<String>? onStatusChanged;

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

  /// Task v2 "Create task from message" (Web CreateTaskSourceMessage): the
  /// message the tasks hang under, quoted above the titles.
  final String? sourceSender, sourceText;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16); // form `space-y-4`
    final batch = titles.length > 1;
    final legacy = RaftTokens.of(context).recipeSet == RaftRecipeSet.legacy;
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    return RaftModalBackdrop(
      child: RaftDialog.card(
        key: const ValueKey('create-task-dialog'),
        title: sourceText != null
            ? (batch ? 'Create tasks from message' : 'Create task from message')
            : batch
            ? 'Create tasks'
            : 'Create task',
        onClose: onClose,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sourceText != null) ...[
              _SourceMessageQuote(
                sender: sourceSender ?? '',
                text: sourceText!,
              ),
              gap,
            ],
            if (error != null) ...[RaftErrorBanner(error!), gap],
            if (channelField != null) ...[channelField!, gap],
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
                            // Web `<form onSubmit>`: Enter submits.
                            onSubmitted: (_) {
                              if (!submitting) onSubmit();
                            },
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
                          label: 'Add another',
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
                          label: 'Add another',
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
            if (status != null) ...[
              gap,
              RaftCreateTaskStatusField(
                status: status!,
                onChanged: submitting ? null : onStatusChanged,
                hint: filledCount > 1
                    ? raftFormat(
                        context,
                        'Status applies to all {count} tasks.',
                        {'count': filledCount},
                      )
                    : null,
              ),
            ],
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
                  ? 'Create'
                  : raftFormat(context, 'Create {count} tasks', {
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

/// `<blockquote className="rounded-control border border-line-hairline
/// bg-layer-card px-3 py-2 text-footnote text-foreground-muted">`: the sender
/// in `font-semibold text-foreground`, the text `line-clamp-3`.
class _SourceMessageQuote extends StatelessWidget {
  const _SourceMessageQuote({required this.sender, required this.text});
  final String sender, text;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    return DecoratedBox(
      key: const ValueKey('create-task-source-message'),
      decoration: BoxDecoration(
        color: ui.layerCard,
        borderRadius: BorderRadius.circular(
          t.size('radius.control', fallback: RaftRadius.control),
        ),
        border: Border.all(
          color: ui.lineHairline,
          width: raftControlBorderPx(context, RaftSpace.hairline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RaftSpace.x3,
          vertical: RaftSpace.x2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sender,
              style: t.scale(
                RaftTypeScale.footnote,
                weight: FontWeight.w600,
                color: ui.foreground,
              ),
            ),
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: t.scale(RaftTypeScale.footnote, color: ui.foregroundMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web v1.24 `CreateTaskChannelField`: the channel a create goes in, picked
/// (the Tasks page's New task); [error] goes under the select.
class RaftCreateTaskChannelField extends StatelessWidget {
  const RaftCreateTaskChannelField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.error,
  });
  final String label;

  /// (id, already-displayed label) of each channel that can be picked.
  final List<({String id, String label})> options;
  final String? value;
  final ValueChanged<String>? onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = raftText(context, label);
    return RaftField(
      key: const ValueKey('create-task-channel-field'),
      label: text,
      error: error,
      child: RaftSelectField<String>(
        key: const ValueKey('create-task-channel'),
        label: text,
        value: value,
        invalid: error != null,
        placeholder: raftText(context, 'Choose a channel'),
        items: [
          for (final option in options)
            RaftSelectItem(
              value: option.id,
              label: option.label,
              labelKey: ValueKey('create-task-channel-${option.id}'),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (next) {
                if (next != null) onChanged!(next);
              },
      ),
    );
  }
}

/// Web v1.24 `CreateTaskStatusField`: the status a new task starts in, one of
/// Backlog, Todo or In progress (shared TASK_CREATE_STATUSES).
class RaftCreateTaskStatusField extends StatelessWidget {
  const RaftCreateTaskStatusField({
    super.key,
    required this.status,
    required this.onChanged,
    this.hint,
  });
  final String status;
  final ValueChanged<String>? onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, 'Status');
    return RaftField(
      key: const ValueKey('create-task-status-field'),
      label: label,
      hint: hint,
      child: RaftSelectField<String>(
        key: const ValueKey('create-task-status'),
        label: label,
        value: status,
        items: [
          for (final value in const ['backlog', 'todo', 'in_progress'])
            RaftSelectItem(
              value: value,
              label: raftText(context, raftTaskStatusLabel(value)),
              labelKey: ValueKey('create-task-status-$value'),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) onChanged!(value);
              },
      ),
    );
  }
}

/// Web v1.24 `CreateTaskMessageDialog`: task v2's New task without a source
/// message is a message the person sends; its first line is the task's
/// title, the rest its description (Web `taskFromMessage`).
class RaftCreateTaskMessageDialogView extends StatelessWidget {
  const RaftCreateTaskMessageDialogView({
    super.key,
    required this.text,
    required this.status,
    required this.onStatusChanged,
    required this.onClose,
    required this.onSubmit,
    required this.canSubmit,
    this.channelLabel,
    this.channelField,
    this.error,
    this.submitting = false,
  });
  final TextEditingController text;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onClose;
  final FutureOr<void> Function() onSubmit;

  /// A title is written (the send button is enabled).
  final bool canSubmit;

  /// `#name` (or `@peer`) of a fixed channel, said under the title.
  final String? channelLabel;

  /// The Post in picker when the channel is not fixed (the Tasks page).
  final Widget? channelField;
  final String? error;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    final t = RaftTokens.of(context);
    final placeholder = raftText(context, 'What needs to be done?');
    return RaftModalBackdrop(
      child: RaftDialog.card(
        key: const ValueKey('create-task-message-dialog'),
        title: 'Create task',
        onClose: onClose,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (channelLabel != null) ...[
              Text(
                raftFormat(context, 'In {channel}', {'channel': channelLabel}),
                key: const ValueKey('create-task-posts-in'),
                style: t.scale(
                  RaftTypeScale.footnote,
                  color: t.ui.foregroundMuted,
                ),
              ),
              gap,
            ],
            if (error != null) ...[RaftErrorBanner(error!), gap],
            if (channelField != null) ...[channelField!, gap],
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                CallbackShortcuts(
                  // Enter is a new line (the rest is the description);
                  // Ctrl/Cmd+Enter sends.
                  bindings: {
                    const SingleActivator(
                      LogicalKeyboardKey.enter,
                      control: true,
                    ): () {
                      if (canSubmit && !submitting) onSubmit();
                    },
                    const SingleActivator(
                      LogicalKeyboardKey.enter,
                      meta: true,
                    ): () {
                      if (canSubmit && !submitting) onSubmit();
                    },
                  },
                  child: RaftTextarea(
                    controller: text,
                    fieldKey: const ValueKey('create-task-message'),
                    hintText: placeholder,
                    semanticLabel: placeholder,
                    rows: 4,
                    autofocus: true,
                    enabled: !submitting,
                    growsWithScale: true,
                  ),
                ),
                Text(
                  raftText(
                    context,
                    "The first line is the task's title; the rest is its description.",
                  ),
                  key: const ValueKey('create-task-message-hint'),
                  style: t.scale(
                    RaftTypeScale.footnote,
                    color: t.ui.foregroundMuted,
                  ),
                ),
              ],
            ),
            gap,
            RaftCreateTaskStatusField(
              status: status,
              onChanged: submitting ? null : onStatusChanged,
            ),
          ],
        ),
        footer: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            RaftButton(
              key: const ValueKey('create-task-cancel'),
              label: 'Cancel',
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.lg,
              onPressed: raftExplicitClose(context, onClose),
            ),
            RaftButton(
              key: const ValueKey('create-task-submit'),
              label: submitting ? 'Sending...' : 'Send and create task',
              uiVariant: RaftButtonVariant.accent,
              uiSize: RaftButtonSize.lg,
              disabled: submitting || !canSubmit,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
