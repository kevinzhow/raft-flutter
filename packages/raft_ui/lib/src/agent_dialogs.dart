// Agent / member dialogs of the Web `components/agent` and `components/member`
// folders: the radio mark of raft-ui `RadioGroupItem` and `ResetAgentDialog`.
// Values come from the generated recipes; Tailwind classes written in the JSX
// are resolved in comments.
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'error_presentation.dart' show RaftErrorScope;
import 'dialog_card.dart' show raftRecipeThemeOf;
import 'icons.dart';
import 'overlays/dialog.dart' show showRaftDialog;
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/field.g.dart' as field_recipe;
import 'radio_group.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'agent_avatar_picker.dart' show RaftAvatarDiscardConfirmation;
import 'banner.dart';
import 'panel_layout.dart' show RaftCssText;
import 'settings_controls.dart';
import 'settings_layout.dart' show RaftSettingsText;
import 'theme.dart';

/// Web `ResetAgentDialog`: [ConfirmDialog] (`max-w-md`) holding a radio group
/// of restart / reset-session / full-reset, a warning banner for the full reset
/// and a confirm button that follows the chosen mode.
class RaftResetAgentDialog extends StatefulWidget {
  const RaftResetAgentDialog({
    super.key,
    required this.agentName,
    required this.canFullReset,
    required this.onConfirm,
    this.memberRuntimeOnly = false,
  });
  final String agentName;
  final bool canFullReset, memberRuntimeOnly;

  /// Runs the reset for `restart`, `session` or `full`.
  final Future<void> Function(String mode) onConfirm;
  @override
  State<RaftResetAgentDialog> createState() => _RaftResetAgentDialogState();
}

class _RaftResetAgentDialogState extends State<RaftResetAgentDialog> {
  String mode = 'restart';

  List<(String, String, String)> get options => widget.memberRuntimeOnly
      ? const [
          (
            'restart',
            'Restart Model',
            'Restart the agent process while keeping its runtime session and workspace files.',
          ),
          (
            'session',
            'Reset Model',
            'Clear the runtime session and restart the agent. Workspace files are preserved.',
          ),
        ]
      : [
          (
            'restart',
            'Restart Agent',
            'Stop and restart the agent process. Keeps the runtime session and workspace files.',
          ),
          (
            'session',
            'Reset Session & Restart',
            'Clear the runtime session and restart. Workspace files (MEMORY.md, notes/) are preserved.',
          ),
          if (widget.canFullReset)
            (
              'full',
              'Full Reset & Restart',
              'Clear the runtime session, delete all workspace files, and restart from scratch.',
            ),
        ];

  @override
  void didUpdateWidget(RaftResetAgentDialog old) {
    super.didUpdateWidget(old);
    // The chosen mode can leave the list (e.g. Full Reset once the viewer
    // loses permission while the dialog is open): fall back to the default.
    if (!options.any((o) => o.$1 == mode)) mode = 'restart';
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final choices = options;
    final selected = choices.firstWhere(
      (o) => o.$1 == mode,
      orElse: () => choices.first,
    );
    final strong = t.strong;
    return RaftConfirmDialog(
      surfaceKey: const ValueKey('agent-dialog'),
      title: raftFormat(context, 'Restart or reset {name}', {
        'name': widget.agentName,
      }),
      maxWidth: 448,
      confirmLabel: raftText(context, selected.$2),
      cancelLabel: raftText(context, 'Keep Working'),
      loadingLabel: raftText(context, 'Restarting…'),
      confirmGlyph: RaftGlyph.rotateCcw,
      confirmVariant: mode == 'full'
          ? RaftButtonRecipeVariant.danger
          : mode == 'session'
          ? RaftButtonRecipeVariant.warning
          : RaftButtonRecipeVariant.primary,
      onConfirm: () => widget.onConfirm(mode),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `space-y-3` group, `gap-3` between the radio rows.
          RaftRadioGroup<String>(
            value: mode,
            onChanged: (next) => setState(() => mode = next),
            spacing: 12,
            children: [
              for (final o in choices)
                RaftRadioGroupItem<String>(
                  key: ValueKey('agent-reset-option-${o.$1}'),
                  value: o.$1,
                  // `mt-0.5 shrink-0`
                  markInset: const EdgeInsets.only(top: 2),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // `block text-sm font-bold`
                      RaftCssText(
                        raftText(context, o.$2),
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w700,
                          color: strong,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // `mt-1 block text-xs text-foreground-muted`
                      RaftCssText(
                        raftText(context, o.$3),
                        style: RaftTypography.body(
                          t,
                          size: 12,
                          line: 16,
                          color: t.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (mode == 'full') ...[
            const SizedBox(height: 12),
            RaftBanner(
              size: RaftBannerRecipeSize.sm,
              descriptionWeight: FontWeight.w700,
              glyph: RaftGlyph.triangleAlert,
              description: raftText(
                context,
                'This will permanently delete all workspace files including MEMORY.md and notes/. This cannot be undone.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Web `AgentProfileEditDialog`: one profile field (display name, description
/// or role) in a `max-w-lg` Dialog with Cancel / Save (`accent`, enabled once
/// the staged value differs). Saving runs [onSave]; a failure is shown as a
/// warning banner in the body.
class RaftAgentProfileEditDialog extends StatefulWidget {
  const RaftAgentProfileEditDialog({
    super.key,
    required this.field,
    required this.onSave,
    this.displayName = '',
    this.description = '',
    this.namePlaceholder = '',
    this.role,
    this.roleOptions = const [],
  });

  /// `displayName`, `description` or `role`.
  final String field;
  final String displayName, description, namePlaceholder;
  final String? role;

  /// Roles the viewer may assign: (id, label).
  final List<(String, String)> roleOptions;

  /// Receives the changed field only.
  final Future<void> Function(Map<String, dynamic> fields) onSave;
  @override
  State<RaftAgentProfileEditDialog> createState() =>
      _RaftAgentProfileEditDialogState();
}

class _RaftAgentProfileEditDialogState
    extends State<RaftAgentProfileEditDialog> {
  late final name = TextEditingController(text: widget.displayName);
  late final description = TextEditingController(text: widget.description);
  late String? role = widget.role;
  bool saving = false, confirming = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next save starts; the dialog state is dropped when it closes.
  String? error;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  /// `requestClose` of AgentProfileEditDialog.tsx: nothing while saving, a
  /// dirty draft asks before it is discarded. The X, Cancel, Escape, Back
  /// and an outside press all run it.
  Future<void> requestClose() async {
    if (saving || confirming) return;
    if (!dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    confirming = true;
    final discard = await showRaftDialog<bool>(
      context: context,
      builder: (c) => RaftAvatarDiscardConfirmation(
        onKeep: () => Navigator.pop(c, false),
        onDiscard: () => Navigator.pop(c, true),
      ),
    );
    confirming = false;
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  String get title => switch (widget.field) {
    'description' => 'Edit Description',
    'role' => 'Edit Role',
    _ => 'Edit Display Name',
  };

  bool get tooLong =>
      widget.field == 'description' && description.text.trim().length > 3000;
  bool get dirty => switch (widget.field) {
    'displayName' => name.text.trim() != widget.displayName,
    'description' => description.text.trim() != widget.description,
    _ => role != widget.role,
  };

  Future<void> save() async {
    if (!dirty || tooLong || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(switch (widget.field) {
        'displayName' => {
          'displayName': name.text.trim().isEmpty ? null : name.text.trim(),
        },
        'description' => {
          'description': description.text.trim().isEmpty
              ? null
              : description.text.trim(),
        },
        _ => {'serverRole': role},
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          // Web: `data.error || agent.detail.editProfile.saveFailed`.
          error = RaftErrorScope.of(context)(
            e,
            fallback: 'Could not save changes. Try again.',
          );
        });
      }
    }
  }

  /// `FormField` label `mb-1` plus the Field root's recipe `gap`.
  double fieldGap(RaftTokens t) =>
      4 +
      (field_recipe.RaftFieldRecipe.resolve(
            theme: raftRecipeThemeOf(t),
            states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
            tokens: RaftRecipeTokens(t),
          ).root.rowGap ??
          0);

  Widget label(RaftTokens t, String text) => RaftCssText(
    raftText(context, text),
    style: RaftTypography.body(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w500,
      color: t.ink,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fieldBody = switch (widget.field) {
      'description' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(t, 'Description'),
          SizedBox(height: fieldGap(t)),
          RaftRecipeTextarea(
            fieldKey: const ValueKey('agent-profile-edit-description'),
            controller: description,
            minHeight: 96,
            recipeText: true,
            autofocus: true,
            placeholder: raftText(context, 'Describe what this agent does'),
            onChanged: (_) => setState(() {}),
          ),
          if (tooLong) ...[
            const SizedBox(height: 4),
            RaftCssText(
              raftFormat(
                context,
                'Description must be {count} characters or fewer.',
                {'count': 3000},
              ),
              style: RaftSettingsText(t).alert,
            ),
          ],
        ],
      ),
      'role' => RaftRadioGroup<String>(
        value: role,
        onChanged: (next) => setState(() => role = next),
        spacing: 12,
        children: [
          for (final o in widget.roleOptions)
            RaftRadioGroupItem<String>(
              value: o.$1,
              gap: 8,
              child: RaftCssText(
                raftText(context, o.$2),
                style: RaftTypography.body(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w500,
                  color: t.ink,
                ),
              ),
            ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(t, 'Display name'),
          SizedBox(height: fieldGap(t)),
          RaftRecipeInput(
            fieldKey: const ValueKey('agent-profile-edit-display-name'),
            controller: name,
            recipeText: true,
            autofocus: true,
            placeholder: widget.namePlaceholder,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    };
    return PopScope(
      canPop: !saving && !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) requestClose();
      },
      child: RaftDialogShell(
        surfaceKey: const ValueKey('agent-dialog'),
        title: title,
        maxWidth: 512,
        outlineClose: true,
        onClose: saving ? null : requestClose,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            fieldBody,
            if (error != null) ...[
              const SizedBox(height: 20),
              RaftBanner(size: RaftBannerRecipeSize.sm, description: error!),
            ],
          ],
        ),
        footer: [
          RaftSettingsRecipeButton(
            label: raftText(context, 'Cancel'),
            size: RaftButtonRecipeSize.sm,
            disabledOpacity: .3,
            onPressed: saving ? null : requestClose,
          ),
          RaftSettingsRecipeButton(
            key: const ValueKey('agent-profile-edit-save'),
            label: raftText(context, 'Save'),
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.sm,
            onPressed: dirty && !tooLong && !saving ? save : null,
          ),
        ],
      ),
    );
  }
}
